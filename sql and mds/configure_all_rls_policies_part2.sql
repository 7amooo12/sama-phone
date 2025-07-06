-- Comprehensive RLS Configuration for SmartBizTracker
-- Part 2: Tables 6-12
-- Execute this script AFTER running Part 1

BEGIN;

-- 6. ORDER_ITEMS
ALTER TABLE public.order_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view all order items" ON public.order_items;
DROP POLICY IF EXISTS "Users can view their own order items" ON public.order_items;

CREATE POLICY "Admins can view all order items" ON public.order_items
FOR SELECT TO authenticated USING (public.is_admin());

CREATE POLICY "Users can view their own order items" ON public.order_items
FOR SELECT TO authenticated USING (user_id = auth.uid());

-- 7. ORDER_NOTIFICATIONS
ALTER TABLE public.order_notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admins_can_view_all_notifications" ON public.order_notifications;
DROP POLICY IF EXISTS "system_can_create_notifications" ON public.order_notifications;
DROP POLICY IF EXISTS "users_can_update_own_notifications" ON public.order_notifications;
DROP POLICY IF EXISTS "users_can_view_own_notifications" ON public.order_notifications;

CREATE POLICY "admins_can_view_all_notifications" ON public.order_notifications
FOR SELECT TO authenticated USING (auth.is_admin());

CREATE POLICY "system_can_create_notifications" ON public.order_notifications
FOR INSERT TO service_role WITH CHECK (true);

CREATE POLICY "users_can_update_own_notifications" ON public.order_notifications
FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_can_view_own_notifications" ON public.order_notifications
FOR SELECT TO authenticated USING (user_id = auth.uid());

-- 8. ORDER_TRACKING_LINKS
ALTER TABLE public.order_tracking_links DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_tracking_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admins_can_update_tracking_links" ON public.order_tracking_links;
DROP POLICY IF EXISTS "admins_can_view_all_tracking_links" ON public.order_tracking_links;
DROP POLICY IF EXISTS "clients_can_view_own_tracking_links" ON public.order_tracking_links;
DROP POLICY IF EXISTS "creators_can_update_own_tracking_links" ON public.order_tracking_links;
DROP POLICY IF EXISTS "staff_can_create_tracking_links" ON public.order_tracking_links;

CREATE POLICY "admins_can_update_tracking_links" ON public.order_tracking_links
FOR UPDATE TO authenticated USING (auth.is_admin()) WITH CHECK (auth.is_admin());

CREATE POLICY "admins_can_view_all_tracking_links" ON public.order_tracking_links
FOR SELECT TO authenticated USING (auth.is_admin());

CREATE POLICY "clients_can_view_own_tracking_links" ON public.order_tracking_links
FOR SELECT TO authenticated USING (auth.is_client() AND user_id = auth.uid());

CREATE POLICY "creators_can_update_own_tracking_links" ON public.order_tracking_links
FOR UPDATE TO authenticated USING (created_by = auth.uid()) WITH CHECK (created_by = auth.uid());

CREATE POLICY "staff_can_create_tracking_links" ON public.order_tracking_links
FOR INSERT TO authenticated WITH CHECK (auth.is_worker());

-- 9. ORDERS
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can update all orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can view all orders" ON public.orders;
DROP POLICY IF EXISTS "Users can insert their own orders" ON public.orders;
DROP POLICY IF EXISTS "Users can view their own orders" ON public.orders;

CREATE POLICY "Admins can update all orders" ON public.orders
FOR UPDATE TO authenticated USING (auth.is_admin()) WITH CHECK (auth.is_admin());

CREATE POLICY "Admins can view all orders" ON public.orders
FOR SELECT TO authenticated USING (auth.is_admin());

CREATE POLICY "Users can insert their own orders" ON public.orders
FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Users can view their own orders" ON public.orders
FOR SELECT TO authenticated USING (user_id = auth.uid());

-- 10. PRODUCTS
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage products" ON public.products;
DROP POLICY IF EXISTS "Products are viewable by everyone" ON public.products;

CREATE POLICY "Admins can manage products" ON public.products
FOR ALL TO authenticated USING (auth.is_admin()) WITH CHECK (auth.is_admin());

CREATE POLICY "Products are viewable by everyone" ON public.products
FOR SELECT USING (true);

-- 11. TASK_FEEDBACK (Priority - currently has RLS enabled but no policies)
-- Keep RLS enabled and create policies
DROP POLICY IF EXISTS "Admins can manage all feedback" ON public.task_feedback;
DROP POLICY IF EXISTS "Workers can create feedback for their tasks" ON public.task_feedback;
DROP POLICY IF EXISTS "Workers can view feedback for their tasks" ON public.task_feedback;
DROP POLICY IF EXISTS "Task assignees can update their feedback" ON public.task_feedback;

CREATE POLICY "Admins can manage all feedback" ON public.task_feedback
FOR ALL TO authenticated USING (auth.is_admin()) WITH CHECK (auth.is_admin());

CREATE POLICY "Workers can create feedback for their tasks" ON public.task_feedback
FOR INSERT TO authenticated WITH CHECK (
  auth.is_worker() AND
  EXISTS (
    SELECT 1 FROM public.tasks
    WHERE id = task_id AND assigned_to = auth.uid()::text
  )
);

CREATE POLICY "Workers can view feedback for their tasks" ON public.task_feedback
FOR SELECT TO authenticated USING (
  auth.is_worker() AND
  EXISTS (
    SELECT 1 FROM public.tasks
    WHERE id = task_id AND assigned_to = auth.uid()::text
  )
);

CREATE POLICY "Task assignees can update their feedback" ON public.task_feedback
FOR UPDATE TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.tasks
    WHERE id = task_id AND assigned_to = auth.uid()::text
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.tasks
    WHERE id = task_id AND assigned_to = auth.uid()::text
  )
);

-- 12. TASK_SUBMISSIONS (Priority - currently has RLS enabled but no policies)
-- Keep RLS enabled and create policies
DROP POLICY IF EXISTS "Admins can manage all submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Workers can create submissions for their tasks" ON public.task_submissions;
DROP POLICY IF EXISTS "Workers can view their submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Workers can update their submissions" ON public.task_submissions;

CREATE POLICY "Admins can manage all submissions" ON public.task_submissions
FOR ALL TO authenticated USING (auth.is_admin()) WITH CHECK (auth.is_admin());

CREATE POLICY "Workers can create submissions for their tasks" ON public.task_submissions
FOR INSERT TO authenticated WITH CHECK (
  auth.is_worker() AND
  EXISTS (
    SELECT 1 FROM public.tasks
    WHERE id = task_id AND assigned_to = auth.uid()::text
  )
);

CREATE POLICY "Workers can view their submissions" ON public.task_submissions
FOR SELECT TO authenticated USING (
  auth.is_worker() AND
  EXISTS (
    SELECT 1 FROM public.tasks
    WHERE id = task_id AND assigned_to = auth.uid()::text
  )
);

CREATE POLICY "Workers can update their submissions" ON public.task_submissions
FOR UPDATE TO authenticated USING (
  auth.is_worker() AND
  EXISTS (
    SELECT 1 FROM public.tasks
    WHERE id = task_id AND assigned_to = auth.uid()::text
  )
) WITH CHECK (
  auth.is_worker() AND
  EXISTS (
    SELECT 1 FROM public.tasks
    WHERE id = task_id AND assigned_to = auth.uid()::text
  )
);

COMMIT;
