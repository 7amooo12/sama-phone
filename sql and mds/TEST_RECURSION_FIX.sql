-- =====================================================
-- SIMPLE TEST FOR RECURSION FIX
-- Run this after EMERGENCY_RLS_RECURSION_FIX.sql
-- =====================================================

-- Test 1: Basic table access (should not hang or error)
SELECT 'Test 1: Basic COUNT operation' as test_name;
SELECT COUNT(*) as total_profiles FROM public.user_profiles;

-- Test 2: Check remaining policies for recursion patterns
SELECT 'Test 2: Policy Safety Check' as test_name;
SELECT 
    policyname,
    CASE 
        WHEN qual LIKE '%user_profiles%' AND policyname NOT LIKE '%service_role%' 
        THEN 'POTENTIAL RECURSION RISK'
        ELSE 'SAFE'
    END as safety_status,
    cmd as operation
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'user_profiles'
ORDER BY policyname;

-- Test 3: Test the new safe admin function
SELECT 'Test 3: Safe Admin Function' as test_name;
SELECT public.is_admin_safe() as admin_check_result;

-- Test 4: Simple SELECT with WHERE clause (common operation that was failing)
SELECT 'Test 4: SELECT with WHERE clause' as test_name;
SELECT COUNT(*) as count_with_where 
FROM public.user_profiles 
WHERE role = 'client';

-- Test 5: Verify RLS is still enabled
SELECT 'Test 5: RLS Status Check' as test_name;
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'user_profiles';

-- Final Result
SELECT 
    '✅ RECURSION FIX VERIFICATION COMPLETE' as result,
    'If all tests above completed without hanging, the fix was successful' as message,
    'You can now test Flutter app authentication' as next_action;
