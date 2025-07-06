-- =====================================================
-- TEST WALLET SCHEMA FIX
-- Verifies that the metadata schema error is resolved
-- =====================================================

-- STEP 1: VERIFY CURRENT SCHEMA
-- =====================================================

SELECT '=== TESTING WALLET SCHEMA FIX ===' as section;

-- Check if all required columns exist
SELECT
    'Schema verification' as test_name,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'wallets'
            AND column_name = 'metadata'
        ) THEN '✅ metadata column exists'
        ELSE '❌ metadata column missing'
    END as metadata_check,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'wallets'
            AND column_name = 'wallet_type'
        ) THEN '✅ wallet_type column exists'
        ELSE '❌ wallet_type column missing'
    END as wallet_type_check,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'wallets'
            AND column_name = 'is_active'
        ) THEN '✅ is_active column exists'
        ELSE '❌ is_active column missing'
    END as is_active_check;

-- STEP 2: TEST BUSINESS WALLET CREATION
-- =====================================================

DO $$
DECLARE
    business_wallet_id UUID;
    test_result TEXT;
BEGIN
    RAISE NOTICE '=== TESTING BUSINESS WALLET CREATION ===';

    -- Test business wallet creation
    BEGIN
        SELECT public.get_or_create_business_wallet() INTO business_wallet_id;

        IF business_wallet_id IS NOT NULL THEN
            test_result := '✅ Business wallet creation successful: ' || business_wallet_id::TEXT;
        ELSE
            test_result := '❌ Business wallet creation returned NULL';
        END IF;

        RAISE NOTICE '%', test_result;

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Business wallet creation failed: %', SQLERRM;
    END;
END $$;

-- STEP 3: TEST CLIENT WALLET CREATION
-- =====================================================

DO $$
DECLARE
    client_wallet_id UUID;
    test_user_id UUID := '12345678-1234-1234-1234-123456789012'::UUID; -- Test UUID
    test_result TEXT;
BEGIN
    RAISE NOTICE '=== TESTING CLIENT WALLET CREATION ===';

    -- Test client wallet creation
    BEGIN
        SELECT public.get_or_create_client_wallet(test_user_id) INTO client_wallet_id;

        IF client_wallet_id IS NOT NULL THEN
            test_result := '✅ Client wallet creation successful: ' || client_wallet_id::TEXT;
        ELSE
            test_result := '❌ Client wallet creation returned NULL';
        END IF;

        RAISE NOTICE '%', test_result;

        -- Clean up test wallet
        DELETE FROM public.wallets WHERE id = client_wallet_id;
        RAISE NOTICE 'ℹ️ Cleaned up test client wallet';

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Client wallet creation failed: %', SQLERRM;
    END;
END $$;

-- STEP 4: TEST DUAL WALLET TRANSACTION FUNCTION
-- =====================================================

DO $$
DECLARE
    function_exists BOOLEAN := false;
BEGIN
    RAISE NOTICE '=== TESTING DUAL WALLET TRANSACTION FUNCTION ===';

    -- Check if the function exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'process_dual_wallet_transaction'
    ) INTO function_exists;

    IF function_exists THEN
        RAISE NOTICE '✅ process_dual_wallet_transaction function exists';
    ELSE
        RAISE NOTICE '❌ process_dual_wallet_transaction function missing';
    END IF;
END $$;

-- STEP 5: VERIFY WALLET TABLE STRUCTURE
-- =====================================================

SELECT 
    '=== FINAL WALLET TABLE STRUCTURE ===' as verification,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'wallets'
ORDER BY ordinal_position;

-- STEP 6: CHECK FOR BUSINESS WALLETS
-- =====================================================

SELECT 
    '=== CURRENT BUSINESS WALLETS ===' as check_name,
    id,
    user_id,
    COALESCE(wallet_type, 'N/A') as wallet_type,
    role,
    balance,
    status,
    COALESCE(is_active::TEXT, 'N/A') as is_active
FROM public.wallets 
WHERE role = 'admin' OR (
    EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND column_name = 'wallet_type'
    ) AND wallet_type = 'business'
)
ORDER BY created_at;

-- STEP 7: SUMMARY
-- =====================================================

DO $$
DECLARE
    metadata_exists BOOLEAN;
    wallet_type_exists BOOLEAN;
    is_active_exists BOOLEAN;
    business_wallet_count INTEGER;
    function_exists BOOLEAN;
BEGIN
    -- Check column existence
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'wallets' AND column_name = 'metadata'
    ) INTO metadata_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'wallets' AND column_name = 'wallet_type'
    ) INTO wallet_type_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'wallets' AND column_name = 'is_active'
    ) INTO is_active_exists;
    
    -- Check business wallets
    SELECT COUNT(*) INTO business_wallet_count
    FROM public.wallets 
    WHERE role = 'admin' OR (wallet_type_exists AND wallet_type = 'business');
    
    -- Check function existence
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_schema = 'public' AND routine_name = 'process_dual_wallet_transaction'
    ) INTO function_exists;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== WALLET SCHEMA FIX TEST SUMMARY ===';
    RAISE NOTICE 'metadata column: %', CASE WHEN metadata_exists THEN '✅ EXISTS' ELSE '❌ MISSING' END;
    RAISE NOTICE 'wallet_type column: %', CASE WHEN wallet_type_exists THEN '✅ EXISTS' ELSE '❌ MISSING' END;
    RAISE NOTICE 'is_active column: %', CASE WHEN is_active_exists THEN '✅ EXISTS' ELSE '❌ MISSING' END;
    RAISE NOTICE 'Business wallets count: %', business_wallet_count;
    RAISE NOTICE 'Dual wallet function: %', CASE WHEN function_exists THEN '✅ EXISTS' ELSE '❌ MISSING' END;
    RAISE NOTICE '';
    
    IF metadata_exists AND wallet_type_exists AND is_active_exists AND business_wallet_count > 0 AND function_exists THEN
        RAISE NOTICE '🎉 ALL TESTS PASSED! Electronic payment system should work properly.';
    ELSE
        RAISE NOTICE '⚠️ Some issues detected. Please review the test results above.';
    END IF;
    
    RAISE NOTICE 'Test completed at: %', NOW();
END $$;
