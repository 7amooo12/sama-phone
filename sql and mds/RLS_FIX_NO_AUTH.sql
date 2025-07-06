-- =====================================================
-- RLS FIX FOR CLIENT ORDERS - NO AUTH REQUIRED
-- =====================================================
-- This script fixes RLS policies and tests them without
-- requiring authentication in the SQL Editor
-- =====================================================

-- =====================================================
-- 1. RESET ALL RLS POLICIES
-- =====================================================

-- Drop all existing policies
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
DROP POLICY IF EXISTS "Manager full access to client orders" ON public.client_orders;
DROP POLICY IF EXISTS "Client access to own orders" ON public.client_orders;
DROP POLICY IF EXISTS "Worker access to assigned orders" ON public.client_orders;
DROP POLICY IF EXISTS "Worker read access to orders" ON public.client_orders;
DROP POLICY IF EXISTS "Worker update assigned orders" ON public.client_orders;
DROP POLICY IF EXISTS "Approved users fallback access" ON public.client_orders;
DROP POLICY IF EXISTS "Approved users emergency access" ON public.client_orders;
DROP POLICY IF EXISTS "clients_can_view_own_orders" ON public.client_orders;
DROP POLICY IF EXISTS "clients_can_create_orders" ON public.client_orders;
DROP POLICY IF EXISTS "admins_can_view_all_orders" ON public.client_orders;
DROP POLICY IF EXISTS "admins_can_update_all_orders" ON public.client_orders;
DROP POLICY IF EXISTS "workers_can_view_assigned_orders" ON public.client_orders;
DROP POLICY IF EXISTS "admin_full_access" ON public.client_orders;
DROP POLICY IF EXISTS "owner_full_access" ON public.client_orders;
DROP POLICY IF EXISTS "accountant_full_access" ON public.client_orders;
DROP POLICY IF EXISTS "manager_full_access" ON public.client_orders;
DROP POLICY IF EXISTS "client_own_orders" ON public.client_orders;
DROP POLICY IF EXISTS "worker_assigned_orders" ON public.client_orders;
DROP POLICY IF EXISTS "worker_update_assigned" ON public.client_orders;
DROP POLICY IF EXISTS "emergency_insert_access" ON public.client_orders;

-- =====================================================
-- 2. ENSURE RLS IS ENABLED
-- =====================================================

ALTER TABLE public.client_orders ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 3. CREATE WORKING RLS POLICIES
-- =====================================================

-- Policy 1: Admin users - full access
CREATE POLICY "admin_full_access" ON public.client_orders
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

-- Policy 2: Owner users - full access
CREATE POLICY "owner_full_access" ON public.client_orders
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

-- Policy 3: Accountant users - full access
CREATE POLICY "accountant_full_access" ON public.client_orders
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

-- Policy 4: Manager users - full access
CREATE POLICY "manager_full_access" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'manager'
            AND status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'manager'
            AND status = 'approved'
        )
    );

-- Policy 5: Client users - own orders only
CREATE POLICY "client_own_orders" ON public.client_orders
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

-- Policy 6: Worker users - assigned orders only
CREATE POLICY "worker_assigned_orders" ON public.client_orders
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

-- Policy 7: Worker update assigned orders
CREATE POLICY "worker_update_assigned" ON public.client_orders
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'worker'
            AND status = 'approved'
        )
        AND assigned_to = auth.uid()
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'worker'
            AND status = 'approved'
        )
        AND assigned_to = auth.uid()
    );

-- =====================================================
-- 4. GRANT PERMISSIONS
-- =====================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_orders TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_order_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.order_tracking_links TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.order_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.order_notifications TO authenticated;

-- =====================================================
-- 5. SHOW AVAILABLE USERS FOR TESTING
-- =====================================================

-- Show admin users that can be used for testing
SELECT 
    'ADMIN USERS FOR TESTING:' as info,
    id,
    email,
    name,
    status
FROM public.user_profiles 
WHERE role = 'admin'
AND status = 'approved'
ORDER BY created_at DESC;

-- Show all approved users
SELECT 
    'ALL APPROVED USERS:' as info,
    id,
    email,
    name,
    role,
    status
FROM public.user_profiles 
WHERE status = 'approved'
ORDER BY role, created_at DESC;

-- =====================================================
-- 6. VERIFICATION
-- =====================================================

-- Show final RLS policies
SELECT 
    'FINAL RLS POLICIES:' as info,
    policyname,
    cmd as command
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public'
ORDER BY policyname;

-- Show RLS status
SELECT 
    'RLS STATUS:' as info,
    rowsecurity as enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'client_orders';

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

-- =====================================================
-- 7. INSTRUCTIONS FOR FLUTTER APP TESTING
-- =====================================================

SELECT 
    'FLUTTER APP TESTING INSTRUCTIONS:' as info,
    '1. RLS policies are now properly configured' as step_1,
    '2. Ensure user is logged in to Flutter app' as step_2,
    '3. User must have approved status in user_profiles' as step_3,
    '4. Order creation should now work in Flutter app' as step_4;

SELECT 
    'TROUBLESHOOTING:' as info,
    'If order creation still fails in Flutter:' as issue,
    '1. Check user authentication in Flutter app' as solution_1,
    '2. Verify user profile exists and is approved' as solution_2,
    '3. Check Flutter app logs for specific error details' as solution_3;

-- =====================================================
-- COMPLETION
-- =====================================================

SELECT 'RLS POLICIES FIXED - FLUTTER APP SHOULD NOW WORK' as status;
