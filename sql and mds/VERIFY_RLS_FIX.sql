-- =====================================================
-- VERIFICATION SCRIPT FOR RLS POLICY FIXES (PERMISSION-SAFE)
-- Run this after applying CRITICAL_RLS_FIX.sql
-- This version avoids auth schema access issues
-- =====================================================

-- 1. Check current RLS policies on user_profiles
SELECT
    '=== Current RLS Policies on user_profiles ===' as info;

SELECT
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'user_profiles'
ORDER BY policyname;

-- 2. Check if RLS is enabled
SELECT
    '=== RLS Status ===' as info;

SELECT
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'user_profiles';

-- 3. Test the helper function (public schema version)
SELECT
    '=== Testing public.is_admin_user() function ===' as info;

-- This should work without permission issues
SELECT public.is_admin_user() as is_admin_result;

-- 4. Test the safe profile creation function
SELECT
    '=== Testing create_user_profile_safe function ===' as info;

-- Generate a test UUID and email
DO $$
DECLARE
    test_uuid UUID := gen_random_uuid();
    test_email TEXT := 'test-' || extract(epoch from now()) || '@example.com';
BEGIN
    -- This should work without recursion issues
    PERFORM create_user_profile_safe(
        test_uuid,
        test_email,
        'Test User',
        '+1234567890',
        'client',
        'pending'
    );

    RAISE NOTICE '✅ Profile creation function executed successfully';
    RAISE NOTICE 'Test UUID: %', test_uuid;
    RAISE NOTICE 'Test Email: %', test_email;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Profile creation function failed: %', SQLERRM;
END $$;

-- 5. Check for any remaining problematic policies
SELECT
    '=== Checking for potentially problematic policies ===' as info;

SELECT
    schemaname,
    tablename,
    policyname,
    CASE
        WHEN qual LIKE '%user_profiles%' THEN 'POTENTIAL RECURSION RISK'
        ELSE 'OK'
    END as recursion_risk
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'user_profiles'
ORDER BY tablename, policyname;

-- 6. Test basic operations that should work now
SELECT
    '=== Testing basic user_profiles operations ===' as info;

-- Count total profiles (this should work without recursion)
SELECT COUNT(*) as total_profiles FROM public.user_profiles;

-- 7. Test simple SELECT operations (should not cause recursion)
SELECT
    '=== Testing SELECT operations for recursion ===' as info;

-- Test 1: Simple count (should work)
SELECT 'Simple COUNT test' as test_name, COUNT(*) as result
FROM public.user_profiles;

-- Test 2: Select with LIMIT (should work)
SELECT 'SELECT with LIMIT test' as test_name, COUNT(*) as result
FROM (SELECT * FROM public.user_profiles LIMIT 5) as limited_results;

-- Test 3: Check if we can access profile data structure
SELECT
    '=== Profile table structure verification ===' as info;

SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'user_profiles'
ORDER BY ordinal_position;

-- 8. Final verification and recommendations
SELECT
    '=== VERIFICATION COMPLETE ===' as status;

SELECT
    '✅ If you see this message without errors above, the basic RLS fix was successful' as message;

SELECT
    'Next steps:' as next_steps,
    '1. Test Flutter app authentication' as step_1,
    '2. Monitor for any remaining recursion errors' as step_2,
    '3. Check application logs for PostgrestException errors' as step_3;
