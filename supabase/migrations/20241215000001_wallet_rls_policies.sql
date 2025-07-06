-- RLS Policies for Wallet System
-- Migration: 20241215000001_wallet_rls_policies.sql

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "wallets_admin_full_access" ON public.wallets;
DROP POLICY IF EXISTS "wallets_accountant_full_access" ON public.wallets;
DROP POLICY IF EXISTS "wallets_owner_read_access" ON public.wallets;
DROP POLICY IF EXISTS "wallets_user_own_access" ON public.wallets;

DROP POLICY IF EXISTS "wallet_transactions_admin_full_access" ON public.wallet_transactions;
DROP POLICY IF EXISTS "wallet_transactions_accountant_full_access" ON public.wallet_transactions;
DROP POLICY IF EXISTS "wallet_transactions_owner_read_access" ON public.wallet_transactions;
DROP POLICY IF EXISTS "wallet_transactions_user_own_access" ON public.wallet_transactions;

-- WALLETS TABLE POLICIES

-- Admin: Full access to all wallets
CREATE POLICY "wallets_admin_full_access" ON public.wallets
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'admin'
            AND status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'admin'
            AND status = 'approved'
        )
    );

-- Accountant: Full access to all wallets (same as admin for financial operations)
CREATE POLICY "wallets_accountant_full_access" ON public.wallets
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'accountant'
            AND status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'accountant'
            AND status = 'approved'
        )
    );

-- Owner: Read-only access to all wallets
CREATE POLICY "wallets_owner_read_access" ON public.wallets
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'owner'
            AND status = 'approved'
        )
    );

-- Workers and Clients: Access only to their own wallet
CREATE POLICY "wallets_user_own_access" ON public.wallets
    FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role IN ('worker', 'client')
            AND status = 'approved'
        )
    );

-- WALLET_TRANSACTIONS TABLE POLICIES

-- Admin: Full access to all transactions
CREATE POLICY "wallet_transactions_admin_full_access" ON public.wallet_transactions
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'admin'
            AND status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'admin'
            AND status = 'approved'
        )
    );

-- Accountant: Full access to all transactions (same as admin for financial operations)
CREATE POLICY "wallet_transactions_accountant_full_access" ON public.wallet_transactions
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'accountant'
            AND status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'accountant'
            AND status = 'approved'
        )
    );

-- Owner: Read-only access to all transactions
CREATE POLICY "wallet_transactions_owner_read_access" ON public.wallet_transactions
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'owner'
            AND status = 'approved'
        )
    );

-- Workers and Clients: Access only to their own transactions
CREATE POLICY "wallet_transactions_user_own_access" ON public.wallet_transactions
    FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role IN ('worker', 'client')
            AND status = 'approved'
        )
    );

-- Additional policy for users to see transactions where they are the creator (for admin/accountant actions)
CREATE POLICY "wallet_transactions_creator_access" ON public.wallet_transactions
    FOR SELECT
    TO authenticated
    USING (
        created_by = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND status = 'approved'
        )
    );

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wallets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wallet_transactions TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Create view for wallet summary (for easier querying)
CREATE OR REPLACE VIEW public.wallet_summary AS
SELECT
    w.id,
    w.user_id,
    up.name as user_name,
    up.email as user_email,
    up.phone_number,
    w.role,
    w.balance,
    w.currency,
    w.status,
    w.created_at,
    w.updated_at,
    (
        SELECT COUNT(*)
        FROM public.wallet_transactions wt
        WHERE wt.wallet_id = w.id
    ) as transaction_count,
    (
        SELECT MAX(wt.created_at)
        FROM public.wallet_transactions wt
        WHERE wt.wallet_id = w.id
    ) as last_transaction_date
FROM public.wallets w
JOIN public.user_profiles up ON w.user_id = up.id;

-- Grant access to the view
GRANT SELECT ON public.wallet_summary TO authenticated;

-- Note: RLS policies cannot be applied to views in PostgreSQL
-- Access control for the view is handled through the underlying tables' RLS policies
