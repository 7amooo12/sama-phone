-- =====================================================
-- WORKER DATA RETRIEVAL DIAGNOSTIC & FIX
-- Diagnoses and fixes worker loading issues in Flutter app
-- =====================================================

-- STEP 1: ANALYZE CURRENT WORKER DATA
-- =====================================================

SELECT 
    '=== WORKER DATA ANALYSIS ===' as analysis;

-- Check total users in database
SELECT 
    'Total users in database' as metric,
    COUNT(*) as count
FROM public.user_profiles;

-- Check users by role
SELECT 
    'Users by role' as metric,
    role,
    COUNT(*) as count
FROM public.user_profiles
GROUP BY role
ORDER BY role;

-- Check users by status
SELECT 
    'Users by status' as metric,
    status,
    COUNT(*) as count
FROM public.user_profiles
GROUP BY status
ORDER BY status;

-- Check workers specifically
SELECT 
    'Workers by status' as metric,
    status,
    COUNT(*) as count
FROM public.user_profiles
WHERE role = 'worker'
GROUP BY status
ORDER BY status;

-- List all workers with details
SELECT 
    '=== ALL WORKERS DETAILS ===' as section;

SELECT 
    id,
    name,
    email,
    role,
    status,
    created_at,
    updated_at
FROM public.user_profiles
WHERE role = 'worker'
ORDER BY name;

-- STEP 2: TEST WORKER QUERIES
-- =====================================================

SELECT 
    '=== TESTING WORKER QUERIES ===' as test_section;

-- Test 1: Basic worker query (what the app is trying to do)
SELECT 
    'Test 1: Basic worker query' as test_name,
    COUNT(*) as result
FROM public.user_profiles
WHERE role = 'worker';

-- Test 2: Approved/Active workers query
SELECT 
    'Test 2: Approved/Active workers' as test_name,
    COUNT(*) as result
FROM public.user_profiles
WHERE role = 'worker'
AND (status = 'approved' OR status = 'active');

-- Test 3: The exact query used by getUsersByRole
SELECT
    'Test 3: getUsersByRole query simulation' as test_name,
    COUNT(*) as result
FROM public.user_profiles
WHERE role = 'worker'
AND (status = 'approved' OR status = 'active');

-- STEP 3: ANALYZE RLS POLICIES
-- =====================================================

SELECT 
    '=== RLS POLICIES ANALYSIS ===' as rls_section;

-- Check if RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'user_profiles';

-- List all policies on user_profiles table
SELECT 
    policyname,
    cmd,
    roles,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'user_profiles'
ORDER BY policyname;

-- STEP 4: CHECK AUTHENTICATION CONTEXT
-- =====================================================

SELECT 
    '=== AUTHENTICATION CONTEXT ===' as auth_section;

-- Check current user
SELECT 
    'Current authenticated user' as context,
    auth.uid() as user_id,
    auth.role() as auth_role;

-- Check if current user has a profile
SELECT 
    'Current user profile exists' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid()
        ) THEN 'YES'
        ELSE 'NO'
    END as result;

-- Get current user profile if exists
SELECT 
    'Current user profile details' as info,
    id,
    name,
    email,
    role,
    status
FROM public.user_profiles
WHERE id = auth.uid();

-- STEP 5: TEST POLICY EFFECTIVENESS
-- =====================================================

SELECT 
    '=== TESTING POLICY EFFECTIVENESS ===' as policy_test;

-- Test if current user can see any profiles
SELECT 
    'Profiles visible to current user' as test_name,
    COUNT(*) as count
FROM public.user_profiles;

-- Test if current user can see workers specifically
SELECT 
    'Workers visible to current user' as test_name,
    COUNT(*) as count
FROM public.user_profiles
WHERE role = 'worker';

-- Test if current user can see approved workers
SELECT 
    'Approved workers visible to current user' as test_name,
    COUNT(*) as count
FROM public.user_profiles
WHERE role = 'worker'
AND (status = 'approved' OR status = 'active');

-- STEP 6: IDENTIFY PROBLEMATIC POLICIES
-- =====================================================

SELECT 
    '=== PROBLEMATIC POLICIES IDENTIFICATION ===' as problem_section;

-- Check for recursive policies (policies that reference user_profiles within themselves)
SELECT 
    'Policies with potential recursion' as issue_type,
    policyname,
    qual
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'user_profiles'
AND (
    qual LIKE '%user_profiles%' OR
    with_check LIKE '%user_profiles%'
)
ORDER BY policyname;

-- STEP 7: PROPOSED SOLUTION
-- =====================================================

SELECT 
    '=== PROPOSED SOLUTION ===' as solution_section;

-- The issue is likely that the RLS policies are too restrictive
-- or have recursive references that prevent proper data access

-- Check if we need to create a permissive policy for worker data access
SELECT 
    'Recommended action' as action,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE schemaname = 'public' 
            AND tablename = 'user_profiles'
            AND policyname LIKE '%admin%'
            AND qual LIKE '%user_profiles%'
        ) THEN 'Fix recursive admin policies'
        WHEN NOT EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE schemaname = 'public' 
            AND tablename = 'user_profiles'
            AND cmd = 'SELECT'
            AND roles = '{authenticated}'
            AND qual = 'true'
        ) THEN 'Add permissive read policy for authenticated users'
        ELSE 'Investigate other RLS issues'
    END as recommendation;

-- STEP 8: VERIFICATION QUERIES
-- =====================================================

SELECT 
    '=== VERIFICATION QUERIES ===' as verification;

-- These queries should work after fixing RLS policies

-- Query 1: Should return all workers
SELECT 
    'All workers count' as query_name,
    COUNT(*) as expected_result
FROM public.user_profiles
WHERE role = 'worker';

-- Query 2: Should return approved workers
SELECT 
    'Approved workers count' as query_name,
    COUNT(*) as expected_result
FROM public.user_profiles
WHERE role = 'worker'
AND (status = 'approved' OR status = 'active');

-- Query 3: Should return worker details
SELECT 
    'Sample worker details' as query_name,
    id,
    name,
    email,
    status
FROM public.user_profiles
WHERE role = 'worker'
LIMIT 3;

-- STEP 9: SUCCESS INDICATORS
-- =====================================================

SELECT 
    '=== SUCCESS INDICATORS ===' as success_section;

SELECT 
    'Workers should be visible' as indicator,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ SUCCESS: Workers found'
        ELSE '❌ FAILURE: No workers visible'
    END as status,
    COUNT(*) as worker_count
FROM public.user_profiles
WHERE role = 'worker'
AND (status = 'approved' OR status = 'active');

-- Final summary
SELECT 
    '🎯 DIAGNOSTIC COMPLETE' as status,
    'Check results above to identify worker loading issues' as next_step;
