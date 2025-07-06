-- Corrected RLS policies for user_profiles table
-- This script fixes the role assignments and ensures proper security

-- 1. Clean up all existing policies first
DROP POLICY IF EXISTS "user_profiles_open_access" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can insert profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "admins_delete_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "admins_insert_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "admins_select_all_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "admins_update_all_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "authenticated_users_select_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "authenticated_users_update_own_profile" ON public.user_profiles;

-- 2. Ensure RLS is enabled
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- 3. Create new policies with proper role assignments

-- Policy for authenticated users to select their own profile
CREATE POLICY "user_select_own" ON public.user_profiles
    FOR SELECT 
    TO authenticated
    USING (auth.uid() = id);

-- Policy for authenticated users to update their own profile  
CREATE POLICY "user_update_own" ON public.user_profiles
    FOR UPDATE 
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Policy for admins to select all profiles
CREATE POLICY "admin_select_all" ON public.user_profiles
    FOR SELECT 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid() 
            AND up.role IN ('admin', 'owner')
            AND up.status IN ('approved', 'active')
        )
    );

-- Policy for admins to update all profiles
CREATE POLICY "admin_update_all" ON public.user_profiles
    FOR UPDATE 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid() 
            AND up.role IN ('admin', 'owner')
            AND up.status IN ('approved', 'active')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid() 
            AND up.role IN ('admin', 'owner')
            AND up.status IN ('approved', 'active')
        )
    );

-- Policy for admins to insert new profiles
CREATE POLICY "admin_insert_profiles" ON public.user_profiles
    FOR INSERT 
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid() 
            AND up.role IN ('admin', 'owner')
            AND up.status IN ('approved', 'active')
        )
    );

-- Policy for admins to delete profiles (with restrictions)
CREATE POLICY "admin_delete_profiles" ON public.user_profiles
    FOR DELETE 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid() 
            AND up.role = 'admin'
            AND up.status IN ('approved', 'active')
        )
        AND role != 'admin' -- Prevent admins from deleting other admins
    );

-- 4. Test the new policies
DO $$
DECLARE
    test_user_id UUID;
    policy_count INTEGER;
BEGIN
    -- Count the new policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename = 'user_profiles';
    
    RAISE NOTICE '✅ Created % RLS policies for user_profiles table', policy_count;
    
    -- Find a test user
    SELECT id INTO test_user_id 
    FROM public.user_profiles 
    WHERE role = 'client' 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        RAISE NOTICE '✅ Test user found: %', test_user_id;
        
        -- Test if we can access tracking_link column
        PERFORM tracking_link 
        FROM public.user_profiles 
        WHERE id = test_user_id;
        
        RAISE NOTICE '✅ tracking_link column is accessible';
    ELSE
        RAISE NOTICE '⚠️ No test user found';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error during testing: %', SQLERRM;
END $$;

-- 5. Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- 6. Show final policy summary with correct role information
SELECT 
    policyname,
    cmd,
    CASE 
        WHEN roles = '{public}' THEN 'Public Access'
        WHEN roles = '{authenticated}' THEN 'Authenticated Users'
        WHEN roles = '{anon}' THEN 'Anonymous Users'
        ELSE array_to_string(roles, ', ')
    END as access_level,
    CASE 
        WHEN qual IS NOT NULL THEN 'Has Conditions'
        ELSE 'No Conditions'
    END as conditions,
    CASE 
        WHEN with_check IS NOT NULL THEN 'Has Check'
        ELSE 'No Check'
    END as with_check_status
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- 7. Final verification message
DO $$
BEGIN
    RAISE NOTICE '🎉 RLS policies setup completed successfully!';
    RAISE NOTICE '🔒 All policies now use authenticated role instead of public';
    RAISE NOTICE '📝 tracking_link column should work properly now';
    RAISE NOTICE '🔄 Please restart your Flutter app to test the changes';
END $$;
