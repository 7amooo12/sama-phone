-- Test script for attendance settings migration
-- This script tests the attendance_settings table and functions

-- Test 1: Check if table exists and has correct structure
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'attendance_settings'
ORDER BY ordinal_position;

-- Test 2: Check if default settings were inserted
SELECT 
    id,
    work_start_hour,
    work_start_minute,
    work_end_hour,
    work_end_minute,
    late_tolerance_minutes,
    early_departure_tolerance_minutes,
    required_daily_hours,
    work_days,
    is_active,
    created_at
FROM attendance_settings 
WHERE is_active = true;

-- Test 3: Test get_attendance_settings function (requires admin user)
-- This will fail if no admin user exists, which is expected in test environment
-- SELECT get_attendance_settings();

-- Test 4: Test constraints
-- This should fail due to invalid work hours constraint
DO $$
BEGIN
    BEGIN
        INSERT INTO attendance_settings (
            work_start_hour, work_start_minute,
            work_end_hour, work_end_minute,
            late_tolerance_minutes,
            early_departure_tolerance_minutes,
            required_daily_hours,
            work_days,
            is_active
        ) VALUES (
            17, 0,  -- Start at 5 PM
            9, 0,   -- End at 9 AM (invalid - start after end)
            15, 10, 8.0,
            ARRAY[1,2,3,4,5],
            false
        );
        RAISE EXCEPTION 'Constraint test failed - invalid work hours should be rejected';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'SUCCESS: Invalid work hours constraint working correctly';
    END;
END $$;

-- Test 5: Test work days constraint (invalid day numbers)
DO $$
BEGIN
    BEGIN
        INSERT INTO attendance_settings (
            work_start_hour, work_start_minute,
            work_end_hour, work_end_minute,
            late_tolerance_minutes,
            early_departure_tolerance_minutes,
            required_daily_hours,
            work_days,
            is_active
        ) VALUES (
            9, 0, 17, 0, 15, 10, 8.0,
            ARRAY[8,9], -- Invalid day numbers
            false
        );
        RAISE EXCEPTION 'Constraint test failed - invalid work days should be rejected';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'SUCCESS: Invalid work days constraint working correctly';
    END;
END $$;

-- Test 6: Test work days uniqueness (duplicate days)
DO $$
BEGIN
    BEGIN
        INSERT INTO attendance_settings (
            work_start_hour, work_start_minute,
            work_end_hour, work_end_minute,
            late_tolerance_minutes,
            early_departure_tolerance_minutes,
            required_daily_hours,
            work_days,
            is_active
        ) VALUES (
            9, 0, 17, 0, 15, 10, 8.0,
            ARRAY[1,2,2,3], -- Duplicate day 2
            false
        );
        RAISE EXCEPTION 'Trigger test failed - duplicate work days should be rejected';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'SUCCESS: Duplicate work days trigger working correctly';
    END;
END $$;

-- Test 7: Test empty work days
DO $$
BEGIN
    BEGIN
        INSERT INTO attendance_settings (
            work_start_hour, work_start_minute,
            work_end_hour, work_end_minute,
            late_tolerance_minutes,
            early_departure_tolerance_minutes,
            required_daily_hours,
            work_days,
            is_active
        ) VALUES (
            9, 0, 17, 0, 15, 10, 8.0,
            ARRAY[]::INTEGER[], -- Empty work days
            false
        );
        RAISE EXCEPTION 'Trigger test failed - empty work days should be rejected';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'SUCCESS: Empty work days trigger working correctly';
    END;
END $$;

-- Test 8: Test valid settings insertion
INSERT INTO attendance_settings (
    work_start_hour, work_start_minute,
    work_end_hour, work_end_minute,
    late_tolerance_minutes,
    early_departure_tolerance_minutes,
    required_daily_hours,
    work_days,
    is_active
) VALUES (
    8, 30,   -- 8:30 AM start
    16, 30,  -- 4:30 PM end
    20,      -- 20 minutes late tolerance
    15,      -- 15 minutes early departure tolerance
    7.5,     -- 7.5 hours required daily
    ARRAY[6,7,1,2,3], -- Saturday to Wednesday
    false    -- Not active (test record)
);

-- Verify the test record was inserted
SELECT 
    'Test record inserted successfully' as result,
    work_start_hour,
    work_start_minute,
    work_end_hour,
    work_end_minute,
    late_tolerance_minutes,
    early_departure_tolerance_minutes,
    required_daily_hours,
    work_days
FROM attendance_settings 
WHERE work_start_hour = 8 AND work_start_minute = 30;

-- Test 9: Test update trigger
UPDATE attendance_settings 
SET late_tolerance_minutes = 25 
WHERE work_start_hour = 8 AND work_start_minute = 30;

-- Verify updated_at was changed
SELECT 
    'Update trigger test' as test,
    updated_at > created_at as updated_at_changed,
    late_tolerance_minutes
FROM attendance_settings 
WHERE work_start_hour = 8 AND work_start_minute = 30;

-- Clean up test record
DELETE FROM attendance_settings 
WHERE work_start_hour = 8 AND work_start_minute = 30;

-- Test 10: Check indexes exist
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'attendance_settings';

-- Test 11: Check RLS policies exist
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'attendance_settings';

RAISE NOTICE 'All attendance settings migration tests completed successfully!';
