-- الإصلاح النهائي لجدول task_submissions
-- يضيف جميع الحقول المطلوبة بالضبط كما يستخدمها الكود

BEGIN;

-- إضافة جميع الحقول المطلوبة من الكود
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS task_id UUID;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS worker_id UUID;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS progress_report TEXT;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS completion_percentage INTEGER DEFAULT 0 CHECK (completion_percentage >= 0 AND completion_percentage <= 100);

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS hours_worked DECIMAL(5,2);

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS is_final_submission BOOLEAN DEFAULT false;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'submitted' CHECK (status IN ('submitted', 'approved', 'rejected', 'needs_revision'));

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::jsonb;

-- إضافة الحقول الإضافية المستخدمة في approveTaskSubmission
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS approved_by UUID;

-- إضافة الحقول الأساسية للجدول
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS id UUID PRIMARY KEY DEFAULT gen_random_uuid();

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMP WITH TIME ZONE DEFAULT now();

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT now();

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

-- إضافة المراجع الخارجية إذا لم تكن موجودة
DO $$
BEGIN
    -- إضافة foreign key لـ task_id إذا لم يكن موجود
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'task_submissions_task_id_fkey' 
        AND table_name = 'task_submissions'
    ) THEN
        ALTER TABLE public.task_submissions 
        ADD CONSTRAINT task_submissions_task_id_fkey 
        FOREIGN KEY (task_id) REFERENCES public.worker_tasks(id) ON DELETE CASCADE;
    END IF;
    
    -- إضافة foreign key لـ worker_id إذا لم يكن موجود
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'task_submissions_worker_id_fkey' 
        AND table_name = 'task_submissions'
    ) THEN
        ALTER TABLE public.task_submissions 
        ADD CONSTRAINT task_submissions_worker_id_fkey 
        FOREIGN KEY (worker_id) REFERENCES auth.users(id) ON DELETE CASCADE;
    END IF;
    
    -- إضافة foreign key لـ approved_by إذا لم يكن موجود
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'task_submissions_approved_by_fkey' 
        AND table_name = 'task_submissions'
    ) THEN
        ALTER TABLE public.task_submissions 
        ADD CONSTRAINT task_submissions_approved_by_fkey 
        FOREIGN KEY (approved_by) REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- إنشاء trigger لتحديث updated_at
CREATE OR REPLACE FUNCTION update_task_submissions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_task_submissions_updated_at_trigger ON public.task_submissions;
CREATE TRIGGER update_task_submissions_updated_at_trigger
    BEFORE UPDATE ON public.task_submissions
    FOR EACH ROW
    EXECUTE FUNCTION update_task_submissions_updated_at();

-- إنشاء فهارس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_task_submissions_task_id ON public.task_submissions(task_id);
CREATE INDEX IF NOT EXISTS idx_task_submissions_worker_id ON public.task_submissions(worker_id);
CREATE INDEX IF NOT EXISTS idx_task_submissions_status ON public.task_submissions(status);
CREATE INDEX IF NOT EXISTS idx_task_submissions_submitted_at ON public.task_submissions(submitted_at);

COMMIT;

-- التحقق من جميع الحقول المطلوبة
DO $$
DECLARE
    required_columns TEXT[] := ARRAY[
        'id', 'task_id', 'worker_id', 'progress_report', 
        'completion_percentage', 'hours_worked', 'notes', 
        'is_final_submission', 'status', 'attachments',
        'approved_at', 'approved_by', 'submitted_at', 
        'created_at', 'updated_at'
    ];
    col_name TEXT;
    col_count INTEGER;
    missing_count INTEGER := 0;
BEGIN
    RAISE NOTICE '=== فحص الحقول المطلوبة في جدول task_submissions ===';
    
    FOREACH col_name IN ARRAY required_columns
    LOOP
        SELECT COUNT(*) INTO col_count
        FROM information_schema.columns 
        WHERE table_name = 'task_submissions' 
        AND table_schema = 'public'
        AND column_name = col_name;
        
        IF col_count = 0 THEN
            missing_count := missing_count + 1;
            RAISE NOTICE '❌ MISSING: % column', col_name;
        ELSE
            RAISE NOTICE '✅ EXISTS: % column', col_name;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    IF missing_count = 0 THEN
        RAISE NOTICE '🎉 جميع الحقول المطلوبة موجودة!';
        RAISE NOTICE '✅ جدول task_submissions جاهز للاستخدام';
        RAISE NOTICE '🚀 جرب إرسال تقرير التقدم الآن - يجب أن يعمل!';
    ELSE
        RAISE NOTICE '⚠️  يوجد % حقل مفقود', missing_count;
    END IF;
END $$;
