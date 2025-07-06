-- =====================================================
-- SUPABASE COMPATIBLE RLS FIX FOR CLIENT ORDERS
-- =====================================================
-- Execute this script in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. DROP EXISTING PROBLEMATIC POLICIES
-- =====================================================

-- Drop any existing policies that might be causing issues
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

-- Policy 4: Client role - Access to own orders
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
        AND (
            client_orders.user_id = auth.uid() OR
            client_orders.client_id = auth.uid() OR
            client_orders.customer_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'client'
            AND user_profiles.status = 'approved'
        )
        AND (
            client_orders.user_id = auth.uid() OR
            client_orders.client_id = auth.uid() OR
            client_orders.customer_id = auth.uid()
        )
    );

-- Policy 5: Worker role - Read access for order fulfillment
CREATE POLICY "Worker read access to orders" ON public.client_orders
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'worker'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 6: Fallback policy for any approved user (if needed)
CREATE POLICY "Approved users fallback access" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.status = 'approved'
        )
    );

-- =====================================================
-- 4. GRANT NECESSARY PERMISSIONS
-- =====================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_orders TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- =====================================================
-- 5. VERIFICATION QUERIES
-- =====================================================

-- Show current RLS status
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'client_orders';

-- Show all policies on client_orders
SELECT 
    policyname,
    cmd as command,
    roles
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public'
ORDER BY policyname;

-- Show table permissions
SELECT 
    privilege_type,
    is_grantable
FROM information_schema.table_privileges 
WHERE table_schema = 'public' 
AND table_name = 'client_orders'
AND grantee = 'authenticated'
ORDER BY privilege_type;

-- =====================================================
-- 6. TEST THE FIX (SIMPLE VERSION)
-- =====================================================

-- Simple test to verify current user can access the table
SELECT 
    CASE 
        WHEN auth.uid() IS NULL THEN 'No authenticated user'
        ELSE 'User authenticated: ' || auth.uid()::text
    END as auth_status;

-- Check current user's profile
SELECT 
    id,
    name,
    email,
    role,
    status
FROM public.user_profiles 
WHERE id = auth.uid();

-- Try to count orders (this will test SELECT permission)
SELECT COUNT(*) as order_count FROM public.client_orders;

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

-- This will show in the results
SELECT 'RLS FIX COMPLETED - Check the results above to verify success' as status;
