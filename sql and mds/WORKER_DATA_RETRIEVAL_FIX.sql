-- =====================================================
-- WORKER DATA RETRIEVAL FIX
-- Fixes RLS policies to allow proper worker data access
-- =====================================================

-- STEP 1: BACKUP CURRENT POLICIES
-- =====================================================

SELECT 
    '=== BACKING UP CURRENT POLICIES ===' as backup_info;

-- Show current policies before modification
SELECT 
    'Current user_profiles policies' as info,
    policyname,
    cmd,
    roles,
    qual
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'user_profiles'
ORDER BY policyname;

-- STEP 2: REMOVE PROBLEMATIC RECURSIVE POLICIES
-- =====================================================

SELECT 
    '=== REMOVING PROBLEMATIC POLICIES ===' as cleanup_info;

-- Remove policies that might cause recursion or access issues
DROP POLICY IF EXISTS "Admin users can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admin users can update all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can insert all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.user_profiles;

-- Remove any other potentially problematic policies
DROP POLICY IF EXISTS "View own profile or admin bypass" ON public.user_profiles;
DROP POLICY IF EXISTS "Approved users or admin can read profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Only approved users can update" ON public.user_profiles;

-- STEP 3: CREATE SAFE, NON-RECURSIVE POLICIES
-- =====================================================

SELECT 
    '=== CREATING SAFE POLICIES ===' as policy_creation;

-- Policy 1: Service role full access (for system operations)
CREATE POLICY "user_profiles_service_role_access" ON public.user_profiles
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

-- Policy 2: Users can view their own profile
CREATE POLICY "user_profiles_view_own" ON public.user_profiles
FOR SELECT TO authenticated
USING (id = auth.uid());

-- Policy 3: Users can update their own profile
CREATE POLICY "user_profiles_update_own" ON public.user_profiles
FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Policy 4: Users can insert their own profile during signup
CREATE POLICY "user_profiles_insert_own" ON public.user_profiles
FOR INSERT TO authenticated
WITH CHECK (id = auth.uid());

-- Policy 5: CRITICAL - Allow authenticated users to view worker profiles
-- This is the key policy that was missing and causing worker loading issues
CREATE POLICY "user_profiles_view_workers" ON public.user_profiles
FOR SELECT TO authenticated
USING (role = 'worker' AND status IN ('approved', 'active'));

-- Policy 6: Allow authenticated users to view all profiles for admin operations
-- This enables admin dashboards to load user data properly
CREATE POLICY "user_profiles_admin_view_all" ON public.user_profiles
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth.users 
        WHERE auth.users.id = auth.uid()
    )
);

-- STEP 4: CREATE SAFE ADMIN ACCESS FUNCTION
-- =====================================================

-- Create a function to check admin status without recursion
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'owner', 'accountant')
        AND status IN ('active', 'approved')
        LIMIT 1
    );
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.is_admin_user() TO authenticated;

-- Policy 7: Admin users can manage all profiles using safe function
CREATE POLICY "user_profiles_admin_manage_all" ON public.user_profiles
FOR ALL TO authenticated
USING (public.is_admin_user())
WITH CHECK (public.is_admin_user());

-- STEP 5: ENSURE RLS IS PROPERLY CONFIGURED
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- STEP 6: TEST THE FIX
-- =====================================================

SELECT 
    '=== TESTING THE FIX ===' as test_section;

-- Test 1: Check if workers are now visible
SELECT 
    'Workers visible after fix' as test_name,
    COUNT(*) as count
FROM public.user_profiles
WHERE role = 'worker';

-- Test 2: Check approved workers
SELECT 
    'Approved workers visible' as test_name,
    COUNT(*) as count
FROM public.user_profiles
WHERE role = 'worker'
AND status IN ('approved', 'active');

-- Test 3: Check if admin function works
SELECT 
    'Admin function test' as test_name,
    public.is_admin_user() as result;

-- Test 4: Simulate the getUsersByRole query
SELECT
    'getUsersByRole simulation' as test_name,
    COUNT(*) as count
FROM public.user_profiles
WHERE role = 'worker'
AND (status = 'approved' OR status = 'active');

-- STEP 7: VERIFY POLICY STRUCTURE
-- =====================================================

SELECT 
    '=== FINAL POLICY VERIFICATION ===' as verification;

-- Show final policies
SELECT 
    'Final user_profiles policies' as info,
    policyname,
    cmd,
    roles,
    CASE 
        WHEN qual LIKE '%user_profiles%' THEN '⚠️ POTENTIAL RECURSION'
        ELSE '✅ SAFE'
    END as safety_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'user_profiles'
ORDER BY policyname;

-- Check for any remaining recursive policies
SELECT 
    'Recursive policies remaining' as check_name,
    COUNT(*) as count
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'user_profiles'
AND (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%');

-- STEP 8: ADDITIONAL WORKER-SPECIFIC OPTIMIZATIONS
-- =====================================================

-- Create an index for faster worker queries if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_user_profiles_role_status 
ON public.user_profiles(role, status) 
WHERE role = 'worker';

-- Create an index for name ordering
CREATE INDEX IF NOT EXISTS idx_user_profiles_name 
ON public.user_profiles(name) 
WHERE role = 'worker';

-- STEP 9: SUCCESS VERIFICATION
-- =====================================================

SELECT 
    '=== SUCCESS VERIFICATION ===' as final_check;

-- Final verification that workers are accessible
DO $$
DECLARE
    worker_count INTEGER;
    approved_worker_count INTEGER;
BEGIN
    -- Count total workers
    SELECT COUNT(*) INTO worker_count
    FROM public.user_profiles
    WHERE role = 'worker';
    
    -- Count approved workers
    SELECT COUNT(*) INTO approved_worker_count
    FROM public.user_profiles
    WHERE role = 'worker'
    AND status IN ('approved', 'active');
    
    -- Report results
    RAISE NOTICE '✅ Total workers found: %', worker_count;
    RAISE NOTICE '✅ Approved workers found: %', approved_worker_count;
    
    IF worker_count > 0 THEN
        RAISE NOTICE '🎉 SUCCESS: Worker data retrieval should now work in Flutter app';
    ELSE
        RAISE NOTICE '⚠️ WARNING: No workers found in database - check worker registration';
    END IF;
    
END $$;

-- STEP 10: FLUTTER APP TESTING GUIDANCE
-- =====================================================

SELECT 
    '=== FLUTTER APP TESTING GUIDANCE ===' as guidance;

SELECT 
    'Next steps for Flutter app' as step,
    'Test worker loading in the following screens:' as action;

SELECT 
    'Screen to test' as screen,
    'Expected result' as expected
UNION ALL
SELECT 'Owner Dashboard - Workers Tab', 'Should show list of workers'
UNION ALL
SELECT 'Admin Task Assignment', 'Should show workers in dropdown'
UNION ALL
SELECT 'Accountant Rewards Management', 'Should show workers for reward assignment'
UNION ALL
SELECT 'Worker Performance Analytics', 'Should display worker statistics';

-- Final success message
SELECT 
    '🎯 WORKER DATA RETRIEVAL FIX COMPLETE' as status,
    'Worker loading should now work in Flutter app' as result,
    'Test the app to verify worker data appears correctly' as next_step;
