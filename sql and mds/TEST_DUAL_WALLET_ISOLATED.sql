-- ============================================================================
-- ISOLATED DUAL WALLET SYSTEM TEST
-- ============================================================================
-- This script tests the dual wallet system using completely isolated test data
-- No dependency on auth.users table or existing data

BEGIN;

-- Create temporary test tables if needed (for complete isolation)
CREATE TEMP TABLE IF NOT EXISTS temp_test_results (
    test_name TEXT,
    status TEXT,
    message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Main test execution
DO $$
DECLARE
    -- Test UUIDs (completely isolated with timestamp to ensure uniqueness)
    test_client_id UUID;
    test_electronic_wallet_id UUID;
    test_payment_id UUID;
    
    -- Test amounts
    initial_client_balance DECIMAL(10,2) := 1000.00;
    initial_electronic_balance DECIMAL(10,2) := 500.00;
    payment_amount DECIMAL(10,2) := 150.00;
    
    -- Result variables
    final_client_balance DECIMAL(10,2);
    final_electronic_balance DECIMAL(10,2);
    client_transaction_count INTEGER;
    electronic_transaction_count INTEGER;
    test_result JSON;
    
    -- Test tracking
    tests_passed INTEGER := 0;
    tests_failed INTEGER := 0;
    total_tests INTEGER := 6;
BEGIN
    -- Generate unique test IDs using timestamp
    test_client_id := gen_random_uuid();
    test_electronic_wallet_id := gen_random_uuid();
    test_payment_id := gen_random_uuid();

    RAISE NOTICE '=== ISOLATED DUAL WALLET SYSTEM TEST ===';
    RAISE NOTICE 'Test Client ID: %', test_client_id;
    RAISE NOTICE 'Test Electronic Wallet ID: %', test_electronic_wallet_id;
    RAISE NOTICE 'Test Payment ID: %', test_payment_id;
    RAISE NOTICE '';

    -- Setup: Create isolated test data
    RAISE NOTICE '=== SETUP: Creating isolated test data ===';

    -- Cleanup any existing test data first
    DELETE FROM public.electronic_payments WHERE client_id = test_client_id;
    DELETE FROM public.payment_accounts WHERE account_holder_name = 'Test Isolated Wallet';
    DELETE FROM public.electronic_wallets WHERE wallet_name = 'Test Isolated Wallet';
    DELETE FROM public.wallet_transactions WHERE reference_id = test_payment_id::TEXT;
    DELETE FROM public.electronic_wallet_transactions WHERE payment_id = test_payment_id::TEXT;
    DELETE FROM public.wallets WHERE user_id = test_client_id;

    -- Create test client wallet
    INSERT INTO public.wallets (id, user_id, role, balance, currency, status, created_at, updated_at)
    VALUES (
        gen_random_uuid(),
        test_client_id,
        'client',
        initial_client_balance,
        'EGP',
        'active',
        now(),
        now()
    );

    -- Create test electronic wallet
    INSERT INTO public.electronic_wallets (
        id, wallet_type, phone_number, wallet_name, current_balance, status, created_at, updated_at
    ) VALUES (
        test_electronic_wallet_id,
        'vodafone_cash',
        '01099999999',
        'Test Isolated Wallet',
        initial_electronic_balance,
        'active',
        now(),
        now()
    );

    -- Create corresponding payment account with conflict handling
    INSERT INTO public.payment_accounts (
        id, account_type, account_number, account_holder_name, is_active, created_at, updated_at
    ) VALUES (
        test_electronic_wallet_id,
        'vodafone_cash',
        '01099999999',
        'Test Isolated Wallet',
        true,
        now(),
        now()
    ) ON CONFLICT (id) DO UPDATE SET
        account_type = EXCLUDED.account_type,
        account_number = EXCLUDED.account_number,
        account_holder_name = EXCLUDED.account_holder_name,
        is_active = EXCLUDED.is_active,
        updated_at = EXCLUDED.updated_at;

    -- Create test electronic payment
    INSERT INTO public.electronic_payments (
        id, client_id, payment_method, amount, recipient_account_id, status, created_at, updated_at
    ) VALUES (
        test_payment_id,
        test_client_id,
        'vodafone_cash',
        payment_amount,
        test_electronic_wallet_id,
        'pending',
        now(),
        now()
    ) ON CONFLICT (id) DO UPDATE SET
        status = 'pending',
        updated_at = now();
    
    RAISE NOTICE '✅ Test data created successfully';
    RAISE NOTICE '';
    
    -- TEST 1: Function existence check
    RAISE NOTICE '=== TEST 1: Function Existence Check ===';
    BEGIN
        IF EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'process_dual_wallet_transaction'
        ) THEN
            RAISE NOTICE '✅ process_dual_wallet_transaction function exists';
            tests_passed := tests_passed + 1;
            INSERT INTO temp_test_results VALUES ('Function Existence', 'PASS', 'process_dual_wallet_transaction exists');
        ELSE
            RAISE NOTICE '❌ process_dual_wallet_transaction function missing';
            tests_failed := tests_failed + 1;
            INSERT INTO temp_test_results VALUES ('Function Existence', 'FAIL', 'process_dual_wallet_transaction missing');
        END IF;
    END;
    
    -- TEST 2: Direct function call with sufficient balance
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 2: Direct Function Call (Sufficient Balance) ===';
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
        tests_passed := tests_passed + 1;
        INSERT INTO temp_test_results VALUES ('Direct Function Call', 'PASS', 'Function executed successfully');
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Direct function call failed: %', SQLERRM;
            tests_failed := tests_failed + 1;
            INSERT INTO temp_test_results VALUES ('Direct Function Call', 'FAIL', SQLERRM);
    END;
    
    -- Reset balances for next test
    UPDATE public.wallets SET balance = initial_client_balance WHERE user_id = test_client_id;
    UPDATE public.electronic_wallets SET current_balance = initial_electronic_balance WHERE id = test_electronic_wallet_id;
    
    -- TEST 3: Insufficient balance scenario
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 3: Insufficient Balance Test ===';
    
    -- Set client balance to insufficient amount
    UPDATE public.wallets SET balance = 50.00 WHERE user_id = test_client_id;
    
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
        tests_failed := tests_failed + 1;
        INSERT INTO temp_test_results VALUES ('Insufficient Balance', 'FAIL', 'Function should have failed but succeeded');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%رصيد العميل غير كافي%' OR SQLERRM LIKE '%insufficient%' THEN
                RAISE NOTICE '✅ Insufficient balance test passed - correctly rejected: %', SQLERRM;
                tests_passed := tests_passed + 1;
                INSERT INTO temp_test_results VALUES ('Insufficient Balance', 'PASS', 'Correctly rejected insufficient balance');
            ELSE
                RAISE NOTICE '❌ Insufficient balance test failed with unexpected error: %', SQLERRM;
                tests_failed := tests_failed + 1;
                INSERT INTO temp_test_results VALUES ('Insufficient Balance', 'FAIL', 'Unexpected error: ' || SQLERRM);
            END IF;
    END;
    
    -- Reset balances for trigger test
    UPDATE public.wallets SET balance = initial_client_balance WHERE user_id = test_client_id;
    UPDATE public.electronic_wallets SET current_balance = initial_electronic_balance WHERE id = test_electronic_wallet_id;
    
    -- TEST 4: Trigger-based approval
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 4: Trigger-Based Approval ===';
    BEGIN
        -- Approve the payment (this should trigger the dual wallet transaction)
        UPDATE public.electronic_payments 
        SET 
            status = 'approved',
            approved_by = test_client_id,
            approved_at = now()
        WHERE id = test_payment_id;
        
        RAISE NOTICE '✅ Payment approval trigger executed successfully';
        tests_passed := tests_passed + 1;
        INSERT INTO temp_test_results VALUES ('Trigger Approval', 'PASS', 'Trigger executed without error');
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Payment approval trigger failed: %', SQLERRM;
            tests_failed := tests_failed + 1;
            INSERT INTO temp_test_results VALUES ('Trigger Approval', 'FAIL', SQLERRM);
    END;
    
    -- Check final balances
    SELECT balance INTO final_client_balance FROM public.wallets WHERE user_id = test_client_id;
    SELECT current_balance INTO final_electronic_balance FROM public.electronic_wallets WHERE id = test_electronic_wallet_id;
    
    -- TEST 5: Balance verification
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 5: Balance Verification ===';
    
    DECLARE
        expected_client_balance DECIMAL(10,2) := initial_client_balance - payment_amount;
        expected_electronic_balance DECIMAL(10,2) := initial_electronic_balance + payment_amount;
        balance_test_passed BOOLEAN := true;
    BEGIN
        RAISE NOTICE 'Expected Client Balance: % EGP', expected_client_balance;
        RAISE NOTICE 'Actual Client Balance: % EGP', final_client_balance;
        RAISE NOTICE 'Expected Electronic Balance: % EGP', expected_electronic_balance;
        RAISE NOTICE 'Actual Electronic Balance: % EGP', final_electronic_balance;
        
        IF final_client_balance != expected_client_balance THEN
            RAISE NOTICE '❌ Client balance incorrect';
            balance_test_passed := false;
        END IF;
        
        IF final_electronic_balance != expected_electronic_balance THEN
            RAISE NOTICE '❌ Electronic balance incorrect';
            balance_test_passed := false;
        END IF;
        
        IF balance_test_passed THEN
            RAISE NOTICE '✅ All balances correct';
            tests_passed := tests_passed + 1;
            INSERT INTO temp_test_results VALUES ('Balance Verification', 'PASS', 'All balances updated correctly');
        ELSE
            tests_failed := tests_failed + 1;
            INSERT INTO temp_test_results VALUES ('Balance Verification', 'FAIL', 'Balance mismatch detected');
        END IF;
    END;
    
    -- TEST 6: Money conservation
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 6: Money Conservation ===';
    
    DECLARE
        total_before DECIMAL(10,2) := initial_client_balance + initial_electronic_balance;
        total_after DECIMAL(10,2) := final_client_balance + final_electronic_balance;
    BEGIN
        RAISE NOTICE 'Total money before: % EGP', total_before;
        RAISE NOTICE 'Total money after: % EGP', total_after;
        
        IF total_before = total_after THEN
            RAISE NOTICE '✅ Money conservation verified - no money created or destroyed';
            tests_passed := tests_passed + 1;
            INSERT INTO temp_test_results VALUES ('Money Conservation', 'PASS', 'Total system money unchanged');
        ELSE
            RAISE NOTICE '❌ Money conservation failed - money was created or destroyed';
            tests_failed := tests_failed + 1;
            INSERT INTO temp_test_results VALUES ('Money Conservation', 'FAIL', 'Total system money changed');
        END IF;
    END;
    
    -- Final test summary
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST SUMMARY ===';
    RAISE NOTICE 'Total Tests: %', total_tests;
    RAISE NOTICE 'Tests Passed: %', tests_passed;
    RAISE NOTICE 'Tests Failed: %', tests_failed;
    RAISE NOTICE 'Success Rate: %%%', ROUND((tests_passed::DECIMAL / total_tests::DECIMAL) * 100, 2);
    
    IF tests_failed = 0 THEN
        RAISE NOTICE '🎉 ALL TESTS PASSED - DUAL WALLET SYSTEM IS WORKING CORRECTLY';
    ELSE
        RAISE NOTICE '⚠️ SOME TESTS FAILED - PLEASE REVIEW THE ISSUES ABOVE';
    END IF;
    
    -- Cleanup test data
    RAISE NOTICE '';
    RAISE NOTICE '=== CLEANUP ===';
    BEGIN
        DELETE FROM public.electronic_payments WHERE id = test_payment_id;
        DELETE FROM public.payment_accounts WHERE id = test_electronic_wallet_id;
        DELETE FROM public.electronic_wallets WHERE id = test_electronic_wallet_id;
        DELETE FROM public.wallet_transactions WHERE reference_id = test_payment_id::TEXT;
        DELETE FROM public.electronic_wallet_transactions WHERE payment_id = test_payment_id::TEXT;
        DELETE FROM public.wallets WHERE user_id = test_client_id;

        RAISE NOTICE '✅ Test data cleanup completed';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '⚠️ Cleanup warning: %', SQLERRM;
    END;

    RAISE NOTICE '';
    RAISE NOTICE '=== ISOLATED DUAL WALLET SYSTEM TEST COMPLETED ===';
    RAISE NOTICE 'Check the test results above for detailed analysis.';

END;
$$;

-- Display test results
SELECT
    test_name,
    status,
    message,
    created_at
FROM temp_test_results
ORDER BY created_at;

-- Drop temporary table
DROP TABLE IF EXISTS temp_test_results;

COMMIT;
