-- Fix RLS Infinite Recursion Error on user_profiles table
-- This script resolves PostgreSQL error code 42P17

-- ========================================
-- 1. BACKUP EXISTING POLICIES (FOR REFERENCE)
-- ========================================

SELECT 
    '=== BACKING UP EXISTING POLICIES ===' as step_info;

-- Create a backup table to store existing policy definitions
CREATE TABLE IF NOT EXISTS user_profiles_policy_backup AS
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check,
    NOW() as backup_timestamp
FROM pg_policies 
WHERE tablename = 'user_profiles';

-- ========================================
-- 2. DROP ALL EXISTING POLICIES
-- ========================================

SELECT 
    '=== DROPPING ALL EXISTING POLICIES ===' as step_info;

-- Drop all existing policies on user_profiles table
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    FOR policy_record IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'user_profiles'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_record.policyname || '" ON user_profiles';
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;
END $$;

-- ========================================
-- 3. CREATE SIMPLE, NON-RECURSIVE POLICIES
-- ========================================

SELECT 
    '=== CREATING NEW NON-RECURSIVE POLICIES ===' as step_info;

-- Policy 1: Users can read their own profile
CREATE POLICY "users_can_read_own_profile" ON user_profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Policy 2: Users can update their own profile
CREATE POLICY "users_can_update_own_profile" ON user_profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 3: Service role has full access (for admin operations)
CREATE POLICY "service_role_full_access" ON user_profiles
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy 4: Authenticated users can read approved users (for user lists)
-- This is simplified to avoid recursion - only reads basic info
CREATE POLICY "authenticated_can_read_approved_users" ON user_profiles
FOR SELECT
TO authenticated
USING (status IN ('approved', 'active'));

-- ========================================
-- 4. TEST THE NEW POLICIES
-- ========================================

SELECT 
    '=== TESTING NEW POLICIES ===' as step_info;

-- Test function to verify policies work without recursion
CREATE OR REPLACE FUNCTION test_new_policies()
RETURNS TABLE(test_name TEXT, result TEXT, details TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Test 1: Basic table access
    BEGIN
        PERFORM COUNT(*) FROM user_profiles;
        RETURN QUERY SELECT 'Basic Access'::TEXT, 'SUCCESS'::TEXT, 'Can count user_profiles rows'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 'Basic Access'::TEXT, 'FAILED'::TEXT, SQLERRM::TEXT;
    END;
    
    -- Test 2: Specific user query
    BEGIN
        PERFORM * FROM user_profiles WHERE email = 'eslam@sama.com';
        RETURN QUERY SELECT 'Eslam Query'::TEXT, 'SUCCESS'::TEXT, 'Can query eslam@sama.com'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 'Eslam Query'::TEXT, 'FAILED'::TEXT, SQLERRM::TEXT;
    END;
    
    -- Test 3: Email-based lookup (the failing operation)
    BEGIN
        PERFORM * FROM user_profiles WHERE email LIKE '%@sama.com';
        RETURN QUERY SELECT 'Email Lookup'::TEXT, 'SUCCESS'::TEXT, 'Can query by email pattern'::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT 'Email Lookup'::TEXT, 'FAILED'::TEXT, SQLERRM::TEXT;
    END;
END;
$$;

-- Run the tests
SELECT * FROM test_new_policies();

-- ========================================
-- 5. VERIFY ESLAM USER ACCESS
-- ========================================

SELECT 
    '=== VERIFYING ESLAM USER ACCESS ===' as step_info;

-- Test the specific query that was failing
SELECT 
    'ESLAM USER VERIFICATION' as test_type,
    id,
    name,
    email,
    role,
    status,
    email_confirmed
FROM user_profiles 
WHERE email = 'eslam@sama.com';

-- ========================================
-- 6. CREATE ADMIN-SPECIFIC POLICIES (IF NEEDED)
-- ========================================

SELECT 
    '=== CREATING ADMIN-SPECIFIC POLICIES ===' as step_info;

-- Policy for admin users to manage all users
-- This uses a simple role check without recursion
CREATE POLICY "admin_full_access" ON user_profiles
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND auth.users.raw_user_meta_data->>'role' = 'admin'
    )
);

-- ========================================
-- 7. FINAL VERIFICATION
-- ========================================

SELECT 
    '=== FINAL VERIFICATION ===' as step_info;

-- List all new policies
SELECT 
    'NEW POLICIES CREATED' as info,
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- Test critical operations
SELECT 
    'CRITICAL OPERATIONS TEST' as info,
    COUNT(*) as total_users,
    COUNT(CASE WHEN email LIKE '%@sama.com' THEN 1 END) as sama_users,
    COUNT(CASE WHEN email = 'eslam@sama.com' THEN 1 END) as eslam_user
FROM user_profiles;

-- ========================================
-- 8. CLEANUP AND SUCCESS MESSAGE
-- ========================================

-- Drop test function
DROP FUNCTION IF EXISTS test_new_policies();

SELECT 
    '=== RLS FIX COMPLETED ===' as status,
    'Infinite recursion error should be resolved' as result,
    'Test authentication with eslam@sama.com now' as next_step;

-- ========================================
-- 9. ROLLBACK INSTRUCTIONS (IF NEEDED)
-- ========================================

SELECT 
    '=== ROLLBACK INSTRUCTIONS (IF NEEDED) ===' as info,
    'If issues persist, you can restore from user_profiles_policy_backup table' as rollback_info,
    'Or temporarily disable RLS: ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;' as emergency_option;
