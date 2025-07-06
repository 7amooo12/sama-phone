-- =====================================================
-- SmartBizTracker Worker Attendance QR System Migration
-- =====================================================
-- 
-- This migration adds comprehensive support for QR-based worker attendance
-- tracking with security, performance, and business rule enforcement.
--
-- Features:
-- - One-time QR token validation with 20-second expiry
-- - Device binding and fingerprinting
-- - 15-hour minimum gap rule enforcement
-- - Logical sequence enforcement (check_in → check_out → check_in)
-- - Replay attack prevention with nonce tracking
-- - Automated cleanup and maintenance
--
-- Author: SmartBizTracker Development Team
-- Date: 2024-06-23
-- Version: 1.0
-- =====================================================

-- Enable required extensions (graceful handling if extensions don't exist)
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'uuid-ossp extension not available. Using built-in UUID functions.';
END $$;

DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "pg_cron";
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'pg_cron extension not available. Manual cleanup will be required.';
END $$;

-- =====================================================
-- 1. CREATE ENUMS
-- =====================================================

-- Attendance type enumeration
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'attendance_type_enum') THEN
        CREATE TYPE attendance_type_enum AS ENUM ('check_in', 'check_out');
    END IF;
END $$;

-- =====================================================
-- 2. WORKER ATTENDANCE PROFILES TABLE
-- =====================================================

-- Table to store worker device registration and last attendance state
CREATE TABLE IF NOT EXISTS worker_attendance_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    device_hash VARCHAR(64) NOT NULL,
    device_model VARCHAR(255),
    device_os_version VARCHAR(100),
    last_attendance_type attendance_type_enum,
    last_attendance_time TIMESTAMP WITH TIME ZONE,
    total_check_ins INTEGER DEFAULT 0,
    total_check_outs INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT unique_worker_device UNIQUE(worker_id, device_hash),
    CONSTRAINT valid_device_hash CHECK (LENGTH(device_hash) = 64),
    CONSTRAINT valid_totals CHECK (total_check_ins >= 0 AND total_check_outs >= 0)
);

-- Indexes for worker_attendance_profiles
CREATE INDEX IF NOT EXISTS idx_worker_attendance_profiles_worker_id 
    ON worker_attendance_profiles(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_attendance_profiles_device_hash 
    ON worker_attendance_profiles(device_hash);
CREATE INDEX IF NOT EXISTS idx_worker_attendance_profiles_active 
    ON worker_attendance_profiles(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_worker_attendance_profiles_last_attendance 
    ON worker_attendance_profiles(worker_id, last_attendance_time DESC);

-- =====================================================
-- 3. QR NONCE HISTORY TABLE (Replay Attack Prevention)
-- =====================================================

-- Table to track used QR nonces and prevent replay attacks
CREATE TABLE IF NOT EXISTS qr_nonce_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nonce VARCHAR(36) NOT NULL UNIQUE,
    worker_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    device_hash VARCHAR(64) NOT NULL,
    qr_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    validation_result JSONB,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
    
    -- Constraints
    CONSTRAINT valid_nonce_format CHECK (nonce ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'),
    CONSTRAINT valid_device_hash_nonce CHECK (LENGTH(device_hash) = 64),
    CONSTRAINT valid_timestamps CHECK (qr_timestamp <= used_at)
);

-- Indexes for qr_nonce_history
CREATE UNIQUE INDEX IF NOT EXISTS idx_nonce_lookup
    ON qr_nonce_history(nonce);
CREATE INDEX IF NOT EXISTS idx_worker_nonce
    ON qr_nonce_history(worker_id, used_at DESC);
CREATE INDEX IF NOT EXISTS idx_nonce_expiry
    ON qr_nonce_history(expires_at);
CREATE INDEX IF NOT EXISTS idx_device_nonce
    ON qr_nonce_history(device_hash, used_at DESC);

-- =====================================================
-- 4. WORKER ATTENDANCE RECORDS TABLE
-- =====================================================

-- Main table for storing attendance records
CREATE TABLE IF NOT EXISTS worker_attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    attendance_type attendance_type_enum NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    device_hash VARCHAR(64) NOT NULL,
    qr_nonce VARCHAR(36) NOT NULL,
    location_info JSONB,
    validation_details JSONB,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_device_hash_record CHECK (LENGTH(device_hash) = 64),
    CONSTRAINT valid_nonce_format_record CHECK (qr_nonce ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'),
    CONSTRAINT valid_timestamp CHECK (timestamp <= created_at)
);

-- =====================================================
-- 4. IMMUTABLE HELPER FUNCTIONS FOR INDEXES
-- =====================================================

-- Immutable function to extract date from timestamp for index expressions
CREATE OR REPLACE FUNCTION extract_date_immutable(ts TIMESTAMP WITH TIME ZONE)
RETURNS DATE
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
    SELECT ts::date;
$$;

-- =====================================================
-- 5. INDEXES FOR PERFORMANCE
-- =====================================================

-- Indexes for worker_attendance_records
CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_worker_id
    ON worker_attendance_records(worker_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_date
    ON worker_attendance_records(extract_date_immutable(timestamp));
CREATE INDEX IF NOT EXISTS idx_attendance_type
    ON worker_attendance_records(attendance_type, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_device
    ON worker_attendance_records(device_hash, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_nonce
    ON worker_attendance_records(qr_nonce);

-- =====================================================
-- 6. BUSINESS RULE ENFORCEMENT FUNCTIONS
-- =====================================================

-- Function to validate 15-hour minimum gap rule
CREATE OR REPLACE FUNCTION validate_attendance_gap(
    p_worker_id UUID,
    p_attendance_type attendance_type_enum
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    last_checkin_time TIMESTAMP WITH TIME ZONE;
    time_diff INTERVAL;
BEGIN
    -- Only check gap for check_in attempts
    IF p_attendance_type != 'check_in' THEN
        RETURN TRUE;
    END IF;
    
    -- Get last check-in time
    SELECT timestamp INTO last_checkin_time
    FROM worker_attendance_records
    WHERE worker_id = p_worker_id 
      AND attendance_type = 'check_in'
    ORDER BY timestamp DESC
    LIMIT 1;
    
    -- If no previous check-in, allow
    IF last_checkin_time IS NULL THEN
        RETURN TRUE;
    END IF;
    
    -- Calculate time difference
    time_diff := NOW() - last_checkin_time;
    
    -- Enforce 15-hour minimum gap
    RETURN time_diff >= INTERVAL '15 hours';
END;
$$;

-- Function to validate logical sequence (check_in → check_out → check_in)
CREATE OR REPLACE FUNCTION validate_attendance_sequence(
    p_worker_id UUID,
    p_attendance_type attendance_type_enum
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    last_attendance_type attendance_type_enum;
BEGIN
    -- Get last attendance type from profile
    SELECT last_attendance_type INTO last_attendance_type
    FROM worker_attendance_profiles
    WHERE worker_id = p_worker_id AND is_active = true;

    -- If no previous attendance, only allow check_in
    IF last_attendance_type IS NULL THEN
        RETURN p_attendance_type = 'check_in';
    END IF;

    -- Enforce logical sequence
    IF last_attendance_type = 'check_in' THEN
        RETURN p_attendance_type = 'check_out';
    ELSE
        RETURN p_attendance_type = 'check_in';
    END IF;
END;
$$;

-- Function to validate QR token (comprehensive validation)
CREATE OR REPLACE FUNCTION validate_qr_attendance_token(
    p_worker_id UUID,
    p_device_hash VARCHAR(64),
    p_nonce VARCHAR(36),
    p_qr_timestamp TIMESTAMP WITH TIME ZONE,
    p_attendance_type attendance_type_enum
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    validation_result JSONB := '{}';
    profile_exists BOOLEAN := FALSE;
    nonce_used BOOLEAN := FALSE;
    gap_valid BOOLEAN := FALSE;
    sequence_valid BOOLEAN := FALSE;
    timestamp_valid BOOLEAN := FALSE;
    time_diff INTERVAL;
BEGIN
    -- Initialize result
    validation_result := jsonb_build_object(
        'success', false,
        'timestamp', NOW(),
        'worker_id', p_worker_id,
        'device_hash', p_device_hash,
        'nonce', p_nonce,
        'attendance_type', p_attendance_type,
        'validations', '{}'::jsonb
    );

    -- 1. Validate timestamp (20 seconds ± 5 seconds tolerance)
    time_diff := NOW() - p_qr_timestamp;
    timestamp_valid := time_diff >= INTERVAL '-5 seconds' AND time_diff <= INTERVAL '25 seconds';
    validation_result := jsonb_set(validation_result, '{validations,timestamp}',
        jsonb_build_object('valid', timestamp_valid, 'age_seconds', EXTRACT(EPOCH FROM time_diff)));

    IF NOT timestamp_valid THEN
        validation_result := jsonb_set(validation_result, '{error}', '"QR token expired or invalid timestamp"');
        RETURN validation_result;
    END IF;

    -- 2. Check if worker profile exists and device is registered
    SELECT EXISTS(
        SELECT 1 FROM worker_attendance_profiles
        WHERE worker_id = p_worker_id
          AND device_hash = p_device_hash
          AND is_active = true
    ) INTO profile_exists;

    validation_result := jsonb_set(validation_result, '{validations,profile}',
        jsonb_build_object('exists', profile_exists));

    IF NOT profile_exists THEN
        validation_result := jsonb_set(validation_result, '{error}', '"Worker profile not found or device not registered"');
        RETURN validation_result;
    END IF;

    -- 3. Check nonce uniqueness (prevent replay attacks)
    SELECT EXISTS(
        SELECT 1 FROM qr_nonce_history
        WHERE nonce = p_nonce
    ) INTO nonce_used;

    validation_result := jsonb_set(validation_result, '{validations,nonce}',
        jsonb_build_object('unique', NOT nonce_used));

    IF nonce_used THEN
        validation_result := jsonb_set(validation_result, '{error}', '"QR token already used (replay attack detected)"');
        RETURN validation_result;
    END IF;

    -- 4. Validate 15-hour gap rule
    gap_valid := validate_attendance_gap(p_worker_id, p_attendance_type);
    validation_result := jsonb_set(validation_result, '{validations,gap}',
        jsonb_build_object('valid', gap_valid));

    IF NOT gap_valid THEN
        validation_result := jsonb_set(validation_result, '{error}', '"15-hour minimum gap rule violation"');
        RETURN validation_result;
    END IF;

    -- 5. Validate logical sequence
    sequence_valid := validate_attendance_sequence(p_worker_id, p_attendance_type);
    validation_result := jsonb_set(validation_result, '{validations,sequence}',
        jsonb_build_object('valid', sequence_valid));

    IF NOT sequence_valid THEN
        validation_result := jsonb_set(validation_result, '{error}', '"Invalid attendance sequence"');
        RETURN validation_result;
    END IF;

    -- All validations passed
    validation_result := jsonb_set(validation_result, '{success}', 'true');
    validation_result := jsonb_set(validation_result, '{message}', '"QR token validation successful"');

    RETURN validation_result;
END;
$$;

-- Function to process attendance (main entry point)
CREATE OR REPLACE FUNCTION process_qr_attendance(
    p_worker_id UUID,
    p_device_hash VARCHAR(64),
    p_nonce VARCHAR(36),
    p_qr_timestamp TIMESTAMP WITH TIME ZONE,
    p_attendance_type attendance_type_enum,
    p_location_info JSONB DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
AS $$
DECLARE
    validation_result JSONB;
    attendance_id UUID;
    profile_updated BOOLEAN := FALSE;
    update_count INTEGER;
BEGIN
    -- Validate the QR token
    validation_result := validate_qr_attendance_token(
        p_worker_id, p_device_hash, p_nonce, p_qr_timestamp, p_attendance_type
    );

    -- If validation failed, return error
    IF NOT (validation_result->>'success')::boolean THEN
        -- Still record the nonce to prevent replay attacks
        INSERT INTO qr_nonce_history (
            nonce, worker_id, device_hash, qr_timestamp, validation_result
        ) VALUES (
            p_nonce, p_worker_id, p_device_hash, p_qr_timestamp, validation_result
        );

        RETURN validation_result;
    END IF;

    -- Record the nonce as used
    INSERT INTO qr_nonce_history (
        nonce, worker_id, device_hash, qr_timestamp, validation_result
    ) VALUES (
        p_nonce, p_worker_id, p_device_hash, p_qr_timestamp, validation_result
    );

    -- Create attendance record
    INSERT INTO worker_attendance_records (
        worker_id, attendance_type, device_hash, qr_nonce,
        location_info, validation_details
    ) VALUES (
        p_worker_id, p_attendance_type, p_device_hash, p_nonce,
        p_location_info, validation_result
    ) RETURNING id INTO attendance_id;

    -- Update worker profile
    UPDATE worker_attendance_profiles SET
        last_attendance_type = p_attendance_type,
        last_attendance_time = NOW(),
        total_check_ins = CASE WHEN p_attendance_type = 'check_in' THEN total_check_ins + 1 ELSE total_check_ins END,
        total_check_outs = CASE WHEN p_attendance_type = 'check_out' THEN total_check_outs + 1 ELSE total_check_outs END,
        updated_at = NOW()
    WHERE worker_id = p_worker_id AND device_hash = p_device_hash;

    -- Check if the update affected any rows
    GET DIAGNOSTICS update_count = ROW_COUNT;
    profile_updated := update_count > 0;

    -- Add success details to result
    validation_result := jsonb_set(validation_result, '{attendance_id}', to_jsonb(attendance_id));
    validation_result := jsonb_set(validation_result, '{profile_updated}', to_jsonb(profile_updated));
    validation_result := jsonb_set(validation_result, '{processed_at}', to_jsonb(NOW()));

    RETURN validation_result;
END;
$$;

-- =====================================================
-- 6. MAINTENANCE AND CLEANUP FUNCTIONS
-- =====================================================

-- Function to cleanup expired nonces
CREATE OR REPLACE FUNCTION cleanup_expired_nonces()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM qr_nonce_history
    WHERE expires_at < NOW();

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    -- Log cleanup activity
    INSERT INTO qr_nonce_history (
        nonce, worker_id, device_hash, qr_timestamp, validation_result
    ) VALUES (
        gen_random_uuid()::text,
        '00000000-0000-0000-0000-000000000000'::uuid,
        'cleanup_system',
        NOW(),
        jsonb_build_object(
            'cleanup', true,
            'deleted_count', deleted_count,
            'timestamp', NOW()
        )
    );

    RETURN deleted_count;
END;
$$;

-- Function to get worker attendance statistics
CREATE OR REPLACE FUNCTION get_worker_attendance_stats(
    p_worker_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    stats JSONB;
    total_days INTEGER;
    present_days INTEGER;
    total_hours NUMERIC;
BEGIN
    -- Set default date range (last 30 days if not specified)
    IF p_start_date IS NULL THEN
        p_start_date := CURRENT_DATE - INTERVAL '30 days';
    END IF;

    IF p_end_date IS NULL THEN
        p_end_date := CURRENT_DATE;
    END IF;

    -- Calculate statistics
    WITH attendance_pairs AS (
        SELECT
            extract_date_immutable(timestamp) as attendance_date,
            MIN(CASE WHEN attendance_type = 'check_in' THEN timestamp END) as check_in_time,
            MAX(CASE WHEN attendance_type = 'check_out' THEN timestamp END) as check_out_time
        FROM worker_attendance_records
        WHERE worker_id = p_worker_id
          AND extract_date_immutable(timestamp) BETWEEN p_start_date AND p_end_date
        GROUP BY extract_date_immutable(timestamp)
    ),
    daily_hours AS (
        SELECT
            attendance_date,
            CASE
                WHEN check_in_time IS NOT NULL AND check_out_time IS NOT NULL
                THEN EXTRACT(EPOCH FROM (check_out_time - check_in_time)) / 3600.0
                ELSE 0
            END as hours_worked
        FROM attendance_pairs
    )
    SELECT
        jsonb_build_object(
            'period', jsonb_build_object(
                'start_date', p_start_date,
                'end_date', p_end_date,
                'total_days', p_end_date - p_start_date + 1
            ),
            'attendance', jsonb_build_object(
                'present_days', COUNT(*),
                'total_hours', COALESCE(SUM(hours_worked), 0),
                'average_hours_per_day', COALESCE(AVG(hours_worked), 0)
            ),
            'details', jsonb_agg(
                jsonb_build_object(
                    'date', attendance_date,
                    'hours_worked', hours_worked
                ) ORDER BY attendance_date
            )
        )
    INTO stats
    FROM daily_hours
    WHERE hours_worked > 0;

    RETURN COALESCE(stats, jsonb_build_object(
        'period', jsonb_build_object(
            'start_date', p_start_date,
            'end_date', p_end_date,
            'total_days', p_end_date - p_start_date + 1
        ),
        'attendance', jsonb_build_object(
            'present_days', 0,
            'total_hours', 0,
            'average_hours_per_day', 0
        ),
        'details', '[]'::jsonb
    ));
END;
$$;

-- =====================================================
-- 7. TRIGGERS AND AUTOMATION
-- =====================================================

-- Trigger function to update profile timestamps
CREATE OR REPLACE FUNCTION update_attendance_profile_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
VOLATILE
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Create trigger for profile updates
DROP TRIGGER IF EXISTS trigger_update_attendance_profile_timestamp ON worker_attendance_profiles;
CREATE TRIGGER trigger_update_attendance_profile_timestamp
    BEFORE UPDATE ON worker_attendance_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_attendance_profile_timestamp();

-- =====================================================
-- 8. SCHEDULED MAINTENANCE
-- =====================================================

-- Schedule cleanup to run every hour (requires pg_cron extension)
-- This section will only execute if pg_cron extension is available
DO $$
BEGIN
    -- Check if pg_cron extension exists
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Remove existing job if it exists
        BEGIN
            PERFORM cron.unschedule('cleanup-qr-nonces');
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;

        -- Schedule new cleanup job
        PERFORM cron.schedule('cleanup-qr-nonces', '0 * * * *', 'SELECT cleanup_expired_nonces();');
        RAISE NOTICE 'Scheduled automatic cleanup job: cleanup-qr-nonces (hourly)';
    ELSE
        RAISE NOTICE 'pg_cron extension not available. Manual cleanup required using: SELECT cleanup_expired_nonces();';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not schedule automatic cleanup. Manual cleanup required using: SELECT cleanup_expired_nonces();';
END $$;

-- =====================================================
-- 9. PERMISSIONS AND SECURITY
-- =====================================================

-- Grant necessary permissions to application roles
-- Note: Adjust role names according to your setup
DO $$
BEGIN
    -- Check if 'authenticated' role exists (common in Supabase)
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        -- Grant SELECT permissions for reading attendance data
        GRANT SELECT ON worker_attendance_profiles TO authenticated;
        GRANT SELECT ON worker_attendance_records TO authenticated;
        GRANT SELECT ON qr_nonce_history TO authenticated;

        -- Grant EXECUTE permissions for attendance functions
        GRANT EXECUTE ON FUNCTION validate_qr_attendance_token TO authenticated;
        GRANT EXECUTE ON FUNCTION process_qr_attendance TO authenticated;
        GRANT EXECUTE ON FUNCTION get_worker_attendance_stats TO authenticated;
        GRANT EXECUTE ON FUNCTION cleanup_expired_nonces TO authenticated;

        -- Restrict direct INSERT/UPDATE/DELETE to functions only
        REVOKE INSERT, UPDATE, DELETE ON worker_attendance_profiles FROM authenticated;
        REVOKE INSERT, UPDATE, DELETE ON worker_attendance_records FROM authenticated;
        REVOKE INSERT, UPDATE, DELETE ON qr_nonce_history FROM authenticated;

        RAISE NOTICE 'Permissions granted to authenticated role';
    ELSE
        RAISE NOTICE 'Role "authenticated" not found. Please manually configure permissions for your application role.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not configure permissions. Please manually grant permissions to your application role.';
END $$;

-- =====================================================
-- 10. INITIAL DATA AND TESTING
-- =====================================================

-- Create a test function for development/testing
CREATE OR REPLACE FUNCTION test_qr_attendance_system()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    test_result JSONB;
    test_worker_id UUID;
    test_device_hash VARCHAR(64);
    test_nonce VARCHAR(36);
BEGIN
    -- This function is for testing purposes only
    -- Remove in production

    test_result := jsonb_build_object(
        'test_timestamp', NOW(),
        'tables_created', jsonb_build_object(
            'worker_attendance_profiles', EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'worker_attendance_profiles'),
            'qr_nonce_history', EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'qr_nonce_history'),
            'worker_attendance_records', EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'worker_attendance_records')
        ),
        'functions_created', jsonb_build_object(
            'validate_qr_attendance_token', EXISTS(SELECT 1 FROM information_schema.routines WHERE routine_name = 'validate_qr_attendance_token'),
            'process_qr_attendance', EXISTS(SELECT 1 FROM information_schema.routines WHERE routine_name = 'process_qr_attendance'),
            'cleanup_expired_nonces', EXISTS(SELECT 1 FROM information_schema.routines WHERE routine_name = 'cleanup_expired_nonces')
        ),
        'enum_created', EXISTS(SELECT 1 FROM pg_type WHERE typname = 'attendance_type_enum')
    );

    RETURN test_result;
END;
$$;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

-- Validate migration and log results
DO $$
DECLARE
    table_count INTEGER;
    function_count INTEGER;
    index_count INTEGER;
    enum_exists BOOLEAN;
BEGIN
    -- Count created objects
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_name IN ('worker_attendance_profiles', 'qr_nonce_history', 'worker_attendance_records');

    SELECT COUNT(*) INTO function_count
    FROM information_schema.routines
    WHERE routine_name IN ('validate_qr_attendance_token', 'process_qr_attendance', 'cleanup_expired_nonces', 'get_worker_attendance_stats');

    SELECT COUNT(*) INTO index_count
    FROM pg_indexes
    WHERE indexname LIKE '%attendance%' OR indexname LIKE '%nonce%';

    SELECT EXISTS(SELECT 1 FROM pg_type WHERE typname = 'attendance_type_enum') INTO enum_exists;

    -- Log migration results
    RAISE NOTICE '=== SmartBizTracker Worker Attendance QR System Migration Results ===';
    RAISE NOTICE 'Tables created: % of 3 expected', table_count;
    RAISE NOTICE 'Functions created: % of 4 expected', function_count;
    RAISE NOTICE 'Indexes created: % total', index_count;
    RAISE NOTICE 'Enum created: %', CASE WHEN enum_exists THEN 'YES' ELSE 'NO' END;

    IF table_count = 3 AND function_count = 4 AND enum_exists THEN
        RAISE NOTICE '✅ Migration completed successfully!';
        RAISE NOTICE 'Core features: QR token validation, attendance tracking, business rules enforcement';
        RAISE NOTICE 'Security: Device binding, replay attack prevention, 20-second token expiry';
        RAISE NOTICE 'Performance: Optimized indexes, automated cleanup, efficient queries';
    ELSE
        RAISE WARNING '⚠️ Migration incomplete. Please check for errors above.';
    END IF;

    RAISE NOTICE '=== Next Steps ===';
    RAISE NOTICE '1. Test the system: SELECT test_qr_attendance_system();';
    RAISE NOTICE '2. Create worker profiles before first QR attendance';
    RAISE NOTICE '3. Monitor cleanup job or run manually: SELECT cleanup_expired_nonces();';
    RAISE NOTICE '================================================================';
END $$;
