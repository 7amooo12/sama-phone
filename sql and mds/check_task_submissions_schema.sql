-- فحص مخطط جدول task_submissions
-- تشغيل هذا السكريبت لرؤية الأعمدة الحالية والمفقودة

-- عرض جميع الأعمدة في جدول task_submissions
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'task_submissions' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- فحص الأعمدة المطلوبة
DO $$
DECLARE
    missing_columns TEXT[] := ARRAY[]::TEXT[];
    col_count INTEGER;
    required_columns TEXT[] := ARRAY[
        'completion_percentage',
        'progress_notes', 
        'estimated_completion_date',
        'actual_hours_worked',
        'quality_rating',
        'is_final_submission',
        'submission_type',
        'attachments',
        'submitted_at',
        'updated_at',
        'task_id',
        'worker_id',
        'title',
        'description',
        'status'
    ];
    col_name TEXT;
BEGIN
    RAISE NOTICE '=== فحص الأعمدة المطلوبة في جدول task_submissions ===';
    
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
    
    RAISE NOTICE '';
    IF array_length(missing_columns, 1) > 0 THEN
        RAISE NOTICE '⚠️  الأعمدة المفقودة: %', array_to_string(missing_columns, ', ');
        RAISE NOTICE '🔧 شغّل fix_task_submissions_schema.sql لإضافة الأعمدة المفقودة';
    ELSE
        RAISE NOTICE '✅ جميع الأعمدة المطلوبة موجودة!';
        RAISE NOTICE '🎉 جدول task_submissions جاهز للاستخدام';
    END IF;
END $$;

-- فحص RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as operation
FROM pg_policies 
WHERE schemaname = 'public'
    AND tablename = 'task_submissions'
ORDER BY policyname;
