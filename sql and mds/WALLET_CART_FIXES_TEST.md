# Testing Guide for Wallet Creation and Cart Privacy Fixes

## Issues Fixed

### 1. Automatic Wallet Creation
- **Problem**: New users didn't get wallets created automatically during registration
- **Solution**: Added wallet creation to both registration and user approval processes
- **Files Modified**:
  - `lib/providers/supabase_provider.dart` - Added wallet creation to signup and approval methods
  - Added WalletService import and integration

### 2. Shopping Cart Privacy Violation
- **Problem**: All users shared the same cart storage key, causing privacy violations
- **Solution**: Made cart storage user-specific with unique keys per user
- **Files Modified**:
  - `lib/providers/customer_cart_provider.dart` - Added user-specific cart keys
  - `lib/main.dart` - Updated provider setup to listen to authentication changes

## Testing Steps

### Test 1: Wallet Creation During Registration
1. Register a new user account
2. Check if wallet is created automatically
3. Verify wallet appears in admin/accountant wallet management

### Test 2: Wallet Creation During Approval
1. Admin approves a pending user
2. Check if wallet is created with appropriate initial balance based on role
3. Verify wallet appears in wallet management interface

### Test 3: Cart Privacy Isolation
1. Login as User A
2. Add products to cart
3. Logout and login as User B
4. Verify User B sees empty cart (not User A's cart)
5. Add different products to User B's cart
6. Logout and login back as User A
7. Verify User A still sees their original cart items

### Test 4: Cart Persistence
1. Login as a user
2. Add products to cart
3. Close and reopen the app
4. Login as the same user
5. Verify cart items are still there

## Expected Results

### Wallet Creation
- Every new user should automatically get a wallet
- Approved users should get wallets with role-based initial balances:
  - Admin: 10,000 EGP
  - Owner: 5,000 EGP
  - Accountant: 1,000 EGP
  - Worker: 500 EGP
  - Client: 100 EGP

### Cart Privacy
- Each user should have their own isolated cart
- Cart data should be stored with user-specific keys
- No user should see another user's cart items
- Cart should persist for each user individually

## Technical Implementation Details

### Cart Storage Keys
- Old: `'customer_cart_items'` (shared by all users)
- New: `'customer_cart_items_${userId}'` (unique per user)

### Wallet Creation Triggers
1. During user registration (immediate)
2. During user approval by admin (with role-based initial balance)
3. Automatic creation when accessing wallet features (fallback)

### Authentication Integration
- Cart provider now listens to authentication state changes
- Cart is automatically updated when users login/logout
- Cart is cleared when user logs out for security

## Files Modified

1. `lib/providers/customer_cart_provider.dart`
   - Added user-specific cart storage
   - Added authentication state handling
   - Added cart clearing on logout

2. `lib/providers/supabase_provider.dart`
   - Added WalletService integration
   - Added wallet creation to signup process
   - Added wallet creation to user approval process

3. `lib/main.dart`
   - Updated CustomerCartProvider to use ProxyProvider
   - Added authentication state listening for cart updates

## Quick Test Commands

### Run the app:
```bash
cd flutter_app/smartbiztracker_new
flutter clean
flutter pub get
flutter run
```

### Test with existing accounts:
- Admin: admin@sama.com
- Client: test@sama.com, cust@sama.com
- Worker: worker@sama.com, testw@sama.com
- Accountant: hima@sama.com
- Owner: eslam@sama.com

## Verification

### Check Wallet Creation in Database
```sql
SELECT 
    up.id,
    up.name,
    up.email,
    up.role,
    up.status,
    w.id as wallet_id,
    w.balance,
    w.created_at as wallet_created
FROM user_profiles up
LEFT JOIN wallets w ON up.id = w.user_id
ORDER BY up.created_at DESC;
```

### Check Cart Storage
- Cart keys should be user-specific: `customer_cart_items_${userId}`
- No shared `customer_cart_items` key should exist

## Success Criteria

✅ New users get wallets automatically during registration
✅ Approved users get wallets with role-based initial balances  
✅ Each user has isolated cart storage
✅ Cart persists per user across sessions
✅ No cart data leakage between users
✅ Wallets appear in admin/accountant management interfaces
