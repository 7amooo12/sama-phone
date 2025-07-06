-- إصلاح قيد التحقق لعمود status في جدول task_submissions
-- المشكلة: القيم المسموحة في CHECK constraint لا تتطابق مع ما يرسله الكود

BEGIN;

-- أولاً: إزالة القيد الحالي إذا كان موجود
DO $$
BEGIN
    -- البحث عن قيد التحقق الحالي وإزالته
    IF EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name LIKE '%status_check%' 
        AND constraint_schema = 'public'
    ) THEN
        ALTER TABLE public.task_submissions 
        DROP CONSTRAINT IF EXISTS task_submissions_status_check;
        RAISE NOTICE 'تم إزالة قيد التحقق القديم للحالة';
    END IF;
END $$;

-- ثانياً: إضافة قيد تحقق جديد يتضمن جميع القيم المطلوبة
ALTER TABLE public.task_submissions 
ADD CONSTRAINT task_submissions_status_check 
CHECK (status IN (
    'submitted',        -- القيمة التي يرسلها الكود
    'approved', 
    'rejected', 
    'needs_revision',
    'pending',          -- قيمة إضافية قد تكون مطلوبة
    'in_review',        -- قيمة إضافية قد تكون مطلوبة
    'revision_required' -- قيمة إضافية قد تكون مطلوبة
));

-- ثالثاً: التأكد من أن العمود له قيمة افتراضية صحيحة
ALTER TABLE public.task_submissions 
ALTER COLUMN status SET DEFAULT 'submitted';

-- رابعاً: تحديث أي سجلات موجودة بقيم غير صحيحة
UPDATE public.task_submissions 
SET status = 'submitted' 
WHERE status NOT IN (
    'submitted', 'approved', 'rejected', 'needs_revision',
    'pending', 'in_review', 'revision_required'
);

COMMIT;

-- التحقق من النتائج
DO $$
DECLARE
    constraint_count INTEGER;
BEGIN
    -- التحقق من وجود القيد الجديد
    SELECT COUNT(*) INTO constraint_count
    FROM information_schema.check_constraints 
    WHERE constraint_name = 'task_submissions_status_check'
    AND constraint_schema = 'public';
    
    IF constraint_count > 0 THEN
        RAISE NOTICE '✅ SUCCESS: تم إنشاء قيد التحقق الجديد للحالة';
        RAISE NOTICE 'القيم المسموحة الآن:';
        RAISE NOTICE '- submitted (القيمة الافتراضية)';
        RAISE NOTICE '- approved';
        RAISE NOTICE '- rejected';
        RAISE NOTICE '- needs_revision';
        RAISE NOTICE '- pending';
        RAISE NOTICE '- in_review';
        RAISE NOTICE '- revision_required';
    ELSE
        RAISE NOTICE '❌ ERROR: فشل في إنشاء قيد التحقق';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎉 تم إصلاح مشكلة قيد التحقق للحالة!';
    RAISE NOTICE '🚀 جرب إرسال تقرير التقدم الآن - يجب أن يعمل!';
END $$;
