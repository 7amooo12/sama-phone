-- COMPREHENSIVE FIX: Resolve infinite recursion in ALL tables with user_profiles RLS dependencies
-- This addresses PostgreSQL error: "infinite recursion detected in policy for relation user_profiles"
-- Affects: client_orders, warehouses, warehouse_inventory, warehouse_requests, warehouse_transactions, products, etc.

-- =====================================================
-- STEP 1: IDENTIFY ALL AFFECTED TABLES
-- =====================================================

SELECT 'Starting comprehensive infinite recursion fix for ALL tables...' as status;

-- List all tables with RLS policies that query user_profiles
SELECT 
    'AFFECTED TABLES WITH user_profiles DEPENDENCIES:' as info,
    tablename,
    policyname,
    cmd
FROM pg_policies 
WHERE (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%')
  AND tablename != 'user_profiles'
ORDER BY tablename, policyname;

-- =====================================================
-- STEP 2: CREATE UNIVERSAL SECURITY DEFINER FUNCTIONS
-- =====================================================

-- Function to check if user has admin role
CREATE OR REPLACE FUNCTION public.user_is_admin_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND role = 'admin'
        AND status IN ('approved', 'active')
    );
$$;

-- Function to check if user has owner role
CREATE OR REPLACE FUNCTION public.user_is_owner_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND role = 'owner'
        AND status IN ('approved', 'active')
    );
$$;

-- Function to check if user has accountant role
CREATE OR REPLACE FUNCTION public.user_is_accountant_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND role = 'accountant'
        AND status IN ('approved', 'active')
    );
$$;

-- Function to check if user has warehouse manager role
CREATE OR REPLACE FUNCTION public.user_is_warehouse_manager_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND role IN ('warehouseManager', 'warehouse_manager')
        AND status IN ('approved', 'active')
    );
$$;

-- Function to check if user has worker role
CREATE OR REPLACE FUNCTION public.user_is_worker_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND role = 'worker'
        AND status IN ('approved', 'active')
    );
$$;

-- Function to check if user has client role
CREATE OR REPLACE FUNCTION public.user_is_client_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND role = 'client'
        AND status IN ('approved', 'active')
    );
$$;

-- Function to check if user has admin OR owner role (common pattern)
CREATE OR REPLACE FUNCTION public.user_is_admin_or_owner_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'owner')
        AND status IN ('approved', 'active')
    );
$$;

-- Function to check if user has warehouse access (admin/owner/accountant/warehouse_manager)
CREATE OR REPLACE FUNCTION public.user_has_warehouse_access_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'owner', 'accountant', 'warehouseManager', 'warehouse_manager')
        AND status IN ('approved', 'active')
    );
$$;

-- Function to check if user has order management access (admin/owner/worker)
CREATE OR REPLACE FUNCTION public.user_has_order_access_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'owner', 'worker', 'accountant')
        AND status IN ('approved', 'active')
    );
$$;

-- Function to check if user is approved (any role)
CREATE OR REPLACE FUNCTION public.user_is_approved_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND status IN ('approved', 'active')
    );
$$;

SELECT 'Created universal SECURITY DEFINER functions for all role patterns' as step_completed;

-- =====================================================
-- STEP 3: GRANT PERMISSIONS ON ALL FUNCTIONS
-- =====================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.user_is_admin_safe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_is_owner_safe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_is_accountant_safe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_is_warehouse_manager_safe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_is_worker_safe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_is_client_safe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_is_admin_or_owner_safe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_has_warehouse_access_safe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_has_order_access_safe() TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_is_approved_safe() TO authenticated;

-- Grant execute permissions to service role
GRANT EXECUTE ON FUNCTION public.user_is_admin_safe() TO service_role;
GRANT EXECUTE ON FUNCTION public.user_is_owner_safe() TO service_role;
GRANT EXECUTE ON FUNCTION public.user_is_accountant_safe() TO service_role;
GRANT EXECUTE ON FUNCTION public.user_is_warehouse_manager_safe() TO service_role;
GRANT EXECUTE ON FUNCTION public.user_is_worker_safe() TO service_role;
GRANT EXECUTE ON FUNCTION public.user_is_client_safe() TO service_role;
GRANT EXECUTE ON FUNCTION public.user_is_admin_or_owner_safe() TO service_role;
GRANT EXECUTE ON FUNCTION public.user_has_warehouse_access_safe() TO service_role;
GRANT EXECUTE ON FUNCTION public.user_has_order_access_safe() TO service_role;
GRANT EXECUTE ON FUNCTION public.user_is_approved_safe() TO service_role;

SELECT 'Granted permissions on all SECURITY DEFINER functions' as step_completed;

-- =====================================================
-- STEP 4: VERIFICATION
-- =====================================================

-- Check that all functions exist
SELECT 
    proname as function_name,
    'EXISTS' as status
FROM pg_proc 
WHERE proname LIKE '%_safe'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY proname;

SELECT 'Universal SECURITY DEFINER functions created successfully!' as final_status;

-- =====================================================
-- NEXT STEPS
-- =====================================================

SELECT 
    'NEXT STEPS TO COMPLETE THE FIX:' as instructions,
    '1. Run fix_client_orders_infinite_recursion.sql' as step_1,
    '2. Run fix_warehouses_infinite_recursion.sql' as step_2,
    '3. Run fix_products_infinite_recursion.sql' as step_3,
    '4. Test all affected tables for infinite recursion resolution' as step_4;
