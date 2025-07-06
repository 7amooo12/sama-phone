# Testing Electronic Wallet Synchronization

## Steps to Test the Fixes

### 1. Run Database Migration
Execute the SQL script to set up the synchronization:
```sql
-- Run the FIX_ELECTRONIC_PAYMENT_APPROVAL_WORKFLOW.sql script in Supabase SQL Editor
```

### 2. Test Wallet Creation Synchronization
1. **Login as Accountant**
2. **Navigate to Electronic Payments → Wallet Management**
3. **Create a new electronic wallet:**
   - Wallet Type: Vodafone Cash or InstaPay
   - Phone Number: Valid Egyptian number (e.g., 01012345678)
   - Wallet Name: Test Wallet
   - Initial Balance: 1000 EGP
4. **Verify the wallet appears in the list**

### 3. Test Client Payment Options
1. **Login as Client**
2. **Navigate to Electronic Payments**
3. **Select Payment Method (Vodafone Cash or InstaPay)**
4. **Check if newly created wallets appear as payment options**
5. **Verify wallet details are correct (name, phone number)**

### 4. Test Payment Creation
1. **As Client, create a payment:**
   - Select the newly created wallet
   - Enter amount (e.g., 100 EGP)
   - Upload proof image
   - Submit payment
2. **Verify payment is created without foreign key errors**

### 5. Test Payment Approval and Wallet Balance Update
1. **Login as Accountant**
2. **Navigate to Electronic Payments → Payment Management**
3. **Find the pending payment**
4. **Approve the payment**
5. **Navigate back to Wallet Management**
6. **Verify the wallet balance increased by the payment amount**
   - Original: 1000 EGP
   - After 100 EGP payment: 1100 EGP

### 6. Test Wallet Transactions View
1. **In Wallet Management, click "View Transactions" for the wallet**
2. **Verify the approved payment appears in the transactions list**
3. **Check transaction details:**
   - Amount: 100 EGP
   - Client information
   - Date and time
   - Status: Approved

### 7. Test Manual Synchronization (Admin)
1. **Login as Admin**
2. **Navigate to the Wallet Sync Utility** (if added to admin menu)
3. **Click "Start Synchronization"**
4. **Verify success message**

## Expected Results

### ✅ Successful Test Indicators:
- [ ] New wallets created by accountants automatically appear as client payment options
- [ ] Clients can create payments without foreign key constraint errors
- [ ] Approved payments increase the electronic wallet balance
- [ ] Wallet transactions screen shows approved payments correctly
- [ ] Manual synchronization works without errors

### ❌ Issues to Watch For:
- Foreign key constraint violations when creating payments
- Wallets not appearing in client payment options
- Wallet balances not updating after payment approval
- Empty transaction lists in wallet transactions screen
- Synchronization errors

## Database Verification Queries

### Check Wallet-Payment Account Synchronization:
```sql
-- Check if all wallets have corresponding payment accounts
SELECT 
    ew.id,
    ew.wallet_name,
    ew.wallet_type,
    pa.account_type,
    pa.account_holder_name,
    pa.is_active
FROM electronic_wallets ew
LEFT JOIN payment_accounts pa ON ew.id = pa.id
ORDER BY ew.created_at DESC;
```

### Check Electronic Payment Approval Workflow:
```sql
-- Check if approved payments have corresponding wallet transactions
SELECT 
    ep.id as payment_id,
    ep.amount,
    ep.status,
    ep.approved_at,
    ewt.id as transaction_id,
    ewt.transaction_type,
    ewt.amount as transaction_amount,
    ew.wallet_name,
    ew.current_balance
FROM electronic_payments ep
LEFT JOIN electronic_wallet_transactions ewt ON ep.id = ewt.payment_id
LEFT JOIN electronic_wallets ew ON ep.recipient_account_id = ew.id
WHERE ep.status = 'approved'
ORDER BY ep.approved_at DESC;
```

### Check Wallet Balance Updates:
```sql
-- Check wallet balance history
SELECT 
    ew.wallet_name,
    ew.current_balance,
    COUNT(ewt.id) as transaction_count,
    SUM(CASE WHEN ewt.transaction_type = 'deposit' THEN ewt.amount ELSE 0 END) as total_deposits
FROM electronic_wallets ew
LEFT JOIN electronic_wallet_transactions ewt ON ew.id = ewt.wallet_id
GROUP BY ew.id, ew.wallet_name, ew.current_balance
ORDER BY ew.created_at DESC;
```

## Troubleshooting

### If wallets don't appear as payment options:
1. Check if payment accounts were created for the wallets
2. Run manual synchronization
3. Restart the app to refresh cached data

### If foreign key errors persist:
1. Verify the database migration ran successfully
2. Check if the `ensurePaymentAccountForWallet` function is working
3. Manually create payment accounts for existing wallets

### If wallet balances don't update:
1. Check if the approval trigger is working
2. Verify the `update_electronic_wallet_balance` function exists
3. Check database logs for errors during approval

## Notes
- The synchronization should happen automatically when wallets are created
- Manual synchronization is available as a backup option
- All changes maintain data consistency and referential integrity
- The system supports both Vodafone Cash and InstaPay wallets
