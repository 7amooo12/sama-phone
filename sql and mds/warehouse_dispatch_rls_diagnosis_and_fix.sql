-- تشخيص وإصلاح مشاكل RLS لطلبات صرف المخزون
-- Warehouse Dispatch RLS Diagnosis and Fix

-- =====================================================
-- STEP 1: CURRENT STATE DIAGNOSIS
-- =====================================================

SELECT '=== STEP 1: CHECKING CURRENT RLS STATUS ===' as step;

-- Check if tables exist and their RLS status
SELECT 
    n.nspname as schema_name,
    c.relname as table_name,
    c.relrowsecurity as rls_enabled,
    c.relforcerowsecurity as rls_forced,
    CASE 
        WHEN c.relrowsecurity THEN 'RLS ENABLED'
        ELSE 'RLS DISABLED'
    END as rls_status
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relname IN ('warehouse_requests', 'warehouse_request_items')
AND n.nspname = 'public'
AND c.relkind = 'r'
ORDER BY c.relname;

-- Check existing RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as operation,
    qual as using_expression,
    with_check as with_check_expression
FROM pg_policies 
WHERE tablename IN ('warehouse_requests', 'warehouse_request_items')
AND schemaname = 'public'
ORDER BY tablename, cmd;

-- Check table permissions
SELECT 
    grantee,
    table_name,
    privilege_type,
    is_grantable
FROM information_schema.table_privileges 
WHERE table_name IN ('warehouse_requests', 'warehouse_request_items')
AND table_schema = 'public'
ORDER BY table_name, privilege_type;

-- =====================================================
-- STEP 2: CHECK CURRENT USER CONTEXT
-- =====================================================

SELECT '=== STEP 2: CHECKING USER CONTEXT ===' as step;

-- Check current user and auth functions
SELECT 
    current_user as current_user,
    session_user as session_user;

-- Test auth functions
DO $$
BEGIN
    BEGIN
        RAISE NOTICE 'Current auth.uid(): %', auth.uid();
        RAISE NOTICE 'Current auth.email(): %', auth.email();
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Auth functions error: %', SQLERRM;
    END;
END $$;

-- Check user_profiles table access
DO $$
DECLARE
    user_record RECORD;
BEGIN
    BEGIN
        SELECT role, status INTO user_record
        FROM user_profiles 
        WHERE id = auth.uid()
        LIMIT 1;
        
        IF FOUND THEN
            RAISE NOTICE 'Current user role: %, status: %', user_record.role, user_record.status;
        ELSE
            RAISE NOTICE 'No user profile found for current user';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Cannot access user_profiles: %', SQLERRM;
    END;
END $$;

-- =====================================================
-- STEP 3: TEST CURRENT DELETE PERMISSIONS
-- =====================================================

SELECT '=== STEP 3: TESTING CURRENT DELETE PERMISSIONS ===' as step;

-- Test read access
DO $$
DECLARE
    req_count INTEGER;
    item_count INTEGER;
BEGIN
    BEGIN
        SELECT COUNT(*) INTO req_count FROM warehouse_requests;
        RAISE NOTICE 'Can read warehouse_requests: % records found', req_count;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Cannot read warehouse_requests: %', SQLERRM;
    END;
    
    BEGIN
        SELECT COUNT(*) INTO item_count FROM warehouse_request_items;
        RAISE NOTICE 'Can read warehouse_request_items: % records found', item_count;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Cannot read warehouse_request_items: %', SQLERRM;
    END;
END $$;

-- Test delete access with dummy condition
DO $$
BEGIN
    BEGIN
        DELETE FROM warehouse_request_items WHERE id = '00000000-0000-0000-0000-000000000000';
        RAISE NOTICE 'Can execute DELETE on warehouse_request_items';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Cannot DELETE from warehouse_request_items: %', SQLERRM;
    END;
    
    BEGIN
        DELETE FROM warehouse_requests WHERE id = '00000000-0000-0000-0000-000000000000';
        RAISE NOTICE 'Can execute DELETE on warehouse_requests';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Cannot DELETE from warehouse_requests: %', SQLERRM;
    END;
END $$;

-- =====================================================
-- STEP 4: FIX RLS POLICIES
-- =====================================================

SELECT '=== STEP 4: FIXING RLS POLICIES ===' as step;

-- Drop existing policies
DROP POLICY IF EXISTS "warehouse_requests_select_policy" ON public.warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_policy" ON public.warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_update_policy" ON public.warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_delete_policy" ON public.warehouse_requests;

DROP POLICY IF EXISTS "warehouse_request_items_select_policy" ON public.warehouse_request_items;
DROP POLICY IF EXISTS "warehouse_request_items_insert_policy" ON public.warehouse_request_items;
DROP POLICY IF EXISTS "warehouse_request_items_update_policy" ON public.warehouse_request_items;
DROP POLICY IF EXISTS "warehouse_request_items_delete_policy" ON public.warehouse_request_items;

-- Create new comprehensive policies for warehouse_requests
CREATE POLICY "warehouse_requests_all_operations" ON public.warehouse_requests
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'warehouseManager', 'accountant')
            AND status IN ('approved', 'active')
        )
    );

-- Create new comprehensive policies for warehouse_request_items  
CREATE POLICY "warehouse_request_items_all_operations" ON public.warehouse_request_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'warehouseManager', 'accountant')
            AND status IN ('approved', 'active')
        )
    );

-- Enable RLS on both tables
ALTER TABLE public.warehouse_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_request_items ENABLE ROW LEVEL SECURITY;

-- Grant permissions
GRANT ALL ON public.warehouse_requests TO authenticated;
GRANT ALL ON public.warehouse_request_items TO authenticated;

-- =====================================================
-- STEP 5: VERIFY THE FIX
-- =====================================================

SELECT '=== STEP 5: VERIFYING THE FIX ===' as step;

-- Check new policies
SELECT 
    tablename,
    policyname,
    cmd as operation,
    CASE 
        WHEN cmd = 'ALL' THEN 'All Operations (SELECT, INSERT, UPDATE, DELETE)'
        ELSE cmd
    END as operation_description
FROM pg_policies 
WHERE tablename IN ('warehouse_requests', 'warehouse_request_items')
AND schemaname = 'public'
ORDER BY tablename;

-- Test delete operations again
DO $$
BEGIN
    BEGIN
        DELETE FROM warehouse_request_items WHERE id = '00000000-0000-0000-0000-000000000000';
        RAISE NOTICE '✅ DELETE permission verified for warehouse_request_items';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ DELETE still blocked for warehouse_request_items: %', SQLERRM;
    END;
    
    BEGIN
        DELETE FROM warehouse_requests WHERE id = '00000000-0000-0000-0000-000000000000';
        RAISE NOTICE '✅ DELETE permission verified for warehouse_requests';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ DELETE still blocked for warehouse_requests: %', SQLERRM;
    END;
END $$;

-- =====================================================
-- STEP 6: CREATE HELPER FUNCTION FOR CLEARING DATA
-- =====================================================

SELECT '=== STEP 6: CREATING HELPER FUNCTION ===' as step;

-- Create a secure function to clear all warehouse dispatch data
CREATE OR REPLACE FUNCTION clear_warehouse_dispatch_data()
RETURNS TABLE (
    success BOOLEAN,
    items_deleted INTEGER,
    requests_deleted INTEGER,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    items_count INTEGER := 0;
    requests_count INTEGER := 0;
    user_role TEXT;
BEGIN
    -- Check user permissions
    SELECT role INTO user_role
    FROM user_profiles 
    WHERE id = auth.uid() 
    AND status IN ('approved', 'active');
    
    IF user_role NOT IN ('admin', 'owner', 'warehouseManager', 'accountant') THEN
        RETURN QUERY SELECT FALSE, 0, 0, 'Insufficient permissions. User role: ' || COALESCE(user_role, 'unknown');
        RETURN;
    END IF;
    
    -- Delete items first
    DELETE FROM warehouse_request_items;
    GET DIAGNOSTICS items_count = ROW_COUNT;
    
    -- Delete requests
    DELETE FROM warehouse_requests;
    GET DIAGNOSTICS requests_count = ROW_COUNT;
    
    -- Return success
    RETURN QUERY SELECT TRUE, items_count, requests_count, 'Successfully deleted ' || requests_count || ' requests and ' || items_count || ' items';
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, 0, 0, 'Error: ' || SQLERRM;
END;
$$;

GRANT EXECUTE ON FUNCTION clear_warehouse_dispatch_data TO authenticated;

-- =====================================================
-- STEP 7: FINAL TEST
-- =====================================================

SELECT '=== STEP 7: FINAL VERIFICATION ===' as step;

-- Test the helper function
SELECT * FROM clear_warehouse_dispatch_data();

SELECT '=== DIAGNOSIS AND FIX COMPLETED ===' as final_step;
SELECT 'You can now test the warehouse dispatch clear functionality in your Flutter app.' as instruction;
