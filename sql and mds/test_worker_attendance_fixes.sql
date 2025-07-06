-- Test Script for Worker Attendance Reports Fixes
-- This script validates that all the database issues have been resolved

-- =====================================================
-- 1. TEST DATABASE FUNCTION EXISTENCE
-- =====================================================

-- Check if get_worker_attendance_report_data function exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_worker_attendance_report_data'
    ) THEN
        RAISE NOTICE '✅ Function get_worker_attendance_report_data exists';
    ELSE
        RAISE NOTICE '❌ Function get_worker_attendance_report_data does NOT exist';
    END IF;
END $$;

-- Check if get_attendance_summary_stats function exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_attendance_summary_stats'
    ) THEN
        RAISE NOTICE '✅ Function get_attendance_summary_stats exists';
    ELSE
        RAISE NOTICE '❌ Function get_attendance_summary_stats does NOT exist';
    END IF;
END $$;

-- =====================================================
-- 2. TEST USER_PROFILES TABLE SCHEMA
-- =====================================================

-- Check if user_profiles table has correct columns
DO $$
DECLARE
    has_name_column BOOLEAN := FALSE;
    has_profile_image_column BOOLEAN := FALSE;
    has_status_column BOOLEAN := FALSE;
BEGIN
    -- Check for 'name' column (not 'full_name')
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'name'
        AND table_schema = 'public'
    ) INTO has_name_column;
    
    -- Check for 'profile_image' column (not 'profile_image_url')
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'profile_image'
        AND table_schema = 'public'
    ) INTO has_profile_image_column;
    
    -- Check for 'status' column (not 'is_active')
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'status'
        AND table_schema = 'public'
    ) INTO has_status_column;
    
    IF has_name_column THEN
        RAISE NOTICE '✅ user_profiles.name column exists';
    ELSE
        RAISE NOTICE '❌ user_profiles.name column does NOT exist';
    END IF;
    
    IF has_profile_image_column THEN
        RAISE NOTICE '✅ user_profiles.profile_image column exists';
    ELSE
        RAISE NOTICE '❌ user_profiles.profile_image column does NOT exist';
    END IF;
    
    IF has_status_column THEN
        RAISE NOTICE '✅ user_profiles.status column exists';
    ELSE
        RAISE NOTICE '❌ user_profiles.status column does NOT exist';
    END IF;
END $$;

-- =====================================================
-- 3. TEST FUNCTION PARAMETERS AND EXECUTION
-- =====================================================

-- Test the get_worker_attendance_report_data function with sample parameters
DO $$
DECLARE
    test_result RECORD;
    function_works BOOLEAN := TRUE;
BEGIN
    BEGIN
        -- Try to execute the function with test parameters
        SELECT * FROM get_worker_attendance_report_data(
            start_date := NOW() - INTERVAL '7 days',
            end_date := NOW(),
            work_start_hour := 9,
            work_start_minute := 0,
            work_end_hour := 17,
            work_end_minute := 0,
            late_tolerance_minutes := 15,
            early_departure_tolerance_minutes := 10
        ) LIMIT 1 INTO test_result;
        
        RAISE NOTICE '✅ Function get_worker_attendance_report_data executes successfully';
        
    EXCEPTION WHEN OTHERS THEN
        function_works := FALSE;
        RAISE NOTICE '❌ Function get_worker_attendance_report_data failed: %', SQLERRM;
    END;
END $$;

-- Test the get_attendance_summary_stats function
DO $$
DECLARE
    test_result RECORD;
    function_works BOOLEAN := TRUE;
BEGIN
    BEGIN
        -- Try to execute the function with test parameters
        SELECT * FROM get_attendance_summary_stats(
            start_date := NOW() - INTERVAL '7 days',
            end_date := NOW(),
            work_start_hour := 9,
            work_start_minute := 0,
            work_end_hour := 17,
            work_end_minute := 0,
            late_tolerance_minutes := 15,
            early_departure_tolerance_minutes := 10
        ) INTO test_result;
        
        RAISE NOTICE '✅ Function get_attendance_summary_stats executes successfully';
        
    EXCEPTION WHEN OTHERS THEN
        function_works := FALSE;
        RAISE NOTICE '❌ Function get_attendance_summary_stats failed: %', SQLERRM;
    END;
END $$;

-- =====================================================
-- 4. TEST WORKER QUERY
-- =====================================================

-- Test the worker query that was failing
DO $$
DECLARE
    worker_count INTEGER := 0;
BEGIN
    BEGIN
        -- Test the query that was causing issues
        SELECT COUNT(*) FROM user_profiles
        WHERE role = 'عامل' AND status = 'approved'
        INTO worker_count;
        
        RAISE NOTICE '✅ Worker query executes successfully. Found % workers', worker_count;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Worker query failed: %', SQLERRM;
    END;
END $$;

-- =====================================================
-- 5. TEST REQUIRED TABLES EXISTENCE
-- =====================================================

-- Check if worker_attendance_records table exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'worker_attendance_records'
    ) THEN
        RAISE NOTICE '✅ Table worker_attendance_records exists';
    ELSE
        RAISE NOTICE '❌ Table worker_attendance_records does NOT exist';
    END IF;
END $$;

-- Check if worker_attendance_profiles table exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'worker_attendance_profiles'
    ) THEN
        RAISE NOTICE '✅ Table worker_attendance_profiles exists';
    ELSE
        RAISE NOTICE '❌ Table worker_attendance_profiles does NOT exist';
    END IF;
END $$;

-- =====================================================
-- 6. TEST INDEXES FOR PERFORMANCE
-- =====================================================

-- Check if performance indexes exist
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'user_profiles' 
        AND indexname LIKE '%worker%role%'
    ) THEN
        RAISE NOTICE '✅ Worker role index exists on user_profiles';
    ELSE
        RAISE NOTICE 'ℹ️ Worker role index may not exist on user_profiles (this is optional)';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'worker_attendance_records' 
        AND indexname LIKE '%worker%timestamp%'
    ) THEN
        RAISE NOTICE '✅ Worker attendance timestamp index exists';
    ELSE
        RAISE NOTICE 'ℹ️ Worker attendance timestamp index may not exist (this is optional)';
    END IF;
END $$;

-- =====================================================
-- 7. SUMMARY
-- =====================================================

RAISE NOTICE '';
RAISE NOTICE '=== TEST SUMMARY ===';
RAISE NOTICE 'If all tests show ✅, the worker attendance reports should work properly.';
RAISE NOTICE 'If any tests show ❌, those issues need to be addressed.';
RAISE NOTICE 'Items marked with ℹ️ are optional optimizations.';
RAISE NOTICE '';
RAISE NOTICE 'Next steps:';
RAISE NOTICE '1. Apply the migration: apply_worker_attendance_migration.sql';
RAISE NOTICE '2. Test the Flutter app attendance reports functionality';
RAISE NOTICE '3. Verify no more database errors in the logs';
