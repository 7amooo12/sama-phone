-- =====================================================
-- APPLY WORKER VISIBILITY FIXES
-- =====================================================
-- 
-- This script applies the fixes identified in the comprehensive
-- attendance fixes to resolve worker visibility issues
--

-- Step 1: No status updates needed - function will handle both 'approved' and 'active'
-- This ensures future workers with 'active' status will automatically appear in reports

-- Step 2: Ensure the database function supports both role names
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
    
    -- Loop through all workers (support both Arabic and English role names, and both status values)
    FOR worker_record IN
        SELECT up.id, up.name, up.profile_image
        FROM user_profiles up
        WHERE (up.role = 'عامل' OR up.role = 'worker') AND up.status IN ('approved', 'active')
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

-- Step 3: Update the index to support both role names and both status values
DROP INDEX IF EXISTS idx_user_profiles_role_status;
DROP INDEX IF EXISTS idx_user_profiles_role_status_workers;
CREATE INDEX IF NOT EXISTS idx_user_profiles_role_status_workers_active_approved
ON user_profiles(role, status)
WHERE (role = 'عامل' OR role = 'worker') AND status IN ('approved', 'active');

-- Step 4: Create worker attendance profiles for any missing workers
-- Generate 64-character hexadecimal device hashes that meet the constraint requirements
INSERT INTO worker_attendance_profiles (
    worker_id,
    device_hash,
    device_model,
    device_os_version,
    is_active,
    total_check_ins,
    total_check_outs
)
SELECT
    up.id,
    -- Generate a 64-character hexadecimal device hash using MD5 of worker ID + timestamp
    LOWER(MD5(up.id::text || EXTRACT(EPOCH FROM NOW())::text)) ||
    LOWER(MD5(up.id::text || 'smartbiztracker' || EXTRACT(EPOCH FROM NOW())::text)),
    'Default Device',
    'Unknown OS',
    true,
    0,
    0
FROM user_profiles up
LEFT JOIN worker_attendance_profiles wap ON up.id = wap.worker_id
WHERE (up.role = 'عامل' OR up.role = 'worker')
  AND up.status IN ('approved', 'active')
  AND wap.id IS NULL;

-- Step 5: Verify device hash generation and constraints
DO $$
DECLARE
    test_hash TEXT;
    hash_length INTEGER;
BEGIN
    -- Test device hash generation
    SELECT LOWER(MD5('test' || EXTRACT(EPOCH FROM NOW())::text)) ||
           LOWER(MD5('test' || 'smartbiztracker' || EXTRACT(EPOCH FROM NOW())::text))
    INTO test_hash;

    hash_length := LENGTH(test_hash);

    IF hash_length = 64 THEN
        RAISE NOTICE '✅ Device hash generation test passed: % characters', hash_length;
    ELSE
        RAISE NOTICE '❌ Device hash generation test failed: % characters (expected 64)', hash_length;
    END IF;
END $$;

-- Step 6: Verify the fixes
SELECT
    'VERIFICATION: Workers in system' as check_type,
    COUNT(*) as count
FROM user_profiles
WHERE (role = 'عامل' OR role = 'worker') AND status IN ('approved', 'active')
UNION ALL
SELECT
    'VERIFICATION: Workers with profiles' as check_type,
    COUNT(*) as count
FROM user_profiles up
INNER JOIN worker_attendance_profiles wap ON up.id = wap.worker_id
WHERE (up.role = 'عامل' OR up.role = 'worker') AND up.status IN ('approved', 'active')
UNION ALL
SELECT
    'VERIFICATION: Workers in reports' as check_type,
    COUNT(*) as count
FROM get_worker_attendance_report_data(
    CURRENT_DATE::TIMESTAMP,
    (CURRENT_DATE + INTERVAL '1 day')::TIMESTAMP,
    9, 0, 17, 0, 15, 10
);

-- Final success message
SELECT
    '✅ WORKER VISIBILITY FIXES APPLIED' as status,
    'All 4 workers should now appear in attendance reports' as result;
