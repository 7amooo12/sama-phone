# Flutter App RLS Debugging Guide

## 🚨 Issue: SQL Test Passes, Flutter App Fails

### **Root Cause**
- **SQL Editor**: Runs with admin privileges (bypasses RLS in practice)
- **Flutter App**: Runs with user authentication context (RLS fully enforced)

## 🔍 Step-by-Step Debugging Process

### **Step 1: Run Authentication Diagnostic**
```sql
-- Execute FLUTTER_AUTH_DIAGNOSTIC.sql in Supabase SQL Editor
-- This will:
-- ✅ Check all registered users
-- ✅ Create missing user profiles
-- ✅ Approve all users for testing
-- ✅ Verify RLS policy conditions
```

### **Step 2: Add Debug Code to Flutter App**

Add this debug code to your `SupabaseOrdersService.createOrder` method:

```dart
Future<String?> createOrder({
  required String clientId,
  required String clientName,
  required String clientEmail,
  required String clientPhone,
  required List<client_service.CartItem> cartItems,
  String? notes,
  String? shippingAddress,
}) async {
  try {
    // 🔍 DEBUG: Check authentication status
    final currentUser = _client.auth.currentUser;
    AppLogger.info('🔍 DEBUG: Current user: ${currentUser?.id}');
    AppLogger.info('🔍 DEBUG: User email: ${currentUser?.email}');
    AppLogger.info('🔍 DEBUG: JWT token exists: ${currentUser?.accessToken != null}');
    
    if (currentUser == null) {
      AppLogger.error('❌ No authenticated user found');
      return null;
    }

    // 🔍 DEBUG: Check user profile
    try {
      final profileResponse = await _client
          .from('user_profiles')
          .select('id, email, name, role, status')
          .eq('id', currentUser.id)
          .maybeSingle();
      
      AppLogger.info('🔍 DEBUG: User profile: $profileResponse');
      
      if (profileResponse == null) {
        AppLogger.error('❌ User profile not found for: ${currentUser.id}');
        return null;
      }
      
      if (profileResponse['status'] != 'approved') {
        AppLogger.error('❌ User not approved: ${profileResponse['status']}');
        return null;
      }
      
      AppLogger.info('✅ User profile OK: ${profileResponse['role']} - ${profileResponse['status']}');
    } catch (e) {
      AppLogger.error('❌ Error checking user profile: $e');
      return null;
    }

    // 🔍 DEBUG: Test RLS policy condition
    try {
      final policyTest = await _client
          .from('user_profiles')
          .select('id')
          .eq('id', currentUser.id)
          .eq('status', 'approved')
          .maybeSingle();
      
      AppLogger.info('🔍 DEBUG: RLS policy test result: ${policyTest != null ? 'PASS' : 'FAIL'}');
    } catch (e) {
      AppLogger.error('❌ RLS policy test failed: $e');
    }

    AppLogger.info('🔄 إنشاء طلب جديد في Supabase...');

    // حساب المجموع الإجمالي
    final total = cartItems.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));

    // 🔍 DEBUG: Log order data before insert
    final orderData = {
      'client_id': clientId,
      'client_name': clientName,
      'client_email': clientEmail,
      'client_phone': clientPhone,
      'total_amount': total,
      'status': 'pending',
      'payment_status': 'pending',
      'notes': notes,
      'shipping_address': shippingAddress != null ? {'address': shippingAddress} : null,
      'metadata': {
        'created_from': 'mobile_app',
        'items_count': cartItems.length,
      },
    };
    
    AppLogger.info('🔍 DEBUG: Order data to insert: $orderData');
    AppLogger.info('🔍 DEBUG: Client ID matches current user: ${clientId == currentUser.id}');

    // إنشاء الطلب الرئيسي
    final orderResponse = await _client
        .from(_ordersTable)
        .insert(orderData)
        .select('id, order_number')
        .single();

    final orderId = orderResponse['id'] as String;
    final orderNumber = orderResponse['order_number'] as String;

    AppLogger.info('✅ تم إنشاء الطلب: $orderNumber (ID: $orderId)');

    // Continue with rest of the method...
    // ... existing code for order items ...

    return orderId;
  } catch (e) {
    AppLogger.error('❌ خطأ في إنشاء الطلب: $e');
    
    // 🔍 DEBUG: Enhanced error logging
    if (e is PostgrestException) {
      AppLogger.error('🔍 DEBUG: PostgrestException details:');
      AppLogger.error('  - Message: ${e.message}');
      AppLogger.error('  - Code: ${e.code}');
      AppLogger.error('  - Details: ${e.details}');
      AppLogger.error('  - Hint: ${e.hint}');
    }
    
    return null;
  }
}
```

### **Step 3: Check Authentication Flow**

Add this to your login/authentication code:

```dart
// After successful login
final user = Supabase.instance.client.auth.currentUser;
if (user != null) {
  AppLogger.info('✅ User logged in: ${user.email}');
  
  // Check if profile exists
  final profile = await Supabase.instance.client
      .from('user_profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();
  
  if (profile == null) {
    AppLogger.error('❌ User profile missing - creating...');
    // Create profile or redirect to profile creation
  } else {
    AppLogger.info('✅ User profile exists: ${profile['role']} - ${profile['status']}');
    if (profile['status'] != 'approved') {
      AppLogger.warning('⚠️ User not approved - redirect to approval page');
    }
  }
}
```

### **Step 4: Test with Known Good User**

Use one of these test accounts:

```dart
// Test with admin account
Email: admin@samastore.com
Password: [your admin password]

// Or test with client account  
Email: test@sama.com
Password: [your test password]
```

### **Step 5: Verify RLS Policy Match**

The order creation will work if:

1. ✅ **User is authenticated**: `auth.uid()` returns valid UUID
2. ✅ **Profile exists**: Record in `user_profiles` table
3. ✅ **Status approved**: `status = 'approved'`
4. ✅ **Valid role**: One of `admin`, `owner`, `accountant`, `client`, `worker`
5. ✅ **Client ID matches**: For clients, `client_id = auth.uid()`

## 🔧 Common Issues & Fixes

### **Issue 1: User Profile Missing**
```sql
-- Fix: Create profile for authenticated user
INSERT INTO public.user_profiles (id, email, name, role, status)
VALUES ('user-uuid-here', 'user@email.com', 'User Name', 'client', 'approved');
```

### **Issue 2: User Not Approved**
```sql
-- Fix: Approve the user
UPDATE public.user_profiles 
SET status = 'approved' 
WHERE id = 'user-uuid-here';
```

### **Issue 3: Client ID Mismatch**
```dart
// Fix: Ensure client_id matches authenticated user
final currentUser = Supabase.instance.client.auth.currentUser;
final clientId = currentUser?.id; // Use this for client_id
```

### **Issue 4: Session Expired**
```dart
// Fix: Check and refresh session
final session = Supabase.instance.client.auth.currentSession;
if (session == null) {
  // Redirect to login
} else if (session.isExpired) {
  // Refresh session
  await Supabase.instance.client.auth.refreshSession();
}
```

## 🎯 Expected Debug Output

**Successful Order Creation:**
```
🔍 DEBUG: Current user: 12345678-1234-1234-1234-123456789012
🔍 DEBUG: User email: test@sama.com
🔍 DEBUG: JWT token exists: true
🔍 DEBUG: User profile: {id: 12345..., role: client, status: approved}
✅ User profile OK: client - approved
🔍 DEBUG: RLS policy test result: PASS
🔍 DEBUG: Client ID matches current user: true
✅ تم إنشاء الطلب: ORD-20250602-001 (ID: order-uuid)
```

**Failed Order Creation:**
```
🔍 DEBUG: Current user: 12345678-1234-1234-1234-123456789012
🔍 DEBUG: User profile: {id: 12345..., role: client, status: pending}
❌ User not approved: pending
```

## 🚀 Quick Fix Commands

Run these in Supabase SQL Editor:

```sql
-- 1. Approve all users
UPDATE public.user_profiles SET status = 'approved';

-- 2. Create missing profiles
INSERT INTO public.user_profiles (id, email, name, role, status)
SELECT id, email, SPLIT_PART(email, '@', 1), 'client', 'approved'
FROM auth.users 
WHERE id NOT IN (SELECT id FROM public.user_profiles);

-- 3. Verify fix
SELECT email, role, status FROM public.user_profiles WHERE status = 'approved';
```

After running the diagnostic and adding debug code, the exact cause of the RLS failure will be clear in your Flutter logs.
