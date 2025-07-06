-- =====================================================
-- DEBUG DUAL WALLET FUNCTION ISSUE
-- =====================================================
-- This script diagnoses why the function is still using wrong parameters

-- Step 1: Check all existing function signatures
SELECT 
    'Current Function Signatures:' as info,
    oid::regprocedure::text as function_signature,
    pronargs as parameter_count
FROM pg_proc 
WHERE proname = 'process_dual_wallet_transaction' 
AND pronamespace = 'public'::regnamespace
ORDER BY oid;

-- Step 2: Check function source code
SELECT 
    'Function Source Code:' as info,
    prosrc as source_code
FROM pg_proc 
WHERE proname = 'process_dual_wallet_transaction' 
AND pronamespace = 'public'::regnamespace
LIMIT 1;

-- Step 3: Check if constraint includes electronic_payment
SELECT 
    'Constraint Check:' as info,
    pg_get_constraintdef(oid) as constraint_definition,
    CASE 
        WHEN pg_get_constraintdef(oid) LIKE '%electronic_payment%' THEN 'INCLUDES electronic_payment'
        ELSE 'MISSING electronic_payment'
    END as status
FROM pg_constraint 
WHERE conrelid = 'public.wallet_transactions'::regclass 
AND conname = 'wallet_transactions_reference_type_valid';

-- Step 4: Check the specific payment data
SELECT 
    'Payment Data Check:' as info,
    id as payment_id,
    client_id,
    amount,
    status,
    created_at
FROM public.electronic_payments 
WHERE id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca';

-- Step 5: Test function call with correct parameters
DO $$
DECLARE
    test_result JSON;
    payment_data RECORD;
    client_wallet_id UUID;
BEGIN
    RAISE NOTICE '🧪 Testing function call with correct parameters...';
    
    -- Get payment data
    SELECT * INTO payment_data
    FROM public.electronic_payments 
    WHERE id = 'c0c851f5-ad62-479a-b6ce-a9bc44f7d2ca';
    
    IF NOT FOUND THEN
        RAISE NOTICE '❌ Payment not found';
        RETURN;
    END IF;
    
    -- Get client wallet
    SELECT id INTO client_wallet_id
    FROM public.wallets
    WHERE user_id = payment_data.client_id AND is_active = true;
    
    IF client_wallet_id IS NULL THEN
        RAISE NOTICE '❌ Client wallet not found';
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Test parameters:';
    RAISE NOTICE '   p_payment_id: %', payment_data.id;
    RAISE NOTICE '   p_client_wallet_id: %', client_wallet_id;
    RAISE NOTICE '   p_amount: %', payment_data.amount;
    RAISE NOTICE '   p_approved_by: 4ac083bc-3e05-4456-8579-0877d2627b15';
    
    -- Test the function call (this should work if function is correct)
    BEGIN
        SELECT public.process_dual_wallet_transaction(
            payment_data.id,                                    -- p_payment_id (UUID)
            client_wallet_id,                                   -- p_client_wallet_id (UUID)
            payment_data.amount,                                -- p_amount (NUMERIC)
            '4ac083bc-3e05-4456-8579-0877d2627b15'::UUID,      -- p_approved_by (UUID)
            'Test function call',                               -- p_admin_notes (TEXT)
            NULL                                                -- p_business_wallet_id (UUID)
        ) INTO test_result;
        
        RAISE NOTICE '✅ Function call succeeded: %', test_result;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Function call failed: %', SQLERRM;
            
            -- Check if error mentions client_id instead of payment_id
            IF SQLERRM LIKE '%aaaaf98e-f3aa-489d-9586-573332ff6301%' THEN
                RAISE NOTICE '🚨 ERROR ANALYSIS: Function is still using CLIENT_ID instead of PAYMENT_ID!';
                RAISE NOTICE '🔧 This means the wrong function version is still active';
            END IF;
    END;
    
END $$;

-- Step 6: Function cache refresh (manual step)
-- Note: Run 'DISCARD ALL;' manually outside this script if needed to refresh function cache

-- Step 7: Final verification
DO $$
DECLARE
    function_count INTEGER;
    latest_function_oid OID;
    function_source TEXT;
BEGIN
    RAISE NOTICE '🔍 Final verification...';
    
    -- Count functions
    SELECT COUNT(*) INTO function_count
    FROM pg_proc 
    WHERE proname = 'process_dual_wallet_transaction' 
    AND pronamespace = 'public'::regnamespace;
    
    RAISE NOTICE '📊 Found % function(s) with name process_dual_wallet_transaction', function_count;
    
    IF function_count > 1 THEN
        RAISE NOTICE '⚠️  Multiple function versions detected - this could cause conflicts';
        
        -- Show all versions
        FOR latest_function_oid IN 
            SELECT oid 
            FROM pg_proc 
            WHERE proname = 'process_dual_wallet_transaction' 
            AND pronamespace = 'public'::regnamespace
            ORDER BY oid
        LOOP
            SELECT oid::regprocedure::text INTO function_source
            FROM pg_proc WHERE oid = latest_function_oid;
            
            RAISE NOTICE '   Function version: %', function_source;
        END LOOP;
    END IF;
    
    -- Get the latest function source to check if it uses p_payment_id
    SELECT prosrc INTO function_source
    FROM pg_proc 
    WHERE proname = 'process_dual_wallet_transaction' 
    AND pronamespace = 'public'::regnamespace
    ORDER BY oid DESC
    LIMIT 1;
    
    IF function_source LIKE '%p_payment_id%' THEN
        RAISE NOTICE '✅ Latest function uses p_payment_id parameter';
    ELSE
        RAISE NOTICE '❌ Latest function does NOT use p_payment_id parameter';
    END IF;
    
    IF function_source LIKE '%WHERE id = p_payment_id%' THEN
        RAISE NOTICE '✅ Function correctly looks up payment by p_payment_id';
    ELSE
        RAISE NOTICE '❌ Function does NOT look up payment by p_payment_id';
    END IF;
    
END $$;
