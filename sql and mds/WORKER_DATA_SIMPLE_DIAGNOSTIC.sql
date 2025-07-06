-- =====================================================
-- SIMPLE WORKER DATA DIAGNOSTIC
-- Quick check of worker data and RLS policies
-- No GROUP BY/ORDER BY conflicts
-- =====================================================

-- STEP 1: BASIC DATA ANALYSIS
-- =====================================================

SELECT '=== BASIC WORKER DATA ANALYSIS ===' as section;

-- Check total users
SELECT 
    'Total users in database' as metric,
    COUNT(*) as count
FROM public.user_profiles;

-- Check users by role (fixed GROUP BY)
SELECT 
    'Users by role' as analysis,
    role,
    COUNT(*) as count
FROM public.user_profiles
GROUP BY role
ORDER BY role;

-- Check users by status (fixed GROUP BY)
SELECT 
    'Users by status' as analysis,
    status,
    COUNT(*) as count
FROM public.user_profiles
GROUP BY status
ORDER BY status;

-- Check workers specifically (fixed GROUP BY)
SELECT 
    'Workers by status' as analysis,
    status,
    COUNT(*) as count
FROM public.user_profiles
WHERE role = 'worker'
GROUP BY status
ORDER BY status;

-- STEP 2: LIST ALL WORKERS
-- =====================================================

SELECT '=== ALL WORKERS DETAILS ===' as section;

-- List all workers with details (no GROUP BY issue)
SELECT 
    id,
    name,
    email,
    role,
    status,
    created_at
FROM public.user_profiles
WHERE role = 'worker'
ORDER BY name;

-- STEP 3: TEST WORKER QUERIES
-- =====================================================

SELECT '=== TESTING WORKER QUERIES ===' as section;

-- Test 1: Basic worker count
SELECT 
    'Basic worker count' as test_name,
    COUNT(*) as result
FROM public.user_profiles
WHERE role = 'worker';

-- Test 2: Approved/Active workers count
SELECT 
    'Approved/Active workers count' as test_name,
    COUNT(*) as result
FROM public.user_profiles
WHERE role = 'worker'
AND (status = 'approved' OR status = 'active');

-- Test 3: Sample worker data (what Flutter app needs)
SELECT 
    'Sample worker data' as test_name,
    id,
    name,
    email,
    status
FROM public.user_profiles
WHERE role = 'worker'
AND (status = 'approved' OR status = 'active')
LIMIT 3;

-- STEP 4: CHECK RLS POLICIES
-- =====================================================

SELECT '=== RLS POLICIES ANALYSIS ===' as section;

-- Check if RLS is enabled
SELECT 
    'RLS enabled on user_profiles' as check_name,
    rowsecurity as enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'user_profiles';

-- List all policies on user_profiles table
SELECT 
    'Current policies' as info,
    policyname,
    cmd,
    roles
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'user_profiles'
ORDER BY policyname;

-- STEP 5: CHECK AUTHENTICATION
-- =====================================================

SELECT '=== AUTHENTICATION CHECK ===' as section;

-- Check current user
SELECT 
    'Current authenticated user' as context,
    auth.uid() as user_id,
    auth.role() as auth_role;

-- Check if current user has a profile
SELECT 
    'Current user profile' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid()
        ) THEN 'EXISTS'
        ELSE 'NOT_FOUND'
    END as result;

-- Get current user profile details if exists
SELECT 
    'Current user details' as info,
    id,
    name,
    email,
    role,
    status
FROM public.user_profiles
WHERE id = auth.uid();

-- STEP 6: TEST POLICY EFFECTIVENESS
-- =====================================================

SELECT '=== POLICY EFFECTIVENESS TEST ===' as section;

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

-- STEP 7: IDENTIFY ISSUES
-- =====================================================

SELECT '=== ISSUE IDENTIFICATION ===' as section;

-- Check for recursive policies
SELECT 
    'Policies with potential recursion' as issue_type,
    COUNT(*) as count
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'user_profiles'
AND (
    qual LIKE '%user_profiles%' OR
    with_check LIKE '%user_profiles%'
);

-- List problematic policies
SELECT 
    'Problematic policies' as issue_type,
    policyname,
    cmd
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'user_profiles'
AND (
    qual LIKE '%user_profiles%' OR
    with_check LIKE '%user_profiles%'
)
ORDER BY policyname;

-- STEP 8: RECOMMENDATIONS
-- =====================================================

SELECT '=== RECOMMENDATIONS ===' as section;

-- Provide recommendations based on findings
SELECT 
    'Recommended action' as action,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM public.user_profiles WHERE role = 'worker'
        ) THEN 'No workers in database - check worker registration'
        WHEN EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE schemaname = 'public' 
            AND tablename = 'user_profiles'
            AND qual LIKE '%user_profiles%'
        ) THEN 'Fix recursive RLS policies'
        WHEN NOT EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE schemaname = 'public' 
            AND tablename = 'user_profiles'
            AND cmd = 'SELECT'
            AND roles = '{authenticated}'
        ) THEN 'Add permissive read policy for authenticated users'
        ELSE 'Run detailed analysis to identify specific issue'
    END as recommendation;

-- Final summary
SELECT 
    'DIAGNOSTIC COMPLETE' as status,
    'Review results above to identify worker loading issues' as next_step;
