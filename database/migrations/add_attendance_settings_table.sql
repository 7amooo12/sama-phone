-- Migration: Add Attendance Settings Table for SmartBizTracker
-- This migration creates a table to store attendance configuration settings
-- including work hours, tolerance periods, and work days for persistent storage.

-- Create attendance_settings table
CREATE TABLE IF NOT EXISTS attendance_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID, -- For future multi-tenant support
    work_start_hour INTEGER NOT NULL DEFAULT 9 CHECK (work_start_hour >= 0 AND work_start_hour <= 23),
    work_start_minute INTEGER NOT NULL DEFAULT 0 CHECK (work_start_minute >= 0 AND work_start_minute <= 59),
    work_end_hour INTEGER NOT NULL DEFAULT 17 CHECK (work_end_hour >= 0 AND work_end_hour <= 23),
    work_end_minute INTEGER NOT NULL DEFAULT 0 CHECK (work_end_minute >= 0 AND work_end_minute <= 59),
    late_tolerance_minutes INTEGER NOT NULL DEFAULT 15 CHECK (late_tolerance_minutes >= 0 AND late_tolerance_minutes <= 120),
    early_departure_tolerance_minutes INTEGER NOT NULL DEFAULT 10 CHECK (early_departure_tolerance_minutes >= 0 AND early_departure_tolerance_minutes <= 120),
    required_daily_hours DECIMAL(4,2) NOT NULL DEFAULT 8.0 CHECK (required_daily_hours >= 1.0 AND required_daily_hours <= 24.0),
    work_days INTEGER[] NOT NULL DEFAULT ARRAY[1,2,3,4,5], -- 1=Monday, 7=Sunday
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES user_profiles(id),
    updated_by UUID REFERENCES user_profiles(id),
    
    -- Constraints
    CONSTRAINT valid_work_hours CHECK (
        (work_start_hour * 60 + work_start_minute) < (work_end_hour * 60 + work_end_minute)
    ),
    CONSTRAINT valid_work_days CHECK (
        array_length(work_days, 1) > 0 AND
        work_days <@ ARRAY[1,2,3,4,5,6,7]
    )
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_attendance_settings_active ON attendance_settings(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_attendance_settings_org ON attendance_settings(organization_id) WHERE organization_id IS NOT NULL;

-- Create function to validate work_days uniqueness and other business rules
CREATE OR REPLACE FUNCTION validate_attendance_settings()
RETURNS TRIGGER AS $$
DECLARE
    unique_days INTEGER[];
    day_count INTEGER;
    unique_count INTEGER;
BEGIN
    -- Validate work_days uniqueness (since we can't use subqueries in CHECK constraints)
    SELECT array_agg(DISTINCT unnest) INTO unique_days FROM unnest(NEW.work_days);
    day_count := array_length(NEW.work_days, 1);
    unique_count := array_length(unique_days, 1);

    IF day_count != unique_count THEN
        RAISE EXCEPTION 'أيام العمل يجب أن تكون فريدة - لا يمكن تكرار نفس اليوم';
    END IF;

    -- Additional business rule validations can be added here
    -- For example, ensure at least one work day is selected
    IF day_count = 0 THEN
        RAISE EXCEPTION 'يجب تحديد يوم واحد على الأقل للعمل';
    END IF;

    -- Validate that work days are within valid range (1-7)
    IF EXISTS (SELECT 1 FROM unnest(NEW.work_days) AS day WHERE day < 1 OR day > 7) THEN
        RAISE EXCEPTION 'أيام العمل يجب أن تكون بين 1 (الاثنين) و 7 (الأحد)';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to validate attendance settings before insert/update
CREATE TRIGGER trigger_validate_attendance_settings
    BEFORE INSERT OR UPDATE ON attendance_settings
    FOR EACH ROW
    EXECUTE FUNCTION validate_attendance_settings();

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_attendance_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_attendance_settings_updated_at
    BEFORE UPDATE ON attendance_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_attendance_settings_updated_at();

-- Insert default attendance settings if none exist
INSERT INTO attendance_settings (
    work_start_hour,
    work_start_minute,
    work_end_hour,
    work_end_minute,
    late_tolerance_minutes,
    early_departure_tolerance_minutes,
    required_daily_hours,
    work_days,
    created_by
)
SELECT 
    9,    -- 9:00 AM start time
    0,
    17,   -- 5:00 PM end time  
    0,
    15,   -- 15 minutes late tolerance
    10,   -- 10 minutes early departure tolerance
    8.0,  -- 8 hours required daily
    ARRAY[6,7,1,2,3], -- Saturday to Wednesday (Middle Eastern work week)
    (SELECT id FROM user_profiles WHERE role IN ('admin', 'مدير') LIMIT 1)
WHERE NOT EXISTS (
    SELECT 1 FROM attendance_settings WHERE is_active = true LIMIT 1
);

-- Add RLS (Row Level Security) policies
ALTER TABLE attendance_settings ENABLE ROW LEVEL SECURITY;

-- Policy: Admins and warehouse managers can view all settings
CREATE POLICY attendance_settings_select_policy ON attendance_settings
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'مدير', 'warehouseManager', 'مدير_مخزن')
            AND status IN ('active', 'approved')
        )
    );

-- Policy: Only admins can insert/update/delete settings
CREATE POLICY attendance_settings_modify_policy ON attendance_settings
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'مدير')
            AND status IN ('active', 'approved')
        )
    );

-- Grant necessary permissions
GRANT SELECT ON attendance_settings TO authenticated;
GRANT INSERT, UPDATE, DELETE ON attendance_settings TO authenticated;

-- Function to get current attendance settings
CREATE OR REPLACE FUNCTION get_attendance_settings()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    settings_record RECORD;
    result JSON;
BEGIN
    -- Check if user has permission to view settings
    IF NOT EXISTS (
        SELECT 1 FROM user_profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'مدير', 'warehouseManager', 'مدير_مخزن')
        AND status IN ('active', 'approved')
    ) THEN
        RAISE EXCEPTION 'غير مصرح لك بعرض إعدادات الحضور';
    END IF;

    -- Get the active attendance settings
    SELECT * INTO settings_record
    FROM attendance_settings
    WHERE is_active = true
    ORDER BY created_at DESC
    LIMIT 1;

    -- If no settings found, return default settings
    IF NOT FOUND THEN
        result := json_build_object(
            'work_start_hour', 9,
            'work_start_minute', 0,
            'work_end_hour', 17,
            'work_end_minute', 0,
            'late_tolerance_minutes', 15,
            'early_departure_tolerance_minutes', 10,
            'required_daily_hours', 8.0,
            'work_days', ARRAY[6,7,1,2,3], -- Saturday to Wednesday
            'is_default', true
        );
    ELSE
        result := json_build_object(
            'id', settings_record.id,
            'work_start_hour', settings_record.work_start_hour,
            'work_start_minute', settings_record.work_start_minute,
            'work_end_hour', settings_record.work_end_hour,
            'work_end_minute', settings_record.work_end_minute,
            'late_tolerance_minutes', settings_record.late_tolerance_minutes,
            'early_departure_tolerance_minutes', settings_record.early_departure_tolerance_minutes,
            'required_daily_hours', settings_record.required_daily_hours,
            'work_days', settings_record.work_days,
            'is_default', false,
            'created_at', settings_record.created_at,
            'updated_at', settings_record.updated_at
        );
    END IF;

    RETURN result;
END;
$$;

-- Function to update attendance settings
CREATE OR REPLACE FUNCTION update_attendance_settings(
    p_work_start_hour INTEGER,
    p_work_start_minute INTEGER,
    p_work_end_hour INTEGER,
    p_work_end_minute INTEGER,
    p_late_tolerance_minutes INTEGER,
    p_early_departure_tolerance_minutes INTEGER,
    p_required_daily_hours DECIMAL,
    p_work_days INTEGER[]
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    settings_id UUID;
    result JSON;
BEGIN
    -- Check if user has permission to update settings (admin only)
    IF NOT EXISTS (
        SELECT 1 FROM user_profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'مدير')
        AND status IN ('active', 'approved')
    ) THEN
        RAISE EXCEPTION 'غير مصرح لك بتحديث إعدادات الحضور';
    END IF;

    -- Validate input parameters
    IF p_work_start_hour < 0 OR p_work_start_hour > 23 THEN
        RAISE EXCEPTION 'ساعة بداية العمل يجب أن تكون بين 0 و 23';
    END IF;

    IF p_work_start_minute < 0 OR p_work_start_minute > 59 THEN
        RAISE EXCEPTION 'دقيقة بداية العمل يجب أن تكون بين 0 و 59';
    END IF;

    IF p_work_end_hour < 0 OR p_work_end_hour > 23 THEN
        RAISE EXCEPTION 'ساعة نهاية العمل يجب أن تكون بين 0 و 23';
    END IF;

    IF p_work_end_minute < 0 OR p_work_end_minute > 59 THEN
        RAISE EXCEPTION 'دقيقة نهاية العمل يجب أن تكون بين 0 و 59';
    END IF;

    IF (p_work_start_hour * 60 + p_work_start_minute) >= (p_work_end_hour * 60 + p_work_end_minute) THEN
        RAISE EXCEPTION 'وقت بداية العمل يجب أن يكون قبل وقت نهاية العمل';
    END IF;

    IF p_late_tolerance_minutes < 0 OR p_late_tolerance_minutes > 120 THEN
        RAISE EXCEPTION 'فترة تسامح التأخير يجب أن تكون بين 0 و 120 دقيقة';
    END IF;

    IF p_early_departure_tolerance_minutes < 0 OR p_early_departure_tolerance_minutes > 120 THEN
        RAISE EXCEPTION 'فترة تسامح الانصراف المبكر يجب أن تكون بين 0 و 120 دقيقة';
    END IF;

    IF p_required_daily_hours < 1.0 OR p_required_daily_hours > 24.0 THEN
        RAISE EXCEPTION 'ساعات العمل المطلوبة يومياً يجب أن تكون بين 1 و 24 ساعة';
    END IF;

    IF array_length(p_work_days, 1) = 0 OR NOT (p_work_days <@ ARRAY[1,2,3,4,5,6,7]) THEN
        RAISE EXCEPTION 'أيام العمل يجب أن تحتوي على قيم صحيحة بين 1 و 7';
    END IF;

    -- Deactivate existing settings
    UPDATE attendance_settings SET is_active = false WHERE is_active = true;

    -- Insert new settings
    INSERT INTO attendance_settings (
        work_start_hour,
        work_start_minute,
        work_end_hour,
        work_end_minute,
        late_tolerance_minutes,
        early_departure_tolerance_minutes,
        required_daily_hours,
        work_days,
        created_by,
        updated_by
    ) VALUES (
        p_work_start_hour,
        p_work_start_minute,
        p_work_end_hour,
        p_work_end_minute,
        p_late_tolerance_minutes,
        p_early_departure_tolerance_minutes,
        p_required_daily_hours,
        p_work_days,
        auth.uid(),
        auth.uid()
    ) RETURNING id INTO settings_id;

    -- Return success result
    result := json_build_object(
        'success', true,
        'message', 'تم تحديث إعدادات الحضور بنجاح',
        'settings_id', settings_id
    );

    RETURN result;
END;
$$;
