-- =====================================================
-- EMERGENCY FIX FOR RLS INFINITE RECURSION
-- This script removes ALL recursive policies causing the infinite loop
-- =====================================================

-- Step 1: Drop ALL problematic recursive policies
DROP POLICY IF EXISTS "Accountant can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Owner can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admin can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admin users can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admin users can update all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can insert all profiles" ON public.user_profiles;

-- Step 2: Keep only the SAFE, NON-RECURSIVE policies
-- These are the policies that work without causing recursion:

-- ✅ SAFE: user_can_view_own_profile (no recursion)
-- ✅ SAFE: user_can_update_own_profile (no recursion)  
-- ✅ SAFE: user_can_insert_own_profile (no recursion)
-- ✅ SAFE: service_role_full_access (for system operations)
-- ✅ SAFE: temp_open_access (temporary public access)

-- Step 3: Create a SAFE admin check using auth.jwt() instead of user_profiles lookup
CREATE OR REPLACE FUNCTION public.is_admin_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT COALESCE(
    (auth.jwt() ->> 'user_metadata')::jsonb ->> 'role' = 'admin',
    false
  );
$$;

-- Step 4: Create SAFE admin policies using the non-recursive function
CREATE POLICY "admin_safe_view_all" ON public.user_profiles
FOR SELECT TO authenticated
USING (public.is_admin_safe());

CREATE POLICY "admin_safe_update_all" ON public.user_profiles
FOR UPDATE TO authenticated
USING (public.is_admin_safe())
WITH CHECK (public.is_admin_safe());

CREATE POLICY "admin_safe_insert_all" ON public.user_profiles
FOR INSERT TO authenticated
WITH CHECK (public.is_admin_safe());

-- Step 5: Grant permissions
GRANT EXECUTE ON FUNCTION public.is_admin_safe TO authenticated;

-- Step 6: Verification - show remaining policies
SELECT 
    '=== REMAINING POLICIES AFTER RECURSION FIX ===' as info;

SELECT 
    policyname,
    cmd,
    CASE 
        WHEN qual LIKE '%user_profiles%' AND policyname NOT LIKE '%service_role%' 
        THEN '⚠️ STILL RECURSIVE'
        ELSE '✅ SAFE'
    END as safety_status
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'user_profiles'
ORDER BY policyname;

-- Step 7: Test the fix
DO $$
BEGIN
    -- This should work without infinite recursion
    PERFORM COUNT(*) FROM public.user_profiles LIMIT 1;
    RAISE NOTICE '✅ Basic SELECT test passed - no infinite recursion detected';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Basic SELECT test failed: %', SQLERRM;
END $$;

-- Step 8: Create a simple role-based access alternative
-- Instead of complex recursive policies, use a simple approach:

-- Remove the temp open access policy for security
DROP POLICY IF EXISTS "temp_open_access" ON public.user_profiles;

-- Create a simple authenticated user policy for basic access
CREATE POLICY "authenticated_basic_access" ON public.user_profiles
FOR SELECT TO authenticated
USING (
    -- Users can see their own profile OR if they are admin (from JWT)
    id = auth.uid() 
    OR 
    COALESCE((auth.jwt() ->> 'user_metadata')::jsonb ->> 'role' = 'admin', false)
);

-- Step 9: Final verification message
SELECT 
    '🎯 EMERGENCY FIX COMPLETE' as status,
    'Infinite recursion policies have been removed' as message,
    'Test your Flutter app authentication now' as next_step;
