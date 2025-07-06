-- Simple fix for tracking_link RLS policy issues
-- This script replaces the overly permissive policy with specific ones

-- 1. Drop the problematic overly permissive policy
DROP POLICY IF EXISTS "user_profiles_open_access" ON public.user_profiles;

-- 2. Create specific policies for authenticated users

-- Allow authenticated users to view their own profile
CREATE POLICY "users_select_own_profile" ON public.user_profiles
    FOR SELECT 
    USING (auth.uid() = id);

-- Allow authenticated users to update their own profile
CREATE POLICY "users_update_own_profile" ON public.user_profiles
    FOR UPDATE 
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Allow admins to view all profiles
CREATE POLICY "admins_select_all_profiles" ON public.user_profiles
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid() 
            AND up.role IN ('admin', 'owner')
            AND up.status IN ('approved', 'active')
        )
    );

-- Allow admins to update all profiles
CREATE POLICY "admins_update_all_profiles" ON public.user_profiles
    FOR UPDATE 
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

-- Allow admins to insert new profiles
CREATE POLICY "admins_insert_profiles" ON public.user_profiles
    FOR INSERT 
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid() 
            AND up.role IN ('admin', 'owner')
            AND up.status IN ('approved', 'active')
        )
    );

-- 3. Ensure RLS is enabled
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- 4. Refresh schema cache
NOTIFY pgrst, 'reload schema';

-- 5. Test the policies
DO $$
DECLARE
    test_user_id UUID;
BEGIN
    -- Find a test user
    SELECT id INTO test_user_id 
    FROM public.user_profiles 
    WHERE role = 'client' 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        -- Test selecting tracking_link
        PERFORM tracking_link 
        FROM public.user_profiles 
        WHERE id = test_user_id;
        
        RAISE NOTICE '✅ Successfully tested tracking_link access for user %', test_user_id;
    ELSE
        RAISE NOTICE '⚠️ No test user found';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error testing policies: %', SQLERRM;
END $$;

-- 6. Show final policy status
SELECT 
    policyname,
    cmd,
    CASE 
        WHEN roles = '{public}' THEN 'Public Access'
        WHEN roles = '{authenticated}' THEN 'Authenticated Users'
        ELSE array_to_string(roles, ', ')
    END as access_level
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;
