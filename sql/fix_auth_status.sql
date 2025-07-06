-- إصلاح حالة المصادقة للمستخدمين العالقين

-- إنشاء function لإصلاح حالة المصادقة
CREATE OR REPLACE FUNCTION fix_user_auth_status(user_email TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- إصلاح حالة المصادقة في auth.users (فقط email_confirmed_at)
    UPDATE auth.users
    SET
        email_confirmed_at = COALESCE(email_confirmed_at, NOW())
    WHERE
        email = user_email;

    -- إصلاح حالة المستخدم في user_profiles
    UPDATE user_profiles
    SET
        status = 'active',
        email_confirmed = TRUE,
        email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
        updated_at = NOW()
    WHERE
        email = user_email;

    RETURN TRUE;
END;
$$;

-- إصلاح المستخدم المحدد
SELECT fix_user_auth_status('testo@sama.com');

-- إنشاء function لإصلاح جميع المستخدمين العالقين
CREATE OR REPLACE FUNCTION fix_all_stuck_users()
RETURNS TABLE(
    user_email TEXT,
    old_status TEXT,
    new_status TEXT,
    fixed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH stuck_users AS (
        SELECT
            up.email,
            up.status as old_status
        FROM user_profiles up
        LEFT JOIN auth.users au ON up.email = au.email
        WHERE
            up.status = 'approved'
            AND (
                up.email_confirmed = FALSE
                OR up.email_confirmed IS NULL
                OR au.email_confirmed_at IS NULL
                OR au.confirmed_at IS NULL
            )
    ),
    fixed_users AS (
        UPDATE user_profiles
        SET
            status = 'active',
            email_confirmed = TRUE,
            email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
            updated_at = NOW()
        WHERE email IN (SELECT email FROM stuck_users)
        RETURNING email, 'approved' as old_status, status as new_status
    ),
    fixed_auth AS (
        UPDATE auth.users
        SET
            email_confirmed_at = COALESCE(email_confirmed_at, NOW())
        WHERE email IN (SELECT email FROM stuck_users)
        RETURNING email
    )
    SELECT
        fu.email as user_email,
        fu.old_status,
        fu.new_status,
        TRUE as fixed
    FROM fixed_users fu;
END;
$$;

-- إنشاء function للحصول على تقرير المستخدمين العالقين
CREATE OR REPLACE FUNCTION get_stuck_users_report()
RETURNS TABLE(
    user_email TEXT,
    profile_status TEXT,
    profile_email_confirmed BOOLEAN,
    auth_email_confirmed_at TIMESTAMPTZ,
    is_stuck BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        up.email as user_email,
        up.status as profile_status,
        COALESCE(up.email_confirmed, FALSE) as profile_email_confirmed,
        au.email_confirmed_at as auth_email_confirmed_at,
        (
            up.status = 'approved'
            AND (
                up.email_confirmed = FALSE
                OR up.email_confirmed IS NULL
                OR au.email_confirmed_at IS NULL
            )
        ) as is_stuck
    FROM user_profiles up
    LEFT JOIN auth.users au ON up.email = au.email
    WHERE up.status IN ('approved', 'active')
    ORDER BY up.created_at DESC;
END;
$$;

-- تشغيل التقرير لرؤية المستخدمين العالقين
SELECT * FROM get_stuck_users_report() WHERE is_stuck = TRUE;

-- إصلاح جميع المستخدمين العالقين
SELECT * FROM fix_all_stuck_users();

-- التحقق من النتيجة
SELECT * FROM get_stuck_users_report() WHERE user_email = 'testo@sama.com';

-- إضافة تعليقات
COMMENT ON FUNCTION fix_user_auth_status(TEXT) IS 'إصلاح حالة المصادقة لمستخدم محدد';
COMMENT ON FUNCTION fix_all_stuck_users() IS 'إصلاح جميع المستخدمين العالقين في حالة المصادقة';
COMMENT ON FUNCTION get_stuck_users_report() IS 'تقرير المستخدمين العالقين في حالة المصادقة';
