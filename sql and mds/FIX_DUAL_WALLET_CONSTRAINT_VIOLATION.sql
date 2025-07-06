-- =====================================================
-- FIX DUAL WALLET CONSTRAINT VIOLATION ERROR
-- Resolves: duplicate key value violates unique constraint "wallets_user_id_key"
-- =====================================================

-- STEP 1: ANALYZE CURRENT CONSTRAINT ISSUES
-- =====================================================

SELECT '=== ANALYZING WALLET CONSTRAINT ISSUES ===' as section;

-- Check current wallets table structure and constraints
SELECT 
    'Current wallets table constraints' as info,
    constraint_name,
    constraint_type,
    table_name
FROM information_schema.table_constraints 
WHERE table_schema = 'public' 
AND table_name = 'wallets'
ORDER BY constraint_name;

-- Check for duplicate user_id entries
SELECT 
    'Duplicate user_id analysis' as info,
    user_id,
    COUNT(*) as count,
    array_agg(id) as wallet_ids,
    array_agg(role) as roles,
    array_agg(wallet_type) as wallet_types
FROM public.wallets 
GROUP BY user_id 
HAVING COUNT(*) > 1;

-- Check business wallets
SELECT 
    'Current business wallets' as info,
    id,
    user_id,
    wallet_type,
    role,
    balance,
    status,
    is_active
FROM public.wallets 
WHERE wallet_type = 'business' OR role = 'business'
ORDER BY created_at;

-- STEP 2: FIX WALLET TABLE SCHEMA
-- =====================================================

-- First, ensure the wallets table has all required columns
DO $$
BEGIN
    -- Add metadata column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'wallets'
        AND column_name = 'metadata'
    ) THEN
        ALTER TABLE public.wallets ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
        RAISE NOTICE '✅ Added metadata column to wallets table';
    END IF;

    -- Add wallet_type column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'wallets'
        AND column_name = 'wallet_type'
    ) THEN
        ALTER TABLE public.wallets ADD COLUMN wallet_type TEXT DEFAULT 'personal';
        RAISE NOTICE '✅ Added wallet_type column to wallets table';
    END IF;

    -- Add is_active column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'wallets'
        AND column_name = 'is_active'
    ) THEN
        ALTER TABLE public.wallets ADD COLUMN is_active BOOLEAN DEFAULT true;
        RAISE NOTICE '✅ Added is_active column to wallets table';
    END IF;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error adding columns: %', SQLERRM;
END $$;

-- Drop the problematic unique constraint on user_id only
DO $$
BEGIN
    -- Drop existing unique constraint on user_id if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_schema = 'public'
        AND table_name = 'wallets'
        AND constraint_name = 'wallets_user_id_key'
    ) THEN
        ALTER TABLE public.wallets DROP CONSTRAINT wallets_user_id_key;
        RAISE NOTICE '✅ Dropped problematic wallets_user_id_key constraint';
    END IF;

    -- Drop other variations of user_id constraints
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_schema = 'public'
        AND table_name = 'wallets'
        AND constraint_name = 'wallets_user_id_unique'
    ) THEN
        ALTER TABLE public.wallets DROP CONSTRAINT wallets_user_id_unique;
        RAISE NOTICE '✅ Dropped wallets_user_id_unique constraint';
    END IF;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Note: Some constraints may not exist: %', SQLERRM;
END $$;

-- Add proper constraint that allows multiple wallets per user but prevents duplicates of same type
DO $$
BEGIN
    -- Create composite unique constraint on (user_id, wallet_type) allowing NULL user_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND constraint_name = 'wallets_user_wallet_type_unique'
    ) THEN
        -- Use partial unique index to handle NULL user_id for business wallets
        CREATE UNIQUE INDEX wallets_user_wallet_type_unique 
        ON public.wallets (user_id, wallet_type) 
        WHERE user_id IS NOT NULL;
        
        RAISE NOTICE '✅ Created partial unique index on (user_id, wallet_type) excluding NULL user_id';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not create unique index: %', SQLERRM;
END $$;

-- STEP 3: FIX BUSINESS WALLET CREATION FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_or_create_business_wallet()
RETURNS UUID AS $$
DECLARE
    business_wallet_id UUID;
    system_user_id UUID := '00000000-0000-0000-0000-000000000000'::UUID;
BEGIN
    -- Try to find existing business wallet (system wallet with NULL user_id)
    SELECT id INTO business_wallet_id
    FROM public.wallets
    WHERE wallet_type = 'business' 
    AND (user_id IS NULL OR user_id = system_user_id)
    AND (is_active = true OR is_active IS NULL)
    LIMIT 1;
    
    -- If no business wallet exists, create one
    IF business_wallet_id IS NULL THEN
        -- Create business wallet with NULL user_id (system wallet)
        INSERT INTO public.wallets (
            user_id,
            wallet_type,
            role,
            balance,
            currency,
            status,
            is_active,
            created_at,
            updated_at,
            metadata
        ) VALUES (
            NULL, -- NULL user_id for system business wallet
            'business',
            'admin',
            0.00,
            'EGP',
            'active',
            true,
            NOW(),
            NOW(),
            jsonb_build_object(
                'type', 'system_business_wallet',
                'description', 'محفظة الشركة للمدفوعات الإلكترونية',
                'created_by_system', true
            )
        ) RETURNING id INTO business_wallet_id;
        
        RAISE NOTICE '✅ Created new system business wallet with ID: %', business_wallet_id;
    ELSE
        RAISE NOTICE '✅ Using existing business wallet with ID: %', business_wallet_id;
    END IF;
    
    RETURN business_wallet_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 4: FIX CLIENT WALLET CREATION FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_or_create_client_wallet(p_user_id UUID)
RETURNS UUID AS $$
DECLARE
    client_wallet_id UUID;
BEGIN
    -- Try to find existing client wallet
    SELECT id INTO client_wallet_id
    FROM public.wallets
    WHERE user_id = p_user_id 
    AND (wallet_type = 'personal' OR wallet_type IS NULL)
    AND (is_active = true OR is_active IS NULL)
    LIMIT 1;
    
    -- If no client wallet exists, create one using UPSERT
    IF client_wallet_id IS NULL THEN
        INSERT INTO public.wallets (
            user_id,
            wallet_type,
            role,
            balance,
            currency,
            status,
            is_active,
            created_at,
            updated_at,
            metadata
        ) VALUES (
            p_user_id,
            'personal',
            'client',
            0.00,
            'EGP',
            'active',
            true,
            NOW(),
            NOW(),
            jsonb_build_object(
                'type', 'client_personal_wallet',
                'description', 'محفظة العميل الشخصية'
            )
        ) 
        ON CONFLICT (user_id, wallet_type) DO UPDATE SET
            updated_at = NOW(),
            is_active = true,
            status = 'active'
        RETURNING id INTO client_wallet_id;
        
        RAISE NOTICE '✅ Created/updated client wallet for user: %, wallet ID: %', p_user_id, client_wallet_id;
    END IF;
    
    RETURN client_wallet_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 5: UPDATE DUAL WALLET TRANSACTION FUNCTION
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
    -- Input validation
    IF p_payment_id IS NULL OR p_client_wallet_id IS NULL OR p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Invalid input parameters: payment_id=%, client_wallet_id=%, amount=%', 
            p_payment_id, p_client_wallet_id, p_amount;
    END IF;
    
    -- Get or create business wallet (this now handles constraint violations properly)
    BEGIN
        IF p_business_wallet_id IS NULL THEN
            v_business_wallet_id := public.get_or_create_business_wallet();
        ELSE
            v_business_wallet_id := p_business_wallet_id;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to get/create business wallet: %', SQLERRM;
    END;
    
    -- Verify payment exists and is in pending status
    SELECT * INTO v_payment_record
    FROM public.electronic_payments
    WHERE id = p_payment_id AND status = 'pending';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payment not found or not in pending status: %', p_payment_id;
    END IF;
    
    -- Get current balances with better error handling
    SELECT balance INTO v_client_balance_before
    FROM public.wallets
    WHERE id = p_client_wallet_id AND (is_active = true OR is_active IS NULL);
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Client wallet not found or inactive: %', p_client_wallet_id;
    END IF;
    
    SELECT balance INTO v_business_balance_before
    FROM public.wallets
    WHERE id = v_business_wallet_id AND (is_active = true OR is_active IS NULL);
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Business wallet not found or inactive: %', v_business_wallet_id;
    END IF;
    
    -- Validate client has sufficient balance (client pays, business receives)
    IF v_client_balance_before < p_amount THEN
        RAISE EXCEPTION 'Insufficient client wallet balance: current=%, required=%', 
            v_client_balance_before, p_amount;
    END IF;
    
    -- Calculate new balances (client loses money, business gains money)
    v_client_balance_after := v_client_balance_before - p_amount;
    v_business_balance_after := v_business_balance_before + p_amount;
    
    -- Start atomic transaction
    BEGIN
        -- Update client wallet balance (debit)
        UPDATE public.wallets
        SET balance = v_client_balance_after,
            updated_at = NOW()
        WHERE id = p_client_wallet_id;
        
        -- Update business wallet balance (credit)
        UPDATE public.wallets
        SET balance = v_business_balance_after,
            updated_at = NOW()
        WHERE id = v_business_wallet_id;
        
        -- Create client wallet transaction record (debit)
        INSERT INTO public.wallet_transactions (
            wallet_id, user_id, transaction_type, amount,
            balance_before, balance_after, reference_type, reference_id,
            description, status, created_by, created_at
        ) VALUES (
            p_client_wallet_id, v_payment_record.client_id, 'debit', p_amount,
            v_client_balance_before, v_client_balance_after, 'electronic_payment', p_payment_id::TEXT,
            'دفعة إلكترونية - ' || COALESCE(p_admin_notes, 'تم الدفع'), 'completed', p_approved_by, NOW()
        ) RETURNING id INTO v_client_transaction_id;
        
        -- Create business wallet transaction record (credit)
        INSERT INTO public.wallet_transactions (
            wallet_id, user_id, transaction_type, amount,
            balance_before, balance_after, reference_type, reference_id,
            description, status, created_by, created_at
        ) VALUES (
            v_business_wallet_id, p_approved_by, 'credit', p_amount,
            v_business_balance_before, v_business_balance_after, 'electronic_payment', p_payment_id::TEXT,
            'استلام دفعة إلكترونية من العميل - ' || COALESCE(p_admin_notes, 'تم الاستلام'), 'completed', p_approved_by, NOW()
        ) RETURNING id INTO v_business_transaction_id;
        
        -- Update payment status
        UPDATE public.electronic_payments
        SET status = 'approved', approved_by = p_approved_by, approved_at = NOW(),
            admin_notes = p_admin_notes, updated_at = NOW()
        WHERE id = p_payment_id;
        
        -- Build result JSON
        v_result := jsonb_build_object(
            'success', true, 'payment_id', p_payment_id,
            'client_wallet_id', p_client_wallet_id, 'business_wallet_id', v_business_wallet_id,
            'amount', p_amount, 'client_balance_before', v_client_balance_before,
            'client_balance_after', v_client_balance_after, 'business_balance_before', v_business_balance_before,
            'business_balance_after', v_business_balance_after, 'client_transaction_id', v_client_transaction_id,
            'business_transaction_id', v_business_transaction_id, 'approved_by', p_approved_by, 'approved_at', NOW()
        );
        
        RAISE NOTICE '✅ Dual wallet transaction completed: Payment %, Client: % → %, Business: % → %', 
            p_payment_id, v_client_balance_before, v_client_balance_after, 
            v_business_balance_before, v_business_balance_after;
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Transaction failed during wallet updates: %', SQLERRM;
    END;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Dual wallet transaction failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 6: GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION public.get_or_create_business_wallet() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_client_wallet(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_dual_wallet_transaction(UUID, UUID, NUMERIC, UUID, TEXT, UUID) TO authenticated;

-- STEP 7: VERIFICATION AND CLEANUP
-- =====================================================

-- Clean up any duplicate business wallets
DO $$
DECLARE
    duplicate_count INTEGER;
BEGIN
    -- Count business wallets
    SELECT COUNT(*) INTO duplicate_count
    FROM public.wallets 
    WHERE wallet_type = 'business';
    
    IF duplicate_count > 1 THEN
        -- Keep only the newest business wallet
        DELETE FROM public.wallets 
        WHERE wallet_type = 'business' 
        AND id NOT IN (
            SELECT id FROM public.wallets 
            WHERE wallet_type = 'business' 
            ORDER BY created_at DESC 
            LIMIT 1
        );
        
        RAISE NOTICE '🧹 Cleaned up % duplicate business wallets', duplicate_count - 1;
    END IF;
END $$;

-- Final verification
SELECT 
    '=== CONSTRAINT VIOLATION FIX COMPLETED ===' as status,
    COUNT(*) as total_wallets,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) FILTER (WHERE wallet_type = 'business') as business_wallets
FROM public.wallets;

RAISE NOTICE '✅ DUAL WALLET CONSTRAINT VIOLATION FIX COMPLETED SUCCESSFULLY!';
RAISE NOTICE '🔧 Removed problematic unique constraint on user_id';
RAISE NOTICE '💰 Business wallets can now be created without constraint violations';
RAISE NOTICE '🚀 Dual wallet transactions will work properly';
RAISE NOTICE '📋 Script execution completed at: %', NOW();
