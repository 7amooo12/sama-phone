-- فحص قيود التحقق في جدول task_submissions
-- لمعرفة ما هي القيم المسموحة حالياً

-- عرض جميع قيود التحقق للجدول
SELECT 
    constraint_name,
    check_clause
FROM information_schema.check_constraints 
WHERE constraint_schema = 'public'
AND constraint_name LIKE '%task_submissions%';

-- عرض تفاصيل عمود status
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'task_submissions' 
AND table_schema = 'public'
AND column_name = 'status';

-- فحص القيم الموجودة حالياً في عمود status
DO $$
DECLARE
    status_values TEXT[];
    val TEXT;
BEGIN
    -- الحصول على جميع القيم الفريدة في عمود status
    SELECT ARRAY_AGG(DISTINCT status) INTO status_values
    FROM public.task_submissions 
    WHERE status IS NOT NULL;
    
    RAISE NOTICE '=== القيم الموجودة حالياً في عمود status ===';
    
    IF status_values IS NOT NULL THEN
        FOREACH val IN ARRAY status_values
        LOOP
            RAISE NOTICE 'القيمة الموجودة: "%"', val;
        END LOOP;
    ELSE
        RAISE NOTICE 'لا توجد بيانات في الجدول بعد';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE 'القيمة التي يحاول الكود إدراجها: "submitted"';
    RAISE NOTICE 'إذا كانت "submitted" غير موجودة في القيود، فهذا سبب الخطأ.';
END $$;
