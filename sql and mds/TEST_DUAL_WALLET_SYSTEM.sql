-- ============================================================================
-- TEST DUAL WALLET SYSTEM
-- ============================================================================
-- This script tests the dual wallet system for electronic payments
-- to ensure proper money transfer between client and company wallets

BEGIN;

-- Step 1: Create test data
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
    test_email TEXT := 'test_dual_wallet_' || extract(epoch from now())::bigint || '@example.com';
    existing_user_id UUID;
BEGIN
    RAISE NOTICE '=== TESTING DUAL WALLET SYSTEM ===';

    -- Generate a unique test client ID
    test_client_id := gen_random_uuid();

    -- Check if we can use an existing user or need to create one
    SELECT id INTO existing_user_id
    FROM auth.users
    WHERE email LIKE 'test_dual_wallet_%@example.com'
    LIMIT 1;

    IF existing_user_id IS NOT NULL THEN
        -- Use existing test user
        test_client_id := existing_user_id;
        RAISE NOTICE 'Using existing test user: %', test_client_id;
    ELSE
        -- Try to create a new test user
        BEGIN
            INSERT INTO auth.users (id, email, created_at, updated_at)
            VALUES (
                test_client_id,
                test_email,
                now(),
                now()
            );
            RAISE NOTICE 'Created new test user: %', test_client_id;
        EXCEPTION
            WHEN OTHERS THEN
                -- If we can't create in auth.users, use a random UUID and skip auth table
                RAISE NOTICE 'Cannot create auth user (%), using UUID only: %', SQLERRM, test_client_id;
        END;
    END IF;
    
    -- Create client wallet with initial balance
    INSERT INTO public.wallets (user_id, role, balance, currency, status)
    VALUES (test_client_id, 'client', initial_client_balance, 'EGP', 'active')
    ON CONFLICT (user_id) DO UPDATE SET 
        balance = initial_client_balance,
        updated_at = now();
    
    -- Create electronic wallet
    INSERT INTO public.electronic_wallets (
        wallet_type, phone_number, wallet_name, current_balance, status
    ) VALUES (
        'vodafone_cash', '01012345678', 'Test Vodafone Wallet', initial_electronic_balance, 'active'
    ) RETURNING id INTO test_electronic_wallet_id;
    
    -- Create corresponding payment account
    INSERT INTO public.payment_accounts (
        id, account_type, account_number, account_holder_name, is_active
    ) VALUES (
        test_electronic_wallet_id, 'vodafone_cash', '01012345678', 'Test Vodafone Wallet', true
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
    
    -- Test 1: Validate client balance before approval
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 1: BALANCE VALIDATION ===';
    
    -- This should succeed (client has sufficient balance)
    BEGIN
        PERFORM public.process_dual_wallet_transaction(
            test_client_id,
            test_electronic_wallet_id,
            payment_amount,
            test_payment_id::TEXT,
            'Test dual wallet transaction',
            test_client_id
        );
        RAISE NOTICE '✅ Balance validation test passed - sufficient balance';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Balance validation test failed: %', SQLERRM;
    END;
    
    -- Test 2: Test insufficient balance scenario
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 2: INSUFFICIENT BALANCE TEST ===';
    
    BEGIN
        PERFORM public.process_dual_wallet_transaction(
            test_client_id,
            test_electronic_wallet_id,
            2000.00, -- More than client balance
            test_payment_id::TEXT,
            'Test insufficient balance',
            test_client_id
        );
        RAISE NOTICE '❌ Insufficient balance test failed - should have been rejected';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '✅ Insufficient balance test passed - correctly rejected: %', SQLERRM;
    END;
    
    -- Test 3: Test payment approval workflow
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 3: PAYMENT APPROVAL WORKFLOW ===';
    
    -- Reset balances for clean test
    UPDATE public.wallets 
    SET balance = initial_client_balance 
    WHERE user_id = test_client_id;
    
    UPDATE public.electronic_wallets 
    SET current_balance = initial_electronic_balance 
    WHERE id = test_electronic_wallet_id;
    
    -- Approve the payment (this should trigger the dual wallet transaction)
    UPDATE public.electronic_payments 
    SET 
        status = 'approved',
        approved_by = test_client_id,
        approved_at = now()
    WHERE id = test_payment_id;
    
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
    
    -- Test 4: Verify money conservation (total money in system unchanged)
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 4: MONEY CONSERVATION ===';
    
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
    
    -- Test 5: Verify transaction linking
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST 5: TRANSACTION LINKING ===';
    
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
    
    RAISE NOTICE '';
    RAISE NOTICE '=== DUAL WALLET SYSTEM TEST COMPLETED ===';

    -- Cleanup test data (in reverse order of creation)
    BEGIN
        DELETE FROM public.electronic_payments WHERE id = test_payment_id;
        RAISE NOTICE 'Deleted test electronic payment';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Could not delete electronic payment: %', SQLERRM;
    END;

    BEGIN
        DELETE FROM public.payment_accounts WHERE id = test_electronic_wallet_id;
        RAISE NOTICE 'Deleted test payment account';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Could not delete payment account: %', SQLERRM;
    END;

    BEGIN
        DELETE FROM public.electronic_wallets WHERE id = test_electronic_wallet_id;
        RAISE NOTICE 'Deleted test electronic wallet';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Could not delete electronic wallet: %', SQLERRM;
    END;

    BEGIN
        DELETE FROM public.wallet_transactions WHERE reference_id = test_payment_id::TEXT;
        RAISE NOTICE 'Deleted test wallet transactions';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Could not delete wallet transactions: %', SQLERRM;
    END;

    BEGIN
        DELETE FROM public.wallets WHERE user_id = test_client_id;
        RAISE NOTICE 'Deleted test client wallet';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Could not delete client wallet: %', SQLERRM;
    END;

    -- Only try to delete from auth.users if we created the user
    IF existing_user_id IS NULL THEN
        BEGIN
            DELETE FROM auth.users WHERE id = test_client_id AND email = test_email;
            RAISE NOTICE 'Deleted test auth user';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Could not delete auth user (this is normal): %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'Preserved existing test user';
    END IF;

    RAISE NOTICE 'Test data cleanup completed';
    
END;
$$;

COMMIT;

-- ============================================================================
-- MANUAL VERIFICATION QUERIES
-- ============================================================================

-- Query to check dual wallet transaction function exists
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'process_dual_wallet_transaction';

-- Query to check approval trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%electronic_payment_approval%';

-- Query to verify wallet balance update functions
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name IN (
    'update_electronic_wallet_balance',
    'update_client_wallet_balance',
    'handle_electronic_payment_approval_v3'
);

-- ============================================================================
-- PRODUCTION VERIFICATION QUERIES
-- ============================================================================

-- Check for any payments that might have balance issues
SELECT 
    ep.id,
    ep.amount,
    ep.status,
    w.balance as client_balance,
    ew.current_balance as electronic_balance,
    CASE 
        WHEN w.balance >= ep.amount THEN 'Sufficient'
        ELSE 'Insufficient'
    END as balance_status
FROM public.electronic_payments ep
JOIN public.wallets w ON ep.client_id = w.user_id
JOIN public.electronic_wallets ew ON ep.recipient_account_id = ew.id
WHERE ep.status = 'pending'
ORDER BY ep.created_at DESC;

-- Check transaction linking for recent payments
SELECT 
    ep.id as payment_id,
    ep.amount,
    ep.status,
    wt.id as client_transaction_id,
    ewt.id as electronic_transaction_id,
    wt.amount as client_amount,
    ewt.amount as electronic_amount
FROM public.electronic_payments ep
LEFT JOIN public.wallet_transactions wt ON ep.id::TEXT = wt.reference_id
LEFT JOIN public.electronic_wallet_transactions ewt ON ep.id::TEXT = ewt.payment_id
WHERE ep.status = 'approved'
ORDER BY ep.approved_at DESC
LIMIT 10;
