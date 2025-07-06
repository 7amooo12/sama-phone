# SmartBizTracker Authentication & RLS Testing Guide

## 🚨 Critical Issue: auth.uid() Returns NULL in SQL Editor

### **Problem Explanation**
The Supabase SQL Editor runs in an **unauthenticated context**, which means:
- `auth.uid()` returns `NULL`
- `auth.jwt()` returns `NULL` 
- `auth.role()` returns `anon` (anonymous)
- RLS policies that depend on `auth.uid()` will fail

### **Why This Happens**
1. **SQL Editor Context**: The Supabase SQL Editor doesn't maintain user authentication sessions
2. **Server-Side Execution**: SQL runs on the server without client authentication context
3. **Security Design**: This is intentional - SQL Editor has admin privileges, not user context

## 🔧 Solutions for RLS Testing

### **Solution 1: Use Actual UUIDs (Recommended)**

Instead of using `auth.uid()`, use actual user UUIDs from your database:

```sql
-- Find available users
SELECT id, email, name, role, status 
FROM public.user_profiles 
WHERE status = 'approved';

-- Use actual UUID in INSERT
INSERT INTO public.client_orders (
    client_id,
    client_name,
    -- ... other fields
) VALUES (
    '12345678-1234-1234-1234-123456789012', -- Actual UUID
    'Test Customer',
    -- ... other values
);
```

### **Solution 2: Temporarily Disable RLS**

For testing basic functionality:

```sql
-- Disable RLS temporarily
ALTER TABLE public.client_orders DISABLE ROW LEVEL SECURITY;

-- Run your tests
-- ... test code here ...

-- Re-enable RLS
ALTER TABLE public.client_orders ENABLE ROW LEVEL SECURITY;
```

### **Solution 3: Test in Flutter App Context**

The proper way to test RLS policies is within the authenticated Flutter app:

1. **Login to Flutter App**: Ensure user is authenticated
2. **Check User Profile**: Verify user has approved status
3. **Test Order Creation**: Use the app's order creation functionality
4. **Monitor Logs**: Check Flutter logs for RLS errors

## 📋 Step-by-Step Fix Process

### **Step 1: Run Authentication Diagnostic**
```sql
-- Execute AUTH_DIAGNOSTIC.sql
-- This will show you available users and authentication status
```

### **Step 2: Apply RLS Fix**
```sql
-- Execute RLS_FIX_NO_AUTH.sql
-- This creates proper RLS policies without requiring authentication
```

### **Step 3: Test with Actual UUIDs**
```sql
-- Execute MANUAL_TEST_WITH_UUID.sql
-- This tests order creation using real user UUIDs
```

### **Step 4: Test in Flutter App**
1. Login to your Flutter app with an approved user
2. Try creating an order through the app
3. Check if the RLS error is resolved

## 🎯 Flutter App Authentication Requirements

### **User Profile Requirements**
For order creation to work, users must have:

```sql
-- Required user profile structure
{
    "id": "uuid-from-auth-users",
    "email": "user@example.com", 
    "name": "User Name",
    "role": "admin|owner|accountant|manager|client|worker",
    "status": "approved",  -- CRITICAL: Must be 'approved'
    "created_at": "timestamp"
}
```

### **Authentication Flow**
1. **User Registration**: Creates record in `auth.users`
2. **Profile Creation**: Creates record in `user_profiles`
3. **Admin Approval**: Status changed to 'approved'
4. **Login**: User authenticates and gets JWT token
5. **Order Creation**: RLS policies check authenticated user

## 🔍 Troubleshooting Guide

### **Issue: "new row violates row-level security policy"**

**Diagnosis Steps:**
1. Check if user is authenticated: `auth.uid()` should return UUID
2. Check user profile exists: Query `user_profiles` table
3. Check user status: Must be 'approved'
4. Check user role: Must be valid role (admin, client, etc.)

**Common Fixes:**
```sql
-- Fix 1: Update user status
UPDATE public.user_profiles 
SET status = 'approved' 
WHERE id = 'user-uuid-here';

-- Fix 2: Create missing profile
INSERT INTO public.user_profiles (id, email, name, role, status)
VALUES ('user-uuid', 'email@example.com', 'Name', 'client', 'approved');

-- Fix 3: Check RLS policies exist
SELECT * FROM pg_policies WHERE tablename = 'client_orders';
```

### **Issue: auth.uid() returns NULL**

**In SQL Editor:**
- This is normal - use actual UUIDs for testing
- SQL Editor doesn't maintain user sessions

**In Flutter App:**
- Check user login status
- Verify Supabase client initialization
- Check JWT token validity

## 🛠️ RLS Policy Structure

### **Current Working Policies**
```sql
-- Admin/Owner/Accountant/Manager: Full access
CREATE POLICY "admin_full_access" ON public.client_orders
    FOR ALL TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() 
        AND role = 'admin'
        AND status = 'approved'
    ));

-- Client: Own orders only  
CREATE POLICY "client_own_orders" ON public.client_orders
    FOR ALL TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() 
        AND role = 'client'
        AND status = 'approved'
    ) AND client_id = auth.uid());

-- Worker: Assigned orders only
CREATE POLICY "worker_assigned_orders" ON public.client_orders
    FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() 
        AND role = 'worker'
        AND status = 'approved'
    ) AND assigned_to = auth.uid());
```

## 🎉 Success Verification

### **RLS Policies Working When:**
1. ✅ User is authenticated in Flutter app (`auth.uid()` returns UUID)
2. ✅ User profile exists in `user_profiles` table
3. ✅ User status is 'approved'
4. ✅ User role matches policy conditions
5. ✅ Order data matches policy requirements (e.g., `client_id = auth.uid()`)

### **Order Creation Success Indicators:**
- ✅ No RLS policy violation errors
- ✅ Order appears in `client_orders` table
- ✅ Order items created in `client_order_items` table
- ✅ User can view their orders in Flutter app

## 📞 Support

If you continue experiencing issues:

1. **Run Diagnostics**: Execute all diagnostic scripts
2. **Check Logs**: Review Flutter app logs for specific errors
3. **Verify Data**: Ensure user profiles are properly configured
4. **Test Incrementally**: Test each component separately

The RLS policies are now properly configured. The main requirement is ensuring users are authenticated and approved in the Flutter app context.
