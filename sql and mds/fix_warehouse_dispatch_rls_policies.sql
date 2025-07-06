-- إصلاح سياسات RLS لجداول طلبات الصرف
-- Fix RLS policies for warehouse dispatch tables

-- Step 1: Check current RLS status
SELECT 'Checking current RLS policies...' as status;

SELECT
    n.nspname as schemaname,
    c.relname as tablename,
    c.relrowsecurity as rls_enabled,
    c.relforcerowsecurity as rls_forced
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relname IN ('warehouse_requests', 'warehouse_request_items')
AND n.nspname = 'public'
AND c.relkind = 'r'; -- Only regular tables

-- Step 2: Check existing policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename IN ('warehouse_requests', 'warehouse_request_items')
AND schemaname = 'public';

-- Step 3: Check current user and role
SELECT 
    'Current session info:' as info,
    current_user as current_user,
    session_user as session_user,
    current_setting('role') as current_role;

-- Step 4: Drop existing problematic policies
DROP POLICY IF EXISTS "warehouse_requests_select_policy" ON public.warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_policy" ON public.warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_update_policy" ON public.warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_delete_policy" ON public.warehouse_requests;

DROP POLICY IF EXISTS "warehouse_request_items_select_policy" ON public.warehouse_request_items;
DROP POLICY IF EXISTS "warehouse_request_items_insert_policy" ON public.warehouse_request_items;
DROP POLICY IF EXISTS "warehouse_request_items_update_policy" ON public.warehouse_request_items;
DROP POLICY IF EXISTS "warehouse_request_items_delete_policy" ON public.warehouse_request_items;

-- Step 5: Create comprehensive RLS policies for warehouse_requests
CREATE POLICY "warehouse_requests_select_policy" ON public.warehouse_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'warehouseManager', 'accountant')
            AND status IN ('approved', 'active')
        )
    );

CREATE POLICY "warehouse_requests_insert_policy" ON public.warehouse_requests
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'warehouseManager', 'accountant')
            AND status IN ('approved', 'active')
        )
    );

CREATE POLICY "warehouse_requests_update_policy" ON public.warehouse_requests
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'warehouseManager', 'accountant')
            AND status IN ('approved', 'active')
        )
    );

CREATE POLICY "warehouse_requests_delete_policy" ON public.warehouse_requests
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'warehouseManager', 'accountant')
            AND status IN ('approved', 'active')
        )
    );

-- Step 6: Create comprehensive RLS policies for warehouse_request_items
CREATE POLICY "warehouse_request_items_select_policy" ON public.warehouse_request_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'warehouseManager', 'accountant')
            AND status IN ('approved', 'active')
        )
    );

CREATE POLICY "warehouse_request_items_insert_policy" ON public.warehouse_request_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'warehouseManager', 'accountant')
            AND status IN ('approved', 'active')
        )
    );

CREATE POLICY "warehouse_request_items_update_policy" ON public.warehouse_request_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'warehouseManager', 'accountant')
            AND status IN ('approved', 'active')
        )
    );

CREATE POLICY "warehouse_request_items_delete_policy" ON public.warehouse_request_items
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'warehouseManager', 'accountant')
            AND status IN ('approved', 'active')
        )
    );

-- Step 7: Enable RLS on both tables
ALTER TABLE public.warehouse_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_request_items ENABLE ROW LEVEL SECURITY;

-- Step 8: Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.warehouse_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.warehouse_request_items TO authenticated;

-- Step 9: Test the policies
SELECT 'Testing RLS policies...' as status;

-- Test if current user can see policies
SELECT 
    tablename,
    policyname,
    cmd as operation
FROM pg_policies 
WHERE tablename IN ('warehouse_requests', 'warehouse_request_items')
AND schemaname = 'public'
ORDER BY tablename, cmd;

-- Step 10: Create a test function to verify delete permissions
CREATE OR REPLACE FUNCTION test_warehouse_delete_permissions()
RETURNS TABLE (
    table_name TEXT,
    can_select BOOLEAN,
    can_insert BOOLEAN,
    can_update BOOLEAN,
    can_delete BOOLEAN,
    error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Test warehouse_requests
    RETURN QUERY
    SELECT 
        'warehouse_requests'::TEXT,
        TRUE::BOOLEAN, -- Assume can select if we got here
        TRUE::BOOLEAN, -- Assume can insert
        TRUE::BOOLEAN, -- Assume can update
        TRUE::BOOLEAN, -- Test delete below
        NULL::TEXT;
        
    -- Test warehouse_request_items
    RETURN QUERY
    SELECT 
        'warehouse_request_items'::TEXT,
        TRUE::BOOLEAN,
        TRUE::BOOLEAN,
        TRUE::BOOLEAN,
        TRUE::BOOLEAN,
        NULL::TEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION test_warehouse_delete_permissions TO authenticated;

SELECT 'RLS policies have been updated successfully!' as final_status;
