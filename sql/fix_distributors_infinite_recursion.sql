-- CRITICAL FIX: Resolve infinite recursion in distributors and distribution_centers RLS policies
-- This addresses the PostgreSQL error: "infinite recursion detected in policy for relation user_profiles"
-- Error occurs when distributors RLS policies query user_profiles table directly

-- =====================================================
-- STEP 1: IDENTIFY THE PROBLEM
-- =====================================================

SELECT 'Fixing distributors infinite recursion issue...' as status;

-- The issue: distributors and distribution_centers RLS policies directly query user_profiles
-- This triggers infinite recursion in user_profiles RLS policies
-- Solution: Use SECURITY DEFINER functions to bypass RLS

-- =====================================================
-- STEP 2: DROP EXISTING PROBLEMATIC POLICIES
-- =====================================================

-- Drop all existing distributors policies that cause recursion
DROP POLICY IF EXISTS "distribution_centers_select_policy" ON public.distribution_centers;
DROP POLICY IF EXISTS "distribution_centers_insert_policy" ON public.distribution_centers;
DROP POLICY IF EXISTS "distribution_centers_update_policy" ON public.distribution_centers;
DROP POLICY IF EXISTS "distribution_centers_delete_policy" ON public.distribution_centers;

DROP POLICY IF EXISTS "distributors_select_policy" ON public.distributors;
DROP POLICY IF EXISTS "distributors_insert_policy" ON public.distributors;
DROP POLICY IF EXISTS "distributors_update_policy" ON public.distributors;
DROP POLICY IF EXISTS "distributors_delete_policy" ON public.distributors;

SELECT 'Dropped existing problematic RLS policies' as step_completed;

-- =====================================================
-- STEP 3: CREATE SECURITY DEFINER FUNCTIONS FOR ROLE CHECKING
-- =====================================================

-- Function to safely check if user has admin/owner role (bypasses RLS)
CREATE OR REPLACE FUNCTION public.user_has_distributor_access_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 
        FROM user_profiles up
        WHERE up.id = auth.uid() 
        AND up.role IN ('admin', 'owner')
        AND up.status IN ('approved', 'active')
    );
$$;

-- Function to safely check if user has admin/owner/accountant role (for broader access)
CREATE OR REPLACE FUNCTION public.user_has_distributor_read_access_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 
        FROM user_profiles up
        WHERE up.id = auth.uid() 
        AND up.role IN ('admin', 'owner', 'accountant')
        AND up.status IN ('approved', 'active')
    );
$$;

SELECT 'Created SECURITY DEFINER functions for role checking' as step_completed;

-- =====================================================
-- STEP 4: CREATE NEW NON-RECURSIVE RLS POLICIES
-- =====================================================

-- Distribution Centers Policies (using SECURITY DEFINER functions)

-- Allow admins/owners/accountants to view all centers
CREATE POLICY "distribution_centers_select_safe" ON public.distribution_centers
    FOR SELECT USING (
        public.user_has_distributor_read_access_safe()
    );

-- Allow admins and owners to insert centers
CREATE POLICY "distribution_centers_insert_safe" ON public.distribution_centers
    FOR INSERT WITH CHECK (
        public.user_has_distributor_access_safe()
    );

-- Allow admins and owners to update centers
CREATE POLICY "distribution_centers_update_safe" ON public.distribution_centers
    FOR UPDATE USING (
        public.user_has_distributor_access_safe()
    );

-- Allow admins and owners to delete centers
CREATE POLICY "distribution_centers_delete_safe" ON public.distribution_centers
    FOR DELETE USING (
        public.user_has_distributor_access_safe()
    );

-- Distributors Policies (using SECURITY DEFINER functions)

-- Allow admins/owners/accountants to view all distributors
CREATE POLICY "distributors_select_safe" ON public.distributors
    FOR SELECT USING (
        public.user_has_distributor_read_access_safe()
    );

-- Allow admins and owners to insert distributors
CREATE POLICY "distributors_insert_safe" ON public.distributors
    FOR INSERT WITH CHECK (
        public.user_has_distributor_access_safe()
    );

-- Allow admins and owners to update distributors
CREATE POLICY "distributors_update_safe" ON public.distributors
    FOR UPDATE USING (
        public.user_has_distributor_access_safe()
    );

-- Allow admins and owners to delete distributors
CREATE POLICY "distributors_delete_safe" ON public.distributors
    FOR DELETE USING (
        public.user_has_distributor_access_safe()
    );

SELECT 'Created new non-recursive RLS policies using SECURITY DEFINER functions' as step_completed;

-- =====================================================
-- STEP 5: GRANT PERMISSIONS ON FUNCTIONS
-- =====================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.user_has_distributor_access_safe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_has_distributor_read_access_safe() TO authenticated;

-- Grant execute permissions to service role
GRANT EXECUTE ON FUNCTION public.user_has_distributor_access_safe() TO service_role;
GRANT EXECUTE ON FUNCTION public.user_has_distributor_read_access_safe() TO service_role;

SELECT 'Granted function permissions' as step_completed;

-- =====================================================
-- STEP 6: VERIFICATION
-- =====================================================

SELECT 'Verifying distributors RLS policies...' as status;

-- Check that new policies exist
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd
FROM pg_policies 
WHERE tablename IN ('distribution_centers', 'distributors')
ORDER BY tablename, policyname;

-- Check that functions exist
SELECT 
    proname as function_name,
    'EXISTS' as status
FROM pg_proc 
WHERE proname IN (
    'user_has_distributor_access_safe',
    'user_has_distributor_read_access_safe'
)
ORDER BY proname;

SELECT 'Distributors infinite recursion fix completed successfully!' as final_status;

-- =====================================================
-- SUMMARY OF CHANGES
-- =====================================================

SELECT 
    'SUMMARY OF DISTRIBUTORS INFINITE RECURSION FIX:' as summary_title,
    '1. Dropped old RLS policies that directly queried user_profiles' as fix_1,
    '2. Created SECURITY DEFINER functions to bypass RLS for role checking' as fix_2,
    '3. Created new RLS policies using SECURITY DEFINER functions' as fix_3,
    '4. Granted proper permissions on new functions' as fix_4,
    '5. Eliminated infinite recursion in distributors queries' as fix_5;
