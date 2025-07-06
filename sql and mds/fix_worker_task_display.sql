-- إصلاح عرض المهام للعمال
-- هذا السكريبت يحل مشكلة عدم ظهور المهام للعمال

BEGIN;

-- أولاً: التحقق من المهام الموجودة في جدول tasks
DO $$
DECLARE
    task_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO task_count FROM public.tasks;
    RAISE NOTICE 'عدد المهام في جدول tasks: %', task_count;
    
    SELECT COUNT(*) INTO task_count FROM public.worker_tasks;
    RAISE NOTICE 'عدد المهام في جدول worker_tasks: %', task_count;
END $$;

-- إنشاء دالة لنسخ المهام من جدول tasks إلى worker_tasks
CREATE OR REPLACE FUNCTION sync_tasks_to_worker_tasks()
RETURNS VOID AS $$
DECLARE
    task_record RECORD;
    existing_count INTEGER;
BEGIN
    -- نسخ المهام من جدول tasks إلى worker_tasks
    FOR task_record IN 
        SELECT 
            id,
            title,
            description,
            worker_id as assigned_to,
            admin_id as assigned_by,
            status,
            created_at,
            deadline as due_date,
            quantity,
            category,
            product_name,
            product_id
        FROM public.tasks 
        WHERE worker_id IS NOT NULL
    LOOP
        -- التحقق من وجود المهمة في worker_tasks
        SELECT COUNT(*) INTO existing_count 
        FROM public.worker_tasks 
        WHERE id = task_record.id;
        
        -- إدراج المهمة إذا لم تكن موجودة
        IF existing_count = 0 THEN
            INSERT INTO public.worker_tasks (
                id,
                title,
                description,
                assigned_to,
                assigned_by,
                priority,
                status,
                due_date,
                created_at,
                updated_at,
                estimated_hours,
                category,
                location,
                requirements,
                is_active
            ) VALUES (
                task_record.id,
                task_record.title,
                task_record.description,
                task_record.assigned_to,
                task_record.assigned_by,
                'medium', -- افتراضي
                CASE 
                    WHEN task_record.status = 'pending' THEN 'assigned'
                    WHEN task_record.status = 'in_progress' THEN 'inProgress'
                    ELSE task_record.status
                END,
                task_record.due_date,
                task_record.created_at,
                task_record.created_at,
                NULL, -- estimated_hours
                task_record.category,
                NULL, -- location
                'إنتاج ' || COALESCE(task_record.product_name, '') || 
                ' بكمية ' || COALESCE(task_record.quantity::text, ''), -- requirements
                true
            );
            
            RAISE NOTICE 'تم نسخ المهمة: % للعامل: %', task_record.title, task_record.assigned_to;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- تشغيل دالة المزامنة
SELECT sync_tasks_to_worker_tasks();

-- إنشاء trigger لمزامنة المهام الجديدة تلقائياً
CREATE OR REPLACE FUNCTION auto_sync_new_task()
RETURNS TRIGGER AS $$
BEGIN
    -- إدراج المهمة في worker_tasks عند إنشاء مهمة جديدة في tasks
    INSERT INTO public.worker_tasks (
        id,
        title,
        description,
        assigned_to,
        assigned_by,
        priority,
        status,
        due_date,
        created_at,
        updated_at,
        estimated_hours,
        category,
        location,
        requirements,
        is_active
    ) VALUES (
        NEW.id,
        NEW.title,
        NEW.description,
        NEW.worker_id,
        NEW.admin_id,
        'medium', -- افتراضي
        CASE 
            WHEN NEW.status = 'pending' THEN 'assigned'
            WHEN NEW.status = 'in_progress' THEN 'inProgress'
            ELSE NEW.status
        END,
        NEW.deadline,
        NEW.created_at,
        NEW.created_at,
        NULL, -- estimated_hours
        NEW.category,
        NULL, -- location
        'إنتاج ' || COALESCE(NEW.product_name, '') || 
        ' بكمية ' || COALESCE(NEW.quantity::text, ''), -- requirements
        true
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء trigger
DROP TRIGGER IF EXISTS trigger_auto_sync_task ON public.tasks;
CREATE TRIGGER trigger_auto_sync_task
    AFTER INSERT ON public.tasks
    FOR EACH ROW
    WHEN (NEW.worker_id IS NOT NULL)
    EXECUTE FUNCTION auto_sync_new_task();

-- إنشاء trigger للتحديثات
CREATE OR REPLACE FUNCTION auto_sync_task_updates()
RETURNS TRIGGER AS $$
BEGIN
    -- تحديث المهمة في worker_tasks عند تحديثها في tasks
    UPDATE public.worker_tasks 
    SET 
        title = NEW.title,
        description = NEW.description,
        assigned_to = NEW.worker_id,
        status = CASE 
            WHEN NEW.status = 'pending' THEN 'assigned'
            WHEN NEW.status = 'in_progress' THEN 'inProgress'
            ELSE NEW.status
        END,
        due_date = NEW.deadline,
        updated_at = NOW(),
        requirements = 'إنتاج ' || COALESCE(NEW.product_name, '') || 
                      ' بكمية ' || COALESCE(NEW.quantity::text, '')
    WHERE id = NEW.id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء trigger للتحديثات
DROP TRIGGER IF EXISTS trigger_auto_sync_task_updates ON public.tasks;
CREATE TRIGGER trigger_auto_sync_task_updates
    AFTER UPDATE ON public.tasks
    FOR EACH ROW
    WHEN (NEW.worker_id IS NOT NULL)
    EXECUTE FUNCTION auto_sync_task_updates();

COMMIT;

-- التحقق من النتائج
DO $$
DECLARE
    task_count INTEGER;
    worker_task_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO task_count FROM public.tasks;
    SELECT COUNT(*) INTO worker_task_count FROM public.worker_tasks;
    
    RAISE NOTICE '=== نتائج المزامنة ===';
    RAISE NOTICE 'عدد المهام في جدول tasks: %', task_count;
    RAISE NOTICE 'عدد المهام في جدول worker_tasks: %', worker_task_count;
    RAISE NOTICE '';
    
    IF worker_task_count > 0 THEN
        RAISE NOTICE '✅ تم نسخ المهام بنجاح!';
        RAISE NOTICE '🎉 العمال سيرون المهام الآن في صفحة المهام';
    ELSE
        RAISE NOTICE '⚠️ لم يتم نسخ أي مهام. تحقق من وجود مهام مع worker_id';
    END IF;
END $$;
