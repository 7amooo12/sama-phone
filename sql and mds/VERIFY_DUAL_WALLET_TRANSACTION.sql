-- =====================================================
-- VERIFY DUAL WALLET TRANSACTION ACCURACY
-- =====================================================
-- This script verifies that the electronic payment dual wallet transaction
-- is working correctly with proper balance updates and financial accuracy

-- Step 1: Verify Payment Status Change
SELECT 
    '=== PAYMENT STATUS VERIFICATION ===' as section,
    id as payment_id,
    client_id,
    amount,
    status,
    approved_by,
    approved_at,
    admin_notes,
    created_at,
    updated_at
FROM public.electronic_payments 
WHERE id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca';

-- Step 2: Verify Client Wallet Balance Changes
SELECT 
    '=== CLIENT WALLET VERIFICATION ===' as section,
    id as wallet_id,
    user_id as client_id,
    balance as current_balance,
    currency,
    wallet_type,
    is_active,
    updated_at as last_updated
FROM public.wallets 
WHERE id = '69fe870b-3439-4d4f-a0f3-f7c93decd79a';

-- Step 3: Verify Business Wallet Balance Changes
SELECT 
    '=== BUSINESS WALLET VERIFICATION ===' as section,
    id as wallet_id,
    user_id,
    balance as current_balance,
    currency,
    wallet_type,
    is_active,
    updated_at as last_updated
FROM public.wallets 
WHERE wallet_type = 'business' AND is_active = true;

-- Step 4: Verify Client Wallet Transaction Record
SELECT 
    '=== CLIENT WALLET TRANSACTION ===' as section,
    id as transaction_id,
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
FROM public.wallet_transactions 
WHERE wallet_id = '69fe870b-3439-4d4f-a0f3-f7c93decd79a'
AND reference_type = 'electronic_payment'
AND reference_id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca'
ORDER BY created_at DESC
LIMIT 1;

-- Step 5: Verify Business Wallet Transaction Record
SELECT 
    '=== BUSINESS WALLET TRANSACTION ===' as section,
    wt.id as transaction_id,
    wt.wallet_id,
    wt.user_id,
    wt.transaction_type,
    wt.amount,
    wt.balance_before,
    wt.balance_after,
    wt.reference_type,
    wt.reference_id,
    wt.description,
    wt.status,
    wt.created_by,
    wt.created_at
FROM public.wallet_transactions wt
JOIN public.wallets w ON wt.wallet_id = w.id
WHERE w.wallet_type = 'business'
AND wt.reference_type = 'electronic_payment'
AND wt.reference_id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca'
ORDER BY wt.created_at DESC
LIMIT 1;

-- Step 6: Balance Conservation Verification
DO $$
DECLARE
    v_client_transaction RECORD;
    v_business_transaction RECORD;
    v_client_balance_change DECIMAL(15,2);
    v_business_balance_change DECIMAL(15,2);
    v_total_change DECIMAL(15,2);
    v_payment_amount DECIMAL(15,2);
BEGIN
    RAISE NOTICE '=== BALANCE CONSERVATION ANALYSIS ===';
    
    -- Get payment amount
    SELECT amount INTO v_payment_amount
    FROM public.electronic_payments 
    WHERE id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca';
    
    RAISE NOTICE 'Payment Amount: % EGP', v_payment_amount;
    
    -- Get client transaction
    SELECT * INTO v_client_transaction
    FROM public.wallet_transactions 
    WHERE wallet_id = '69fe870b-3439-4d4f-a0f3-f7c93decd79a'
    AND reference_type = 'electronic_payment'
    AND reference_id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca'
    ORDER BY created_at DESC
    LIMIT 1;
    
    -- Get business transaction
    SELECT wt.* INTO v_business_transaction
    FROM public.wallet_transactions wt
    JOIN public.wallets w ON wt.wallet_id = w.id
    WHERE w.wallet_type = 'business'
    AND wt.reference_type = 'electronic_payment'
    AND wt.reference_id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca'
    ORDER BY wt.created_at DESC
    LIMIT 1;
    
    -- Calculate balance changes
    v_client_balance_change := v_client_transaction.balance_after - v_client_transaction.balance_before;
    v_business_balance_change := v_business_transaction.balance_after - v_business_transaction.balance_before;
    v_total_change := v_client_balance_change + v_business_balance_change;
    
    RAISE NOTICE 'Client Balance Change: % EGP (% → %)', 
        v_client_balance_change, v_client_transaction.balance_before, v_client_transaction.balance_after;
    RAISE NOTICE 'Business Balance Change: % EGP (% → %)', 
        v_business_balance_change, v_business_transaction.balance_before, v_business_transaction.balance_after;
    RAISE NOTICE 'Total System Change: % EGP', v_total_change;
    
    -- Verification checks
    IF v_client_balance_change = -v_payment_amount THEN
        RAISE NOTICE '✅ Client debit amount is correct';
    ELSE
        RAISE NOTICE '❌ Client debit amount is INCORRECT: expected %, got %', -v_payment_amount, v_client_balance_change;
    END IF;
    
    IF v_business_balance_change = v_payment_amount THEN
        RAISE NOTICE '✅ Business credit amount is correct';
    ELSE
        RAISE NOTICE '❌ Business credit amount is INCORRECT: expected %, got %', v_payment_amount, v_business_balance_change;
    END IF;
    
    IF v_total_change = 0 THEN
        RAISE NOTICE '✅ BALANCE CONSERVATION: Total system change is 0 (no money created or lost)';
    ELSE
        RAISE NOTICE '❌ BALANCE CONSERVATION FAILED: Total system change is % (money was created or lost!)', v_total_change;
    END IF;
    
    IF v_client_transaction.transaction_type = 'debit' THEN
        RAISE NOTICE '✅ Client transaction type is correct (debit)';
    ELSE
        RAISE NOTICE '❌ Client transaction type is INCORRECT: expected debit, got %', v_client_transaction.transaction_type;
    END IF;
    
    IF v_business_transaction.transaction_type = 'credit' THEN
        RAISE NOTICE '✅ Business transaction type is correct (credit)';
    ELSE
        RAISE NOTICE '❌ Business transaction type is INCORRECT: expected credit, got %', v_business_transaction.transaction_type;
    END IF;
    
    IF v_client_transaction.reference_type = 'electronic_payment' AND v_business_transaction.reference_type = 'electronic_payment' THEN
        RAISE NOTICE '✅ Both transactions have correct reference_type (electronic_payment)';
    ELSE
        RAISE NOTICE '❌ Reference type INCORRECT: client=%, business=%', v_client_transaction.reference_type, v_business_transaction.reference_type;
    END IF;
    
END $$;

-- Step 7: Transaction Timing Verification
SELECT 
    '=== TRANSACTION TIMING VERIFICATION ===' as section,
    'Client Transaction' as transaction_source,
    created_at as transaction_time
FROM public.wallet_transactions 
WHERE wallet_id = '69fe870b-3439-4d4f-a0f3-f7c93decd79a'
AND reference_type = 'electronic_payment'
AND reference_id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca'

UNION ALL

SELECT 
    '=== TRANSACTION TIMING VERIFICATION ===' as section,
    'Business Transaction' as transaction_source,
    wt.created_at as transaction_time
FROM public.wallet_transactions wt
JOIN public.wallets w ON wt.wallet_id = w.id
WHERE w.wallet_type = 'business'
AND wt.reference_type = 'electronic_payment'
AND wt.reference_id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca'

UNION ALL

SELECT 
    '=== TRANSACTION TIMING VERIFICATION ===' as section,
    'Payment Approval' as transaction_source,
    approved_at as transaction_time
FROM public.electronic_payments 
WHERE id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca'

ORDER BY transaction_time;

-- Step 8: Final Summary
DO $$
DECLARE
    v_payment_status TEXT;
    v_client_balance DECIMAL(15,2);
    v_business_balance DECIMAL(15,2);
    v_client_transactions INTEGER;
    v_business_transactions INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== FINAL VERIFICATION SUMMARY ===';
    
    -- Get current status
    SELECT status INTO v_payment_status
    FROM public.electronic_payments 
    WHERE id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca';
    
    SELECT balance INTO v_client_balance
    FROM public.wallets 
    WHERE id = '69fe870b-3439-4d4f-a0f3-f7c93decd79a';
    
    SELECT balance INTO v_business_balance
    FROM public.wallets 
    WHERE wallet_type = 'business' AND is_active = true;
    
    -- Count transactions
    SELECT COUNT(*) INTO v_client_transactions
    FROM public.wallet_transactions 
    WHERE wallet_id = '69fe870b-3439-4d4f-a0f3-f7c93decd79a'
    AND reference_type = 'electronic_payment'
    AND reference_id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca';
    
    SELECT COUNT(*) INTO v_business_transactions
    FROM public.wallet_transactions wt
    JOIN public.wallets w ON wt.wallet_id = w.id
    WHERE w.wallet_type = 'business'
    AND wt.reference_type = 'electronic_payment'
    AND wt.reference_id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca';
    
    RAISE NOTICE 'Payment Status: %', v_payment_status;
    RAISE NOTICE 'Client Wallet Balance: % EGP', v_client_balance;
    RAISE NOTICE 'Business Wallet Balance: % EGP', v_business_balance;
    RAISE NOTICE 'Client Transactions Created: %', v_client_transactions;
    RAISE NOTICE 'Business Transactions Created: %', v_business_transactions;
    
    -- Overall assessment
    IF v_payment_status = 'approved' AND 
       v_client_balance = 158800 AND 
       v_business_balance = 1000 AND
       v_client_transactions = 1 AND 
       v_business_transactions = 1 THEN
        RAISE NOTICE '';
        RAISE NOTICE '🎉 VERIFICATION PASSED: Dual wallet transaction is working correctly!';
        RAISE NOTICE '✅ All balance updates are accurate';
        RAISE NOTICE '✅ Money conservation is maintained';
        RAISE NOTICE '✅ Transaction records are properly created';
        RAISE NOTICE '✅ Electronic payment approval is functioning correctly';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '❌ VERIFICATION FAILED: Issues detected in dual wallet transaction';
    END IF;
    
END $$;
