-- =====================================================================
-- COMPREHENSIVE TESTING SCRIPT FOR CRITICAL DATABASE FIXES
-- =====================================================================
-- This script tests and verifies the fixes for:
-- 1. Schema mismatch issues (phone vs phone_number)
-- 2. User approval status problems
-- 3. Client debt management functionality
-- =====================================================================

-- Test 1: Verify database schema is correct
DO $$
BEGIN
    RAISE NOTICE '🧪 TEST 1: VERIFYING DATABASE SCHEMA...';
    
    -- Check that phone_number column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles' 
        AND column_name = 'phone_number'
    ) THEN
        RAISE NOTICE '✅ PASS: phone_number column exists in user_profiles';
    ELSE
        RAISE NOTICE '❌ FAIL: phone_number column missing from user_profiles';
    END IF;
    
    -- Check that phone column does NOT exist (it shouldn't)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles' 
        AND column_name = 'phone'
    ) THEN
        RAISE NOTICE '✅ PASS: No conflicting phone column in user_profiles';
    ELSE
        RAISE NOTICE '⚠️ WARNING: phone column exists alongside phone_number';
    END IF;
END $$;

-- Test 2: Verify user approval status consistency
DO $$
DECLARE
    total_wallets INTEGER;
    approved_users INTEGER;
    consistency_ratio NUMERIC;
BEGIN
    RAISE NOTICE '🧪 TEST 2: VERIFYING USER APPROVAL STATUS CONSISTENCY...';
    
    -- Count active client wallets
    SELECT COUNT(*) INTO total_wallets
    FROM wallets 
    WHERE role = 'client' AND status = 'active';
    
    -- Count approved users with wallets
    SELECT COUNT(DISTINCT w.user_id) INTO approved_users
    FROM wallets w
    INNER JOIN user_profiles up ON w.user_id = up.id
    WHERE w.role = 'client' 
    AND w.status = 'active'
    AND up.status = 'approved';
    
    -- Calculate consistency ratio
    IF total_wallets > 0 THEN
        consistency_ratio := (approved_users::NUMERIC / total_wallets::NUMERIC) * 100;
    ELSE
        consistency_ratio := 0;
    END IF;
    
    RAISE NOTICE '📊 Active client wallets: %', total_wallets;
    RAISE NOTICE '📊 Approved users with wallets: %', approved_users;
    RAISE NOTICE '📊 Consistency ratio: % percent (should be 100 percent)', ROUND(consistency_ratio, 2);
    
    IF consistency_ratio = 100 THEN
        RAISE NOTICE '✅ PASS: All users with wallets are properly approved';
    ELSE
        RAISE NOTICE '❌ FAIL: % users with wallets are not approved', (total_wallets - approved_users);
    END IF;
END $$;

-- Test 3: Test specific problematic user from logs
DO $$
DECLARE
    test_user_id UUID := 'aaaaf98e-f3aa-489d-9586-573332ff6301';
    user_name TEXT;
    user_status TEXT;
    wallet_balance NUMERIC;
    has_profile BOOLEAN;
    has_wallet BOOLEAN;
    is_approved BOOLEAN;
BEGIN
    RAISE NOTICE '🧪 TEST 3: TESTING SPECIFIC USER %...', test_user_id;
    
    -- Get user profile info
    SELECT name, status INTO user_name, user_status
    FROM user_profiles 
    WHERE id = test_user_id;
    
    -- Get wallet info
    SELECT balance INTO wallet_balance
    FROM wallets 
    WHERE user_id = test_user_id AND role = 'client' AND status = 'active';
    
    -- Set flags
    has_profile := user_name IS NOT NULL;
    has_wallet := wallet_balance IS NOT NULL;
    is_approved := user_status = 'approved';
    
    RAISE NOTICE '📊 User profile exists: %', has_profile;
    RAISE NOTICE '📊 User name: %', COALESCE(user_name, 'NULL');
    RAISE NOTICE '📊 User status: %', COALESCE(user_status, 'NULL');
    RAISE NOTICE '📊 Has wallet: %', has_wallet;
    RAISE NOTICE '📊 Wallet balance: % EGP', COALESCE(wallet_balance, 0);
    RAISE NOTICE '📊 Is approved: %', is_approved;
    
    IF has_profile AND has_wallet AND is_approved THEN
        RAISE NOTICE '✅ PASS: Test user should appear in client debt management';
    ELSE
        RAISE NOTICE '❌ FAIL: Test user will not appear in client debt management';
        
        IF NOT has_profile THEN
            RAISE NOTICE '   - Missing user profile';
        END IF;
        IF NOT has_wallet THEN
            RAISE NOTICE '   - Missing wallet';
        END IF;
        IF NOT is_approved THEN
            RAISE NOTICE '   - User not approved (status: %)', COALESCE(user_status, 'NULL');
        END IF;
    END IF;
END $$;

-- Test 4: Simulate client debt query that the app uses
DO $$
DECLARE
    client_count INTEGER;
    wallet_count INTEGER;
    rec RECORD;
BEGIN
    RAISE NOTICE '🧪 TEST 4: SIMULATING APP CLIENT DEBT QUERY...';
    
    -- This mimics the exact query the Flutter app uses
    SELECT COUNT(*) INTO client_count
    FROM user_profiles
    WHERE role = 'client' AND status = 'approved';
    
    SELECT COUNT(*) INTO wallet_count
    FROM wallets
    WHERE role = 'client' AND status = 'active';
    
    RAISE NOTICE '📊 Approved clients (app will fetch): %', client_count;
    RAISE NOTICE '📊 Active wallets (app will fetch): %', wallet_count;
    
    IF client_count > 0 AND wallet_count > 0 THEN
        RAISE NOTICE '✅ PASS: App should be able to load client debt data';
        
        -- Show sample of what the app will see
        RAISE NOTICE '📋 Sample clients the app will see:';
        FOR rec IN (
            SELECT up.name, up.id, w.balance
            FROM user_profiles up
            LEFT JOIN wallets w ON up.id = w.user_id AND w.role = 'client' AND w.status = 'active'
            WHERE up.role = 'client' AND up.status = 'approved'
            ORDER BY w.balance DESC NULLS LAST
            LIMIT 5
        ) LOOP
            RAISE NOTICE '   👤 % (%) - Balance: % EGP', 
                rec.name, 
                rec.id, 
                COALESCE(rec.balance, 0);
        END LOOP;
    ELSE
        RAISE NOTICE '❌ FAIL: App will not be able to load client debt data';
        
        IF client_count = 0 THEN
            RAISE NOTICE '   - No approved clients found';
        END IF;
        IF wallet_count = 0 THEN
            RAISE NOTICE '   - No active wallets found';
        END IF;
    END IF;
END $$;

-- Test 5: Test phone_number field access (simulates app update operations)
DO $$
DECLARE
    test_user_id UUID;
    update_success BOOLEAN := TRUE;
BEGIN
    RAISE NOTICE '🧪 TEST 5: TESTING PHONE_NUMBER FIELD ACCESS...';
    
    -- Get a test user
    SELECT id INTO test_user_id
    FROM user_profiles
    WHERE role = 'client'
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        BEGIN
            -- Try to update phone_number (this should work)
            UPDATE user_profiles 
            SET phone_number = '01234567890', updated_at = NOW()
            WHERE id = test_user_id;
            
            RAISE NOTICE '✅ PASS: phone_number field update successful';
        EXCEPTION WHEN OTHERS THEN
            update_success := FALSE;
            RAISE NOTICE '❌ FAIL: phone_number field update failed: %', SQLERRM;
        END;
        
        -- Try to access phone field (this should fail if our fix worked)
        BEGIN
            PERFORM phone FROM user_profiles WHERE id = test_user_id LIMIT 1;
            RAISE NOTICE '⚠️ WARNING: phone field still accessible (should not exist)';
        EXCEPTION WHEN undefined_column THEN
            RAISE NOTICE '✅ PASS: phone field properly removed/non-existent';
        WHEN OTHERS THEN
            RAISE NOTICE '❓ UNKNOWN: Unexpected error accessing phone field: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE '⚠️ SKIP: No test user available for phone_number test';
    END IF;
END $$;

-- Test 6: Final summary and recommendations
DO $$
DECLARE
    total_issues INTEGER := 0;
    schema_ok BOOLEAN;
    approval_ok BOOLEAN;
    test_user_ok BOOLEAN;
    query_ok BOOLEAN;
    phone_ok BOOLEAN;
BEGIN
    RAISE NOTICE '🧪 TEST 6: FINAL SUMMARY AND RECOMMENDATIONS...';
    
    -- Check schema
    schema_ok := EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles' 
        AND column_name = 'phone_number'
    );
    
    -- Check approval consistency
    approval_ok := (
        SELECT COUNT(DISTINCT w.user_id) 
        FROM wallets w
        INNER JOIN user_profiles up ON w.user_id = up.id
        WHERE w.role = 'client' AND w.status = 'active' AND up.status = 'approved'
    ) = (
        SELECT COUNT(*) 
        FROM wallets 
        WHERE role = 'client' AND status = 'active'
    );
    
    -- Check test user
    test_user_ok := EXISTS (
        SELECT 1 FROM user_profiles up
        INNER JOIN wallets w ON up.id = w.user_id
        WHERE up.id = 'aaaaf98e-f3aa-489d-9586-573332ff6301'
        AND up.status = 'approved'
        AND w.role = 'client' AND w.status = 'active'
    );
    
    -- Check query readiness
    query_ok := (
        SELECT COUNT(*) FROM user_profiles WHERE role = 'client' AND status = 'approved'
    ) > 0 AND (
        SELECT COUNT(*) FROM wallets WHERE role = 'client' AND status = 'active'
    ) > 0;
    
    -- Count issues
    IF NOT schema_ok THEN total_issues := total_issues + 1; END IF;
    IF NOT approval_ok THEN total_issues := total_issues + 1; END IF;
    IF NOT test_user_ok THEN total_issues := total_issues + 1; END IF;
    IF NOT query_ok THEN total_issues := total_issues + 1; END IF;
    
    RAISE NOTICE '📊 FINAL TEST RESULTS:';
    RAISE NOTICE '   - Schema correctness: %', CASE WHEN schema_ok THEN '✅ PASS' ELSE '❌ FAIL' END;
    RAISE NOTICE '   - Approval consistency: %', CASE WHEN approval_ok THEN '✅ PASS' ELSE '❌ FAIL' END;
    RAISE NOTICE '   - Test user status: %', CASE WHEN test_user_ok THEN '✅ PASS' ELSE '❌ FAIL' END;
    RAISE NOTICE '   - Query readiness: %', CASE WHEN query_ok THEN '✅ PASS' ELSE '❌ FAIL' END;
    RAISE NOTICE '   - Total issues: %', total_issues;
    
    IF total_issues = 0 THEN
        RAISE NOTICE '🎉 ALL TESTS PASSED! The client debt management system should work correctly.';
        RAISE NOTICE '📝 NEXT STEPS:';
        RAISE NOTICE '   1. Restart the Flutter app to clear any cached data';
        RAISE NOTICE '   2. Test account information updates for all user roles';
        RAISE NOTICE '   3. Verify the accountant dashboard shows client debt data';
        RAISE NOTICE '   4. Confirm the "مديونية العملاء" tab displays clients properly';
    ELSE
        RAISE NOTICE '⚠️ % ISSUES FOUND! Manual intervention may be required.', total_issues;
        RAISE NOTICE '📝 RECOMMENDED ACTIONS:';
        
        IF NOT schema_ok THEN
            RAISE NOTICE '   - Fix database schema: ensure phone_number column exists';
        END IF;
        IF NOT approval_ok THEN
            RAISE NOTICE '   - Run the user approval fix script again';
        END IF;
        IF NOT test_user_ok THEN
            RAISE NOTICE '   - Manually approve the test user or investigate profile issues';
        END IF;
        IF NOT query_ok THEN
            RAISE NOTICE '   - Ensure there are approved clients and active wallets in the system';
        END IF;
    END IF;
END $$;

-- Final completion message
DO $$
BEGIN
    RAISE NOTICE '🏁 TESTING COMPLETED!';
END $$;
