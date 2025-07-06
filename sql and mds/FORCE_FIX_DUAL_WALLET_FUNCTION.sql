-- =====================================================
-- FORCE FIX DUAL WALLET FUNCTION (AGGRESSIVE APPROACH)
-- =====================================================
-- This script aggressively removes ALL versions and recreates the function

-- Step 1: Drop ALL possible function signatures
DO $$
DECLARE
    func_record RECORD;
BEGIN
    RAISE NOTICE '🗑️  Dropping ALL versions of process_dual_wallet_transaction...';
    
    -- Drop all existing versions by OID
    FOR func_record IN 
        SELECT oid, oid::regprocedure::text as signature
        FROM pg_proc 
        WHERE proname = 'process_dual_wallet_transaction' 
        AND pronamespace = 'public'::regnamespace
    LOOP
        RAISE NOTICE '   Dropping: %', func_record.signature;
        EXECUTE 'DROP FUNCTION ' || func_record.oid::regprocedure;
    END LOOP;
    
    RAISE NOTICE '✅ All function versions dropped';
END $$;

-- Step 2: Verify no functions remain
DO $$
DECLARE
    remaining_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO remaining_count
    FROM pg_proc 
    WHERE proname = 'process_dual_wallet_transaction' 
    AND pronamespace = 'public'::regnamespace;
    
    IF remaining_count = 0 THEN
        RAISE NOTICE '✅ Confirmed: No remaining function versions';
    ELSE
        RAISE EXCEPTION 'ERROR: Still found % function versions after drop', remaining_count;
    END IF;
END $$;

-- Step 3: Create the correct function with explicit parameter types
CREATE FUNCTION public.process_dual_wallet_transaction(
    p_payment_id UUID,
    p_client_wallet_id UUID,
    p_amount NUMERIC,
    p_approved_by UUID,
    p_admin_notes TEXT DEFAULT NULL,
    p_business_wallet_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
    -- Start transaction with detailed logging
    RAISE NOTICE 'DUAL WALLET TRANSACTION START: payment_id=%, client_wallet_id=%, amount=%', 
        p_payment_id, p_client_wallet_id, p_amount;
    
    -- Validate input parameters
    IF p_payment_id IS NULL OR p_client_wallet_id IS NULL OR p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Invalid input parameters: payment_id=%, client_wallet_id=%, amount=%', 
            p_payment_id, p_client_wallet_id, p_amount;
    END IF;
    
    -- CRITICAL: Verify payment exists and is in pending status using p_payment_id
    RAISE NOTICE 'Looking up payment with ID: %', p_payment_id;
    
    SELECT * INTO v_payment_record
    FROM public.electronic_payments
    WHERE id = p_payment_id AND status = 'pending';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payment not found or not in pending status: %', p_payment_id;
    END IF;
    
    RAISE NOTICE 'Payment found: client_id=%, amount=%, status=%', 
        v_payment_record.client_id, v_payment_record.amount, v_payment_record.status;
    
    -- Verify payment amount matches
    IF v_payment_record.amount != p_amount THEN
        RAISE EXCEPTION 'Payment amount mismatch: expected %, got %', v_payment_record.amount, p_amount;
    END IF;
    
    -- Get or create business wallet
    IF p_business_wallet_id IS NULL THEN
        SELECT id INTO v_business_wallet_id
        FROM public.wallets
        WHERE wallet_type = 'business' AND is_active = true
        LIMIT 1;
        
        IF v_business_wallet_id IS NULL THEN
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
    
    -- Create client wallet transaction record (debit) with electronic_payment reference_type
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
    
    -- Create business wallet transaction record (credit) with electronic_payment reference_type
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
    
    RAISE NOTICE 'DUAL WALLET TRANSACTION SUCCESS: %', v_result;
    
    RETURN v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Dual wallet transaction failed: %', SQLERRM;
END;
$$;

-- Step 4: Verify function creation and signature
DO $$
DECLARE
    function_signature TEXT;
    function_source TEXT;
BEGIN
    RAISE NOTICE '🔍 Verifying new function...';
    
    -- Get function signature
    SELECT oid::regprocedure::text INTO function_signature
    FROM pg_proc 
    WHERE proname = 'process_dual_wallet_transaction' 
    AND pronamespace = 'public'::regnamespace;
    
    -- Get function source
    SELECT prosrc INTO function_source
    FROM pg_proc 
    WHERE proname = 'process_dual_wallet_transaction' 
    AND pronamespace = 'public'::regnamespace;
    
    RAISE NOTICE '✅ Function signature: %', function_signature;
    
    -- Verify it uses correct parameter
    IF function_source LIKE '%WHERE id = p_payment_id%' THEN
        RAISE NOTICE '✅ Function correctly uses p_payment_id for payment lookup';
    ELSE
        RAISE EXCEPTION 'Function does NOT use p_payment_id for payment lookup';
    END IF;
    
    -- Verify it uses electronic_payment reference_type
    IF function_source LIKE '%electronic_payment%' THEN
        RAISE NOTICE '✅ Function uses electronic_payment reference_type';
    ELSE
        RAISE EXCEPTION 'Function does NOT use electronic_payment reference_type';
    END IF;
    
    RAISE NOTICE '🎯 Function is ready for electronic payment processing';
END $$;
