-- إضافة الأعمدة المفقودة الإضافية لجدول task_submissions
-- هذا السكريبت يضيف العمود المفقود hours_worked وأي أعمدة أخرى قد تكون مطلوبة

BEGIN;

-- إضافة العمود المفقود hours_worked
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS hours_worked DECIMAL(8,2) DEFAULT 0.0;

-- إضافة أعمدة إضافية قد تكون مطلوبة من الكود
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS images JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS files JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT now();

-- إضافة عمود progress_percentage كبديل لـ completion_percentage
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS progress_percentage DECIMAL(5,2) DEFAULT 0.0;

-- إضافة عمود work_hours كبديل لـ hours_worked
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS work_hours DECIMAL(8,2) DEFAULT 0.0;

-- إضافة عمود submission_date
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS submission_date TIMESTAMP WITH TIME ZONE DEFAULT now();

-- إضافة عمود feedback للملاحظات من الإدارة
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS feedback TEXT;

-- إضافة عمود approved_by للموافقة
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS approved_by UUID;

-- إضافة عمود approved_at لتاريخ الموافقة
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE;

COMMIT;

-- التحقق من إضافة العمود المطلوب
DO $$
DECLARE
    col_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_name = 'task_submissions' 
    AND table_schema = 'public'
    AND column_name = 'hours_worked';
    
    IF col_count > 0 THEN
        RAISE NOTICE '✅ SUCCESS: عمود hours_worked تم إضافته بنجاح';
    ELSE
        RAISE NOTICE '❌ ERROR: عمود hours_worked لا يزال مفقود';
    END IF;
    
    -- فحص الأعمدة الأخرى
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_name = 'task_submissions' 
    AND table_schema = 'public'
    AND column_name = 'completion_percentage';
    
    IF col_count > 0 THEN
        RAISE NOTICE '✅ عمود completion_percentage موجود';
    ELSE
        RAISE NOTICE '❌ عمود completion_percentage مفقود';
    END IF;
    
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_name = 'task_submissions' 
    AND table_schema = 'public';
    
    RAISE NOTICE '';
    RAISE NOTICE 'إجمالي الأعمدة في جدول task_submissions: %', col_count;
    RAISE NOTICE '🎉 تم تحديث جدول task_submissions بالأعمدة المطلوبة!';
    RAISE NOTICE 'جرب إرسال تقرير التقدم مرة أخرى.';
END $$;
