-- إصلاح قيد بيانات الإكمال لأذون صرف المخزون
-- Fix completion data constraint for warehouse release orders

-- إزالة القيد القديم وإضافة قيد محسن يدعم تأكيد التسليم
-- Remove old constraint and add enhanced constraint that supports delivery confirmation

-- إزالة القيد القديم
ALTER TABLE public.warehouse_release_orders 
DROP CONSTRAINT IF EXISTS valid_completion_data;

-- إضافة قيد محسن يدعم تأكيد التسليم
ALTER TABLE public.warehouse_release_orders
ADD CONSTRAINT valid_completion_data CHECK (
    -- عند الحالة 'completed': يجب أن يكون completed_at موجود (التسليم اختياري)
    (status = 'completed' AND completed_at IS NOT NULL) OR
    -- للحالات الأخرى: completed_at اختياري
    (status != 'completed')
);

-- إضافة تعليق للتوضيح
COMMENT ON CONSTRAINT valid_completion_data ON public.warehouse_release_orders IS
'يضمن أن completed_at موجود عند حالة completed. حقول التسليم (delivered_at, delivered_by) اختيارية ومستقلة.';

-- إضافة فهرس مركب للأداء
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_completion_status 
ON public.warehouse_release_orders(status, completed_at, delivered_at);

-- تحديث السجلات الموجودة لضمان التوافق مع القيد الجديد
-- Update existing records to ensure compatibility with new constraint

-- تحديث السجلات التي لها حالة 'completed' لكن بدون completed_at
UPDATE public.warehouse_release_orders 
SET completed_at = delivered_at 
WHERE status = 'completed' 
  AND completed_at IS NULL 
  AND delivered_at IS NOT NULL;

-- إضافة تحقق من صحة البيانات بعد التحديث
DO $$
DECLARE
    invalid_count INTEGER;
BEGIN
    -- فحص السجلات التي قد تنتهك القيد الجديد
    SELECT COUNT(*) INTO invalid_count
    FROM public.warehouse_release_orders
    WHERE status = 'completed' AND completed_at IS NULL;

    IF invalid_count > 0 THEN
        RAISE NOTICE '⚠️  تحذير: يوجد % سجل بحالة completed بدون completed_at. يرجى مراجعة البيانات.', invalid_count;
    ELSE
        RAISE NOTICE '✅ جميع السجلات متوافقة مع القيد الجديد';
    END IF;
END $$;
