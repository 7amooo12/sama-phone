-- =====================================================
-- تنظيف المحافظ المكررة في قاعدة البيانات
-- Cleanup Duplicate Wallets in Database
-- =====================================================

-- ⚠️ تحذير: قم بإنشاء نسخة احتياطية قبل تشغيل هذا السكريپت
-- ⚠️ Warning: Create a backup before running this script

-- بدء المعاملة لضمان الأمان
BEGIN;

-- الخطوة 1: إنشاء نسخة احتياطية من جدول wallets
-- Step 1: Create backup of wallets table
DROP TABLE IF EXISTS wallets_backup;
CREATE TABLE wallets_backup AS
SELECT * FROM public.wallets;

-- تأكيد إنشاء النسخة الاحتياطية
DO $$
DECLARE
    backup_count INTEGER;
    original_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO backup_count FROM wallets_backup;
    SELECT COUNT(*) INTO original_count FROM public.wallets;

    IF backup_count = original_count THEN
        RAISE NOTICE 'تم إنشاء نسخة احتياطية بنجاح: % سجل', backup_count;
        RAISE NOTICE 'Backup created successfully: % records', backup_count;
    ELSE
        RAISE EXCEPTION 'فشل في إنشاء النسخة الاحتياطية - Backup creation failed';
    END IF;
END $$;

-- الخطوة 2: فحص المحافظ المكررة
-- Step 2: Check for duplicate wallets
DO $$
DECLARE
    duplicate_count INTEGER;
    rec RECORD;
BEGIN
    -- عد المحافظ المكررة
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT user_id, wallet_type
        FROM public.wallets
        WHERE is_active = true
        GROUP BY user_id, wallet_type
        HAVING COUNT(*) > 1
    ) duplicates;

    RAISE NOTICE 'عدد المستخدمين مع محافظ مكررة: %', duplicate_count;
    RAISE NOTICE 'Number of users with duplicate wallets: %', duplicate_count;

    -- عرض تفاصيل المحافظ المكررة
    IF duplicate_count > 0 THEN
        RAISE NOTICE 'تفاصيل المحافظ المكررة:';
        RAISE NOTICE 'Duplicate wallet details:';

        FOR rec IN
            SELECT
                user_id,
                wallet_type,
                COUNT(*) as wallet_count,
                STRING_AGG(id::text, ', ') as wallet_ids,
                STRING_AGG(balance::text, ', ') as balances
            FROM public.wallets
            WHERE is_active = true
            GROUP BY user_id, wallet_type
            HAVING COUNT(*) > 1
            ORDER BY COUNT(*) DESC
            LIMIT 10
        LOOP
            RAISE NOTICE 'User: %, Type: %, Count: %, IDs: %, Balances: %',
                rec.user_id, rec.wallet_type, rec.wallet_count, rec.wallet_ids, rec.balances;
        END LOOP;
    END IF;
END $$;

-- الخطوة 3: تحديد المحافظ التي يجب الاحتفاظ بها (الأحدث مع أعلى رصيد)
-- Step 3: Identify wallets to keep (newest with highest balance)
WITH duplicate_wallets AS (
    SELECT 
        user_id,
        wallet_type,
        id,
        balance,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY user_id, wallet_type 
            ORDER BY balance DESC, created_at DESC
        ) as rn
    FROM public.wallets 
    WHERE is_active = true
),
wallets_to_remove AS (
    SELECT 
        user_id,
        wallet_type,
        id,
        balance,
        created_at
    FROM duplicate_wallets 
    WHERE rn > 1
)
SELECT 
    'المحافظ التي سيتم إزالتها:' as info,
    user_id,
    wallet_type,
    id,
    balance,
    created_at
FROM wallets_to_remove
ORDER BY user_id, wallet_type;

-- الخطوة 4: دمج الأرصدة من المحافظ المكررة
-- Step 4: Merge balances from duplicate wallets
WITH duplicate_wallets AS (
    SELECT
        user_id,
        wallet_type,
        id,
        balance,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY user_id, wallet_type
            ORDER BY balance DESC, created_at DESC
        ) as rn
    FROM public.wallets
    WHERE is_active = true
),
wallets_to_keep AS (
    -- تحديد المحافظ التي سيتم الاحتفاظ بها (الأولى في كل مجموعة)
    SELECT
        user_id,
        wallet_type,
        id as keep_wallet_id
    FROM duplicate_wallets
    WHERE rn = 1
    AND user_id IN (
        SELECT user_id
        FROM duplicate_wallets
        GROUP BY user_id, wallet_type
        HAVING COUNT(*) > 1
    )
),
balance_totals AS (
    -- حساب إجمالي الرصيد لكل مجموعة محافظ مكررة
    SELECT
        user_id,
        wallet_type,
        SUM(balance) as total_balance
    FROM duplicate_wallets
    WHERE user_id IN (
        SELECT user_id
        FROM duplicate_wallets
        GROUP BY user_id, wallet_type
        HAVING COUNT(*) > 1
    )
    GROUP BY user_id, wallet_type
),
final_updates AS (
    -- دمج معرف المحفظة المحتفظ بها مع إجمالي الرصيد
    SELECT
        wtk.keep_wallet_id,
        bt.total_balance
    FROM wallets_to_keep wtk
    JOIN balance_totals bt ON wtk.user_id = bt.user_id AND wtk.wallet_type = bt.wallet_type
)
UPDATE public.wallets
SET balance = final_updates.total_balance,
    updated_at = NOW()
FROM final_updates
WHERE wallets.id = final_updates.keep_wallet_id;

-- الخطوة 5: تحديث معاملات المحافظ للإشارة إلى المحفظة المحتفظ بها
-- Step 5: Update wallet transactions to reference the kept wallet
WITH duplicate_wallets AS (
    SELECT 
        user_id,
        wallet_type,
        id,
        balance,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY user_id, wallet_type 
            ORDER BY balance DESC, created_at DESC
        ) as rn
    FROM public.wallets 
    WHERE is_active = true
),
wallet_mapping AS (
    SELECT 
        user_id,
        wallet_type,
        id as old_wallet_id,
        FIRST_VALUE(id) OVER (
            PARTITION BY user_id, wallet_type 
            ORDER BY balance DESC, created_at DESC
        ) as new_wallet_id
    FROM duplicate_wallets
    WHERE user_id IN (
        SELECT user_id 
        FROM duplicate_wallets 
        GROUP BY user_id, wallet_type 
        HAVING COUNT(*) > 1
    )
)
UPDATE public.wallet_transactions 
SET wallet_id = wallet_mapping.new_wallet_id
FROM wallet_mapping
WHERE wallet_transactions.wallet_id = wallet_mapping.old_wallet_id
AND wallet_mapping.old_wallet_id != wallet_mapping.new_wallet_id;

-- الخطوة 6: إزالة المحافظ المكررة (الاحتفاظ بالأحدث مع أعلى رصيد)
-- Step 6: Remove duplicate wallets (keep newest with highest balance)
WITH duplicate_wallets AS (
    SELECT 
        user_id,
        wallet_type,
        id,
        balance,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY user_id, wallet_type 
            ORDER BY balance DESC, created_at DESC
        ) as rn
    FROM public.wallets 
    WHERE is_active = true
)
DELETE FROM public.wallets 
WHERE id IN (
    SELECT id 
    FROM duplicate_wallets 
    WHERE rn > 1
);

-- الخطوة 7: التحقق من النتائج
-- Step 7: Verify results
DO $$
DECLARE
    remaining_duplicates INTEGER;
BEGIN
    -- فحص المحافظ المكررة المتبقية
    SELECT COUNT(*) INTO remaining_duplicates
    FROM (
        SELECT user_id, wallet_type
        FROM public.wallets
        WHERE is_active = true
        GROUP BY user_id, wallet_type
        HAVING COUNT(*) > 1
    ) duplicates;

    IF remaining_duplicates = 0 THEN
        RAISE NOTICE '✅ تم تنظيف جميع المحافظ المكررة بنجاح';
        RAISE NOTICE '✅ All duplicate wallets cleaned successfully';
    ELSE
        RAISE WARNING '⚠️ لا تزال هناك % محافظ مكررة', remaining_duplicates;
        RAISE WARNING '⚠️ Still % duplicate wallets remaining', remaining_duplicates;
    END IF;
END $$;

-- الخطوة 8: إضافة قيد فريد لمنع التكرار في المستقبل
-- Step 8: Add unique constraint to prevent future duplicates
ALTER TABLE public.wallets 
DROP CONSTRAINT IF EXISTS unique_user_wallet_type;

ALTER TABLE public.wallets 
ADD CONSTRAINT unique_user_wallet_type 
UNIQUE (user_id, wallet_type, is_active) 
DEFERRABLE INITIALLY DEFERRED;

-- الخطوة 9: إنشاء فهرس لتحسين الأداء
-- Step 9: Create index for performance
CREATE INDEX IF NOT EXISTS idx_wallets_user_wallet_type_active 
ON public.wallets(user_id, wallet_type, is_active) 
WHERE is_active = true;

-- الخطوة 10: تحديث إحصائيات الجدول
-- Step 10: Update table statistics
ANALYZE public.wallets;
ANALYZE public.wallet_transactions;

-- =====================================================
-- تقرير نهائي
-- Final Report
-- =====================================================

-- عرض ملخص المحافظ النهائي
DO $$
DECLARE
    rec RECORD;
    total_wallets INTEGER;
    total_users INTEGER;
    total_balance NUMERIC;
BEGIN
    RAISE NOTICE '=== ملخص المحافظ النهائي ===';
    RAISE NOTICE '=== Final Wallets Summary ===';

    -- إحصائيات عامة
    SELECT COUNT(*), COUNT(DISTINCT user_id), SUM(balance)
    INTO total_wallets, total_users, total_balance
    FROM public.wallets
    WHERE is_active = true;

    RAISE NOTICE 'إجمالي المحافظ النشطة: %', total_wallets;
    RAISE NOTICE 'إجمالي المستخدمين: %', total_users;
    RAISE NOTICE 'إجمالي الرصيد: % ج.م', total_balance;
    RAISE NOTICE 'Total active wallets: %', total_wallets;
    RAISE NOTICE 'Total users: %', total_users;
    RAISE NOTICE 'Total balance: % EGP', total_balance;

    -- تفاصيل حسب نوع المحفظة
    RAISE NOTICE '--- تفاصيل حسب نوع المحفظة ---';
    RAISE NOTICE '--- Details by wallet type ---';

    FOR rec IN
        SELECT
            wallet_type,
            COUNT(*) as total_wallets,
            COUNT(DISTINCT user_id) as unique_users,
            SUM(balance) as total_balance
        FROM public.wallets
        WHERE is_active = true
        GROUP BY wallet_type
        ORDER BY wallet_type
    LOOP
        RAISE NOTICE 'نوع: %, محافظ: %, مستخدمين: %, رصيد: %',
            rec.wallet_type, rec.total_wallets, rec.unique_users, rec.total_balance;
    END LOOP;
END $$;

-- =====================================================
-- تعليمات ما بعد التنظيف
-- Post-cleanup instructions
-- =====================================================

-- بعد التأكد من نجاح التنظيف، يمكن حذف النسخة الاحتياطية:
-- After confirming successful cleanup, you can delete the backup:
-- DROP TABLE wallets_backup;

-- للتحقق من عمل النظام:
-- To verify system functionality:
-- 1. اختبر تسجيل الدخول للعملاء
-- 2. اختبر عرض أرصدة المحافظ
-- 3. اختبر المدفوعات الإلكترونية
-- 4. تأكد من عدم ظهور أخطاء "multiple rows returned"

-- إظهار رسائل النجاح والتأكيد النهائي
DO $$
DECLARE
    final_duplicate_count INTEGER;
BEGIN
    -- فحص نهائي للمحافظ المكررة
    SELECT COUNT(*) INTO final_duplicate_count
    FROM (
        SELECT user_id, wallet_type
        FROM public.wallets
        WHERE is_active = true
        GROUP BY user_id, wallet_type
        HAVING COUNT(*) > 1
    ) duplicates;

    IF final_duplicate_count = 0 THEN
        RAISE NOTICE '🎉 === تم تنظيف المحافظ المكررة بنجاح ===';
        RAISE NOTICE '✅ لا توجد محافظ مكررة متبقية';
        RAISE NOTICE '📱 يرجى اختبار النظام للتأكد من عمل المدفوعات الإلكترونية';
        RAISE NOTICE '';
        RAISE NOTICE '🎉 === Duplicate wallets cleanup completed successfully ===';
        RAISE NOTICE '✅ No duplicate wallets remaining';
        RAISE NOTICE '📱 Please test the system to ensure electronic payments work correctly';
    ELSE
        RAISE WARNING '⚠️ لا تزال هناك % محافظ مكررة - يرجى مراجعة السكريپت', final_duplicate_count;
        RAISE WARNING '⚠️ Still % duplicate wallets remaining - please review the script', final_duplicate_count;
    END IF;
END $$;

-- تأكيد المعاملة
COMMIT;

-- رسالة تأكيد نهائية
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== تم تطبيق جميع التغييرات بنجاح ===';
    RAISE NOTICE '=== All changes applied successfully ===';
    RAISE NOTICE '';
END $$;
