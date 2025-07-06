-- ============================================================================
-- ROBUST DUAL WALLET SYSTEM TEST
-- ============================================================================
-- This script tests the dual wallet system with proper error handling
-- Can be run multiple times without conflicts

BEGIN;

-- Create test results table
CREATE TEMP TABLE test_results (
    test_id SERIAL PRIMARY KEY,
    test_name TEXT NOT NULL,
    status TEXT NOT NULL,
    message TEXT,
    execution_time TIMESTAMP DEFAULT NOW()
);

-- Main test execution
DO $$
DECLARE
    -- Test identifiers (unique each run)
    test_run_id TEXT := 'test_' || extract(epoch from now())::bigint;
    test_client_id UUID := gen_random_uuid();
    test_electronic_wallet_id UUID := gen_random_uuid();
    test_payment_id UUID := gen_random_uuid();
    
    -- Test amounts
    initial_client_balance DECIMAL(10,2) := 1000.00;
    initial_electronic_balance DECIMAL(10,2) := 500.00;
    payment_amount DECIMAL(10,2) := 150.00;
    
    -- Result variables
    final_client_balance DECIMAL(10,2);
    final_electronic_balance DECIMAL(10,2);
    test_result JSON;
    
    -- Test counters
    tests_passed INTEGER := 0;
    tests_failed INTEGER := 0;
    
    -- Helper function to log test results
    PROCEDURE log_test_result(test_name TEXT, status TEXT, message TEXT DEFAULT NULL) AS $$
    BEGIN
        INSERT INTO test_results (test_name, status, message) 
        VALUES (test_name, status, message);
        
        IF status = 'PASS' THEN
            tests_passed := tests_passed + 1;
        ELSE
            tests_failed := tests_failed + 1;
        END IF;
    END;
    $$;
    
BEGIN
    RAISE NOTICE '=== ROBUST DUAL WALLET SYSTEM TEST ===';
    RAISE NOTICE 'Test Run ID: %', test_run_id;
    RAISE NOTICE 'Test Client ID: %', test_client_id;
    RAISE NOTICE 'Test Electronic Wallet ID: %', test_electronic_wallet_id;
    RAISE NOTICE 'Test Payment ID: %', test_payment_id;
    RAISE NOTICE '';
    
    -- SETUP: Clean and create test data
    RAISE NOTICE '=== SETUP: Creating test data ===';
    
    BEGIN
        -- Clean any existing test data
        DELETE FROM public.electronic_payments 
        WHERE client_id = test_client_id OR id = test_payment_id;
        
        DELETE FROM public.payment_accounts 
        WHERE account_holder_name LIKE 'Test Robust Wallet%';
        
        DELETE FROM public.electronic_wallets 
        WHERE wallet_name LIKE 'Test Robust Wallet%';
        
        DELETE FROM public.wallet_transactions 
        WHERE reference_id = test_payment_id::TEXT;
        
        DELETE FROM public.electronic_wallet_transactions 
        WHERE payment_id = test_payment_id::TEXT;
        
        DELETE FROM public.wallets 
        WHERE user_id = test_client_id;
        
        -- Create test client wallet
        INSERT INTO public.wallets (user_id, role, balance, currency, status)
        VALUES (test_client_id, 'client', initial_client_balance, 'EGP', 'active');
        
        -- Create test electronic wallet
        INSERT INTO public.electronic_wallets (
            id, wallet_type, phone_number, wallet_name, current_balance, status
        ) VALUES (
            test_electronic_wallet_id,
            'vodafone_cash',
            '01099999999',
            'Test Robust Wallet ' || test_run_id,
            initial_electronic_balance,
            'active'
        );
        
        -- Create payment account (with conflict resolution)
        INSERT INTO public.payment_accounts (
            id, account_type, account_number, account_holder_name, is_active
        ) VALUES (
            test_electronic_wallet_id,
            'vodafone_cash',
            '01099999999',
            'Test Robust Wallet ' || test_run_id,
            true
        ) ON CONFLICT (id) DO UPDATE SET
            account_holder_name = EXCLUDED.account_holder_name,
            updated_at = now();
        
        -- Create test payment
        INSERT INTO public.electronic_payments (
            id, client_id, payment_method, amount, recipient_account_id, status
        ) VALUES (
            test_payment_id,
            test_client_id,
            'vodafone_cash',
            payment_amount,
            test_electronic_wallet_id,
            'pending'
        ) ON CONFLICT (id) DO UPDATE SET
            status = 'pending',
            updated_at = now();
        
        CALL log_test_result('Setup', 'PASS', 'Test data created successfully');
        RAISE NOTICE '✅ Test data setup completed';
        
    EXCEPTION
        WHEN OTHERS THEN
            CALL log_test_result('Setup', 'FAIL', 'Setup failed: ' || SQLERRM);
            RAISE NOTICE '❌ Setup failed: %', SQLERRM;
            RETURN; -- Exit if setup fails
    END;
    
    -- TEST 1: Function existence
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 1: Function Existence ===';
    
    BEGIN
        IF EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'process_dual_wallet_transaction'
        ) THEN
            CALL log_test_result('Function Existence', 'PASS', 'process_dual_wallet_transaction exists');
            RAISE NOTICE '✅ Required function exists';
        ELSE
            CALL log_test_result('Function Existence', 'FAIL', 'process_dual_wallet_transaction missing');
            RAISE NOTICE '❌ Required function missing';
        END IF;
    END;
    
    -- TEST 2: Direct function call
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 2: Direct Function Call ===';
    
    BEGIN
        SELECT public.process_dual_wallet_transaction(
            test_client_id,
            test_electronic_wallet_id,
            payment_amount,
            test_payment_id::TEXT,
            'Test dual wallet transaction',
            test_client_id
        ) INTO test_result;
        
        CALL log_test_result('Direct Function Call', 'PASS', 'Function executed: ' || test_result::TEXT);
        RAISE NOTICE '✅ Direct function call succeeded';
        
    EXCEPTION
        WHEN OTHERS THEN
            CALL log_test_result('Direct Function Call', 'FAIL', SQLERRM);
            RAISE NOTICE '❌ Direct function call failed: %', SQLERRM;
    END;
    
    -- Reset balances for next test
    UPDATE public.wallets SET balance = initial_client_balance WHERE user_id = test_client_id;
    UPDATE public.electronic_wallets SET current_balance = initial_electronic_balance WHERE id = test_electronic_wallet_id;
    
    -- TEST 3: Insufficient balance
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 3: Insufficient Balance ===';
    
    -- Set insufficient balance
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
        
        CALL log_test_result('Insufficient Balance', 'FAIL', 'Should have been rejected but succeeded');
        RAISE NOTICE '❌ Insufficient balance test failed';
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%رصيد العميل غير كافي%' OR SQLERRM LIKE '%insufficient%' THEN
                CALL log_test_result('Insufficient Balance', 'PASS', 'Correctly rejected: ' || SQLERRM);
                RAISE NOTICE '✅ Insufficient balance correctly rejected';
            ELSE
                CALL log_test_result('Insufficient Balance', 'FAIL', 'Unexpected error: ' || SQLERRM);
                RAISE NOTICE '❌ Unexpected error: %', SQLERRM;
            END IF;
    END;
    
    -- Reset for trigger test
    UPDATE public.wallets SET balance = initial_client_balance WHERE user_id = test_client_id;
    UPDATE public.electronic_wallets SET current_balance = initial_electronic_balance WHERE id = test_electronic_wallet_id;
    
    -- TEST 4: Trigger approval
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 4: Trigger Approval ===';
    
    BEGIN
        UPDATE public.electronic_payments 
        SET status = 'approved', approved_by = test_client_id, approved_at = now()
        WHERE id = test_payment_id;
        
        CALL log_test_result('Trigger Approval', 'PASS', 'Trigger executed successfully');
        RAISE NOTICE '✅ Trigger approval succeeded';
        
    EXCEPTION
        WHEN OTHERS THEN
            CALL log_test_result('Trigger Approval', 'FAIL', SQLERRM);
            RAISE NOTICE '❌ Trigger approval failed: %', SQLERRM;
    END;
    
    -- Check final balances
    SELECT balance INTO final_client_balance FROM public.wallets WHERE user_id = test_client_id;
    SELECT current_balance INTO final_electronic_balance FROM public.electronic_wallets WHERE id = test_electronic_wallet_id;
    
    -- TEST 5: Balance verification
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 5: Balance Verification ===';
    
    DECLARE
        expected_client DECIMAL(10,2) := initial_client_balance - payment_amount;
        expected_electronic DECIMAL(10,2) := initial_electronic_balance + payment_amount;
    BEGIN
        IF final_client_balance = expected_client AND final_electronic_balance = expected_electronic THEN
            CALL log_test_result('Balance Verification', 'PASS', 
                format('Client: %s->%s, Electronic: %s->%s', 
                       initial_client_balance, final_client_balance,
                       initial_electronic_balance, final_electronic_balance));
            RAISE NOTICE '✅ All balances correct';
        ELSE
            CALL log_test_result('Balance Verification', 'FAIL', 
                format('Expected Client: %s, Got: %s; Expected Electronic: %s, Got: %s',
                       expected_client, final_client_balance,
                       expected_electronic, final_electronic_balance));
            RAISE NOTICE '❌ Balance mismatch detected';
        END IF;
    END;
    
    -- TEST 6: Money conservation
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 6: Money Conservation ===';
    
    DECLARE
        total_before DECIMAL(10,2) := initial_client_balance + initial_electronic_balance;
        total_after DECIMAL(10,2) := final_client_balance + final_electronic_balance;
    BEGIN
        IF total_before = total_after THEN
            CALL log_test_result('Money Conservation', 'PASS', 
                format('Total unchanged: %s EGP', total_before));
            RAISE NOTICE '✅ Money conservation verified';
        ELSE
            CALL log_test_result('Money Conservation', 'FAIL', 
                format('Before: %s, After: %s', total_before, total_after));
            RAISE NOTICE '❌ Money conservation failed';
        END IF;
    END;
    
    -- Final summary
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST SUMMARY ===';
    RAISE NOTICE 'Tests Passed: %', tests_passed;
    RAISE NOTICE 'Tests Failed: %', tests_failed;
    RAISE NOTICE 'Total Tests: %', tests_passed + tests_failed;
    
    IF tests_failed = 0 THEN
        RAISE NOTICE '🎉 ALL TESTS PASSED - DUAL WALLET SYSTEM WORKING CORRECTLY';
    ELSE
        RAISE NOTICE '⚠️ % TESTS FAILED - REVIEW RESULTS BELOW', tests_failed;
    END IF;
    
    -- Cleanup
    RAISE NOTICE '';
    RAISE NOTICE '=== CLEANUP ===';
    
    BEGIN
        DELETE FROM public.electronic_payments WHERE id = test_payment_id;
        DELETE FROM public.payment_accounts WHERE id = test_electronic_wallet_id;
        DELETE FROM public.electronic_wallets WHERE id = test_electronic_wallet_id;
        DELETE FROM public.wallet_transactions WHERE reference_id = test_payment_id::TEXT;
        DELETE FROM public.electronic_wallet_transactions WHERE payment_id = test_payment_id::TEXT;
        DELETE FROM public.wallets WHERE user_id = test_client_id;
        
        RAISE NOTICE '✅ Cleanup completed';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '⚠️ Cleanup warning: %', SQLERRM;
    END;
    
END;
$$;

-- Display detailed test results
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== DETAILED TEST RESULTS ===';
END;
$$;

SELECT 
    test_id,
    test_name,
    status,
    COALESCE(message, 'No additional details') as details,
    execution_time
FROM test_results
ORDER BY test_id;

-- Summary
SELECT 
    COUNT(*) as total_tests,
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) as passed,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) as failed,
    ROUND(
        (SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END)::DECIMAL / COUNT(*)::DECIMAL) * 100, 
        2
    ) as success_rate_percent
FROM test_results;

-- Drop temp table
DROP TABLE test_results;

COMMIT;
