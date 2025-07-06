-- ============================================================================
-- SIMPLE DUAL WALLET SYSTEM TEST
-- ============================================================================
-- This script tests the dual wallet system without relying on auth.users table
-- Uses existing users from the system for testing

BEGIN;

-- Step 1: Test with existing users
DO $$
DECLARE
    test_client_id UUID;
    test_electronic_wallet_id UUID;
    test_payment_id UUID;
    initial_client_balance DECIMAL(10,2) := 1000.00;
    initial_electronic_balance DECIMAL(10,2) := 500.00;
    payment_amount DECIMAL(10,2) := 150.00;
    final_client_balance DECIMAL(10,2);
    final_electronic_balance DECIMAL(10,2);
    client_transaction_count INTEGER;
    electronic_transaction_count INTEGER;
    test_result JSON;
BEGIN
    RAISE NOTICE '=== TESTING DUAL WALLET SYSTEM (SIMPLE) ===';
    
    -- Use an existing user or create a test UUID
    SELECT user_id INTO test_client_id 
    FROM public.wallets 
    WHERE role = 'client' 
    LIMIT 1;
    
    IF test_client_id IS NULL THEN
        -- Create a test UUID if no client wallets exist
        test_client_id := gen_random_uuid();
        RAISE NOTICE 'Using test UUID (no auth.users dependency): %', test_client_id;
        
        -- Create a test client wallet
        INSERT INTO public.wallets (user_id, role, balance, currency, status)
        VALUES (test_client_id, 'client', initial_client_balance, 'EGP', 'active');
    ELSE
        RAISE NOTICE 'Using existing client: %', test_client_id;
        
        -- Update existing wallet balance for testing
        UPDATE public.wallets 
        SET balance = initial_client_balance 
        WHERE user_id = test_client_id;
    END IF;
    
    -- Create test electronic wallet
    INSERT INTO public.electronic_wallets (
        wallet_type, phone_number, wallet_name, current_balance, status
    ) VALUES (
        'vodafone_cash', '01099999999', 'Test Dual Wallet System', initial_electronic_balance, 'active'
    ) RETURNING id INTO test_electronic_wallet_id;
    
    -- Create corresponding payment account
    INSERT INTO public.payment_accounts (
        id, account_type, account_number, account_holder_name, is_active
    ) VALUES (
        test_electronic_wallet_id, 'vodafone_cash', '01099999999', 'Test Dual Wallet System', true
    );
    
    -- Create test electronic payment
    INSERT INTO public.electronic_payments (
        client_id, payment_method, amount, recipient_account_id, status
    ) VALUES (
        test_client_id, 'vodafone_cash', payment_amount, test_electronic_wallet_id, 'pending'
    ) RETURNING id INTO test_payment_id;
    
    RAISE NOTICE 'Test data created:';
    RAISE NOTICE '- Client ID: %', test_client_id;
    RAISE NOTICE '- Electronic Wallet ID: %', test_electronic_wallet_id;
    RAISE NOTICE '- Payment ID: %', test_payment_id;
    RAISE NOTICE '- Initial Client Balance: % EGP', initial_client_balance;
    RAISE NOTICE '- Initial Electronic Balance: % EGP', initial_electronic_balance;
    RAISE NOTICE '- Payment Amount: % EGP', payment_amount;
    
    -- Test 1: Direct function call test
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 1: DIRECT FUNCTION CALL ===';
    
    BEGIN
        SELECT public.process_dual_wallet_transaction(
            test_client_id,
            test_electronic_wallet_id,
            payment_amount,
            test_payment_id::TEXT,
            'Test dual wallet transaction',
            test_client_id
        ) INTO test_result;
        
        RAISE NOTICE '✅ Direct function call succeeded: %', test_result;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Direct function call failed: %', SQLERRM;
    END;
    
    -- Reset balances for trigger test
    UPDATE public.wallets 
    SET balance = initial_client_balance 
    WHERE user_id = test_client_id;
    
    UPDATE public.electronic_wallets 
    SET current_balance = initial_electronic_balance 
    WHERE id = test_electronic_wallet_id;
    
    -- Test 2: Trigger-based approval test
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 2: TRIGGER-BASED APPROVAL ===';
    
    BEGIN
        -- Approve the payment (this should trigger the dual wallet transaction)
        UPDATE public.electronic_payments 
        SET 
            status = 'approved',
            approved_by = test_client_id,
            approved_at = now()
        WHERE id = test_payment_id;
        
        RAISE NOTICE '✅ Payment approval trigger executed successfully';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Payment approval trigger failed: %', SQLERRM;
    END;
    
    -- Check final balances
    SELECT balance INTO final_client_balance 
    FROM public.wallets 
    WHERE user_id = test_client_id;
    
    SELECT current_balance INTO final_electronic_balance 
    FROM public.electronic_wallets 
    WHERE id = test_electronic_wallet_id;
    
    -- Check transaction records
    SELECT COUNT(*) INTO client_transaction_count 
    FROM public.wallet_transactions wt
    JOIN public.wallets w ON wt.wallet_id = w.id
    WHERE w.user_id = test_client_id 
    AND wt.reference_id = test_payment_id::TEXT;
    
    SELECT COUNT(*) INTO electronic_transaction_count 
    FROM public.electronic_wallet_transactions 
    WHERE wallet_id = test_electronic_wallet_id 
    AND payment_id = test_payment_id::TEXT;
    
    -- Validate results
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST RESULTS ===';
    RAISE NOTICE 'Expected Client Balance: % EGP', initial_client_balance - payment_amount;
    RAISE NOTICE 'Actual Client Balance: % EGP', final_client_balance;
    RAISE NOTICE 'Expected Electronic Balance: % EGP', initial_electronic_balance + payment_amount;
    RAISE NOTICE 'Actual Electronic Balance: % EGP', final_electronic_balance;
    RAISE NOTICE 'Client Transaction Records: %', client_transaction_count;
    RAISE NOTICE 'Electronic Transaction Records: %', electronic_transaction_count;
    
    -- Validate client balance
    IF final_client_balance = initial_client_balance - payment_amount THEN
        RAISE NOTICE '✅ Client balance correctly debited';
    ELSE
        RAISE NOTICE '❌ Client balance incorrect - Expected: %, Got: %', 
                     initial_client_balance - payment_amount, final_client_balance;
    END IF;
    
    -- Validate electronic balance
    IF final_electronic_balance = initial_electronic_balance + payment_amount THEN
        RAISE NOTICE '✅ Electronic wallet balance correctly credited';
    ELSE
        RAISE NOTICE '❌ Electronic wallet balance incorrect - Expected: %, Got: %', 
                     initial_electronic_balance + payment_amount, final_electronic_balance;
    END IF;
    
    -- Validate transaction records
    IF client_transaction_count >= 1 THEN
        RAISE NOTICE '✅ Client transaction record created';
    ELSE
        RAISE NOTICE '❌ Client transaction record missing';
    END IF;
    
    IF electronic_transaction_count >= 1 THEN
        RAISE NOTICE '✅ Electronic wallet transaction record created';
    ELSE
        RAISE NOTICE '❌ Electronic wallet transaction record missing';
    END IF;
    
    -- Test 3: Money conservation
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 3: MONEY CONSERVATION ===';
    
    DECLARE
        total_before DECIMAL(10,2) := initial_client_balance + initial_electronic_balance;
        total_after DECIMAL(10,2) := final_client_balance + final_electronic_balance;
    BEGIN
        RAISE NOTICE 'Total money before: % EGP', total_before;
        RAISE NOTICE 'Total money after: % EGP', total_after;
        
        IF total_before = total_after THEN
            RAISE NOTICE '✅ Money conservation verified - no money created or destroyed';
        ELSE
            RAISE NOTICE '❌ Money conservation failed - money was created or destroyed';
        END IF;
    END;
    
    -- Test 4: Transaction linking
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 4: TRANSACTION LINKING ===';
    
    DECLARE
        linked_transactions INTEGER;
    BEGIN
        SELECT COUNT(*) INTO linked_transactions
        FROM public.wallet_transactions wt
        JOIN public.electronic_wallet_transactions ewt ON wt.reference_id = ewt.payment_id
        WHERE wt.reference_id = test_payment_id::TEXT;
        
        IF linked_transactions >= 1 THEN
            RAISE NOTICE '✅ Transactions properly linked via payment ID';
        ELSE
            RAISE NOTICE '❌ Transactions not properly linked';
        END IF;
    END;
    
    -- Test 5: Insufficient balance scenario
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 5: INSUFFICIENT BALANCE TEST ===';
    
    -- Set client balance to less than payment amount
    UPDATE public.wallets 
    SET balance = 50.00 
    WHERE user_id = test_client_id;
    
    BEGIN
        SELECT public.process_dual_wallet_transaction(
            test_client_id,
            test_electronic_wallet_id,
            payment_amount, -- 150.00 > 50.00
            test_payment_id::TEXT,
            'Test insufficient balance',
            test_client_id
        ) INTO test_result;
        
        RAISE NOTICE '❌ Insufficient balance test failed - should have been rejected';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '✅ Insufficient balance test passed - correctly rejected: %', SQLERRM;
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== DUAL WALLET SYSTEM TEST COMPLETED ===';
    
    -- Cleanup test data
    BEGIN
        DELETE FROM public.electronic_payments WHERE id = test_payment_id;
        DELETE FROM public.payment_accounts WHERE id = test_electronic_wallet_id;
        DELETE FROM public.electronic_wallets WHERE id = test_electronic_wallet_id;
        DELETE FROM public.wallet_transactions WHERE reference_id = test_payment_id::TEXT;
        DELETE FROM public.electronic_wallet_transactions WHERE payment_id = test_payment_id::TEXT;
        
        -- Only delete wallet if we created it for testing
        IF (SELECT COUNT(*) FROM public.wallets WHERE user_id = test_client_id AND role = 'client') = 1 
           AND NOT EXISTS (SELECT 1 FROM auth.users WHERE id = test_client_id) THEN
            DELETE FROM public.wallets WHERE user_id = test_client_id;
            RAISE NOTICE 'Deleted test wallet (no corresponding auth user)';
        ELSE
            -- Reset balance to original if it was an existing wallet
            UPDATE public.wallets SET balance = 0.00 WHERE user_id = test_client_id;
            RAISE NOTICE 'Reset existing wallet balance';
        END IF;
        
        RAISE NOTICE 'Test data cleanup completed';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Cleanup warning: %', SQLERRM;
    END;
    
END;
$$;

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check if dual wallet functions exist
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name IN (
    'process_dual_wallet_transaction',
    'update_client_wallet_balance',
    'update_electronic_wallet_balance',
    'handle_electronic_payment_approval_v3'
)
ORDER BY routine_name;

-- Check if trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table
FROM information_schema.triggers 
WHERE trigger_name LIKE '%electronic_payment_approval%'
ORDER BY trigger_name;
