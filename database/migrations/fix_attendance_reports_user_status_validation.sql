-- =====================================================
-- FIX ATTENDANCE REPORTS USER STATUS VALIDATION
-- =====================================================
-- 
-- This migration fixes the user status validation in attendance report
-- database functions to support both 'approved' and 'active' status values
-- for users accessing the reports, not just workers.
--

-- Update get_worker_attendance_report_data function to support active users
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
STABLE
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
    current_user_id UUID;
    user_role TEXT;
BEGIN
    -- Security check: Only allow admin, owner, accountant, warehouseManager roles to access reports
    current_user_id := auth.uid();

    -- FIXED: Support both 'approved' and 'active' status for users accessing reports
    SELECT role INTO user_role
    FROM user_profiles
    WHERE id = current_user_id AND status IN ('approved', 'active');

    IF user_role NOT IN ('admin', 'owner', 'accountant', 'warehouseManager') THEN
        RAISE EXCEPTION 'Access denied: Only admin, owner, accountant, and warehouseManager roles can access attendance reports';
    END IF;
    
    -- Calculate work times
    work_start_time := make_time(work_start_hour, work_start_minute, 0);
    work_end_time := make_time(work_end_hour, work_end_minute, 0);
    late_tolerance_time := work_start_time + (late_tolerance_minutes || ' minutes')::INTERVAL;
    early_departure_time := work_end_time - (early_departure_tolerance_minutes || ' minutes')::INTERVAL;
    
    -- Calculate total work days in period (excluding weekends)
    SELECT COUNT(*) INTO total_work_days
    FROM generate_series(start_date::DATE, end_date::DATE, '1 day'::INTERVAL) AS d
    WHERE EXTRACT(DOW FROM d) BETWEEN 1 AND 5; -- Monday to Friday
    
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
        check_out_status := 'absent';
        total_hours_worked := 0;
        attendance_days := 0;
        absence_days := 0;
        late_arrivals := 0;
        early_departures := 0;
        late_minutes := 0;
        early_minutes := 0;
        report_date := start_date;
        
        -- Get aggregated attendance data for this worker in the date range
        SELECT 
            COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_in' THEN war.timestamp::date END) as days_present,
            COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_in' AND war.timestamp::TIME > late_tolerance_time 
                               THEN war.timestamp::date END) as late_days,
            COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_out' AND war.timestamp::TIME < early_departure_time 
                               THEN war.timestamp::date END) as early_days,
            COALESCE(SUM(
                CASE WHEN war.attendance_type = 'check_in' AND war.timestamp::TIME > late_tolerance_time 
                     THEN EXTRACT(EPOCH FROM (war.timestamp::TIME - work_start_time))/60 
                     ELSE 0 END
            ), 0) as total_late_minutes,
            COALESCE(SUM(
                CASE WHEN war.attendance_type = 'check_out' AND war.timestamp::TIME < early_departure_time 
                     THEN EXTRACT(EPOCH FROM (work_end_time - war.timestamp::TIME))/60 
                     ELSE 0 END
            ), 0) as total_early_minutes,
            MIN(CASE WHEN war.attendance_type = 'check_in' THEN war.timestamp END) as first_check_in,
            MAX(CASE WHEN war.attendance_type = 'check_out' THEN war.timestamp END) as last_check_out,
            COALESCE(SUM(
                CASE WHEN war.attendance_type = 'check_out' 
                     THEN EXTRACT(EPOCH FROM (war.timestamp - 
                         (SELECT MIN(war2.timestamp) 
                          FROM worker_attendance_records war2 
                          WHERE war2.worker_id = war.worker_id 
                          AND war2.attendance_type = 'check_in' 
                          AND war2.timestamp::date = war.timestamp::date)))/3600
                     ELSE 0 END
            ), 0) as total_hours
        INTO daily_record
        FROM worker_attendance_records war
        WHERE war.worker_id = worker_record.id
        AND war.timestamp >= start_date
        AND war.timestamp <= end_date;
        
        attendance_days := COALESCE(daily_record.days_present, 0);
        absence_days := total_work_days - attendance_days;
        late_arrivals := COALESCE(daily_record.late_days, 0);
        early_departures := COALESCE(daily_record.early_days, 0);
        total_hours_worked := COALESCE(daily_record.total_hours, 0);
        check_in_time := daily_record.first_check_in;
        check_out_time := daily_record.last_check_out;
        late_minutes := COALESCE(daily_record.total_late_minutes, 0);
        early_minutes := COALESCE(daily_record.total_early_minutes, 0);
        
        -- Set overall status based on aggregated data
        IF attendance_days > 0 THEN
            check_in_status := CASE WHEN late_arrivals > 0 THEN 'late' ELSE 'onTime' END;
            check_out_status := CASE WHEN early_departures > 0 THEN 'earlyDeparture' ELSE 'onTime' END;
        END IF;
        
        RETURN NEXT;
    END LOOP;
END;
$$;

-- Update get_attendance_summary_stats function to support active users
CREATE OR REPLACE FUNCTION get_attendance_summary_stats(
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
    total_workers INTEGER,
    present_workers INTEGER,
    absent_workers INTEGER,
    attendance_rate NUMERIC,
    total_late_arrivals INTEGER,
    total_early_departures INTEGER,
    average_working_hours NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    report_data RECORD;
    worker_count INTEGER := 0;
    present_count INTEGER := 0;
    total_late INTEGER := 0;
    total_early INTEGER := 0;
    total_hours NUMERIC := 0;
    current_user_id UUID;
    user_role TEXT;
BEGIN
    -- Security check: Only allow admin, owner, accountant, warehouseManager roles to access reports
    current_user_id := auth.uid();

    -- FIXED: Support both 'approved' and 'active' status for users accessing reports
    SELECT role INTO user_role
    FROM user_profiles
    WHERE id = current_user_id AND status IN ('approved', 'active');

    IF user_role NOT IN ('admin', 'owner', 'accountant', 'warehouseManager') THEN
        RAISE EXCEPTION 'Access denied: Only admin, owner, accountant, and warehouseManager roles can access attendance reports';
    END IF;
    
    -- Get aggregated data from the report function
    FOR report_data IN 
        SELECT * FROM get_worker_attendance_report_data(
            start_date, end_date, work_start_hour, work_start_minute,
            work_end_hour, work_end_minute, late_tolerance_minutes, early_departure_tolerance_minutes
        )
    LOOP
        worker_count := worker_count + 1;
        
        IF report_data.check_in_status != 'absent' THEN
            present_count := present_count + 1;
        END IF;
        
        total_late := total_late + report_data.late_arrivals;
        total_early := total_early + report_data.early_departures;
        total_hours := total_hours + report_data.total_hours_worked;
    END LOOP;
    
    -- Calculate summary statistics
    total_workers := worker_count;
    present_workers := present_count;
    absent_workers := worker_count - present_count;
    attendance_rate := CASE WHEN worker_count > 0 THEN ROUND((present_count::NUMERIC / worker_count::NUMERIC) * 100, 2) ELSE 0 END;
    total_late_arrivals := total_late;
    total_early_departures := total_early;
    average_working_hours := CASE WHEN present_count > 0 THEN ROUND(total_hours / present_count, 2) ELSE 0 END;
    
    RETURN NEXT;
END;
$$;

-- Verification query to test the fix
SELECT 
    'VERIFICATION: Functions updated successfully' as status,
    COUNT(*) as function_count
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('get_worker_attendance_report_data', 'get_attendance_summary_stats')
AND routine_type = 'FUNCTION';
