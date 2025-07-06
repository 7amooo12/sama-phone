-- Biometric and Location-Based Attendance System Migration
-- This migration adds support for biometric authentication and location validation
-- for the SmartBizTracker worker attendance system

-- Create warehouse location settings table
CREATE TABLE IF NOT EXISTS warehouse_location_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    warehouse_name VARCHAR(255) NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    geofence_radius DECIMAL(8, 2) NOT NULL DEFAULT 500.0,
    is_active BOOLEAN DEFAULT true,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES user_profiles(id),

    -- Constraints
    CONSTRAINT valid_latitude CHECK (latitude >= -90 AND latitude <= 90),
    CONSTRAINT valid_longitude CHECK (longitude >= -180 AND longitude <= 180),
    CONSTRAINT valid_geofence_radius CHECK (geofence_radius >= 10 AND geofence_radius <= 5000)
);

-- Add location fields to existing worker_attendance_records table
ALTER TABLE worker_attendance_records 
ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8),
ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8),
ADD COLUMN IF NOT EXISTS location_validated BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS distance_from_warehouse DECIMAL(8, 2),
ADD COLUMN IF NOT EXISTS location_accuracy DECIMAL(8, 2),
ADD COLUMN IF NOT EXISTS attendance_method VARCHAR(20) DEFAULT 'qr' CHECK (attendance_method IN ('qr', 'biometric')),
ADD COLUMN IF NOT EXISTS biometric_verified BOOLEAN DEFAULT false;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_warehouse_location_active ON warehouse_location_settings(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_attendance_location ON worker_attendance_records(latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_attendance_method ON worker_attendance_records(attendance_method);
CREATE INDEX IF NOT EXISTS idx_attendance_location_validated ON worker_attendance_records(location_validated);

-- Create partial unique index to ensure only one active warehouse location
-- This replaces the deferrable unique constraint which doesn't work with ON CONFLICT
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_warehouse
ON warehouse_location_settings(is_active)
WHERE is_active = true;

-- Helper function to reset worker profile state when 15-hour gap has passed
CREATE OR REPLACE FUNCTION reset_worker_profile_state_if_needed(
    p_worker_id UUID,
    p_device_hash VARCHAR(64)
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_time TIMESTAMP WITH TIME ZONE;
    v_time_gap_hours INTEGER;
BEGIN
    -- Get last attendance time from profile
    SELECT last_attendance_time INTO v_last_time
    FROM worker_attendance_profiles
    WHERE worker_id = p_worker_id AND device_hash = p_device_hash;

    -- If no last time, no reset needed
    IF v_last_time IS NULL THEN
        RETURN false;
    END IF;

    -- Calculate time gap
    v_time_gap_hours := EXTRACT(EPOCH FROM (NOW() - v_last_time)) / 3600;

    -- If 15+ hours have passed, reset the profile state
    IF v_time_gap_hours >= 15 THEN
        UPDATE worker_attendance_profiles
        SET last_attendance_type = NULL,
            last_attendance_time = NULL,
            updated_at = NOW()
        WHERE worker_id = p_worker_id AND device_hash = p_device_hash;

        RETURN true; -- Profile was reset
    END IF;

    RETURN false; -- No reset needed
END;
$$;

-- Create function to process biometric attendance
CREATE OR REPLACE FUNCTION process_biometric_attendance(
    p_worker_id UUID,
    p_attendance_type attendance_type_enum,
    p_device_hash VARCHAR(64),
    p_location_info JSONB DEFAULT NULL,
    p_location_validation JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_attendance_id UUID;
    v_worker_profile RECORD;
    v_last_attendance RECORD;
    v_time_gap_hours INTEGER;
    v_validation_result JSONB;
    v_location_lat DECIMAL(10, 8);
    v_location_lng DECIMAL(11, 8);
    v_location_validated BOOLEAN DEFAULT false;
    v_distance_from_warehouse DECIMAL(8, 2);
    v_location_accuracy DECIMAL(8, 2);
BEGIN
    -- Validate worker exists
    SELECT * INTO v_worker_profile
    FROM worker_attendance_profiles
    WHERE worker_id = p_worker_id AND device_hash = p_device_hash;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'WORKER_NOT_FOUND',
            'error_message', 'العامل غير مسجل في النظام'
        );
    END IF;

    -- Check sequence logic using worker profile state (consistent with QR system)
    -- First, get the last attendance type from worker profile
    DECLARE
        v_profile_last_type attendance_type_enum;
        v_profile_last_time TIMESTAMP WITH TIME ZONE;
        v_should_reset_profile BOOLEAN := false;
    BEGIN
        SELECT last_attendance_type, last_attendance_time
        INTO v_profile_last_type, v_profile_last_time
        FROM worker_attendance_profiles
        WHERE worker_id = p_worker_id AND device_hash = p_device_hash;

        -- Also check the actual records table for verification
        SELECT * INTO v_last_attendance
        FROM worker_attendance_records
        WHERE worker_id = p_worker_id
        ORDER BY timestamp DESC
        LIMIT 1;

        -- If we have a profile last time, check if 15-hour gap has passed
        IF v_profile_last_time IS NOT NULL THEN
            v_time_gap_hours := EXTRACT(EPOCH FROM (NOW() - v_profile_last_time)) / 3600;

            -- If 15+ hours have passed, reset the sequence (allow fresh start)
            IF v_time_gap_hours >= 15 THEN
                v_should_reset_profile := true;
                -- Reset profile state to allow fresh check-in
                UPDATE worker_attendance_profiles
                SET last_attendance_type = NULL,
                    last_attendance_time = NULL,
                    updated_at = NOW()
                WHERE worker_id = p_worker_id AND device_hash = p_device_hash;

                v_profile_last_type := NULL; -- Treat as fresh start
            END IF;
        END IF;

        -- Validate sequence based on profile state (after potential reset)
        IF v_profile_last_type IS NOT NULL AND NOT v_should_reset_profile THEN
            -- Check for sequence violations within 15-hour window
            IF (p_attendance_type = 'check_in' AND v_profile_last_type = 'check_in') OR
               (p_attendance_type = 'check_out' AND v_profile_last_type = 'check_out') THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'error_code', 'SEQUENCE_ERROR',
                    'error_message', CASE
                        WHEN p_attendance_type = 'check_in' THEN 'تم تسجيل الحضور مسبقاً. يجب تسجيل الانصراف أولاً'
                        ELSE 'تم تسجيل الانصراف مسبقاً. يجب تسجيل الحضور أولاً'
                    END,
                    'debug_info', jsonb_build_object(
                        'profile_last_type', v_profile_last_type,
                        'profile_last_time', v_profile_last_time,
                        'time_gap_hours', v_time_gap_hours,
                        'should_reset', v_should_reset_profile
                    )
                );
            END IF;
        ELSIF v_profile_last_type IS NULL AND p_attendance_type != 'check_in' THEN
            -- First attendance must be check_in
            RETURN jsonb_build_object(
                'success', false,
                'error_code', 'SEQUENCE_ERROR',
                'error_message', 'أول تسجيل يجب أن يكون حضور وليس انصراف',
                'debug_info', jsonb_build_object(
                    'profile_last_type', v_profile_last_type,
                    'is_first_attendance', true
                )
            );
        END IF;
    END;

    -- Extract location information
    IF p_location_info IS NOT NULL THEN
        v_location_lat := (p_location_info->>'latitude')::DECIMAL(10, 8);
        v_location_lng := (p_location_info->>'longitude')::DECIMAL(11, 8);
        v_location_accuracy := (p_location_info->>'accuracy')::DECIMAL(8, 2);
    END IF;

    -- Extract location validation
    IF p_location_validation IS NOT NULL THEN
        v_location_validated := (p_location_validation->>'isValid')::BOOLEAN;
        v_distance_from_warehouse := (p_location_validation->>'distanceFromWarehouse')::DECIMAL(8, 2);
    END IF;

    -- Create validation result
    v_validation_result := jsonb_build_object(
        'timestamp', NOW(),
        'method', 'biometric',
        'location_validated', v_location_validated,
        'distance_from_warehouse', v_distance_from_warehouse,
        'device_hash', p_device_hash
    );

    -- Create attendance record
    INSERT INTO worker_attendance_records (
        worker_id, 
        attendance_type, 
        device_hash, 
        qr_nonce,
        location_info, 
        validation_details,
        latitude,
        longitude,
        location_validated,
        distance_from_warehouse,
        location_accuracy,
        attendance_method,
        biometric_verified
    ) VALUES (
        p_worker_id, 
        p_attendance_type, 
        p_device_hash, 
        'biometric_' || gen_random_uuid()::text,
        p_location_info, 
        v_validation_result,
        v_location_lat,
        v_location_lng,
        v_location_validated,
        v_distance_from_warehouse,
        v_location_accuracy,
        'biometric',
        true
    ) RETURNING id INTO v_attendance_id;

    -- Update worker profile
    UPDATE worker_attendance_profiles SET
        last_attendance_type = p_attendance_type,
        last_attendance_time = NOW(),
        total_check_ins = CASE WHEN p_attendance_type = 'check_in' THEN total_check_ins + 1 ELSE total_check_ins END,
        total_check_outs = CASE WHEN p_attendance_type = 'check_out' THEN total_check_outs + 1 ELSE total_check_outs END,
        updated_at = NOW()
    WHERE worker_id = p_worker_id AND device_hash = p_device_hash;

    -- Return success with detailed debug information
    RETURN jsonb_build_object(
        'success', true,
        'attendance_id', v_attendance_id,
        'attendance_type', p_attendance_type,
        'timestamp', NOW(),
        'location_validated', v_location_validated,
        'distance_from_warehouse', v_distance_from_warehouse,
        'debug_info', jsonb_build_object(
            'worker_id', p_worker_id,
            'device_hash', p_device_hash,
            'sequence_validation_passed', true,
            'profile_updated', true
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        -- Enhanced error logging with context
        RETURN jsonb_build_object(
            'success', false,
            'error_code', 'DATABASE_ERROR',
            'error_message', 'خطأ في قاعدة البيانات: ' || SQLERRM,
            'debug_info', jsonb_build_object(
                'worker_id', p_worker_id,
                'device_hash', p_device_hash,
                'attendance_type', p_attendance_type,
                'sql_error', SQLERRM,
                'sql_state', SQLSTATE,
                'timestamp', NOW()
            )
        );
END;
$$;

-- Create function to get location-based attendance statistics
CREATE OR REPLACE FUNCTION get_location_attendance_stats(
    start_date TIMESTAMP DEFAULT CURRENT_DATE,
    end_date TIMESTAMP DEFAULT CURRENT_DATE + INTERVAL '1 day'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_records INTEGER;
    v_location_validated INTEGER;
    v_biometric_records INTEGER;
    v_qr_records INTEGER;
    v_avg_distance DECIMAL(8, 2);
    v_outside_geofence INTEGER;
BEGIN
    -- Get statistics
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE location_validated = true),
        COUNT(*) FILTER (WHERE attendance_method = 'biometric'),
        COUNT(*) FILTER (WHERE attendance_method = 'qr'),
        AVG(distance_from_warehouse) FILTER (WHERE distance_from_warehouse IS NOT NULL),
        COUNT(*) FILTER (WHERE location_validated = false AND latitude IS NOT NULL)
    INTO 
        v_total_records,
        v_location_validated,
        v_biometric_records,
        v_qr_records,
        v_avg_distance,
        v_outside_geofence
    FROM worker_attendance_records
    WHERE timestamp BETWEEN start_date AND end_date;

    RETURN jsonb_build_object(
        'total_records', v_total_records,
        'location_validated', v_location_validated,
        'biometric_records', v_biometric_records,
        'qr_records', v_qr_records,
        'average_distance', v_avg_distance,
        'outside_geofence', v_outside_geofence,
        'location_validation_rate', 
            CASE WHEN v_total_records > 0 
                THEN ROUND((v_location_validated::DECIMAL / v_total_records) * 100, 2)
                ELSE 0 
            END
    );
END;
$$;

-- Create function to validate warehouse location settings
CREATE OR REPLACE FUNCTION validate_warehouse_location()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Ensure only one active warehouse location
    IF NEW.is_active = true THEN
        -- Deactivate all other active warehouse locations
        UPDATE warehouse_location_settings
        SET is_active = false, updated_at = NOW()
        WHERE id != COALESCE(NEW.id, gen_random_uuid()) AND is_active = true;
    END IF;

    -- Set updated_at timestamp
    NEW.updated_at = NOW();

    RETURN NEW;
END;
$$;

-- Create trigger for warehouse location validation
DROP TRIGGER IF EXISTS trigger_validate_warehouse_location ON warehouse_location_settings;
CREATE TRIGGER trigger_validate_warehouse_location
    BEFORE INSERT OR UPDATE ON warehouse_location_settings
    FOR EACH ROW
    EXECUTE FUNCTION validate_warehouse_location();

-- Create function to cleanup old location data (optional)
CREATE OR REPLACE FUNCTION cleanup_old_location_data()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    -- Delete location data older than 1 year for privacy
    DELETE FROM worker_attendance_records
    WHERE timestamp < NOW() - INTERVAL '1 year'
    AND latitude IS NOT NULL;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RETURN v_deleted_count;
END;
$$;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON warehouse_location_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE ON worker_attendance_records TO authenticated;
GRANT EXECUTE ON FUNCTION process_biometric_attendance TO authenticated;
GRANT EXECUTE ON FUNCTION get_location_attendance_stats TO authenticated;

-- Insert default geofence settings (optional) - only if no warehouse locations exist
INSERT INTO warehouse_location_settings (
    warehouse_name,
    latitude,
    longitude,
    geofence_radius,
    is_active,
    description,
    created_by
)
SELECT
    'المخزن الرئيسي',
    24.7136,  -- Riyadh coordinates as example
    46.6753,
    500.0,
    false,  -- Set to false initially, admin needs to configure
    'الموقع الافتراضي - يجب تحديث الإحداثيات',
    (SELECT id FROM user_profiles WHERE role = 'admin' LIMIT 1)
WHERE NOT EXISTS (
    SELECT 1 FROM warehouse_location_settings LIMIT 1
);

-- Add comments for documentation
COMMENT ON TABLE warehouse_location_settings IS 'إعدادات مواقع المخازن للتحقق من الحضور';
COMMENT ON COLUMN warehouse_location_settings.geofence_radius IS 'نطاق الجيوفنس بالمتر (10-5000)';
COMMENT ON COLUMN worker_attendance_records.attendance_method IS 'طريقة تسجيل الحضور: qr أو biometric';
COMMENT ON COLUMN worker_attendance_records.location_validated IS 'هل تم التحقق من صحة الموقع';
COMMENT ON FUNCTION process_biometric_attendance IS 'معالجة حضور العامل بالمصادقة البيومترية مع التحقق من الموقع';
