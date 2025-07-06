-- فحص بيانات تقارير التقدم في قاعدة البيانات

-- 1. عرض جميع تقارير التقدم الموجودة
SELECT 
    'تقارير التقدم الموجودة' as info,
    COUNT(*) as total_submissions
FROM public.task_submissions;

-- 2. عرض آخر 5 تقارير تقدم
SELECT 
    'آخر 5 تقارير تقدم' as info,
    id,
    task_id,
    worker_id,
    progress_report,
    completion_percentage,
    status,
    submitted_at
FROM public.task_submissions 
ORDER BY submitted_at DESC 
LIMIT 5;

-- 3. فحص المهام الموجودة في worker_tasks
SELECT 
    'المهام في worker_tasks' as info,
    COUNT(*) as total_tasks
FROM public.worker_tasks;

-- 4. عرض آخر 5 مهام
SELECT 
    'آخر 5 مهام' as info,
    id,
    title,
    assigned_to,
    status,
    created_at
FROM public.worker_tasks 
ORDER BY created_at DESC 
LIMIT 5;

-- 5. فحص العلاقة بين المهام وتقارير التقدم
SELECT 
    'العلاقة بين المهام والتقارير' as info,
    wt.title as task_title,
    ts.progress_report,
    ts.completion_percentage,
    ts.status as submission_status,
    ts.submitted_at
FROM public.worker_tasks wt
LEFT JOIN public.task_submissions ts ON wt.id = ts.task_id
ORDER BY ts.submitted_at DESC
LIMIT 10;

-- 6. فحص المستخدمين (العمال)
SELECT 
    'العمال المسجلين' as info,
    id,
    name,
    role,
    status
FROM public.user_profiles 
WHERE role = 'worker'
ORDER BY created_at DESC;

-- 7. إحصائيات شاملة
DO $$
DECLARE
    total_tasks INTEGER;
    total_submissions INTEGER;
    total_workers INTEGER;
    submitted_reports INTEGER;
    approved_reports INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_tasks FROM public.worker_tasks;
    SELECT COUNT(*) INTO total_submissions FROM public.task_submissions;
    SELECT COUNT(*) INTO total_workers FROM public.user_profiles WHERE role = 'worker';
    SELECT COUNT(*) INTO submitted_reports FROM public.task_submissions WHERE status = 'submitted';
    SELECT COUNT(*) INTO approved_reports FROM public.task_submissions WHERE status = 'approved';
    
    RAISE NOTICE '=== إحصائيات النظام ===';
    RAISE NOTICE 'إجمالي المهام: %', total_tasks;
    RAISE NOTICE 'إجمالي تقارير التقدم: %', total_submissions;
    RAISE NOTICE 'إجمالي العمال: %', total_workers;
    RAISE NOTICE 'التقارير المرسلة: %', submitted_reports;
    RAISE NOTICE 'التقارير المعتمدة: %', approved_reports;
    RAISE NOTICE '';
    
    IF total_submissions = 0 THEN
        RAISE NOTICE '⚠️ لا توجد تقارير تقدم في النظام';
        RAISE NOTICE '💡 تأكد من أن العمال أرسلوا تقارير التقدم';
    ELSE
        RAISE NOTICE '✅ يوجد % تقرير تقدم في النظام', total_submissions;
        RAISE NOTICE '🎯 يمكن للإدارة مراجعة التقارير الآن';
    END IF;
END $$;
