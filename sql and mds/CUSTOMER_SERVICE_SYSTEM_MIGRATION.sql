-- Customer Service System Migration
-- This script updates the existing customer service system to make order_number optional
-- and adds admin response functionality

-- 1. Make order_number optional in product_returns table
ALTER TABLE public.product_returns 
ALTER COLUMN order_number DROP NOT NULL;

-- 2. Add admin_response_date column if it doesn't exist
ALTER TABLE public.product_returns 
ADD COLUMN IF NOT EXISTS admin_response_date TIMESTAMP WITH TIME ZONE;

-- 3. Add admin_response_date column to error_reports if it doesn't exist
ALTER TABLE public.error_reports 
ADD COLUMN IF NOT EXISTS admin_response_date TIMESTAMP WITH TIME ZONE;

-- 4. Update existing records with empty order_number to NULL
UPDATE public.product_returns 
SET order_number = NULL 
WHERE order_number = '' OR order_number IS NULL;

-- 5. Create indexes for better performance on admin response queries
CREATE INDEX IF NOT EXISTS idx_product_returns_admin_response_date ON public.product_returns(admin_response_date);
CREATE INDEX IF NOT EXISTS idx_error_reports_admin_response_date ON public.error_reports(admin_response_date);

-- 6. Create indexes for status filtering
CREATE INDEX IF NOT EXISTS idx_product_returns_status_created ON public.product_returns(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_error_reports_status_created ON public.error_reports(status, created_at DESC);

-- 7. Add RLS policies for customer access to their own requests
-- Drop existing policies if they exist, then create new ones
DROP POLICY IF EXISTS "Customers can view their own product returns" ON public.product_returns;
DROP POLICY IF EXISTS "Customers can view their own error reports" ON public.error_reports;

-- Policy for customers to view their own product returns
CREATE POLICY "Customers can view their own product returns" ON public.product_returns
    FOR SELECT USING (auth.uid() = customer_id);

-- Policy for customers to view their own error reports
CREATE POLICY "Customers can view their own error reports" ON public.error_reports
    FOR SELECT USING (auth.uid() = customer_id);

-- 8. Add function to automatically update admin_response_date when admin_response is added
CREATE OR REPLACE FUNCTION update_admin_response_date()
RETURNS TRIGGER AS $$
BEGIN
    -- Update admin_response_date when admin_response is added or updated
    IF NEW.admin_response IS NOT NULL AND NEW.admin_response != '' AND 
       (OLD.admin_response IS NULL OR OLD.admin_response = '' OR OLD.admin_response != NEW.admin_response) THEN
        NEW.admin_response_date = NOW();
    END IF;
    
    -- Update updated_at timestamp
    NEW.updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 9. Create triggers for both tables
DROP TRIGGER IF EXISTS trigger_update_product_returns_admin_response_date ON public.product_returns;
CREATE TRIGGER trigger_update_product_returns_admin_response_date
    BEFORE UPDATE ON public.product_returns
    FOR EACH ROW
    EXECUTE FUNCTION update_admin_response_date();

DROP TRIGGER IF EXISTS trigger_update_error_reports_admin_response_date ON public.error_reports;
CREATE TRIGGER trigger_update_error_reports_admin_response_date
    BEFORE UPDATE ON public.error_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_admin_response_date();

-- 10. Create function to get customer service statistics
CREATE OR REPLACE FUNCTION get_customer_service_stats()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'error_reports', json_build_object(
            'total', (SELECT COUNT(*) FROM public.error_reports),
            'pending', (SELECT COUNT(*) FROM public.error_reports WHERE status = 'pending'),
            'processing', (SELECT COUNT(*) FROM public.error_reports WHERE status = 'processing'),
            'resolved', (SELECT COUNT(*) FROM public.error_reports WHERE status = 'resolved'),
            'rejected', (SELECT COUNT(*) FROM public.error_reports WHERE status = 'rejected')
        ),
        'product_returns', json_build_object(
            'total', (SELECT COUNT(*) FROM public.product_returns),
            'pending', (SELECT COUNT(*) FROM public.product_returns WHERE status = 'pending'),
            'approved', (SELECT COUNT(*) FROM public.product_returns WHERE status = 'approved'),
            'rejected', (SELECT COUNT(*) FROM public.product_returns WHERE status = 'rejected'),
            'processing', (SELECT COUNT(*) FROM public.product_returns WHERE status = 'processing'),
            'completed', (SELECT COUNT(*) FROM public.product_returns WHERE status = 'completed')
        )
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_customer_service_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION update_admin_response_date() TO authenticated;

-- 12. Enable RLS on tables if not already enabled
ALTER TABLE public.product_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.error_reports ENABLE ROW LEVEL SECURITY;

-- 13. Create notification trigger function for new customer service requests
CREATE OR REPLACE FUNCTION notify_new_customer_service_request()
RETURNS TRIGGER AS $$
DECLARE
    admin_users RECORD;
    notification_title TEXT;
    notification_body TEXT;
    request_type TEXT;
BEGIN
    -- Determine request type and notification content
    IF TG_TABLE_NAME = 'product_returns' THEN
        request_type := 'product_return';
        notification_title := 'طلب إرجاع منتج جديد';
        notification_body := 'تم استلام طلب إرجاع جديد من ' || NEW.customer_name || ' للمنتج: ' || NEW.product_name;
    ELSIF TG_TABLE_NAME = 'error_reports' THEN
        request_type := 'error_report';
        notification_title := 'تقرير خطأ جديد';
        notification_body := 'تم استلام تقرير خطأ جديد من ' || NEW.customer_name || ': ' || NEW.title;
    END IF;

    -- Send notifications to all admin users
    FOR admin_users IN 
        SELECT id FROM auth.users 
        WHERE raw_user_meta_data->>'role' IN ('admin', 'owner')
    LOOP
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            type,
            category,
            priority,
            reference_id,
            reference_type,
            route,
            created_at
        ) VALUES (
            admin_users.id,
            notification_title,
            notification_body,
            'customer_service_request',
            'customer_service',
            'normal',
            NEW.id::TEXT,
            request_type,
            '/admin/customer-service',
            NOW()
        );
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 14. Create triggers for new request notifications
DROP TRIGGER IF EXISTS trigger_notify_new_product_return ON public.product_returns;
CREATE TRIGGER trigger_notify_new_product_return
    AFTER INSERT ON public.product_returns
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_customer_service_request();

DROP TRIGGER IF EXISTS trigger_notify_new_error_report ON public.error_reports;
CREATE TRIGGER trigger_notify_new_error_report
    AFTER INSERT ON public.error_reports
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_customer_service_request();

-- 15. Create notification trigger for status updates
CREATE OR REPLACE FUNCTION notify_customer_service_status_update()
RETURNS TRIGGER AS $$
DECLARE
    notification_title TEXT;
    notification_body TEXT;
    request_type TEXT;
BEGIN
    -- Only notify if status actually changed
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    -- Determine request type and notification content
    IF TG_TABLE_NAME = 'product_returns' THEN
        request_type := 'product_return';
        notification_title := 'تحديث حالة طلب الإرجاع';
        notification_body := 'تم تحديث حالة طلب إرجاع المنتج "' || NEW.product_name || '" إلى: ' || 
                           CASE NEW.status 
                               WHEN 'approved' THEN 'موافق عليه'
                               WHEN 'rejected' THEN 'مرفوض'
                               WHEN 'processing' THEN 'قيد المعالجة'
                               WHEN 'completed' THEN 'مكتمل'
                               ELSE NEW.status
                           END;
    ELSIF TG_TABLE_NAME = 'error_reports' THEN
        request_type := 'error_report';
        notification_title := 'تحديث حالة تقرير الخطأ';
        notification_body := 'تم تحديث حالة تقرير الخطأ "' || NEW.title || '" إلى: ' || 
                           CASE NEW.status 
                               WHEN 'processing' THEN 'قيد المعالجة'
                               WHEN 'resolved' THEN 'تم الحل'
                               WHEN 'rejected' THEN 'مرفوض'
                               ELSE NEW.status
                           END;
    END IF;

    -- Send notification to customer
    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        category,
        priority,
        reference_id,
        reference_type,
        route,
        created_at
    ) VALUES (
        NEW.customer_id,
        notification_title,
        notification_body,
        'customer_service_update',
        'customer_service',
        'normal',
        NEW.id::TEXT,
        request_type,
        '/customer/requests',
        NOW()
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 16. Create triggers for status update notifications
DROP TRIGGER IF EXISTS trigger_notify_product_return_status_update ON public.product_returns;
CREATE TRIGGER trigger_notify_product_return_status_update
    AFTER UPDATE ON public.product_returns
    FOR EACH ROW
    EXECUTE FUNCTION notify_customer_service_status_update();

DROP TRIGGER IF EXISTS trigger_notify_error_report_status_update ON public.error_reports;
CREATE TRIGGER trigger_notify_error_report_status_update
    AFTER UPDATE ON public.error_reports
    FOR EACH ROW
    EXECUTE FUNCTION notify_customer_service_status_update();

-- 17. Grant permissions for notification functions
GRANT EXECUTE ON FUNCTION notify_new_customer_service_request() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_customer_service_status_update() TO authenticated;

COMMENT ON FUNCTION get_customer_service_stats() IS 'Returns statistics for customer service requests';
COMMENT ON FUNCTION update_admin_response_date() IS 'Automatically updates admin_response_date when admin responds';
COMMENT ON FUNCTION notify_new_customer_service_request() IS 'Sends notifications to admins when new customer service requests are created';
COMMENT ON FUNCTION notify_customer_service_status_update() IS 'Sends notifications to customers when request status is updated';
