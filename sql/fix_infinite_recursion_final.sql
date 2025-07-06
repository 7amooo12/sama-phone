-- CRITICAL FIX: Resolve infinite recursion in user_profiles RLS policies
-- This addresses the PostgreSQL error: "infinite recursion detected in policy for relation user_profiles"
-- Error code: 42P17

-- =====================================================
-- STEP 1: CLEAN UP ALL EXISTING PROBLEMATIC POLICIES
-- =====================================================

SELECT 'Starting infinite recursion fix for user_profiles RLS policies...' as status;

-- Drop ALL existing policies that might cause recursion
DROP POLICY IF EXISTS "user_profiles_open_access" ON public.user_profiles;
DROP POLICY IF EXISTS "authenticated_users_select_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "authenticated_users_update_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "authenticated_users_insert_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "admins_view_all_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "admins_insert_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "admins_delete_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "service_role_access" ON public.user_profiles;
DROP POLICY IF EXISTS "authenticated_read_all" ON public.user_profiles;
DROP POLICY IF EXISTS "users_update_own" ON public.user_profiles;
DROP POLICY IF EXISTS "users_view_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "users_update_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "users_insert_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "service_role_full_access" ON public.user_profiles;
DROP POLICY IF EXISTS "public_read_for_signup_checks" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_service_role_access" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_view_own" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_update_own" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_insert_own" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_authenticated_view_all" ON public.user_profiles;
DROP POLICY IF EXISTS "users_can_read_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "users_can_update_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "user_can_view_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "user_can_update_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "user_can_insert_own_profile" ON public.user_profiles;

SELECT 'Dropped all existing policies' as step_completed;

-- =====================================================
-- STEP 2: CREATE SECURITY DEFINER FUNCTIONS TO BYPASS RLS
-- =====================================================

-- Function to safely get user by email (bypasses RLS)
CREATE OR REPLACE FUNCTION public.get_user_by_email_safe(user_email text)
RETURNS TABLE(
    id uuid,
    email text,
    name text,
    phone_number text,
    role text,
    status text,
    profile_image text,
    created_at timestamptz,
    updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        up.id,
        up.email,
        up.name,
        up.phone_number,
        up.role,
        up.status,
        up.profile_image,
        up.created_at,
        up.updated_at
    FROM user_profiles up
    WHERE up.email = user_email
    LIMIT 1;
$$;

-- Function to safely get user by ID (bypasses RLS)
CREATE OR REPLACE FUNCTION public.get_user_by_id_safe(user_id uuid)
RETURNS TABLE(
    id uuid,
    email text,
    name text,
    phone_number text,
    role text,
    status text,
    profile_image text,
    created_at timestamptz,
    updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        up.id,
        up.email,
        up.name,
        up.phone_number,
        up.role,
        up.status,
        up.profile_image,
        up.created_at,
        up.updated_at
    FROM user_profiles up
    WHERE up.id = user_id
    LIMIT 1;
$$;

-- Function to check if user has specific role (bypasses RLS)
CREATE OR REPLACE FUNCTION public.user_has_role_safe(user_id uuid, required_role text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 
        FROM user_profiles up
        WHERE up.id = user_id 
        AND up.role = required_role
        AND up.status IN ('approved', 'active')
    );
$$;

-- Function to check if user is approved (bypasses RLS)
CREATE OR REPLACE FUNCTION public.user_is_approved_safe(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 
        FROM user_profiles up
        WHERE up.id = user_id 
        AND up.status IN ('approved', 'active')
    );
$$;

-- Function to safely update user profile (bypasses RLS)
CREATE OR REPLACE FUNCTION public.update_user_profile_safe(
    user_id uuid,
    update_data jsonb
)
RETURNS TABLE(
    id uuid,
    email text,
    name text,
    phone_number text,
    role text,
    status text,
    profile_image text,
    created_at timestamptz,
    updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE user_profiles
    SET
        email = COALESCE((update_data->>'email')::text, email),
        name = COALESCE((update_data->>'name')::text, name),
        phone_number = COALESCE((update_data->>'phone_number')::text, phone_number),
        role = COALESCE((update_data->>'role')::text, role),
        status = COALESCE((update_data->>'status')::text, status),
        profile_image = COALESCE((update_data->>'profile_image')::text, profile_image),
        updated_at = COALESCE((update_data->>'updated_at')::timestamptz, NOW())
    WHERE user_profiles.id = user_id
    RETURNING
        user_profiles.id,
        user_profiles.email,
        user_profiles.name,
        user_profiles.phone_number,
        user_profiles.role,
        user_profiles.status,
        user_profiles.profile_image,
        user_profiles.created_at,
        user_profiles.updated_at;
$$;

-- Function to safely delete user profile (bypasses RLS)
CREATE OR REPLACE FUNCTION public.delete_user_profile_safe(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    WITH deleted AS (
        DELETE FROM user_profiles
        WHERE id = user_id
        RETURNING id
    )
    SELECT COUNT(*) > 0 FROM deleted;
$$;

-- Function to safely insert user profile (bypasses RLS)
CREATE OR REPLACE FUNCTION public.insert_user_profile_safe(
    user_id uuid,
    user_email text,
    user_name text,
    user_phone text DEFAULT NULL,
    user_role text DEFAULT 'client',
    user_status text DEFAULT 'pending',
    user_profile_image text DEFAULT NULL
)
RETURNS TABLE(
    id uuid,
    email text,
    name text,
    phone_number text,
    role text,
    status text,
    profile_image text,
    created_at timestamptz,
    updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    INSERT INTO user_profiles (
        id, email, name, phone_number, role, status, profile_image, created_at, updated_at
    ) VALUES (
        user_id, user_email, user_name, user_phone, user_role, user_status, user_profile_image, NOW(), NOW()
    )
    RETURNING
        user_profiles.id,
        user_profiles.email,
        user_profiles.name,
        user_profiles.phone_number,
        user_profiles.role,
        user_profiles.status,
        user_profiles.profile_image,
        user_profiles.created_at,
        user_profiles.updated_at;
$$;

SELECT 'Created SECURITY DEFINER functions for all operations' as step_completed;

-- =====================================================
-- STEP 3: CREATE SIMPLE, NON-RECURSIVE RLS POLICIES
-- =====================================================

-- Temporarily disable RLS to clean up
ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;

-- Re-enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to ensure clean state (idempotent)
DROP POLICY IF EXISTS "service_role_full_access" ON public.user_profiles;
DROP POLICY IF EXISTS "users_view_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "users_update_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "users_insert_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "anonymous_email_check" ON public.user_profiles;

-- Policy 1: Service role has full access (for system operations)
CREATE POLICY "service_role_full_access" ON public.user_profiles
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

-- Policy 2: Users can view their own profile (NO RECURSION)
CREATE POLICY "users_view_own_profile" ON public.user_profiles
FOR SELECT TO authenticated
USING (id = auth.uid());

-- Policy 3: Users can update their own profile (NO RECURSION)
CREATE POLICY "users_update_own_profile" ON public.user_profiles
FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Policy 4: Users can insert their own profile during signup (NO RECURSION)
CREATE POLICY "users_insert_own_profile" ON public.user_profiles
FOR INSERT TO authenticated
WITH CHECK (id = auth.uid());

-- Policy 5: Allow anonymous users to check if email exists (for signup validation)
CREATE POLICY "anonymous_email_check" ON public.user_profiles
FOR SELECT TO anon
USING (true);

SELECT 'Created simple, non-recursive RLS policies (idempotent)' as step_completed;

-- =====================================================
-- STEP 4: GRANT PERMISSIONS ON FUNCTIONS
-- =====================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.get_user_by_email_safe(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_by_id_safe(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_has_role_safe(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_is_approved_safe(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_user_profile_safe(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_profile_safe(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.insert_user_profile_safe(uuid, text, text, text, text, text, text) TO authenticated;

-- Grant execute permissions to anonymous users for signup checks
GRANT EXECUTE ON FUNCTION public.get_user_by_email_safe(text) TO anon;
GRANT EXECUTE ON FUNCTION public.insert_user_profile_safe(uuid, text, text, text, text, text, text) TO anon;

SELECT 'Granted function permissions' as step_completed;

-- =====================================================
-- STEP 5: VERIFICATION
-- =====================================================

SELECT 'Verifying RLS policies...' as status;

-- Check that policies exist
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'user_profiles' 
ORDER BY policyname;

SELECT 'RLS infinite recursion fix completed successfully!' as final_status;
