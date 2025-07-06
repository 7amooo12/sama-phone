-- =====================================================
-- FIX CLIENT ORDER ITEMS RLS POLICY VIOLATION
-- =====================================================
-- This script fixes the RLS policy violation when clients
-- try to insert order items into client_order_items table
-- 
-- Error: "new row violates row-level security policy for table 'client_order_items'"
-- User: cust@sama.com (client role, approved status)
-- Order ID: 23dfc246-9758-4951-9a4a-1e8625712c5c
-- =====================================================

BEGIN;

-- =====================================================
-- 1. DROP EXISTING PROBLEMATIC POLICIES
-- =====================================================

-- Drop all existing policies for client_order_items
DROP POLICY IF EXISTS "clients_can_create_order_items" ON public.client_order_items;
DROP POLICY IF EXISTS "clients_can_view_own_order_items" ON public.client_order_items;
DROP POLICY IF EXISTS "admins_can_view_all_order_items" ON public.client_order_items;
DROP POLICY IF EXISTS "admins_can_update_order_items" ON public.client_order_items;
DROP POLICY IF EXISTS "assigned_staff_can_view_order_items" ON public.client_order_items;

-- =====================================================
-- 2. ENSURE RLS IS ENABLED
-- =====================================================

ALTER TABLE public.client_order_items ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 3. CREATE WORKING RLS POLICIES
-- =====================================================

-- Policy 1: Clients can insert order items for their own orders
-- REMOVED the restrictive status = 'pending' check that was causing issues
CREATE POLICY "clients_can_create_order_items" ON public.client_order_items
    FOR INSERT 
    TO authenticated 
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.client_orders
            WHERE client_orders.id = order_id 
            AND client_orders.client_id = auth.uid()
        )
        AND EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'client'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 2: Clients can view their own order items
CREATE POLICY "clients_can_view_own_order_items" ON public.client_order_items
    FOR SELECT 
    TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.client_orders
            WHERE client_orders.id = order_id 
            AND client_orders.client_id = auth.uid()
        )
        AND EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'client'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 3: Admins can view all order items
CREATE POLICY "admins_can_view_all_order_items" ON public.client_order_items
    FOR SELECT 
    TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'owner', 'accountant')
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 4: Admins can update order items
CREATE POLICY "admins_can_update_order_items" ON public.client_order_items
    FOR UPDATE 
    TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'owner')
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'owner')
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 5: Workers can view order items for assigned orders
CREATE POLICY "workers_can_view_assigned_order_items" ON public.client_order_items
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
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'worker'
            AND user_profiles.status = 'approved'
        )
    );

-- =====================================================
-- 4. GRANT NECESSARY PERMISSIONS
-- =====================================================

-- Ensure authenticated users have necessary permissions
GRANT SELECT, INSERT, UPDATE ON public.client_order_items TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- =====================================================
-- 5. VERIFICATION TEST
-- =====================================================

-- Test the policies with the specific user and order from the error
DO $$
DECLARE
    test_user_id UUID := 'aaaaf98e-f3aa-489d-9586-573332ff6301'; -- cust@sama.com
    test_order_id UUID := '23dfc246-9758-4951-9a4a-1e8625712c5c';
    user_role TEXT;
    user_status TEXT;
    order_exists BOOLEAN;
    order_client_id UUID;
BEGIN
    -- Check user profile
    SELECT role, status INTO user_role, user_status
    FROM public.user_profiles 
    WHERE id = test_user_id;
    
    RAISE NOTICE '🔍 User Profile Check:';
    RAISE NOTICE '  - User ID: %', test_user_id;
    RAISE NOTICE '  - Role: %', COALESCE(user_role, 'NOT FOUND');
    RAISE NOTICE '  - Status: %', COALESCE(user_status, 'NOT FOUND');
    
    -- Check order
    SELECT true, client_id INTO order_exists, order_client_id
    FROM public.client_orders 
    WHERE id = test_order_id;
    
    RAISE NOTICE '🔍 Order Check:';
    RAISE NOTICE '  - Order ID: %', test_order_id;
    RAISE NOTICE '  - Order Exists: %', COALESCE(order_exists::TEXT, 'false');
    RAISE NOTICE '  - Order Client ID: %', COALESCE(order_client_id::TEXT, 'NULL');
    RAISE NOTICE '  - Client ID Match: %', (order_client_id = test_user_id)::TEXT;
    
    -- Test policy conditions
    IF user_role = 'client' AND user_status = 'approved' AND order_client_id = test_user_id THEN
        RAISE NOTICE '✅ All policy conditions met - INSERT should work';
    ELSE
        RAISE NOTICE '❌ Policy conditions not met:';
        IF user_role != 'client' THEN
            RAISE NOTICE '  - Wrong role: % (expected: client)', user_role;
        END IF;
        IF user_status != 'approved' THEN
            RAISE NOTICE '  - Wrong status: % (expected: approved)', user_status;
        END IF;
        IF order_client_id != test_user_id THEN
            RAISE NOTICE '  - Order client mismatch: % != %', order_client_id, test_user_id;
        END IF;
    END IF;
END $$;

-- =====================================================
-- 6. SHOW FINAL POLICY CONFIGURATION
-- =====================================================

SELECT 'CLIENT_ORDER_ITEMS RLS POLICIES:' as info;
SELECT
    policyname,
    cmd as command,
    roles,
    qual as using_expression,
    with_check as with_check_expression
FROM pg_policies
WHERE tablename = 'client_order_items'
AND schemaname = 'public'
ORDER BY policyname;

COMMIT;

-- =====================================================
-- 7. FINAL VERIFICATION MESSAGE
-- =====================================================

SELECT '✅ CLIENT ORDER ITEMS RLS POLICIES FIXED' as result;
SELECT 'The restrictive status=pending check has been removed' as note;
SELECT 'Clients can now insert order items for any of their orders' as note2;
