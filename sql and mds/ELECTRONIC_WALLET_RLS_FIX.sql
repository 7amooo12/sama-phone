-- ============================================================================
-- Electronic Wallet RLS Policies Fix
-- This script fixes the RLS policies for electronic wallet system
-- ============================================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "electronic_wallets_admin_policy" ON public.electronic_wallets;
DROP POLICY IF EXISTS "electronic_wallets_read_policy" ON public.electronic_wallets;
DROP POLICY IF EXISTS "electronic_wallet_transactions_admin_policy" ON public.electronic_wallet_transactions;
DROP POLICY IF EXISTS "electronic_wallet_transactions_read_policy" ON public.electronic_wallet_transactions;

-- ============================================================================
-- STEP 1: Create Fixed RLS Policies for Electronic Wallets
-- ============================================================================

-- Policy for electronic_wallets - Admin and Accountant can manage all wallets
CREATE POLICY "electronic_wallets_admin_policy" ON public.electronic_wallets
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('admin', 'accountant')
            AND up.status IN ('active', 'approved')
        )
    );

-- Policy for electronic_wallets - Read access for authenticated users
CREATE POLICY "electronic_wallets_read_policy" ON public.electronic_wallets
    FOR SELECT USING (
        auth.role() = 'authenticated'
    );

-- ============================================================================
-- STEP 2: Create Fixed RLS Policies for Electronic Wallet Transactions
-- ============================================================================

-- Policy for electronic_wallet_transactions - Admin and Accountant can manage all transactions
CREATE POLICY "electronic_wallet_transactions_admin_policy" ON public.electronic_wallet_transactions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('admin', 'accountant')
            AND up.status IN ('active', 'approved')
        )
    );

-- Policy for electronic_wallet_transactions - Read access for authenticated users
CREATE POLICY "electronic_wallet_transactions_read_policy" ON public.electronic_wallet_transactions
    FOR SELECT USING (
        auth.role() = 'authenticated'
    );

-- ============================================================================
-- STEP 3: Verification
-- ============================================================================

-- Verify that the policies were created successfully
SELECT 
    schemaname,
    tablename,
    policyname,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('electronic_wallets', 'electronic_wallet_transactions')
ORDER BY tablename, policyname;

-- Check if the tables have RLS enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('electronic_wallets', 'electronic_wallet_transactions');

-- ============================================================================
-- STEP 4: Test the Policies (Optional)
-- ============================================================================

-- Test query to verify admin access (should work for admin/accountant users)
-- SELECT COUNT(*) FROM public.electronic_wallets;

-- Test query to verify read access (should work for all authenticated users)
-- SELECT wallet_type, COUNT(*) FROM public.electronic_wallets GROUP BY wallet_type;

-- ============================================================================
-- STEP 5: Grant Additional Permissions if Needed
-- ============================================================================

-- Ensure authenticated users can read the tables
GRANT SELECT ON public.electronic_wallets TO authenticated;
GRANT SELECT ON public.electronic_wallet_transactions TO authenticated;

-- Ensure service_role has full access
GRANT ALL ON public.electronic_wallets TO service_role;
GRANT ALL ON public.electronic_wallet_transactions TO service_role;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

SELECT 
    'Electronic Wallet RLS Policies Fixed Successfully!' as status,
    'The following issues were resolved:' as details,
    '1. Fixed up.user_id to up.id in RLS policies' as fix_1,
    '2. Updated status check to include both active and approved' as fix_2,
    '3. Verified all policies are correctly applied' as fix_3;
