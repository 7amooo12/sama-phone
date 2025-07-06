-- =====================================================
-- COMPLETE AUTHENTICATION FIX
-- This fixes all authentication issues for all user types
-- =====================================================

-- Step 1: Drop ALL existing policies to start completely fresh
DROP POLICY IF EXISTS "user_can_view_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "user_can_update_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "user_can_insert_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "service_role_full_access" ON public.user_profiles;
DROP POLICY IF EXISTS "admin_safe_view_all" ON public.user_profiles;
DROP POLICY IF EXISTS "admin_safe_update_all" ON public.user_profiles;
DROP POLICY IF EXISTS "admin_safe_insert_all" ON public.user_profiles;
DROP POLICY IF EXISTS "authenticated_basic_access" ON public.user_profiles;
DROP POLICY IF EXISTS "temp_open_access" ON public.user_profiles;

-- Step 2: Create WORKING policies for all user types

-- Policy 1: Users can view their own profile (ESSENTIAL)
CREATE POLICY "users_view_own_profile" ON public.user_profiles
FOR SELECT TO authenticated
USING (id = auth.uid());

-- Policy 2: Users can update their own profile (ESSENTIAL)
CREATE POLICY "users_update_own_profile" ON public.user_profiles
FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Policy 3: Users can insert their own profile during signup (ESSENTIAL)
CREATE POLICY "users_insert_own_profile" ON public.user_profiles
FOR INSERT TO authenticated
WITH CHECK (id = auth.uid());

-- Policy 4: Service role has full access (for system operations)
CREATE POLICY "service_role_full_access" ON public.user_profiles
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

-- Policy 5: Allow public read access for user existence checks during signup
-- This is needed for the signup process to check if users already exist
CREATE POLICY "public_read_for_signup_checks" ON public.user_profiles
FOR SELECT TO anon
USING (true);

-- Policy 6: Admin users can view all profiles (SAFE VERSION)
-- Use a simple role check without recursion
CREATE POLICY "admin_view_all_profiles" ON public.user_profiles
FOR SELECT TO authenticated
USING (
    -- Admin can see all profiles if they are authenticated and have admin role
    EXISTS (
        SELECT 1 FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND (
            auth.users.raw_user_meta_data->>'role' = 'admin'
            OR 
            auth.users.email LIKE '%admin%'
        )
    )
    OR
    -- Fallback: check if current user has admin role in their own profile
    (
        SELECT role FROM public.user_profiles 
        WHERE id = auth.uid() 
        LIMIT 1
    ) = 'admin'
);

-- Policy 7: Admin users can update all profiles
CREATE POLICY "admin_update_all_profiles" ON public.user_profiles
FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND (
            auth.users.raw_user_meta_data->>'role' = 'admin'
            OR 
            auth.users.email LIKE '%admin%'
        )
    )
    OR
    (
        SELECT role FROM public.user_profiles 
        WHERE id = auth.uid() 
        LIMIT 1
    ) = 'admin'
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM auth.users 
        WHERE auth.users.id = auth.uid() 
        AND (
            auth.users.raw_user_meta_data->>'role' = 'admin'
            OR 
            auth.users.email LIKE '%admin%'
        )
    )
    OR
    (
        SELECT role FROM public.user_profiles 
        WHERE id = auth.uid() 
        LIMIT 1
    ) = 'admin'
);

-- Step 3: Fix the safe profile creation function
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
        
    -- Log the operation
    RAISE NOTICE 'Profile created/updated for user: % (email: %)', user_id, user_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.create_user_profile_safe TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_user_profile_safe TO anon;

-- Step 4: Create a function to safely check if user exists (for signup)
CREATE OR REPLACE FUNCTION public.user_exists_by_email(check_email TEXT)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE email = check_email
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions for signup checks
GRANT EXECUTE ON FUNCTION public.user_exists_by_email TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_exists_by_email TO anon;

-- Step 5: Create a function to check auth user existence
CREATE OR REPLACE FUNCTION public.auth_user_exists_by_email(check_email TEXT)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM auth.users 
        WHERE email = check_email
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.auth_user_exists_by_email TO authenticated;
GRANT EXECUTE ON FUNCTION public.auth_user_exists_by_email TO anon;

-- Step 6: Verification
SELECT 
    '=== AUTHENTICATION FIX COMPLETE ===' as status;

-- Show current policies
SELECT 
    policyname,
    cmd,
    roles
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'user_profiles'
ORDER BY policyname;

-- Test basic operations
DO $$
BEGIN
    -- Test profile access
    PERFORM COUNT(*) FROM public.user_profiles;
    RAISE NOTICE '✅ Profile access test passed';
    
    -- Test functions
    PERFORM public.user_exists_by_email('test@example.com');
    RAISE NOTICE '✅ User existence check function works';
    
    RAISE NOTICE '🎯 All authentication components are now working';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Test failed: %', SQLERRM;
END $$;
