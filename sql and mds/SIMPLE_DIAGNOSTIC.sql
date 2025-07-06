-- =====================================================
-- SIMPLE DIAGNOSTIC FOR CLIENT ORDERS RLS
-- =====================================================
-- Supabase compatible diagnostic script
-- =====================================================

-- =====================================================
-- 1. CHECK CURRENT USER AUTHENTICATION
-- =====================================================

-- Check if user is authenticated
SELECT 
    CASE 
        WHEN auth.uid() IS NULL THEN 'ERROR: No authenticated user found'
        ELSE 'SUCCESS: User authenticated with ID: ' || auth.uid()::text
    END as authentication_status;

-- =====================================================
-- 2. CHECK USER PROFILE
-- =====================================================

-- Get current user's profile information
SELECT 
    'USER PROFILE:' as info,
    id,
    name,
    email,
    role,
    status,
    CASE 
        WHEN status = 'approved' THEN 'OK'
        ELSE 'PROBLEM: Status should be approved'
    END as status_check
FROM public.user_profiles 
WHERE id = auth.uid();

-- =====================================================
-- 3. CHECK CLIENT_ORDERS TABLE
-- =====================================================

-- Verify table exists and show structure
SELECT 'CLIENT_ORDERS TABLE STRUCTURE:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'client_orders'
ORDER BY ordinal_position;

-- =====================================================
-- 4. CHECK RLS STATUS
-- =====================================================

-- Check if RLS is enabled
SELECT 
    'RLS STATUS:' as info,
    schemaname,
    tablename,
    CASE 
        WHEN rowsecurity THEN 'ENABLED'
        ELSE 'DISABLED'
    END as rls_status
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'client_orders';

-- =====================================================
-- 5. CHECK EXISTING POLICIES
-- =====================================================

-- Show current RLS policies
SELECT 
    'CURRENT RLS POLICIES:' as info,
    policyname,
    cmd as command,
    roles
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public'
ORDER BY policyname;

-- =====================================================
-- 6. CHECK TABLE PERMISSIONS
-- =====================================================

-- Check permissions for authenticated role
SELECT 
    'TABLE PERMISSIONS:' as info,
    privilege_type,
    grantee,
    is_grantable
FROM information_schema.table_privileges 
WHERE table_schema = 'public' 
AND table_name = 'client_orders'
ORDER BY privilege_type;

-- =====================================================
-- 7. TEST BASIC ACCESS
-- =====================================================

-- Try to count existing orders (tests SELECT permission)
SELECT 
    'ORDER COUNT TEST:' as test_type,
    CASE 
        WHEN COUNT(*) >= 0 THEN 'SUCCESS: Can read orders (' || COUNT(*)::text || ' orders found)'
        ELSE 'ERROR: Cannot read orders'
    END as result
FROM public.client_orders;

-- =====================================================
-- 8. POLICY EVALUATION TEST
-- =====================================================

-- Test if current user matches any policy conditions
SELECT 
    'POLICY EVALUATION:' as test_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'admin'
            AND user_profiles.status = 'approved'
        ) THEN 'MATCHES: Admin policy'
        WHEN EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'owner'
            AND user_profiles.status = 'approved'
        ) THEN 'MATCHES: Owner policy'
        WHEN EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'accountant'
            AND user_profiles.status = 'approved'
        ) THEN 'MATCHES: Accountant policy'
        WHEN EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'client'
            AND user_profiles.status = 'approved'
        ) THEN 'MATCHES: Client policy'
        WHEN EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'worker'
            AND user_profiles.status = 'approved'
        ) THEN 'MATCHES: Worker policy'
        ELSE 'ERROR: No policy matches - this is the problem!'
    END as policy_match;

-- =====================================================
-- 9. COMMON ISSUES CHECK
-- =====================================================

-- Check for common issues
SELECT 
    'COMMON ISSUES CHECK:' as check_type,
    CASE 
        WHEN auth.uid() IS NULL THEN 'ISSUE: User not authenticated'
        WHEN NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid()) THEN 'ISSUE: User profile missing'
        WHEN EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND status != 'approved') THEN 'ISSUE: User not approved'
        WHEN EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role NOT IN ('admin', 'owner', 'accountant', 'client', 'worker')) THEN 'ISSUE: Invalid user role'
        WHEN NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'client_orders') THEN 'ISSUE: No RLS policies exist'
        ELSE 'OK: No obvious issues found'
    END as issue_status;

-- =====================================================
-- 10. RECOMMENDATIONS
-- =====================================================

-- Provide recommendations based on findings
SELECT 
    'RECOMMENDATIONS:' as info,
    CASE 
        WHEN auth.uid() IS NULL THEN 'Log in to the application first'
        WHEN NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid()) THEN 'Create user profile in user_profiles table'
        WHEN EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND status != 'approved') THEN 'Update user status to approved in user_profiles table'
        WHEN NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'client_orders') THEN 'Run SUPABASE_RLS_FIX.sql to create proper RLS policies'
        ELSE 'Run SUPABASE_RLS_FIX.sql to fix RLS policies'
    END as recommendation;

-- =====================================================
-- DIAGNOSTIC COMPLETE
-- =====================================================

SELECT 'DIAGNOSTIC COMPLETED - Review results above' as status;
