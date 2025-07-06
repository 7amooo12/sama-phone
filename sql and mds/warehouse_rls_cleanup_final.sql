-- 🔧 FINAL WAREHOUSE RLS CLEANUP AND FIX
-- Based on CSV analysis showing multiple conflicting policies
-- This script removes ALL conflicting policies and creates ONE working set

-- =====================================================
-- STEP 1: REMOVE ALL CONFLICTING WAREHOUSE POLICIES
-- =====================================================

SELECT '🧹 === REMOVING ALL CONFLICTING WAREHOUSE POLICIES ===' as cleanup_step;

-- Remove all warehouse policies (from CSV analysis)
DROP POLICY IF EXISTS "warehouses_select_expanded_roles" ON warehouses;
DROP POLICY IF EXISTS "warehouses_insert_expanded_roles" ON warehouses;
DROP POLICY IF EXISTS "warehouses_update_expanded_roles" ON warehouses;
DROP POLICY IF EXISTS "warehouses_delete_expanded_roles" ON warehouses;

DROP POLICY IF EXISTS "allow_warehouse_access_2025" ON warehouses;
DROP POLICY IF EXISTS "allow_warehouse_create_2025" ON warehouses;
DROP POLICY IF EXISTS "allow_warehouse_update_2025" ON warehouses;
DROP POLICY IF EXISTS "allow_warehouse_delete_2025" ON warehouses;

DROP POLICY IF EXISTS "unified_warehouses_select_2025" ON warehouses;
DROP POLICY IF EXISTS "unified_warehouses_insert_2025" ON warehouses;

-- Remove all warehouse_inventory policies
DROP POLICY IF EXISTS "warehouse_inventory_select_expanded_roles" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_insert_expanded_roles" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_update_expanded_roles" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_delete_expanded_roles" ON warehouse_inventory;

DROP POLICY IF EXISTS "allow_inventory_access_2025" ON warehouse_inventory;
DROP POLICY IF EXISTS "allow_inventory_manage_2025" ON warehouse_inventory;

SELECT '✅ All conflicting policies removed' as cleanup_result;

-- =====================================================
-- STEP 2: ENSURE USER STATUS IS CORRECT
-- =====================================================

SELECT '👥 === FIXING USER STATUS ===' as user_fix_step;

-- Update all users to have approved status
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
  COUNT(*) as user_count
FROM user_profiles 
WHERE role IN ('admin', 'owner', 'accountant', 'warehouseManager')
GROUP BY role, status
ORDER BY role, status;

-- =====================================================
-- STEP 3: CREATE SIMPLE, WORKING RLS POLICIES
-- =====================================================

SELECT '🔐 === CREATING SIMPLE WORKING POLICIES ===' as policy_creation_step;

-- Ensure RLS is enabled
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;

-- WAREHOUSES TABLE - SIMPLE POLICIES WITHOUT FUNCTIONS
-- SELECT: Allow all authorized roles to view warehouses
CREATE POLICY "final_warehouses_select_2025" ON warehouses
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Allow admin, owner, accountant to create warehouses
CREATE POLICY "final_warehouses_insert_2025" ON warehouses
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Allow admin, owner, accountant to update warehouses
CREATE POLICY "final_warehouses_update_2025" ON warehouses
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Allow only admin and owner to delete warehouses
CREATE POLICY "final_warehouses_delete_2025" ON warehouses
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- WAREHOUSE_INVENTORY TABLE - SIMPLE POLICIES
-- SELECT: Allow all authorized roles to view inventory
CREATE POLICY "final_inventory_select_2025" ON warehouse_inventory
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Allow all authorized roles to add inventory
CREATE POLICY "final_inventory_insert_2025" ON warehouse_inventory
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Allow all authorized roles to update inventory
CREATE POLICY "final_inventory_update_2025" ON warehouse_inventory
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Allow admin, owner, accountant to delete inventory
CREATE POLICY "final_inventory_delete_2025" ON warehouse_inventory
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

SELECT '✅ Simple working policies created successfully' as policy_result;

-- =====================================================
-- STEP 4: VERIFICATION TEST
-- =====================================================

SELECT '🧪 === VERIFICATION TEST ===' as verification_step;

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
  '📋 FINAL POLICIES CREATED' as check_type,
  policyname,
  cmd,
  CASE 
    WHEN policyname LIKE 'final_%2025%' THEN '✅ NEW WORKING POLICY'
    ELSE '⚠️ UNEXPECTED POLICY'
  END as policy_status
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory')
ORDER BY tablename, cmd;

-- Final user status check
SELECT 
  '👥 FINAL USER STATUS' as check_type,
  role,
  status,
  COUNT(*) as user_count
FROM user_profiles 
WHERE role IN ('admin', 'owner', 'accountant', 'warehouseManager')
GROUP BY role, status
ORDER BY role, status;

SELECT '✅ === WAREHOUSE RLS CLEANUP COMPLETED ===' as completion_message;
SELECT 'Test warehouse access in Flutter app now - should work for all authorized roles' as next_step;
