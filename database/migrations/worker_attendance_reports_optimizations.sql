-- Worker Attendance Reports Database Optimizations for SmartBizTracker
-- This migration adds indexes and optimized functions for attendance reporting

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_worker_id_timestamp 
ON worker_attendance_records(worker_id, timestamp);

CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_timestamp_type 
ON worker_attendance_records(timestamp, attendance_type);

-- Create index on timestamp and worker_id for date-based queries
-- Note: Using timestamp directly instead of date extraction for better PostgreSQL compatibility
CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_date_worker
ON worker_attendance_records(timestamp, worker_id);

CREATE INDEX IF NOT EXISTS idx_user_profiles_role_status
ON user_profiles(role, status) WHERE (role = 'عامل' OR role = 'worker') AND status IN ('approved', 'active');

-- Function to get attendance report data for a specific period
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
                
                -- Determine check-in status
                IF daily_record.day_check_in::TIME <= late_tolerance_time THEN
                    check_in_status := 'onTime';
                ELSE
                    check_in_status := 'late';
                    late_arrivals := 1;
                    late_minutes := EXTRACT(EPOCH FROM (daily_record.day_check_in::TIME - work_start_time)) / 60;
                END IF;
                
                IF daily_record.day_check_out IS NOT NULL THEN
                    check_out_time := daily_record.day_check_out;
                    check_out_status := 'onTime';
                    
                    -- Determine check-out status
                    IF daily_record.day_check_out::TIME < early_departure_time THEN
                        check_out_status := 'earlyDeparture';
                        early_departures := 1;
                        early_minutes := EXTRACT(EPOCH FROM (work_end_time - daily_record.day_check_out::TIME)) / 60;
                    END IF;
                    
                    -- Calculate hours worked
                    total_hours_worked := EXTRACT(EPOCH FROM (daily_record.day_check_out - daily_record.day_check_in)) / 3600;
                ELSE
                    check_out_status := 'missingCheckOut';
                END IF;
            ELSE
                absence_days := 1;
            END IF;
        ELSE
            -- For weekly/monthly reports, aggregate data
            FOR current_date IN 
                SELECT generate_series(start_date::DATE, end_date::DATE, '1 day'::INTERVAL)::DATE
                WHERE EXTRACT(DOW FROM generate_series) BETWEEN 1 AND 5 -- Only work days
            LOOP
                SELECT
                    MIN(CASE WHEN war.attendance_type = 'check_in' THEN war.timestamp END) as day_check_in,
                    MAX(CASE WHEN war.attendance_type = 'check_out' THEN war.timestamp END) as day_check_out
                INTO daily_record
                FROM worker_attendance_records war
                WHERE war.worker_id = worker_record.id
                AND war.timestamp::date = current_date;
                
                IF daily_record.day_check_in IS NOT NULL THEN
                    attendance_days := attendance_days + 1;
                    
                    -- Check for late arrival
                    IF daily_record.day_check_in::TIME > late_tolerance_time THEN
                        late_arrivals := late_arrivals + 1;
                        late_minutes := late_minutes + (EXTRACT(EPOCH FROM (daily_record.day_check_in::TIME - work_start_time)) / 60);
                    END IF;
                    
                    -- Check for early departure and calculate hours
                    IF daily_record.day_check_out IS NOT NULL THEN
                        IF daily_record.day_check_out::TIME < early_departure_time THEN
                            early_departures := early_departures + 1;
                            early_minutes := early_minutes + (EXTRACT(EPOCH FROM (work_end_time - daily_record.day_check_out::TIME)) / 60);
                        END IF;
                        
                        total_hours_worked := total_hours_worked + (EXTRACT(EPOCH FROM (daily_record.day_check_out - daily_record.day_check_in)) / 3600);
                    END IF;
                ELSE
                    absence_days := absence_days + 1;
                END IF;
            END LOOP;
            
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

-- Function to get attendance summary statistics
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
    
    -- Return summary statistics
    total_workers := worker_count;
    present_workers := present_count;
    absent_workers := worker_count - present_count;
    attendance_rate := CASE WHEN worker_count > 0 THEN present_count::NUMERIC / worker_count ELSE 0 END;
    total_late_arrivals := total_late;
    total_early_departures := total_early;
    average_working_hours := CASE WHEN worker_count > 0 THEN total_hours / worker_count ELSE 0 END;
    
    RETURN NEXT;
END;
$$;

-- Function to clean up old attendance records (optional maintenance)
CREATE OR REPLACE FUNCTION cleanup_old_attendance_records(days_to_keep INTEGER DEFAULT 365)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM worker_attendance_records 
    WHERE timestamp < NOW() - (days_to_keep || ' days')::INTERVAL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get worker attendance statistics for a specific worker (optimized version)
CREATE OR REPLACE FUNCTION get_worker_attendance_stats_optimized(
    p_worker_id UUID,
    start_date TIMESTAMP,
    end_date TIMESTAMP
)
RETURNS TABLE (
    total_days INTEGER,
    present_days INTEGER,
    absent_days INTEGER,
    late_days INTEGER,
    early_departure_days INTEGER,
    total_hours_worked NUMERIC,
    average_daily_hours NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(DISTINCT war.timestamp::date)::INTEGER as total_days,
        COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_in' THEN war.timestamp::date END)::INTEGER as present_days,
        (COUNT(DISTINCT generate_series(start_date::DATE, end_date::DATE, '1 day'::INTERVAL)::DATE)
         - COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_in' THEN war.timestamp::date END))::INTEGER as absent_days,
        COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_in' AND war.timestamp::TIME > '09:15:00'
                           THEN war.timestamp::date END)::INTEGER as late_days,
        COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_out' AND war.timestamp::TIME < '16:50:00'
                           THEN war.timestamp::date END)::INTEGER as early_departure_days,
        COALESCE(SUM(
            CASE WHEN check_out.timestamp IS NOT NULL AND check_in.timestamp IS NOT NULL
                 THEN EXTRACT(EPOCH FROM (check_out.timestamp - check_in.timestamp)) / 3600
                 ELSE 0 END
        ), 0)::NUMERIC as total_hours_worked,
        COALESCE(AVG(
            CASE WHEN check_out.timestamp IS NOT NULL AND check_in.timestamp IS NOT NULL
                 THEN EXTRACT(EPOCH FROM (check_out.timestamp - check_in.timestamp)) / 3600
                 ELSE NULL END
        ), 0)::NUMERIC as average_daily_hours
    FROM worker_attendance_records war
    LEFT JOIN worker_attendance_records check_in ON
        check_in.worker_id = war.worker_id AND
        check_in.timestamp::date = war.timestamp::date AND
        check_in.attendance_type = 'check_in'
    LEFT JOIN worker_attendance_records check_out ON
        check_out.worker_id = war.worker_id AND
        check_out.timestamp::date = war.timestamp::date AND
        check_out.attendance_type = 'check_out'
    WHERE war.worker_id = p_worker_id
    AND war.timestamp BETWEEN start_date AND end_date;
END;
$$ LANGUAGE plpgsql STABLE;

-- Create a view for easy access to daily attendance summary
CREATE OR REPLACE VIEW daily_attendance_summary AS
SELECT
    war.timestamp::date as attendance_date,
    COUNT(DISTINCT war.worker_id) as total_workers_present,
    COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_in' AND war.timestamp::TIME <= '09:15:00'
                       THEN war.worker_id END) as on_time_workers,
    COUNT(DISTINCT CASE WHEN war.attendance_type = 'check_in' AND war.timestamp::TIME > '09:15:00'
                       THEN war.worker_id END) as late_workers,
    AVG(CASE WHEN check_out.timestamp IS NOT NULL AND check_in.timestamp IS NOT NULL
             THEN EXTRACT(EPOCH FROM (check_out.timestamp - check_in.timestamp)) / 3600
             ELSE NULL END) as average_hours_worked
FROM worker_attendance_records war
LEFT JOIN worker_attendance_records check_in ON
    check_in.worker_id = war.worker_id AND
    check_in.timestamp::date = war.timestamp::date AND
    check_in.attendance_type = 'check_in'
LEFT JOIN worker_attendance_records check_out ON
    check_out.worker_id = war.worker_id AND
    check_out.timestamp::date = war.timestamp::date AND
    check_out.attendance_type = 'check_out'
WHERE war.timestamp >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY war.timestamp::date
ORDER BY attendance_date DESC;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_worker_attendance_report_data TO authenticated;
GRANT EXECUTE ON FUNCTION get_attendance_summary_stats TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_old_attendance_records TO authenticated;
GRANT EXECUTE ON FUNCTION get_worker_attendance_stats_optimized TO authenticated;
GRANT SELECT ON daily_attendance_summary TO authenticated;

-- Add comments for documentation
COMMENT ON FUNCTION get_worker_attendance_report_data IS 'Returns comprehensive attendance report data for all workers in a specified time period';
COMMENT ON FUNCTION get_attendance_summary_stats IS 'Returns summary statistics for attendance in a specified time period';
COMMENT ON FUNCTION cleanup_old_attendance_records IS 'Removes old attendance records to maintain database performance';
COMMENT ON FUNCTION get_worker_attendance_stats_optimized IS 'Returns detailed attendance statistics for a specific worker with optimized performance';
COMMENT ON VIEW daily_attendance_summary IS 'Provides daily attendance summary for the last 30 days';
