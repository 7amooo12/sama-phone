-- =====================================================
-- إصلاح مشكلة عدم تطابق أدوار المحافظ مع أدوار المستخدمين
-- Fix Wallet Role Mismatch Issue
-- =====================================================

-- ⚠️ تحذير: قم بإنشاء نسخة احتياطية قبل تشغيل هذا السكريپت
-- ⚠️ Warning: Create a backup before running this script

BEGIN;

-- الخطوة 1: فحص البيانات الحالية وتحديد المشاكل
-- Step 1: Examine current data and identify issues

-- إنشاء جدول مؤقت لتحليل المشاكل
CREATE TEMP TABLE wallet_role_analysis AS
SELECT 
    up.id as user_id,
    up.name as user_name,
    up.email as user_email,
    up.role as user_profile_role,
    up.status as user_status,
    w.id as wallet_id,
    w.role as wallet_role,
    w.balance as wallet_balance,
    w.status as wallet_status,
    CASE 
        WHEN up.role != w.role THEN 'ROLE_MISMATCH'
        WHEN up.role = w.role THEN 'CORRECT'
        WHEN w.id IS NULL THEN 'NO_WALLET'
        ELSE 'UNKNOWN'
    END as issue_type
FROM public.user_profiles up
LEFT JOIN public.wallets w ON up.id = w.user_id
WHERE up.status = 'approved';

-- عرض تحليل المشاكل
SELECT 
    '=== تحليل مشاكل أدوار المحافظ ===' as analysis_title;

SELECT 
    issue_type,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM wallet_role_analysis
GROUP BY issue_type
ORDER BY count DESC;

-- عرض المستخدمين الذين لديهم عدم تطابق في الأدوار
SELECT 
    '=== المستخدمون الذين لديهم عدم تطابق في الأدوار ===' as mismatch_title;

SELECT 
    user_name,
    user_email,
    user_profile_role,
    wallet_role,
    wallet_balance
FROM wallet_role_analysis
WHERE issue_type = 'ROLE_MISMATCH'
ORDER BY user_profile_role, user_name;

-- الخطوة 2: إصلاح عدم تطابق الأدوار
-- Step 2: Fix role mismatches

-- إنشاء نسخة احتياطية من جدول المحافظ
CREATE TABLE IF NOT EXISTS wallets_backup_role_fix AS
SELECT 
    *,
    NOW() as backup_timestamp,
    'role_mismatch_fix' as backup_reason
FROM public.wallets;

-- تحديث أدوار المحافظ لتتطابق مع أدوار المستخدمين
UPDATE public.wallets 
SET 
    role = (
        SELECT up.role 
        FROM public.user_profiles up 
        WHERE up.id = wallets.user_id
    ),
    updated_at = NOW()
WHERE EXISTS (
    SELECT 1 
    FROM public.user_profiles up 
    WHERE up.id = wallets.user_id 
    AND up.role != wallets.role
    AND up.status = 'approved'
);

-- الخطوة 3: إنشاء محافظ للمستخدمين الذين ليس لديهم محافظ
-- Step 3: Create wallets for users who don't have wallets

INSERT INTO public.wallets (user_id, role, balance, currency, status, created_at, updated_at)
SELECT 
    up.id,
    up.role,
    CASE 
        WHEN up.role = 'admin' THEN 10000.00
        WHEN up.role = 'owner' THEN 5000.00
        WHEN up.role = 'accountant' THEN 1000.00
        WHEN up.role = 'worker' THEN 500.00
        WHEN up.role = 'client' THEN 100.00
        WHEN up.role = 'warehouseManager' THEN 1000.00
        ELSE 0.00
    END as initial_balance,
    'EGP',
    'active',
    NOW(),
    NOW()
FROM public.user_profiles up
WHERE up.status = 'approved' 
    AND NOT EXISTS (
        SELECT 1 FROM public.wallets w 
        WHERE w.user_id = up.id
    );

-- الخطوة 4: التحقق من النتائج بعد الإصلاح
-- Step 4: Verify results after fix

-- إعادة تحليل البيانات بعد الإصلاح
DROP TABLE IF EXISTS wallet_role_analysis;
CREATE TEMP TABLE wallet_role_analysis AS
SELECT 
    up.id as user_id,
    up.name as user_name,
    up.email as user_email,
    up.role as user_profile_role,
    up.status as user_status,
    w.id as wallet_id,
    w.role as wallet_role,
    w.balance as wallet_balance,
    w.status as wallet_status,
    CASE 
        WHEN up.role != w.role THEN 'ROLE_MISMATCH'
        WHEN up.role = w.role THEN 'CORRECT'
        WHEN w.id IS NULL THEN 'NO_WALLET'
        ELSE 'UNKNOWN'
    END as issue_type
FROM public.user_profiles up
LEFT JOIN public.wallets w ON up.id = w.user_id
WHERE up.status = 'approved';

-- عرض النتائج بعد الإصلاح
SELECT 
    '=== النتائج بعد الإصلاح ===' as results_title;

SELECT 
    issue_type,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM wallet_role_analysis
GROUP BY issue_type
ORDER BY count DESC;

-- عرض إحصائيات المحافظ حسب الدور
SELECT 
    '=== إحصائيات المحافظ حسب الدور ===' as stats_title;

SELECT 
    w.role,
    COUNT(*) as wallet_count,
    SUM(w.balance) as total_balance,
    AVG(w.balance) as average_balance,
    MIN(w.balance) as min_balance,
    MAX(w.balance) as max_balance
FROM public.wallets w
JOIN public.user_profiles up ON w.user_id = up.id
WHERE up.status = 'approved'
GROUP BY w.role
ORDER BY wallet_count DESC;

-- الخطوة 5: إنشاء دالة للتحقق من تطابق الأدوار
-- Step 5: Create function to validate role consistency

CREATE OR REPLACE FUNCTION validate_wallet_role_consistency()
RETURNS TABLE(
    user_id UUID,
    user_name TEXT,
    user_email TEXT,
    user_role TEXT,
    wallet_role TEXT,
    issue_description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.id,
        up.name,
        up.email,
        up.role,
        w.role,
        CASE 
            WHEN w.id IS NULL THEN 'لا توجد محفظة للمستخدم'
            WHEN up.role != w.role THEN 'عدم تطابق دور المحفظة مع دور المستخدم'
            ELSE 'صحيح'
        END
    FROM public.user_profiles up
    LEFT JOIN public.wallets w ON up.id = w.user_id
    WHERE up.status = 'approved'
    AND (w.id IS NULL OR up.role != w.role);
END;
$$ LANGUAGE plpgsql;

-- الخطوة 6: إنشاء trigger لمنع عدم تطابق الأدوار في المستقبل
-- Step 6: Create trigger to prevent future role mismatches

CREATE OR REPLACE FUNCTION ensure_wallet_role_consistency()
RETURNS TRIGGER AS $$
BEGIN
    -- عند إنشاء محفظة جديدة، تأكد من أن الدور يتطابق مع دور المستخدم
    IF TG_OP = 'INSERT' THEN
        NEW.role := (
            SELECT up.role 
            FROM public.user_profiles up 
            WHERE up.id = NEW.user_id
        );
    END IF;
    
    -- عند تحديث دور المستخدم، تحديث دور المحفظة أيضاً
    IF TG_OP = 'UPDATE' AND TG_TABLE_NAME = 'user_profiles' THEN
        UPDATE public.wallets 
        SET role = NEW.role, updated_at = NOW()
        WHERE user_id = NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء triggers
DROP TRIGGER IF EXISTS trigger_ensure_wallet_role_consistency ON public.wallets;
CREATE TRIGGER trigger_ensure_wallet_role_consistency
    BEFORE INSERT ON public.wallets
    FOR EACH ROW
    EXECUTE FUNCTION ensure_wallet_role_consistency();

DROP TRIGGER IF EXISTS trigger_update_wallet_role_on_user_role_change ON public.user_profiles;
CREATE TRIGGER trigger_update_wallet_role_on_user_role_change
    AFTER UPDATE OF role ON public.user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION ensure_wallet_role_consistency();

-- الخطوة 7: التحقق النهائي
-- Step 7: Final verification

SELECT 
    '=== التحقق النهائي من تطابق الأدوار ===' as final_check_title;

SELECT * FROM validate_wallet_role_consistency();

-- عرض رسالة النجاح
SELECT 
    '✅ تم إصلاح مشكلة عدم تطابق أدوار المحافظ بنجاح' as success_message,
    'يجب الآن أن تظهر محافظ العملاء والعمال في الأقسام الصحيحة' as result_message;

COMMIT;

-- =====================================================
-- إصلاح مشكلة أدوار المحافظ مكتمل
-- Wallet Role Mismatch Fix Complete
-- =====================================================
