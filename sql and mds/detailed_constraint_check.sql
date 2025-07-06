-- فحص مفصل لقيود التحقق في جدول task_submissions

-- 1. عرض جميع قيود التحقق للجدول (طريقة أوسع)
SELECT 
    tc.constraint_name,
    tc.table_name,
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc 
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name = 'task_submissions' 
    AND tc.constraint_type = 'CHECK'
    AND tc.table_schema = 'public';

-- 2. فحص قيود التحقق من pg_constraint مباشرة
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'public.task_submissions'::regclass 
    AND contype = 'c';

-- 3. محاولة إدراج قيمة تجريبية لاختبار القيد
DO $$
BEGIN
    -- محاولة إدراج سجل تجريبي بقيمة 'submitted'
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
            gen_random_uuid(),
            gen_random_uuid(),
            'تقرير تجريبي',
            50,
            2.5,
            'ملاحظات تجريبية',
            false,
            'submitted',  -- القيمة التي تسبب المشكلة
            '[]'::jsonb
        );
        
        RAISE NOTICE '✅ SUCCESS: تم إدراج السجل التجريبي بنجاح';
        RAISE NOTICE 'القيمة "submitted" مقبولة في قيد التحقق';
        
        -- حذف السجل التجريبي
        DELETE FROM public.task_submissions 
        WHERE progress_report = 'تقرير تجريبي';
        
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE '❌ ERROR: فشل إدراج السجل التجريبي';
        RAISE NOTICE 'سبب الفشل: %', SQLERRM;
        RAISE NOTICE 'القيمة "submitted" غير مقبولة في قيد التحقق الحالي';
        
    WHEN foreign_key_violation THEN
        RAISE NOTICE '⚠️ WARNING: مشكلة في المراجع الخارجية (Foreign Keys)';
        RAISE NOTICE 'لكن قيد التحقق للحالة يبدو صحيح';
        
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ خطأ آخر: %', SQLERRM;
    END;
END $$;

-- 4. عرض جميع الأعمدة في الجدول للتأكد من البنية
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'task_submissions' 
    AND table_schema = 'public'
ORDER BY ordinal_position;
