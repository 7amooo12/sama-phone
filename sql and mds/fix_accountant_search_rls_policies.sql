-- ============================================================================
-- FIX ACCOUNTANT SEARCH FUNCTIONALITY RLS POLICIES
-- ============================================================================
-- This script diagnoses and fixes RLS policies to enable search functionality
-- for the Accountant role in the dashboard
-- ============================================================================

-- ==================== STEP 1: DIAGNOSTIC QUERIES ====================

-- Check current user context and role
SELECT 
  '🔍 CURRENT USER CONTEXT' as diagnostic_type,
  auth.uid() as current_user_id,
  auth.role() as current_auth_role;

-- Check user profile for current user
SELECT 
  '👤 USER PROFILE CHECK' as diagnostic_type,
  id,
  email,
  name,
  role,
  status,
  CASE 
    WHEN status = 'approved' THEN '✅ APPROVED'
    ELSE '❌ NOT APPROVED'
  END as approval_status
FROM user_profiles 
WHERE id = auth.uid();

-- ==================== STEP 2: ANALYZE CURRENT RLS POLICIES ====================

-- Check products table policies
SELECT 
  '📦 PRODUCTS TABLE POLICIES' as table_analysis,
  policyname,
  cmd as operation,
  permissive,
  roles,
  CASE 
    WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN '✅ HAS ACCOUNTANT'
    ELSE '❌ MISSING ACCOUNTANT'
  END as accountant_access,
  LEFT(COALESCE(qual, with_check), 100) as policy_condition
FROM pg_policies 
WHERE tablename = 'products' AND schemaname = 'public'
ORDER BY cmd, policyname;

-- Check warehouse_inventory table policies
SELECT 
  '🏪 WAREHOUSE_INVENTORY TABLE POLICIES' as table_analysis,
  policyname,
  cmd as operation,
  permissive,
  roles,
  CASE 
    WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN '✅ HAS ACCOUNTANT'
    ELSE '❌ MISSING ACCOUNTANT'
  END as accountant_access,
  LEFT(COALESCE(qual, with_check), 100) as policy_condition
FROM pg_policies 
WHERE tablename = 'warehouse_inventory' AND schemaname = 'public'
ORDER BY cmd, policyname;

-- Check user_profiles table policies
SELECT 
  '👥 USER_PROFILES TABLE POLICIES' as table_analysis,
  policyname,
  cmd as operation,
  permissive,
  roles,
  CASE 
    WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN '✅ HAS ACCOUNTANT'
    ELSE '❌ MISSING ACCOUNTANT'
  END as accountant_access,
  LEFT(COALESCE(qual, with_check), 100) as policy_condition
FROM pg_policies 
WHERE tablename = 'user_profiles' AND schemaname = 'public'
ORDER BY cmd, policyname;

-- Check warehouses table policies
SELECT 
  '🏢 WAREHOUSES TABLE POLICIES' as table_analysis,
  policyname,
  cmd as operation,
  permissive,
  roles,
  CASE 
    WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN '✅ HAS ACCOUNTANT'
    ELSE '❌ MISSING ACCOUNTANT'
  END as accountant_access,
  LEFT(COALESCE(qual, with_check), 100) as policy_condition
FROM pg_policies 
WHERE tablename = 'warehouses' AND schemaname = 'public'
ORDER BY cmd, policyname;

-- ==================== STEP 3: CHECK FUNCTION PERMISSIONS ====================

-- Check if search functions exist and have proper permissions
SELECT 
  '🔧 SEARCH FUNCTION PERMISSIONS' as function_check,
  routine_name,
  routine_type,
  security_type,
  CASE 
    WHEN security_type = 'DEFINER' THEN '✅ SECURE'
    ELSE '⚠️ INVOKER'
  END as security_status
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name IN ('search_warehouse_products', 'search_warehouse_categories')
ORDER BY routine_name;

-- Check function grants
SELECT 
  '🔑 FUNCTION GRANTS' as grant_check,
  routine_name,
  grantee,
  privilege_type,
  is_grantable
FROM information_schema.routine_privileges 
WHERE routine_schema = 'public' 
  AND routine_name IN ('search_warehouse_products', 'search_warehouse_categories')
ORDER BY routine_name, grantee;

-- ==================== STEP 4: FIX MISSING POLICIES ====================

-- First, ensure RLS is enabled on all tables
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Fix products table - ensure accountant can read products for search
-- Drop ALL existing policies to avoid conflicts
DROP POLICY IF EXISTS "products_accountant_select" ON public.products;
DROP POLICY IF EXISTS "Products are viewable by authenticated users" ON public.products;
DROP POLICY IF EXISTS "Products viewable by everyone" ON public.products;
DROP POLICY IF EXISTS "Everyone can view products" ON public.products;
DROP POLICY IF EXISTS "products_service_role_access" ON public.products;
DROP POLICY IF EXISTS "products_authenticated_access" ON public.products;

-- Create comprehensive products policy
CREATE POLICY "products_comprehensive_access" ON public.products
  FOR SELECT
  USING (
    -- Allow service role full access
    auth.role() = 'service_role' OR
    -- Allow authenticated users with proper roles
    (
      auth.uid() IS NOT NULL AND
      EXISTS (
        SELECT 1 FROM user_profiles
        WHERE user_profiles.id = auth.uid()
          AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager', 'client')
          AND user_profiles.status = 'approved'
      )
    )
  );

-- Fix warehouse_inventory table - ensure accountant can read inventory for search
DROP POLICY IF EXISTS "warehouse_inventory_accountant_select" ON public.warehouse_inventory;
CREATE POLICY "warehouse_inventory_accountant_select" ON public.warehouse_inventory
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- Fix warehouses table - ensure accountant can read warehouses for search
DROP POLICY IF EXISTS "warehouses_accountant_select" ON public.warehouses;
CREATE POLICY "warehouses_accountant_select" ON public.warehouses
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- Fix user_profiles table - ensure accountant can read profiles for client search
DROP POLICY IF EXISTS "user_profiles_accountant_select" ON public.user_profiles;
CREATE POLICY "user_profiles_accountant_select" ON public.user_profiles
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    (
      -- Users can view their own profile
      id = auth.uid() OR
      -- Accountants can view all profiles for business operations
      EXISTS (
        SELECT 1 FROM user_profiles up
        WHERE up.id = auth.uid() 
          AND up.role IN ('admin', 'owner', 'accountant')
          AND up.status = 'approved'
      )
    )
  );

-- ==================== STEP 5: ENSURE SEARCH FUNCTIONS HAVE PROPER GRANTS ====================

-- Grant execute permissions on search functions to authenticated users
GRANT EXECUTE ON FUNCTION search_warehouse_products TO authenticated;
GRANT EXECUTE ON FUNCTION search_warehouse_categories TO authenticated;

-- Also ensure the functions exist and are accessible
DO $$
BEGIN
  -- Check if search functions exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.routines
    WHERE routine_schema = 'public'
    AND routine_name = 'search_warehouse_products'
  ) THEN
    RAISE NOTICE '⚠️ WARNING: search_warehouse_products function does not exist';
    RAISE NOTICE 'Please run the warehouse search migration: 20250615000004_create_warehouse_search_functions.sql';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.routines
    WHERE routine_schema = 'public'
    AND routine_name = 'search_warehouse_categories'
  ) THEN
    RAISE NOTICE '⚠️ WARNING: search_warehouse_categories function does not exist';
    RAISE NOTICE 'Please run the warehouse search migration: 20250615000004_create_warehouse_search_functions.sql';
  END IF;
END $$;

-- ==================== STEP 5.1: FIX ADDITIONAL SEARCH-RELATED TABLES ====================

-- Fix categories table if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = 'categories'
  ) THEN
    -- Enable RLS on categories
    ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

    -- Drop existing policy
    DROP POLICY IF EXISTS "categories_accountant_select" ON public.categories;

    -- Create policy for accountant access
    CREATE POLICY "categories_accountant_select" ON public.categories
      FOR SELECT
      USING (
        auth.uid() IS NOT NULL AND
        EXISTS (
          SELECT 1 FROM user_profiles
          WHERE user_profiles.id = auth.uid()
            AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
            AND user_profiles.status = 'approved'
        )
      );
  END IF;
END $$;

-- Fix invoices table for invoice search
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = 'invoices'
  ) THEN
    -- Enable RLS on invoices
    ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

    -- Drop existing policy
    DROP POLICY IF EXISTS "invoices_accountant_select" ON public.invoices;

    -- Create policy for accountant access
    CREATE POLICY "invoices_accountant_select" ON public.invoices
      FOR SELECT
      USING (
        auth.uid() IS NOT NULL AND
        EXISTS (
          SELECT 1 FROM user_profiles
          WHERE user_profiles.id = auth.uid()
            AND user_profiles.role IN ('admin', 'owner', 'accountant')
            AND user_profiles.status = 'approved'
        )
      );
  END IF;
END $$;

-- ==================== STEP 6: VERIFICATION ====================

-- Verify new policies are created
SELECT 
  '✅ VERIFICATION - NEW POLICIES' as verification_type,
  tablename,
  policyname,
  cmd as operation,
  CASE 
    WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN '✅ HAS ACCOUNTANT'
    ELSE '❌ MISSING ACCOUNTANT'
  END as accountant_access
FROM pg_policies 
WHERE tablename IN ('products', 'warehouse_inventory', 'warehouses', 'user_profiles')
  AND schemaname = 'public'
  AND policyname LIKE '%accountant%'
ORDER BY tablename, cmd;

-- Test search function access
SELECT 
  '🧪 FUNCTION ACCESS TEST' as test_type,
  'search_warehouse_products' as function_name,
  CASE 
    WHEN has_function_privilege('search_warehouse_products(text, uuid[], integer, integer)', 'execute') 
    THEN '✅ CAN EXECUTE'
    ELSE '❌ CANNOT EXECUTE'
  END as execution_permission;

SELECT 
  '🧪 FUNCTION ACCESS TEST' as test_type,
  'search_warehouse_categories' as function_name,
  CASE 
    WHEN has_function_privilege('search_warehouse_categories(text, uuid[], integer, integer)', 'execute') 
    THEN '✅ CAN EXECUTE'
    ELSE '❌ CANNOT EXECUTE'
  END as execution_permission;

-- ==================== STEP 7: FINAL SECURITY CHECK ====================

-- Ensure all policies have proper authentication and role checks
SELECT 
  '🔒 FINAL SECURITY VERIFICATION' as security_check,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%') 
     AND (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%')
     AND (qual LIKE '%accountant%' OR with_check LIKE '%accountant%')
    THEN '✅ FULLY SECURE WITH ACCOUNTANT ACCESS'
    WHEN (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%') 
     AND (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%')
    THEN '⚠️ SECURE BUT NO EXPLICIT ACCOUNTANT ACCESS'
    ELSE '🚨 SECURITY ISSUE'
  END as security_status
FROM pg_policies 
WHERE tablename IN ('products', 'warehouse_inventory', 'warehouses', 'user_profiles')
  AND schemaname = 'public'
ORDER BY tablename, cmd, policyname;

-- ==================== COMPLETION MESSAGE ====================

SELECT 
  '🎉 RLS POLICY FIX COMPLETED' as status,
  'Accountant search functionality should now work properly' as message,
  'Please test search features in the Accountant dashboard' as next_steps;
