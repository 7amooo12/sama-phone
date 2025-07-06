-- Apply Worker Attendance Reports Migration
-- This script ensures the get_worker_attendance_report_data function exists in the database

-- First, check if the function exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_worker_attendance_report_data'
    ) THEN
        RAISE NOTICE 'Function get_worker_attendance_report_data does not exist. Creating it...';
    ELSE
        RAISE NOTICE 'Function get_worker_attendance_report_data already exists. Updating it...';
    END IF;
END $$;

-- Create or replace the function with correct column names
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
) AS $$
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
    late_tolerance_time := work_start_time + (late_tolerance_minutes || ' minutes')::INTERVAL;
    early_departure_time := work_end_time - (early_departure_tolerance_minutes || ' minutes')::INTERVAL;
    
    -- Calculate total work days in the period
    total_work_days := (end_date::DATE - start_date::DATE) + 1;
    
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
        
        -- Get attendance records for this worker in the specified period
        FOR daily_record IN
            SELECT 
                DATE(war.timestamp) as attendance_date,
                MIN(CASE WHEN war.attendance_type = 'checkIn' THEN war.timestamp END) as daily_check_in,
                MAX(CASE WHEN war.attendance_type = 'checkOut' THEN war.timestamp END) as daily_check_out
            FROM worker_attendance_records war
            WHERE war.worker_id = worker_record.id
            AND war.timestamp >= start_date
            AND war.timestamp <= end_date
            GROUP BY DATE(war.timestamp)
            ORDER BY attendance_date
        LOOP
            -- Count attendance day
            IF daily_record.daily_check_in IS NOT NULL THEN
                attendance_days := attendance_days + 1;
                
                -- Set first check-in time for display
                IF check_in_time IS NULL THEN
                    check_in_time := daily_record.daily_check_in;
                END IF;
                
                -- Set last check-out time for display
                IF daily_record.daily_check_out IS NOT NULL THEN
                    check_out_time := daily_record.daily_check_out;
                    
                    -- Calculate hours worked for this day
                    total_hours_worked := total_hours_worked + 
                        EXTRACT(EPOCH FROM (daily_record.daily_check_out - daily_record.daily_check_in)) / 3600;
                END IF;
                
                -- Check if late arrival
                IF daily_record.daily_check_in::TIME > late_tolerance_time THEN
                    late_arrivals := late_arrivals + 1;
                    late_minutes := late_minutes +
                        EXTRACT(EPOCH FROM (daily_record.daily_check_in::TIME - work_start_time)) / 60;
                END IF;

                -- Check if early departure
                IF daily_record.daily_check_out IS NOT NULL AND daily_record.daily_check_out::TIME < early_departure_time THEN
                    early_departures := early_departures + 1;
                    early_minutes := early_minutes +
                        EXTRACT(EPOCH FROM (work_end_time - daily_record.daily_check_out::TIME)) / 60;
                END IF;
            END IF;
        END LOOP;
        
        -- Calculate absence days
        absence_days := total_work_days - attendance_days;
        
        -- Set overall status based on aggregated data
        IF attendance_days > 0 THEN
            check_in_status := CASE WHEN late_arrivals > 0 THEN 'late' ELSE 'onTime' END;
            check_out_status := CASE WHEN early_departures > 0 THEN 'earlyDeparture' ELSE 'onTime' END;
        END IF;
        
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql STABLE;

-- Create the summary stats function as well
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
) AS $$
DECLARE
    report_data RECORD;
    worker_count INTEGER := 0;
    present_count INTEGER := 0;
    total_late INTEGER := 0;
    total_early INTEGER := 0;
    total_hours NUMERIC := 0;
BEGIN
    -- Get aggregated data from the report function
    FOR report_data IN 
        SELECT * FROM get_worker_attendance_report_data(
            start_date, end_date, work_start_hour, work_start_minute,
            work_end_hour, work_end_minute, late_tolerance_minutes, early_departure_tolerance_minutes
        )
    LOOP
        worker_count := worker_count + 1;
        
        IF report_data.attendance_days > 0 THEN
            present_count := present_count + 1;
        END IF;
        
        total_late := total_late + report_data.late_arrivals;
        total_early := total_early + report_data.early_departures;
        total_hours := total_hours + report_data.total_hours_worked;
    END LOOP;
    
    -- Return aggregated statistics
    total_workers := worker_count;
    present_workers := present_count;
    absent_workers := worker_count - present_count;
    attendance_rate := CASE WHEN worker_count > 0 THEN (present_count::NUMERIC / worker_count::NUMERIC) * 100 ELSE 0 END;
    total_late_arrivals := total_late;
    total_early_departures := total_early;
    average_working_hours := CASE WHEN present_count > 0 THEN total_hours / present_count ELSE 0 END;
    
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE;

-- Add comments for documentation
COMMENT ON FUNCTION get_worker_attendance_report_data IS 'Returns comprehensive attendance report data for all workers in a specified time period';
COMMENT ON FUNCTION get_attendance_summary_stats IS 'Returns summary statistics for attendance in a specified time period';

-- Create index for better performance if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_user_profiles_worker_role 
ON user_profiles(role, status) WHERE role = 'عامل';

-- Create index on worker_attendance_records for better performance
CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_worker_timestamp 
ON worker_attendance_records(worker_id, timestamp);

CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_timestamp_type 
ON worker_attendance_records(timestamp, attendance_type);

RAISE NOTICE '✅ Worker attendance report functions created/updated successfully';
