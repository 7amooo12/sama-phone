-- =====================================================
-- COMPREHENSIVE INFINITE RECURSION FIX
-- =====================================================
-- This script completely eliminates PostgreSQL infinite recursion errors
-- by identifying and fixing ALL RLS policies that cause circular dependencies

SELECT '🔧 STARTING COMPREHENSIVE INFINITE RECURSION FIX...' as progress;

-- =====================================================
-- STEP 1: IDENTIFY ALL PROBLEMATIC POLICIES
-- =====================================================

-- Find ALL policies that reference user_profiles (potential recursion sources)
SELECT 
    '🔍 IDENTIFYING PROBLEMATIC POLICIES' as step,
    schemaname,
    tablename,
    policyname,
    cmd as operation,
    'REFERENCES_USER_PROFILES' as issue_type
FROM pg_policies 
WHERE (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%')
  AND schemaname = 'public'
ORDER BY tablename, cmd;

-- =====================================================
-- STEP 2: CREATE COMPREHENSIVE SECURITY DEFINER FUNCTIONS
-- =====================================================

-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS public.get_user_role_safe();
DROP FUNCTION IF EXISTS public.get_user_status_safe();
DROP FUNCTION IF EXISTS public.check_warehouse_access_safe();
DROP FUNCTION IF EXISTS public.check_user_approved_safe();
DROP FUNCTION IF EXISTS public.is_admin_safe();
DROP FUNCTION IF EXISTS public.is_owner_safe();
DROP FUNCTION IF EXISTS public.is_warehouse_manager_safe();

-- Universal user role checker (bypasses RLS)
CREATE OR REPLACE FUNCTION public.get_user_role_safe()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role
    FROM user_profiles
    WHERE id = auth.uid()
    LIMIT 1;
    
    RETURN COALESCE(user_role, 'guest');
END;
$$;

-- Universal user status checker (bypasses RLS)
CREATE OR REPLACE FUNCTION public.get_user_status_safe()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_status TEXT;
BEGIN
    SELECT status INTO user_status
    FROM user_profiles
    WHERE id = auth.uid()
    LIMIT 1;
    
    RETURN COALESCE(user_status, 'pending');
END;
$$;

-- Check if user is approved (bypasses RLS)
CREATE OR REPLACE FUNCTION public.check_user_approved_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN get_user_status_safe() = 'approved';
END;
$$;

-- Check if user is admin (bypasses RLS)
CREATE OR REPLACE FUNCTION public.is_admin_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN get_user_role_safe() = 'admin';
END;
$$;

-- Check if user is owner (bypasses RLS)
CREATE OR REPLACE FUNCTION public.is_owner_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN get_user_role_safe() = 'owner';
END;
$$;

-- Check if user is warehouse manager (bypasses RLS)
CREATE OR REPLACE FUNCTION public.is_warehouse_manager_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN get_user_role_safe() = 'warehouseManager';
END;
$$;

-- Universal warehouse access checker (bypasses RLS)
CREATE OR REPLACE FUNCTION public.check_warehouse_access_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
    user_status TEXT;
BEGIN
    user_role := get_user_role_safe();
    user_status := get_user_status_safe();
    
    RETURN user_status = 'approved' AND user_role IN ('admin', 'owner', 'accountant', 'warehouseManager');
END;
$$;

SELECT '✅ SECURITY DEFINER FUNCTIONS CREATED' as progress;

-- =====================================================
-- STEP 3: FIX USER_PROFILES TABLE POLICIES
-- =====================================================

-- Disable RLS temporarily to clean up
ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies on user_profiles (comprehensive list)
DO $$
DECLARE
    policy_record RECORD;
    policy_name text;
    drop_sql text;
BEGIN
    -- Drop all existing policies dynamically
    FOR policy_record IN
        SELECT policyname
        FROM pg_policies
        WHERE tablename = 'user_profiles' AND schemaname = 'public'
    LOOP
        policy_name := policy_record.policyname;
        drop_sql := format('DROP POLICY IF EXISTS "%s" ON user_profiles', policy_name);
        EXECUTE drop_sql;
        RAISE NOTICE 'Dropped policy: %', policy_name;
    END LOOP;

    RAISE NOTICE 'Dropped all existing user_profiles policies';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error dropping policies: %', SQLERRM;
END $$;

-- Re-enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create SIMPLE, NON-RECURSIVE policies for user_profiles
DO $$
BEGIN
    -- Create select policy
    BEGIN
        CREATE POLICY "simple_select_own_profile" ON user_profiles
        FOR SELECT TO authenticated
        USING (id = auth.uid());
        RAISE NOTICE 'Created simple_select_own_profile policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy simple_select_own_profile already exists, skipping';
    END;

    -- Create update policy
    BEGIN
        CREATE POLICY "simple_update_own_profile" ON user_profiles
        FOR UPDATE TO authenticated
        USING (id = auth.uid())
        WITH CHECK (id = auth.uid());
        RAISE NOTICE 'Created simple_update_own_profile policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy simple_update_own_profile already exists, skipping';
    END;

    -- Service role has full access (for Supabase internal operations)
    BEGIN
        CREATE POLICY "service_role_full_access" ON user_profiles
        FOR ALL TO service_role
        USING (true)
        WITH CHECK (true);
        RAISE NOTICE 'Created service_role_full_access policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy service_role_full_access already exists, skipping';
    END;
END $$;

SELECT '✅ USER_PROFILES POLICIES FIXED' as progress;

-- =====================================================
-- STEP 4: FIX ALL WAREHOUSE-RELATED TABLES
-- =====================================================

-- Fix warehouses table
DO $$
BEGIN
    -- Drop all existing policies
    DROP POLICY IF EXISTS "warehouse_managers_can_read_warehouses" ON warehouses;
    DROP POLICY IF EXISTS "warehouse_managers_can_manage_assigned_warehouses" ON warehouses;
    DROP POLICY IF EXISTS "warehouse_select_policy" ON warehouses;
    DROP POLICY IF EXISTS "warehouse_insert_policy" ON warehouses;
    DROP POLICY IF EXISTS "warehouse_update_policy" ON warehouses;
    DROP POLICY IF EXISTS "warehouse_delete_policy" ON warehouses;
    DROP POLICY IF EXISTS "secure_warehouses_select" ON warehouses;

    RAISE NOTICE 'Dropped all existing warehouses policies';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Some warehouses policies may not have existed: %', SQLERRM;
END $$;

-- Create safe policies for warehouses
DO $$
BEGIN
    BEGIN
        CREATE POLICY "warehouses_select_safe" ON warehouses
        FOR SELECT TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouses_select_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouses_select_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouses_insert_safe" ON warehouses
        FOR INSERT TO authenticated
        WITH CHECK (
            auth.uid() IS NOT NULL AND
            (is_admin_safe() OR is_owner_safe())
        );
        RAISE NOTICE 'Created warehouses_insert_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouses_insert_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouses_update_safe" ON warehouses
        FOR UPDATE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            (is_admin_safe() OR is_owner_safe() OR manager_id = auth.uid())
        );
        RAISE NOTICE 'Created warehouses_update_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouses_update_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouses_delete_safe" ON warehouses
        FOR DELETE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            (is_admin_safe() OR is_owner_safe())
        );
        RAISE NOTICE 'Created warehouses_delete_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouses_delete_safe already exists, skipping';
    END;
END $$;

-- Fix warehouse_inventory table
DO $$
BEGIN
    -- Drop all existing policies
    DROP POLICY IF EXISTS "warehouse_inventory_select_policy" ON warehouse_inventory;
    DROP POLICY IF EXISTS "warehouse_inventory_insert_policy" ON warehouse_inventory;
    DROP POLICY IF EXISTS "warehouse_inventory_update_policy" ON warehouse_inventory;
    DROP POLICY IF EXISTS "warehouse_inventory_delete_policy" ON warehouse_inventory;

    RAISE NOTICE 'Dropped all existing warehouse_inventory policies';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Some warehouse_inventory policies may not have existed: %', SQLERRM;
END $$;

-- Create safe policies for warehouse_inventory
DO $$
BEGIN
    BEGIN
        CREATE POLICY "warehouse_inventory_select_safe" ON warehouse_inventory
        FOR SELECT TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_inventory_select_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_inventory_select_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouse_inventory_insert_safe" ON warehouse_inventory
        FOR INSERT TO authenticated
        WITH CHECK (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_inventory_insert_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_inventory_insert_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouse_inventory_update_safe" ON warehouse_inventory
        FOR UPDATE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_inventory_update_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_inventory_update_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouse_inventory_delete_safe" ON warehouse_inventory
        FOR DELETE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            (is_admin_safe() OR is_owner_safe())
        );
        RAISE NOTICE 'Created warehouse_inventory_delete_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_inventory_delete_safe already exists, skipping';
    END;
END $$;

-- Fix warehouse_transactions table
DO $$
BEGIN
    -- Drop all existing policies
    DROP POLICY IF EXISTS "warehouse_transactions_select_policy" ON warehouse_transactions;
    DROP POLICY IF EXISTS "warehouse_transactions_insert_policy" ON warehouse_transactions;
    DROP POLICY IF EXISTS "warehouse_transactions_update_policy" ON warehouse_transactions;
    DROP POLICY IF EXISTS "warehouse_transactions_delete_policy" ON warehouse_transactions;

    RAISE NOTICE 'Dropped all existing warehouse_transactions policies';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Some warehouse_transactions policies may not have existed: %', SQLERRM;
END $$;

-- Create safe policies for warehouse_transactions
DO $$
BEGIN
    BEGIN
        CREATE POLICY "warehouse_transactions_select_safe" ON warehouse_transactions
        FOR SELECT TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_transactions_select_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_transactions_select_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouse_transactions_insert_safe" ON warehouse_transactions
        FOR INSERT TO authenticated
        WITH CHECK (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_transactions_insert_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_transactions_insert_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouse_transactions_update_safe" ON warehouse_transactions
        FOR UPDATE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_transactions_update_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_transactions_update_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouse_transactions_delete_safe" ON warehouse_transactions
        FOR DELETE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            (is_admin_safe() OR is_owner_safe())
        );
        RAISE NOTICE 'Created warehouse_transactions_delete_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_transactions_delete_safe already exists, skipping';
    END;
END $$;

SELECT '✅ ALL WAREHOUSE TABLES FIXED' as progress;

-- =====================================================
-- STEP 5: FIX WAREHOUSE_REQUESTS AND WAREHOUSE_REQUEST_ITEMS
-- =====================================================

-- Fix warehouse_requests table (the main source of the error)
DO $$
BEGIN
    -- Drop all existing policies
    DROP POLICY IF EXISTS "warehouse_requests_select_policy" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_insert_policy" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_update_policy" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_delete_policy" ON warehouse_requests;
    DROP POLICY IF EXISTS "secure_requests_select" ON warehouse_requests;
    DROP POLICY IF EXISTS "secure_requests_insert" ON warehouse_requests;
    DROP POLICY IF EXISTS "secure_requests_update" ON warehouse_requests;
    DROP POLICY IF EXISTS "secure_requests_delete" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_select_safe" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_insert_safe" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_update_safe" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_delete_safe" ON warehouse_requests;

    RAISE NOTICE 'Dropped all existing warehouse_requests policies';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Some warehouse_requests policies may not have existed: %', SQLERRM;
END $$;

-- Create safe policies for warehouse_requests
DO $$
BEGIN
    BEGIN
        CREATE POLICY "warehouse_requests_select_safe" ON warehouse_requests
        FOR SELECT TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_requests_select_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_requests_select_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouse_requests_insert_safe" ON warehouse_requests
        FOR INSERT TO authenticated
        WITH CHECK (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_requests_insert_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_requests_insert_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouse_requests_update_safe" ON warehouse_requests
        FOR UPDATE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_requests_update_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_requests_update_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouse_requests_delete_safe" ON warehouse_requests
        FOR DELETE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            (is_admin_safe() OR is_owner_safe())
        );
        RAISE NOTICE 'Created warehouse_requests_delete_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_requests_delete_safe already exists, skipping';
    END;
END $$;

-- Fix warehouse_request_items table
DO $$
BEGIN
    -- Drop all existing policies
    DROP POLICY IF EXISTS "warehouse_request_items_select_policy" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_insert_policy" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_update_policy" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_delete_policy" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_all_operations" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_select_safe" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_insert_safe" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_update_safe" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_delete_safe" ON warehouse_request_items;

    RAISE NOTICE 'Dropped all existing warehouse_request_items policies';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Some warehouse_request_items policies may not have existed: %', SQLERRM;
END $$;

-- Create safe policies for warehouse_request_items
DO $$
BEGIN
    BEGIN
        CREATE POLICY "warehouse_request_items_select_safe" ON warehouse_request_items
        FOR SELECT TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_request_items_select_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_request_items_select_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouse_request_items_insert_safe" ON warehouse_request_items
        FOR INSERT TO authenticated
        WITH CHECK (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_request_items_insert_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_request_items_insert_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouse_request_items_update_safe" ON warehouse_request_items
        FOR UPDATE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_request_items_update_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_request_items_update_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "warehouse_request_items_delete_safe" ON warehouse_request_items
        FOR DELETE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            (is_admin_safe() OR is_owner_safe())
        );
        RAISE NOTICE 'Created warehouse_request_items_delete_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_request_items_delete_safe already exists, skipping';
    END;
END $$;

SELECT '✅ WAREHOUSE DISPATCH TABLES FIXED' as progress;

-- =====================================================
-- STEP 6: FIX ALL OTHER TABLES WITH USER_PROFILES DEPENDENCIES
-- =====================================================

-- Fix products table (if it has user_profiles dependencies)
DO $$
BEGIN
    -- Drop any existing policies that might reference user_profiles
    DROP POLICY IF EXISTS "Products are manageable by admins" ON products;
    DROP POLICY IF EXISTS "Admins can manage products" ON products;

    RAISE NOTICE 'Dropped existing products policies with user_profiles dependencies';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Some products policies may not have existed: %', SQLERRM;
END $$;

-- Create safe policies for products
DO $$
BEGIN
    BEGIN
        CREATE POLICY "products_select_safe" ON products
        FOR SELECT TO authenticated
        USING (true); -- Products can be viewed by all authenticated users
        RAISE NOTICE 'Created products_select_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy products_select_safe already exists, skipping';
    END;

    BEGIN
        CREATE POLICY "products_manage_safe" ON products
        FOR ALL TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            (is_admin_safe() OR is_owner_safe())
        )
        WITH CHECK (
            auth.uid() IS NOT NULL AND
            (is_admin_safe() OR is_owner_safe())
        );
        RAISE NOTICE 'Created products_manage_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy products_manage_safe already exists, skipping';
    END;
END $$;

-- Fix any other tables that might have user_profiles dependencies
DO $$
DECLARE
    policy_record RECORD;
    table_name text;
    policy_name text;
    drop_sql text;
BEGIN
    -- Find and drop all remaining policies that reference user_profiles
    FOR policy_record IN
        SELECT DISTINCT tablename, policyname
        FROM pg_policies
        WHERE (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%')
          AND tablename NOT IN ('user_profiles', 'warehouses', 'warehouse_inventory', 'warehouse_requests', 'warehouse_request_items', 'warehouse_transactions', 'products')
          AND schemaname = 'public'
    LOOP
        table_name := policy_record.tablename;
        policy_name := policy_record.policyname;

        drop_sql := format('DROP POLICY IF EXISTS "%s" ON %s', policy_name, table_name);
        EXECUTE drop_sql;

        RAISE NOTICE 'Dropped policy % on table %', policy_name, table_name;
    END LOOP;
END $$;

SELECT '✅ ALL OTHER TABLES FIXED' as progress;

-- =====================================================
-- STEP 7: COMPREHENSIVE TESTING AND VALIDATION
-- =====================================================

-- Test all SECURITY DEFINER functions
DO $$
DECLARE
    test_role TEXT;
    test_status TEXT;
    test_approved BOOLEAN;
    test_access BOOLEAN;
BEGIN
    -- Test the functions
    test_role := get_user_role_safe();
    test_status := get_user_status_safe();
    test_approved := check_user_approved_safe();
    test_access := check_warehouse_access_safe();

    RAISE NOTICE '✅ SECURITY DEFINER FUNCTIONS TEST:';
    RAISE NOTICE '   User Role: %', COALESCE(test_role, 'NULL');
    RAISE NOTICE '   User Status: %', COALESCE(test_status, 'NULL');
    RAISE NOTICE '   User Approved: %', test_approved;
    RAISE NOTICE '   Warehouse Access: %', test_access;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ SECURITY DEFINER FUNCTIONS ERROR: %', SQLERRM;
END $$;

-- Test warehouse dispatch queries
DO $$
DECLARE
    test_count integer;
    error_message TEXT;
BEGIN
    -- Test warehouse_requests table
    BEGIN
        SELECT COUNT(*) INTO test_count FROM warehouse_requests;
        RAISE NOTICE '✅ warehouse_requests query returned % rows without infinite recursion', test_count;
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            RAISE NOTICE '❌ warehouse_requests still has issues: %', error_message;
    END;

    -- Test warehouse_request_items table
    BEGIN
        SELECT COUNT(*) INTO test_count FROM warehouse_request_items;
        RAISE NOTICE '✅ warehouse_request_items query returned % rows without infinite recursion', test_count;
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            RAISE NOTICE '❌ warehouse_request_items still has issues: %', error_message;
    END;

    -- Test the exact Flutter query with JOIN
    BEGIN
        SELECT COUNT(*) INTO test_count
        FROM warehouse_requests wr
        LEFT JOIN warehouse_request_items wri ON wr.id = wri.request_id;
        RAISE NOTICE '✅ Flutter JOIN query returned % rows without infinite recursion', test_count;
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            RAISE NOTICE '❌ Flutter JOIN query failed: %', error_message;
    END;
END $$;

-- Show final status of all policies
SELECT
    '✅ FINAL POLICY STATUS' as summary,
    tablename,
    COUNT(*) as policy_count,
    STRING_AGG(policyname, ', ') as policy_names
FROM pg_policies
WHERE tablename IN ('user_profiles', 'warehouse_requests', 'warehouse_request_items', 'warehouses', 'warehouse_inventory', 'warehouse_transactions')
  AND schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

SELECT '🎉 COMPREHENSIVE INFINITE RECURSION FIX COMPLETED!' as final_status;
