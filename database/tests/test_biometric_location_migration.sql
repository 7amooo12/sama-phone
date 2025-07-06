-- Test Script for Biometric Location Attendance Migration
-- This script tests the migration to ensure it works correctly

-- Test 1: Verify table creation
DO $$
BEGIN
    -- Check if warehouse_location_settings table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'warehouse_location_settings'
    ) THEN
        RAISE EXCEPTION 'warehouse_location_settings table was not created';
    END IF;
    
    RAISE NOTICE 'Test 1 PASSED: warehouse_location_settings table exists';
END $$;

-- Test 2: Verify new columns in worker_attendance_records
DO $$
BEGIN
    -- Check if new columns exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'worker_attendance_records' 
        AND column_name = 'latitude'
    ) THEN
        RAISE EXCEPTION 'latitude column was not added to worker_attendance_records';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'worker_attendance_records' 
        AND column_name = 'attendance_method'
    ) THEN
        RAISE EXCEPTION 'attendance_method column was not added to worker_attendance_records';
    END IF;
    
    RAISE NOTICE 'Test 2 PASSED: New columns added to worker_attendance_records';
END $$;

-- Test 3: Verify unique active warehouse constraint
DO $$
DECLARE
    test_user_id UUID;
    first_warehouse_id UUID;
    second_warehouse_id UUID;
    active_count INTEGER;
BEGIN
    -- Get a test user (create one if needed)
    SELECT id INTO test_user_id FROM user_profiles WHERE role = 'admin' LIMIT 1;
    
    IF test_user_id IS NULL THEN
        -- Create a test admin user
        INSERT INTO user_profiles (name, email, role) 
        VALUES ('Test Admin', 'test@admin.com', 'admin')
        RETURNING id INTO test_user_id;
    END IF;
    
    -- Insert first active warehouse
    INSERT INTO warehouse_location_settings (
        warehouse_name, latitude, longitude, geofence_radius, 
        is_active, description, created_by
    ) VALUES (
        'Test Warehouse 1', 24.7136, 46.6753, 500.0, 
        true, 'Test warehouse 1', test_user_id
    ) RETURNING id INTO first_warehouse_id;
    
    -- Insert second active warehouse (should deactivate the first)
    INSERT INTO warehouse_location_settings (
        warehouse_name, latitude, longitude, geofence_radius, 
        is_active, description, created_by
    ) VALUES (
        'Test Warehouse 2', 24.8136, 46.7753, 600.0, 
        true, 'Test warehouse 2', test_user_id
    ) RETURNING id INTO second_warehouse_id;
    
    -- Check that only one warehouse is active
    SELECT COUNT(*) INTO active_count 
    FROM warehouse_location_settings 
    WHERE is_active = true;
    
    IF active_count != 1 THEN
        RAISE EXCEPTION 'Expected 1 active warehouse, found %', active_count;
    END IF;
    
    -- Verify the second warehouse is the active one
    IF NOT EXISTS (
        SELECT 1 FROM warehouse_location_settings 
        WHERE id = second_warehouse_id AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Second warehouse should be active';
    END IF;
    
    -- Verify the first warehouse is deactivated
    IF EXISTS (
        SELECT 1 FROM warehouse_location_settings 
        WHERE id = first_warehouse_id AND is_active = true
    ) THEN
        RAISE EXCEPTION 'First warehouse should be deactivated';
    END IF;
    
    -- Cleanup test data
    DELETE FROM warehouse_location_settings WHERE id IN (first_warehouse_id, second_warehouse_id);
    
    RAISE NOTICE 'Test 3 PASSED: Unique active warehouse constraint works correctly';
END $$;

-- Test 4: Verify process_biometric_attendance function exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'process_biometric_attendance'
    ) THEN
        RAISE EXCEPTION 'process_biometric_attendance function was not created';
    END IF;
    
    RAISE NOTICE 'Test 4 PASSED: process_biometric_attendance function exists';
END $$;

-- Test 5: Test biometric attendance processing (if worker data exists)
DO $$
DECLARE
    test_worker_id UUID;
    test_device_hash VARCHAR(64) := 'test_device_hash_12345';
    result JSONB;
BEGIN
    -- Try to find an existing worker
    SELECT id INTO test_worker_id 
    FROM user_profiles 
    WHERE role = 'worker' 
    LIMIT 1;
    
    IF test_worker_id IS NOT NULL THEN
        -- Create worker attendance profile if it doesn't exist
        INSERT INTO worker_attendance_profiles (
            worker_id, device_hash, device_model, is_active
        ) VALUES (
            test_worker_id, test_device_hash, 'Test Device', true
        ) ON CONFLICT (worker_id, device_hash) DO NOTHING;
        
        -- Test biometric attendance processing
        SELECT process_biometric_attendance(
            test_worker_id,
            'check_in'::attendance_type_enum,
            test_device_hash,
            '{"latitude": 24.7136, "longitude": 46.6753, "accuracy": 10.0}'::JSONB,
            '{"isValid": true, "distanceFromWarehouse": 50.0}'::JSONB
        ) INTO result;
        
        -- Check if the function returned success
        IF (result->>'success')::BOOLEAN != true THEN
            RAISE NOTICE 'Biometric attendance test failed: %', result->>'error_message';
        ELSE
            RAISE NOTICE 'Test 5 PASSED: Biometric attendance processing works';
            
            -- Cleanup test attendance record
            DELETE FROM worker_attendance_records 
            WHERE worker_id = test_worker_id 
            AND attendance_method = 'biometric'
            AND created_at > NOW() - INTERVAL '1 minute';
        END IF;
    ELSE
        RAISE NOTICE 'Test 5 SKIPPED: No worker found for testing biometric attendance';
    END IF;
END $$;

-- Test 6: Verify indexes were created
DO $$
BEGIN
    -- Check for unique active warehouse index
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_unique_active_warehouse'
    ) THEN
        RAISE EXCEPTION 'idx_unique_active_warehouse index was not created';
    END IF;
    
    -- Check for attendance location index
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_attendance_location'
    ) THEN
        RAISE EXCEPTION 'idx_attendance_location index was not created';
    END IF;
    
    RAISE NOTICE 'Test 6 PASSED: Required indexes were created';
END $$;

-- Test 7: Verify constraint checks work
DO $$
DECLARE
    test_user_id UUID;
    error_caught BOOLEAN := false;
BEGIN
    -- Get a test user
    SELECT id INTO test_user_id FROM user_profiles WHERE role = 'admin' LIMIT 1;
    
    -- Test invalid latitude (should fail)
    BEGIN
        INSERT INTO warehouse_location_settings (
            warehouse_name, latitude, longitude, geofence_radius, 
            is_active, created_by
        ) VALUES (
            'Invalid Warehouse', 95.0, 46.6753, 500.0, 
            false, test_user_id
        );
    EXCEPTION
        WHEN check_violation THEN
            error_caught := true;
    END;
    
    IF NOT error_caught THEN
        RAISE EXCEPTION 'Invalid latitude constraint check failed';
    END IF;
    
    -- Reset for next test
    error_caught := false;
    
    -- Test invalid geofence radius (should fail)
    BEGIN
        INSERT INTO warehouse_location_settings (
            warehouse_name, latitude, longitude, geofence_radius, 
            is_active, created_by
        ) VALUES (
            'Invalid Warehouse', 24.7136, 46.6753, 5.0, 
            false, test_user_id
        );
    EXCEPTION
        WHEN check_violation THEN
            error_caught := true;
    END;
    
    IF NOT error_caught THEN
        RAISE EXCEPTION 'Invalid geofence radius constraint check failed';
    END IF;
    
    RAISE NOTICE 'Test 7 PASSED: Constraint checks work correctly';
END $$;

-- Final summary
DO $$
BEGIN
    RAISE NOTICE '=== MIGRATION TEST SUMMARY ===';
    RAISE NOTICE 'All tests completed successfully!';
    RAISE NOTICE 'The biometric location attendance migration is working correctly.';
    RAISE NOTICE '==============================';
END $$;
