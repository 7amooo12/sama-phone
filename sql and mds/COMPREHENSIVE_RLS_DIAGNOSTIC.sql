-- =====================================================
-- COMPREHENSIVE RLS DIAGNOSTIC FOR CLIENT ORDERS
-- =====================================================
-- This script will identify exactly why RLS is failing
-- =====================================================

-- =====================================================
-- 1. CHECK CURRENT USER AUTHENTICATION
-- =====================================================

-- Check current authenticated user
SELECT 
    'CURRENT USER AUTHENTICATION:' as section,
    CASE 
        WHEN auth.uid() IS NULL THEN 'ERROR: No authenticated user'
        ELSE 'SUCCESS: User ID = ' || auth.uid()::text
    END as auth_status;

-- =====================================================
-- 2. CHECK USER PROFILE DETAILS
-- =====================================================

-- Get detailed user profile information
SELECT 
    'USER PROFILE DETAILS:' as section,
    id,
    email,
    name,
    role,
    status,
    created_at,
    updated_at
FROM public.user_profiles 
WHERE id = auth.uid();

-- Check if user profile exists
SELECT 
    'USER PROFILE CHECK:' as section,
    CASE 
        WHEN EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid()) THEN 'EXISTS'
        ELSE 'MISSING - This is likely the problem!'
    END as profile_status;

-- =====================================================
-- 3. CHECK CLIENT_ORDERS TABLE STRUCTURE
-- =====================================================

-- Verify table structure
SELECT 
    'CLIENT_ORDERS TABLE STRUCTURE:' as section,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'client_orders'
ORDER BY ordinal_position;

-- =====================================================
-- 4. CHECK CURRENT RLS POLICIES
-- =====================================================

-- Show all current RLS policies
SELECT 
    'CURRENT RLS POLICIES:' as section,
    policyname,
    cmd as command,
    roles,
    qual as using_condition,
    with_check as with_check_condition
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public'
ORDER BY policyname;

-- Check RLS status
SELECT 
    'RLS STATUS:' as section,
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'client_orders';

-- =====================================================
-- 5. TEST POLICY CONDITIONS INDIVIDUALLY
-- =====================================================

-- Test admin policy condition
SELECT 
    'ADMIN POLICY TEST:' as section,
    EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role = 'admin'
        AND user_profiles.status = 'approved'
    ) as matches_admin_policy;

-- Test owner policy condition
SELECT 
    'OWNER POLICY TEST:' as section,
    EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role = 'owner'
        AND user_profiles.status = 'approved'
    ) as matches_owner_policy;

-- Test accountant policy condition
SELECT 
    'ACCOUNTANT POLICY TEST:' as section,
    EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role = 'accountant'
        AND user_profiles.status = 'approved'
    ) as matches_accountant_policy;

-- Test client policy condition
SELECT 
    'CLIENT POLICY TEST:' as section,
    EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role = 'client'
        AND user_profiles.status = 'approved'
    ) as matches_client_policy;

-- Test fallback policy condition
SELECT 
    'FALLBACK POLICY TEST:' as section,
    EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() 
        AND user_profiles.status = 'approved'
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'manager', 'client', 'worker')
    ) as matches_fallback_policy;

-- =====================================================
-- 6. SIMULATE THE EXACT INSERT FROM FLUTTER APP
-- =====================================================

-- Test the exact insert that the Flutter app is trying to do
-- This simulates the SupabaseOrdersService.createOrder method

-- First, let's see what data would be inserted
SELECT 
    'SIMULATED INSERT DATA:' as section,
    auth.uid() as client_id,
    'Test Customer' as client_name,
    'test@example.com' as client_email,
    '+1234567890' as client_phone,
    100.50 as total_amount,
    'pending' as status,
    'pending' as payment_status,
    'Test notes' as notes;

-- =====================================================
-- 7. CHECK TABLE PERMISSIONS
-- =====================================================

-- Check table permissions for authenticated role
SELECT 
    'TABLE PERMISSIONS:' as section,
    privilege_type,
    grantee,
    is_grantable
FROM information_schema.table_privileges 
WHERE table_schema = 'public' 
AND table_name = 'client_orders'
ORDER BY privilege_type;

-- =====================================================
-- 8. CHECK FOR CONFLICTING POLICIES
-- =====================================================

-- Look for any policies that might be conflicting
SELECT 
    'POLICY CONFLICT CHECK:' as section,
    COUNT(*) as total_policies,
    COUNT(*) FILTER (WHERE cmd = 'INSERT') as insert_policies,
    COUNT(*) FILTER (WHERE cmd = 'ALL') as all_policies
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public';

-- =====================================================
-- 9. DETAILED POLICY ANALYSIS
-- =====================================================

-- Show detailed policy information
SELECT 
    'DETAILED POLICY ANALYSIS:' as section,
    policyname,
    cmd,
    permissive,
    roles,
    CASE 
        WHEN qual IS NOT NULL THEN 'Has USING clause'
        ELSE 'No USING clause'
    END as using_status,
    CASE 
        WHEN with_check IS NOT NULL THEN 'Has WITH CHECK clause'
        ELSE 'No WITH CHECK clause'
    END as with_check_status
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public'
ORDER BY cmd, policyname;

-- =====================================================
-- 10. FINAL DIAGNOSIS
-- =====================================================

-- Provide a comprehensive diagnosis
SELECT 
    'DIAGNOSIS SUMMARY:' as section,
    CASE 
        WHEN auth.uid() IS NULL THEN 'PROBLEM: User not authenticated'
        WHEN NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid()) THEN 'PROBLEM: User profile missing'
        WHEN EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND status != 'approved') THEN 'PROBLEM: User not approved'
        WHEN NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'client_orders') THEN 'PROBLEM: No RLS policies exist'
        WHEN NOT EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.status = 'approved'
            AND user_profiles.role IN ('admin', 'owner', 'accountant', 'manager', 'client', 'worker')
        ) THEN 'PROBLEM: User does not match any policy conditions'
        ELSE 'UNCLEAR: Policies should allow access - may need manual test'
    END as diagnosis;

-- Show specific recommendations
SELECT 
    'RECOMMENDATIONS:' as section,
    CASE 
        WHEN auth.uid() IS NULL THEN 'Log in to the application'
        WHEN NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid()) THEN 'Create user profile or check user registration'
        WHEN EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND status != 'approved') THEN 'Update user status to approved'
        WHEN NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'client_orders') THEN 'Run RLS policy creation script'
        ELSE 'Try manual insert test or check for policy conflicts'
    END as recommendation;

-- =====================================================
-- DIAGNOSTIC COMPLETE
-- =====================================================

SELECT 'COMPREHENSIVE DIAGNOSTIC COMPLETED' as status;
