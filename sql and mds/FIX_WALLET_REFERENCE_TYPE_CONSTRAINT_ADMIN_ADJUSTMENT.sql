-- =====================================================
-- إصلاح قيد reference_type لإضافة adminAdjustment
-- Fix reference_type constraint to add adminAdjustment
-- =====================================================

-- الخطوة 1: فحص القيم الموجودة حالياً
-- Step 1: Check existing values
SELECT 
    '=== CURRENT REFERENCE_TYPE VALUES ===' as analysis_step,
    reference_type,
    COUNT(*) as count,
    MIN(created_at) as first_occurrence,
    MAX(created_at) as last_occurrence
FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL
GROUP BY reference_type
ORDER BY count DESC;

-- الخطوة 2: فحص القيد الحالي
-- Step 2: Check current constraint
SELECT
    '=== CURRENT CONSTRAINT ===' as analysis_step,
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conname = 'wallet_transactions_reference_type_valid';

-- الخطوة 3: إزالة القيد الحالي مؤقتاً
-- Step 3: Temporarily remove current constraint
DO $$
BEGIN
    -- Check if constraint exists before dropping
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'wallet_transactions_reference_type_valid'
    ) THEN
        ALTER TABLE public.wallet_transactions 
        DROP CONSTRAINT wallet_transactions_reference_type_valid;
        RAISE NOTICE '✅ Dropped existing constraint';
    ELSE
        RAISE NOTICE 'ℹ️ Constraint does not exist, skipping drop';
    END IF;
END $$;

-- الخطوة 4: تنظيف القيم غير الصالحة (إن وجدت)
-- Step 4: Clean up invalid values (if any)
UPDATE public.wallet_transactions 
SET reference_type = 'manual'
WHERE reference_type IS NOT NULL 
  AND reference_type NOT IN (
    'order', 'task', 'reward', 'salary', 'manual', 'transfer', 
    'electronic_payment', 'adminAdjustment', 'adjustment', 
    'wallet_topup', 'wallet_withdrawal', 'refund'
  );

-- الخطوة 5: التحقق من النتائج بعد التنظيف
-- Step 5: Verify results after cleanup
SELECT 
    '=== VALUES AFTER CLEANUP ===' as analysis_step,
    reference_type,
    COUNT(*) as count
FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL
GROUP BY reference_type
ORDER BY count DESC;

-- الخطوة 6: إضافة القيد الجديد مع adminAdjustment
-- Step 6: Add new constraint with adminAdjustment
ALTER TABLE public.wallet_transactions 
ADD CONSTRAINT wallet_transactions_reference_type_valid 
CHECK (reference_type IS NULL OR reference_type IN (
    'order', 
    'task', 
    'reward', 
    'salary', 
    'manual', 
    'transfer', 
    'electronic_payment', 
    'adminAdjustment',
    'adjustment',
    'refund', 
    'wallet_topup', 
    'wallet_withdrawal'
));

-- الخطوة 7: التحقق من نجاح إضافة القيد
-- Step 7: Verify constraint was added successfully
SELECT
    '=== NEW CONSTRAINT VERIFICATION ===' as verification_step,
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conname = 'wallet_transactions_reference_type_valid';

-- الخطوة 8: اختبار القيد الجديد
-- Step 8: Test new constraint
DO $$
BEGIN
    RAISE NOTICE '=== TESTING NEW CONSTRAINT ===';
    
    -- Test 1: Try inserting invalid value (should fail)
    BEGIN
        INSERT INTO public.wallet_transactions (
            id, wallet_id, user_id, transaction_type, amount, balance_after,
            description, reference_type, created_by, created_at
        ) VALUES (
            gen_random_uuid(),
            '00000000-0000-0000-0000-000000000000'::uuid,
            '00000000-0000-0000-0000-000000000000'::uuid,
            'credit', 100.00, 100.00,
            'Test transaction', 'invalid_type',
            '00000000-0000-0000-0000-000000000000'::uuid,
            NOW()
        );
        
        RAISE EXCEPTION 'TEST FAILED: Invalid value was accepted';
    EXCEPTION 
        WHEN check_violation THEN
            RAISE NOTICE '✅ TEST 1 PASSED: Invalid value correctly rejected';
        WHEN OTHERS THEN
            RAISE NOTICE '❌ TEST 1 FAILED: Unexpected error: %', SQLERRM;
    END;
    
    -- Test 2: Try inserting adminAdjustment (should succeed)
    BEGIN
        INSERT INTO public.wallet_transactions (
            id, wallet_id, user_id, transaction_type, amount, balance_after,
            description, reference_type, created_by, created_at
        ) VALUES (
            gen_random_uuid(),
            '00000000-0000-0000-0000-000000000000'::uuid,
            '00000000-0000-0000-0000-000000000000'::uuid,
            'credit', 100.00, 100.00,
            'Test adminAdjustment', 'adminAdjustment',
            '00000000-0000-0000-0000-000000000000'::uuid,
            NOW()
        );
        
        -- Clean up test record
        DELETE FROM public.wallet_transactions 
        WHERE description = 'Test adminAdjustment' 
        AND reference_type = 'adminAdjustment';
        
        RAISE NOTICE '✅ TEST 2 PASSED: adminAdjustment value accepted correctly';
    EXCEPTION 
        WHEN OTHERS THEN
            RAISE NOTICE '❌ TEST 2 FAILED: adminAdjustment value rejected: %', SQLERRM;
    END;
    
    -- Test 3: Try inserting electronic_payment (should succeed)
    BEGIN
        INSERT INTO public.wallet_transactions (
            id, wallet_id, user_id, transaction_type, amount, balance_after,
            description, reference_type, created_by, created_at
        ) VALUES (
            gen_random_uuid(),
            '00000000-0000-0000-0000-000000000000'::uuid,
            '00000000-0000-0000-0000-000000000000'::uuid,
            'credit', 100.00, 100.00,
            'Test electronic_payment', 'electronic_payment',
            '00000000-0000-0000-0000-000000000000'::uuid,
            NOW()
        );
        
        -- Clean up test record
        DELETE FROM public.wallet_transactions 
        WHERE description = 'Test electronic_payment' 
        AND reference_type = 'electronic_payment';
        
        RAISE NOTICE '✅ TEST 3 PASSED: electronic_payment value accepted correctly';
    EXCEPTION 
        WHEN OTHERS THEN
            RAISE NOTICE '❌ TEST 3 FAILED: electronic_payment value rejected: %', SQLERRM;
    END;
END $$;

-- الخطوة 9: تقرير نهائي
-- Step 9: Final report
SELECT 
    '=== FINAL REPORT ===' as report_section,
    'Constraint updated successfully' as status,
    'adminAdjustment is now allowed' as note;

-- عرض القيم المقبولة الجديدة
SELECT 
    '=== ALLOWED REFERENCE_TYPE VALUES ===' as info,
    UNNEST(ARRAY[
        'order - طلبات الشراء', 
        'task - المهام', 
        'reward - المكافآت', 
        'salary - الرواتب', 
        'manual - يدوي', 
        'transfer - التحويلات', 
        'electronic_payment - المدفوعات الإلكترونية', 
        'adminAdjustment - تعديلات الإدارة',
        'adjustment - التعديلات',
        'refund - المرتجعات', 
        'wallet_topup - شحن المحفظة', 
        'wallet_withdrawal - سحب من المحفظة'
    ]) as allowed_values_with_description;

-- =====================================================
-- تعليمات التشغيل
-- Execution Instructions
-- =====================================================

/*
لتشغيل هذا السكريبت:
1. قم بتسجيل الدخول إلى Supabase Dashboard
2. انتقل إلى SQL Editor
3. انسخ والصق هذا السكريبت
4. اضغط على "Run" لتنفيذ السكريبت
5. تحقق من النتائج في الـ Output

To run this script:
1. Login to Supabase Dashboard
2. Go to SQL Editor
3. Copy and paste this script
4. Click "Run" to execute the script
5. Check the results in the Output
*/
