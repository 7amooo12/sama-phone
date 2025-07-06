-- فحص بيانات المهام لمعرفة سبب عدم ظهورها للعمال

-- 1. فحص المهام في جدول tasks
SELECT 
    'جدول tasks' as table_name,
    COUNT(*) as total_tasks,
    COUNT(CASE WHEN worker_id IS NOT NULL THEN 1 END) as tasks_with_worker,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_tasks
FROM public.tasks;

-- 2. فحص المهام في جدول worker_tasks
SELECT 
    'جدول worker_tasks' as table_name,
    COUNT(*) as total_tasks,
    COUNT(CASE WHEN assigned_to IS NOT NULL THEN 1 END) as tasks_with_worker,
    COUNT(CASE WHEN status = 'assigned' THEN 1 END) as assigned_tasks
FROM public.worker_tasks;

-- 3. عرض المهام الحديثة من جدول tasks
SELECT 
    'المهام الحديثة في جدول tasks' as info,
    id,
    title,
    worker_id,
    worker_name,
    status,
    created_at
FROM public.tasks 
ORDER BY created_at DESC 
LIMIT 5;

-- 4. عرض المهام الحديثة من جدول worker_tasks
SELECT 
    'المهام الحديثة في جدول worker_tasks' as info,
    id,
    title,
    assigned_to,
    status,
    created_at
FROM public.worker_tasks 
ORDER BY created_at DESC 
LIMIT 5;

-- 5. فحص العمال المسجلين
SELECT 
    'العمال المسجلين' as info,
    id,
    name,
    role,
    email
FROM public.user_profiles 
WHERE role = 'worker'
ORDER BY created_at DESC;

-- 6. البحث عن المهام المعينة لعامل معين (استبدل بـ ID العامل الفعلي)
DO $$
DECLARE
    worker_id_to_check UUID;
    task_count_tasks INTEGER;
    task_count_worker_tasks INTEGER;
BEGIN
    -- الحصول على أول عامل مسجل
    SELECT id INTO worker_id_to_check 
    FROM public.user_profiles 
    WHERE role = 'worker' 
    LIMIT 1;
    
    IF worker_id_to_check IS NOT NULL THEN
        -- عد المهام في جدول tasks
        SELECT COUNT(*) INTO task_count_tasks
        FROM public.tasks 
        WHERE worker_id = worker_id_to_check;
        
        -- عد المهام في جدول worker_tasks
        SELECT COUNT(*) INTO task_count_worker_tasks
        FROM public.worker_tasks 
        WHERE assigned_to = worker_id_to_check;
        
        RAISE NOTICE '=== فحص مهام العامل: % ===', worker_id_to_check;
        RAISE NOTICE 'المهام في جدول tasks: %', task_count_tasks;
        RAISE NOTICE 'المهام في جدول worker_tasks: %', task_count_worker_tasks;
        
        IF task_count_tasks > 0 AND task_count_worker_tasks = 0 THEN
            RAISE NOTICE '⚠️ المشكلة: المهام موجودة في جدول tasks لكن غير موجودة في worker_tasks';
            RAISE NOTICE '🔧 الحل: تشغيل سكريبت fix_worker_task_display.sql';
        ELSIF task_count_worker_tasks > 0 THEN
            RAISE NOTICE '✅ المهام موجودة في worker_tasks';
        ELSE
            RAISE NOTICE 'ℹ️ لا توجد مهام معينة لهذا العامل';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ لا يوجد عمال مسجلين في النظام';
    END IF;
END $$;

-- 7. فحص آخر المهام المنشأة
SELECT 
    'آخر المهام المنشأة' as info,
    t.id,
    t.title,
    t.worker_id,
    t.worker_name,
    t.status,
    t.created_at,
    CASE 
        WHEN wt.id IS NOT NULL THEN 'موجودة في worker_tasks'
        ELSE 'غير موجودة في worker_tasks'
    END as sync_status
FROM public.tasks t
LEFT JOIN public.worker_tasks wt ON t.id = wt.id
ORDER BY t.created_at DESC
LIMIT 10;
