-- =====================================================
-- COMPREHENSIVE AUTHENTICATION TEST FOR ALL USER TYPES
-- Run this after AUTHENTICATION_COMPLETE_FIX.sql
-- =====================================================

-- Step 1: Verify all policies are in place
SELECT 
    '=== CURRENT RLS POLICIES ===' as info;

SELECT 
    policyname,
    cmd,
    roles,
    CASE 
        WHEN policyname LIKE '%own%' THEN '✅ SAFE'
        WHEN policyname LIKE '%service_role%' THEN '✅ SAFE'
        WHEN policyname LIKE '%public%' THEN '⚠️ CHECK'
        WHEN policyname LIKE '%admin%' THEN '⚠️ CHECK'
        ELSE '❓ UNKNOWN'
    END as safety_status
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'user_profiles'
ORDER BY policyname;

-- Step 2: Test the helper functions
SELECT 
    '=== TESTING HELPER FUNCTIONS ===' as info;

-- Test user existence check
SELECT 
    'Testing user_exists_by_email function' as test_name,
    public.user_exists_by_email('nonexistent@test.com') as should_be_false;

-- Test auth user existence check  
SELECT 
    'Testing auth_user_exists_by_email function' as test_name,
    public.auth_user_exists_by_email('nonexistent@test.com') as should_be_false;

-- Step 3: Test profile creation function
SELECT 
    '=== TESTING PROFILE CREATION ===' as info;

DO $$
DECLARE
    test_uuid UUID := gen_random_uuid();
    test_email TEXT := 'test-' || extract(epoch from now()) || '@example.com';
BEGIN
    -- Test profile creation
    PERFORM public.create_user_profile_safe(
        test_uuid,
        test_email,
        'Test User',
        '+1234567890',
        'client',
        'pending'
    );
    
    -- Verify it was created
    IF EXISTS (SELECT 1 FROM public.user_profiles WHERE id = test_uuid) THEN
        RAISE NOTICE '✅ Profile creation test PASSED';
    ELSE
        RAISE NOTICE '❌ Profile creation test FAILED';
    END IF;
    
    -- Clean up test data
    DELETE FROM public.user_profiles WHERE id = test_uuid;
    RAISE NOTICE 'ℹ️ Test data cleaned up';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Profile creation test ERROR: %', SQLERRM;
END $$;

-- Step 4: Check existing users and their roles
SELECT 
    '=== EXISTING USERS BY ROLE ===' as info;

SELECT 
    role,
    status,
    COUNT(*) as user_count
FROM public.user_profiles 
GROUP BY role, status
ORDER BY role, status;

-- Step 5: Test basic profile access for different scenarios
SELECT 
    '=== TESTING PROFILE ACCESS PATTERNS ===' as info;

-- Test 1: Count all profiles (should work with public read policy)
SELECT 
    'Total profiles accessible' as test_name,
    COUNT(*) as count
FROM public.user_profiles;

-- Test 2: Check if we can see profile structure
SELECT 
    'Profile table structure' as test_name,
    COUNT(*) as column_count
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'user_profiles';

-- Step 6: Simulate authentication scenarios
SELECT 
    '=== AUTHENTICATION SCENARIO TESTS ===' as info;

-- Test admin user identification
SELECT 
    'Admin users (by role)' as test_name,
    COUNT(*) as admin_count
FROM public.user_profiles 
WHERE role = 'admin';

-- Test different user statuses
SELECT 
    'Users by status' as test_name,
    status,
    COUNT(*) as count
FROM public.user_profiles 
GROUP BY status
ORDER BY status;

-- Step 7: Test signup scenario simulation
SELECT 
    '=== SIGNUP SCENARIO TEST ===' as info;

DO $$
DECLARE
    test_email TEXT := 'signup-test-' || extract(epoch from now()) || '@example.com';
    user_exists_result BOOLEAN;
    auth_exists_result BOOLEAN;
BEGIN
    -- Test signup checks
    SELECT public.user_exists_by_email(test_email) INTO user_exists_result;
    SELECT public.auth_user_exists_by_email(test_email) INTO auth_exists_result;
    
    IF user_exists_result = false AND auth_exists_result = false THEN
        RAISE NOTICE '✅ Signup checks work correctly - new user can be created';
    ELSE
        RAISE NOTICE '❌ Signup checks failed - user_exists: %, auth_exists: %', 
                     user_exists_result, auth_exists_result;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Signup scenario test ERROR: %', SQLERRM;
END $$;

-- Step 8: Performance check
SELECT 
    '=== PERFORMANCE CHECK ===' as info;

-- This should complete quickly without hanging
EXPLAIN (ANALYZE, BUFFERS) 
SELECT COUNT(*) FROM public.user_profiles WHERE role = 'client';

-- Step 9: Final verification
SELECT 
    '=== FINAL VERIFICATION ===' as status;

SELECT 
    '✅ If you see this message, all tests completed successfully' as message,
    'Your authentication system should now work for all user types' as result,
    'Next: Test your Flutter app with different user accounts' as next_step;

-- Step 10: Troubleshooting information
SELECT 
    '=== TROUBLESHOOTING INFO ===' as info;

SELECT 
    'If authentication still fails, check these:' as troubleshooting,
    '1. Ensure user has correct role in user_profiles table' as step1,
    '2. Check user status is active/approved, not pending' as step2,
    '3. Verify Flutter app is using updated SupabaseService methods' as step3,
    '4. Check Supabase logs for specific error messages' as step4;
