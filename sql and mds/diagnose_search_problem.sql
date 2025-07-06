-- ============================================================================
-- DIAGNOSE SEARCH PROBLEM FOR ACCOUNTANT ROLE
-- ============================================================================
-- تشخيص مشكلة البحث للمحاسب مقارنة بالأدوار الأخرى
-- ============================================================================

-- ==================== STEP 1: CHECK ALL TABLES AND RLS STATUS ====================

SELECT
  'ALL TABLES RLS STATUS' as check_type,
  schemaname,
  tablename,
  rowsecurity as rls_enabled,
  CASE
    WHEN rowsecurity THEN 'RLS ENABLED'
    ELSE 'RLS DISABLED'
  END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- ==================== STEP 2: CHECK ALL RLS POLICIES ====================

SELECT
  'ALL RLS POLICIES' as policy_check,
  tablename,
  policyname,
  cmd as operation,
  permissive,
  roles,
  CASE
    WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN 'ACCOUNTANT INCLUDED'
    WHEN qual LIKE '%admin%' OR with_check LIKE '%admin%' THEN 'ADMIN ONLY'
    WHEN qual LIKE '%owner%' OR with_check LIKE '%owner%' THEN 'OWNER ONLY'
    WHEN qual LIKE '%authenticated%' OR with_check LIKE '%authenticated%' THEN 'AUTHENTICATED'
    ELSE 'OTHER'
  END as access_type,
  LEFT(COALESCE(qual, with_check), 150) as policy_condition
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, cmd, policyname;

-- ==================== STEP 3: CHECK SPECIFIC SEARCH-RELATED TABLES ====================

-- Products table policies
SELECT
  'PRODUCTS TABLE POLICIES' as table_check,
  policyname,
  cmd,
  CASE
    WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN 'ACCOUNTANT CAN ACCESS'
    ELSE 'ACCOUNTANT BLOCKED'
  END as accountant_access,
  qual as condition_text
FROM pg_policies
WHERE tablename = 'products' AND schemaname = 'public'
ORDER BY cmd;

-- Warehouse_inventory table policies
SELECT 
  '🏪 WAREHOUSE_INVENTORY POLICIES' as table_check,
  policyname,
  cmd,
  CASE 
    WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN '✅ ACCOUNTANT CAN ACCESS'
    ELSE '❌ ACCOUNTANT BLOCKED'
  END as accountant_access,
  qual as condition_text
FROM pg_policies 
WHERE tablename = 'warehouse_inventory' AND schemaname = 'public'
ORDER BY cmd;

-- Warehouses table policies
SELECT 
  '🏢 WAREHOUSES POLICIES' as table_check,
  policyname,
  cmd,
  CASE 
    WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN '✅ ACCOUNTANT CAN ACCESS'
    ELSE '❌ ACCOUNTANT BLOCKED'
  END as accountant_access,
  qual as condition_text
FROM pg_policies 
WHERE tablename = 'warehouses' AND schemaname = 'public'
ORDER BY cmd;

-- User_profiles table policies
SELECT 
  '👥 USER_PROFILES POLICIES' as table_check,
  policyname,
  cmd,
  CASE 
    WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN '✅ ACCOUNTANT CAN ACCESS'
    ELSE '❌ ACCOUNTANT BLOCKED'
  END as accountant_access,
  qual as condition_text
FROM pg_policies 
WHERE tablename = 'user_profiles' AND schemaname = 'public'
ORDER BY cmd;

-- ==================== STEP 4: CHECK FUNCTION PERMISSIONS ====================

-- Check all functions and their permissions
SELECT 
  '🔧 ALL FUNCTIONS' as function_check,
  routine_name,
  routine_type,
  security_type,
  CASE 
    WHEN has_function_privilege('authenticated', routine_name, 'execute') 
    THEN '✅ AUTHENTICATED CAN EXECUTE'
    ELSE '❌ NO EXECUTE FOR AUTHENTICATED'
  END as authenticated_access
FROM information_schema.routines 
WHERE routine_schema = 'public'
  AND routine_name LIKE '%search%'
ORDER BY routine_name;

-- ==================== STEP 5: COMPARE ROLE ACCESS ====================

-- Check what each role can access
SELECT 
  '🔍 ROLE COMPARISON' as comparison_type,
  'Checking which roles have access to key tables' as description;

-- Check products access by role
SELECT 
  '📦 PRODUCTS ACCESS BY ROLE' as access_check,
  CASE 
    WHEN qual LIKE '%admin%' THEN 'ADMIN'
    WHEN qual LIKE '%owner%' THEN 'OWNER'
    WHEN qual LIKE '%accountant%' THEN 'ACCOUNTANT'
    WHEN qual LIKE '%warehouseManager%' THEN 'WAREHOUSE_MANAGER'
    WHEN qual LIKE '%authenticated%' THEN 'ALL_AUTHENTICATED'
    ELSE 'OTHER'
  END as role_with_access,
  policyname,
  cmd
FROM pg_policies 
WHERE tablename = 'products' AND schemaname = 'public'
ORDER BY cmd, policyname;

-- ==================== STEP 6: IDENTIFY THE EXACT PROBLEM ====================

-- Find tables that block accountant but allow other roles
SELECT 
  '🚨 TABLES BLOCKING ACCOUNTANT' as problem_identification,
  tablename,
  COUNT(*) as total_policies,
  COUNT(CASE WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN 1 END) as accountant_policies,
  COUNT(CASE WHEN qual LIKE '%admin%' OR with_check LIKE '%admin%' THEN 1 END) as admin_policies,
  COUNT(CASE WHEN qual LIKE '%owner%' OR with_check LIKE '%owner%' THEN 1 END) as owner_policies,
  CASE 
    WHEN COUNT(CASE WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN 1 END) = 0 
     AND COUNT(*) > 0 
    THEN '🚨 ACCOUNTANT COMPLETELY BLOCKED'
    WHEN COUNT(CASE WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN 1 END) < 
         COUNT(CASE WHEN qual LIKE '%admin%' OR with_check LIKE '%admin%' THEN 1 END)
    THEN '⚠️ ACCOUNTANT HAS LESS ACCESS THAN ADMIN'
    ELSE '✅ ACCOUNTANT ACCESS OK'
  END as problem_status
FROM pg_policies 
WHERE schemaname = 'public'
  AND tablename IN ('products', 'warehouse_inventory', 'warehouses', 'user_profiles')
GROUP BY tablename
ORDER BY tablename;

-- ==================== STEP 7: SHOW EXACT POLICIES THAT NEED FIXING ====================

-- Show policies that need to include accountant
SELECT 
  '🔧 POLICIES THAT NEED FIXING' as fix_needed,
  tablename,
  policyname,
  cmd,
  'ADD accountant TO: ' || COALESCE(qual, with_check) as suggested_fix
FROM pg_policies 
WHERE schemaname = 'public'
  AND tablename IN ('products', 'warehouse_inventory', 'warehouses', 'user_profiles')
  AND cmd = 'SELECT'
  AND (qual NOT LIKE '%accountant%' AND with_check NOT LIKE '%accountant%')
  AND (qual LIKE '%admin%' OR qual LIKE '%owner%' OR with_check LIKE '%admin%' OR with_check LIKE '%owner%')
ORDER BY tablename, policyname;

-- ==================== FINAL SUMMARY ====================

SELECT 
  '📊 DIAGNOSIS SUMMARY' as summary_type,
  'Check the results above to see exactly which tables are blocking accountant access' as instruction,
  'Look for 🚨 and ⚠️ indicators to identify the problem' as guidance;
