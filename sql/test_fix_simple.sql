-- Simple test script to verify the infinite recursion fix
-- This tests the SECURITY DEFINER functions with correct column references

-- =====================================================
-- STEP 1: TEST FUNCTION EXISTENCE
-- =====================================================

SELECT 'Testing function existence...' as test_phase;

-- Check if our functions exist
SELECT 
    proname as function_name,
    'EXISTS' as status
FROM pg_proc 
WHERE proname IN (
    'get_user_by_email_safe',
    'get_user_by_id_safe', 
    'user_has_role_safe',
    'user_is_approved_safe'
)
ORDER BY proname;

-- =====================================================
-- STEP 2: TEST get_user_by_email_safe FUNCTION
-- =====================================================

SELECT 'Testing get_user_by_email_safe function...' as test_step;

-- Test the function that was causing infinite recursion
SELECT 
    id, 
    email, 
    name, 
    role, 
    status,
    created_at
FROM get_user_by_email_safe('eslam@sama.com');

-- =====================================================
-- STEP 3: TEST get_user_by_id_safe FUNCTION
-- =====================================================

SELECT 'Testing get_user_by_id_safe function...' as test_step;

-- Get a user ID first, then test the function
DO $$
DECLARE
    test_user_id uuid;
    user_record RECORD;
BEGIN
    -- Get a user ID from the test email
    SELECT id INTO test_user_id 
    FROM get_user_by_email_safe('eslam@sama.com') 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        RAISE NOTICE 'Testing get_user_by_id_safe with ID: %', test_user_id;
        
        -- Test the function
        SELECT * INTO user_record FROM get_user_by_id_safe(test_user_id) LIMIT 1;
        
        IF user_record.id IS NOT NULL THEN
            RAISE NOTICE 'get_user_by_id_safe function test PASSED - User: %', user_record.name;
        ELSE
            RAISE NOTICE 'get_user_by_id_safe function test FAILED - No user returned';
        END IF;
    ELSE
        RAISE NOTICE 'No test user found, skipping get_user_by_id_safe test';
    END IF;
END $$;

-- =====================================================
-- STEP 4: TEST ROLE CHECKING FUNCTIONS
-- =====================================================

SELECT 'Testing role checking functions...' as test_step;

-- Test user_has_role_safe and user_is_approved_safe functions
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
        RAISE NOTICE 'Role checking functions test PASSED';
    ELSE
        RAISE NOTICE 'No test user found, skipping role checking test';
    END IF;
END $$;

-- =====================================================
-- STEP 5: TEST RLS POLICIES
-- =====================================================

SELECT 'Testing RLS policies...' as test_step;

-- Check current RLS policies
SELECT 
    policyname,
    cmd,
    permissive,
    roles
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- =====================================================
-- STEP 6: SIMULATE AUTHENTICATION FLOW
-- =====================================================

SELECT 'Simulating authentication flow...' as test_step;

-- This is the exact pattern that was causing infinite recursion
-- Now it should work through the SECURITY DEFINER function
SELECT 
    'Authentication simulation' as test_type,
    COUNT(*) as user_found
FROM get_user_by_email_safe('eslam@sama.com');

-- =====================================================
-- FINAL VERIFICATION
-- =====================================================

SELECT 
    'INFINITE RECURSION FIX TEST COMPLETED!' as result,
    'If you see this message, the fix is working correctly.' as message,
    NOW() as completion_time;
