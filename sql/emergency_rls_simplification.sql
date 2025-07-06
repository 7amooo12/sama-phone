-- Emergency RLS Simplification for user_profiles table
-- This is a minimal, guaranteed non-recursive approach

-- ========================================
-- EMERGENCY APPROACH: MINIMAL RLS POLICIES
-- ========================================

SELECT 
    '=== EMERGENCY RLS SIMPLIFICATION ===' as approach;

-- Step 1: Drop ALL existing policies
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

-- Step 2: Create only the most basic policies needed for authentication

-- Policy 1: Service role (Supabase internal) has full access
CREATE POLICY "service_role_access" ON user_profiles
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

-- Policy 2: Authenticated users can read all user profiles
-- This is the simplest approach - no conditions that could cause recursion
CREATE POLICY "authenticated_read_all" ON user_profiles
FOR SELECT TO authenticated
USING (true);

-- Policy 3: Users can only update their own profile
CREATE POLICY "users_update_own" ON user_profiles
FOR UPDATE TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 4: Only service role can insert (for user creation)
CREATE POLICY "service_role_insert" ON user_profiles
FOR INSERT TO service_role
WITH CHECK (true);

-- Policy 5: Only service role can delete (for user management)
CREATE POLICY "service_role_delete" ON user_profiles
FOR DELETE TO service_role
USING (true);

-- ========================================
-- TEST THE SIMPLIFIED POLICIES
-- ========================================

SELECT 
    '=== TESTING SIMPLIFIED POLICIES ===' as test_phase;

-- Test 1: Basic count
SELECT 
    'Basic Count Test' as test_name,
    COUNT(*) as user_count
FROM user_profiles;

-- Test 2: Eslam user query
SELECT 
    'Eslam User Test' as test_name,
    id,
    email,
    role,
    status
FROM user_profiles 
WHERE email = 'eslam@sama.com';

-- Test 3: All @sama.com users
SELECT 
    'Sama Users Test' as test_name,
    COUNT(*) as sama_user_count
FROM user_profiles 
WHERE email LIKE '%@sama.com';

-- ========================================
-- VERIFY POLICY SETUP
-- ========================================

SELECT 
    '=== CURRENT POLICY SETUP ===' as verification;

SELECT 
    policyname,
    cmd,
    roles,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- ========================================
-- SUCCESS CONFIRMATION
-- ========================================

SELECT 
    '=== EMERGENCY FIX COMPLETED ===' as status,
    'RLS policies simplified to prevent recursion' as action_taken,
    'All authenticated users can now read user_profiles' as access_level,
    'Test authentication flow immediately' as next_step;

-- ========================================
-- ALTERNATIVE: DISABLE RLS TEMPORARILY
-- ========================================

-- Uncomment the following lines if the simplified policies still cause issues:

-- SELECT '=== DISABLING RLS TEMPORARILY ===' as emergency_action;
-- ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;
-- SELECT 'RLS DISABLED - Authentication should work now' as result;
-- SELECT 'Remember to re-enable RLS after testing: ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;' as reminder;
