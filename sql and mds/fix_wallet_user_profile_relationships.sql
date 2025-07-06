-- 🔧 إصلاح العلاقات بين المحافظ والملفات الشخصية
-- Fix Wallet User Profile Relationships

-- =====================================================
-- STEP 1: فحص الوضع الحالي
-- =====================================================

SELECT 
    '=== فحص الوضع الحالي ===' as section;

-- فحص المحافظ بدون user_profile_id
SELECT 
    'محافظ بدون user_profile_id' as issue_type,
    COUNT(*) as count
FROM wallets
WHERE user_profile_id IS NULL;

-- فحص المحافظ مع user_profile_id غير متطابق مع user_id
SELECT 
    'محافظ مع user_profile_id غير متطابق' as issue_type,
    COUNT(*) as count
FROM wallets
WHERE user_profile_id IS NOT NULL 
AND user_id != user_profile_id;

-- =====================================================
-- STEP 2: إصلاح المحافظ بدون user_profile_id
-- =====================================================

SELECT 
    '=== إصلاح المحافظ بدون user_profile_id ===' as section;

-- تحديث المحافظ لتعيين user_profile_id = user_id
UPDATE wallets 
SET 
    user_profile_id = user_id,
    updated_at = NOW()
WHERE user_profile_id IS NULL
AND EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = wallets.user_id
);

-- عرض النتائج
SELECT 
    'تم تحديث المحافظ' as result,
    ROW_COUNT() as updated_count;

-- =====================================================
-- STEP 3: إصلاح المحافظ مع user_profile_id غير متطابق
-- =====================================================

SELECT 
    '=== إصلاح المحافظ مع user_profile_id غير متطابق ===' as section;

-- تحديث المحافظ لتعيين user_profile_id = user_id
UPDATE wallets 
SET 
    user_profile_id = user_id,
    updated_at = NOW()
WHERE user_profile_id IS NOT NULL 
AND user_id != user_profile_id
AND EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = wallets.user_id
);

-- عرض النتائج
SELECT 
    'تم إصلاح التطابق' as result,
    ROW_COUNT() as fixed_count;

-- =====================================================
-- STEP 4: التحقق من النتائج النهائية
-- =====================================================

SELECT 
    '=== التحقق من النتائج النهائية ===' as section;

-- فحص شامل للمحافظ والعلاقات
SELECT 
    w.id as wallet_id,
    w.user_id,
    w.user_profile_id,
    w.role as wallet_role,
    up.name as user_name,
    up.role as user_role,
    up.status as user_status,
    CASE 
        WHEN w.user_id = w.user_profile_id AND up.id IS NOT NULL THEN '✅ صحيح'
        WHEN w.user_profile_id IS NULL THEN '❌ user_profile_id فارغ'
        WHEN w.user_id != w.user_profile_id THEN '❌ عدم تطابق'
        WHEN up.id IS NULL THEN '❌ ملف شخصي مفقود'
        ELSE '❓ غير محدد'
    END as relationship_status
FROM wallets w
LEFT JOIN user_profiles up ON w.user_profile_id = up.id
WHERE w.role = 'client'
ORDER BY relationship_status, w.created_at DESC;

-- =====================================================
-- STEP 5: إحصائيات نهائية
-- =====================================================

SELECT 
    '=== إحصائيات نهائية ===' as section;

SELECT 
    'إجمالي محافظ العملاء' as metric,
    COUNT(*) as count
FROM wallets
WHERE role = 'client'

UNION ALL

SELECT 
    'محافظ العملاء مع علاقات صحيحة' as metric,
    COUNT(*) as count
FROM wallets w
INNER JOIN user_profiles up ON w.user_profile_id = up.id
WHERE w.role = 'client'
AND w.user_id = w.user_profile_id
AND (up.role = 'client' OR up.role = 'عميل')
AND (up.status = 'approved' OR up.status = 'active')

UNION ALL

SELECT 
    'محافظ العملاء مع مشاكل' as metric,
    COUNT(*) as count
FROM wallets w
LEFT JOIN user_profiles up ON w.user_profile_id = up.id
WHERE w.role = 'client'
AND (
    w.user_profile_id IS NULL 
    OR w.user_id != w.user_profile_id 
    OR up.id IS NULL
    OR up.status NOT IN ('approved', 'active')
);

-- =====================================================
-- STEP 6: إنشاء محافظ للعملاء بدون محافظ (إذا لزم الأمر)
-- =====================================================

SELECT 
    '=== إنشاء محافظ للعملاء بدون محافظ ===' as section;

-- البحث عن العملاء بدون محافظ
SELECT 
    up.id,
    up.name,
    up.email,
    up.role,
    up.status
FROM user_profiles up
LEFT JOIN wallets w ON up.id = w.user_id AND w.role = 'client'
WHERE (up.role = 'client' OR up.role = 'عميل')
AND (up.status = 'approved' OR up.status = 'active')
AND w.id IS NULL;

-- إنشاء محافظ للعملاء بدون محافظ
INSERT INTO wallets (user_id, user_profile_id, role, balance, currency, status)
SELECT 
    up.id,
    up.id,
    'client',
    0.00,
    'EGP',
    'active'
FROM user_profiles up
LEFT JOIN wallets w ON up.id = w.user_id AND w.role = 'client'
WHERE (up.role = 'client' OR up.role = 'عميل')
AND (up.status = 'approved' OR up.status = 'active')
AND w.id IS NULL;

-- عرض النتائج
SELECT 
    'تم إنشاء محافظ جديدة' as result,
    ROW_COUNT() as created_count;

-- =====================================================
-- STEP 7: التحقق النهائي من جميع العملاء
-- =====================================================

SELECT 
    '=== التحقق النهائي من جميع العملاء ===' as section;

-- عرض جميع العملاء ومحافظهم
SELECT 
    up.id as user_id,
    up.name,
    up.email,
    up.role as user_role,
    up.status as user_status,
    w.id as wallet_id,
    w.balance,
    w.currency,
    w.status as wallet_status,
    CASE 
        WHEN w.id IS NOT NULL THEN '✅ لديه محفظة'
        ELSE '❌ بدون محفظة'
    END as wallet_status_text
FROM user_profiles up
LEFT JOIN wallets w ON up.id = w.user_id AND w.role = 'client'
WHERE (up.role = 'client' OR up.role = 'عميل')
AND (up.status = 'approved' OR up.status = 'active')
ORDER BY up.name;

-- إحصائية نهائية
SELECT 
    '=== الإحصائية النهائية ===' as final_section;

SELECT 
    COUNT(DISTINCT up.id) as total_active_clients,
    COUNT(DISTINCT w.id) as clients_with_wallets,
    CASE 
        WHEN COUNT(DISTINCT up.id) = COUNT(DISTINCT w.id) THEN '✅ جميع العملاء لديهم محافظ'
        ELSE '❌ بعض العملاء بدون محافظ'
    END as status
FROM user_profiles up
LEFT JOIN wallets w ON up.id = w.user_id AND w.role = 'client'
WHERE (up.role = 'client' OR up.role = 'عميل')
AND (up.status = 'approved' OR up.status = 'active');
