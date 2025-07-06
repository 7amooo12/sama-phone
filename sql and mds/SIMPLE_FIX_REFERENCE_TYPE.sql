-- =====================================================
-- إصلاح بسيط وآمن لقيد reference_type
-- Simple and safe fix for reference_type constraint
-- =====================================================

-- ⚠️ تشغيل خطوة بخطوة - لا تشغل الكل مرة واحدة
-- ⚠️ Run step by step - do not run all at once

-- الخطوة 1: إنشاء نسخة احتياطية (مهم جداً!)
-- Step 1: Create backup (very important!)
CREATE TABLE wallet_transactions_backup AS 
SELECT * FROM public.wallet_transactions;

-- الخطوة 2: فحص القيم الموجودة
-- Step 2: Check existing values
SELECT 
    reference_type,
    COUNT(*) as count
FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL
GROUP BY reference_type
ORDER BY count DESC;

-- الخطوة 3: إزالة القيد المشكل
-- Step 3: Remove problematic constraint
ALTER TABLE public.wallet_transactions 
DROP CONSTRAINT IF EXISTS wallet_transactions_reference_type_valid;

-- الخطوة 4: تنظيف القيم - wallet_topup
-- Step 4: Clean values - wallet_topup
UPDATE public.wallet_transactions 
SET reference_type = 'wallet_topup'
WHERE reference_type IN ('top_up', 'topup', 'deposit');

-- الخطوة 5: تنظيف القيم - wallet_withdrawal
-- Step 5: Clean values - wallet_withdrawal
UPDATE public.wallet_transactions 
SET reference_type = 'wallet_withdrawal'
WHERE reference_type IN ('withdrawal', 'withdraw');

-- الخطوة 6: تنظيف القيم - electronic_payment
-- Step 6: Clean values - electronic_payment
UPDATE public.wallet_transactions 
SET reference_type = 'electronic_payment'
WHERE reference_type IN ('payment', 'e_payment');

-- الخطوة 7: تنظيف القيم - order
-- Step 7: Clean values - order
UPDATE public.wallet_transactions 
SET reference_type = 'order'
WHERE reference_type IN ('order_payment', 'purchase');

-- الخطوة 8: معالجة القيم غير المعروفة
-- Step 8: Handle unknown values
UPDATE public.wallet_transactions 
SET reference_type = 'adjustment'
WHERE reference_type IS NOT NULL 
AND reference_type NOT IN (
    'order', 'refund', 'adjustment', 'transfer', 
    'electronic_payment', 'wallet_topup', 'wallet_withdrawal'
);

-- الخطوة 9: التحقق من النتائج بعد التنظيف
-- Step 9: Verify results after cleanup
SELECT 
    reference_type,
    COUNT(*) as count
FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL
GROUP BY reference_type
ORDER BY count DESC;

-- الخطوة 10: إضافة القيد الجديد
-- Step 10: Add new constraint
ALTER TABLE public.wallet_transactions 
ADD CONSTRAINT wallet_transactions_reference_type_valid 
CHECK (reference_type IN (
    'order', 
    'refund', 
    'adjustment', 
    'transfer', 
    'electronic_payment', 
    'wallet_topup', 
    'wallet_withdrawal'
));

-- الخطوة 11: التحقق من نجاح إضافة القيد
-- Step 11: Verify constraint was added successfully
SELECT 
    conname as constraint_name
FROM pg_constraint 
WHERE conname = 'wallet_transactions_reference_type_valid';

-- الخطوة 12: اختبار بسيط للقيد
-- Step 12: Simple test for constraint
DO $$
BEGIN
    -- محاولة إدراج قيمة غير صالحة (يجب أن تفشل)
    BEGIN
        INSERT INTO public.wallet_transactions (
            id, wallet_id, transaction_type, amount, balance_after,
            description, reference_type, created_by, created_at
        ) VALUES (
            gen_random_uuid(),
            (SELECT id FROM public.wallets LIMIT 1),
            'credit', 0.01, 0.01,
            'اختبار قيمة غير صالحة', 'invalid_type',
            (SELECT user_id FROM public.wallets LIMIT 1),
            NOW()
        );
        
        RAISE EXCEPTION 'فشل الاختبار - تم قبول قيمة غير صالحة';
    EXCEPTION 
        WHEN check_violation THEN
            RAISE NOTICE 'نجح الاختبار - تم رفض القيمة غير الصالحة';
        WHEN OTHERS THEN
            RAISE NOTICE 'خطأ في الاختبار: %', SQLERRM;
    END;
END $$;

-- =====================================================
-- تقرير نهائي
-- Final Report
-- =====================================================

SELECT 'تم إصلاح قيد reference_type بنجاح' as status;

-- عرض القيم المقبولة
SELECT 
    'القيم المقبولة:' as info,
    UNNEST(ARRAY[
        'order', 
        'refund', 
        'adjustment', 
        'transfer', 
        'electronic_payment', 
        'wallet_topup', 
        'wallet_withdrawal'
    ]) as valid_values;

-- إحصائيات نهائية
SELECT 
    COUNT(*) as total_transactions,
    COUNT(DISTINCT reference_type) as unique_types,
    COUNT(CASE WHEN reference_type IS NULL THEN 1 END) as null_values
FROM public.wallet_transactions;

-- =====================================================
-- تعليمات ما بعد الإصلاح
-- Post-fix instructions
-- =====================================================

-- بعد التأكد من نجاح الإصلاح، يمكن حذف النسخة الاحتياطية:
-- After confirming the fix works, you can delete the backup:
-- DROP TABLE wallet_transactions_backup;
