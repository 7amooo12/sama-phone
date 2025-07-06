-- Enhanced Notification Triggers for SmartBizTracker
-- Intelligent notification system with role-based targeting and contextual messaging
-- Production-ready triggers for all notification scenarios

BEGIN;

-- ============================================================================
-- CORE NOTIFICATION CREATION FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION create_smart_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_type TEXT,
    p_category TEXT,
    p_priority TEXT DEFAULT 'normal',
    p_route TEXT DEFAULT NULL,
    p_reference_id TEXT DEFAULT NULL,
    p_reference_type TEXT DEFAULT NULL,
    p_action_data JSONB DEFAULT '{}',
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    notification_id UUID;
BEGIN
    INSERT INTO public.notifications (
        user_id, title, body, type, category, priority,
        route, reference_id, reference_type, action_data, metadata
    ) VALUES (
        p_user_id, p_title, p_body, p_type, p_category, p_priority,
        p_route, p_reference_id, p_reference_type, p_action_data, p_metadata
    ) RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- ROLE-BASED NOTIFICATION DISTRIBUTION
-- ============================================================================

-- Function to notify all users with specific roles
CREATE OR REPLACE FUNCTION notify_users_by_role(
    p_roles TEXT[],
    p_title TEXT,
    p_body TEXT,
    p_type TEXT,
    p_category TEXT,
    p_priority TEXT DEFAULT 'normal',
    p_route TEXT DEFAULT NULL,
    p_reference_id TEXT DEFAULT NULL,
    p_reference_type TEXT DEFAULT NULL,
    p_action_data JSONB DEFAULT '{}',
    p_metadata JSONB DEFAULT '{}'
)
RETURNS INTEGER AS $$
DECLARE
    user_record RECORD;
    notification_count INTEGER := 0;
BEGIN
    FOR user_record IN 
        SELECT id, role FROM public.user_profiles 
        WHERE role = ANY(p_roles)
        AND id IS NOT NULL
    LOOP
        PERFORM create_smart_notification(
            user_record.id, p_title, p_body, p_type, p_category, p_priority,
            p_route, p_reference_id, p_reference_type, p_action_data, p_metadata
        );
        notification_count := notification_count + 1;
    END LOOP;
    
    RETURN notification_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- ORDER NOTIFICATION TRIGGERS
-- ============================================================================

-- Enhanced order creation trigger
CREATE OR REPLACE FUNCTION handle_order_notifications()
RETURNS TRIGGER AS $$
DECLARE
    order_title TEXT;
    order_message TEXT;
    staff_title TEXT;
    staff_message TEXT;
BEGIN
    -- Handle new order creation
    IF TG_OP = 'INSERT' THEN
        -- Client notification
        order_title := 'تم إنشاء طلبك بنجاح';
        order_message := 'تم استلام طلبك رقم ' || NEW.order_number || ' بقيمة ' || 
                        NEW.total_amount || ' جنيه وسيتم مراجعته قريباً';
        
        PERFORM create_smart_notification(
            NEW.client_id,
            order_title,
            order_message,
            'order_created',
            'orders',
            'normal',
            '/orders/' || NEW.id,
            NEW.id::TEXT,
            'order',
            jsonb_build_object('order_number', NEW.order_number, 'amount', NEW.total_amount),
            jsonb_build_object('currency', 'EGP')
        );
        
        -- Staff notifications
        staff_title := 'طلب جديد: ' || NEW.order_number;
        staff_message := 'تم استلام طلب جديد من العميل ' || NEW.client_name || 
                        ' بقيمة ' || NEW.total_amount || ' جنيه';
        
        PERFORM notify_users_by_role(
            ARRAY['admin', 'manager', 'accountant', 'owner'],
            staff_title,
            staff_message,
            'order_created',
            'orders',
            'high',
            '/admin/orders/' || NEW.id,
            NEW.id::TEXT,
            'order',
            jsonb_build_object('order_number', NEW.order_number, 'client_name', NEW.client_name, 'amount', NEW.total_amount),
            jsonb_build_object('currency', 'EGP', 'requires_action', true)
        );
        
        RETURN NEW;
    END IF;
    
    -- Handle order status changes
    IF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
        -- Client notification for status change
        order_title := 'تم تحديث حالة طلبك';
        order_message := 'تم تحديث حالة طلبك رقم ' || NEW.order_number || ' إلى: ' || 
                        CASE NEW.status
                            WHEN 'confirmed' THEN 'مؤكد'
                            WHEN 'processing' THEN 'قيد التجهيز'
                            WHEN 'shipped' THEN 'تم الشحن'
                            WHEN 'delivered' THEN 'تم التسليم'
                            WHEN 'completed' THEN 'مكتمل'
                            WHEN 'cancelled' THEN 'ملغي'
                            ELSE NEW.status
                        END;
        
        PERFORM create_smart_notification(
            NEW.client_id,
            order_title,
            order_message,
            'order_status_changed',
            'orders',
            CASE WHEN NEW.status IN ('completed', 'delivered') THEN 'high' ELSE 'normal' END,
            '/orders/' || NEW.id,
            NEW.id::TEXT,
            'order',
            jsonb_build_object('order_number', NEW.order_number, 'old_status', OLD.status, 'new_status', NEW.status),
            jsonb_build_object('currency', 'EGP')
        );
        
        -- Staff notification for important status changes
        IF NEW.status IN ('completed', 'cancelled', 'delivered') THEN
            staff_title := 'تحديث حالة الطلب: ' || NEW.order_number;
            staff_message := 'تم تحديث حالة الطلب ' || NEW.order_number || ' إلى: ' || 
                            CASE NEW.status
                                WHEN 'completed' THEN 'مكتمل'
                                WHEN 'delivered' THEN 'تم التسليم'
                                WHEN 'cancelled' THEN 'ملغي'
                                ELSE NEW.status
                            END;
            
            PERFORM notify_users_by_role(
                ARRAY['admin', 'manager', 'accountant', 'owner'],
                staff_title,
                staff_message,
                'order_status_changed',
                'orders',
                'normal',
                '/admin/orders/' || NEW.id,
                NEW.id::TEXT,
                'order',
                jsonb_build_object('order_number', NEW.order_number, 'old_status', OLD.status, 'new_status', NEW.status),
                jsonb_build_object('currency', 'EGP')
            );
        END IF;
        
        RETURN NEW;
    END IF;
    
    -- Handle payment status changes
    IF TG_OP = 'UPDATE' AND OLD.payment_status != NEW.payment_status AND NEW.payment_status = 'paid' THEN
        -- Client notification
        PERFORM create_smart_notification(
            NEW.client_id,
            'تم تأكيد الدفع',
            'تم تأكيد دفع طلبك رقم ' || NEW.order_number || ' بقيمة ' || NEW.total_amount || ' جنيه',
            'payment_received',
            'orders',
            'high',
            '/orders/' || NEW.id,
            NEW.id::TEXT,
            'order',
            jsonb_build_object('order_number', NEW.order_number, 'amount', NEW.total_amount),
            jsonb_build_object('currency', 'EGP', 'payment_confirmed', true)
        );
        
        -- Staff notification
        PERFORM notify_users_by_role(
            ARRAY['admin', 'manager', 'accountant', 'owner'],
            'تم تأكيد الدفع: ' || NEW.order_number,
            'تم تأكيد دفع الطلب ' || NEW.order_number || ' بقيمة ' || NEW.total_amount || ' جنيه',
            'payment_received',
            'orders',
            'high',
            '/admin/orders/' || NEW.id,
            NEW.id::TEXT,
            'order',
            jsonb_build_object('order_number', NEW.order_number, 'amount', NEW.total_amount),
            jsonb_build_object('currency', 'EGP', 'payment_confirmed', true)
        );
        
        RETURN NEW;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create order notification triggers
DROP TRIGGER IF EXISTS trigger_order_notifications ON public.client_orders;
CREATE TRIGGER trigger_order_notifications
    AFTER INSERT OR UPDATE ON public.client_orders
    FOR EACH ROW
    EXECUTE FUNCTION handle_order_notifications();

-- ============================================================================
-- VOUCHER NOTIFICATION TRIGGERS
-- ============================================================================

-- Voucher assignment notification
CREATE OR REPLACE FUNCTION handle_voucher_assignment()
RETURNS TRIGGER AS $$
DECLARE
    voucher_info RECORD;
    client_name TEXT;
BEGIN
    -- Get voucher details
    SELECT v.name, v.description, v.discount_percentage, v.expiration_date
    INTO voucher_info
    FROM public.vouchers v
    WHERE v.id = NEW.voucher_id;
    
    -- Get client name
    SELECT up.name INTO client_name
    FROM public.user_profiles up
    WHERE up.id = NEW.client_id;
    
    -- Notify client about voucher assignment
    PERFORM create_smart_notification(
        NEW.client_id,
        'تم منحك قسيمة خصم جديدة!',
        'تم منحك قسيمة خصم "' || voucher_info.name || '" بخصم ' || 
        voucher_info.discount_percentage || '% صالحة حتى ' || 
        TO_CHAR(voucher_info.expiration_date, 'YYYY-MM-DD'),
        'voucher_assigned',
        'vouchers',
        'high',
        '/vouchers',
        NEW.voucher_id::TEXT,
        'voucher',
        jsonb_build_object(
            'voucher_name', voucher_info.name,
            'discount_percentage', voucher_info.discount_percentage,
            'expiration_date', voucher_info.expiration_date
        ),
        jsonb_build_object('currency', 'EGP', 'action_required', false)
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create voucher assignment trigger
DROP TRIGGER IF EXISTS trigger_voucher_assignment ON public.client_vouchers;
CREATE TRIGGER trigger_voucher_assignment
    AFTER INSERT ON public.client_vouchers
    FOR EACH ROW
    EXECUTE FUNCTION handle_voucher_assignment();

-- ============================================================================
-- WORKER TASK NOTIFICATION TRIGGERS
-- ============================================================================

-- Task assignment notification
CREATE OR REPLACE FUNCTION handle_task_assignment()
RETURNS TRIGGER AS $$
DECLARE
    worker_name TEXT;
    admin_name TEXT;
BEGIN
    -- Get worker name
    SELECT name INTO worker_name
    FROM public.user_profiles
    WHERE id = NEW.assigned_to;

    -- Get admin name
    SELECT name INTO admin_name
    FROM public.user_profiles
    WHERE id = NEW.assigned_by;

    -- Notify worker about task assignment
    PERFORM create_smart_notification(
        NEW.assigned_to,
        'تم تعيين مهمة جديدة لك',
        'تم تعيين مهمة جديدة لك: "' || NEW.title || '" من قبل ' || COALESCE(admin_name, 'الإدارة') ||
        CASE WHEN NEW.due_date IS NOT NULL THEN ' - موعد التسليم: ' || TO_CHAR(NEW.due_date, 'YYYY-MM-DD') ELSE '' END,
        'task_assigned',
        'tasks',
        CASE WHEN NEW.priority = 'high' THEN 'high' ELSE 'normal' END,
        '/worker/tasks/' || NEW.id,
        NEW.id::TEXT,
        'task',
        jsonb_build_object(
            'task_title', NEW.title,
            'priority', NEW.priority,
            'due_date', NEW.due_date,
            'assigned_by', admin_name
        ),
        jsonb_build_object('requires_action', true)
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Task completion notification
CREATE OR REPLACE FUNCTION handle_task_completion()
RETURNS TRIGGER AS $$
DECLARE
    task_info RECORD;
    worker_name TEXT;
BEGIN
    -- Only trigger on status change to completed
    IF TG_OP = 'UPDATE' AND OLD.status != NEW.status AND NEW.status = 'completed' THEN
        -- Get task and worker details
        SELECT wt.title, wt.assigned_by, up.name as worker_name
        INTO task_info
        FROM public.worker_tasks wt
        JOIN public.user_profiles up ON up.id = wt.assigned_to
        WHERE wt.id = NEW.id;

        -- Notify admin/manager about task completion
        PERFORM notify_users_by_role(
            ARRAY['admin', 'manager', 'owner'],
            'تم إكمال مهمة: ' || task_info.title,
            'تم إكمال المهمة "' || task_info.title || '" بواسطة ' || task_info.worker_name,
            'task_completed',
            'tasks',
            'normal',
            '/admin/tasks/' || NEW.id,
            NEW.id::TEXT,
            'task',
            jsonb_build_object(
                'task_title', task_info.title,
                'worker_name', task_info.worker_name,
                'completed_at', NEW.updated_at
            ),
            jsonb_build_object('requires_review', true)
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create task notification triggers
DROP TRIGGER IF EXISTS trigger_task_assignment ON public.worker_tasks;
CREATE TRIGGER trigger_task_assignment
    AFTER INSERT ON public.worker_tasks
    FOR EACH ROW
    EXECUTE FUNCTION handle_task_assignment();

DROP TRIGGER IF EXISTS trigger_task_completion ON public.worker_tasks;
CREATE TRIGGER trigger_task_completion
    AFTER UPDATE ON public.worker_tasks
    FOR EACH ROW
    EXECUTE FUNCTION handle_task_completion();

-- ============================================================================
-- WORKER REWARD NOTIFICATION TRIGGERS
-- ============================================================================

-- Reward/penalty notification
CREATE OR REPLACE FUNCTION handle_worker_reward()
RETURNS TRIGGER AS $$
DECLARE
    worker_name TEXT;
    admin_name TEXT;
    notification_title TEXT;
    notification_body TEXT;
    notification_type TEXT;
    notification_priority TEXT;
BEGIN
    -- Get worker and admin names
    SELECT name INTO worker_name FROM public.user_profiles WHERE id = NEW.worker_id;
    SELECT name INTO admin_name FROM public.user_profiles WHERE id = NEW.awarded_by;

    -- Determine notification content based on reward type and amount
    IF NEW.amount > 0 THEN
        IF NEW.reward_type = 'bonus' THEN
            notification_title := 'تم منحك مكافأة!';
            notification_body := 'تم منحك مكافأة بقيمة ' || NEW.amount || ' جنيه';
            notification_type := 'bonus_awarded';
            notification_priority := 'high';
        ELSIF NEW.reward_type = 'commission' THEN
            notification_title := 'تم منحك عمولة!';
            notification_body := 'تم منحك عمولة بقيمة ' || NEW.amount || ' جنيه';
            notification_type := 'reward_received';
            notification_priority := 'high';
        ELSE
            notification_title := 'تم إضافة مبلغ لحسابك';
            notification_body := 'تم إضافة ' || NEW.amount || ' جنيه لحسابك';
            notification_type := 'reward_received';
            notification_priority := 'normal';
        END IF;
    ELSE
        notification_title := 'تم خصم مبلغ من حسابك';
        notification_body := 'تم خصم ' || ABS(NEW.amount) || ' جنيه من حسابك';
        notification_type := 'penalty_applied';
        notification_priority := 'high';
    END IF;

    -- Add description if provided
    IF NEW.description IS NOT NULL AND NEW.description != '' THEN
        notification_body := notification_body || ' - ' || NEW.description;
    END IF;

    -- Notify worker
    PERFORM create_smart_notification(
        NEW.worker_id,
        notification_title,
        notification_body,
        notification_type,
        'rewards',
        notification_priority,
        '/worker/rewards',
        NEW.id::TEXT,
        'reward',
        jsonb_build_object(
            'amount', NEW.amount,
            'reward_type', NEW.reward_type,
            'description', NEW.description,
            'awarded_by', admin_name
        ),
        jsonb_build_object('currency', 'EGP')
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create reward notification trigger
DROP TRIGGER IF EXISTS trigger_worker_reward ON public.worker_rewards;
CREATE TRIGGER trigger_worker_reward
    AFTER INSERT ON public.worker_rewards
    FOR EACH ROW
    EXECUTE FUNCTION handle_worker_reward();

-- ============================================================================
-- INVENTORY NOTIFICATION TRIGGERS
-- ============================================================================

-- Product inventory update notification
CREATE OR REPLACE FUNCTION handle_inventory_update()
RETURNS TRIGGER AS $$
DECLARE
    clients_cursor CURSOR FOR
        SELECT DISTINCT id FROM public.user_profiles WHERE role = 'client';
    client_record RECORD;
BEGIN
    -- Notify clients about new product arrivals (inventory increase)
    IF TG_OP = 'UPDATE' AND NEW.stock_quantity > OLD.stock_quantity AND OLD.stock_quantity = 0 THEN
        -- Product is back in stock - notify all clients
        FOR client_record IN clients_cursor LOOP
            PERFORM create_smart_notification(
                client_record.id,
                'منتج جديد متوفر!',
                'المنتج "' || NEW.name || '" أصبح متوفراً الآن في المتجر',
                'inventory_updated',
                'inventory',
                'normal',
                '/products/' || NEW.id,
                NEW.id::TEXT,
                'product',
                jsonb_build_object(
                    'product_name', NEW.name,
                    'stock_quantity', NEW.stock_quantity,
                    'price', NEW.price
                ),
                jsonb_build_object('currency', 'EGP', 'new_arrival', true)
            );
        END LOOP;
    END IF;

    -- Notify staff about low inventory
    IF NEW.stock_quantity <= 5 AND NEW.stock_quantity > 0 THEN
        PERFORM notify_users_by_role(
            ARRAY['admin', 'manager', 'owner', 'warehouseManager'],
            'تحذير: مخزون منخفض',
            'المنتج "' || NEW.name || '" يحتاج إعادة تموين - الكمية المتبقية: ' || NEW.stock_quantity,
            'inventory_low',
            'inventory',
            'high',
            '/admin/products/' || NEW.id,
            NEW.id::TEXT,
            'product',
            jsonb_build_object(
                'product_name', NEW.name,
                'stock_quantity', NEW.stock_quantity,
                'threshold', 5
            ),
            jsonb_build_object('requires_action', true)
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create inventory notification trigger
DROP TRIGGER IF EXISTS trigger_inventory_update ON public.products;
CREATE TRIGGER trigger_inventory_update
    AFTER UPDATE ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION handle_inventory_update();

COMMIT;
