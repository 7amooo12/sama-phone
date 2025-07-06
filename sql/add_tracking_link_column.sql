-- Add missing tracking_link column to user_profiles table
-- This migration adds the tracking_link column that is referenced in UserModel.toJson()
-- but missing from the actual database schema

-- Enable idempotent migration - only add if column doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'tracking_link'
        AND table_schema = 'public'
    ) THEN
        -- Add the tracking_link column
        ALTER TABLE public.user_profiles 
        ADD COLUMN tracking_link TEXT;
        
        -- Add comment for documentation
        COMMENT ON COLUMN public.user_profiles.tracking_link IS 'رابط تتبع المستخدم - يستخدم لتتبع أنشطة المستخدم أو الطلبات';
        
        RAISE NOTICE 'Added tracking_link column to user_profiles table';
    ELSE
        RAISE NOTICE 'tracking_link column already exists in user_profiles table';
    END IF;
END $$;

-- Update RLS policies to include the new column if needed
-- The existing policies should automatically include the new column since they use SELECT *
-- But we'll verify that the policies are working correctly

-- Create a function to test if tracking_link updates work
CREATE OR REPLACE FUNCTION test_tracking_link_update()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    test_result BOOLEAN := FALSE;
BEGIN
    -- Test if we can update tracking_link for a user
    -- This is just a test function, not meant to be used in production
    BEGIN
        -- Try to update a non-existent user (safe test)
        UPDATE public.user_profiles 
        SET tracking_link = 'test_link' 
        WHERE id = '00000000-0000-0000-0000-000000000000';
        
        test_result := TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            test_result := FALSE;
    END;
    
    RETURN test_result;
END;
$$;

-- Add index for performance if tracking_link will be queried frequently
CREATE INDEX IF NOT EXISTS idx_user_profiles_tracking_link 
ON public.user_profiles(tracking_link) 
WHERE tracking_link IS NOT NULL;

-- Verify the column was added successfully
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'tracking_link'
        AND table_schema = 'public'
    ) THEN
        RAISE NOTICE '✅ tracking_link column successfully added to user_profiles table';
    ELSE
        RAISE NOTICE '❌ Failed to add tracking_link column to user_profiles table';
    END IF;
END $$;
