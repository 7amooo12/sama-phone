-- ============================================================================
-- FINAL SEARCH DIAGNOSIS FOR ACCOUNTANT
-- ============================================================================
-- تشخيص نهائي لمشكلة البحث للمحاسب
-- ============================================================================

-- 1. Check what search functions exist
SELECT 
  'EXISTING SEARCH FUNCTIONS' as check_type,
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%search%'
ORDER BY routine_name;

-- 2. Test basic table access
SELECT 'PRODUCTS ACCESS' as test, COUNT(*) as count FROM products LIMIT 1;
SELECT 'WAREHOUSES ACCESS' as test, COUNT(*) as count FROM warehouses LIMIT 1;
SELECT 'WAREHOUSE_INVENTORY ACCESS' as test, COUNT(*) as count FROM warehouse_inventory LIMIT 1;
SELECT 'USER_PROFILES ACCESS' as test, COUNT(*) as count FROM user_profiles LIMIT 1;

-- 3. Check RLS policies on key tables
SELECT 
  'PRODUCTS POLICIES' as table_name,
  policyname,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'products' AND schemaname = 'public';

SELECT 
  'WAREHOUSES POLICIES' as table_name,
  policyname,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'warehouses' AND schemaname = 'public';

SELECT 
  'WAREHOUSE_INVENTORY POLICIES' as table_name,
  policyname,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'warehouse_inventory' AND schemaname = 'public';

SELECT 
  'USER_PROFILES POLICIES' as table_name,
  policyname,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'user_profiles' AND schemaname = 'public';

-- 4. Check if accountant is blocked specifically
SELECT 
  'ACCOUNTANT BLOCKING POLICIES' as issue_type,
  tablename,
  policyname,
  cmd,
  qual
FROM pg_policies 
WHERE schemaname = 'public'
  AND tablename IN ('products', 'warehouses', 'warehouse_inventory', 'user_profiles')
  AND cmd = 'SELECT'
  AND qual NOT LIKE '%accountant%'
  AND (qual LIKE '%role%' OR qual LIKE '%admin%' OR qual LIKE '%owner%');

-- 5. Test a simple search query
SELECT 
  'SIMPLE SEARCH TEST' as test_type,
  id,
  name,
  category
FROM products 
WHERE name ILIKE '%test%' OR name ILIKE '%منتج%'
LIMIT 3;

-- 6. Check function permissions
SELECT 
  'FUNCTION PERMISSIONS' as check_type,
  routine_name,
  specific_name,
  routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND (routine_name LIKE '%search%' OR routine_name LIKE '%warehouse%')
ORDER BY routine_name;

-- 7. Check table grants
SELECT 
  'TABLE GRANTS' as check_type,
  table_name,
  privilege_type,
  grantee
FROM information_schema.table_privileges 
WHERE table_schema = 'public' 
  AND table_name IN ('products', 'warehouses', 'warehouse_inventory', 'user_profiles')
  AND grantee IN ('authenticated', 'public', 'postgres')
ORDER BY table_name, privilege_type;

-- 8. Final summary
SELECT 
  'SUMMARY' as result,
  'Check the results above to identify the search problem' as instruction,
  'Look for ACCOUNTANT BLOCKING POLICIES and missing FUNCTION PERMISSIONS' as guidance;
