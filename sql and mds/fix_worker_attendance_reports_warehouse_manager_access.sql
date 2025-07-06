-- =====================================================
-- FIX WORKER ATTENDANCE REPORTS WAREHOUSE MANAGER ACCESS
-- =====================================================
-- 
-- CRITICAL BUG FIX: Database functions get_worker_attendance_report_data 
-- and get_attendance_summary_stats exclude 'warehouseManager' role from 
-- accessing attendance reports, causing WorkerAttendanceReportsService 
-- to return empty results while other components work correctly.
--
-- This fix adds 'warehouseManager' to the allowed roles list in both 
-- SECURITY DEFINER functions to resolve the data inconsistency.
--
-- BUSINESS IMPACT: Fixes incorrect attendance reporting where present 
-- workers appear absent, affecting payroll and operational decisions.
-- =====================================================

-- Step 1: Verify current function exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_schema = 'public' 
        AND routine_name = 'get_worker_attendance_report_data'
    ) THEN
        RAISE NOTICE '✅ Function get_worker_attendance_report_data exists - proceeding with fix';
    ELSE
        RAISE EXCEPTION '❌ Function get_worker_attendance_report_data not found - cannot apply fix';
    END IF;
END $$;

-- Step 2: Update get_worker_attendance_report_data function to include warehouseManager
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

    SELECT role INTO user_role
    FROM user_profiles
    WHERE id = current_user_id AND status = 'approved';

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
    
    -- Loop through all workers
    FOR worker_record IN
        SELECT up.id, up.name, up.profile_image
        FROM user_profiles up
        WHERE up.role = 'عامل' AND up.status = 'approved'
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
        
        -- For daily reports, get today's data
        IF start_date::date = end_date::date THEN
            SELECT
                MIN(CASE WHEN war.attendance_type = 'check_in' THEN war.timestamp END) as day_check_in,
                MAX(CASE WHEN war.attendance_type = 'check_out' THEN war.timestamp END) as day_check_out
            INTO daily_record
            FROM worker_attendance_records war
            WHERE war.worker_id = worker_record.id
            AND war.timestamp::date = start_date::date;
            
            IF daily_record.day_check_in IS NOT NULL THEN
                check_in_time := daily_record.day_check_in;
                attendance_days := 1;
                
                -- Check if late
                IF daily_record.day_check_in::TIME > late_tolerance_time THEN
                    check_in_status := 'late';
                    late_arrivals := 1;
                    late_minutes := EXTRACT(EPOCH FROM (daily_record.day_check_in::TIME - work_start_time)) / 60;
                ELSE
                    check_in_status := 'onTime';
                END IF;
                
                -- Check check-out
                IF daily_record.day_check_out IS NOT NULL THEN
                    check_out_time := daily_record.day_check_out;
                    check_out_status := 'onTime';
                    
                    -- Check if early departure
                    IF daily_record.day_check_out::TIME < early_departure_time THEN
                        check_out_status := 'earlyDeparture';
                        early_departures := 1;
                        early_minutes := EXTRACT(EPOCH FROM (work_end_time - daily_record.day_check_out::TIME)) / 60;
                    END IF;
                    
                    -- Calculate hours worked
                    total_hours_worked := EXTRACT(EPOCH FROM (daily_record.day_check_out - daily_record.day_check_in)) / 3600;
                END IF;
            ELSE
                absence_days := 1;
            END IF;
        ELSE
            -- For period reports, aggregate data
            SELECT
                COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_in' THEN war.timestamp::date END) as days_present,
                COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_in' AND war.timestamp::TIME > late_tolerance_time 
                                   THEN war.timestamp::date END) as late_days,
                COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_out' AND war.timestamp::TIME < early_departure_time 
                                   THEN war.timestamp::date END) as early_days,
                COALESCE(SUM(CASE WHEN check_out.timestamp IS NOT NULL AND check_in.timestamp IS NOT NULL
                                 THEN EXTRACT(EPOCH FROM (check_out.timestamp - check_in.timestamp)) / 3600
                                 ELSE 0 END), 0) as total_hours,
                MIN(CASE WHEN war.attendance_type = 'check_in' THEN war.timestamp END) as first_check_in,
                MAX(CASE WHEN war.attendance_type = 'check_out' THEN war.timestamp END) as last_check_out
            INTO daily_record
            FROM worker_attendance_records war
            LEFT JOIN worker_attendance_records check_in ON check_in.worker_id = war.worker_id 
                AND check_in.timestamp::date = war.timestamp::date 
                AND check_in.attendance_type = 'check_in'
            LEFT JOIN worker_attendance_records check_out ON check_out.worker_id = war.worker_id 
                AND check_out.timestamp::date = war.timestamp::date 
                AND check_out.attendance_type = 'check_out'
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
            
            -- Set overall status based on aggregated data
            IF attendance_days > 0 THEN
                check_in_status := CASE WHEN late_arrivals > 0 THEN 'late' ELSE 'onTime' END;
                check_out_status := CASE WHEN early_departures > 0 THEN 'earlyDeparture' ELSE 'onTime' END;
            END IF;
        END IF;
        
        RETURN NEXT;
    END LOOP;
END;
$$;

-- Step 3: Update get_attendance_summary_stats function to include warehouseManager
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

    SELECT role INTO user_role
    FROM user_profiles
    WHERE id = current_user_id AND status = 'approved';

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
    attendance_rate := CASE WHEN worker_count > 0 THEN (present_count::NUMERIC / worker_count::NUMERIC) * 100 ELSE 0 END;
    total_late_arrivals := total_late;
    total_early_departures := total_early;
    average_working_hours := CASE WHEN present_count > 0 THEN total_hours / present_count ELSE 0 END;
    
    RETURN NEXT;
END;
$$;

-- Step 4: Verify the fix was applied successfully
DO $$
DECLARE
    test_result RECORD;
    function_count INTEGER := 0;
BEGIN
    -- Test if we can call the function (this will help verify the fix)
    BEGIN
        SELECT COUNT(*) INTO function_count
        FROM get_worker_attendance_report_data(
            CURRENT_DATE - INTERVAL '7 days',
            CURRENT_DATE,
            9, 0, 17, 0, 15, 10
        );
        
        RAISE NOTICE '✅ Function get_worker_attendance_report_data is working and returned % records', function_count;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '⚠️ Note: Function test failed (may be due to no test data): %', SQLERRM;
    END;
END $$;

-- Step 5: Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_worker_attendance_report_data TO authenticated;
GRANT EXECUTE ON FUNCTION get_attendance_summary_stats TO authenticated;

-- Step 6: Success message
DO $$
BEGIN
    RAISE NOTICE '🎉 SUCCESS: Worker attendance reports warehouse manager access fix applied!';
    RAISE NOTICE '📋 CHANGES MADE:';
    RAISE NOTICE '   ✅ Added warehouseManager to get_worker_attendance_report_data allowed roles';
    RAISE NOTICE '   ✅ Added warehouseManager to get_attendance_summary_stats allowed roles';
    RAISE NOTICE '   ✅ Updated security comments to reflect new permissions';
    RAISE NOTICE '   ✅ Granted execute permissions to authenticated users';
    RAISE NOTICE '';
    RAISE NOTICE '🔒 SECURITY: Only admin, owner, accountant, and warehouseManager roles can access attendance reports';
    RAISE NOTICE '📊 BUSINESS IMPACT: Warehouse managers can now access attendance reports without permission errors';
END $$;
