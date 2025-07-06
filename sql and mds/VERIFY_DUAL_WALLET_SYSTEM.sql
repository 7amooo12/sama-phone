-- ============================================================================
-- VERIFY DUAL WALLET SYSTEM
-- ============================================================================
-- Quick verification script to check if dual wallet system is properly set up

-- Check if required functions exist
DO $$
BEGIN
    RAISE NOTICE '=== DUAL WALLET SYSTEM VERIFICATION ===';
    RAISE NOTICE '';
    
    RAISE NOTICE '=== CHECKING REQUIRED FUNCTIONS ===';
    
    -- Check process_dual_wallet_transaction
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'process_dual_wallet_transaction') THEN
        RAISE NOTICE '✅ process_dual_wallet_transaction function exists';
    ELSE
        RAISE NOTICE '❌ process_dual_wallet_transaction function MISSING';
    END IF;
    
    -- Check update_client_wallet_balance
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'update_client_wallet_balance') THEN
        RAISE NOTICE '✅ update_client_wallet_balance function exists';
    ELSE
        RAISE NOTICE '❌ update_client_wallet_balance function MISSING';
    END IF;
    
    -- Check update_electronic_wallet_balance
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'update_electronic_wallet_balance') THEN
        RAISE NOTICE '✅ update_electronic_wallet_balance function exists';
    ELSE
        RAISE NOTICE '❌ update_electronic_wallet_balance function MISSING';
    END IF;
    
    -- Check approval trigger function
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'handle_electronic_payment_approval_v3') THEN
        RAISE NOTICE '✅ handle_electronic_payment_approval_v3 function exists';
    ELSE
        RAISE NOTICE '❌ handle_electronic_payment_approval_v3 function MISSING';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== CHECKING TRIGGERS ===';
    
    -- Check if trigger exists
    IF EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name LIKE '%electronic_payment_approval%'
    ) THEN
        RAISE NOTICE '✅ Electronic payment approval trigger exists';
    ELSE
        RAISE NOTICE '❌ Electronic payment approval trigger MISSING';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== CHECKING TABLES ===';
    
    -- Check required tables
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'wallets') THEN
        RAISE NOTICE '✅ wallets table exists';
    ELSE
        RAISE NOTICE '❌ wallets table MISSING';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'electronic_wallets') THEN
        RAISE NOTICE '✅ electronic_wallets table exists';
    ELSE
        RAISE NOTICE '❌ electronic_wallets table MISSING';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'electronic_payments') THEN
        RAISE NOTICE '✅ electronic_payments table exists';
    ELSE
        RAISE NOTICE '❌ electronic_payments table MISSING';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payment_accounts') THEN
        RAISE NOTICE '✅ payment_accounts table exists';
    ELSE
        RAISE NOTICE '❌ payment_accounts table MISSING';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'wallet_transactions') THEN
        RAISE NOTICE '✅ wallet_transactions table exists';
    ELSE
        RAISE NOTICE '❌ wallet_transactions table MISSING';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'electronic_wallet_transactions') THEN
        RAISE NOTICE '✅ electronic_wallet_transactions table exists';
    ELSE
        RAISE NOTICE '❌ electronic_wallet_transactions table MISSING';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== SYSTEM STATUS SUMMARY ===';
    
    -- Count existing data
    DECLARE
        wallet_count INTEGER;
        electronic_wallet_count INTEGER;
        payment_count INTEGER;
        pending_payment_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO wallet_count FROM public.wallets;
        SELECT COUNT(*) INTO electronic_wallet_count FROM public.electronic_wallets;
        SELECT COUNT(*) INTO payment_count FROM public.electronic_payments;
        SELECT COUNT(*) INTO pending_payment_count FROM public.electronic_payments WHERE status = 'pending';
        
        RAISE NOTICE 'Client wallets: %', wallet_count;
        RAISE NOTICE 'Electronic wallets: %', electronic_wallet_count;
        RAISE NOTICE 'Total electronic payments: %', payment_count;
        RAISE NOTICE 'Pending payments: %', pending_payment_count;
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== VERIFICATION COMPLETED ===';
    
END;
$$;

-- Display function signatures for reference
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_name IN (
    'process_dual_wallet_transaction',
    'update_client_wallet_balance', 
    'update_electronic_wallet_balance',
    'handle_electronic_payment_approval_v3'
)
ORDER BY routine_name;

-- Display trigger information
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers 
WHERE trigger_name LIKE '%electronic_payment_approval%'
ORDER BY trigger_name;

-- Check wallet synchronization status
SELECT 
    'Wallet Synchronization Status' as check_type,
    COUNT(ew.id) as electronic_wallets,
    COUNT(pa.id) as payment_accounts,
    COUNT(ew.id) - COUNT(pa.id) as sync_difference
FROM public.electronic_wallets ew
LEFT JOIN public.payment_accounts pa ON ew.id = pa.id;

-- Check for any pending payments with potential balance issues
SELECT 
    'Pending Payments Balance Check' as check_type,
    COUNT(*) as total_pending,
    COUNT(CASE WHEN w.balance >= ep.amount THEN 1 END) as sufficient_balance,
    COUNT(CASE WHEN w.balance < ep.amount THEN 1 END) as insufficient_balance
FROM public.electronic_payments ep
JOIN public.wallets w ON ep.client_id = w.user_id
WHERE ep.status = 'pending';

-- Sample of recent transactions (if any)
SELECT 
    'Recent Dual Wallet Transactions' as info,
    ep.id as payment_id,
    ep.amount,
    ep.status,
    ep.created_at,
    CASE WHEN wt.id IS NOT NULL THEN 'Yes' ELSE 'No' END as has_client_transaction,
    CASE WHEN ewt.id IS NOT NULL THEN 'Yes' ELSE 'No' END as has_electronic_transaction
FROM public.electronic_payments ep
LEFT JOIN public.wallet_transactions wt ON ep.id::TEXT = wt.reference_id
LEFT JOIN public.electronic_wallet_transactions ewt ON ep.id::TEXT = ewt.payment_id
WHERE ep.status = 'approved'
ORDER BY ep.approved_at DESC
LIMIT 5;
