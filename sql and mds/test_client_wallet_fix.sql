-- 🧪 اختبار إصلاح مشكلة عدم ظهور جميع العملاء في صفحة إدارة المحافظ
-- Test Client Wallet Visibility Fix

-- =====================================================
-- STEP 1: التحقق من حالة العملاء الحالية
-- =====================================================

SELECT 
    '=== حالة العملاء الحالية ===' as section;

SELECT 
    id,
    name,
    email,
    role,
    status,
    created_at
FROM user_profiles
WHERE role IN ('client', 'عميل')
ORDER BY created_at DESC;

-- =====================================================
-- STEP 2: التحقق من محافظ العملاء
-- =====================================================

SELECT 
    '=== محافظ العملاء الموجودة ===' as section;

SELECT 
    w.id as wallet_id,
    w.user_id,
    w.user_profile_id,
    w.role as wallet_role,
    w.balance,
    w.status as wallet_status,
    up.name as user_name,
    up.email,
    up.role as user_role,
    up.status as user_status,
    CASE 
        WHEN w.user_id = w.user_profile_id THEN 'متطابق'
        WHEN w.user_profile_id IS NULL THEN 'فارغ'
        ELSE 'غير متطابق'
    END as profile_id_consistency
FROM wallets w
LEFT JOIN user_profiles up ON w.user_profile_id = up.id
WHERE w.role = 'client'
ORDER BY w.created_at DESC;

-- =====================================================
-- STEP 3: محاكاة الاستعلام المحدث (الطريقة الأساسية)
-- =====================================================

SELECT 
    '=== اختبار الاستعلام المحدث (الطريقة الأساسية) ===' as section;

-- محاكاة الاستعلام الجديد مع الإصلاحات
SELECT 
    w.*,
    up.id as profile_id,
    up.name,
    up.email,
    up.phone_number,
    up.role as user_role,
    up.status as user_status,
    'الطريقة الأساسية' as query_method
FROM wallets w
LEFT JOIN user_profiles up ON w.user_profile_id = up.id
WHERE w.role = 'client'
AND (up.role = 'client' OR up.role = 'عميل')
AND (up.status = 'approved' OR up.status = 'active')
ORDER BY w.created_at DESC;

-- =====================================================
-- STEP 4: محاكاة الاستعلام الاحتياطي المحدث
-- =====================================================

SELECT 
    '=== اختبار الاستعلام الاحتياطي المحدث ===' as section;

-- الخطوة 1: جلب العملاء المعتمدين والنشطين
WITH approved_clients AS (
    SELECT id, name, email, phone_number, role, status
    FROM user_profiles
    WHERE (role = 'client' OR role = 'عميل')
    AND (status = 'approved' OR status = 'active')
),
-- الخطوة 2: جلب محافظ هؤلاء العملاء
client_wallets AS (
    SELECT w.*
    FROM wallets w
    INNER JOIN approved_clients ac ON w.user_id = ac.id
    WHERE w.role = 'client'
)
-- الخطوة 3: دمج البيانات مع التحقق من صحة الأدوار
SELECT 
    cw.*,
    ac.name as user_name,
    ac.email as user_email,
    ac.phone_number,
    ac.role as user_role,
    ac.status as user_status,
    'الطريقة الاحتياطية' as query_method,
    CASE 
        WHEN cw.role = 'client' AND (ac.role = 'client' OR ac.role = 'عميل') THEN 'صحيح'
        ELSE 'خطأ'
    END as role_validation,
    CASE 
        WHEN ac.status IN ('approved', 'active') THEN 'صحيح'
        ELSE 'خطأ'
    END as status_validation
FROM client_wallets cw
INNER JOIN approved_clients ac ON cw.user_id = ac.id
WHERE cw.role = 'client' 
AND (ac.role = 'client' OR ac.role = 'عميل')
AND (ac.status = 'approved' OR ac.status = 'active')
ORDER BY cw.created_at DESC;

-- =====================================================
-- STEP 5: مقارنة النتائج
-- =====================================================

SELECT 
    '=== مقارنة النتائج ===' as section;

-- عدد العملاء في user_profiles
WITH stats AS (
    SELECT 
        'إجمالي العملاء في user_profiles' as metric,
        COUNT(*) as count
    FROM user_profiles
    WHERE role IN ('client', 'عميل')
    
    UNION ALL
    
    SELECT 
        'العملاء النشطين/المعتمدين' as metric,
        COUNT(*) as count
    FROM user_profiles
    WHERE role IN ('client', 'عميل')
    AND status IN ('approved', 'active')
    
    UNION ALL
    
    SELECT 
        'محافظ العملاء (الطريقة الأساسية)' as metric,
        COUNT(*) as count
    FROM wallets w
    LEFT JOIN user_profiles up ON w.user_profile_id = up.id
    WHERE w.role = 'client'
    AND (up.role = 'client' OR up.role = 'عميل')
    AND (up.status = 'approved' OR up.status = 'active')
    
    UNION ALL
    
    SELECT 
        'محافظ العملاء (الطريقة الاحتياطية)' as metric,
        COUNT(*) as count
    FROM wallets w
    INNER JOIN user_profiles up ON w.user_id = up.id
    WHERE w.role = 'client'
    AND (up.role = 'client' OR up.role = 'عميل')
    AND (up.status = 'approved' OR up.status = 'active')
)
SELECT * FROM stats;

-- =====================================================
-- STEP 6: فحص العلاقات والتطابق
-- =====================================================

SELECT 
    '=== فحص العلاقات والتطابق ===' as section;

SELECT 
    w.id as wallet_id,
    w.user_id,
    w.user_profile_id,
    up.id as profile_id,
    up.name,
    up.role as user_role,
    up.status as user_status,
    CASE 
        WHEN w.user_id = w.user_profile_id AND w.user_profile_id = up.id THEN '✅ صحيح'
        WHEN w.user_profile_id IS NULL THEN '⚠️ user_profile_id فارغ'
        WHEN w.user_id != w.user_profile_id THEN '❌ عدم تطابق user_id و user_profile_id'
        WHEN w.user_profile_id != up.id THEN '❌ عدم تطابق user_profile_id و profile.id'
        ELSE '❓ غير محدد'
    END as relationship_status
FROM wallets w
LEFT JOIN user_profiles up ON w.user_profile_id = up.id
WHERE w.role = 'client'
ORDER BY relationship_status, w.created_at DESC;

-- =====================================================
-- STEP 7: التوصيات النهائية
-- =====================================================

SELECT 
    '=== التوصيات النهائية ===' as section;

-- فحص إذا كانت هناك حاجة لإصلاحات إضافية
WITH issues AS (
    SELECT 
        COUNT(*) as wallets_with_null_profile_id
    FROM wallets w
    WHERE w.role = 'client' AND w.user_profile_id IS NULL
),
missing_relationships AS (
    SELECT 
        COUNT(*) as wallets_with_missing_profiles
    FROM wallets w
    LEFT JOIN user_profiles up ON w.user_profile_id = up.id
    WHERE w.role = 'client' AND up.id IS NULL
)
SELECT 
    'محافظ بدون user_profile_id' as issue_type,
    wallets_with_null_profile_id as count,
    CASE 
        WHEN wallets_with_null_profile_id > 0 THEN 'يحتاج إصلاح'
        ELSE 'لا يحتاج إصلاح'
    END as recommendation
FROM issues

UNION ALL

SELECT 
    'محافظ بدون ملفات شخصية مرتبطة' as issue_type,
    wallets_with_missing_profiles as count,
    CASE 
        WHEN wallets_with_missing_profiles > 0 THEN 'يحتاج إصلاح'
        ELSE 'لا يحتاج إصلاح'
    END as recommendation
FROM missing_relationships;
