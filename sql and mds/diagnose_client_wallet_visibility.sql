-- 🔍 تشخيص مشكلة عدم ظهور جميع العملاء في صفحة إدارة المحافظ
-- Diagnose Client Wallet Visibility Issues

-- =====================================================
-- STEP 1: فحص جميع العملاء في جدول user_profiles
-- =====================================================

SELECT 
    '=== جميع العملاء في جدول user_profiles ===' as section;

SELECT 
    id,
    name,
    email,
    role,
    status,
    created_at,
    updated_at
FROM user_profiles
WHERE role IN ('client', 'عميل')
ORDER BY created_at DESC;

-- =====================================================
-- STEP 2: فحص العملاء حسب الحالة (status)
-- =====================================================

SELECT 
    '=== العملاء حسب الحالة ===' as section;

SELECT 
    status,
    COUNT(*) as count,
    STRING_AGG(name, ', ') as client_names
FROM user_profiles
WHERE role IN ('client', 'عميل')
GROUP BY status
ORDER BY status;

-- =====================================================
-- STEP 3: فحص المحافظ الموجودة للعملاء
-- =====================================================

SELECT 
    '=== محافظ العملاء الموجودة ===' as section;

SELECT 
    w.id as wallet_id,
    w.user_id,
    w.role as wallet_role,
    w.balance,
    w.status as wallet_status,
    up.name as user_name,
    up.email,
    up.role as user_role,
    up.status as user_status,
    w.created_at
FROM wallets w
LEFT JOIN user_profiles up ON w.user_id = up.id
WHERE w.role = 'client'
ORDER BY w.created_at DESC;

-- =====================================================
-- STEP 4: فحص العملاء بدون محافظ
-- =====================================================

SELECT 
    '=== العملاء بدون محافظ ===' as section;

SELECT 
    up.id,
    up.name,
    up.email,
    up.role,
    up.status,
    up.created_at
FROM user_profiles up
LEFT JOIN wallets w ON up.id = w.user_id AND w.role = 'client'
WHERE up.role IN ('client', 'عميل')
AND w.id IS NULL
ORDER BY up.created_at DESC;

-- =====================================================
-- STEP 5: فحص تطابق الأدوار بين الجدولين
-- =====================================================

SELECT 
    '=== فحص تطابق الأدوار ===' as section;

SELECT 
    w.id as wallet_id,
    w.user_id,
    w.role as wallet_role,
    up.role as user_role,
    up.status as user_status,
    up.name,
    CASE 
        WHEN w.role = up.role THEN 'متطابق'
        ELSE 'غير متطابق'
    END as role_match,
    CASE 
        WHEN up.status IN ('approved', 'active') THEN 'صالح'
        ELSE 'غير صالح'
    END as status_validity
FROM wallets w
INNER JOIN user_profiles up ON w.user_id = up.id
WHERE w.role = 'client' OR up.role IN ('client', 'عميل')
ORDER BY role_match, status_validity;

-- =====================================================
-- STEP 6: محاكاة الاستعلام المستخدم في التطبيق
-- =====================================================

SELECT 
    '=== محاكاة استعلام التطبيق الأساسي ===' as section;

-- محاكاة الاستعلام الأساسي في getWalletsByRole
SELECT 
    w.*,
    up.id as profile_id,
    up.name,
    up.email,
    up.phone_number,
    up.role as user_role,
    up.status as user_status
FROM wallets w
LEFT JOIN user_profiles up ON w.user_id = up.id
WHERE w.role = 'client'
AND up.role = 'client'
AND up.status IN ('approved', 'active')
ORDER BY w.created_at DESC;

-- =====================================================
-- STEP 7: محاكاة الاستعلام الاحتياطي (Fallback)
-- =====================================================

SELECT 
    '=== محاكاة الاستعلام الاحتياطي ===' as section;

-- الخطوة 1: جلب العملاء المعتمدين والنشطين
WITH approved_clients AS (
    SELECT id, name, email, phone_number, role, status
    FROM user_profiles
    WHERE (role = 'client' OR role = 'عميل')
    AND status IN ('approved', 'active')
),
-- الخطوة 2: جلب محافظ هؤلاء العملاء
client_wallets AS (
    SELECT w.*
    FROM wallets w
    INNER JOIN approved_clients ac ON w.user_id = ac.id
    WHERE w.role = 'client'
)
-- الخطوة 3: دمج البيانات
SELECT 
    cw.*,
    ac.name as user_name,
    ac.email as user_email,
    ac.phone_number,
    ac.role as user_role,
    ac.status as user_status
FROM client_wallets cw
INNER JOIN approved_clients ac ON cw.user_id = ac.id
ORDER BY cw.created_at DESC;

-- =====================================================
-- STEP 8: فحص العلاقات الخارجية
-- =====================================================

SELECT 
    '=== فحص العلاقات الخارجية ===' as section;

-- فحص إذا كان هناك مشكلة في العلاقة user_profile_id
SELECT 
    w.id as wallet_id,
    w.user_id,
    w.user_profile_id,
    CASE 
        WHEN w.user_id = w.user_profile_id THEN 'متطابق'
        WHEN w.user_profile_id IS NULL THEN 'فارغ'
        ELSE 'غير متطابق'
    END as profile_id_status
FROM wallets w
WHERE w.role = 'client'
ORDER BY profile_id_status;

-- =====================================================
-- STEP 9: إحصائيات شاملة
-- =====================================================

SELECT 
    '=== إحصائيات شاملة ===' as section;

SELECT 
    'إجمالي العملاء في user_profiles' as metric,
    COUNT(*) as count
FROM user_profiles
WHERE role IN ('client', 'عميل')

UNION ALL

SELECT 
    'العملاء المعتمدين (approved)' as metric,
    COUNT(*) as count
FROM user_profiles
WHERE role IN ('client', 'عميل') AND status = 'approved'

UNION ALL

SELECT 
    'العملاء النشطين (active)' as metric,
    COUNT(*) as count
FROM user_profiles
WHERE role IN ('client', 'عميل') AND status = 'active'

UNION ALL

SELECT 
    'إجمالي محافظ العملاء' as metric,
    COUNT(*) as count
FROM wallets
WHERE role = 'client'

UNION ALL

SELECT 
    'محافظ العملاء مع ملفات شخصية صحيحة' as metric,
    COUNT(*) as count
FROM wallets w
INNER JOIN user_profiles up ON w.user_id = up.id
WHERE w.role = 'client' 
AND up.role IN ('client', 'عميل')
AND up.status IN ('approved', 'active');
