-- إنشاء الـ Triggers والدوال المتقدمة لنظام الطلبات
-- Migration: Create advanced triggers and functions for orders system

-- ===== دالة لإنشاء إشعار جديد =====
CREATE OR REPLACE FUNCTION create_order_notification(
    p_order_id UUID,
    p_title TEXT,
    p_message TEXT,
    p_notification_type TEXT,
    p_recipient_id UUID,
    p_recipient_role TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    notification_id UUID;
BEGIN
    INSERT INTO public.order_notifications (
        order_id, title, message, notification_type, 
        recipient_id, recipient_role
    ) VALUES (
        p_order_id, p_title, p_message, p_notification_type,
        p_recipient_id, p_recipient_role
    ) RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql;

-- ===== دالة لإرسال إشعارات للإدارة والمحاسبين =====
CREATE OR REPLACE FUNCTION notify_staff_about_order(
    p_order_id UUID,
    p_title TEXT,
    p_message TEXT,
    p_notification_type TEXT
)
RETURNS INTEGER AS $$
DECLARE
    staff_user RECORD;
    notification_count INTEGER := 0;
BEGIN
    -- إرسال إشعارات لجميع الإدارة والمحاسبين
    FOR staff_user IN 
        SELECT id, role FROM public.user_profiles 
        WHERE role IN ('admin', 'manager', 'accountant')
        AND id IS NOT NULL
    LOOP
        PERFORM create_order_notification(
            p_order_id, p_title, p_message, p_notification_type,
            staff_user.id, staff_user.role
        );
        notification_count := notification_count + 1;
    END LOOP;
    
    RETURN notification_count;
END;
$$ LANGUAGE plpgsql;

-- ===== Trigger عند إنشاء طلب جديد =====
CREATE OR REPLACE FUNCTION handle_new_order()
RETURNS TRIGGER AS $$
DECLARE
    order_title TEXT;
    order_message TEXT;
BEGIN
    -- توليد رقم الطلب إذا لم يكن موجوداً
    IF NEW.order_number IS NULL OR NEW.order_number = '' THEN
        NEW.order_number := generate_order_number();
    END IF;
    
    -- إضافة سجل في تاريخ الطلب
    PERFORM add_order_history(
        NEW.id, 'created', NULL, NEW.status,
        'تم إنشاء الطلب بنجاح',
        NEW.client_id, NEW.client_name, 'client'
    );
    
    -- إعداد الإشعار
    order_title := 'طلب جديد: ' || NEW.order_number;
    order_message := 'تم استلام طلب جديد من العميل ' || NEW.client_name || 
                    ' بقيمة ' || NEW.total_amount || ' ج.م';
    
    -- إرسال إشعارات للإدارة والمحاسبين
    PERFORM notify_staff_about_order(
        NEW.id, order_title, order_message, 'order_created'
    );
    
    -- إرسال إشعار للعميل
    PERFORM create_order_notification(
        NEW.id, 
        'تم إنشاء طلبك بنجاح',
        'تم استلام طلبك رقم ' || NEW.order_number || ' وسيتم مراجعته قريباً',
        'order_created',
        NEW.client_id,
        'client'
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ربط الـ trigger بجدول الطلبات
CREATE TRIGGER trigger_new_order
    BEFORE INSERT ON public.client_orders
    FOR EACH ROW EXECUTE FUNCTION handle_new_order();

-- ===== Trigger عند تحديث حالة الطلب =====
CREATE OR REPLACE FUNCTION handle_order_status_change()
RETURNS TRIGGER AS $$
DECLARE
    status_title TEXT;
    status_message TEXT;
    status_message_client TEXT;
BEGIN
    -- التحقق من تغيير الحالة
    IF OLD.status != NEW.status THEN
        -- إضافة سجل في تاريخ الطلب
        PERFORM add_order_history(
            NEW.id, 'status_changed', OLD.status, NEW.status,
            'تم تغيير حالة الطلب من ' || OLD.status || ' إلى ' || NEW.status,
            auth.uid(), 
            (SELECT name FROM public.user_profiles WHERE id = auth.uid()),
            (SELECT role FROM public.user_profiles WHERE id = auth.uid())
        );
        
        -- إعداد رسائل الإشعار حسب الحالة الجديدة
        CASE NEW.status
            WHEN 'confirmed' THEN
                status_title := 'تم تأكيد الطلب: ' || NEW.order_number;
                status_message := 'تم تأكيد الطلب ' || NEW.order_number || ' من قبل الإدارة';
                status_message_client := 'تم تأكيد طلبك رقم ' || NEW.order_number || ' وسيتم تحضيره قريباً';
                
            WHEN 'processing' THEN
                status_title := 'جاري تحضير الطلب: ' || NEW.order_number;
                status_message := 'جاري تحضير الطلب ' || NEW.order_number;
                status_message_client := 'جاري تحضير طلبك رقم ' || NEW.order_number;
                
            WHEN 'shipped' THEN
                status_title := 'تم شحن الطلب: ' || NEW.order_number;
                status_message := 'تم شحن الطلب ' || NEW.order_number;
                status_message_client := 'تم شحن طلبك رقم ' || NEW.order_number;
                
            WHEN 'delivered' THEN
                status_title := 'تم توصيل الطلب: ' || NEW.order_number;
                status_message := 'تم توصيل الطلب ' || NEW.order_number || ' بنجاح';
                status_message_client := 'تم توصيل طلبك رقم ' || NEW.order_number || ' بنجاح';
                NEW.completed_at := NOW();
                
            WHEN 'cancelled' THEN
                status_title := 'تم إلغاء الطلب: ' || NEW.order_number;
                status_message := 'تم إلغاء الطلب ' || NEW.order_number;
                status_message_client := 'تم إلغاء طلبك رقم ' || NEW.order_number;
                NEW.cancelled_at := NOW();
                
            ELSE
                status_title := 'تحديث حالة الطلب: ' || NEW.order_number;
                status_message := 'تم تحديث حالة الطلب ' || NEW.order_number || ' إلى ' || NEW.status;
                status_message_client := 'تم تحديث حالة طلبك رقم ' || NEW.order_number;
        END CASE;
        
        -- إرسال إشعارات للإدارة
        PERFORM notify_staff_about_order(
            NEW.id, status_title, status_message, 'status_changed'
        );
        
        -- إرسال إشعار للعميل
        PERFORM create_order_notification(
            NEW.id, 
            status_title,
            status_message_client,
            'status_changed',
            NEW.client_id,
            'client'
        );
    END IF;
    
    -- التحقق من تغيير حالة الدفع
    IF OLD.payment_status != NEW.payment_status THEN
        -- إضافة سجل في تاريخ الطلب
        PERFORM add_order_history(
            NEW.id, 'payment_updated', OLD.payment_status, NEW.payment_status,
            'تم تحديث حالة الدفع من ' || OLD.payment_status || ' إلى ' || NEW.payment_status,
            auth.uid(),
            (SELECT name FROM public.user_profiles WHERE id = auth.uid()),
            (SELECT role FROM public.user_profiles WHERE id = auth.uid())
        );
        
        -- إرسال إشعار عند تأكيد الدفع
        IF NEW.payment_status = 'paid' THEN
            PERFORM notify_staff_about_order(
                NEW.id, 
                'تم تأكيد الدفع: ' || NEW.order_number,
                'تم تأكيد دفع الطلب ' || NEW.order_number,
                'payment_received'
            );
            
            PERFORM create_order_notification(
                NEW.id,
                'تم تأكيد الدفع',
                'تم تأكيد دفع طلبك رقم ' || NEW.order_number,
                'payment_received',
                NEW.client_id,
                'client'
            );
        END IF;
    END IF;
    
    -- التحقق من تعيين موظف
    IF (OLD.assigned_to IS NULL AND NEW.assigned_to IS NOT NULL) OR 
       (OLD.assigned_to != NEW.assigned_to) THEN
        
        -- إضافة سجل في تاريخ الطلب
        PERFORM add_order_history(
            NEW.id, 'assigned', NULL, NULL,
            'تم تعيين الطلب للموظف',
            NEW.assigned_by,
            (SELECT name FROM public.user_profiles WHERE id = NEW.assigned_by),
            (SELECT role FROM public.user_profiles WHERE id = NEW.assigned_by)
        );
        
        -- إرسال إشعار للموظف المعين
        IF NEW.assigned_to IS NOT NULL THEN
            PERFORM create_order_notification(
                NEW.id,
                'تم تعيين طلب جديد لك',
                'تم تعيين الطلب رقم ' || NEW.order_number || ' لك',
                'status_changed',
                NEW.assigned_to,
                (SELECT role FROM public.user_profiles WHERE id = NEW.assigned_to)
            );
        END IF;
        
        NEW.assigned_at := NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ربط الـ trigger بجدول الطلبات
CREATE TRIGGER trigger_order_status_change
    BEFORE UPDATE ON public.client_orders
    FOR EACH ROW EXECUTE FUNCTION handle_order_status_change();

-- ===== Trigger عند إضافة رابط تتبع =====
CREATE OR REPLACE FUNCTION handle_new_tracking_link()
RETURNS TRIGGER AS $$
BEGIN
    -- إضافة سجل في تاريخ الطلب
    PERFORM add_order_history(
        NEW.order_id, 'tracking_added', NULL, NULL,
        'تم إضافة رابط تتبع: ' || NEW.title,
        NEW.created_by, NEW.created_by_name,
        (SELECT role FROM public.user_profiles WHERE id = NEW.created_by)
    );
    
    -- إرسال إشعار للعميل
    PERFORM create_order_notification(
        NEW.order_id,
        'تم إضافة رابط تتبع',
        'تم إضافة رابط تتبع جديد لطلبك: ' || NEW.title,
        'tracking_added',
        (SELECT client_id FROM public.client_orders WHERE id = NEW.order_id),
        'client'
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ربط الـ trigger بجدول روابط التتبع
CREATE TRIGGER trigger_new_tracking_link
    AFTER INSERT ON public.order_tracking_links
    FOR EACH ROW EXECUTE FUNCTION handle_new_tracking_link();

-- ===== دالة لحساب إحصائيات الطلبات =====
CREATE OR REPLACE FUNCTION get_order_statistics(
    start_date DATE DEFAULT NULL,
    end_date DATE DEFAULT NULL
)
RETURNS TABLE(
    total_orders INTEGER,
    pending_orders INTEGER,
    confirmed_orders INTEGER,
    processing_orders INTEGER,
    shipped_orders INTEGER,
    delivered_orders INTEGER,
    cancelled_orders INTEGER,
    total_revenue DECIMAL(10,2),
    average_order_value DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_orders,
        COUNT(CASE WHEN status = 'pending' THEN 1 END)::INTEGER as pending_orders,
        COUNT(CASE WHEN status = 'confirmed' THEN 1 END)::INTEGER as confirmed_orders,
        COUNT(CASE WHEN status = 'processing' THEN 1 END)::INTEGER as processing_orders,
        COUNT(CASE WHEN status = 'shipped' THEN 1 END)::INTEGER as shipped_orders,
        COUNT(CASE WHEN status = 'delivered' THEN 1 END)::INTEGER as delivered_orders,
        COUNT(CASE WHEN status = 'cancelled' THEN 1 END)::INTEGER as cancelled_orders,
        COALESCE(SUM(CASE WHEN status != 'cancelled' THEN total_amount END), 0) as total_revenue,
        COALESCE(AVG(CASE WHEN status != 'cancelled' THEN total_amount END), 0) as average_order_value
    FROM public.client_orders
    WHERE (start_date IS NULL OR DATE(created_at) >= start_date)
      AND (end_date IS NULL OR DATE(created_at) <= end_date);
END;
$$ LANGUAGE plpgsql;
