-- إضافة عمود email_confirmed إلى جدول user_profiles إذا لم يكن موجوداً
-- وإنشاء function لإضافة العمود

-- إضافة العمود إذا لم يكن موجوداً
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'email_confirmed'
    ) THEN
        ALTER TABLE user_profiles 
        ADD COLUMN email_confirmed BOOLEAN DEFAULT FALSE;
        
        -- إضافة عمود تاريخ تأكيد البريد الإلكتروني
        ALTER TABLE user_profiles 
        ADD COLUMN email_confirmed_at TIMESTAMPTZ;
        
        RAISE NOTICE 'Added email_confirmed and email_confirmed_at columns to user_profiles table';
    ELSE
        RAISE NOTICE 'email_confirmed column already exists in user_profiles table';
    END IF;
END $$;

-- إنشاء function لإضافة العمود (للاستخدام من Flutter)
CREATE OR REPLACE FUNCTION add_email_confirmed_column()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- فحص ما إذا كان العمود موجوداً
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'email_confirmed'
    ) THEN
        -- إضافة العمود
        ALTER TABLE user_profiles 
        ADD COLUMN email_confirmed BOOLEAN DEFAULT FALSE;
        
        ALTER TABLE user_profiles 
        ADD COLUMN email_confirmed_at TIMESTAMPTZ;
        
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$;

-- تحديث المستخدمين الموجودين
-- المستخدمين الذين لديهم status = 'approved' أو 'active' يجب أن يكون بريدهم مؤكد
UPDATE user_profiles 
SET 
    email_confirmed = TRUE,
    email_confirmed_at = COALESCE(updated_at, created_at)
WHERE 
    status IN ('approved', 'active') 
    AND (email_confirmed IS NULL OR email_confirmed = FALSE);

-- إنشاء function لإصلاح المستخدمين العالقين
CREATE OR REPLACE FUNCTION fix_stuck_users()
RETURNS TABLE(
    user_id UUID,
    email TEXT,
    old_status TEXT,
    new_status TEXT,
    fixed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH updated_users AS (
        UPDATE user_profiles 
        SET 
            email_confirmed = TRUE,
            email_confirmed_at = NOW(),
            status = 'active',
            updated_at = NOW()
        WHERE 
            status = 'approved' 
            AND (email_confirmed IS NULL OR email_confirmed = FALSE)
        RETURNING 
            id as user_id,
            email,
            'approved' as old_status,
            status as new_status,
            TRUE as fixed
    )
    SELECT * FROM updated_users;
END;
$$;

-- إنشاء function للحصول على تقرير شامل عن المستخدمين
CREATE OR REPLACE FUNCTION get_users_status_report()
RETURNS TABLE(
    status_type TEXT,
    count BIGINT,
    emails TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'pending' as status_type,
        COUNT(*) as count,
        ARRAY_AGG(email) as emails
    FROM user_profiles 
    WHERE status = 'pending'
    
    UNION ALL
    
    SELECT 
        'stuck' as status_type,
        COUNT(*) as count,
        ARRAY_AGG(email) as emails
    FROM user_profiles 
    WHERE status = 'approved' AND (email_confirmed IS NULL OR email_confirmed = FALSE)
    
    UNION ALL
    
    SELECT 
        'active' as status_type,
        COUNT(*) as count,
        ARRAY_AGG(email) as emails
    FROM user_profiles 
    WHERE status = 'active' AND email_confirmed = TRUE
    
    UNION ALL
    
    SELECT 
        'other' as status_type,
        COUNT(*) as count,
        ARRAY_AGG(email) as emails
    FROM user_profiles 
    WHERE NOT (
        status = 'pending' OR 
        (status = 'approved' AND (email_confirmed IS NULL OR email_confirmed = FALSE)) OR
        (status = 'active' AND email_confirmed = TRUE)
    );
END;
$$;

-- إنشاء trigger لتحديث email_confirmed تلقائياً عند الموافقة
CREATE OR REPLACE FUNCTION auto_confirm_email_on_approval()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- إذا تم تغيير الحالة إلى approved أو active، نؤكد البريد تلقائياً
    IF NEW.status IN ('approved', 'active') AND (OLD.status IS NULL OR OLD.status != NEW.status) THEN
        NEW.email_confirmed = TRUE;
        NEW.email_confirmed_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$;

-- إنشاء trigger
DROP TRIGGER IF EXISTS trigger_auto_confirm_email ON user_profiles;
CREATE TRIGGER trigger_auto_confirm_email
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION auto_confirm_email_on_approval();

-- إضافة index لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_user_profiles_email_confirmed 
ON user_profiles(email_confirmed);

CREATE INDEX IF NOT EXISTS idx_user_profiles_status_email_confirmed 
ON user_profiles(status, email_confirmed);

-- إضافة تعليقات للتوضيح
COMMENT ON COLUMN user_profiles.email_confirmed IS 'هل تم تأكيد البريد الإلكتروني للمستخدم';
COMMENT ON COLUMN user_profiles.email_confirmed_at IS 'تاريخ ووقت تأكيد البريد الإلكتروني';
COMMENT ON FUNCTION fix_stuck_users() IS 'إصلاح المستخدمين العالقين في حالة انتظار تأكيد البريد الإلكتروني';
COMMENT ON FUNCTION get_users_status_report() IS 'الحصول على تقرير شامل عن حالة جميع المستخدمين';
