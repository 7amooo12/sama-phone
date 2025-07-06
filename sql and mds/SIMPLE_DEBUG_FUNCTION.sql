-- =====================================================
-- SIMPLE DEBUG FOR DUAL WALLET FUNCTION ISSUE
-- =====================================================
-- This script provides essential diagnostic information

-- Check 1: Current function signatures
SELECT 
    'FUNCTION SIGNATURES:' as check_type,
    oid::regprocedure::text as function_signature,
    pronargs as parameter_count
FROM pg_proc 
WHERE proname = 'process_dual_wallet_transaction' 
AND pronamespace = 'public'::regnamespace
ORDER BY oid;

-- Check 2: Function source code (first 500 characters)
SELECT 
    'FUNCTION SOURCE:' as check_type,
    LEFT(prosrc, 500) as source_preview
FROM pg_proc 
WHERE proname = 'process_dual_wallet_transaction' 
AND pronamespace = 'public'::regnamespace
LIMIT 1;

-- Check 3: Constraint status
SELECT 
    'CONSTRAINT STATUS:' as check_type,
    pg_get_constraintdef(oid) as constraint_definition,
    CASE 
        WHEN pg_get_constraintdef(oid) LIKE '%electronic_payment%' THEN 'INCLUDES electronic_payment'
        ELSE 'MISSING electronic_payment'
    END as status
FROM pg_constraint 
WHERE conrelid = 'public.wallet_transactions'::regclass 
AND conname = 'wallet_transactions_reference_type_valid';

-- Check 4: Payment data
SELECT 
    'PAYMENT DATA:' as check_type,
    id as payment_id,
    client_id,
    amount,
    status,
    created_at
FROM public.electronic_payments 
WHERE id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca';

-- Check 5: Client wallet data
SELECT 
    'CLIENT WALLET:' as check_type,
    w.id as wallet_id,
    w.user_id as client_id,
    w.balance,
    w.is_active,
    w.wallet_type
FROM public.wallets w
WHERE w.user_id = 'aaaaf98e-f3aa-489d-9586-573332ff6301'
AND w.is_active = true;

-- Check 6: Function parameter analysis
DO $$
DECLARE
    function_source TEXT;
    uses_p_payment_id BOOLEAN := FALSE;
    uses_client_user_id BOOLEAN := FALSE;
    uses_electronic_payment BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE '=== FUNCTION ANALYSIS ===';
    
    -- Get function source
    SELECT prosrc INTO function_source
    FROM pg_proc 
    WHERE proname = 'process_dual_wallet_transaction' 
    AND pronamespace = 'public'::regnamespace
    LIMIT 1;
    
    IF function_source IS NULL THEN
        RAISE NOTICE '❌ Function not found';
        RETURN;
    END IF;
    
    -- Check parameter usage
    uses_p_payment_id := function_source LIKE '%p_payment_id%';
    uses_client_user_id := function_source LIKE '%client_user_id%';
    uses_electronic_payment := function_source LIKE '%electronic_payment%';
    
    RAISE NOTICE 'Function parameter analysis:';
    RAISE NOTICE '  Uses p_payment_id: %', uses_p_payment_id;
    RAISE NOTICE '  Uses client_user_id: %', uses_client_user_id;
    RAISE NOTICE '  Uses electronic_payment: %', uses_electronic_payment;
    
    -- Check payment lookup method
    IF function_source LIKE '%WHERE id = p_payment_id%' THEN
        RAISE NOTICE '✅ Function looks up payment by p_payment_id (CORRECT)';
    ELSIF function_source LIKE '%WHERE user_id = client_user_id%' THEN
        RAISE NOTICE '❌ Function looks up payment by client_user_id (WRONG)';
    ELSE
        RAISE NOTICE '⚠️  Cannot determine payment lookup method';
    END IF;
    
    -- Overall assessment
    IF uses_p_payment_id AND uses_electronic_payment THEN
        RAISE NOTICE '✅ Function appears to be CORRECT version';
    ELSE
        RAISE NOTICE '❌ Function appears to be WRONG version';
        RAISE NOTICE '🔧 Need to run FORCE_FIX_DUAL_WALLET_FUNCTION.sql';
    END IF;
    
END $$;

-- Manual cache refresh instruction
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '💡 MANUAL STEPS:';
    RAISE NOTICE '1. If function is wrong, run: FORCE_FIX_DUAL_WALLET_FUNCTION.sql';
    RAISE NOTICE '2. If constraint is missing electronic_payment, run: SIMPLE_CONSTRAINT_FIX.sql';
    RAISE NOTICE '3. To refresh function cache manually, run: DISCARD ALL;';
    RAISE NOTICE '4. Test electronic payment approval in Flutter app';
END $$;
