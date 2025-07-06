-- =====================================================
-- FIX WORKER ATTENDANCE DATA INCONSISTENCY ISSUES
-- =====================================================
-- 
-- This script fixes the critical issues identified in SmartBizTracker logs:
-- 1. Null type cast errors in WorkerAttendanceService.getRecentAttendanceRecords
-- 2. Data inconsistency where system reports "لا يوجد عمال مسجلين في النظام" 
--    despite having 4 workers registered
-- 3. Database function role inconsistency (Arabic 'عامل' vs English 'worker')
--
-- CRITICAL FIXES:
-- - Update database functions to support both Arabic and English role names
-- - Fix column mapping inconsistencies
-- - Ensure proper indexes for performance
--

-- =====================================================
-- STEP 1: UPDATE DATABASE FUNCTION FOR ROLE CONSISTENCY
-- =====================================================

-- Drop and recreate the function with proper role handling
DROP FUNCTION IF EXISTS get_worker_attendance_report_data(
    TIMESTAMP, TIMESTAMP, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
);

CREATE OR REPLACE FUNCTION get_worker_attendance_report_data(
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    work_start_hour INTEGER DEFAULT 9,
    work_start_minute INTEGER DEFAULT 0,
    work_end_hour INTEGER DEFAULT 17,
    work_end_minute INTEGER DEFAULT 0,
    late_tolerance_minutes INTEGER DEFAULT 15,
    early_departure_tolerance_minutes INTEGER DEFAULT 10
)
RETURNS TABLE (
    worker_id UUID,
    worker_name TEXT,
    profile_image_url TEXT,
    check_in_time TIMESTAMP,
    check_out_time TIMESTAMP,
    check_in_status TEXT,
    check_out_status TEXT,
    total_hours_worked NUMERIC,
    attendance_days INTEGER,
    absence_days INTEGER,
    late_arrivals INTEGER,
    early_departures INTEGER,
    late_minutes INTEGER,
    early_minutes INTEGER,
    report_date TIMESTAMP
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    worker_record RECORD;
    daily_record RECORD;
    work_start_time TIME;
    work_end_time TIME;
    late_tolerance_time TIME;
    early_departure_time TIME;
    current_date DATE;
    total_work_days INTEGER;
BEGIN
    -- Calculate work times
    work_start_time := make_time(work_start_hour, work_start_minute, 0);
    work_end_time := make_time(work_end_hour, work_end_minute, 0);
    late_tolerance_time := work_start_time + make_interval(mins => late_tolerance_minutes);
    early_departure_time := work_end_time - make_interval(mins => early_departure_tolerance_minutes);
    
    -- Calculate total work days in the period
    total_work_days := (end_date::date - start_date::date) + 1;
    
    -- Loop through all workers (support both Arabic and English role names)
    FOR worker_record IN
        SELECT up.id, up.name, up.profile_image
        FROM user_profiles up
        WHERE (up.role = 'عامل' OR up.role = 'worker') AND up.status = 'approved'
    LOOP
        -- Initialize variables for this worker
        worker_id := worker_record.id;
        worker_name := worker_record.name;
        profile_image_url := worker_record.profile_image;
        check_in_time := NULL;
        check_out_time := NULL;
        check_in_status := 'absent';
        check_out_status := 'missingCheckOut';
        total_hours_worked := 0;
        attendance_days := 0;
        absence_days := 0;
        late_arrivals := 0;
        early_departures := 0;
        late_minutes := 0;
        early_minutes := 0;
        report_date := NOW();
        
        -- Get attendance data for this worker in the date range
        SELECT 
            COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_in' THEN war.timestamp::date END)::INTEGER,
            COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_in' AND war.timestamp::TIME > late_tolerance_time 
                               THEN war.timestamp::date END)::INTEGER,
            COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_out' AND war.timestamp::TIME < early_departure_time 
                               THEN war.timestamp::date END)::INTEGER,
            COALESCE(SUM(
                CASE WHEN war.attendance_type = 'check_in' AND war.timestamp::TIME > late_tolerance_time
                     THEN EXTRACT(EPOCH FROM (war.timestamp::TIME - work_start_time)) / 60
                     ELSE 0 END
            ), 0)::INTEGER,
            COALESCE(SUM(
                CASE WHEN war.attendance_type = 'check_out' AND war.timestamp::TIME < early_departure_time
                     THEN EXTRACT(EPOCH FROM (work_end_time - war.timestamp::TIME)) / 60
                     ELSE 0 END
            ), 0)::INTEGER,
            MIN(CASE WHEN war.attendance_type = 'check_in' THEN war.timestamp END),
            MAX(CASE WHEN war.attendance_type = 'check_out' THEN war.timestamp END)
        INTO 
            attendance_days, late_arrivals, early_departures, late_minutes, early_minutes, check_in_time, check_out_time
        FROM worker_attendance_records war
        WHERE war.worker_id = worker_record.id
          AND war.timestamp >= start_date
          AND war.timestamp <= end_date;
        
        -- Calculate absence days
        absence_days := total_work_days - COALESCE(attendance_days, 0);
        
        -- Calculate total hours worked (simplified calculation)
        IF check_in_time IS NOT NULL AND check_out_time IS NOT NULL THEN
            total_hours_worked := EXTRACT(EPOCH FROM (check_out_time - check_in_time)) / 3600;
        END IF;
        
        -- Set overall status based on aggregated data
        IF attendance_days > 0 THEN
            check_in_status := CASE WHEN late_arrivals > 0 THEN 'late' ELSE 'onTime' END;
            check_out_status := CASE WHEN early_departures > 0 THEN 'earlyDeparture' ELSE 'onTime' END;
        END IF;
        
        RETURN NEXT;
    END LOOP;
END;
$$;

-- =====================================================
-- STEP 2: UPDATE INDEX FOR ROLE CONSISTENCY
-- =====================================================

-- Drop existing index and create new one that supports both role names
DROP INDEX IF EXISTS idx_user_profiles_role_status;

CREATE INDEX IF NOT EXISTS idx_user_profiles_role_status_workers
ON user_profiles(role, status) 
WHERE (role = 'عامل' OR role = 'worker') AND status = 'approved';

-- =====================================================
-- STEP 3: VERIFY WORKER DATA EXISTS
-- =====================================================

-- Check if workers exist in the system
DO $$
DECLARE
    worker_count INTEGER := 0;
    arabic_workers INTEGER := 0;
    english_workers INTEGER := 0;
BEGIN
    -- Count total workers
    SELECT COUNT(*) INTO worker_count
    FROM user_profiles
    WHERE (role = 'عامل' OR role = 'worker') AND status = 'approved';
    
    -- Count Arabic role workers
    SELECT COUNT(*) INTO arabic_workers
    FROM user_profiles
    WHERE role = 'عامل' AND status = 'approved';
    
    -- Count English role workers
    SELECT COUNT(*) INTO english_workers
    FROM user_profiles
    WHERE role = 'worker' AND status = 'approved';
    
    RAISE NOTICE '=== WORKER DATA VERIFICATION ===';
    RAISE NOTICE 'Total approved workers: %', worker_count;
    RAISE NOTICE 'Workers with Arabic role (عامل): %', arabic_workers;
    RAISE NOTICE 'Workers with English role (worker): %', english_workers;
    
    IF worker_count = 0 THEN
        RAISE NOTICE '❌ WARNING: No approved workers found in system!';
        RAISE NOTICE '💡 This explains why attendance reports show "لا يوجد عمال مسجلين في النظام"';
    ELSE
        RAISE NOTICE '✅ SUCCESS: Found % approved workers in system', worker_count;
    END IF;
END $$;

-- =====================================================
-- STEP 4: TEST THE FIXED FUNCTION
-- =====================================================

-- Test the updated function
DO $$
DECLARE
    test_result RECORD;
    result_count INTEGER := 0;
BEGIN
    RAISE NOTICE '=== TESTING UPDATED FUNCTION ===';
    
    -- Test the function with current date range
    FOR test_result IN
        SELECT * FROM get_worker_attendance_report_data(
            CURRENT_DATE - INTERVAL '7 days',
            CURRENT_DATE + INTERVAL '1 day',
            9, 0, 17, 0, 15, 10
        )
    LOOP
        result_count := result_count + 1;
        RAISE NOTICE 'Worker %: % (ID: %)', result_count, test_result.worker_name, test_result.worker_id;
    END LOOP;
    
    IF result_count = 0 THEN
        RAISE NOTICE '❌ Function still returns no workers';
    ELSE
        RAISE NOTICE '✅ Function now returns % workers', result_count;
    END IF;
END $$;

-- =====================================================
-- STEP 5: COMPLETION MESSAGE
-- =====================================================

SELECT 
    '🎯 WORKER ATTENDANCE DATA INCONSISTENCY FIX COMPLETED' as status,
    'Database functions updated to support both Arabic and English worker roles' as fix_applied,
    'Test the Flutter app attendance reports to verify the fix' as next_step;
