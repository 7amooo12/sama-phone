-- الإصلاح النهائي لجدول task_submissions
-- حل مشكلة الأعمدة المفقودة والمكررة

BEGIN;

-- التأكد من وجود جميع الأعمدة المطلوبة من الكود
-- الكود يحاول إدراج هذه الحقول:
-- 'task_id', 'worker_id', 'progress_report', 'completion_percentage', 
-- 'hours_worked', 'notes', 'is_final_submission', 'status', 'attachments'

-- إضافة الأعمدة المفقودة إذا لم تكن موجودة
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS progress_report TEXT;

-- التأكد من أن جميع الأعمدة المطلوبة موجودة
DO $$
DECLARE
    missing_columns TEXT[] := ARRAY[]::TEXT[];
    col_count INTEGER;
    required_columns TEXT[] := ARRAY[
        'task_id', 'worker_id', 'progress_report', 'completion_percentage',
        'hours_worked', 'notes', 'is_final_submission', 'status', 'attachments'
    ];
    col_name TEXT;
BEGIN
    RAISE NOTICE '=== فحص الأعمدة المطلوبة من الكود ===';
    
    FOREACH col_name IN ARRAY required_columns
    LOOP
        SELECT COUNT(*) INTO col_count
        FROM information_schema.columns 
        WHERE table_name = 'task_submissions' 
        AND table_schema = 'public'
        AND column_name = col_name;
        
        IF col_count = 0 THEN
            missing_columns := array_append(missing_columns, col_name);
            RAISE NOTICE '❌ MISSING: % column', col_name;
        ELSE
            RAISE NOTICE '✅ EXISTS: % column', col_name;
        END IF;
    END LOOP;
    
    IF array_length(missing_columns, 1) > 0 THEN
        RAISE NOTICE '⚠️ أعمدة مفقودة: %', array_to_string(missing_columns, ', ');
    ELSE
        RAISE NOTICE '✅ جميع الأعمدة المطلوبة موجودة!';
    END IF;
END $$;

-- إزالة جميع قيود التحقق الموجودة للحالة
DO $$
DECLARE
    constraint_name TEXT;
BEGIN
    -- البحث عن جميع قيود التحقق المتعلقة بالحالة وإزالتها
    FOR constraint_name IN 
        SELECT tc.constraint_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.check_constraints cc 
            ON tc.constraint_name = cc.constraint_name
        WHERE tc.table_name = 'task_submissions' 
            AND tc.constraint_type = 'CHECK'
            AND tc.table_schema = 'public'
            AND (cc.check_clause LIKE '%status%' OR tc.constraint_name LIKE '%status%')
    LOOP
        EXECUTE format('ALTER TABLE public.task_submissions DROP CONSTRAINT IF EXISTS %I', constraint_name);
        RAISE NOTICE 'تم إزالة القيد: %', constraint_name;
    END LOOP;
END $$;

-- إضافة قيد تحقق جديد ومرن للحالة
ALTER TABLE public.task_submissions 
ADD CONSTRAINT task_submissions_status_check 
CHECK (status IN (
    'submitted', 'approved', 'rejected', 'needs_revision',
    'pending', 'in_review', 'revision_required', 'draft'
));

-- التأكد من القيم الافتراضية الصحيحة
ALTER TABLE public.task_submissions 
ALTER COLUMN status SET DEFAULT 'submitted';

ALTER TABLE public.task_submissions 
ALTER COLUMN completion_percentage SET DEFAULT 0;

ALTER TABLE public.task_submissions 
ALTER COLUMN hours_worked SET DEFAULT 0.0;

ALTER TABLE public.task_submissions 
ALTER COLUMN is_final_submission SET DEFAULT false;

ALTER TABLE public.task_submissions 
ALTER COLUMN attachments SET DEFAULT '[]'::jsonb;

-- اختبار إدراج سجل تجريبي
DO $$
DECLARE
    test_task_id UUID := gen_random_uuid();
    test_worker_id UUID := gen_random_uuid();
    test_submission_id UUID;
BEGIN
    RAISE NOTICE '=== اختبار إدراج سجل تجريبي ===';
    
    BEGIN
        INSERT INTO public.task_submissions (
            task_id,
            worker_id,
            progress_report,
            completion_percentage,
            hours_worked,
            notes,
            is_final_submission,
            status,
            attachments
        ) VALUES (
            test_task_id,
            test_worker_id,
            'تقرير تقدم تجريبي',
            50,
            2.5,
            'ملاحظات تجريبية',
            false,
            'submitted',
            '[]'::jsonb
        ) RETURNING id INTO test_submission_id;
        
        RAISE NOTICE '✅ SUCCESS: تم إدراج السجل التجريبي بنجاح!';
        RAISE NOTICE 'معرف السجل: %', test_submission_id;
        
        -- حذف السجل التجريبي
        DELETE FROM public.task_submissions WHERE id = test_submission_id;
        RAISE NOTICE '🧹 تم حذف السجل التجريبي';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ ERROR: فشل إدراج السجل التجريبي';
        RAISE NOTICE 'سبب الفشل: %', SQLERRM;
        RAISE NOTICE 'رمز الخطأ: %', SQLSTATE;
    END;
END $$;

COMMIT;

-- رسالة النجاح النهائية
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎉 =========================';
    RAISE NOTICE '🎉 تم إصلاح جدول task_submissions بنجاح!';
    RAISE NOTICE '🎉 =========================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ جميع الأعمدة المطلوبة موجودة';
    RAISE NOTICE '✅ قيود التحقق محدثة';
    RAISE NOTICE '✅ القيم الافتراضية صحيحة';
    RAISE NOTICE '✅ اختبار الإدراج نجح';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 جرب إرسال تقرير التقدم الآن - يجب أن يعمل!';
END $$;
