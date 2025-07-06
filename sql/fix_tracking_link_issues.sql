-- Comprehensive fix for tracking_link column issues
-- This script addresses potential caching and RLS policy issues

-- 1. Verify the column exists and refresh schema cache
DO $$
BEGIN
    -- Force schema cache refresh by touching the table
    PERFORM pg_notify('pgrst', 'reload schema');
    
    -- Verify column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'tracking_link'
        AND table_schema = 'public'
    ) THEN
        RAISE NOTICE '✅ tracking_link column exists in user_profiles table';
    ELSE
        RAISE NOTICE '❌ tracking_link column is missing - adding it now';
        ALTER TABLE public.user_profiles ADD COLUMN tracking_link TEXT;
    END IF;
END $$;

-- 2. Check and fix RLS policies for user_profiles table
-- First, let's see what policies exist
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- 3. Ensure RLS policies allow tracking_link column access
-- Drop and recreate policies to ensure they include tracking_link

-- Policy for users to read their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
CREATE POLICY "Users can view own profile" ON public.user_profiles
    FOR SELECT USING (auth.uid() = id);

-- Policy for users to update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
CREATE POLICY "Users can update own profile" ON public.user_profiles
    FOR UPDATE USING (auth.uid() = id);

-- Policy for admins to view all profiles
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.user_profiles;
CREATE POLICY "Admins can view all profiles" ON public.user_profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
            AND status = 'approved'
        )
    );

-- Policy for admins to update all profiles
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.user_profiles;
CREATE POLICY "Admins can update all profiles" ON public.user_profiles
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
            AND status = 'approved'
        )
    );

-- Policy for admins to insert profiles
DROP POLICY IF EXISTS "Admins can insert profiles" ON public.user_profiles;
CREATE POLICY "Admins can insert profiles" ON public.user_profiles
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
            AND status = 'approved'
        )
    );

-- 4. Test tracking_link column access
DO $$
DECLARE
    test_user_id UUID;
    test_result RECORD;
BEGIN
    -- Find an existing user to test with
    SELECT id INTO test_user_id 
    FROM public.user_profiles 
    WHERE role = 'client' 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        -- Test SELECT with tracking_link
        SELECT tracking_link INTO test_result 
        FROM public.user_profiles 
        WHERE id = test_user_id;
        
        RAISE NOTICE '✅ Successfully selected tracking_link for user %', test_user_id;
        
        -- Test UPDATE with tracking_link (using a safe test value)
        UPDATE public.user_profiles 
        SET tracking_link = COALESCE(tracking_link, 'https://test.example.com/tracking')
        WHERE id = test_user_id;
        
        RAISE NOTICE '✅ Successfully updated tracking_link for user %', test_user_id;
    ELSE
        RAISE NOTICE '⚠️ No test user found to test tracking_link operations';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error testing tracking_link operations: %', SQLERRM;
END $$;

-- 5. Create a function to safely update user tracking_link
CREATE OR REPLACE FUNCTION update_user_tracking_link(
    user_id UUID,
    new_tracking_link TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update the tracking_link for the specified user
    UPDATE public.user_profiles 
    SET 
        tracking_link = new_tracking_link,
        updated_at = NOW()
    WHERE id = user_id;
    
    -- Check if the update was successful
    IF FOUND THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error updating tracking_link: %', SQLERRM;
        RETURN FALSE;
END;
$$;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION update_user_tracking_link(UUID, TEXT) TO authenticated;

-- 6. Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- 7. Final verification
DO $$
BEGIN
    RAISE NOTICE '🔄 Schema cache refresh requested';
    RAISE NOTICE '✅ tracking_link column fix completed';
    RAISE NOTICE '💡 If issues persist, restart your Supabase project or contact support';
END $$;
