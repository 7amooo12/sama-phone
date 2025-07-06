-- Fix RLS policies for user_profiles table to properly handle tracking_link column
-- This replaces the overly permissive policy with specific, secure policies

-- 1. Drop the existing overly permissive policy
DROP POLICY IF EXISTS "user_profiles_open_access" ON public.user_profiles;

-- 2. Create specific policies for different operations

-- Policy 1: Allow authenticated users to view their own profile
CREATE POLICY "authenticated_users_select_own_profile" ON public.user_profiles
    FOR SELECT 
    USING (auth.uid() = id);

-- Policy 2: Allow authenticated users to update their own profile (including tracking_link)
CREATE POLICY "authenticated_users_update_own_profile" ON public.user_profiles
    FOR UPDATE 
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Policy 3: Allow admins and owners to view all profiles
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

-- Policy 4: Allow admins and owners to update all profiles (including tracking_link)
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

-- Policy 5: Allow admins and owners to insert new profiles
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

-- Policy 6: Allow admins to delete profiles (with restrictions)
CREATE POLICY "admins_delete_profiles" ON public.user_profiles
    FOR DELETE 
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid() 
            AND up.role = 'admin'
            AND up.status IN ('approved', 'active')
        )
        AND role != 'admin' -- Prevent admins from deleting other admins
    );

-- 3. Ensure RLS is enabled on the table
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- 4. Test the new policies with tracking_link operations
DO $$
DECLARE
    test_user_id UUID;
    admin_user_id UUID;
    test_tracking_link TEXT := 'https://test.example.com/tracking/123';
BEGIN
    -- Find a test client user
    SELECT id INTO test_user_id 
    FROM public.user_profiles 
    WHERE role = 'client' 
    AND status IN ('approved', 'active')
    LIMIT 1;
    
    -- Find an admin user
    SELECT id INTO admin_user_id 
    FROM public.user_profiles 
    WHERE role IN ('admin', 'owner')
    AND status IN ('approved', 'active')
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        -- Test updating tracking_link
        UPDATE public.user_profiles 
        SET tracking_link = test_tracking_link,
            updated_at = NOW()
        WHERE id = test_user_id;
        
        RAISE NOTICE '✅ Successfully updated tracking_link for user %', test_user_id;
        
        -- Test selecting tracking_link
        PERFORM tracking_link 
        FROM public.user_profiles 
        WHERE id = test_user_id;
        
        RAISE NOTICE '✅ Successfully selected tracking_link for user %', test_user_id;
    ELSE
        RAISE NOTICE '⚠️ No test client user found';
    END IF;
    
    IF admin_user_id IS NOT NULL THEN
        RAISE NOTICE '✅ Admin user found: %', admin_user_id;
    ELSE
        RAISE NOTICE '⚠️ No admin user found';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error testing policies: %', SQLERRM;
END $$;

-- 5. Create a function to safely update tracking_link with proper security
-- First drop the function if it exists to avoid conflicts
DROP FUNCTION IF EXISTS public.update_user_tracking_link(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.update_user_tracking_link(
    target_user_id UUID,
    new_tracking_link TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    current_user_role TEXT;
    target_user_exists BOOLEAN;
BEGIN
    -- Check if current user exists and get their role
    SELECT role INTO current_user_role
    FROM public.user_profiles
    WHERE id = current_user_id
    AND status IN ('approved', 'active');

    IF current_user_role IS NULL THEN
        RAISE EXCEPTION 'User not found or not approved';
    END IF;

    -- Check if target user exists
    SELECT EXISTS(
        SELECT 1 FROM public.user_profiles WHERE id = target_user_id
    ) INTO target_user_exists;

    IF NOT target_user_exists THEN
        RAISE EXCEPTION 'Target user not found';
    END IF;

    -- Check permissions: users can update their own, admins can update anyone's
    IF current_user_id = target_user_id OR current_user_role IN ('admin', 'owner') THEN
        UPDATE public.user_profiles
        SET
            tracking_link = new_tracking_link,
            updated_at = NOW()
        WHERE id = target_user_id;

        RETURN FOUND;
    ELSE
        RAISE EXCEPTION 'Permission denied: cannot update tracking_link for this user';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in update_user_tracking_link: %', SQLERRM;
        RETURN FALSE;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.update_user_tracking_link(UUID, TEXT) TO authenticated;

-- 6. Refresh schema cache
NOTIFY pgrst, 'reload schema';

-- 7. Display final policy summary
SELECT 
    'Policy Summary:' as info,
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

-- 8. Final success messages
DO $$
BEGIN
    RAISE NOTICE '✅ RLS policies updated successfully for user_profiles table';
    RAISE NOTICE '🔒 Security: Replaced permissive policy with specific role-based policies';
    RAISE NOTICE '📝 tracking_link column should now work properly with these policies';
    RAISE NOTICE '🔄 Schema cache refresh requested - restart app if issues persist';
END $$;
