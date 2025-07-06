-- =====================================================
-- CLEAN RLS FIX FOR CLIENT ORDERS - SUPABASE COMPATIBLE
-- =====================================================
-- This script fixes RLS policies for client_orders table
-- Uses correct column names: client_id, assigned_to, assigned_by
-- =====================================================

-- =====================================================
-- 1. DROP ALL EXISTING POLICIES
-- =====================================================

-- Drop any existing policies that might be causing conflicts
DROP POLICY IF EXISTS "Enable read access for all users" ON public.client_orders;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.client_orders;
DROP POLICY IF EXISTS "Enable update for users based on email" ON public.client_orders;
DROP POLICY IF EXISTS "Enable delete for users based on email" ON public.client_orders;
DROP POLICY IF EXISTS "Users can view their own orders" ON public.client_orders;
DROP POLICY IF EXISTS "Users can create their own orders" ON public.client_orders;
DROP POLICY IF EXISTS "Users can update their own orders" ON public.client_orders;
DROP POLICY IF EXISTS "Users can delete their own orders" ON public.client_orders;
DROP POLICY IF EXISTS "Admin full access to client orders" ON public.client_orders;
DROP POLICY IF EXISTS "Owner full access to client orders" ON public.client_orders;
DROP POLICY IF EXISTS "Accountant full access to client orders" ON public.client_orders;
DROP POLICY IF EXISTS "Client access to own orders" ON public.client_orders;
DROP POLICY IF EXISTS "Worker read access to orders" ON public.client_orders;
DROP POLICY IF EXISTS "Approved users fallback access" ON public.client_orders;
DROP POLICY IF EXISTS "clients_can_view_own_orders" ON public.client_orders;
DROP POLICY IF EXISTS "clients_can_create_orders" ON public.client_orders;
DROP POLICY IF EXISTS "admins_can_view_all_orders" ON public.client_orders;
DROP POLICY IF EXISTS "admins_can_update_all_orders" ON public.client_orders;
DROP POLICY IF EXISTS "workers_can_view_assigned_orders" ON public.client_orders;

-- =====================================================
-- 2. ENSURE RLS IS ENABLED
-- =====================================================

ALTER TABLE public.client_orders ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 3. CREATE COMPREHENSIVE RLS POLICIES
-- =====================================================

-- Policy 1: Admin role - Full access to all orders
CREATE POLICY "Admin full access to client orders" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'admin'
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'admin'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 2: Owner role - Full access to all orders
CREATE POLICY "Owner full access to client orders" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'owner'
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'owner'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 3: Accountant role - Full access to all orders
CREATE POLICY "Accountant full access to client orders" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'accountant'
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'accountant'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 4: Manager role - Full access to all orders
CREATE POLICY "Manager full access to client orders" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'manager'
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'manager'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 5: Client role - Access to own orders only
CREATE POLICY "Client access to own orders" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'client'
            AND user_profiles.status = 'approved'
        )
        AND client_orders.client_id = auth.uid()
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'client'
            AND user_profiles.status = 'approved'
        )
        AND client_orders.client_id = auth.uid()
    );

-- Policy 6: Worker role - Access to assigned orders
CREATE POLICY "Worker access to assigned orders" ON public.client_orders
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'worker'
            AND user_profiles.status = 'approved'
        )
        AND client_orders.assigned_to = auth.uid()
    );

-- Policy 7: Workers can update assigned orders
CREATE POLICY "Worker update assigned orders" ON public.client_orders
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'worker'
            AND user_profiles.status = 'approved'
        )
        AND client_orders.assigned_to = auth.uid()
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'worker'
            AND user_profiles.status = 'approved'
        )
        AND client_orders.assigned_to = auth.uid()
    );

-- Policy 8: Fallback policy for any approved user (emergency access)
CREATE POLICY "Approved users emergency access" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.status = 'approved'
            AND user_profiles.role IN ('admin', 'owner', 'accountant', 'manager', 'client', 'worker')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.status = 'approved'
            AND user_profiles.role IN ('admin', 'owner', 'accountant', 'manager', 'client', 'worker')
        )
    );

-- =====================================================
-- 4. GRANT NECESSARY PERMISSIONS
-- =====================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_orders TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Grant permissions on related tables
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_order_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.order_tracking_links TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.order_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.order_notifications TO authenticated;

-- =====================================================
-- 5. VERIFICATION QUERIES
-- =====================================================

-- Show current RLS status
SELECT 
    'RLS STATUS:' as info,
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'client_orders';

-- Show all policies on client_orders
SELECT 
    'CURRENT POLICIES:' as info,
    policyname,
    cmd as command
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public'
ORDER BY policyname;

-- Show table permissions
SELECT 
    'TABLE PERMISSIONS:' as info,
    privilege_type,
    grantee
FROM information_schema.table_privileges 
WHERE table_schema = 'public' 
AND table_name = 'client_orders'
AND grantee = 'authenticated'
ORDER BY privilege_type;

-- Check current user authentication
SELECT 
    'CURRENT USER:' as info,
    CASE 
        WHEN auth.uid() IS NULL THEN 'Not authenticated'
        ELSE 'Authenticated: ' || auth.uid()::text
    END as auth_status;

-- Check current user profile
SELECT 
    'USER PROFILE:' as info,
    id,
    name,
    role,
    status
FROM public.user_profiles 
WHERE id = auth.uid();

-- Test basic access (count orders)
SELECT 
    'ACCESS TEST:' as info,
    COUNT(*) as accessible_orders
FROM public.client_orders;

-- =====================================================
-- COMPLETION STATUS
-- =====================================================

SELECT 'CLIENT ORDERS RLS FIX COMPLETED SUCCESSFULLY' as status;
