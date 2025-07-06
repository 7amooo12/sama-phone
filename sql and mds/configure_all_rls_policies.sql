-- Comprehensive RLS Configuration for SmartBizTracker
-- Execute this script in Supabase SQL Editor to configure all table policies
-- Part 1: Tables 1-9

BEGIN;

-- Drop existing helper functions if they exist to avoid conflicts
DROP FUNCTION IF EXISTS public.is_admin();
DROP FUNCTION IF EXISTS public.is_worker();
DROP FUNCTION IF EXISTS public.is_client();

-- 1. CLIENT_ORDER_ITEMS
ALTER TABLE public.client_order_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admins_can_update_order_items" ON public.client_order_items;
DROP POLICY IF EXISTS "admins_can_view_all_order_items" ON public.client_order_items;
DROP POLICY IF EXISTS "assigned_staff_can_view_order_items" ON public.client_order_items;
DROP POLICY IF EXISTS "clients_can_create_order_items" ON public.client_order_items;
DROP POLICY IF EXISTS "clients_can_view_own_order_items" ON public.client_order_items;

CREATE POLICY "admins_can_update_order_items" ON public.client_order_items
FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
) WITH CHECK (
  EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "admins_can_view_all_order_items" ON public.client_order_items
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "assigned_staff_can_view_order_items" ON public.client_order_items
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'worker')
);

CREATE POLICY "clients_can_create_order_items" ON public.client_order_items
FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'client')
);

CREATE POLICY "clients_can_view_own_order_items" ON public.client_order_items
FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'client')
  AND user_id = auth.uid()
);

-- 2. CLIENT_ORDERS
ALTER TABLE public.client_orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admins_can_update_orders" ON public.client_orders;
DROP POLICY IF EXISTS "admins_can_view_all_orders" ON public.client_orders;
DROP POLICY IF EXISTS "assigned_staff_can_update_orders" ON public.client_orders;
DROP POLICY IF EXISTS "assigned_staff_can_view_orders" ON public.client_orders;
DROP POLICY IF EXISTS "clients_can_create_orders" ON public.client_orders;
DROP POLICY IF EXISTS "clients_can_view_own_orders" ON public.client_orders;

CREATE POLICY "admins_can_update_orders" ON public.client_orders
FOR UPDATE TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY "admins_can_view_all_orders" ON public.client_orders
FOR SELECT TO authenticated USING (public.is_admin());

CREATE POLICY "assigned_staff_can_update_orders" ON public.client_orders
FOR UPDATE TO authenticated USING (public.is_worker()) WITH CHECK (public.is_worker());

CREATE POLICY "assigned_staff_can_view_orders" ON public.client_orders
FOR SELECT TO authenticated USING (public.is_worker());

CREATE POLICY "clients_can_create_orders" ON public.client_orders
FOR INSERT TO authenticated WITH CHECK (public.is_client());

CREATE POLICY "clients_can_view_own_orders" ON public.client_orders
FOR SELECT TO authenticated USING (public.is_client() AND user_id = auth.uid());

-- 3. FAVORITES
ALTER TABLE public.favorites DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own favorites" ON public.favorites;

CREATE POLICY "Users can manage their own favorites" ON public.favorites
FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 4. NOTIFICATIONS
ALTER TABLE public.notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;

CREATE POLICY "Users can update their own notifications" ON public.notifications
FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can view their own notifications" ON public.notifications
FOR SELECT TO authenticated USING (user_id = auth.uid());

-- 5. ORDER_HISTORY
ALTER TABLE public.order_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admins_can_view_all_order_history" ON public.order_history;
DROP POLICY IF EXISTS "assigned_staff_can_view_order_history" ON public.order_history;
DROP POLICY IF EXISTS "clients_can_view_own_order_history" ON public.order_history;
DROP POLICY IF EXISTS "system_can_create_order_history" ON public.order_history;

CREATE POLICY "admins_can_view_all_order_history" ON public.order_history
FOR SELECT TO authenticated USING (public.is_admin());

CREATE POLICY "assigned_staff_can_view_order_history" ON public.order_history
FOR SELECT TO authenticated USING (public.is_worker());

CREATE POLICY "clients_can_view_own_order_history" ON public.order_history
FOR SELECT TO authenticated USING (public.is_client() AND user_id = auth.uid());

CREATE POLICY "system_can_create_order_history" ON public.order_history
FOR INSERT TO service_role WITH CHECK (true);

COMMIT;
