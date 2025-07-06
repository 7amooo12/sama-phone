-- =====================================================
-- AUTHENTICATION DIAGNOSTIC FOR SUPABASE
-- =====================================================
-- This script diagnoses authentication issues and provides
-- solutions for testing RLS policies when auth.uid() is NULL
-- =====================================================

-- =====================================================
-- 1. CHECK AUTHENTICATION STATE
-- =====================================================

-- Check if auth.uid() returns a value
SELECT 
    'AUTHENTICATION STATUS:' as section,
    CASE 
        WHEN auth.uid() IS NULL THEN 'NO AUTHENTICATED USER'
        ELSE 'AUTHENTICATED USER: ' || auth.uid()::text
    END as auth_status;

-- Check auth.jwt() for more details
SELECT 
    'JWT TOKEN STATUS:' as section,
    CASE 
        WHEN auth.jwt() IS NULL THEN 'NO JWT TOKEN'
        ELSE 'JWT TOKEN EXISTS'
    END as jwt_status;

-- Check auth.role() 
SELECT 
    'AUTH ROLE:' as section,
    CASE 
        WHEN auth.role() IS NULL THEN 'NO ROLE'
        ELSE auth.role()::text
    END as auth_role;

-- =====================================================
-- 2. SHOW ALL USERS IN USER_PROFILES
-- =====================================================

-- Show all users that exist in the system
SELECT 
    'ALL USERS IN SYSTEM:' as section,
    id,
    email,
    name,
    role,
    status,
    created_at
FROM public.user_profiles 
ORDER BY created_at DESC
LIMIT 10;

-- Count total users by role
SELECT 
    'USER COUNT BY ROLE:' as section,
    role,
    COUNT(*) as user_count,
    COUNT(*) FILTER (WHERE status = 'approved') as approved_count
FROM public.user_profiles 
GROUP BY role
ORDER BY role;

-- =====================================================
-- 3. IDENTIFY ADMIN USERS FOR TESTING
-- =====================================================

-- Show admin users that can be used for testing
SELECT 
    'ADMIN USERS FOR TESTING:' as section,
    id,
    email,
    name,
    status,
    created_at
FROM public.user_profiles 
WHERE role = 'admin'
ORDER BY created_at DESC;

-- Show approved users of all roles
SELECT 
    'APPROVED USERS FOR TESTING:' as section,
    id,
    email,
    name,
    role,
    status
FROM public.user_profiles 
WHERE status = 'approved'
ORDER BY role, created_at DESC;

-- =====================================================
-- 4. CHECK RLS POLICIES WITHOUT AUTH
-- =====================================================

-- Check if RLS is enabled
SELECT 
    'RLS STATUS:' as section,
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'client_orders';

-- Show current RLS policies
SELECT 
    'CURRENT RLS POLICIES:' as section,
    policyname,
    cmd as command,
    roles
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public'
ORDER BY policyname;

-- =====================================================
-- 5. AUTHENTICATION SOLUTIONS
-- =====================================================

-- Solution 1: Show how to authenticate in Supabase Dashboard
SELECT 
    'AUTHENTICATION SOLUTIONS:' as section,
    'To authenticate in Supabase SQL Editor:' as solution_1,
    '1. Go to Authentication > Users in Supabase Dashboard' as step_1,
    '2. Find your user and copy the UUID' as step_2,
    '3. Use the UUID directly in SQL instead of auth.uid()' as step_3;

-- Solution 2: Show sample SQL with hardcoded UUID
SELECT 
    'SAMPLE SQL WITH UUID:' as section,
    'Replace auth.uid() with actual UUID like this:' as instruction,
    'INSERT INTO client_orders (client_id, ...) VALUES (''your-uuid-here'', ...)' as example;

-- =====================================================
-- 6. TEMPORARY RLS BYPASS FOR TESTING
-- =====================================================

-- Show how to temporarily disable RLS for testing
SELECT 
    'TEMPORARY RLS BYPASS:' as section,
    'For testing only, you can disable RLS with:' as warning,
    'ALTER TABLE public.client_orders DISABLE ROW LEVEL SECURITY;' as disable_command,
    'Remember to re-enable with:' as reminder,
    'ALTER TABLE public.client_orders ENABLE ROW LEVEL SECURITY;' as enable_command;

-- =====================================================
-- DIAGNOSTIC COMPLETE
-- =====================================================

SELECT 
    'DIAGNOSTIC SUMMARY:' as section,
    CASE 
        WHEN auth.uid() IS NOT NULL THEN 'User is authenticated - RLS tests can proceed'
        WHEN EXISTS (SELECT 1 FROM public.user_profiles WHERE role = 'admin' AND status = 'approved') 
        THEN 'No auth but admin users exist - use UUID directly in tests'
        ELSE 'No auth and no admin users - create admin user first'
    END as recommendation;

SELECT 'AUTHENTICATION DIAGNOSTIC COMPLETED' as status;
