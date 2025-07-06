-- =====================================================
-- Create Worker Profile Management Functions
-- =====================================================
-- 
-- This script creates secure stored procedures for managing
-- worker attendance profiles, eliminating the need for direct
-- table access and maintaining security through RLS.
--
-- This is an alternative approach to the direct table access fix.
-- Execute this script in your Supabase SQL Editor
-- =====================================================

-- Function 1: Get or Create Worker Attendance Profile
CREATE OR REPLACE FUNCTION get_or_create_worker_profile(
    p_worker_id UUID,
    p_device_hash VARCHAR(64),
    p_device_model VARCHAR(255) DEFAULT NULL,
    p_device_os_version VARCHAR(100) DEFAULT NULL
)
RETURNS TABLE(
    id UUID,
    worker_id UUID,
    device_hash VARCHAR(64),
    device_model VARCHAR(255),
    device_os_version VARCHAR(100),
    last_attendance_type attendance_type_enum,
    last_attendance_time TIMESTAMP WITH TIME ZONE,
    total_check_ins INTEGER,
    total_check_outs INTEGER,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    profile_record RECORD;
    current_user_id UUID;
BEGIN
    -- Get the current authenticated user ID
    current_user_id := auth.uid();
    
    -- Security check: Ensure user can only access their own profile or is admin
    IF current_user_id != p_worker_id AND NOT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = current_user_id 
        AND user_profiles.role IN ('admin', 'owner', 'warehouseManager')
        AND user_profiles.status = 'approved'
    ) THEN
        RAISE EXCEPTION 'Access denied: You can only manage your own attendance profile';
    END IF;

    -- Validate device hash length
    IF LENGTH(p_device_hash) != 64 THEN
        RAISE EXCEPTION 'Invalid device hash length. Expected 64 characters, got %', LENGTH(p_device_hash);
    END IF;

    -- Try to get existing profile
    SELECT * INTO profile_record
    FROM worker_attendance_profiles
    WHERE worker_attendance_profiles.worker_id = p_worker_id
    AND worker_attendance_profiles.device_hash = p_device_hash;

    -- If profile exists, return it
    IF FOUND THEN
        -- Update device info if provided and different
        IF p_device_model IS NOT NULL AND (profile_record.device_model IS NULL OR profile_record.device_model != p_device_model) THEN
            UPDATE worker_attendance_profiles 
            SET 
                device_model = p_device_model,
                device_os_version = COALESCE(p_device_os_version, device_os_version),
                updated_at = NOW()
            WHERE worker_attendance_profiles.worker_id = p_worker_id
            AND worker_attendance_profiles.device_hash = p_device_hash;
        END IF;

        -- Return the existing/updated profile
        RETURN QUERY
        SELECT 
            wap.id,
            wap.worker_id,
            wap.device_hash,
            wap.device_model,
            wap.device_os_version,
            wap.last_attendance_type,
            wap.last_attendance_time,
            wap.total_check_ins,
            wap.total_check_outs,
            wap.is_active,
            wap.created_at,
            wap.updated_at
        FROM worker_attendance_profiles wap
        WHERE wap.worker_id = p_worker_id
        AND wap.device_hash = p_device_hash;
    ELSE
        -- Create new profile
        INSERT INTO worker_attendance_profiles (
            worker_id,
            device_hash,
            device_model,
            device_os_version,
            is_active,
            total_check_ins,
            total_check_outs
        ) VALUES (
            p_worker_id,
            p_device_hash,
            p_device_model,
            p_device_os_version,
            true,
            0,
            0
        );

        -- Return the newly created profile
        RETURN QUERY
        SELECT 
            wap.id,
            wap.worker_id,
            wap.device_hash,
            wap.device_model,
            wap.device_os_version,
            wap.last_attendance_type,
            wap.last_attendance_time,
            wap.total_check_ins,
            wap.total_check_outs,
            wap.is_active,
            wap.created_at,
            wap.updated_at
        FROM worker_attendance_profiles wap
        WHERE wap.worker_id = p_worker_id
        AND wap.device_hash = p_device_hash;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error managing worker profile: %', SQLERRM;
END;
$$;

-- Function 2: Check if Worker Has Attendance Profile
CREATE OR REPLACE FUNCTION check_worker_profile_exists(
    p_worker_id UUID,
    p_device_hash VARCHAR(64)
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    profile_exists BOOLEAN := FALSE;
    current_user_id UUID;
BEGIN
    -- Get the current authenticated user ID
    current_user_id := auth.uid();
    
    -- Security check: Ensure user can only check their own profile or is admin
    IF current_user_id != p_worker_id AND NOT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = current_user_id 
        AND user_profiles.role IN ('admin', 'owner', 'warehouseManager')
        AND user_profiles.status = 'approved'
    ) THEN
        RAISE EXCEPTION 'Access denied: You can only check your own attendance profile';
    END IF;

    -- Check if profile exists
    SELECT EXISTS(
        SELECT 1 FROM worker_attendance_profiles
        WHERE worker_id = p_worker_id
        AND device_hash = p_device_hash
        AND is_active = true
    ) INTO profile_exists;

    RETURN profile_exists;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error checking worker profile: %', SQLERRM;
END;
$$;

-- Function 3: Update Worker Profile Stats (called after successful attendance)
CREATE OR REPLACE FUNCTION update_worker_profile_stats(
    p_worker_id UUID,
    p_device_hash VARCHAR(64),
    p_attendance_type attendance_type_enum
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
BEGIN
    -- Get the current authenticated user ID
    current_user_id := auth.uid();
    
    -- Security check: Ensure user can only update their own profile or is admin
    IF current_user_id != p_worker_id AND NOT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = current_user_id 
        AND user_profiles.role IN ('admin', 'owner', 'warehouseManager')
        AND user_profiles.status = 'approved'
    ) THEN
        RAISE EXCEPTION 'Access denied: You can only update your own attendance profile';
    END IF;

    -- Update profile stats
    UPDATE worker_attendance_profiles 
    SET 
        last_attendance_type = p_attendance_type,
        last_attendance_time = NOW(),
        total_check_ins = CASE 
            WHEN p_attendance_type = 'check_in' THEN total_check_ins + 1 
            ELSE total_check_ins 
        END,
        total_check_outs = CASE 
            WHEN p_attendance_type = 'check_out' THEN total_check_outs + 1 
            ELSE total_check_outs 
        END,
        updated_at = NOW()
    WHERE worker_id = p_worker_id
    AND device_hash = p_device_hash;

    -- Check if update was successful
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Worker profile not found for update';
    END IF;

    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error updating worker profile stats: %', SQLERRM;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_or_create_worker_profile TO authenticated;
GRANT EXECUTE ON FUNCTION check_worker_profile_exists TO authenticated;
GRANT EXECUTE ON FUNCTION update_worker_profile_stats TO authenticated;

-- Add comments for documentation
COMMENT ON FUNCTION get_or_create_worker_profile IS 'Gets existing worker attendance profile or creates a new one with security checks';
COMMENT ON FUNCTION check_worker_profile_exists IS 'Checks if a worker has an active attendance profile for the given device';
COMMENT ON FUNCTION update_worker_profile_stats IS 'Updates worker profile statistics after successful attendance recording';

-- Verification
DO $$
BEGIN
    RAISE NOTICE '🎉 Worker profile management functions created successfully!';
    RAISE NOTICE '✅ get_or_create_worker_profile - Secure profile creation/retrieval';
    RAISE NOTICE '✅ check_worker_profile_exists - Profile existence check';
    RAISE NOTICE '✅ update_worker_profile_stats - Profile statistics update';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Next step: Update BiometricAttendanceService to use these functions';
END $$;
