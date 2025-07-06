-- Test script to verify tracking_link column migration
-- Run this after executing add_tracking_link_column.sql

-- 1. Check if the column exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'tracking_link'
        AND table_schema = 'public'
    ) THEN
        RAISE NOTICE '✅ tracking_link column exists in user_profiles table';
    ELSE
        RAISE NOTICE '❌ tracking_link column is missing from user_profiles table';
    END IF;
END $$;

-- 2. Check column details
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND column_name = 'tracking_link'
AND table_schema = 'public';

-- 3. Test inserting a user with tracking_link
DO $$
DECLARE
    test_user_id UUID := gen_random_uuid();
BEGIN
    -- Insert test user
    INSERT INTO public.user_profiles (
        id,
        name,
        email,
        role,
        phone_number,
        status,
        tracking_link,
        created_at
    ) VALUES (
        test_user_id,
        'Test User',
        'test@example.com',
        'client',
        '1234567890',
        'approved',
        'https://example.com/tracking/123',
        NOW()
    );
    
    RAISE NOTICE '✅ Successfully inserted test user with tracking_link';
    
    -- Update tracking_link
    UPDATE public.user_profiles 
    SET tracking_link = 'https://updated.example.com/tracking/456'
    WHERE id = test_user_id;
    
    RAISE NOTICE '✅ Successfully updated tracking_link for test user';
    
    -- Clean up test data
    DELETE FROM public.user_profiles WHERE id = test_user_id;
    
    RAISE NOTICE '✅ Test completed successfully - tracking_link column is working';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Test failed: %', SQLERRM;
        -- Try to clean up in case of error
        DELETE FROM public.user_profiles WHERE id = test_user_id;
END $$;

-- 4. Check RLS policies that might affect tracking_link
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- 5. Test the test function we created
SELECT test_tracking_link_update() as tracking_link_test_result;

-- 6. Show current user_profiles structure (using SQL instead of psql meta-command)
SELECT
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'user_profiles'
AND table_schema = 'public'
ORDER BY ordinal_position;
