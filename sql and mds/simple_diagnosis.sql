-- ============================================================================
-- SIMPLE DIAGNOSIS FOR ACCOUNTANT SEARCH PROBLEM
-- ============================================================================

-- Check all tables with RLS
SELECT 
  'TABLE RLS STATUS' as info,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;

-- Check all policies
SELECT 
  'ALL POLICIES' as info,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN qual LIKE '%accountant%' THEN 'HAS ACCOUNTANT'
    WHEN qual LIKE '%admin%' THEN 'HAS ADMIN'
    WHEN qual LIKE '%owner%' THEN 'HAS OWNER'
    WHEN qual LIKE '%authenticated%' THEN 'HAS AUTHENTICATED'
    ELSE 'OTHER'
  END as access_type,
  qual as policy_condition
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, cmd;

-- Check products table specifically
SELECT 
  'PRODUCTS POLICIES' as info,
  policyname,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'products' AND schemaname = 'public';

-- Check warehouse_inventory table
SELECT 
  'WAREHOUSE_INVENTORY POLICIES' as info,
  policyname,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'warehouse_inventory' AND schemaname = 'public';

-- Check warehouses table
SELECT 
  'WAREHOUSES POLICIES' as info,
  policyname,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'warehouses' AND schemaname = 'public';

-- Check user_profiles table
SELECT 
  'USER_PROFILES POLICIES' as info,
  policyname,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'user_profiles' AND schemaname = 'public';

-- Check functions
SELECT 
  'SEARCH FUNCTIONS' as info,
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%search%';

-- Find blocking policies
SELECT 
  'BLOCKING POLICIES' as info,
  tablename,
  policyname,
  cmd,
  'BLOCKS ACCOUNTANT' as problem
FROM pg_policies 
WHERE schemaname = 'public'
  AND cmd = 'SELECT'
  AND qual NOT LIKE '%accountant%'
  AND (qual LIKE '%admin%' OR qual LIKE '%owner%')
  AND tablename IN ('products', 'warehouse_inventory', 'warehouses', 'user_profiles');

-- Summary
SELECT 
  'SUMMARY' as info,
  'Check BLOCKING POLICIES results above' as instruction;
