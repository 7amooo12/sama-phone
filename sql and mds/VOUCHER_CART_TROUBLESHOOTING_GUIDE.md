# Shopping Cart Voucher Integration - Troubleshooting Guide

## Problem Analysis

Based on the investigation, the voucher integration issues in the shopping cart are likely caused by one or more of the following:

### 1. **User Authentication Issues**
- **Symptom**: Voucher section shows "يجب تسجيل الدخول لاستخدام القسائم"
- **Cause**: `supabaseProvider.user` returns null
- **Solution**: Ensure user is properly authenticated before accessing cart

### 2. **Voucher Loading Issues**
- **Symptom**: No vouchers displayed even when user is authenticated
- **Cause**: `voucherProvider.validActiveClientVouchers` returns empty list
- **Solution**: Check voucher data integrity and client voucher assignments

### 3. **Cart Item Compatibility Issues**
- **Symptom**: Vouchers load but show as "not applicable"
- **Cause**: Cart items don't match voucher target criteria
- **Solution**: Verify voucher target configuration and cart item categories

### 4. **Discount Calculation Issues**
- **Symptom**: Voucher applies but discount amount is 0
- **Cause**: `calculateVoucherDiscount` returns 0 or negative value
- **Solution**: Check voucher discount calculation logic

## Debugging Steps

### Step 1: Enable Debug Logging
The enhanced CartVoucherSection now includes comprehensive logging. Check the console for:

```
🔄 Starting _loadApplicableVouchers...
📦 Cart has X items
👤 Current user: user-id-here
📋 Current voucher count: X
✅ Valid active vouchers: X
🛒 Cart items for voucher service: X
✅ Found X applicable vouchers
```

### Step 2: Test with Specific Client
Use the previously problematic client ID for testing:
```dart
const TEST_CLIENT_ID = 'aaaaf98e-f3aa-489d-9586-573332ff6301';
```

### Step 3: Run Debug Script
Execute `debug_voucher_cart.dart` to test the complete flow:
```bash
dart debug_voucher_cart.dart
```

## Common Issues and Solutions

### Issue 1: "يجب تسجيل الدخول لاستخدام القسائم"

**Diagnosis:**
```dart
final currentUser = supabaseProvider.user;
if (currentUser == null) {
  // This error occurs
}
```

**Solutions:**
1. Ensure user is logged in before accessing cart
2. Check SupabaseProvider initialization
3. Verify authentication state persistence

**Test:**
```dart
final supabase = Supabase.instance.client;
final user = supabase.auth.currentUser;
print('Current user: ${user?.id}');
```

### Issue 2: "لا توجد قسائم متاحة"

**Diagnosis:**
```dart
final validActiveVouchers = voucherProvider.validActiveClientVouchers;
if (validActiveVouchers.isEmpty) {
  // This message shows
}
```

**Solutions:**
1. Check if vouchers exist for the client:
   ```dart
   await voucherProvider.loadClientVouchers(clientId);
   print('Total vouchers: ${voucherProvider.clientVouchers.length}');
   ```

2. Verify voucher data integrity:
   ```dart
   for (final cv in voucherProvider.clientVouchers) {
     print('Voucher ${cv.id}: ${cv.voucher?.name ?? 'NULL DATA'}');
   }
   ```

3. Check voucher status and expiration:
   ```dart
   for (final cv in voucherProvider.clientVouchers) {
     print('Status: ${cv.status.value}, Can be used: ${cv.canBeUsed}');
   }
   ```

### Issue 3: Vouchers Load But Don't Apply

**Diagnosis:**
```dart
final applicableVouchers = await voucherProvider.getApplicableVouchers(clientId, cartItems);
if (applicableVouchers.isEmpty) {
  // Vouchers exist but none are applicable
}
```

**Solutions:**
1. Check cart item format:
   ```dart
   final cartItemsForVoucher = widget.cartItems.map((item) => {
     'productId': item.productId,
     'productName': item.productName,
     'price': item.price,
     'quantity': item.quantity,
     'category': item.category, // Ensure this exists
   }).toList();
   ```

2. Verify voucher target configuration:
   ```dart
   for (final voucher in voucherProvider.validActiveClientVouchers) {
     print('Voucher: ${voucher.voucher?.name}');
     print('Type: ${voucher.voucher?.type}');
     print('Target: ${voucher.voucher?.targetName}');
   }
   ```

3. Check category matching:
   ```dart
   for (final item in cartItems) {
     print('Cart item: ${item.productName} - Category: ${item.category}');
   }
   ```

### Issue 4: Discount Calculation Returns 0

**Diagnosis:**
```dart
final discountResult = voucherProvider.calculateVoucherDiscount(voucher, cartItems);
final discountAmount = discountResult['totalDiscount'] as double;
if (discountAmount <= 0) {
  // Discount calculation failed
}
```

**Solutions:**
1. Check voucher discount percentage:
   ```dart
   print('Voucher discount: ${voucher.discountPercentage}%');
   ```

2. Verify cart total:
   ```dart
   final cartTotal = cartItems.fold(0.0, (sum, item) => 
     sum + (item['price'] * item['quantity']));
   print('Cart total: $cartTotal');
   ```

3. Check discount calculation logic in VoucherService

## Quick Fix Implementation

### 1. Add Fallback Error Handling
```dart
// In CartVoucherSection._loadApplicableVouchers()
try {
  // ... existing code
} catch (e) {
  AppLogger.error('Voucher loading failed: $e');
  setState(() {
    _validationError = 'خطأ في تحميل القسائم. يرجى المحاولة مرة أخرى.';
    _isLoading = false;
  });
  
  // Show retry button
  _showRetryOption();
}
```

### 2. Add Manual Refresh Option
```dart
Widget _buildErrorDisplay(ThemeData theme) {
  return Container(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Text(_validationError!),
        ElevatedButton(
          onPressed: _loadApplicableVouchers,
          child: const Text('إعادة المحاولة'),
        ),
      ],
    ),
  );
}
```

### 3. Add Debug Information Display
```dart
// In debug mode, show voucher details
if (kDebugMode) {
  return Column(
    children: [
      Text('Debug: ${voucherProvider.clientVouchers.length} total vouchers'),
      Text('Debug: ${_applicableVouchers.length} applicable vouchers'),
      // ... rest of UI
    ],
  );
}
```

## Testing Checklist

- [ ] User authentication works
- [ ] Vouchers load for test client ID
- [ ] Cart items have correct category data
- [ ] Voucher applicability check works
- [ ] Discount calculation returns positive values
- [ ] Voucher application triggers cart update
- [ ] Cart summary shows discount correctly
- [ ] Voucher removal works
- [ ] State persists through navigation

## Next Steps

1. **Run the debug script** to identify the specific issue
2. **Check console logs** for detailed error information
3. **Test with known working vouchers** from the recovery process
4. **Verify cart item data structure** matches VoucherService expectations
5. **Test voucher application flow** step by step

The enhanced logging will help pinpoint exactly where the voucher integration is failing, allowing for targeted fixes.
