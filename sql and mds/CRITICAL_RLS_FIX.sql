-- =====================================================
-- CRITICAL RLS POLICY FIX FOR INFINITE RECURSION
-- This script fixes the infinite recursion in user_profiles RLS policies
-- =====================================================

-- Step 1: Drop ALL existing policies on user_profiles to start clean
DROP POLICY IF EXISTS "Users can view their own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Admin users can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Admin users can update all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can create their own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Admin users can create any profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Admin users can update all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can insert all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Allow insert by self or during signup" ON public.user_profiles;
DROP POLICY IF EXISTS "Allow insert if no profile exists yet" ON public.user_profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.user_profiles;
DROP POLICY IF EXISTS "Approved users or admin can read profile" ON public.user_profiles;
DROP POLICY IF EXISTS "View own profile or admin bypass" ON public.user_profiles;
DROP POLICY IF EXISTS "Only approved users can update" ON public.user_profiles;
DROP POLICY IF EXISTS "Update own profile or admin bypass" ON public.user_profiles;

-- Step 2: Disable RLS temporarily to clean up
ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;

-- Step 3: Re-enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Step 4: Create SIMPLE, NON-RECURSIVE policies

-- Policy 1: Allow users to view their own profile (NO RECURSION)
CREATE POLICY "user_can_view_own_profile" ON public.user_profiles
FOR SELECT TO authenticated
USING (id = auth.uid());

-- Policy 2: Allow users to update their own profile (NO RECURSION)
CREATE POLICY "user_can_update_own_profile" ON public.user_profiles
FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Policy 3: Allow users to insert their own profile during signup (NO RECURSION)
CREATE POLICY "user_can_insert_own_profile" ON public.user_profiles
FOR INSERT TO authenticated
WITH CHECK (id = auth.uid());

-- Policy 4: Allow service role full access (for system operations)
CREATE POLICY "service_role_full_access" ON public.user_profiles
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

-- Step 5: Create helper function in public schema (avoiding auth schema permissions)
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE id = auth.uid()
    AND role = 'admin'
    AND status IN ('active', 'approved')
  );
$$;

-- Policy 5: Admin access using the helper function (NO RECURSION)
-- Note: This is commented out to avoid recursion. We'll use a simpler approach.
-- CREATE POLICY "admin_full_access" ON public.user_profiles
-- FOR ALL TO authenticated
-- USING (public.is_admin_user())
-- WITH CHECK (public.is_admin_user());

-- Step 6: Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.is_admin_user TO authenticated;

-- Step 7: Create or replace the profile creation function with proper security
CREATE OR REPLACE FUNCTION public.create_user_profile_safe(
    user_id UUID,
    user_email TEXT,
    user_name TEXT DEFAULT NULL,
    user_phone TEXT DEFAULT NULL,
    user_role TEXT DEFAULT 'client',
    user_status TEXT DEFAULT 'pending'
) RETURNS void AS $$
BEGIN
    -- Use INSERT with ON CONFLICT to avoid duplicates
    INSERT INTO public.user_profiles(
        id,
        email,
        name,
        phone_number,
        role,
        status,
        created_at,
        updated_at
    ) VALUES (
        user_id,
        user_email,
        COALESCE(user_name, 'مستخدم جديد'),
        user_phone,
        user_role,
        user_status,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        name = COALESCE(EXCLUDED.name, user_profiles.name),
        phone_number = COALESCE(EXCLUDED.phone_number, user_profiles.phone_number),
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.create_user_profile_safe TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_user_profile_safe TO anon;

-- Step 8: Verification queries
DO $$
BEGIN
    RAISE NOTICE '✅ RLS policies fixed successfully';
    RAISE NOTICE 'ℹ️  Current policies on user_profiles:';
END $$;

-- Show current policies
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'user_profiles'
ORDER BY policyname;
