-- =====================================================
-- CLEAN DUAL WALLET TRANSACTION FUNCTION FOR SUPABASE
-- =====================================================
-- Execute this script in Supabase SQL Editor
-- No Markdown formatting - Pure SQL only
-- Handles existing function conflicts and missing columns

-- =====================================================
-- 0. HANDLE EXISTING FUNCTION CONFLICTS
-- =====================================================

-- Drop existing get_wallet_balance function if it exists to avoid parameter conflicts
DROP FUNCTION IF EXISTS public.get_wallet_balance(uuid);
DROP FUNCTION IF EXISTS public.get_wallet_balance(UUID);

-- =====================================================
-- 1. ENSURE WALLETS TABLE HAS REQUIRED COLUMNS
-- =====================================================

-- Add is_active column to wallets table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'wallets'
        AND column_name = 'is_active'
    ) THEN
        ALTER TABLE public.wallets ADD COLUMN is_active BOOLEAN DEFAULT true NOT NULL;
        RAISE NOTICE 'Added is_active column to wallets table';
    ELSE
        RAISE NOTICE 'is_active column already exists in wallets table';
    END IF;
END $$;

-- Add wallet_type column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'wallets'
        AND column_name = 'wallet_type'
    ) THEN
        ALTER TABLE public.wallets ADD COLUMN wallet_type TEXT DEFAULT 'user' NOT NULL;
        RAISE NOTICE 'Added wallet_type column to wallets table';
    ELSE
        RAISE NOTICE 'wallet_type column already exists in wallets table';
    END IF;
END $$;

-- =====================================================
-- 2. CREATE WALLET TRANSACTIONS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('credit', 'debit', 'transfer_in', 'transfer_out')),
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    balance_before DECIMAL(15,2) NOT NULL,
    balance_after DECIMAL(15,2) NOT NULL,
    reference_type TEXT NOT NULL CHECK (reference_type IN ('electronic_payment', 'manual_adjustment', 'order_payment', 'refund')),
    reference_id UUID,
    description TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON public.wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_reference ON public.wallet_transactions(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON public.wallet_transactions(created_at);

-- Enable RLS
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies with fallback for missing user_profiles table
DROP POLICY IF EXISTS "Wallet transactions viewable by wallet owner and admins" ON public.wallet_transactions;

-- Check if user_profiles table exists and create appropriate policy
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'user_profiles'
    ) THEN
        -- Policy with user_profiles table
        EXECUTE 'CREATE POLICY "Wallet transactions viewable by wallet owner and admins"
        ON public.wallet_transactions FOR SELECT
        USING (
            EXISTS (
                SELECT 1 FROM public.wallets w
                WHERE w.id = wallet_id
                AND (w.user_id = auth.uid() OR EXISTS (
                    SELECT 1 FROM public.user_profiles up
                    WHERE up.id = auth.uid()
                    AND up.role IN (''admin'', ''accountant'')
                ))
            )
        )';
        RAISE NOTICE 'Created RLS policy with user_profiles table';
    ELSE
        -- Simplified policy without user_profiles table
        EXECUTE 'CREATE POLICY "Wallet transactions viewable by wallet owner and admins"
        ON public.wallet_transactions FOR SELECT
        USING (
            EXISTS (
                SELECT 1 FROM public.wallets w
                WHERE w.id = wallet_id
                AND w.user_id = auth.uid()
            )
        )';
        RAISE NOTICE 'Created simplified RLS policy without user_profiles table';
    END IF;
END $$;

DROP POLICY IF EXISTS "Admins can manage wallet transactions" ON public.wallet_transactions;

-- Create admin policy with fallback
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'user_profiles'
    ) THEN
        -- Policy with user_profiles table
        EXECUTE 'CREATE POLICY "Admins can manage wallet transactions"
        ON public.wallet_transactions FOR ALL
        USING (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid()
                AND role IN (''admin'', ''accountant'')
            )
        )';
    ELSE
        -- Allow all authenticated users if no user_profiles table
        EXECUTE 'CREATE POLICY "Admins can manage wallet transactions"
        ON public.wallet_transactions FOR ALL
        USING (auth.uid() IS NOT NULL)';
        RAISE NOTICE 'Created permissive admin policy - no user_profiles table found';
    END IF;
END $$;

-- =====================================================
-- 2. CREATE BUSINESS WALLET FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_or_create_business_wallet()
RETURNS UUID AS $$
DECLARE
    business_wallet_id UUID;
BEGIN
    SELECT id INTO business_wallet_id
    FROM public.wallets
    WHERE wallet_type = 'business'
    LIMIT 1;
    
    IF business_wallet_id IS NULL THEN
        INSERT INTO public.wallets (
            user_id,
            wallet_type,
            balance,
            currency,
            is_active,
            created_at,
            updated_at
        ) VALUES (
            NULL,
            'business',
            0.00,
            'EGP',
            true,
            NOW(),
            NOW()
        ) RETURNING id INTO business_wallet_id;
    END IF;
    
    RETURN business_wallet_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 3. CREATE VALIDATION FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.validate_payment_approval(
    p_payment_id UUID,
    p_client_wallet_id UUID,
    p_amount NUMERIC
)
RETURNS JSON AS $$
DECLARE
    v_payment RECORD;
    v_client_balance DECIMAL(15,2);
BEGIN
    SELECT * INTO v_payment
    FROM public.electronic_payments
    WHERE id = p_payment_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Payment not found'
        );
    END IF;
    
    IF v_payment.status != 'pending' THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Payment is not in pending status'
        );
    END IF;
    
    IF v_payment.amount != p_amount THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Amount mismatch'
        );
    END IF;
    
    -- Get client balance with fallback for missing is_active column
    BEGIN
        SELECT balance INTO v_client_balance
        FROM public.wallets
        WHERE id = p_client_wallet_id AND is_active = true;
    EXCEPTION
        WHEN undefined_column THEN
            -- Fallback if is_active column doesn't exist
            SELECT balance INTO v_client_balance
            FROM public.wallets
            WHERE id = p_client_wallet_id;
    END;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Client wallet not found or inactive'
        );
    END IF;
    
    IF v_client_balance < p_amount THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Insufficient balance',
            'available_balance', v_client_balance,
            'required_amount', p_amount
        );
    END IF;
    
    RETURN jsonb_build_object(
        'valid', true,
        'payment', row_to_json(v_payment),
        'client_balance', v_client_balance
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. CREATE MAIN DUAL WALLET TRANSACTION FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.process_dual_wallet_transaction(
    p_payment_id UUID,
    p_client_wallet_id UUID,
    p_amount NUMERIC,
    p_approved_by UUID,
    p_admin_notes TEXT DEFAULT NULL,
    p_business_wallet_id UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_client_balance_before DECIMAL(15,2);
    v_client_balance_after DECIMAL(15,2);
    v_business_balance_before DECIMAL(15,2);
    v_business_balance_after DECIMAL(15,2);
    v_business_wallet_id UUID;
    v_client_transaction_id UUID;
    v_business_transaction_id UUID;
    v_payment_record RECORD;
    v_result JSON;
BEGIN
    IF p_payment_id IS NULL OR p_client_wallet_id IS NULL OR p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Invalid input parameters: payment_id=%, client_wallet_id=%, amount=%', 
            p_payment_id, p_client_wallet_id, p_amount;
    END IF;
    
    IF p_business_wallet_id IS NULL THEN
        v_business_wallet_id := public.get_or_create_business_wallet();
    ELSE
        v_business_wallet_id := p_business_wallet_id;
    END IF;
    
    SELECT * INTO v_payment_record
    FROM public.electronic_payments
    WHERE id = p_payment_id AND status = 'pending';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payment not found or not in pending status: %', p_payment_id;
    END IF;
    
    IF v_payment_record.amount != p_amount THEN
        RAISE EXCEPTION 'Payment amount mismatch: expected %, got %', v_payment_record.amount, p_amount;
    END IF;
    
    -- Lock and get client wallet balance with fallback for missing is_active column
    BEGIN
        SELECT balance INTO v_client_balance_before
        FROM public.wallets
        WHERE id = p_client_wallet_id AND is_active = true
        FOR UPDATE;
    EXCEPTION
        WHEN undefined_column THEN
            -- Fallback if is_active column doesn't exist
            SELECT balance INTO v_client_balance_before
            FROM public.wallets
            WHERE id = p_client_wallet_id
            FOR UPDATE;
    END;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Client wallet not found or inactive: %', p_client_wallet_id;
    END IF;

    IF v_client_balance_before < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance: available %, required %', v_client_balance_before, p_amount;
    END IF;

    -- Lock and get business wallet balance with fallback for missing is_active column
    BEGIN
        SELECT balance INTO v_business_balance_before
        FROM public.wallets
        WHERE id = v_business_wallet_id AND is_active = true
        FOR UPDATE;
    EXCEPTION
        WHEN undefined_column THEN
            -- Fallback if is_active column doesn't exist
            SELECT balance INTO v_business_balance_before
            FROM public.wallets
            WHERE id = v_business_wallet_id
            FOR UPDATE;
    END;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Business wallet not found or inactive: %', v_business_wallet_id;
    END IF;
    
    v_client_balance_after := v_client_balance_before - p_amount;
    v_business_balance_after := v_business_balance_before + p_amount;
    
    UPDATE public.wallets
    SET 
        balance = v_client_balance_after,
        updated_at = NOW()
    WHERE id = p_client_wallet_id;
    
    UPDATE public.wallets
    SET 
        balance = v_business_balance_after,
        updated_at = NOW()
    WHERE id = v_business_wallet_id;
    
    INSERT INTO public.wallet_transactions (
        wallet_id,
        transaction_type,
        amount,
        balance_before,
        balance_after,
        reference_type,
        reference_id,
        description,
        metadata,
        created_by
    ) VALUES (
        p_client_wallet_id,
        'debit',
        p_amount,
        v_client_balance_before,
        v_client_balance_after,
        'electronic_payment',
        p_payment_id,
        'Electronic payment approval - amount deducted',
        jsonb_build_object(
            'payment_id', p_payment_id,
            'approved_by', p_approved_by,
            'business_wallet_id', v_business_wallet_id,
            'admin_notes', COALESCE(p_admin_notes, '')
        ),
        p_approved_by
    ) RETURNING id INTO v_client_transaction_id;
    
    INSERT INTO public.wallet_transactions (
        wallet_id,
        transaction_type,
        amount,
        balance_before,
        balance_after,
        reference_type,
        reference_id,
        description,
        metadata,
        created_by
    ) VALUES (
        v_business_wallet_id,
        'credit',
        p_amount,
        v_business_balance_before,
        v_business_balance_after,
        'electronic_payment',
        p_payment_id,
        'Electronic payment approval - amount received',
        jsonb_build_object(
            'payment_id', p_payment_id,
            'approved_by', p_approved_by,
            'client_wallet_id', p_client_wallet_id,
            'admin_notes', COALESCE(p_admin_notes, '')
        ),
        p_approved_by
    ) RETURNING id INTO v_business_transaction_id;
    
    UPDATE public.electronic_payments
    SET 
        status = 'approved',
        approved_by = p_approved_by,
        approved_at = NOW(),
        admin_notes = COALESCE(p_admin_notes, admin_notes),
        updated_at = NOW()
    WHERE id = p_payment_id;
    
    v_result := jsonb_build_object(
        'success', true,
        'payment_id', p_payment_id,
        'amount', p_amount,
        'client_wallet_id', p_client_wallet_id,
        'business_wallet_id', v_business_wallet_id,
        'client_balance_before', v_client_balance_before,
        'client_balance_after', v_client_balance_after,
        'business_balance_before', v_business_balance_before,
        'business_balance_after', v_business_balance_after,
        'client_transaction_id', v_client_transaction_id,
        'business_transaction_id', v_business_transaction_id,
        'approved_by', p_approved_by,
        'approved_at', NOW()
    );
    
    RETURN v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Dual wallet transaction failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. CREATE HELPER FUNCTION FOR WALLET BALANCE
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_wallet_balance(p_wallet_id UUID)
RETURNS DECIMAL(15,2) AS $$
DECLARE
    v_balance DECIMAL(15,2);
BEGIN
    -- Try with is_active column first, fallback if column doesn't exist
    BEGIN
        SELECT balance INTO v_balance
        FROM public.wallets
        WHERE id = p_wallet_id AND is_active = true;
    EXCEPTION
        WHEN undefined_column THEN
            -- Fallback if is_active column doesn't exist
            SELECT balance INTO v_balance
            FROM public.wallets
            WHERE id = p_wallet_id;
    END;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Wallet not found or inactive: %', p_wallet_id;
    END IF;

    RETURN v_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION public.process_dual_wallet_transaction(UUID, UUID, NUMERIC, UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_business_wallet() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_wallet_balance(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_payment_approval(UUID, UUID, NUMERIC) TO authenticated;

GRANT SELECT, INSERT, UPDATE ON public.wallet_transactions TO authenticated;
GRANT SELECT, UPDATE ON public.wallets TO authenticated;
GRANT SELECT, UPDATE ON public.electronic_payments TO authenticated;

-- =====================================================
-- 7. VERIFICATION
-- =====================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'process_dual_wallet_transaction'
    ) THEN
        RAISE NOTICE 'SUCCESS: process_dual_wallet_transaction function created';
    ELSE
        RAISE NOTICE 'ERROR: process_dual_wallet_transaction function not found';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'wallet_transactions'
    ) THEN
        RAISE NOTICE 'SUCCESS: wallet_transactions table exists';
    ELSE
        RAISE NOTICE 'ERROR: wallet_transactions table not found';
    END IF;
END $$;
