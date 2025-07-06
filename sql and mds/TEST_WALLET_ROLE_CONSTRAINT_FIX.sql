-- 🧪 Test Wallet Role Constraint Fix
-- This script tests that the wallet role NOT NULL constraint violation has been fixed

-- STEP 1: VERIFY NO NULL ROLES EXIST
-- =====================================================

DO $$
DECLARE
    null_role_count INTEGER;
    total_wallets INTEGER;
    rec RECORD;  -- Added missing RECORD declaration for FOR loop
BEGIN
    RAISE NOTICE '=== اختبار إصلاح قيد NOT NULL للعمود role ===';
    RAISE NOTICE '=== Testing Wallet Role NOT NULL Constraint Fix ===';
    
    -- Count total wallets and NULL roles
    SELECT COUNT(*) INTO total_wallets FROM public.wallets;
    SELECT COUNT(*) INTO null_role_count FROM public.wallets WHERE role IS NULL;
    
    RAISE NOTICE '📊 Database Statistics:';
    RAISE NOTICE '   Total wallets: %', total_wallets;
    RAISE NOTICE '   Wallets with NULL role: %', null_role_count;
    
    IF null_role_count = 0 THEN
        RAISE NOTICE '✅ SUCCESS: No NULL role values found!';
    ELSE
        RAISE NOTICE '❌ FAILURE: % wallets still have NULL role values', null_role_count;
        
        -- Show the problematic records
        RAISE NOTICE '🔍 Wallets with NULL roles:';
        FOR rec IN (
            SELECT id, user_id, wallet_type, status, is_active
            FROM public.wallets 
            WHERE role IS NULL
            LIMIT 5
        ) LOOP
            RAISE NOTICE '   Wallet: % | User: % | Type: % | Status: % | Active: %',
                rec.id, rec.user_id, rec.wallet_type, rec.status, rec.is_active;
        END LOOP;
    END IF;
END $$;

-- STEP 2: TEST BUSINESS WALLET CREATION
-- =====================================================

DO $$
DECLARE
    business_wallet_id UUID;
    wallet_role TEXT;
    error_occurred BOOLEAN := false;
BEGIN
    RAISE NOTICE '🏢 Testing business wallet creation...';
    
    BEGIN
        -- Test business wallet creation
        SELECT public.get_or_create_business_wallet() INTO business_wallet_id;
        
        -- Verify the created wallet has a proper role
        SELECT role INTO wallet_role
        FROM public.wallets
        WHERE id = business_wallet_id;
        
        IF wallet_role IS NOT NULL THEN
            RAISE NOTICE '✅ Business wallet creation successful: % (role: %)', business_wallet_id, wallet_role;
        ELSE
            RAISE NOTICE '❌ Business wallet created but role is NULL: %', business_wallet_id;
            error_occurred := true;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Business wallet creation failed: %', SQLERRM;
            error_occurred := true;
    END;
    
    IF NOT error_occurred THEN
        RAISE NOTICE '✅ Business wallet function test PASSED';
    ELSE
        RAISE NOTICE '❌ Business wallet function test FAILED';
    END IF;
END $$;

-- STEP 3: TEST CLIENT WALLET CREATION
-- =====================================================

DO $$
DECLARE
    test_user_id UUID;
    client_wallet_id UUID;
    wallet_role TEXT;
    error_occurred BOOLEAN := false;
BEGIN
    RAISE NOTICE '👤 Testing client wallet creation...';
    
    -- Get a sample user for testing
    SELECT id INTO test_user_id 
    FROM public.user_profiles 
    WHERE status = 'approved'
    LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE '⚠️ No approved users found for testing';
        RETURN;
    END IF;
    
    RAISE NOTICE '   Testing with user: %', test_user_id;
    
    BEGIN
        -- Test client wallet creation
        SELECT public.get_or_create_client_wallet(test_user_id) INTO client_wallet_id;
        
        -- Verify the created wallet has a proper role
        SELECT role INTO wallet_role
        FROM public.wallets
        WHERE id = client_wallet_id;
        
        IF wallet_role IS NOT NULL THEN
            RAISE NOTICE '✅ Client wallet creation successful: % (role: %)', client_wallet_id, wallet_role;
        ELSE
            RAISE NOTICE '❌ Client wallet created but role is NULL: %', client_wallet_id;
            error_occurred := true;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Client wallet creation failed: %', SQLERRM;
            error_occurred := true;
    END;
    
    IF NOT error_occurred THEN
        RAISE NOTICE '✅ Client wallet function test PASSED';
    ELSE
        RAISE NOTICE '❌ Client wallet function test FAILED';
    END IF;
END $$;

-- STEP 4: TEST ROLE VALIDATION FUNCTION
-- =====================================================

DO $$
DECLARE
    test_user_id UUID;
    user_role TEXT;
    error_occurred BOOLEAN := false;
BEGIN
    RAISE NOTICE '🔍 Testing role validation function...';
    
    -- Get a sample user for testing
    SELECT id INTO test_user_id 
    FROM public.user_profiles 
    WHERE status = 'approved'
    LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE '⚠️ No approved users found for testing';
        RETURN;
    END IF;
    
    BEGIN
        -- Test role validation
        SELECT public.validate_user_role(test_user_id) INTO user_role;
        
        IF user_role IS NOT NULL THEN
            RAISE NOTICE '✅ Role validation successful for user %: %', test_user_id, user_role;
        ELSE
            RAISE NOTICE '❌ Role validation returned NULL for user: %', test_user_id;
            error_occurred := true;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Role validation failed: %', SQLERRM;
            error_occurred := true;
    END;
    
    IF NOT error_occurred THEN
        RAISE NOTICE '✅ Role validation function test PASSED';
    ELSE
        RAISE NOTICE '❌ Role validation function test FAILED';
    END IF;
END $$;

-- STEP 5: TEST DUAL WALLET TRANSACTION (SIMULATION)
-- =====================================================

DO $$
DECLARE
    test_payment_id UUID := gen_random_uuid();
    test_client_wallet UUID;
    test_business_wallet UUID;
    test_user_id UUID;
    test_approver_id UUID;
    simulation_successful BOOLEAN := true;
BEGIN
    RAISE NOTICE '💰 Testing dual wallet transaction simulation...';
    
    -- Get test users
    SELECT id INTO test_user_id 
    FROM public.user_profiles 
    WHERE role = 'client' AND status = 'approved'
    LIMIT 1;
    
    SELECT id INTO test_approver_id 
    FROM public.user_profiles 
    WHERE role IN ('admin', 'owner', 'accountant') AND status = 'approved'
    LIMIT 1;
    
    IF test_user_id IS NULL OR test_approver_id IS NULL THEN
        RAISE NOTICE '⚠️ Insufficient test users found (client: %, approver: %)', test_user_id, test_approver_id;
        RETURN;
    END IF;
    
    -- Test wallet creation for transaction
    BEGIN
        test_client_wallet := public.get_or_create_client_wallet(test_user_id);
        test_business_wallet := public.get_or_create_business_wallet();
        
        RAISE NOTICE '✅ Wallets prepared for transaction:';
        RAISE NOTICE '   Client wallet: % (user: %)', test_client_wallet, test_user_id;
        RAISE NOTICE '   Business wallet: %', test_business_wallet;
        RAISE NOTICE '   Approver: %', test_approver_id;
        
        -- Verify both wallets have proper roles
        IF EXISTS (SELECT 1 FROM public.wallets WHERE id = test_client_wallet AND role IS NOT NULL) AND
           EXISTS (SELECT 1 FROM public.wallets WHERE id = test_business_wallet AND role IS NOT NULL) THEN
            RAISE NOTICE '✅ Both wallets have proper role assignments';
        ELSE
            RAISE NOTICE '❌ One or both wallets have NULL roles';
            simulation_successful := false;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Wallet preparation failed: %', SQLERRM;
            simulation_successful := false;
    END;
    
    IF simulation_successful THEN
        RAISE NOTICE '✅ Dual wallet transaction simulation PASSED';
        RAISE NOTICE '🎉 Electronic payment approval should work without role constraint violations';
    ELSE
        RAISE NOTICE '❌ Dual wallet transaction simulation FAILED';
    END IF;
END $$;

-- STEP 6: FINAL VERIFICATION REPORT
-- =====================================================

DO $$
DECLARE
    null_role_count INTEGER;
    business_wallet_count INTEGER;
    client_wallet_count INTEGER;
    total_tests_passed INTEGER := 0;
    total_tests INTEGER := 5;
BEGIN
    -- Final statistics
    SELECT COUNT(*) INTO null_role_count FROM public.wallets WHERE role IS NULL;
    SELECT COUNT(*) INTO business_wallet_count FROM public.wallets WHERE wallet_type = 'business' AND role IS NOT NULL;
    SELECT COUNT(*) INTO client_wallet_count FROM public.wallets WHERE wallet_type = 'personal' AND role IS NOT NULL;
    
    RAISE NOTICE '=== نتائج الاختبار النهائية ===';
    RAISE NOTICE '=== Final Test Results ===';
    RAISE NOTICE 'Wallets with NULL roles: %', null_role_count;
    RAISE NOTICE 'Business wallets with proper roles: %', business_wallet_count;
    RAISE NOTICE 'Client wallets with proper roles: %', client_wallet_count;
    
    -- Count successful tests
    IF null_role_count = 0 THEN total_tests_passed := total_tests_passed + 1; END IF;
    IF business_wallet_count > 0 THEN total_tests_passed := total_tests_passed + 1; END IF;
    IF client_wallet_count > 0 THEN total_tests_passed := total_tests_passed + 1; END IF;
    
    RAISE NOTICE 'Tests passed: % / %', total_tests_passed, total_tests;
    
    IF total_tests_passed = total_tests THEN
        RAISE NOTICE '✅ SUCCESS: All wallet role constraint tests PASSED';
        RAISE NOTICE '✅ Electronic payment system should work without role constraint violations';
        RAISE NOTICE '🚀 Ready to test Flutter app electronic payment approval';
    ELSE
        RAISE NOTICE '❌ FAILURE: Some tests failed';
        RAISE NOTICE '🔧 Please review the database functions and run the fix script again';
    END IF;
    
    RAISE NOTICE '=== اختبار مكتمل ===';
    RAISE NOTICE '=== Test Complete ===';
END $$;
