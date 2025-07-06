-- =====================================================
-- FIX BIOMETRIC ATTENDANCE SEQUENCE LOGIC ERROR
-- =====================================================
-- This script fixes the critical issue where biometric check-in 
-- incorrectly reports "تم تسجيل الحضور مسبقاً" even when no 
-- previous check-in exists, causing the attendance system to lock.
--
-- Root Cause: Inconsistency between worker_attendance_records table
-- and worker_attendance_profiles.last_attendance_type field
-- =====================================================

-- Step 1: Clean up any stale data in worker profiles
-- Reset profiles where 15+ hours have passed since last attendance
UPDATE worker_attendance_profiles 
SET 
    last_attendance_type = NULL,
    last_attendance_time = NULL,
    updated_at = NOW()
WHERE 
    last_attendance_time IS NOT NULL 
    AND EXTRACT(EPOCH FROM (NOW() - last_attendance_time)) / 3600 >= 15;

-- Step 2: Fix profiles with inconsistent state
-- Find profiles where last_attendance_type doesn't match actual records
WITH profile_vs_records AS (
    SELECT 
        p.worker_id,
        p.device_hash,
        p.last_attendance_type as profile_type,
        r.attendance_type as record_type,
        r.timestamp as record_time,
        p.last_attendance_time as profile_time
    FROM worker_attendance_profiles p
    LEFT JOIN LATERAL (
        SELECT attendance_type, timestamp
        FROM worker_attendance_records 
        WHERE worker_id = p.worker_id 
        ORDER BY timestamp DESC 
        LIMIT 1
    ) r ON true
    WHERE p.is_active = true
),
inconsistent_profiles AS (
    SELECT worker_id, device_hash
    FROM profile_vs_records
    WHERE 
        -- Profile says there's a last type but no records exist
        (profile_type IS NOT NULL AND record_type IS NULL)
        OR
        -- Profile type doesn't match the actual last record
        (profile_type IS NOT NULL AND record_type IS NOT NULL AND profile_type != record_type)
        OR
        -- Profile time doesn't match record time (allowing 1 minute tolerance)
        (profile_time IS NOT NULL AND record_time IS NOT NULL 
         AND ABS(EXTRACT(EPOCH FROM (profile_time - record_time))) > 60)
)
UPDATE worker_attendance_profiles 
SET 
    last_attendance_type = (
        SELECT attendance_type 
        FROM worker_attendance_records 
        WHERE worker_id = worker_attendance_profiles.worker_id 
        ORDER BY timestamp DESC 
        LIMIT 1
    ),
    last_attendance_time = (
        SELECT timestamp 
        FROM worker_attendance_records 
        WHERE worker_id = worker_attendance_profiles.worker_id 
        ORDER BY timestamp DESC 
        LIMIT 1
    ),
    updated_at = NOW()
WHERE (worker_id, device_hash) IN (
    SELECT worker_id, device_hash FROM inconsistent_profiles
);

-- Step 3: Apply the updated biometric attendance function
-- (The function has already been updated in add_biometric_location_attendance.sql)

-- Step 4: Create a diagnostic function to help troubleshoot future issues
CREATE OR REPLACE FUNCTION diagnose_worker_attendance_state(
    p_worker_id UUID,
    p_device_hash VARCHAR(64) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile RECORD;
    v_last_record RECORD;
    v_time_gap_hours INTEGER;
    v_diagnosis JSONB;
BEGIN
    -- Get worker profile
    SELECT * INTO v_profile
    FROM worker_attendance_profiles
    WHERE worker_id = p_worker_id 
    AND (p_device_hash IS NULL OR device_hash = p_device_hash)
    AND is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;
    
    -- Get last attendance record
    SELECT * INTO v_last_record
    FROM worker_attendance_records
    WHERE worker_id = p_worker_id
    ORDER BY timestamp DESC
    LIMIT 1;
    
    -- Calculate time gap if profile has last time
    IF v_profile.last_attendance_time IS NOT NULL THEN
        v_time_gap_hours := EXTRACT(EPOCH FROM (NOW() - v_profile.last_attendance_time)) / 3600;
    END IF;
    
    -- Build diagnosis
    v_diagnosis := jsonb_build_object(
        'worker_id', p_worker_id,
        'diagnosis_time', NOW(),
        'profile_exists', v_profile.id IS NOT NULL,
        'profile_info', CASE 
            WHEN v_profile.id IS NOT NULL THEN
                jsonb_build_object(
                    'device_hash', v_profile.device_hash,
                    'last_attendance_type', v_profile.last_attendance_type,
                    'last_attendance_time', v_profile.last_attendance_time,
                    'total_check_ins', v_profile.total_check_ins,
                    'total_check_outs', v_profile.total_check_outs,
                    'is_active', v_profile.is_active
                )
            ELSE NULL
        END,
        'last_record_info', CASE 
            WHEN v_last_record.id IS NOT NULL THEN
                jsonb_build_object(
                    'attendance_type', v_last_record.attendance_type,
                    'timestamp', v_last_record.timestamp,
                    'device_hash', v_last_record.device_hash,
                    'attendance_method', v_last_record.attendance_method
                )
            ELSE NULL
        END,
        'time_analysis', jsonb_build_object(
            'time_gap_hours', v_time_gap_hours,
            'gap_exceeds_15h', v_time_gap_hours >= 15,
            'should_allow_fresh_checkin', v_time_gap_hours IS NULL OR v_time_gap_hours >= 15
        ),
        'consistency_check', jsonb_build_object(
            'profile_record_match', 
                (v_profile.last_attendance_type IS NULL AND v_last_record.id IS NULL) OR
                (v_profile.last_attendance_type = v_last_record.attendance_type),
            'recommended_action', CASE
                WHEN v_profile.id IS NULL THEN 'CREATE_PROFILE'
                WHEN v_time_gap_hours >= 15 THEN 'RESET_PROFILE_STATE'
                WHEN v_profile.last_attendance_type != v_last_record.attendance_type THEN 'SYNC_PROFILE_WITH_RECORDS'
                ELSE 'NO_ACTION_NEEDED'
            END
        )
    );
    
    RETURN v_diagnosis;
END;
$$;

-- Step 5: Create a function to fix worker profile state
CREATE OR REPLACE FUNCTION fix_worker_attendance_state(
    p_worker_id UUID,
    p_device_hash VARCHAR(64)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_diagnosis JSONB;
    v_action_taken TEXT;
BEGIN
    -- Get current diagnosis
    v_diagnosis := diagnose_worker_attendance_state(p_worker_id, p_device_hash);
    
    -- Take action based on diagnosis
    CASE (v_diagnosis->'consistency_check'->>'recommended_action')
        WHEN 'RESET_PROFILE_STATE' THEN
            UPDATE worker_attendance_profiles 
            SET last_attendance_type = NULL, 
                last_attendance_time = NULL,
                updated_at = NOW()
            WHERE worker_id = p_worker_id AND device_hash = p_device_hash;
            v_action_taken := 'PROFILE_STATE_RESET';
            
        WHEN 'SYNC_PROFILE_WITH_RECORDS' THEN
            UPDATE worker_attendance_profiles 
            SET last_attendance_type = (
                    SELECT attendance_type 
                    FROM worker_attendance_records 
                    WHERE worker_id = p_worker_id 
                    ORDER BY timestamp DESC 
                    LIMIT 1
                ),
                last_attendance_time = (
                    SELECT timestamp 
                    FROM worker_attendance_records 
                    WHERE worker_id = p_worker_id 
                    ORDER BY timestamp DESC 
                    LIMIT 1
                ),
                updated_at = NOW()
            WHERE worker_id = p_worker_id AND device_hash = p_device_hash;
            v_action_taken := 'PROFILE_SYNCED_WITH_RECORDS';
            
        ELSE
            v_action_taken := 'NO_ACTION_TAKEN';
    END CASE;
    
    RETURN jsonb_build_object(
        'success', true,
        'action_taken', v_action_taken,
        'worker_id', p_worker_id,
        'device_hash', p_device_hash,
        'timestamp', NOW()
    );
END;
$$;

-- Step 6: Log the completion
DO $$
BEGIN
    RAISE NOTICE '✅ Biometric attendance sequence logic fixes applied successfully';
    RAISE NOTICE '📊 Use diagnose_worker_attendance_state(worker_id) to troubleshoot issues';
    RAISE NOTICE '🔧 Use fix_worker_attendance_state(worker_id, device_hash) to fix profile state';
END $$;
