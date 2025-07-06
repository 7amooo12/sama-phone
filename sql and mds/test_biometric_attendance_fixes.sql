-- =====================================================
-- TEST BIOMETRIC ATTENDANCE SEQUENCE LOGIC FIXES
-- =====================================================
-- This script tests the fixed biometric attendance system
-- to ensure it handles all scenarios correctly
-- =====================================================

-- Test setup: Create test worker and warehouse location
DO $$
DECLARE
    test_worker_id UUID := '11111111-1111-1111-1111-111111111111';
    test_device_hash VARCHAR(64) := 'test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
    warehouse_location_id UUID;
BEGIN
    -- Clean up any existing test data
    DELETE FROM worker_attendance_records WHERE worker_id = test_worker_id;
    DELETE FROM worker_attendance_profiles WHERE worker_id = test_worker_id;
    DELETE FROM user_profiles WHERE id = test_worker_id;
    DELETE FROM warehouse_location_settings WHERE name = 'Test Warehouse';
    
    -- Create test user profile
    INSERT INTO user_profiles (
        id, name, email, role, status, created_at
    ) VALUES (
        test_worker_id, 'Test Worker', 'test@example.com', 'worker', 'active', NOW()
    );
    
    -- Create test warehouse location
    INSERT INTO warehouse_location_settings (
        name, latitude, longitude, radius_meters, is_active, created_at
    ) VALUES (
        'Test Warehouse', 24.7136, 46.6753, 100, true, NOW()
    ) RETURNING id INTO warehouse_location_id;
    
    -- Create test worker profile
    INSERT INTO worker_attendance_profiles (
        worker_id, device_hash, device_model, is_active
    ) VALUES (
        test_worker_id, test_device_hash, 'Test Device', true
    );
    
    RAISE NOTICE '✅ Test setup completed - Worker ID: %', test_worker_id;
END $$;

-- Test 1: Fresh worker should be able to check in
DO $$
DECLARE
    test_worker_id UUID := '11111111-1111-1111-1111-111111111111';
    test_device_hash VARCHAR(64) := 'test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
    result JSONB;
BEGIN
    RAISE NOTICE '🧪 TEST 1: Fresh worker check-in';
    
    -- Diagnose initial state
    SELECT diagnose_worker_attendance_state(test_worker_id, test_device_hash) INTO result;
    RAISE NOTICE 'Initial diagnosis: %', result;
    
    -- Attempt check-in
    SELECT process_biometric_attendance(
        test_worker_id,
        'check_in'::attendance_type_enum,
        test_device_hash,
        '{"latitude": 24.7136, "longitude": 46.6753, "accuracy": 10.0}'::JSONB,
        '{"isValid": true, "distanceFromWarehouse": 50.0}'::JSONB
    ) INTO result;
    
    IF result->>'success' = 'true' THEN
        RAISE NOTICE '✅ TEST 1 PASSED: Fresh check-in successful';
    ELSE
        RAISE NOTICE '❌ TEST 1 FAILED: %', result->>'error_message';
    END IF;
END $$;

-- Test 2: Duplicate check-in should be blocked
DO $$
DECLARE
    test_worker_id UUID := '11111111-1111-1111-1111-111111111111';
    test_device_hash VARCHAR(64) := 'test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
    result JSONB;
BEGIN
    RAISE NOTICE '🧪 TEST 2: Duplicate check-in should be blocked';
    
    -- Attempt second check-in (should fail)
    SELECT process_biometric_attendance(
        test_worker_id,
        'check_in'::attendance_type_enum,
        test_device_hash,
        '{"latitude": 24.7136, "longitude": 46.6753, "accuracy": 10.0}'::JSONB,
        '{"isValid": true, "distanceFromWarehouse": 50.0}'::JSONB
    ) INTO result;
    
    IF result->>'success' = 'false' AND result->>'error_code' = 'SEQUENCE_ERROR' THEN
        RAISE NOTICE '✅ TEST 2 PASSED: Duplicate check-in correctly blocked';
    ELSE
        RAISE NOTICE '❌ TEST 2 FAILED: Expected sequence error, got: %', result;
    END IF;
END $$;

-- Test 3: Check-out after check-in should work
DO $$
DECLARE
    test_worker_id UUID := '11111111-1111-1111-1111-111111111111';
    test_device_hash VARCHAR(64) := 'test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
    result JSONB;
BEGIN
    RAISE NOTICE '🧪 TEST 3: Check-out after check-in';
    
    -- Attempt check-out
    SELECT process_biometric_attendance(
        test_worker_id,
        'check_out'::attendance_type_enum,
        test_device_hash,
        '{"latitude": 24.7136, "longitude": 46.6753, "accuracy": 10.0}'::JSONB,
        '{"isValid": true, "distanceFromWarehouse": 50.0}'::JSONB
    ) INTO result;
    
    IF result->>'success' = 'true' THEN
        RAISE NOTICE '✅ TEST 3 PASSED: Check-out after check-in successful';
    ELSE
        RAISE NOTICE '❌ TEST 3 FAILED: %', result->>'error_message';
    END IF;
END $$;

-- Test 4: 15-hour gap reset functionality
DO $$
DECLARE
    test_worker_id UUID := '11111111-1111-1111-1111-111111111111';
    test_device_hash VARCHAR(64) := 'test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
    result JSONB;
BEGIN
    RAISE NOTICE '🧪 TEST 4: 15-hour gap reset functionality';
    
    -- Simulate 15+ hours ago by updating the profile manually
    UPDATE worker_attendance_profiles 
    SET last_attendance_time = NOW() - INTERVAL '16 hours',
        last_attendance_type = 'check_in'
    WHERE worker_id = test_worker_id AND device_hash = test_device_hash;
    
    -- Attempt check-in (should work due to 15-hour gap)
    SELECT process_biometric_attendance(
        test_worker_id,
        'check_in'::attendance_type_enum,
        test_device_hash,
        '{"latitude": 24.7136, "longitude": 46.6753, "accuracy": 10.0}'::JSONB,
        '{"isValid": true, "distanceFromWarehouse": 50.0}'::JSONB
    ) INTO result;
    
    IF result->>'success' = 'true' THEN
        RAISE NOTICE '✅ TEST 4 PASSED: 15-hour gap reset allows fresh check-in';
    ELSE
        RAISE NOTICE '❌ TEST 4 FAILED: %', result->>'error_message';
    END IF;
END $$;

-- Test 5: Profile state consistency after fixes
DO $$
DECLARE
    test_worker_id UUID := '11111111-1111-1111-1111-111111111111';
    test_device_hash VARCHAR(64) := 'test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
    result JSONB;
    profile_type TEXT;
    record_type TEXT;
BEGIN
    RAISE NOTICE '🧪 TEST 5: Profile state consistency';
    
    -- Get profile state
    SELECT last_attendance_type INTO profile_type
    FROM worker_attendance_profiles
    WHERE worker_id = test_worker_id AND device_hash = test_device_hash;
    
    -- Get last record state
    SELECT attendance_type INTO record_type
    FROM worker_attendance_records
    WHERE worker_id = test_worker_id
    ORDER BY timestamp DESC
    LIMIT 1;
    
    IF profile_type = record_type THEN
        RAISE NOTICE '✅ TEST 5 PASSED: Profile and records are consistent';
    ELSE
        RAISE NOTICE '❌ TEST 5 FAILED: Profile type (%) != Record type (%)', profile_type, record_type;
    END IF;
END $$;

-- Test 6: Diagnostic function
DO $$
DECLARE
    test_worker_id UUID := '11111111-1111-1111-1111-111111111111';
    test_device_hash VARCHAR(64) := 'test1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
    diagnosis JSONB;
BEGIN
    RAISE NOTICE '🧪 TEST 6: Diagnostic function';
    
    SELECT diagnose_worker_attendance_state(test_worker_id, test_device_hash) INTO diagnosis;
    
    IF diagnosis->>'profile_exists' = 'true' AND 
       diagnosis->'consistency_check'->>'profile_record_match' = 'true' THEN
        RAISE NOTICE '✅ TEST 6 PASSED: Diagnostic function works correctly';
    ELSE
        RAISE NOTICE '❌ TEST 6 FAILED: Diagnostic shows issues: %', diagnosis;
    END IF;
END $$;

-- Test 7: Error handling for non-existent worker
DO $$
DECLARE
    fake_worker_id UUID := '99999999-9999-9999-9999-999999999999';
    test_device_hash VARCHAR(64) := 'fake1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
    result JSONB;
BEGIN
    RAISE NOTICE '🧪 TEST 7: Error handling for non-existent worker';
    
    SELECT process_biometric_attendance(
        fake_worker_id,
        'check_in'::attendance_type_enum,
        test_device_hash,
        '{"latitude": 24.7136, "longitude": 46.6753, "accuracy": 10.0}'::JSONB,
        '{"isValid": true, "distanceFromWarehouse": 50.0}'::JSONB
    ) INTO result;
    
    IF result->>'success' = 'false' AND result->>'error_code' = 'WORKER_NOT_FOUND' THEN
        RAISE NOTICE '✅ TEST 7 PASSED: Non-existent worker correctly handled';
    ELSE
        RAISE NOTICE '❌ TEST 7 FAILED: Expected WORKER_NOT_FOUND, got: %', result;
    END IF;
END $$;

-- Cleanup test data
DO $$
DECLARE
    test_worker_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
    DELETE FROM worker_attendance_records WHERE worker_id = test_worker_id;
    DELETE FROM worker_attendance_profiles WHERE worker_id = test_worker_id;
    DELETE FROM user_profiles WHERE id = test_worker_id;
    DELETE FROM warehouse_location_settings WHERE name = 'Test Warehouse';
    
    RAISE NOTICE '🧹 Test cleanup completed';
END $$;

-- Summary
DO $$
BEGIN
    RAISE NOTICE '📋 BIOMETRIC ATTENDANCE SYSTEM TEST SUMMARY:';
    RAISE NOTICE '   - Fresh worker check-in functionality';
    RAISE NOTICE '   - Duplicate check-in prevention';
    RAISE NOTICE '   - Proper check-in/check-out sequence';
    RAISE NOTICE '   - 15-hour gap reset mechanism';
    RAISE NOTICE '   - Profile-record consistency';
    RAISE NOTICE '   - Diagnostic and troubleshooting tools';
    RAISE NOTICE '   - Error handling for edge cases';
    RAISE NOTICE '';
    RAISE NOTICE '✅ All tests completed. Check the output above for results.';
END $$;
