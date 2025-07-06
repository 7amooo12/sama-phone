-- ============================================================================
-- QUICK ACCOUNTANT SEARCH DIAGNOSTIC
-- ============================================================================
-- This script provides a quick diagnostic of Accountant search functionality
-- Run this to identify issues with RLS policies for search operations
-- ============================================================================

-- ==================== STEP 1: CHECK USER CONTEXT ====================

SELECT 
  '🔍 CURRENT SESSION INFO' as check_type,
  auth.uid() as user_id,
  auth.role() as auth_role,
  current_user as db_user;

-- Check if current user is an accountant
SELECT 
  '👤 USER ROLE CHECK' as check_type,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
        AND role = 'accountant' 
        AND status = 'approved'
    ) THEN '✅ VALID ACCOUNTANT USER'
    WHEN EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
        AND role = 'accountant'
    ) THEN '⚠️ ACCOUNTANT BUT NOT APPROVED'
    WHEN auth.uid() IS NOT NULL THEN '❌ NOT AN ACCOUNTANT'
    ELSE '❌ NOT AUTHENTICATED'
  END as user_status;

-- ==================== STEP 2: QUICK TABLE ACCESS TEST ====================

-- Test products table access
SELECT 
  '📦 PRODUCTS ACCESS' as table_test,
  CASE 
    WHEN COUNT(*) > 0 THEN CONCAT('✅ SUCCESS - Can read ', COUNT(*), ' products')
    ELSE '❌ FAILED - Cannot read products'
  END as access_result
FROM (SELECT * FROM products LIMIT 1) p;

-- Test warehouse_inventory access
SELECT 
  '🏪 INVENTORY ACCESS' as table_test,
  CASE 
    WHEN COUNT(*) > 0 THEN CONCAT('✅ SUCCESS - Can read ', COUNT(*), ' inventory records')
    ELSE '❌ FAILED - Cannot read inventory'
  END as access_result
FROM (SELECT * FROM warehouse_inventory LIMIT 1) wi;

-- Test warehouses access
SELECT 
  '🏢 WAREHOUSES ACCESS' as table_test,
  CASE 
    WHEN COUNT(*) > 0 THEN CONCAT('✅ SUCCESS - Can read ', COUNT(*), ' warehouses')
    ELSE '❌ FAILED - Cannot read warehouses'
  END as access_result
FROM (SELECT * FROM warehouses LIMIT 1) w;

-- Test user_profiles access
SELECT 
  '👥 USER PROFILES ACCESS' as table_test,
  CASE 
    WHEN COUNT(*) > 0 THEN CONCAT('✅ SUCCESS - Can read ', COUNT(*), ' user profiles')
    ELSE '❌ FAILED - Cannot read user profiles'
  END as access_result
FROM (SELECT * FROM user_profiles LIMIT 1) up;

-- ==================== STEP 3: SEARCH FUNCTION TEST ====================

-- Test search function existence and permissions
SELECT 
  '🔧 SEARCH FUNCTIONS' as function_test,
  routine_name,
  CASE 
    WHEN has_function_privilege(routine_name || '(text, uuid[], integer, integer)', 'execute') 
    THEN '✅ CAN EXECUTE'
    ELSE '❌ NO EXECUTE PERMISSION'
  END as permission_status
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name IN ('search_warehouse_products', 'search_warehouse_categories');

-- ==================== STEP 4: POLICY ANALYSIS ====================

-- Check which policies exist for key tables
SELECT 
  '🛡️ RLS POLICIES SUMMARY' as policy_check,
  tablename,
  COUNT(*) as policy_count,
  STRING_AGG(policyname, ', ') as policy_names
FROM pg_policies 
WHERE tablename IN ('products', 'warehouse_inventory', 'warehouses', 'user_profiles')
  AND schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

-- Check for accountant-specific policies
SELECT 
  '👨‍💼 ACCOUNTANT POLICIES' as policy_check,
  tablename,
  policyname,
  cmd as operation,
  CASE 
    WHEN qual LIKE '%accountant%' OR with_check LIKE '%accountant%' THEN '✅ HAS ACCOUNTANT ACCESS'
    ELSE '❌ NO ACCOUNTANT ACCESS'
  END as accountant_access
FROM pg_policies 
WHERE tablename IN ('products', 'warehouse_inventory', 'warehouses', 'user_profiles')
  AND schemaname = 'public'
  AND (qual LIKE '%accountant%' OR with_check LIKE '%accountant%' OR policyname LIKE '%accountant%')
ORDER BY tablename, cmd;

-- ==================== STEP 5: COMMON ISSUES CHECK ====================

-- Check for overly restrictive policies
SELECT 
  '⚠️ POTENTIAL ISSUES' as issue_check,
  'Checking for overly restrictive policies' as description;

-- Look for policies that might block accountant access
SELECT 
  '🚨 RESTRICTIVE POLICIES' as issue_type,
  tablename,
  policyname,
  cmd,
  'This policy might be blocking accountant access' as warning
FROM pg_policies 
WHERE tablename IN ('products', 'warehouse_inventory', 'warehouses', 'user_profiles')
  AND schemaname = 'public'
  AND (
    (qual NOT LIKE '%accountant%' AND with_check NOT LIKE '%accountant%') OR
    (qual LIKE '%admin%' AND qual NOT LIKE '%accountant%') OR
    (with_check LIKE '%admin%' AND with_check NOT LIKE '%accountant%')
  )
  AND cmd = 'SELECT'
ORDER BY tablename;

-- ==================== STEP 6: RECOMMENDATIONS ====================

-- Provide recommendations based on findings
SELECT 
  '💡 RECOMMENDATIONS' as recommendation_type,
  CASE 
    WHEN NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'products' 
        AND (qual LIKE '%accountant%' OR with_check LIKE '%accountant%')
    ) THEN 'Run fix_accountant_search_rls_policies.sql to add missing policies'
    WHEN NOT EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_name = 'search_warehouse_products'
    ) THEN 'Run warehouse search migration: 20250615000004_create_warehouse_search_functions.sql'
    ELSE 'Policies appear to be in place - check user authentication and approval status'
  END as recommendation;

-- ==================== STEP 7: QUICK FIX COMMANDS ====================

SELECT 
  '🔧 QUICK FIX COMMANDS' as fix_type,
  'If issues found, run these commands:' as instruction;

SELECT 
  '1. Enable RLS' as step,
  'ALTER TABLE products ENABLE ROW LEVEL SECURITY;' as command;

SELECT 
  '2. Grant Function Access' as step,
  'GRANT EXECUTE ON FUNCTION search_warehouse_products TO authenticated;' as command;

SELECT 
  '3. Create Basic Policy' as step,
  'CREATE POLICY "products_accountant_access" ON products FOR SELECT USING (auth.uid() IS NOT NULL);' as command;

-- ==================== COMPLETION ====================

SELECT 
  '✅ DIAGNOSTIC COMPLETE' as status,
  'Review results above for any ❌ FAILED or 🚨 issues' as instruction,
  'If all tests show ✅ SUCCESS, search should work' as success_indicator;
