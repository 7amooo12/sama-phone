-- =====================================================
-- FIX DUAL WALLET FUNCTION SIGNATURE ISSUE
-- =====================================================
-- This script fixes the process_dual_wallet_transaction function
-- to use the correct parameter signature and logic

-- Step 1: Check current function signature
DO $$
DECLARE
    function_exists BOOLEAN;
    function_count INTEGER;
BEGIN
    RAISE NOTICE '🔍 Checking current function signature...';
    
    -- Check if function exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_schema = 'public' 
        AND routine_name = 'process_dual_wallet_transaction'
    ) INTO function_exists;
    
    IF function_exists THEN
        -- Count how many versions exist
        SELECT COUNT(*) INTO function_count
        FROM information_schema.routines 
        WHERE routine_schema = 'public' 
        AND routine_name = 'process_dual_wallet_transaction';
        
        RAISE NOTICE '📋 Found % version(s) of process_dual_wallet_transaction function', function_count;
        
        -- Show function signatures
        FOR function_signature IN
            SELECT oid::regprocedure::text as signature
            FROM pg_proc
            WHERE proname = 'process_dual_wallet_transaction'
            AND pronamespace = 'public'::regnamespace
        LOOP
            RAISE NOTICE '   - %', function_signature.signature;
        END LOOP;
    ELSE
        RAISE NOTICE '❌ Function does not exist';
    END IF;
END $$;

-- Step 2: Drop all existing versions of the function
DO $$
BEGIN
    RAISE NOTICE '🗑️  Dropping all existing versions of process_dual_wallet_transaction...';
    
    -- Drop all overloaded versions
    DROP FUNCTION IF EXISTS public.process_dual_wallet_transaction(UUID, UUID, NUMERIC, UUID, TEXT, UUID);
    DROP FUNCTION IF EXISTS public.process_dual_wallet_transaction(UUID, UUID, DECIMAL, TEXT, TEXT, UUID);
    DROP FUNCTION IF EXISTS public.process_dual_wallet_transaction(UUID, UUID, DECIMAL(10,2), TEXT, TEXT, UUID);
    
    RAISE NOTICE '✅ Dropped existing function versions';
END $$;

-- Step 3: Create the correct function with proper signature
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
    -- Start transaction
    RAISE NOTICE 'Starting dual wallet transaction for payment: %, amount: %', p_payment_id, p_amount;
    
    -- Validate input parameters
    IF p_payment_id IS NULL OR p_client_wallet_id IS NULL OR p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Invalid input parameters: payment_id=%, client_wallet_id=%, amount=%', 
            p_payment_id, p_client_wallet_id, p_amount;
    END IF;
    
    -- Get or create business wallet
    IF p_business_wallet_id IS NULL THEN
        -- Get or create business wallet
        SELECT id INTO v_business_wallet_id
        FROM public.wallets
        WHERE wallet_type = 'business' AND is_active = true
        LIMIT 1;
        
        IF v_business_wallet_id IS NULL THEN
            -- Create business wallet
            INSERT INTO public.wallets (
                wallet_type, balance, currency, is_active, created_at, updated_at
            ) VALUES (
                'business', 0.00, 'EGP', true, NOW(), NOW()
            ) RETURNING id INTO v_business_wallet_id;
            
            RAISE NOTICE 'Created new business wallet: %', v_business_wallet_id;
        END IF;
    ELSE
        v_business_wallet_id := p_business_wallet_id;
    END IF;
    
    -- Verify payment exists and is in pending status
    SELECT * INTO v_payment_record
    FROM public.electronic_payments
    WHERE id = p_payment_id AND status = 'pending';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payment not found or not in pending status: %', p_payment_id;
    END IF;
    
    -- Verify payment amount matches
    IF v_payment_record.amount != p_amount THEN
        RAISE EXCEPTION 'Payment amount mismatch: expected %, got %', v_payment_record.amount, p_amount;
    END IF;
    
    -- Get client wallet balance
    SELECT balance INTO v_client_balance_before
    FROM public.wallets
    WHERE id = p_client_wallet_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Client wallet not found: %', p_client_wallet_id;
    END IF;
    
    -- Check if client has sufficient balance
    IF v_client_balance_before < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance: has %, needs %', v_client_balance_before, p_amount;
    END IF;
    
    -- Get business wallet balance
    SELECT balance INTO v_business_balance_before
    FROM public.wallets
    WHERE id = v_business_wallet_id;
    
    -- Calculate new balances
    v_client_balance_after := v_client_balance_before - p_amount;
    v_business_balance_after := v_business_balance_before + p_amount;
    
    -- Update client wallet balance (debit)
    UPDATE public.wallets
    SET balance = v_client_balance_after, updated_at = NOW()
    WHERE id = p_client_wallet_id;
    
    -- Update business wallet balance (credit)
    UPDATE public.wallets
    SET balance = v_business_balance_after, updated_at = NOW()
    WHERE id = v_business_wallet_id;
    
    -- Create client wallet transaction record (debit)
    INSERT INTO public.wallet_transactions (
        wallet_id,
        user_id,
        transaction_type,
        amount,
        balance_before,
        balance_after,
        reference_type,
        reference_id,
        description,
        status,
        created_by,
        created_at
    ) VALUES (
        p_client_wallet_id,
        v_payment_record.client_id,
        'debit',
        p_amount,
        v_client_balance_before,
        v_client_balance_after,
        'electronic_payment',
        p_payment_id::TEXT,
        'Electronic payment approval - ' || COALESCE(p_admin_notes, 'Payment approved'),
        'completed',
        p_approved_by,
        NOW()
    ) RETURNING id INTO v_client_transaction_id;
    
    -- Create business wallet transaction record (credit)
    INSERT INTO public.wallet_transactions (
        wallet_id,
        user_id,
        transaction_type,
        amount,
        balance_before,
        balance_after,
        reference_type,
        reference_id,
        description,
        status,
        created_by,
        created_at
    ) VALUES (
        v_business_wallet_id,
        p_approved_by,
        'credit',
        p_amount,
        v_business_balance_before,
        v_business_balance_after,
        'electronic_payment',
        p_payment_id::TEXT,
        'Electronic payment received from client - ' || COALESCE(p_admin_notes, 'Payment received'),
        'completed',
        p_approved_by,
        NOW()
    ) RETURNING id INTO v_business_transaction_id;
    
    -- Update payment status to approved
    UPDATE public.electronic_payments
    SET 
        status = 'approved',
        approved_by = p_approved_by,
        approved_at = NOW(),
        admin_notes = COALESCE(p_admin_notes, 'Payment approved'),
        updated_at = NOW()
    WHERE id = p_payment_id;
    
    -- Build result
    v_result := jsonb_build_object(
        'success', true,
        'payment_id', p_payment_id,
        'client_wallet_id', p_client_wallet_id,
        'business_wallet_id', v_business_wallet_id,
        'amount', p_amount,
        'client_balance_before', v_client_balance_before,
        'client_balance_after', v_client_balance_after,
        'business_balance_before', v_business_balance_before,
        'business_balance_after', v_business_balance_after,
        'client_transaction_id', v_client_transaction_id,
        'business_transaction_id', v_business_transaction_id,
        'approved_by', p_approved_by,
        'approved_at', NOW()
    );
    
    RAISE NOTICE 'Dual wallet transaction completed successfully: %', v_result;
    
    RETURN v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Dual wallet transaction failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Verify the function was created correctly
DO $$
DECLARE
    function_signature TEXT;
BEGIN
    RAISE NOTICE '🔍 Verifying function creation...';
    
    -- Get function signature
    SELECT oid::regprocedure::text INTO function_signature
    FROM pg_proc 
    WHERE proname = 'process_dual_wallet_transaction' 
    AND pronamespace = 'public'::regnamespace;
    
    IF function_signature IS NOT NULL THEN
        RAISE NOTICE '✅ Function created successfully: %', function_signature;
    ELSE
        RAISE EXCEPTION 'Function creation failed';
    END IF;
END $$;

-- Final summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎯 DUAL WALLET FUNCTION FIX COMPLETED!';
    RAISE NOTICE '✅ Dropped old function versions with incorrect signatures';
    RAISE NOTICE '✅ Created new function with correct parameter signature';
    RAISE NOTICE '✅ Function now properly validates payment_id (not client_id)';
    RAISE NOTICE '✅ Function uses electronic_payment reference_type';
    RAISE NOTICE '';
    RAISE NOTICE '💡 Next: Test electronic payment approval in Flutter app';
    RAISE NOTICE '📋 The payment c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca should now process correctly';
END $$;
