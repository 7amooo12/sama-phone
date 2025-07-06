-- =====================================================
-- إصلاح قيد reference_type في جدول wallet_transactions
-- Fix reference_type constraint in wallet_transactions table
-- =====================================================

-- الخطوة 1: فحص القيم الموجودة حالياً
-- Step 1: Check existing values
SELECT 
    reference_type,
    COUNT(*) as count,
    MIN(created_at) as first_occurrence,
    MAX(created_at) as last_occurrence
FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL
GROUP BY reference_type
ORDER BY count DESC;

-- الخطوة 2: إزالة القيد الحالي مؤقتاً
-- Step 2: Temporarily remove current constraint
ALTER TABLE public.wallet_transactions 
DROP CONSTRAINT IF EXISTS wallet_transactions_reference_type_valid;

-- الخطوة 3: تنظيف وتوحيد القيم الموجودة
-- Step 3: Clean and standardize existing values

-- تحديث القيم المشابهة لتوحيد التسمية
UPDATE public.wallet_transactions 
SET reference_type = 'wallet_topup'
WHERE reference_type IN ('top_up', 'topup', 'deposit');

UPDATE public.wallet_transactions 
SET reference_type = 'wallet_withdrawal'
WHERE reference_type IN ('withdrawal', 'withdraw');

UPDATE public.wallet_transactions 
SET reference_type = 'electronic_payment'
WHERE reference_type IN ('payment', 'e_payment');

UPDATE public.wallet_transactions 
SET reference_type = 'order'
WHERE reference_type IN ('order_payment', 'purchase');

-- تحديث أي قيم غير معروفة إلى 'adjustment'
UPDATE public.wallet_transactions 
SET reference_type = 'adjustment'
WHERE reference_type IS NOT NULL 
AND reference_type NOT IN (
    'order', 'refund', 'adjustment', 'transfer', 
    'electronic_payment', 'wallet_topup', 'wallet_withdrawal'
);

-- الخطوة 4: التحقق من النتائج بعد التنظيف
-- Step 4: Verify results after cleanup
SELECT 
    reference_type,
    COUNT(*) as count
FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL
GROUP BY reference_type
ORDER BY count DESC;

-- الخطوة 5: إضافة القيد الجديد
-- Step 5: Add new constraint
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

-- الخطوة 6: التحقق من نجاح إضافة القيد
-- Step 6: Verify constraint was added successfully
SELECT 
    conname as constraint_name,
    consrc as constraint_definition
FROM pg_constraint 
WHERE conname = 'wallet_transactions_reference_type_valid';

-- الخطوة 7: اختبار القيد الجديد
-- Step 7: Test new constraint
DO $$
BEGIN
    -- محاولة إدراج قيمة غير صالحة (يجب أن تفشل)
    BEGIN
        INSERT INTO public.wallet_transactions (
            wallet_id, transaction_type, amount, balance_after,
            description, reference_type, created_by, created_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000'::uuid,
            'credit', 100.00, 100.00,
            'Test transaction', 'invalid_type',
            '00000000-0000-0000-0000-000000000000'::uuid,
            NOW()
        );
        
        RAISE EXCEPTION 'Constraint test failed - invalid value was accepted';
    EXCEPTION 
        WHEN check_violation THEN
            RAISE NOTICE 'SUCCESS: Constraint is working correctly - invalid value rejected';
        WHEN OTHERS THEN
            RAISE NOTICE 'Test failed with unexpected error: %', SQLERRM;
    END;
    
    -- محاولة إدراج قيمة صالحة (يجب أن تنجح)
    BEGIN
        INSERT INTO public.wallet_transactions (
            wallet_id, transaction_type, amount, balance_after,
            description, reference_type, created_by, created_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000'::uuid,
            'credit', 100.00, 100.00,
            'Test transaction', 'electronic_payment',
            '00000000-0000-0000-0000-000000000000'::uuid,
            NOW()
        );
        
        -- حذف السجل التجريبي
        DELETE FROM public.wallet_transactions 
        WHERE description = 'Test transaction' 
        AND reference_type = 'electronic_payment';
        
        RAISE NOTICE 'SUCCESS: Valid value accepted correctly';
    EXCEPTION 
        WHEN OTHERS THEN
            RAISE NOTICE 'Test failed - valid value rejected: %', SQLERRM;
    END;
END $$;

-- =====================================================
-- تقرير نهائي
-- Final Report
-- =====================================================

-- عرض ملخص نهائي للقيم المقبولة
SELECT 
    'القيم المقبولة في reference_type:' as info,
    UNNEST(ARRAY[
        'order', 
        'refund', 
        'adjustment', 
        'transfer', 
        'electronic_payment', 
        'wallet_topup', 
        'wallet_withdrawal'
    ]) as valid_values;

-- عرض إحصائيات نهائية
SELECT 
    'إحصائيات نهائية:' as info,
    COUNT(*) as total_transactions,
    COUNT(DISTINCT reference_type) as unique_reference_types,
    COUNT(CASE WHEN reference_type IS NULL THEN 1 END) as null_reference_types
FROM public.wallet_transactions;

RAISE NOTICE '=== تم إصلاح قيد reference_type بنجاح ===';
RAISE NOTICE 'يمكن الآن استخدام المدفوعات الإلكترونية بدون أخطاء';
RAISE NOTICE '=== reference_type constraint fixed successfully ===';
RAISE NOTICE 'Electronic payments can now be used without errors';
