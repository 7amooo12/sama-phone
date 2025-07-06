-- 🧪 اختبار إصلاح مشكلة PGRST116 - Test Script
-- Verification script for PGRST116 duplicate wallet fix

-- STEP 1: VERIFY NO DUPLICATE WALLETS EXIST
-- =====================================================

DO $$
DECLARE
    duplicate_count INTEGER;
    total_users INTEGER;
    total_wallets INTEGER;
    rec RECORD;  -- Added missing RECORD declaration for FOR loop
BEGIN
    RAISE NOTICE '=== اختبار إصلاح مشكلة PGRST116 ===';
    RAISE NOTICE '=== PGRST116 Fix Verification Test ===';
    
    -- Count total statistics
    SELECT COUNT(DISTINCT user_id) INTO total_users FROM public.wallets;
    SELECT COUNT(*) INTO total_wallets FROM public.wallets;
    
    -- Check for duplicate wallets
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT user_id, COUNT(*) as wallet_count
        FROM public.wallets
        GROUP BY user_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    RAISE NOTICE '📊 Database Statistics:';
    RAISE NOTICE '   Total users with wallets: %', total_users;
    RAISE NOTICE '   Total wallet records: %', total_wallets;
    RAISE NOTICE '   Users with multiple wallets: %', duplicate_count;
    
    IF duplicate_count = 0 THEN
        RAISE NOTICE '✅ SUCCESS: No duplicate wallets found!';
        RAISE NOTICE '✅ PGRST116 error should be resolved';
    ELSE
        RAISE NOTICE '❌ FAILURE: % users still have multiple wallets', duplicate_count;
        RAISE NOTICE '❌ PGRST116 error may still occur';
        
        -- Show remaining duplicates
        RAISE NOTICE '🔍 Remaining duplicate wallets:';
        FOR rec IN (
            SELECT 
                user_id,
                COUNT(*) as wallet_count,
                STRING_AGG(id::text, ', ') as wallet_ids
            FROM public.wallets
            GROUP BY user_id
            HAVING COUNT(*) > 1
            LIMIT 5
        ) LOOP
            RAISE NOTICE '   User: % | Count: % | Wallet IDs: %', 
                rec.user_id, rec.wallet_count, rec.wallet_ids;
        END LOOP;
    END IF;
END $$;

-- STEP 2: TEST WALLET QUERY PATTERNS
-- =====================================================

DO $$
DECLARE
    test_user_id UUID;
    wallet_count INTEGER;
    test_balance DECIMAL(15,2);
    test_wallet_id UUID;
BEGIN
    RAISE NOTICE '🧪 Testing wallet query patterns...';
    
    -- Get a sample user ID for testing
    SELECT user_id INTO test_user_id 
    FROM public.wallets 
    LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE '⚠️ No wallets found for testing';
        RETURN;
    END IF;
    
    RAISE NOTICE '👤 Testing with user ID: %', test_user_id;
    
    -- Test 1: Count wallets for user (should be 1)
    SELECT COUNT(*) INTO wallet_count
    FROM public.wallets
    WHERE user_id = test_user_id;
    
    RAISE NOTICE '   Wallet count for user: %', wallet_count;
    
    -- Test 2: Get wallet balance (should not cause PGRST116)
    BEGIN
        SELECT balance INTO test_balance
        FROM public.wallets
        WHERE user_id = test_user_id
        LIMIT 1;
        
        RAISE NOTICE '   ✅ Balance query successful: % EGP', test_balance;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '   ❌ Balance query failed: %', SQLERRM;
    END;
    
    -- Test 3: Get wallet ID (should not cause PGRST116)
    BEGIN
        SELECT id INTO test_wallet_id
        FROM public.wallets
        WHERE user_id = test_user_id
        LIMIT 1;
        
        RAISE NOTICE '   ✅ Wallet ID query successful: %', test_wallet_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '   ❌ Wallet ID query failed: %', SQLERRM;
    END;
    
END $$;

-- STEP 3: TEST DATABASE FUNCTIONS
-- =====================================================

DO $$
DECLARE
    test_user_id UUID;
    function_result UUID;
BEGIN
    RAISE NOTICE '🔧 Testing database functions...';
    
    -- Get a sample user for testing
    SELECT user_id INTO test_user_id 
    FROM public.wallets 
    LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE '⚠️ No users found for function testing';
        RETURN;
    END IF;
    
    -- Test get_or_create_client_wallet function
    BEGIN
        SELECT public.get_or_create_client_wallet(test_user_id) INTO function_result;
        RAISE NOTICE '   ✅ get_or_create_client_wallet successful: %', function_result;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '   ❌ get_or_create_client_wallet failed: %', SQLERRM;
    END;
    
END $$;

-- STEP 4: VERIFY WALLET CONSTRAINTS
-- =====================================================

DO $$
DECLARE
    constraint_exists BOOLEAN;
    column_exists BOOLEAN;
BEGIN
    RAISE NOTICE '🔒 Verifying wallet constraints and schema...';
    
    -- Check unique constraint on user_id
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'wallets_user_id_unique' 
        AND table_name = 'wallets'
    ) INTO constraint_exists;
    
    IF constraint_exists THEN
        RAISE NOTICE '   ✅ Unique constraint on user_id exists';
    ELSE
        RAISE NOTICE '   ⚠️ Unique constraint on user_id missing';
    END IF;
    
    -- Check wallet_type column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'wallets' 
        AND column_name = 'wallet_type'
    ) INTO column_exists;
    
    IF column_exists THEN
        RAISE NOTICE '   ✅ wallet_type column exists';
    ELSE
        RAISE NOTICE '   ⚠️ wallet_type column missing';
    END IF;
    
    -- Check is_active column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'wallets' 
        AND column_name = 'is_active'
    ) INTO column_exists;
    
    IF column_exists THEN
        RAISE NOTICE '   ✅ is_active column exists';
    ELSE
        RAISE NOTICE '   ⚠️ is_active column missing';
    END IF;
    
END $$;

-- STEP 5: SAMPLE DATA VERIFICATION
-- =====================================================

DO $$
DECLARE
    rec RECORD;  -- Added missing RECORD declaration for FOR loop
BEGIN
    RAISE NOTICE '📋 Sample wallet data after cleanup:';
    
    FOR rec IN (
        SELECT 
            user_id,
            id as wallet_id,
            balance,
            COALESCE(wallet_type, 'NULL') as wallet_type,
            COALESCE(is_active::text, 'NULL') as is_active,
            COALESCE(status, 'NULL') as status,
            created_at
        FROM public.wallets
        ORDER BY created_at DESC
        LIMIT 10
    ) LOOP
        RAISE NOTICE '   User: % | Wallet: % | Balance: % | Type: % | Active: % | Status: %',
            rec.user_id, rec.wallet_id, rec.balance, rec.wallet_type, rec.is_active, rec.status;
    END LOOP;
    
END $$;

-- STEP 6: FINAL RECOMMENDATIONS
-- =====================================================

DO $$
DECLARE
    duplicate_count INTEGER;
    total_wallets INTEGER;
BEGIN
    -- Final duplicate check
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT user_id, COUNT(*) as wallet_count
        FROM public.wallets
        GROUP BY user_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    SELECT COUNT(*) INTO total_wallets FROM public.wallets;
    
    RAISE NOTICE '=== نتائج الاختبار النهائية ===';
    RAISE NOTICE '=== Final Test Results ===';
    RAISE NOTICE 'Total wallets: %', total_wallets;
    RAISE NOTICE 'Duplicate wallet users: %', duplicate_count;
    
    IF duplicate_count = 0 THEN
        RAISE NOTICE '✅ SUCCESS: PGRST116 fix verification PASSED';
        RAISE NOTICE '✅ Electronic payment system should work correctly';
        RAISE NOTICE '📱 You can now test the Flutter app electronic payments';
    ELSE
        RAISE NOTICE '❌ FAILURE: PGRST116 fix verification FAILED';
        RAISE NOTICE '❌ % users still have multiple wallets', duplicate_count;
        RAISE NOTICE '🔧 Please run the cleanup script again or contact support';
    END IF;
    
    RAISE NOTICE '=== اختبار مكتمل ===';
    RAISE NOTICE '=== Test Complete ===';
END $$;
