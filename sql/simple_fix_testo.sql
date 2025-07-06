-- حل مبسط ومباشر لإصلاح المستخدم testo@sama.com

-- 1. إصلاح حالة المصادقة في auth.users
UPDATE auth.users 
SET email_confirmed_at = NOW()
WHERE email = 'testo@sama.com' 
AND email_confirmed_at IS NULL;

-- 2. إصلاح حالة المستخدم في user_profiles
UPDATE user_profiles 
SET 
    status = 'active',
    email_confirmed = TRUE,
    email_confirmed_at = NOW(),
    updated_at = NOW()
WHERE email = 'testo@sama.com';

-- 3. التحقق من النتيجة في user_profiles
SELECT 
    id,
    email,
    status,
    email_confirmed,
    email_confirmed_at,
    updated_at
FROM user_profiles 
WHERE email = 'testo@sama.com';

-- 4. التحقق من النتيجة في auth.users
SELECT 
    id,
    email,
    email_confirmed_at,
    last_sign_in_at,
    created_at
FROM auth.users 
WHERE email = 'testo@sama.com';

-- 5. إنشاء function مبسطة للإصلاح السريع
CREATE OR REPLACE FUNCTION quick_fix_user(user_email TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result_message TEXT;
BEGIN
    -- إصلاح auth.users
    UPDATE auth.users 
    SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
    WHERE email = user_email;
    
    -- إصلاح user_profiles
    UPDATE user_profiles 
    SET 
        status = 'active',
        email_confirmed = TRUE,
        email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
        updated_at = NOW()
    WHERE email = user_email;
    
    -- إنشاء رسالة النتيجة
    result_message := 'تم إصلاح المستخدم ' || user_email || ' بنجاح في ' || NOW();
    
    RETURN result_message;
END;
$$;

-- 6. تشغيل الإصلاح السريع
SELECT quick_fix_user('testo@sama.com');

-- 7. إصلاح جميع المستخدمين الموافق عليهم
UPDATE user_profiles 
SET 
    status = 'active',
    email_confirmed = TRUE,
    email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
    updated_at = NOW()
WHERE status = 'approved';

-- 8. إصلاح جميع المستخدمين في auth.users
UPDATE auth.users 
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email_confirmed_at IS NULL 
AND email IN (
    SELECT email FROM user_profiles WHERE status IN ('approved', 'active')
);

-- 9. تقرير سريع عن الحالة
SELECT 
    'user_profiles' as table_name,
    status,
    COUNT(*) as count
FROM user_profiles 
GROUP BY status
UNION ALL
SELECT 
    'auth.users' as table_name,
    CASE 
        WHEN email_confirmed_at IS NOT NULL THEN 'confirmed'
        ELSE 'not_confirmed'
    END as status,
    COUNT(*) as count
FROM auth.users 
GROUP BY CASE 
    WHEN email_confirmed_at IS NOT NULL THEN 'confirmed'
    ELSE 'not_confirmed'
END;

-- 10. فحص المستخدم المحدد
SELECT 
    'Final Check for testo@sama.com' as check_type,
    up.email,
    up.status as profile_status,
    up.email_confirmed as profile_email_confirmed,
    au.email_confirmed_at as auth_email_confirmed_at,
    CASE 
        WHEN up.status = 'active' AND up.email_confirmed = TRUE AND au.email_confirmed_at IS NOT NULL 
        THEN 'FIXED ✅'
        ELSE 'NEEDS ATTENTION ❌'
    END as fix_status
FROM user_profiles up
LEFT JOIN auth.users au ON up.email = au.email
WHERE up.email = 'testo@sama.com';
