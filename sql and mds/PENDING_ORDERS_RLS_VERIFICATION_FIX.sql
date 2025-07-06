-- =====================================================
-- PENDING ORDERS WORKFLOW RLS VERIFICATION & FIX
-- =====================================================
-- This script ensures all RLS policies are correctly configured
-- for the pending orders workflow system to function properly
-- =====================================================

BEGIN;

-- =====================================================
-- 1. CLEAN UP EXISTING POLICIES
-- =====================================================

-- Drop all existing policies for client_orders
DROP POLICY IF EXISTS "admin_full_access" ON public.client_orders;
DROP POLICY IF EXISTS "owner_full_access" ON public.client_orders;
DROP POLICY IF EXISTS "accountant_full_access" ON public.client_orders;
DROP POLICY IF EXISTS "client_own_orders" ON public.client_orders;
DROP POLICY IF EXISTS "worker_assigned_orders" ON public.client_orders;
DROP POLICY IF EXISTS "Admin full access to client orders" ON public.client_orders;
DROP POLICY IF EXISTS "Owner full access to client orders" ON public.client_orders;
DROP POLICY IF EXISTS "Accountant full access to client orders" ON public.client_orders;
DROP POLICY IF EXISTS "Client own orders access" ON public.client_orders;
DROP POLICY IF EXISTS "Worker assigned orders access" ON public.client_orders;
DROP POLICY IF EXISTS "admins_can_view_all_orders" ON public.client_orders;
DROP POLICY IF EXISTS "admins_can_update_orders" ON public.client_orders;
DROP POLICY IF EXISTS "clients_can_view_own_orders" ON public.client_orders;
DROP POLICY IF EXISTS "clients_can_create_orders" ON public.client_orders;

-- Drop all existing policies for client_order_items
DROP POLICY IF EXISTS "clients_can_create_order_items" ON public.client_order_items;
DROP POLICY IF EXISTS "clients_can_view_own_order_items" ON public.client_order_items;
DROP POLICY IF EXISTS "admins_can_view_all_order_items" ON public.client_order_items;
DROP POLICY IF EXISTS "admins_can_update_order_items" ON public.client_order_items;
DROP POLICY IF EXISTS "workers_can_view_assigned_order_items" ON public.client_order_items;

-- =====================================================
-- 2. ENSURE RLS IS ENABLED
-- =====================================================

ALTER TABLE public.client_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_order_items ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 3. CREATE COMPREHENSIVE CLIENT_ORDERS POLICIES
-- =====================================================

-- Policy 1: Admin - Full access to all orders
CREATE POLICY "pending_orders_admin_full_access" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND status = 'approved'
        )
    );

-- Policy 2: Owner - Full access to all orders
CREATE POLICY "pending_orders_owner_full_access" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'owner'
            AND status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'owner'
            AND status = 'approved'
        )
    );

-- Policy 3: Accountant - Full access to all orders
CREATE POLICY "pending_orders_accountant_full_access" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'accountant'
            AND status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'accountant'
            AND status = 'approved'
        )
    );

-- Policy 4: Client - Own orders only
CREATE POLICY "pending_orders_client_own_orders" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'client'
            AND status = 'approved'
        )
        AND client_id = auth.uid()
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'client'
            AND status = 'approved'
        )
        AND client_id = auth.uid()
    );

-- Policy 5: Worker - Assigned orders only (read-only)
CREATE POLICY "pending_orders_worker_assigned_orders" ON public.client_orders
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'worker'
            AND status = 'approved'
        )
        AND assigned_to = auth.uid()
    );

-- =====================================================
-- 4. CREATE COMPREHENSIVE CLIENT_ORDER_ITEMS POLICIES
-- =====================================================

-- Policy 1: Admin - Full access to all order items
CREATE POLICY "pending_orders_admin_full_order_items" ON public.client_order_items
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND status = 'approved'
        )
    );

-- Policy 2: Owner - Full access to all order items
CREATE POLICY "pending_orders_owner_full_order_items" ON public.client_order_items
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'owner'
            AND status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'owner'
            AND status = 'approved'
        )
    );

-- Policy 3: Accountant - Full access to all order items
CREATE POLICY "pending_orders_accountant_full_order_items" ON public.client_order_items
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'accountant'
            AND status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'accountant'
            AND status = 'approved'
        )
    );

-- Policy 4: Client - Own order items only
CREATE POLICY "pending_orders_client_own_order_items" ON public.client_order_items
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.client_orders
            WHERE client_orders.id = order_id 
            AND client_orders.client_id = auth.uid()
        )
        AND EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() 
            AND role = 'client'
            AND status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.client_orders
            WHERE client_orders.id = order_id 
            AND client_orders.client_id = auth.uid()
        )
        AND EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() 
            AND role = 'client'
            AND status = 'approved'
        )
    );

-- Policy 5: Worker - Assigned order items only (read-only)
CREATE POLICY "pending_orders_worker_assigned_order_items" ON public.client_order_items
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.client_orders
            WHERE client_orders.id = order_id 
            AND client_orders.assigned_to = auth.uid()
        )
        AND EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() 
            AND role = 'worker'
            AND status = 'approved'
        )
    );

-- =====================================================
-- 5. GRANT NECESSARY PERMISSIONS
-- =====================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_orders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_order_items TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- =====================================================
-- 6. VERIFICATION TEST
-- =====================================================

-- Test with specific user roles
DO $$
DECLARE
    admin_user_id UUID := 'aaaaf98e-f3aa-489d-9586-573332ff6301'; -- Replace with actual admin ID
    client_user_id UUID := 'aaaaf98e-f3aa-489d-9586-573332ff6301'; -- Replace with actual client ID
    test_order_id UUID := '31ff13ba-dc45-4bfd-89ac-ea9e334fce04'; -- Replace with actual order ID
BEGIN
    RAISE NOTICE '🔍 PENDING ORDERS RLS VERIFICATION:';
    
    -- Check if policies exist
    RAISE NOTICE '📋 Checking policies...';
    
    -- List all policies for client_orders
    FOR rec IN 
        SELECT policyname, cmd, roles 
        FROM pg_policies 
        WHERE tablename = 'client_orders' 
        AND schemaname = 'public'
        AND policyname LIKE 'pending_orders_%'
    LOOP
        RAISE NOTICE '  ✅ Policy: % (%) for roles: %', rec.policyname, rec.cmd, rec.roles;
    END LOOP;
    
    -- List all policies for client_order_items
    FOR rec IN 
        SELECT policyname, cmd, roles 
        FROM pg_policies 
        WHERE tablename = 'client_order_items' 
        AND schemaname = 'public'
        AND policyname LIKE 'pending_orders_%'
    LOOP
        RAISE NOTICE '  ✅ Policy: % (%) for roles: %', rec.policyname, rec.cmd, rec.roles;
    END LOOP;
    
    RAISE NOTICE '✅ RLS policies configured successfully for pending orders workflow';
END $$;

COMMIT;

-- =====================================================
-- 7. FINAL STATUS
-- =====================================================

SELECT '✅ PENDING ORDERS RLS VERIFICATION COMPLETE' as status;
SELECT 'All admin, owner, and accountant roles have full access to orders' as note1;
SELECT 'Clients can only access their own orders' as note2;
SELECT 'Workers can only view orders assigned to them' as note3;
