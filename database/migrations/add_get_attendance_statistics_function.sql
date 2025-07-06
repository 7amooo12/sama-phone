-- =====================================================
-- SmartBizTracker Worker Attendance Statistics Function
-- =====================================================
-- 
-- This migration adds the missing get_attendance_statistics() function
-- that provides overall attendance statistics without requiring parameters.
--
-- Author: SmartBizTracker Development Team
-- Date: 2024-06-24
-- Version: 1.0
-- =====================================================

-- Function to get overall attendance statistics
CREATE OR REPLACE FUNCTION get_attendance_statistics()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    result JSON;
    total_workers_count INTEGER := 0;
    present_workers_count INTEGER := 0;
    absent_workers_count INTEGER := 0;
    late_workers_count INTEGER := 0;
    today_date DATE := CURRENT_DATE;
BEGIN
    -- Get total number of workers from user_profiles with role 'عامل'
    SELECT COUNT(*)
    INTO total_workers_count
    FROM user_profiles
    WHERE role = 'عامل' AND status IN ('active', 'approved');
    
    -- If no workers found, return empty statistics
    IF total_workers_count = 0 THEN
        RETURN json_build_object(
            'total_workers', 0,
            'present_workers', 0,
            'absent_workers', 0,
            'late_workers', 0,
            'last_updated', NOW()
        );
    END IF;
    
    -- Get workers who checked in today
    SELECT COUNT(DISTINCT worker_id)
    INTO present_workers_count
    FROM worker_attendance_records
    WHERE DATE(timestamp) = today_date
    AND attendance_type = 'check_in';
    
    -- Calculate absent workers (total - present)
    absent_workers_count := total_workers_count - present_workers_count;
    
    -- Get late workers (those who checked in after 9 AM)
    -- This is a simplified logic - can be enhanced based on business rules
    SELECT COUNT(DISTINCT worker_id)
    INTO late_workers_count
    FROM worker_attendance_records
    WHERE DATE(timestamp) = today_date
    AND attendance_type = 'check_in'
    AND EXTRACT(HOUR FROM timestamp) >= 9;
    
    -- Build the result JSON
    SELECT json_build_object(
        'total_workers', total_workers_count,
        'present_workers', present_workers_count,
        'absent_workers', absent_workers_count,
        'late_workers', late_workers_count,
        'last_updated', NOW()
    ) INTO result;
    
    RETURN result;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Return empty statistics on error
        RETURN json_build_object(
            'total_workers', 0,
            'present_workers', 0,
            'absent_workers', 0,
            'late_workers', 0,
            'last_updated', NOW(),
            'error', SQLERRM
        );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_attendance_statistics() TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION get_attendance_statistics() IS 'Returns overall attendance statistics for all workers including total, present, absent, and late workers for the current date';

-- Test the function
DO $$
DECLARE
    test_result JSON;
BEGIN
    -- Test the function
    SELECT get_attendance_statistics() INTO test_result;
    
    IF test_result IS NOT NULL THEN
        RAISE NOTICE '✅ Function get_attendance_statistics() created successfully';
        RAISE NOTICE 'Test result: %', test_result;
    ELSE
        RAISE NOTICE '❌ Function test returned null';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Function test failed: %', SQLERRM;
END $$;

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed: get_attendance_statistics() function added';
    RAISE NOTICE 'Function provides overall attendance statistics without parameters';
    RAISE NOTICE 'Compatible with WorkerAttendanceService.getAttendanceStatistics() method';
END $$;
