-- ============================================================================
-- COMPARE USER ROLES ACCESS - ADMIN VS OWNER VS ACCOUNTANT
-- ============================================================================
-- مقارنة صلاحيات الأدوار - أدمن مقابل صاحب العمل مقابل المحاسب
-- ============================================================================

-- 1. Show actual users and their roles
SELECT 
  'ACTUAL USERS BY ROLE' as info,
  role,
  status,
  COUNT(*) as user_count,
  STRING_AGG(name, ', ') as user_names
FROM user_profiles 
GROUP BY role, status
ORDER BY role, status;

-- 2. Show specific admin users
SELECT 
  'ADMIN USERS' as user_type,
  id,
  name,
  email,
  role,
  status,
  created_at
FROM user_profiles 
WHERE role = 'admin'
ORDER BY created_at;

-- 3. Show specific owner users
SELECT 
  'OWNER USERS' as user_type,
  id,
  name,
  email,
  role,
  status,
  created_at
FROM user_profiles 
WHERE role = 'owner'
ORDER BY created_at;

-- 4. Show specific accountant users
SELECT 
  'ACCOUNTANT USERS' as user_type,
  id,
  name,
  email,
  role,
  status,
  created_at
FROM user_profiles 
WHERE role = 'accountant'
ORDER BY created_at;

-- 5. Check ALL RLS policies and which roles they allow
SELECT 
  'ALL RLS POLICIES DETAILED' as policy_info,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN qual LIKE '%admin%' THEN 'ALLOWS ADMIN'
    ELSE 'NO ADMIN'
  END as admin_access,
  CASE 
    WHEN qual LIKE '%owner%' THEN 'ALLOWS OWNER'
    ELSE 'NO OWNER'
  END as owner_access,
  CASE 
    WHEN qual LIKE '%accountant%' THEN 'ALLOWS ACCOUNTANT'
    ELSE 'NO ACCOUNTANT'
  END as accountant_access,
  CASE 
    WHEN qual LIKE '%authenticated%' THEN 'ALLOWS ALL AUTHENTICATED'
    ELSE 'RESTRICTED'
  END as general_access,
  qual as full_condition
FROM pg_policies 
WHERE schemaname = 'public'
  AND tablename IN ('products', 'warehouses', 'warehouse_inventory', 'user_profiles')
ORDER BY tablename, cmd, policyname;

-- 6. Find policies that allow admin/owner but NOT accountant
SELECT 
  'POLICIES BLOCKING ACCOUNTANT' as blocking_info,
  tablename,
  policyname,
  cmd,
  'ADMIN/OWNER CAN ACCESS BUT ACCOUNTANT CANNOT' as problem,
  qual as condition_blocking_accountant
FROM pg_policies 
WHERE schemaname = 'public'
  AND tablename IN ('products', 'warehouses', 'warehouse_inventory', 'user_profiles')
  AND cmd = 'SELECT'
  AND (qual LIKE '%admin%' OR qual LIKE '%owner%')
  AND qual NOT LIKE '%accountant%'
ORDER BY tablename;

-- 7. Check what search functions exist and their security
SELECT 
  'SEARCH FUNCTIONS SECURITY' as function_info,
  routine_name,
  routine_type,
  security_type,
  routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%search%'
ORDER BY routine_name;

-- 8. Test if we can simulate admin access
SELECT 
  'ADMIN ACCESS SIMULATION' as test_type,
  'Testing if admin role conditions work' as description;

-- Test products access with admin-like condition
SELECT 
  'PRODUCTS WITH ADMIN CONDITION' as test,
  COUNT(*) as accessible_products
FROM products p
WHERE EXISTS (
  SELECT 1 FROM user_profiles up 
  WHERE up.role IN ('admin', 'owner') 
  AND up.status = 'approved'
  LIMIT 1
);

-- 9. Test if we can simulate accountant access
SELECT 
  'ACCOUNTANT ACCESS SIMULATION' as test_type,
  'Testing if accountant role conditions work' as description;

-- Test products access with accountant-like condition
SELECT 
  'PRODUCTS WITH ACCOUNTANT CONDITION' as test,
  COUNT(*) as accessible_products
FROM products p
WHERE EXISTS (
  SELECT 1 FROM user_profiles up 
  WHERE up.role IN ('admin', 'owner', 'accountant') 
  AND up.status = 'approved'
  LIMIT 1
);

-- 10. Check table-level permissions
SELECT 
  'TABLE LEVEL PERMISSIONS' as permission_info,
  table_name,
  privilege_type,
  grantee,
  is_grantable
FROM information_schema.table_privileges 
WHERE table_schema = 'public' 
  AND table_name IN ('products', 'warehouses', 'warehouse_inventory', 'user_profiles')
ORDER BY table_name, grantee, privilege_type;

-- 11. Check function-level permissions
SELECT 
  'FUNCTION LEVEL PERMISSIONS' as permission_info,
  routine_name,
  privilege_type,
  grantee,
  is_grantable
FROM information_schema.routine_privileges 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%search%'
ORDER BY routine_name, grantee;

-- 12. Final diagnosis
SELECT 
  'FINAL DIAGNOSIS' as diagnosis,
  'Check POLICIES BLOCKING ACCOUNTANT section above' as step1,
  'Look for policies that allow admin/owner but exclude accountant' as step2,
  'The solution is to add accountant to those policy conditions' as solution;
