-- Check current database state before running migration
-- Run this first to understand what exists

-- ============================================================================
-- STEP 1: Check if electronic payment tables exist
-- ============================================================================

SELECT 
    'Electronic Payment Tables Check' as check_type,
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('payment_accounts', 'electronic_payments')
ORDER BY table_name;

-- If no results, tables don't exist and migration needs to be run

-- ============================================================================
-- STEP 2: Check user_profiles table structure
-- ============================================================================

-- Check if user_profiles table exists
SELECT 
    'user_profiles table exists' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'user_profiles'
        ) THEN 'YES ✅'
        ELSE 'NO ❌'
    END as result;

-- Check user_profiles table structure
SELECT 
    'user_profiles structure' as info_type,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'user_profiles'
ORDER BY ordinal_position;

-- ============================================================================
-- STEP 3: Check auth.users table (Supabase default)
-- ============================================================================

-- Check if auth.users exists (should always exist in Supabase)
SELECT 
    'auth.users table exists' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'auth' 
            AND table_name = 'users'
        ) THEN 'YES ✅'
        ELSE 'NO ❌'
    END as result;

-- ============================================================================
-- STEP 4: Sample user_profiles data (if table exists)
-- ============================================================================

-- Check sample user_profiles data to understand structure
-- This will fail if table doesn't exist - that's expected
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles'
    ) THEN
        -- Table exists, show sample data
        RAISE NOTICE 'user_profiles table exists - checking sample data...';
    ELSE
        RAISE NOTICE 'user_profiles table does not exist';
    END IF;
END $$;

-- Try to show sample user_profiles data (will fail if table doesn't exist)
-- Comment this out if it causes errors
/*
SELECT 
    'Sample user_profiles data' as info_type,
    *
FROM public.user_profiles 
LIMIT 3;
*/

-- ============================================================================
-- STEP 5: Check existing RLS policies
-- ============================================================================

-- Check what RLS policies already exist
SELECT 
    'Existing RLS Policies' as info_type,
    schemaname,
    tablename,
    policyname
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ============================================================================
-- STEP 6: Summary and Next Steps
-- ============================================================================

SELECT 
    'SUMMARY' as section,
    'Database State Check Complete' as message,
    now() as checked_at;

-- Determine what needs to be done
SELECT 
    'NEXT STEPS' as section,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name IN ('payment_accounts', 'electronic_payments')
        ) THEN '1. Run ELECTRONIC_PAYMENT_MIGRATION_CLEAN.sql to create tables'
        ELSE '1. Tables exist - check why verification failed'
    END as step_1;

SELECT 
    'NEXT STEPS' as section,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'user_profiles'
        ) THEN '2. Create user_profiles table first'
        ELSE '2. Check user_profiles column names in RLS policies'
    END as step_2;

SELECT 
    'NEXT STEPS' as section,
    '3. After fixing issues, run TEST_ELECTRONIC_PAYMENT_TABLES.sql again' as step_3;
