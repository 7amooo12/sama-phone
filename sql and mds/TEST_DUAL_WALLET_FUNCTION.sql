-- =====================================================
-- TEST SCRIPT FOR DUAL WALLET TRANSACTION FUNCTION
-- =====================================================
-- This script tests the process_dual_wallet_transaction function
-- with your specific payment data

-- =====================================================
-- 1. VERIFY FUNCTION EXISTS
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_schema = 'public' 
        AND routine_name = 'process_dual_wallet_transaction'
    ) THEN
        RAISE EXCEPTION 'Function process_dual_wallet_transaction does not exist. Please run CREATE_DUAL_WALLET_TRANSACTION_FUNCTION.sql first.';
    ELSE
        RAISE NOTICE '✅ Function process_dual_wallet_transaction exists';
    END IF;
END $$;

-- =====================================================
-- 2. CHECK CURRENT DATA STATE
-- =====================================================

-- Check the specific payment from your error
SELECT 
    id,
    client_id,
    amount,
    status,
    created_at,
    proof_image_url
FROM public.electronic_payments 
WHERE id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca';

-- Check client wallet
SELECT 
    w.id as wallet_id,
    w.user_id,
    w.balance,
    w.currency,
    w.is_active,
    up.name as user_name
FROM public.wallets w
LEFT JOIN public.user_profiles up ON w.user_id = up.id
WHERE w.user_id = 'aaaaf98e-f3aa-489d-9586-573332ff6301';

-- Check if business wallet exists
SELECT 
    id,
    wallet_type,
    balance,
    currency,
    is_active
FROM public.wallets 
WHERE wallet_type = 'business';

-- =====================================================
-- 3. VALIDATION TEST
-- =====================================================

-- Test validation function with your specific data
DO $$
DECLARE
    v_validation_result JSON;
    v_client_wallet_id UUID;
BEGIN
    -- Get client wallet ID
    SELECT id INTO v_client_wallet_id
    FROM public.wallets
    WHERE user_id = 'aaaaf98e-f3aa-489d-9586-573332ff6301'
    LIMIT 1;
    
    IF v_client_wallet_id IS NULL THEN
        RAISE NOTICE '❌ Client wallet not found for user: aaaaf98e-f3aa-489d-9586-573332ff6301';
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Testing validation with:';
    RAISE NOTICE '   Payment ID: c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca';
    RAISE NOTICE '   Client Wallet ID: %', v_client_wallet_id;
    RAISE NOTICE '   Amount: 1000.0';
    
    -- Test validation
    SELECT public.validate_payment_approval(
        'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca'::UUID,
        v_client_wallet_id,
        1000.0
    ) INTO v_validation_result;
    
    RAISE NOTICE '📊 Validation Result: %', v_validation_result;
    
    -- Check if validation passed
    IF (v_validation_result->>'valid')::boolean = true THEN
        RAISE NOTICE '✅ Validation passed - ready for transaction';
    ELSE
        RAISE NOTICE '❌ Validation failed: %', v_validation_result->>'error';
    END IF;
END $$;

-- =====================================================
-- 4. DRY RUN TEST (SIMULATION)
-- =====================================================

-- Simulate the transaction without actually executing it
DO $$
DECLARE
    v_client_wallet_id UUID;
    v_business_wallet_id UUID;
    v_client_balance DECIMAL(15,2);
    v_business_balance DECIMAL(15,2);
    v_amount DECIMAL(15,2) := 1000.0;
BEGIN
    RAISE NOTICE '🧪 SIMULATION MODE - No actual changes will be made';
    RAISE NOTICE '================================================';
    
    -- Get client wallet
    SELECT id, balance INTO v_client_wallet_id, v_client_balance
    FROM public.wallets
    WHERE user_id = 'aaaaf98e-f3aa-489d-9586-573332ff6301'
    LIMIT 1;
    
    -- Get or simulate business wallet
    SELECT id, balance INTO v_business_wallet_id, v_business_balance
    FROM public.wallets
    WHERE wallet_type = 'business'
    LIMIT 1;
    
    IF v_business_wallet_id IS NULL THEN
        v_business_balance := 0.0;
        RAISE NOTICE '📝 Business wallet would be created with balance: 0.0';
    END IF;
    
    RAISE NOTICE '📊 Current State:';
    RAISE NOTICE '   Client Wallet ID: %', v_client_wallet_id;
    RAISE NOTICE '   Client Balance: %', v_client_balance;
    RAISE NOTICE '   Business Wallet ID: %', COALESCE(v_business_wallet_id::text, 'Would be created');
    RAISE NOTICE '   Business Balance: %', v_business_balance;
    RAISE NOTICE '   Transaction Amount: %', v_amount;
    
    RAISE NOTICE '🔄 After Transaction (Simulated):';
    RAISE NOTICE '   Client Balance: % → %', v_client_balance, v_client_balance - v_amount;
    RAISE NOTICE '   Business Balance: % → %', v_business_balance, v_business_balance + v_amount;
    
    -- Check if transaction would succeed
    IF v_client_balance >= v_amount THEN
        RAISE NOTICE '✅ Transaction would succeed';
    ELSE
        RAISE NOTICE '❌ Transaction would fail - insufficient balance';
    END IF;
END $$;

-- =====================================================
-- 5. ACTUAL TRANSACTION TEST (COMMENTED OUT)
-- =====================================================

-- UNCOMMENT THE FOLLOWING BLOCK TO EXECUTE THE ACTUAL TRANSACTION
-- WARNING: This will modify your database!

/*
DO $$
DECLARE
    v_client_wallet_id UUID;
    v_approved_by UUID;
    v_result JSON;
BEGIN
    RAISE NOTICE '🚀 EXECUTING ACTUAL TRANSACTION';
    RAISE NOTICE '================================';
    
    -- Get client wallet ID
    SELECT id INTO v_client_wallet_id
    FROM public.wallets
    WHERE user_id = 'aaaaf98e-f3aa-489d-9586-573332ff6301'
    LIMIT 1;
    
    -- Get an admin user ID for approved_by (replace with actual admin ID)
    SELECT id INTO v_approved_by
    FROM public.user_profiles
    WHERE role IN ('admin', 'accountant')
    LIMIT 1;
    
    IF v_approved_by IS NULL THEN
        RAISE EXCEPTION 'No admin user found for approval';
    END IF;
    
    RAISE NOTICE '📋 Executing transaction with:';
    RAISE NOTICE '   Payment ID: c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca';
    RAISE NOTICE '   Client Wallet: %', v_client_wallet_id;
    RAISE NOTICE '   Amount: 1000.0';
    RAISE NOTICE '   Approved By: %', v_approved_by;
    
    -- Execute the transaction
    SELECT public.process_dual_wallet_transaction(
        'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca'::UUID,  -- payment_id
        v_client_wallet_id,                              -- client_wallet_id
        1000.0,                                          -- amount
        v_approved_by,                                   -- approved_by
        'Test approval via SQL function',                -- admin_notes
        NULL                                             -- business_wallet_id (auto-create)
    ) INTO v_result;
    
    RAISE NOTICE '✅ Transaction completed successfully!';
    RAISE NOTICE '📊 Result: %', v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Transaction failed: %', SQLERRM;
        RAISE EXCEPTION 'Transaction failed: %', SQLERRM;
END $$;
*/

-- =====================================================
-- 6. POST-TRANSACTION VERIFICATION
-- =====================================================

-- Check payment status after transaction
SELECT 
    id,
    status,
    approved_by,
    approved_at,
    admin_notes,
    updated_at
FROM public.electronic_payments 
WHERE id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca';

-- Check wallet balances after transaction
SELECT 
    w.id,
    w.wallet_type,
    w.balance,
    w.updated_at,
    up.name as owner_name
FROM public.wallets w
LEFT JOIN public.user_profiles up ON w.user_id = up.id
WHERE w.user_id = 'aaaaf98e-f3aa-489d-9586-573332ff6301'
   OR w.wallet_type = 'business';

-- Check transaction history
SELECT 
    wt.id,
    wt.wallet_id,
    wt.transaction_type,
    wt.amount,
    wt.balance_before,
    wt.balance_after,
    wt.reference_type,
    wt.reference_id,
    wt.description,
    wt.created_at
FROM public.wallet_transactions wt
WHERE wt.reference_id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca'
ORDER BY wt.created_at DESC;

-- =====================================================
-- 7. FUNCTION USAGE EXAMPLES
-- =====================================================

-- Example 1: Basic approval
/*
SELECT public.process_dual_wallet_transaction(
    'payment-uuid'::UUID,
    'client-wallet-uuid'::UUID,
    100.00,
    'admin-user-uuid'::UUID,
    'Approved by admin',
    NULL
);
*/

-- Example 2: With specific business wallet
/*
SELECT public.process_dual_wallet_transaction(
    'payment-uuid'::UUID,
    'client-wallet-uuid'::UUID,
    100.00,
    'admin-user-uuid'::UUID,
    'Approved with custom business wallet',
    'business-wallet-uuid'::UUID
);
*/

-- Example 3: Validation before approval
/*
SELECT public.validate_payment_approval(
    'payment-uuid'::UUID,
    'client-wallet-uuid'::UUID,
    100.00
);
*/

RAISE NOTICE '🎯 Test script completed!';
RAISE NOTICE '📝 To execute the actual transaction, uncomment the transaction block in section 5';
RAISE NOTICE '⚠️  Always test in a development environment first';
