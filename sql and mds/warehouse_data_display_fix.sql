-- 🔧 COMPREHENSIVE WAREHOUSE DATA DISPLAY FIX
-- Fix warehouse data visibility for admin, owner, accountant, and warehouseManager roles
-- This script addresses RLS policy conflicts and ensures consistent data access

-- =====================================================
-- STEP 1: DIAGNOSTIC - CHECK CURRENT STATE
-- =====================================================

SELECT '🔍 === WAREHOUSE DATA DISPLAY DIAGNOSTIC ===' as diagnostic_step;

-- Check current warehouse RLS policies
SELECT 
  '📋 CURRENT WAREHOUSE POLICIES' as check_type,
  policyname,
  cmd,
  qual as using_condition,
  with_check as with_check_condition
FROM pg_policies 
WHERE tablename = 'warehouses'
ORDER BY cmd, policyname;

-- Check current warehouse_inventory RLS policies
SELECT 
  '📦 CURRENT WAREHOUSE_INVENTORY POLICIES' as check_type,
  policyname,
  cmd,
  qual as using_condition,
  with_check as with_check_condition
FROM pg_policies 
WHERE tablename = 'warehouse_inventory'
ORDER BY cmd, policyname;

-- Check user profiles and their roles/status
SELECT 
  '👥 USER ROLES AND STATUS' as check_type,
  role,
  status,
  COUNT(*) as user_count,
  STRING_AGG(email, ', ') as sample_emails
FROM user_profiles 
WHERE role IN ('admin', 'owner', 'accountant', 'warehouseManager')
GROUP BY role, status
ORDER BY role, status;

-- Check current authenticated user
SELECT 
  '🔐 CURRENT AUTH USER' as check_type,
  auth.uid() as user_id,
  CASE 
    WHEN auth.uid() IS NULL THEN '❌ NOT AUTHENTICATED'
    ELSE '✅ AUTHENTICATED'
  END as auth_status;

-- Check current user profile
SELECT 
  '👤 CURRENT USER PROFILE' as check_type,
  up.id,
  up.email,
  up.name,
  up.role,
  up.status,
  CASE 
    WHEN up.role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND up.status = 'approved' 
    THEN '✅ SHOULD HAVE WAREHOUSE ACCESS'
    ELSE '❌ INSUFFICIENT PERMISSIONS'
  END as expected_access
FROM user_profiles up
WHERE up.id = auth.uid();

-- Check warehouse data availability
SELECT 
  '🏢 WAREHOUSE DATA CHECK' as check_type,
  COUNT(*) as total_warehouses,
  COUNT(*) FILTER (WHERE is_active = true) as active_warehouses,
  STRING_AGG(name, ', ') as warehouse_names
FROM warehouses;

-- Check warehouse inventory data
SELECT 
  '📦 WAREHOUSE INVENTORY CHECK' as check_type,
  COUNT(*) as total_inventory_items,
  COUNT(DISTINCT warehouse_id) as warehouses_with_inventory,
  SUM(quantity) as total_quantity
FROM warehouse_inventory;

-- =====================================================
-- STEP 2: COMPREHENSIVE POLICY CLEANUP
-- =====================================================

SELECT '🧹 === COMPREHENSIVE POLICY CLEANUP ===' as cleanup_step;

-- Drop ALL existing warehouse policies to avoid conflicts
DROP POLICY IF EXISTS "المخازن قابلة للقراءة من قبل المستخدمين المصرح لهم" ON warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للإنشاء من قبل المديرين ومديري المخازن" ON warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للإنشاء من قبل المديرين" ON warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للتحديث من قبل المديرين ومديري المخازن" ON warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للتحديث من قبل المديرين" ON warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للحذف من قبل المديرين فقط" ON warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للحذف من قبل المديرين" ON warehouses;
DROP POLICY IF EXISTS "warehouse_managers_can_read_warehouses" ON warehouses;
DROP POLICY IF EXISTS "warehouse_managers_can_manage_assigned_warehouses" ON warehouses;
DROP POLICY IF EXISTS "secure_warehouses_select" ON warehouses;
DROP POLICY IF EXISTS "warehouse_select_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouse_insert_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouse_update_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouse_delete_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouses_select_admin_accountant" ON warehouses;
DROP POLICY IF EXISTS "warehouses_insert_admin_accountant" ON warehouses;
DROP POLICY IF EXISTS "warehouses_update_admin_accountant" ON warehouses;
DROP POLICY IF EXISTS "warehouses_delete_admin_accountant" ON warehouses;

-- Drop ALL existing warehouse_inventory policies
DROP POLICY IF EXISTS "مخزون المخازن قابل للقراءة من قبل المستخدمين المصرح لهم" ON warehouse_inventory;
DROP POLICY IF EXISTS "مخزون المخازن قابل للتحديث من قبل مديري المخازن" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_select_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_insert_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_update_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_delete_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_select_admin_accountant" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_insert_admin_accountant" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_update_admin_accountant" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_delete_admin_accountant" ON warehouse_inventory;

SELECT '✅ All conflicting policies dropped successfully' as cleanup_result;

-- =====================================================
-- STEP 3: ENSURE USER STATUS IS CORRECT
-- =====================================================

SELECT '👥 === USER STATUS CORRECTION ===' as user_fix_step;

-- Update all admin, owner, accountant, warehouseManager users to have 'approved' status
UPDATE user_profiles
SET
  status = 'approved',
  updated_at = NOW()
WHERE
  role IN ('admin', 'owner', 'accountant', 'warehouseManager')
  AND status != 'approved';

-- Show updated user status
SELECT
  '✅ UPDATED USER STATUS' as result_type,
  role,
  status,
  COUNT(*) as user_count,
  STRING_AGG(email, ', ') as emails
FROM user_profiles
WHERE role IN ('admin', 'owner', 'accountant', 'warehouseManager')
GROUP BY role, status
ORDER BY role, status;

-- =====================================================
-- STEP 4: CREATE UNIFIED WAREHOUSE RLS POLICIES
-- =====================================================

SELECT '🔐 === CREATING UNIFIED WAREHOUSE POLICIES ===' as policy_creation_step;

-- Ensure RLS is enabled
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;

-- WAREHOUSES TABLE POLICIES
-- SELECT: Allow all authorized roles to view warehouses
CREATE POLICY "unified_warehouses_select_2025" ON warehouses
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Allow admin, owner, accountant to create warehouses
CREATE POLICY "unified_warehouses_insert_2025" ON warehouses
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Allow admin, owner, accountant to update warehouses
CREATE POLICY "unified_warehouses_update_2025" ON warehouses
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Allow only admin and owner to delete warehouses
CREATE POLICY "unified_warehouses_delete_2025" ON warehouses
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- WAREHOUSE_INVENTORY TABLE POLICIES
-- SELECT: Allow all authorized roles to view inventory
CREATE POLICY "unified_warehouse_inventory_select_2025" ON warehouse_inventory
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Allow all authorized roles to add inventory
CREATE POLICY "unified_warehouse_inventory_insert_2025" ON warehouse_inventory
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Allow all authorized roles to update inventory
CREATE POLICY "unified_warehouse_inventory_update_2025" ON warehouse_inventory
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Allow admin, owner, accountant to delete inventory (warehouseManager excluded for audit)
CREATE POLICY "unified_warehouse_inventory_delete_2025" ON warehouse_inventory
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

SELECT '✅ Unified warehouse policies created successfully' as policy_result;

-- =====================================================
-- STEP 5: VERIFICATION AND TESTING
-- =====================================================

SELECT '🧪 === VERIFICATION AND TESTING ===' as verification_step;

-- Test warehouse access for current user
SELECT
  '🏢 WAREHOUSE ACCESS TEST' as test_type,
  COUNT(*) as accessible_warehouses,
  STRING_AGG(name, ', ') as warehouse_names
FROM warehouses;

-- Test warehouse inventory access for current user
SELECT
  '📦 INVENTORY ACCESS TEST' as test_type,
  COUNT(*) as accessible_inventory_items,
  COUNT(DISTINCT warehouse_id) as warehouses_with_inventory
FROM warehouse_inventory;

-- Show final policy status
SELECT
  '📋 FINAL WAREHOUSE POLICIES' as check_type,
  policyname,
  cmd,
  CASE
    WHEN policyname LIKE '%unified%2025%' THEN '✅ NEW UNIFIED POLICY'
    ELSE '⚠️ OLD POLICY (SHOULD BE CLEANED)'
  END as policy_status
FROM pg_policies
WHERE tablename = 'warehouses'
ORDER BY cmd, policyname;

-- Show final inventory policy status
SELECT
  '📦 FINAL INVENTORY POLICIES' as check_type,
  policyname,
  cmd,
  CASE
    WHEN policyname LIKE '%unified%2025%' THEN '✅ NEW UNIFIED POLICY'
    ELSE '⚠️ OLD POLICY (SHOULD BE CLEANED)'
  END as policy_status
FROM pg_policies
WHERE tablename = 'warehouse_inventory'
ORDER BY cmd, policyname;

-- Final user status check
SELECT
  '👥 FINAL USER STATUS' as check_type,
  role,
  status,
  COUNT(*) as user_count,
  CASE
    WHEN status = 'approved' THEN '✅ READY FOR WAREHOUSE ACCESS'
    ELSE '❌ NEEDS STATUS UPDATE'
  END as access_status
FROM user_profiles
WHERE role IN ('admin', 'owner', 'accountant', 'warehouseManager')
GROUP BY role, status
ORDER BY role, status;

-- =====================================================
-- STEP 6: TROUBLESHOOTING GUIDE
-- =====================================================

SELECT '🔧 === TROUBLESHOOTING GUIDE ===' as troubleshooting_step;

SELECT
  '📝 TROUBLESHOOTING CHECKLIST' as guide_type,
  '1. Verify user has role: admin, owner, accountant, or warehouseManager' as step_1,
  '2. Verify user status = approved' as step_2,
  '3. Verify user is authenticated (auth.uid() not null)' as step_3,
  '4. Check Flutter app uses correct Supabase client configuration' as step_4,
  '5. Ensure warehouse service calls use proper error handling' as step_5;

-- Create diagnostic function for future use
CREATE OR REPLACE FUNCTION diagnose_warehouse_access(user_email TEXT DEFAULT NULL)
RETURNS TABLE (
  check_type TEXT,
  status TEXT,
  details TEXT
) AS $$
DECLARE
  target_user_id UUID;
  user_role TEXT;
  user_status TEXT;
  warehouse_count INTEGER;
  inventory_count INTEGER;
BEGIN
  -- Get user ID
  IF user_email IS NOT NULL THEN
    SELECT id, role, status INTO target_user_id, user_role, user_status
    FROM user_profiles
    WHERE email = user_email;
  ELSE
    SELECT auth.uid(), up.role, up.status INTO target_user_id, user_role, user_status
    FROM user_profiles up
    WHERE up.id = auth.uid();
  END IF;

  -- Check authentication
  IF target_user_id IS NULL THEN
    RETURN QUERY SELECT 'Authentication'::TEXT, 'FAILED'::TEXT, 'User not found or not authenticated'::TEXT;
    RETURN;
  END IF;

  RETURN QUERY SELECT 'Authentication'::TEXT, 'SUCCESS'::TEXT, format('User ID: %s', target_user_id)::TEXT;

  -- Check role
  IF user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') THEN
    RETURN QUERY SELECT 'Role Check'::TEXT, 'SUCCESS'::TEXT, format('Role: %s (authorized)', user_role)::TEXT;
  ELSE
    RETURN QUERY SELECT 'Role Check'::TEXT, 'FAILED'::TEXT, format('Role: %s (not authorized)', COALESCE(user_role, 'NULL'))::TEXT;
  END IF;

  -- Check status
  IF user_status = 'approved' THEN
    RETURN QUERY SELECT 'Status Check'::TEXT, 'SUCCESS'::TEXT, format('Status: %s', user_status)::TEXT;
  ELSE
    RETURN QUERY SELECT 'Status Check'::TEXT, 'FAILED'::TEXT, format('Status: %s (should be approved)', COALESCE(user_status, 'NULL'))::TEXT;
  END IF;

  -- Test warehouse access
  BEGIN
    SELECT COUNT(*) INTO warehouse_count FROM warehouses;
    RETURN QUERY SELECT 'Warehouse Access'::TEXT, 'SUCCESS'::TEXT, format('Can access %s warehouses', warehouse_count)::TEXT;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 'Warehouse Access'::TEXT, 'FAILED'::TEXT, format('Error: %s', SQLERRM)::TEXT;
  END;

  -- Test inventory access
  BEGIN
    SELECT COUNT(*) INTO inventory_count FROM warehouse_inventory;
    RETURN QUERY SELECT 'Inventory Access'::TEXT, 'SUCCESS'::TEXT, format('Can access %s inventory items', inventory_count)::TEXT;
  EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 'Inventory Access'::TEXT, 'FAILED'::TEXT, format('Error: %s', SQLERRM)::TEXT;
  END;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant access to the diagnostic function
GRANT EXECUTE ON FUNCTION diagnose_warehouse_access(TEXT) TO authenticated;

SELECT '✅ === WAREHOUSE DATA DISPLAY FIX COMPLETED ===' as completion_message;
SELECT 'Run this script in Supabase SQL Editor to fix warehouse data visibility issues' as instructions;
SELECT 'After running, test warehouse access in Flutter app for all user roles' as next_steps;
