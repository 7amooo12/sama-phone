-- إضافة تأكيد التسليم لأذون صرف المخزون
-- Add Delivery Confirmation to Warehouse Release Orders

-- إضافة حالة جديدة "جاهز للتسليم" وحقول تأكيد التسليم
-- Add new "ready for delivery" status and delivery confirmation fields

-- إضافة الحقول الجديدة لتأكيد التسليم
ALTER TABLE public.warehouse_release_orders 
ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS delivered_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS delivered_by_name TEXT,
ADD COLUMN IF NOT EXISTS delivery_notes TEXT;

-- تحديث قيد التحقق من الحالة لإضافة الحالة الجديدة
ALTER TABLE public.warehouse_release_orders 
DROP CONSTRAINT IF EXISTS valid_release_order_status;

ALTER TABLE public.warehouse_release_orders 
ADD CONSTRAINT valid_release_order_status CHECK (status IN (
    'pendingWarehouseApproval',  -- في انتظار موافقة مدير المخزن
    'approvedByWarehouse',       -- تم الموافقة من مدير المخزن
    'readyForDelivery',          -- جاهز للتسليم (تم المعالجة)
    'completed',                 -- مكتمل (تم التسليم للعميل)
    'rejected',                  -- مرفوض
    'cancelled'                  -- ملغي
));

-- إضافة فهرس للحقول الجديدة
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_delivered_at 
ON public.warehouse_release_orders(delivered_at);

CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_delivered_by 
ON public.warehouse_release_orders(delivered_by);

-- تحديث جدول تاريخ أذون الصرف لإضافة إجراء التسليم
ALTER TABLE public.warehouse_release_order_history 
DROP CONSTRAINT IF EXISTS valid_history_action;

ALTER TABLE public.warehouse_release_order_history 
ADD CONSTRAINT valid_history_action CHECK (action IN (
    'created',           -- تم الإنشاء
    'status_changed',    -- تم تغيير الحالة
    'approved',          -- تم الموافقة
    'rejected',          -- تم الرفض
    'completed',         -- تم الإكمال
    'cancelled',         -- تم الإلغاء
    'updated',           -- تم التحديث
    'delivered'          -- تم التسليم
));

-- إضافة تعليقات للحقول الجديدة
COMMENT ON COLUMN public.warehouse_release_orders.delivered_at IS 'تاريخ ووقت تأكيد التسليم';
COMMENT ON COLUMN public.warehouse_release_orders.delivered_by IS 'معرف مدير المخزن الذي أكد التسليم';
COMMENT ON COLUMN public.warehouse_release_orders.delivered_by_name IS 'اسم مدير المخزن الذي أكد التسليم';
COMMENT ON COLUMN public.warehouse_release_orders.delivery_notes IS 'ملاحظات التسليم';

-- تحديث التعليق على عمود الحالة
COMMENT ON COLUMN public.warehouse_release_orders.status IS 'حالة أذن الصرف: pendingWarehouseApproval, approvedByWarehouse, readyForDelivery, completed, rejected, cancelled';

-- إنشاء دالة لتحديث حالة الطلب الأصلي عند تأكيد التسليم
CREATE OR REPLACE FUNCTION update_client_order_on_delivery_confirmation()
RETURNS TRIGGER AS $$
BEGIN
    -- التحقق من أن الحالة تغيرت إلى "completed" (مكتمل)
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- تحديث حالة الطلب الأصلي إلى "delivered" (تم التسليم)
        UPDATE public.client_orders 
        SET 
            status = 'delivered',
            updated_at = NOW()
        WHERE id = NEW.original_order_id;
        
        -- إضافة سجل في تاريخ الطلب
        INSERT INTO public.order_history (
            order_id,
            action,
            old_status,
            new_status,
            description,
            changed_by,
            changed_by_name,
            changed_by_role,
            metadata
        ) VALUES (
            NEW.original_order_id,
            'completed',
            'shipped',
            'delivered',
            'تم تأكيد التسليم من مدير المخزن',
            NEW.delivered_by,
            NEW.delivered_by_name,
            'warehouse_manager',
            jsonb_build_object(
                'release_order_id', NEW.id,
                'release_order_number', NEW.release_order_number,
                'delivered_at', NEW.delivered_at,
                'delivery_notes', NEW.delivery_notes
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء المشغل لتحديث حالة الطلب الأصلي تلقائياً
DROP TRIGGER IF EXISTS trigger_update_client_order_on_delivery ON public.warehouse_release_orders;
CREATE TRIGGER trigger_update_client_order_on_delivery
    AFTER UPDATE ON public.warehouse_release_orders
    FOR EACH ROW
    EXECUTE FUNCTION update_client_order_on_delivery_confirmation();

-- Migration completed successfully
-- تم إكمال الترحيل بنجاح
