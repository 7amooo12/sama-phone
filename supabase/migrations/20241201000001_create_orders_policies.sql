-- إنشاء سياسات الأمان (RLS Policies) لنظام الطلبات
-- Migration: Create RLS policies for orders system

-- ===== سياسات جدول الطلبات الرئيسي =====

-- العملاء يمكنهم رؤية طلباتهم فقط
CREATE POLICY "clients_can_view_own_orders" ON public.client_orders
    FOR SELECT USING (
        auth.uid() = client_id
    );

-- العملاء يمكنهم إنشاء طلبات جديدة
CREATE POLICY "clients_can_create_orders" ON public.client_orders
    FOR INSERT WITH CHECK (
        auth.uid() = client_id
    );

-- الإدارة والمحاسبين يمكنهم رؤية جميع الطلبات
CREATE POLICY "admins_can_view_all_orders" ON public.client_orders
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'accountant', 'manager')
        )
    );

-- الإدارة يمكنها تحديث الطلبات
CREATE POLICY "admins_can_update_orders" ON public.client_orders
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'manager')
        )
    );

-- الموظفين المعينين يمكنهم رؤية وتحديث طلباتهم المعينة
CREATE POLICY "assigned_staff_can_view_orders" ON public.client_orders
    FOR SELECT USING (
        auth.uid() = assigned_to
    );

CREATE POLICY "assigned_staff_can_update_orders" ON public.client_orders
    FOR UPDATE USING (
        auth.uid() = assigned_to
    );

-- ===== سياسات جدول عناصر الطلب =====

-- العملاء يمكنهم رؤية عناصر طلباتهم
CREATE POLICY "clients_can_view_own_order_items" ON public.client_order_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.client_orders
            WHERE client_orders.id = order_id 
            AND client_orders.client_id = auth.uid()
        )
    );

-- العملاء يمكنهم إضافة عناصر لطلباتهم الجديدة
CREATE POLICY "clients_can_create_order_items" ON public.client_order_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.client_orders
            WHERE client_orders.id = order_id 
            AND client_orders.client_id = auth.uid()
            AND client_orders.status = 'pending'
        )
    );

-- الإدارة يمكنها رؤية جميع عناصر الطلبات
CREATE POLICY "admins_can_view_all_order_items" ON public.client_order_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'accountant', 'manager')
        )
    );

-- الإدارة يمكنها تحديث عناصر الطلبات
CREATE POLICY "admins_can_update_order_items" ON public.client_order_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'manager')
        )
    );

-- الموظفين المعينين يمكنهم رؤية عناصر طلباتهم المعينة
CREATE POLICY "assigned_staff_can_view_order_items" ON public.client_order_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.client_orders
            WHERE client_orders.id = order_id 
            AND client_orders.assigned_to = auth.uid()
        )
    );

-- ===== سياسات جدول روابط التتبع =====

-- العملاء يمكنهم رؤية روابط تتبع طلباتهم
CREATE POLICY "clients_can_view_own_tracking_links" ON public.order_tracking_links
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.client_orders
            WHERE client_orders.id = order_id 
            AND client_orders.client_id = auth.uid()
        )
    );

-- الإدارة والموظفين يمكنهم إضافة روابط التتبع
CREATE POLICY "staff_can_create_tracking_links" ON public.order_tracking_links
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'manager', 'employee')
        )
    );

-- الإدارة يمكنها رؤية جميع روابط التتبع
CREATE POLICY "admins_can_view_all_tracking_links" ON public.order_tracking_links
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'accountant', 'manager')
        )
    );

-- الإدارة يمكنها تحديث روابط التتبع
CREATE POLICY "admins_can_update_tracking_links" ON public.order_tracking_links
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'manager')
        )
    );

-- منشئ الرابط يمكنه تحديثه
CREATE POLICY "creators_can_update_own_tracking_links" ON public.order_tracking_links
    FOR UPDATE USING (
        auth.uid() = created_by
    );

-- ===== سياسات جدول تاريخ الطلبات =====

-- العملاء يمكنهم رؤية تاريخ طلباتهم
CREATE POLICY "clients_can_view_own_order_history" ON public.order_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.client_orders
            WHERE client_orders.id = order_id 
            AND client_orders.client_id = auth.uid()
        )
    );

-- الإدارة يمكنها رؤية جميع تاريخ الطلبات
CREATE POLICY "admins_can_view_all_order_history" ON public.order_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'accountant', 'manager')
        )
    );

-- النظام يمكنه إضافة سجلات التاريخ (عبر الدوال)
CREATE POLICY "system_can_create_order_history" ON public.order_history
    FOR INSERT WITH CHECK (true);

-- الموظفين المعينين يمكنهم رؤية تاريخ طلباتهم المعينة
CREATE POLICY "assigned_staff_can_view_order_history" ON public.order_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.client_orders
            WHERE client_orders.id = order_id 
            AND client_orders.assigned_to = auth.uid()
        )
    );

-- ===== سياسات جدول إشعارات الطلبات =====

-- المستخدمين يمكنهم رؤية إشعاراتهم فقط
CREATE POLICY "users_can_view_own_notifications" ON public.order_notifications
    FOR SELECT USING (
        auth.uid() = recipient_id
    );

-- المستخدمين يمكنهم تحديث حالة قراءة إشعاراتهم
CREATE POLICY "users_can_update_own_notifications" ON public.order_notifications
    FOR UPDATE USING (
        auth.uid() = recipient_id
    );

-- النظام يمكنه إنشاء إشعارات (عبر الدوال والـ triggers)
CREATE POLICY "system_can_create_notifications" ON public.order_notifications
    FOR INSERT WITH CHECK (true);

-- الإدارة يمكنها رؤية جميع الإشعارات
CREATE POLICY "admins_can_view_all_notifications" ON public.order_notifications
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'manager')
        )
    );

-- ===== دوال مساعدة للتحقق من الصلاحيات =====

-- دالة للتحقق من كون المستخدم إدارياً
CREATE OR REPLACE FUNCTION is_admin(user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = user_id 
        AND role IN ('admin', 'manager')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للتحقق من كون المستخدم محاسباً
CREATE OR REPLACE FUNCTION is_accountant(user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = user_id 
        AND role IN ('admin', 'accountant', 'manager')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للتحقق من كون المستخدم موظفاً
CREATE OR REPLACE FUNCTION is_staff(user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = user_id 
        AND role IN ('admin', 'manager', 'employee', 'accountant')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
