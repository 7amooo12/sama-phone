# Wallet System Migration Instructions

## Steps to Apply Wallet System to Supabase

### 1. Run the Database Migrations

Execute the following SQL files in your Supabase SQL Editor in this order:

1. **Create Wallet Tables:**
   ```sql
   -- Copy and paste the content from:
   -- supabase/migrations/20241215000000_create_wallet_system.sql
   ```

2. **Apply RLS Policies:**
   ```sql
   -- Copy and paste the content from:
   -- supabase/migrations/20241215000001_wallet_rls_policies.sql
   ```

### 2. Verify Tables Created

After running the migrations, verify that the following tables exist in your Supabase database:

- `wallets`
- `wallet_transactions`
- `wallet_summary` (view)

### 3. Test the System

1. **Create Test Wallets:**
   ```sql
   -- Create wallets for existing approved users
   INSERT INTO public.wallets (user_id, role, balance)
   SELECT id, role, 0.00
   FROM public.user_profiles
   WHERE status = 'approved'
   ON CONFLICT (user_id, role) DO NOTHING;
   ```

2. **Create Test Transactions:**
   ```sql
   -- Add some test transactions
   INSERT INTO public.wallet_transactions (
     wallet_id, user_id, transaction_type, amount, description, created_by
   )
   SELECT 
     w.id, 
     w.user_id, 
     'credit', 
     1000.00, 
     'Initial balance for testing',
     (SELECT id FROM public.user_profiles WHERE role = 'admin' LIMIT 1)
   FROM public.wallets w
   WHERE w.role IN ('client', 'worker')
   LIMIT 5;
   ```

### 4. Flutter App Integration

The wallet system is now integrated into the Flutter app with:

- ✅ **Models:** `WalletModel` and `WalletTransactionModel`
- ✅ **Service:** `WalletService` for database operations
- ✅ **Provider:** `WalletProvider` for state management
- ✅ **UI:** `CompanyAccountsWidget` in Owner Dashboard
- ✅ **Tab:** New "حسابات الشركة" (Company Accounts) tab added

### 5. Features Available

#### For Owners:
- View all client and worker wallets
- Monitor wallet balances and transaction history
- View wallet statistics and analytics
- Professional charts and data visualization

#### For Admins/Accountants:
- Full wallet management capabilities
- Create and manage transactions
- Update wallet statuses
- Complete financial oversight

#### For Workers/Clients:
- View their own wallet balance
- See transaction history
- Read-only access to personal financial data

### 6. Automatic Features

- **Auto Wallet Creation:** Wallets are automatically created when users are approved
- **Balance Updates:** Wallet balances update automatically with transactions
- **Transaction Tracking:** Complete audit trail with before/after balances
- **Role-Based Security:** RLS policies ensure proper access control

### 7. Next Steps

1. Run the migrations in Supabase
2. Test the wallet creation and transactions
3. Access the Owner Dashboard to see the new "Company Accounts" tab
4. Verify role-based access is working correctly

The wallet system is now fully integrated and ready for use!
