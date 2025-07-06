-- =====================================================
-- SmartBizTracker Worker Attendance QR System Test Script
-- =====================================================
-- 
-- This script tests the database migration and validates
-- all components of the QR attendance system.
--
-- Run this after executing the main migration script.
-- =====================================================

-- =====================================================
-- CRITICAL: PostgreSQL Immutable Function Compliance Test
-- =====================================================

-- Test 0: Verify PostgreSQL version and extension support
SELECT 'TEST 0: PostgreSQL Environment Check' as test_name;

SELECT
    'PostgreSQL Version' as check_type,
    version() as version_info,
    CASE WHEN version() LIKE '%PostgreSQL 1%' OR version() LIKE '%PostgreSQL 9%'
         THEN '✅ SUPPORTED'
         ELSE '⚠️ CHECK COMPATIBILITY'
    END as status;

-- Test 1: Verify all objects were created
SELECT 'TEST 1: Object Creation Verification' as test_name;

-- Check tables
SELECT 
    'Tables' as object_type,
    COUNT(*) as created_count,
    3 as expected_count,
    CASE WHEN COUNT(*) = 3 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM information_schema.tables 
WHERE table_name IN ('worker_attendance_profiles', 'qr_nonce_history', 'worker_attendance_records');

-- Check functions
SELECT 
    'Functions' as object_type,
    COUNT(*) as created_count,
    4 as expected_count,
    CASE WHEN COUNT(*) >= 4 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM information_schema.routines 
WHERE routine_name IN ('validate_qr_attendance_token', 'process_qr_attendance', 'cleanup_expired_nonces', 'get_worker_attendance_stats');

-- Check enum
SELECT 
    'Enums' as object_type,
    COUNT(*) as created_count,
    1 as expected_count,
    CASE WHEN COUNT(*) = 1 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM pg_type 
WHERE typname = 'attendance_type_enum';

-- Test 1.5: Verify Index Creation (Critical for Immutable Function Compliance)
SELECT 'TEST 1.5: Index Creation and Immutable Function Compliance' as test_name;

-- Check that all indexes were created successfully
SELECT
    'Indexes' as object_type,
    COUNT(*) as created_count,
    CASE WHEN COUNT(*) >= 8 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM pg_indexes
WHERE indexname LIKE '%attendance%' OR indexname LIKE '%nonce%';

-- Specifically check the problematic date index
SELECT
    'Date Index (Critical)' as check_type,
    CASE WHEN EXISTS(
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_attendance_date'
        AND indexdef LIKE '%timestamp::date%'
    ) THEN '✅ IMMUTABLE COMPLIANT'
    ELSE '❌ IMMUTABLE VIOLATION'
    END as status;

-- Test 2: Test system functionality
SELECT 'TEST 2: System Functionality Test' as test_name;

-- Run the built-in test function
SELECT test_qr_attendance_system() as system_test_result;

-- Test 3: Create test worker profile
SELECT 'TEST 3: Worker Profile Creation Test' as test_name;

-- Insert a test worker profile
DO $$
DECLARE
    test_worker_id UUID := '12345678-1234-1234-1234-123456789012';
    test_device_hash VARCHAR(64) := 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
    profile_id UUID;
BEGIN
    -- Clean up any existing test data
    DELETE FROM worker_attendance_profiles WHERE worker_id = test_worker_id;
    
    -- Insert test profile
    INSERT INTO worker_attendance_profiles (
        worker_id, 
        device_hash, 
        device_model, 
        device_os_version,
        is_active
    ) VALUES (
        test_worker_id,
        test_device_hash,
        'Test Device Model',
        'Test OS 1.0',
        true
    ) RETURNING id INTO profile_id;
    
    RAISE NOTICE '✅ Test worker profile created: %', profile_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Failed to create test worker profile: %', SQLERRM;
END $$;

-- Test 4: Validate business rules
SELECT 'TEST 4: Business Rules Validation Test' as test_name;

DO $$
DECLARE
    test_worker_id UUID := '12345678-1234-1234-1234-123456789012';
    test_device_hash VARCHAR(64) := 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
    test_nonce VARCHAR(36) := 'test-nonce-' || gen_random_uuid()::text;
    validation_result JSONB;
BEGIN
    -- Test QR token validation
    validation_result := validate_qr_attendance_token(
        test_worker_id,
        test_device_hash,
        test_nonce,
        NOW(),
        'check_in'::attendance_type_enum
    );
    
    IF (validation_result->>'success')::boolean THEN
        RAISE NOTICE '✅ QR token validation test passed';
    ELSE
        RAISE NOTICE '⚠️ QR token validation test result: %', validation_result->>'error';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Business rules validation test failed: %', SQLERRM;
END $$;

-- Test 5: Test attendance processing
SELECT 'TEST 5: Attendance Processing Test' as test_name;

DO $$
DECLARE
    test_worker_id UUID := '12345678-1234-1234-1234-123456789012';
    test_device_hash VARCHAR(64) := 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
    test_nonce VARCHAR(36) := 'test-attendance-' || gen_random_uuid()::text;
    process_result JSONB;
BEGIN
    -- Test attendance processing
    process_result := process_qr_attendance(
        test_worker_id,
        test_device_hash,
        test_nonce,
        NOW(),
        'check_in'::attendance_type_enum,
        '{"test": true}'::jsonb
    );
    
    IF (process_result->>'success')::boolean THEN
        RAISE NOTICE '✅ Attendance processing test passed: %', process_result->>'attendance_id';
    ELSE
        RAISE NOTICE '⚠️ Attendance processing test result: %', process_result->>'error';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Attendance processing test failed: %', SQLERRM;
END $$;

-- Test 6: Test statistics function
SELECT 'TEST 6: Statistics Function Test' as test_name;

DO $$
DECLARE
    test_worker_id UUID := '12345678-1234-1234-1234-123456789012';
    stats_result JSONB;
BEGIN
    -- Test statistics retrieval
    stats_result := get_worker_attendance_stats(
        test_worker_id,
        CURRENT_DATE - INTERVAL '7 days',
        CURRENT_DATE
    );
    
    IF stats_result IS NOT NULL THEN
        RAISE NOTICE '✅ Statistics function test passed';
        RAISE NOTICE 'Stats: %', stats_result;
    ELSE
        RAISE NOTICE '❌ Statistics function returned null';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Statistics function test failed: %', SQLERRM;
END $$;

-- Test 7: Test cleanup function
SELECT 'TEST 7: Cleanup Function Test' as test_name;

DO $$
DECLARE
    cleanup_count INTEGER;
BEGIN
    -- Test cleanup function
    cleanup_count := cleanup_expired_nonces();
    
    RAISE NOTICE '✅ Cleanup function test passed. Cleaned up % expired nonces', cleanup_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Cleanup function test failed: %', SQLERRM;
END $$;

-- Test 8: Performance test
SELECT 'TEST 8: Performance Test' as test_name;

DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    duration INTERVAL;
    test_worker_id UUID := '12345678-1234-1234-1234-123456789012';
    test_device_hash VARCHAR(64) := 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
    i INTEGER;
BEGIN
    start_time := clock_timestamp();
    
    -- Perform multiple validations to test performance
    FOR i IN 1..10 LOOP
        PERFORM validate_qr_attendance_token(
            test_worker_id,
            test_device_hash,
            'perf-test-' || i || '-' || gen_random_uuid()::text,
            NOW(),
            'check_in'::attendance_type_enum
        );
    END LOOP;
    
    end_time := clock_timestamp();
    duration := end_time - start_time;
    
    RAISE NOTICE '✅ Performance test completed. 10 validations took: %', duration;
    
    IF EXTRACT(EPOCH FROM duration) < 1.0 THEN
        RAISE NOTICE '✅ Performance test PASSED (< 1 second)';
    ELSE
        RAISE NOTICE '⚠️ Performance test SLOW (> 1 second)';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Performance test failed: %', SQLERRM;
END $$;

-- Cleanup test data
DO $$
DECLARE
    test_worker_id UUID := '12345678-1234-1234-1234-123456789012';
BEGIN
    DELETE FROM worker_attendance_records WHERE worker_id = test_worker_id;
    DELETE FROM qr_nonce_history WHERE worker_id = test_worker_id;
    DELETE FROM worker_attendance_profiles WHERE worker_id = test_worker_id;
    
    RAISE NOTICE '🧹 Test data cleaned up';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ Could not clean up test data: %', SQLERRM;
END $$;

-- Final summary
SELECT 'TEST SUMMARY: SmartBizTracker QR Attendance System' as summary;
SELECT 'All tests completed. Check the notices above for results.' as instructions;
SELECT 'If all tests show ✅ PASS, the migration was successful!' as conclusion;
