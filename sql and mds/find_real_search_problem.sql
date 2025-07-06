-- ============================================================================
-- FIND THE REAL SEARCH PROBLEM
-- ============================================================================

-- Check if search functions exist
SELECT
  'SEARCH FUNCTIONS CHECK' as info,
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND (routine_name LIKE '%search%' OR routine_name LIKE '%Search%')
ORDER BY routine_name;

-- Check basic table access for authenticated users
SELECT 
  'PRODUCTS ACCESS TEST' as test_type,
  COUNT(*) as can_read_count
FROM products 
LIMIT 1;

SELECT 
  'WAREHOUSES ACCESS TEST' as test_type,
  COUNT(*) as can_read_count
FROM warehouses 
LIMIT 1;

SELECT 
  'WAREHOUSE_INVENTORY ACCESS TEST' as test_type,
  COUNT(*) as can_read_count
FROM warehouse_inventory 
LIMIT 1;

SELECT 
  'USER_PROFILES ACCESS TEST' as test_type,
  COUNT(*) as can_read_count
FROM user_profiles 
LIMIT 1;

-- Check if the original search functions from the app exist
SELECT 
  'ORIGINAL SEARCH FUNCTIONS' as info,
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name IN (
    'search_warehouse_products',
    'search_warehouse_categories',
    'search_products',
    'search_warehouses',
    'search_users'
  );

-- Check table permissions for authenticated role
SELECT 
  'TABLE PERMISSIONS' as info,
  table_name,
  privilege_type,
  grantee
FROM information_schema.table_privileges 
WHERE table_schema = 'public' 
  AND table_name IN ('products', 'warehouses', 'warehouse_inventory', 'user_profiles')
  AND grantee IN ('authenticated', 'public')
ORDER BY table_name, privilege_type;

-- Check if RLS is blocking everything
SELECT
  'RLS STATUS CHECK' as info,
  t.tablename,
  t.rowsecurity as rls_enabled,
  COUNT(p.policyname) as policy_count
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
WHERE t.schemaname = 'public'
  AND t.tablename IN ('products', 'warehouses', 'warehouse_inventory', 'user_profiles')
GROUP BY t.tablename, t.rowsecurity
ORDER BY t.tablename;

-- Test simple queries that the app might be using
SELECT 
  'SIMPLE PRODUCT QUERY TEST' as test_type,
  'Testing basic product search query' as description;

-- Try a basic search query like the app would do
SELECT 
  id,
  name,
  category
FROM products 
WHERE name ILIKE '%test%' 
LIMIT 5;

-- Check if there are any specific search-related tables
SELECT 
  'ALL TABLES' as info,
  tablename
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- Final diagnosis - simple version
SELECT 'DIAGNOSIS' as result, 'Check results above' as instruction;
