-- 🔍 COMPREHENSIVE WAREHOUSE ACCESS DIAGNOSIS
-- Systematic analysis of RLS policies and user access patterns

-- ==================== STEP 1: VERIFY TABLE STRUCTURE ====================

-- Check user_profiles table structure
SELECT 
  '📋 USER_PROFILES TABLE STRUCTURE' as info,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check warehouse tables structure
SELECT 
  '🏢 WAREHOUSE TABLES STRUCTURE' as info,
  table_name,
  column_name,
  data_type
FROM information_schema.columns 
WHERE table_name IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests', 'warehouse_request_items')
  AND table_schema = 'public'
ORDER BY table_name, ordinal_position;

-- ==================== STEP 2: CHECK RLS STATUS ====================

-- Check RLS status on all warehouse tables
SELECT 
  '🔒 RLS STATUS CHECK' as info,
  schemaname,
  tablename,
  rowsecurity as rls_enabled,
  CASE 
    WHEN rowsecurity THEN '✅ RLS ENABLED'
    ELSE '❌ RLS DISABLED'
  END as status
FROM pg_tables 
WHERE tablename IN ('user_profiles', 'warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests', 'warehouse_request_items')
  AND schemaname = 'public';

-- ==================== STEP 3: ANALYZE CURRENT RLS POLICIES ====================

-- Show all current RLS policies on warehouse tables
SELECT 
  '📜 CURRENT RLS POLICIES' as info,
  schemaname,
  tablename,
  policyname,
  cmd as operation,
  roles,
  CASE 
    WHEN roles = '{public}' THEN '🚨 PUBLIC ACCESS'
    ELSE '🔒 RESTRICTED'
  END as access_level
FROM pg_policies 
WHERE tablename IN ('user_profiles', 'warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests', 'warehouse_request_items')
ORDER BY tablename, cmd;

-- ==================== STEP 4: CHECK USER PROFILES DATA ====================

-- Show all user profiles with roles and status
SELECT 
  '👥 USER PROFILES ANALYSIS' as info,
  id,
  email,
  name,
  role,
  status,
  CASE 
    WHEN role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND status = 'approved' 
    THEN '✅ SHOULD HAVE ACCESS'
    ELSE '❌ NO ACCESS EXPECTED'
  END as expected_access,
  created_at
FROM user_profiles 
ORDER BY role, created_at;

-- ==================== STEP 5: CHECK WAREHOUSE DATA ====================

-- Show warehouse data availability
SELECT 
  '🏢 WAREHOUSE DATA AVAILABILITY' as info,
  COUNT(*) as total_warehouses,
  COUNT(CASE WHEN is_active = true THEN 1 END) as active_warehouses,
  COUNT(CASE WHEN is_active = false THEN 1 END) as inactive_warehouses
FROM warehouses;

-- Show sample warehouse records
SELECT 
  '📦 SAMPLE WAREHOUSE RECORDS' as info,
  id,
  name,
  address,
  is_active,
  created_by,
  created_at
FROM warehouses 
ORDER BY created_at DESC 
LIMIT 5;

-- ==================== STEP 6: CHECK WAREHOUSE INVENTORY ====================

-- Show warehouse inventory availability
SELECT 
  '📊 WAREHOUSE INVENTORY AVAILABILITY' as info,
  COUNT(*) as total_inventory_items,
  COUNT(DISTINCT warehouse_id) as warehouses_with_inventory,
  COUNT(DISTINCT product_id) as unique_products
FROM warehouse_inventory;

-- ==================== STEP 7: SECURITY DEFINER FUNCTIONS ====================

-- Check for existing SECURITY DEFINER functions
SELECT 
  '🔧 SECURITY DEFINER FUNCTIONS' as info,
  routine_name,
  routine_type,
  security_type,
  definer_rights
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND security_type = 'DEFINER'
  AND routine_name LIKE '%user%' OR routine_name LIKE '%warehouse%'
ORDER BY routine_name;

-- ==================== STEP 8: TEST QUERIES FOR DIFFERENT ROLES ====================

-- This section will be used to test access for specific users
-- Replace the UUID with actual user IDs for testing

-- Test query template for admin role
SELECT 
  '🧪 TEST QUERY TEMPLATE' as info,
  'Replace USER_ID_HERE with actual user ID to test access' as instruction;

-- Example test for warehouses access
-- SELECT * FROM warehouses WHERE auth.uid() = 'USER_ID_HERE';

-- ==================== STEP 9: FOREIGN KEY RELATIONSHIPS ====================

-- Check foreign key relationships
SELECT 
  '🔗 FOREIGN KEY RELATIONSHIPS' as info,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests', 'warehouse_request_items')
ORDER BY tc.table_name;
