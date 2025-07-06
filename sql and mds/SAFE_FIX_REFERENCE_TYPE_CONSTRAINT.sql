-- =====================================================
-- إصلاح آمن لقيد reference_type - تشغيل خطوة بخطوة
-- Safe fix for reference_type constraint - Run step by step
-- =====================================================

-- ⚠️ تحذير: قم بتشغيل هذه الاستعلامات واحداً تلو الآخر
-- ⚠️ Warning: Run these queries one by one

-- الخطوة 1: فحص القيم الموجودة (للمعلومات فقط)
-- Step 1: Check existing values (information only)
SELECT 
    'الخطوة 1: فحص القيم الموجودة' as step,
    reference_type,
    COUNT(*) as count
FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL
GROUP BY reference_type
ORDER BY count DESC;

-- الخطوة 2: إزالة القيد الحالي
-- Step 2: Remove current constraint
ALTER TABLE public.wallet_transactions 
DROP CONSTRAINT IF EXISTS wallet_transactions_reference_type_valid;

-- تأكيد إزالة القيد
SELECT 'الخطوة 2: تم إزالة القيد' as step, 'مكتمل' as status;

-- الخطوة 3: تنظيف القيم - الجزء الأول
-- Step 3: Clean values - Part 1
UPDATE public.wallet_transactions
SET reference_type = 'wallet_topup'
WHERE reference_type IN ('top_up', 'topup', 'deposit');

-- الخطوة 4: تنظيف القيم - الجزء الثاني
-- Step 4: Clean values - Part 2
UPDATE public.wallet_transactions
SET reference_type = 'wallet_withdrawal'
WHERE reference_type IN ('withdrawal', 'withdraw');

-- الخطوة 5: تنظيف القيم - الجزء الثالث
-- Step 5: Clean values - Part 3
UPDATE public.wallet_transactions
SET reference_type = 'electronic_payment'
WHERE reference_type IN ('payment', 'e_payment');

-- الخطوة 6: تنظيف القيم - الجزء الرابع
-- Step 6: Clean values - Part 4
UPDATE public.wallet_transactions
SET reference_type = 'order'
WHERE reference_type IN ('order_payment', 'purchase');

-- الخطوة 7: معالجة القيم غير المعروفة
-- Step 7: Handle unknown values
UPDATE public.wallet_transactions
SET reference_type = 'adjustment'
WHERE reference_type IS NOT NULL
AND reference_type NOT IN (
    'order', 'refund', 'adjustment', 'transfer',
    'electronic_payment', 'wallet_topup', 'wallet_withdrawal'
);

-- الخطوة 8: التحقق من النتائج النهائية
-- Step 8: Verify final results
SELECT 
    'الخطوة 8: التحقق النهائي' as step,
    reference_type,
    COUNT(*) as count
FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL
GROUP BY reference_type
ORDER BY count DESC;

-- الخطوة 9: إضافة القيد الجديد
-- Step 9: Add new constraint
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

SELECT 'الخطوة 9: تم إضافة القيد الجديد' as step, 'مكتمل' as status;

-- الخطوة 10: التحقق من نجاح إضافة القيد
-- Step 10: Verify constraint was added successfully
SELECT 
    'الخطوة 10: التحقق من القيد' as step,
    conname as constraint_name,
    'موجود' as status
FROM pg_constraint 
WHERE conname = 'wallet_transactions_reference_type_valid';

-- =====================================================
-- اختبار نهائي (اختياري)
-- Final test (optional)
-- =====================================================

-- اختبار إدراج قيمة صالحة
DO $$
DECLARE
    test_wallet_id UUID;
    test_user_id UUID;
BEGIN
    -- الحصول على wallet_id صالح للاختبار
    SELECT id INTO test_wallet_id 
    FROM public.wallets 
    WHERE is_active = true 
    LIMIT 1;
    
    -- الحصول على user_id صالح للاختبار
    SELECT user_id INTO test_user_id 
    FROM public.wallets 
    WHERE id = test_wallet_id;
    
    IF test_wallet_id IS NOT NULL AND test_user_id IS NOT NULL THEN
        -- اختبار إدراج قيمة صالحة
        INSERT INTO public.wallet_transactions (
            wallet_id, transaction_type, amount, balance_after,
            description, reference_type, created_by, created_at
        ) VALUES (
            test_wallet_id,
            'credit', 0.01, 0.01,
            'اختبار القيد - سيتم حذفه', 'electronic_payment',
            test_user_id,
            NOW()
        );
        
        -- حذف السجل التجريبي فوراً
        DELETE FROM public.wallet_transactions 
        WHERE description = 'اختبار القيد - سيتم حذفه';
        
        RAISE NOTICE 'نجح الاختبار: القيد يعمل بشكل صحيح';
    ELSE
        RAISE NOTICE 'تم تخطي الاختبار: لا توجد محافظ متاحة';
    END IF;
    
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'فشل الاختبار: %', SQLERRM;
END $$;

-- =====================================================
-- تقرير نهائي
-- Final Report
-- =====================================================

SELECT 
    '=== تقرير نهائي ===' as report,
    'تم إصلاح قيد reference_type بنجاح' as status,
    'يمكن الآن استخدام المدفوعات الإلكترونية' as note;

-- عرض القيم المقبولة
SELECT 
    'القيم المقبولة في reference_type:' as info,
    UNNEST(ARRAY[
        'order - طلبات الشراء', 
        'refund - المرتجعات', 
        'adjustment - التعديلات', 
        'transfer - التحويلات', 
        'electronic_payment - المدفوعات الإلكترونية', 
        'wallet_topup - شحن المحفظة', 
        'wallet_withdrawal - سحب من المحفظة'
    ]) as valid_values_with_description;
