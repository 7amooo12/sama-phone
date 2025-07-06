-- ============================================================================
-- TEST ELECTRONIC WALLET WITHDRAWAL FUNCTIONALITY
-- ============================================================================
-- 
-- Purpose: Comprehensive testing of the update_wallet_balance function
--          to identify why withdrawal/payment transactions are not working
-- 
-- Tests Include:
-- 1. Function existence and signature verification
-- 2. Test wallet creation with sufficient balance
-- 3. Deposit transaction test (should work)
-- 4. Withdrawal transaction test (currently failing)
-- 5. Payment transaction test (currently failing)
-- 6. Insufficient balance test
-- 7. Permission and error handling tests
-- 
-- Date: 2025-06-18
-- ============================================================================

-- ============================================================================
-- STEP 1: VERIFY FUNCTION EXISTS
-- ============================================================================

SELECT 
    routine_name,
    routine_type,
    data_type as return_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'update_wallet_balance';

-- ============================================================================
-- STEP 2: CREATE TEST WALLET WITH SUFFICIENT BALANCE
-- ============================================================================

-- First, let's check if we have any test wallets
SELECT
    id,
    wallet_name,
    phone_number,
    current_balance,
    status,
    wallet_type
FROM public.electronic_wallets
WHERE wallet_name LIKE '%TEST%' OR phone_number LIKE '%01111111111%'
ORDER BY created_at DESC
LIMIT 5;

-- Delete any existing test wallets first
DELETE FROM public.electronic_wallets
WHERE phone_number = '01111111111';

-- Create a fresh test wallet
INSERT INTO public.electronic_wallets (
    id,
    wallet_name,
    phone_number,
    wallet_type,
    current_balance,
    status,
    created_at,
    updated_at
) VALUES (
    gen_random_uuid(),
    'TEST WALLET - Withdrawal Testing',
    '01111111111',
    'vodafone_cash',
    1000.00,  -- Start with 1000 balance for testing
    'active',
    now(),
    now()
)
RETURNING id, wallet_name, current_balance;

-- ============================================================================
-- STEP 3: TEST DEPOSIT TRANSACTION (SHOULD WORK)
-- ============================================================================

DO $$
DECLARE
    test_wallet_id UUID;
    transaction_id UUID;
    initial_balance DECIMAL(12,2);
    final_balance DECIMAL(12,2);
BEGIN
    -- Get test wallet ID
    SELECT id INTO test_wallet_id
    FROM public.electronic_wallets
    WHERE phone_number = '01111111111'
    LIMIT 1;
    
    IF test_wallet_id IS NULL THEN
        RAISE EXCEPTION 'Test wallet not found';
    END IF;
    
    -- Get initial balance
    SELECT current_balance INTO initial_balance
    FROM public.electronic_wallets
    WHERE id = test_wallet_id;
    
    RAISE NOTICE 'TEST 1: DEPOSIT TRANSACTION';
    RAISE NOTICE 'Wallet ID: %', test_wallet_id;
    RAISE NOTICE 'Initial Balance: %', initial_balance;
    
    -- Test deposit transaction
    BEGIN
        SELECT public.update_wallet_balance(
            test_wallet_id,
            100.00,
            'deposit',
            'Test deposit transaction',
            'TEST_DEPOSIT_REF',
            NULL,
            NULL
        ) INTO transaction_id;
        
        -- Get final balance
        SELECT current_balance INTO final_balance
        FROM public.electronic_wallets
        WHERE id = test_wallet_id;
        
        RAISE NOTICE 'SUCCESS: Deposit transaction completed';
        RAISE NOTICE 'Transaction ID: %', transaction_id;
        RAISE NOTICE 'Final Balance: %', final_balance;
        RAISE NOTICE 'Balance Change: %', (final_balance - initial_balance);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'FAILED: Deposit transaction error: %', SQLERRM;
    END;
END;
$$;

-- ============================================================================
-- STEP 4: TEST WITHDRAWAL TRANSACTION
-- ============================================================================

DO $$
DECLARE
    test_wallet_id UUID;
    transaction_id UUID;
    initial_balance DECIMAL(12,2);
    final_balance DECIMAL(12,2);
BEGIN
    -- Get test wallet ID
    SELECT id INTO test_wallet_id
    FROM public.electronic_wallets
    WHERE phone_number = '01111111111'
    LIMIT 1;
    
    -- Get initial balance
    SELECT current_balance INTO initial_balance
    FROM public.electronic_wallets
    WHERE id = test_wallet_id;
    
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 2: WITHDRAWAL TRANSACTION';
    RAISE NOTICE 'Wallet ID: %', test_wallet_id;
    RAISE NOTICE 'Initial Balance: %', initial_balance;
    
    -- Test withdrawal transaction
    BEGIN
        SELECT public.update_wallet_balance(
            test_wallet_id,
            50.00,
            'withdrawal',
            'Test withdrawal transaction',
            'TEST_WITHDRAWAL_REF',
            NULL,
            NULL
        ) INTO transaction_id;
        
        -- Get final balance
        SELECT current_balance INTO final_balance
        FROM public.electronic_wallets
        WHERE id = test_wallet_id;
        
        RAISE NOTICE 'SUCCESS: Withdrawal transaction completed';
        RAISE NOTICE 'Transaction ID: %', transaction_id;
        RAISE NOTICE 'Final Balance: %', final_balance;
        RAISE NOTICE 'Balance Change: %', (final_balance - initial_balance);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'FAILED: Withdrawal transaction error: %', SQLERRM;
            RAISE NOTICE 'Error Code: %', SQLSTATE;
    END;
END;
$$;

-- ============================================================================
-- STEP 5: TEST PAYMENT TRANSACTION
-- ============================================================================

DO $$
DECLARE
    test_wallet_id UUID;
    transaction_id UUID;
    initial_balance DECIMAL(12,2);
    final_balance DECIMAL(12,2);
BEGIN
    -- Get test wallet ID
    SELECT id INTO test_wallet_id
    FROM public.electronic_wallets
    WHERE phone_number = '01111111111'
    LIMIT 1;
    
    -- Get initial balance
    SELECT current_balance INTO initial_balance
    FROM public.electronic_wallets
    WHERE id = test_wallet_id;
    
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 3: PAYMENT TRANSACTION';
    RAISE NOTICE 'Wallet ID: %', test_wallet_id;
    RAISE NOTICE 'Initial Balance: %', initial_balance;
    
    -- Test payment transaction
    BEGIN
        SELECT public.update_wallet_balance(
            test_wallet_id,
            75.00,
            'payment',
            'Test payment transaction',
            'TEST_PAYMENT_REF',
            gen_random_uuid(),
            NULL
        ) INTO transaction_id;
        
        -- Get final balance
        SELECT current_balance INTO final_balance
        FROM public.electronic_wallets
        WHERE id = test_wallet_id;
        
        RAISE NOTICE 'SUCCESS: Payment transaction completed';
        RAISE NOTICE 'Transaction ID: %', transaction_id;
        RAISE NOTICE 'Final Balance: %', final_balance;
        RAISE NOTICE 'Balance Change: %', (final_balance - initial_balance);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'FAILED: Payment transaction error: %', SQLERRM;
            RAISE NOTICE 'Error Code: %', SQLSTATE;
    END;
END;
$$;

-- ============================================================================
-- STEP 6: TEST INSUFFICIENT BALANCE SCENARIO
-- ============================================================================

DO $$
DECLARE
    test_wallet_id UUID;
    transaction_id UUID;
    current_balance DECIMAL(12,2);
BEGIN
    -- Get test wallet ID
    SELECT id INTO test_wallet_id
    FROM public.electronic_wallets 
    WHERE phone_number = 'TEST-01234567890'
    LIMIT 1;
    
    -- Get current balance
    SELECT ew.current_balance INTO current_balance
    FROM public.electronic_wallets ew
    WHERE ew.id = test_wallet_id;
    
    RAISE NOTICE '';
    RAISE NOTICE 'TEST 4: INSUFFICIENT BALANCE TEST';
    RAISE NOTICE 'Wallet ID: %', test_wallet_id;
    RAISE NOTICE 'Current Balance: %', current_balance;
    RAISE NOTICE 'Attempting withdrawal of: %', (current_balance + 100.00);
    
    -- Test insufficient balance scenario
    BEGIN
        SELECT public.update_wallet_balance(
            test_wallet_id,
            current_balance + 100.00,  -- More than available balance
            'withdrawal',
            'Test insufficient balance withdrawal',
            'TEST_INSUFFICIENT_REF',
            NULL,
            NULL
        ) INTO transaction_id;
        
        RAISE NOTICE 'UNEXPECTED: Insufficient balance check failed - transaction should have been rejected';
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%Insufficient balance%' THEN
                RAISE NOTICE 'SUCCESS: Insufficient balance properly detected: %', SQLERRM;
            ELSE
                RAISE NOTICE 'FAILED: Unexpected error: %', SQLERRM;
            END IF;
    END;
END;
$$;

-- ============================================================================
-- STEP 7: SHOW TRANSACTION HISTORY
-- ============================================================================

SELECT 
    'TRANSACTION HISTORY FOR TEST WALLET' as info;

SELECT 
    t.id,
    t.transaction_type,
    t.amount,
    t.balance_before,
    t.balance_after,
    t.status,
    t.description,
    t.reference_id,
    t.created_at
FROM public.electronic_wallet_transactions t
JOIN public.electronic_wallets w ON t.wallet_id = w.id
WHERE w.phone_number = 'TEST-01234567890'
ORDER BY t.created_at DESC
LIMIT 10;

-- ============================================================================
-- STEP 8: SHOW FINAL WALLET STATE
-- ============================================================================

SELECT 
    'FINAL WALLET STATE' as info;

SELECT 
    id,
    wallet_name,
    phone_number,
    current_balance,
    status,
    updated_at
FROM public.electronic_wallets 
WHERE phone_number = 'TEST-01234567890';

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

SELECT 'Electronic wallet withdrawal functionality testing completed' as status;
