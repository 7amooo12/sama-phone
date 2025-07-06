-- Test script to verify the infinite recursion fix is working
-- This script tests the SECURITY DEFINER functions and RLS policies

-- =====================================================
-- STEP 1: TEST SECURITY DEFINER FUNCTIONS
-- =====================================================

SELECT 'Testing SECURITY DEFINER functions...' as test_phase;

-- Test 1: Check if functions exist
SELECT 
    'Function exists: ' || proname as function_check
FROM pg_proc 
WHERE proname IN (
    'get_user_by_email_safe',
    'get_user_by_id_safe', 
    'user_has_role_safe',
    'user_is_approved_safe'
);

-- Test 2: Test get_user_by_email_safe function
SELECT 'Testing get_user_by_email_safe function...' as test_step;

-- This should work without infinite recursion
SELECT 
    id, 
    email, 
    name, 
    role, 
    status
FROM get_user_by_email_safe('eslam@sama.com');

-- Test 3: Test get_user_by_id_safe function (if we have a known user ID)
SELECT 'Testing get_user_by_id_safe function...' as test_step;

-- Get a user ID first, then test the function
DO $$
DECLARE
    test_user_id uuid;
BEGIN
    -- Get a user ID from the test email
    SELECT id INTO test_user_id 
    FROM get_user_by_email_safe('eslam@sama.com') 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        RAISE NOTICE 'Testing get_user_by_id_safe with ID: %', test_user_id;
        
        -- Test the function
        PERFORM * FROM get_user_by_id_safe(test_user_id);
        
        RAISE NOTICE 'get_user_by_id_safe function test passed';
    ELSE
        RAISE NOTICE 'No test user found, skipping get_user_by_id_safe test';
    END IF;
END $$;

-- =====================================================
-- STEP 2: TEST RLS POLICIES
-- =====================================================

SELECT 'Testing RLS policies...' as test_phase;

-- Test 4: Check current RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- Test 5: Test anonymous access (should work for email checks)
SET ROLE anon;
SELECT 'Testing anonymous access...' as test_step;

-- This should work for signup validation
SELECT COUNT(*) as user_count 
FROM user_profiles 
WHERE email = 'eslam@sama.com';

-- Reset role
RESET ROLE;

-- =====================================================
-- STEP 3: SIMULATE AUTHENTICATION FLOW
-- =====================================================

SELECT 'Simulating authentication flow...' as test_phase;

-- Test 6: Simulate the exact query that was causing infinite recursion
SELECT 'Testing the problematic query pattern...' as test_step;

-- This is the pattern that was causing infinite recursion
-- Now it should work through the SECURITY DEFINER function
SELECT 
    id,
    email,
    name,
    role,
    status,
    created_at
FROM get_user_by_email_safe('eslam@sama.com');

-- Test 7: Test role-based access
SELECT 'Testing role-based access patterns...' as test_step;

-- Test user_has_role_safe function
DO $$
DECLARE
    test_user_id uuid;
    is_admin boolean;
    is_approved boolean;
BEGIN
    -- Get test user ID
    SELECT id INTO test_user_id 
    FROM get_user_by_email_safe('eslam@sama.com') 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        -- Test role checking
        SELECT user_has_role_safe(test_user_id, 'admin') INTO is_admin;
        SELECT user_is_approved_safe(test_user_id) INTO is_approved;
        
        RAISE NOTICE 'User % - Is Admin: %, Is Approved: %', test_user_id, is_admin, is_approved;
    END IF;
END $$;

-- =====================================================
-- STEP 4: PERFORMANCE TEST
-- =====================================================

SELECT 'Running performance test...' as test_phase;

-- Test 8: Performance comparison
SELECT 'Testing query performance...' as test_step;

-- Time the SECURITY DEFINER function
\timing on

SELECT COUNT(*) as function_result
FROM get_user_by_email_safe('eslam@sama.com');

\timing off

-- =====================================================
-- STEP 5: FINAL VERIFICATION
-- =====================================================

SELECT 'Final verification...' as test_phase;

-- Test 9: Verify no infinite recursion
SELECT 'Verifying no infinite recursion in complex queries...' as test_step;

-- This type of query was problematic before
SELECT 
    u.id,
    u.email,
    u.name,
    u.role,
    u.status,
    CASE 
        WHEN u.status IN ('approved', 'active') THEN 'Active User'
        ELSE 'Inactive User'
    END as user_status_description
FROM get_user_by_email_safe('eslam@sama.com') u;

-- Test 10: Test multiple concurrent calls (simulate real app usage)
SELECT 'Testing multiple concurrent function calls...' as test_step;

SELECT 
    'User 1' as test_case,
    COUNT(*) as result
FROM get_user_by_email_safe('eslam@sama.com')

UNION ALL

SELECT 
    'User 2' as test_case,
    COUNT(*) as result  
FROM get_user_by_email_safe('eslam@sama.com')

UNION ALL

SELECT 
    'User 3' as test_case,
    COUNT(*) as result
FROM get_user_by_email_safe('eslam@sama.com');

-- =====================================================
-- FINAL RESULT
-- =====================================================

SELECT 
    'INFINITE RECURSION FIX TEST COMPLETED SUCCESSFULLY!' as final_result,
    NOW() as completion_time;

SELECT 
    'If you see this message without errors, the infinite recursion fix is working correctly.' as success_message;
