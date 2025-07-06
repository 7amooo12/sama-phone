-- إصلاح مخطط جدول task_submissions لإضافة الأعمدة المفقودة
-- هذا السكريبت يحل مشكلة عمود completion_percentage المفقود

BEGIN;

-- فحص الأعمدة الحالية في جدول task_submissions
DO $$
BEGIN
    RAISE NOTICE 'فحص مخطط جدول task_submissions...';
END $$;

-- إضافة الأعمدة المفقودة إلى جدول task_submissions
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS completion_percentage DECIMAL(5,2) DEFAULT 0.0;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS progress_notes TEXT;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS estimated_completion_date TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS actual_hours_worked DECIMAL(8,2);

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS quality_rating INTEGER CHECK (quality_rating >= 1 AND quality_rating <= 5);

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS is_final_submission BOOLEAN DEFAULT false;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS submission_type TEXT DEFAULT 'progress';

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMP WITH TIME ZONE DEFAULT now();

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

-- التأكد من وجود الأعمدة الأساسية
ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS id UUID PRIMARY KEY DEFAULT gen_random_uuid();

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS task_id UUID;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS worker_id UUID;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS title TEXT;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS description TEXT;

ALTER TABLE public.task_submissions 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'submitted';

-- إنشاء دالة لتحديث updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_task_submissions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء trigger لتحديث updated_at
DROP TRIGGER IF EXISTS update_task_submissions_updated_at_trigger ON public.task_submissions;
CREATE TRIGGER update_task_submissions_updated_at_trigger
    BEFORE UPDATE ON public.task_submissions
    FOR EACH ROW
    EXECUTE FUNCTION update_task_submissions_updated_at();

-- إضافة فهارس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_task_submissions_task_id ON public.task_submissions(task_id);
CREATE INDEX IF NOT EXISTS idx_task_submissions_worker_id ON public.task_submissions(worker_id);
CREATE INDEX IF NOT EXISTS idx_task_submissions_submitted_at ON public.task_submissions(submitted_at);

-- تحديث RLS policies لجدول task_submissions
DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.task_submissions;
DROP POLICY IF EXISTS "Workers can manage their submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Admins can view all submissions" ON public.task_submissions;

-- إنشاء policies محدثة
CREATE POLICY "Workers can manage their submissions" 
ON public.task_submissions 
FOR ALL 
TO authenticated 
USING (
    worker_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
) 
WITH CHECK (
    worker_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Admins can view all submissions" 
ON public.task_submissions 
FOR SELECT 
TO authenticated 
USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
);

-- منح الصلاحيات
GRANT ALL ON public.task_submissions TO authenticated;
GRANT ALL ON public.task_submissions TO service_role;

COMMIT;

-- التحقق من النتائج
DO $$
DECLARE
    col_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_name = 'task_submissions' 
    AND table_schema = 'public'
    AND column_name = 'completion_percentage';
    
    IF col_count > 0 THEN
        RAISE NOTICE '✅ SUCCESS: عمود completion_percentage تم إضافته بنجاح';
    ELSE
        RAISE NOTICE '❌ ERROR: عمود completion_percentage لا يزال مفقود';
    END IF;
    
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_name = 'task_submissions' 
    AND table_schema = 'public';
    
    RAISE NOTICE 'إجمالي الأعمدة في جدول task_submissions: %', col_count;
    RAISE NOTICE '';
    RAISE NOTICE '🎉 تم تحديث مخطط جدول task_submissions بنجاح!';
    RAISE NOTICE 'يمكن للعمال الآن إرسال تقارير التقدم بدون أخطاء.';
END $$;
