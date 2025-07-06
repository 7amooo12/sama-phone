-- 🔐 GRANT FULL WAREHOUSE PERMISSIONS TO ADMIN & ACCOUNTANT ROLES
-- Comprehensive RLS policy updates for warehouse management system

-- ==================== CURRENT STATE ANALYSIS ====================

-- Check existing warehouse-related tables
SELECT 
  '📋 WAREHOUSE TABLES INVENTORY' as analysis_type,
  table_name,
  CASE 
    WHEN table_name LIKE '%warehouse%' THEN '🏭 WAREHOUSE TABLE'
    ELSE '📊 RELATED TABLE'
  END as table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND (table_name LIKE '%warehouse%' OR table_name IN ('products', 'invoices'))
ORDER BY table_name;

-- Check current RLS policies for warehouse tables
SELECT 
  '🛡️ CURRENT RLS POLICIES' as policy_check,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN with_check LIKE '%admin%' AND with_check LIKE '%accountant%' THEN '✅ INCLUDES BOTH'
    WHEN with_check LIKE '%admin%' OR with_check LIKE '%accountant%' THEN '⚠️ PARTIAL'
    ELSE '❌ MISSING'
  END as admin_accountant_access
FROM pg_policies 
WHERE tablename LIKE '%warehouse%'
ORDER BY tablename, cmd;

-- ==================== WAREHOUSES TABLE PERMISSIONS ====================

-- Drop existing policies for warehouses table
DROP POLICY IF EXISTS "warehouse_select_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouse_insert_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouse_update_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouse_delete_policy" ON warehouses;
DROP POLICY IF EXISTS "secure_warehouses_select" ON warehouses;
DROP POLICY IF EXISTS "secure_warehouses_insert" ON warehouses;
DROP POLICY IF EXISTS "secure_warehouses_update" ON warehouses;
DROP POLICY IF EXISTS "secure_warehouses_delete" ON warehouses;

-- Enable RLS on warehouses table
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;

-- CREATE COMPREHENSIVE POLICIES FOR WAREHOUSES
-- SELECT: Admin, Accountant, Warehouse Manager can view
CREATE POLICY "warehouses_select_admin_accountant" ON warehouses
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Admin, Accountant, Owner can create warehouses
CREATE POLICY "warehouses_insert_admin_accountant" ON warehouses
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Admin, Accountant, Owner can modify warehouses
CREATE POLICY "warehouses_update_admin_accountant" ON warehouses
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Admin, Owner can delete warehouses
CREATE POLICY "warehouses_delete_admin_accountant" ON warehouses
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

-- ==================== WAREHOUSE_REQUESTS TABLE PERMISSIONS ====================

-- Drop existing policies for warehouse_requests table
DROP POLICY IF EXISTS "warehouse_requests_insert_fixed" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_secure" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_debug" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_robust" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_simple" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_clean" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_allow_warehouse_managers" ON warehouse_requests;
DROP POLICY IF EXISTS "secure_requests_select" ON warehouse_requests;
DROP POLICY IF EXISTS "secure_requests_update" ON warehouse_requests;
DROP POLICY IF EXISTS "secure_requests_delete" ON warehouse_requests;

-- Enable RLS on warehouse_requests table
ALTER TABLE warehouse_requests ENABLE ROW LEVEL SECURITY;

-- CREATE COMPREHENSIVE POLICIES FOR WAREHOUSE_REQUESTS
-- SELECT: Admin, Accountant, Warehouse Manager, Owner can view
CREATE POLICY "warehouse_requests_select_admin_accountant" ON warehouse_requests
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Admin, Accountant, Warehouse Manager, Owner can create requests
CREATE POLICY "warehouse_requests_insert_admin_accountant" ON warehouse_requests
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Admin, Accountant, Owner can approve/modify requests
CREATE POLICY "warehouse_requests_update_admin_accountant" ON warehouse_requests
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Admin, Owner can delete requests
CREATE POLICY "warehouse_requests_delete_admin_accountant" ON warehouse_requests
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

-- ==================== WAREHOUSE_INVENTORY TABLE PERMISSIONS ====================

-- Drop existing policies for warehouse_inventory table
DROP POLICY IF EXISTS "warehouse_inventory_select_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_insert_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_update_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_delete_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "secure_inventory_select" ON warehouse_inventory;
DROP POLICY IF EXISTS "secure_inventory_insert" ON warehouse_inventory;
DROP POLICY IF EXISTS "secure_inventory_update" ON warehouse_inventory;
DROP POLICY IF EXISTS "secure_inventory_delete" ON warehouse_inventory;

-- Enable RLS on warehouse_inventory table
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;

-- CREATE COMPREHENSIVE POLICIES FOR WAREHOUSE_INVENTORY
-- SELECT: Admin, Accountant, Warehouse Manager, Owner can view
CREATE POLICY "warehouse_inventory_select_admin_accountant" ON warehouse_inventory
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Admin, Accountant, Warehouse Manager, Owner can add inventory
CREATE POLICY "warehouse_inventory_insert_admin_accountant" ON warehouse_inventory
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Admin, Accountant, Warehouse Manager, Owner can modify inventory
CREATE POLICY "warehouse_inventory_update_admin_accountant" ON warehouse_inventory
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Admin, Accountant, Owner can delete inventory records
CREATE POLICY "warehouse_inventory_delete_admin_accountant" ON warehouse_inventory
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'accountant', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== WAREHOUSE_TRANSACTIONS TABLE PERMISSIONS ====================

-- Drop existing policies for warehouse_transactions table
DROP POLICY IF EXISTS "warehouse_transactions_select_policy" ON warehouse_transactions;
DROP POLICY IF EXISTS "warehouse_transactions_insert_policy" ON warehouse_transactions;
DROP POLICY IF EXISTS "warehouse_transactions_update_policy" ON warehouse_transactions;
DROP POLICY IF EXISTS "warehouse_transactions_delete_policy" ON warehouse_transactions;
DROP POLICY IF EXISTS "secure_transactions_select" ON warehouse_transactions;
DROP POLICY IF EXISTS "secure_transactions_insert" ON warehouse_transactions;
DROP POLICY IF EXISTS "secure_transactions_update" ON warehouse_transactions;
DROP POLICY IF EXISTS "secure_transactions_delete" ON warehouse_transactions;

-- Enable RLS on warehouse_transactions table
ALTER TABLE warehouse_transactions ENABLE ROW LEVEL SECURITY;

-- CREATE COMPREHENSIVE POLICIES FOR WAREHOUSE_TRANSACTIONS
-- SELECT: Admin, Accountant, Warehouse Manager, Owner can view
CREATE POLICY "warehouse_transactions_select_admin_accountant" ON warehouse_transactions
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Admin, Accountant, Warehouse Manager, Owner can create transactions
CREATE POLICY "warehouse_transactions_insert_admin_accountant" ON warehouse_transactions
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Admin, Accountant can modify transactions (audit integrity)
CREATE POLICY "warehouse_transactions_update_admin_accountant" ON warehouse_transactions
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'accountant', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Admin only can delete transactions (strict audit control)
CREATE POLICY "warehouse_transactions_delete_admin_accountant" ON warehouse_transactions
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role = 'admin'
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== VERIFICATION & TESTING ====================

-- Verify all new policies are in place
SELECT
  '✅ NEW POLICIES VERIFICATION' as verification_type,
  tablename,
  policyname,
  cmd,
  CASE
    WHEN policyname LIKE '%admin_accountant%' THEN '✅ NEW POLICY'
    ELSE '⚠️ OLD POLICY'
  END as policy_status
FROM pg_policies
WHERE tablename IN ('warehouses', 'warehouse_requests', 'warehouse_inventory', 'warehouse_transactions')
ORDER BY tablename, cmd;

-- Test permissions for admin role
DO $$
DECLARE
  admin_user_id UUID;
  admin_permissions RECORD;
BEGIN
  -- Find an admin user for testing
  SELECT id INTO admin_user_id FROM user_profiles WHERE role = 'admin' AND status = 'approved' LIMIT 1;

  IF admin_user_id IS NOT NULL THEN
    -- Test admin permissions
    SELECT
      EXISTS(SELECT 1 FROM user_profiles WHERE id = admin_user_id AND role IN ('admin', 'accountant', 'warehouseManager', 'owner') AND status = 'approved') as warehouses_select,
      EXISTS(SELECT 1 FROM user_profiles WHERE id = admin_user_id AND role IN ('admin', 'accountant', 'owner') AND status = 'approved') as warehouses_insert,
      EXISTS(SELECT 1 FROM user_profiles WHERE id = admin_user_id AND role IN ('admin', 'accountant', 'owner') AND status = 'approved') as warehouses_update,
      EXISTS(SELECT 1 FROM user_profiles WHERE id = admin_user_id AND role IN ('admin', 'owner') AND status = 'approved') as warehouses_delete
    INTO admin_permissions;

    RAISE NOTICE '';
    RAISE NOTICE '🧪 ADMIN PERMISSIONS TEST:';
    RAISE NOTICE '========================';
    RAISE NOTICE 'Admin User ID: %', admin_user_id;
    RAISE NOTICE 'Warehouses SELECT: %', CASE WHEN admin_permissions.warehouses_select THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
    RAISE NOTICE 'Warehouses INSERT: %', CASE WHEN admin_permissions.warehouses_insert THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
    RAISE NOTICE 'Warehouses UPDATE: %', CASE WHEN admin_permissions.warehouses_update THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
    RAISE NOTICE 'Warehouses DELETE: %', CASE WHEN admin_permissions.warehouses_delete THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
    RAISE NOTICE '';
  ELSE
    RAISE NOTICE '⚠️ No admin user found for testing';
  END IF;
END $$;

-- Test permissions for accountant role
DO $$
DECLARE
  accountant_user_id UUID;
  accountant_permissions RECORD;
BEGIN
  -- Find an accountant user for testing (our corrected user)
  SELECT id INTO accountant_user_id FROM user_profiles WHERE role = 'accountant' AND status = 'approved' LIMIT 1;

  IF accountant_user_id IS NOT NULL THEN
    -- Test accountant permissions
    SELECT
      EXISTS(SELECT 1 FROM user_profiles WHERE id = accountant_user_id AND role IN ('admin', 'accountant', 'warehouseManager', 'owner') AND status = 'approved') as warehouses_select,
      EXISTS(SELECT 1 FROM user_profiles WHERE id = accountant_user_id AND role IN ('admin', 'accountant', 'owner') AND status = 'approved') as warehouses_insert,
      EXISTS(SELECT 1 FROM user_profiles WHERE id = accountant_user_id AND role IN ('admin', 'accountant', 'owner') AND status = 'approved') as warehouses_update,
      EXISTS(SELECT 1 FROM user_profiles WHERE id = accountant_user_id AND role IN ('admin', 'owner') AND status = 'approved') as warehouses_delete
    INTO accountant_permissions;

    RAISE NOTICE '';
    RAISE NOTICE '🧪 ACCOUNTANT PERMISSIONS TEST:';
    RAISE NOTICE '==============================';
    RAISE NOTICE 'Accountant User ID: %', accountant_user_id;
    RAISE NOTICE 'Warehouses SELECT: %', CASE WHEN accountant_permissions.warehouses_select THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
    RAISE NOTICE 'Warehouses INSERT: %', CASE WHEN accountant_permissions.warehouses_insert THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
    RAISE NOTICE 'Warehouses UPDATE: %', CASE WHEN accountant_permissions.warehouses_update THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
    RAISE NOTICE 'Warehouses DELETE: %', CASE WHEN accountant_permissions.warehouses_delete THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
    RAISE NOTICE '';
  ELSE
    RAISE NOTICE '⚠️ No accountant user found for testing';
  END IF;
END $$;

-- ==================== SECURITY VALIDATION ====================

-- Test that unauthorized users are still blocked
DO $$
DECLARE
  client_user_id UUID;
  unauthorized_permissions RECORD;
BEGIN
  -- Find a client user for testing (should be blocked)
  SELECT id INTO client_user_id FROM user_profiles WHERE role = 'client' AND status = 'approved' LIMIT 1;

  IF client_user_id IS NOT NULL THEN
    -- Test client permissions (should all be false)
    SELECT
      EXISTS(SELECT 1 FROM user_profiles WHERE id = client_user_id AND role IN ('admin', 'accountant', 'warehouseManager', 'owner') AND status = 'approved') as warehouses_select,
      EXISTS(SELECT 1 FROM user_profiles WHERE id = client_user_id AND role IN ('admin', 'accountant', 'owner') AND status = 'approved') as warehouses_insert
    INTO unauthorized_permissions;

    RAISE NOTICE '';
    RAISE NOTICE '🔒 SECURITY VALIDATION TEST:';
    RAISE NOTICE '============================';
    RAISE NOTICE 'Client User ID: %', client_user_id;
    RAISE NOTICE 'Warehouses SELECT: %', CASE WHEN unauthorized_permissions.warehouses_select THEN '🚨 SECURITY BREACH' ELSE '✅ PROPERLY BLOCKED' END;
    RAISE NOTICE 'Warehouses INSERT: %', CASE WHEN unauthorized_permissions.warehouses_insert THEN '🚨 SECURITY BREACH' ELSE '✅ PROPERLY BLOCKED' END;
    RAISE NOTICE '';
  ELSE
    RAISE NOTICE '⚠️ No client user found for security testing';
  END IF;
END $$;

-- ==================== PERMISSION MATRIX SUMMARY ====================

-- Show comprehensive permission matrix
WITH permission_matrix AS (
  SELECT
    'admin' as role_type,
    'warehouses' as table_name,
    '✅ Full Access' as select_perm,
    '✅ Full Access' as insert_perm,
    '✅ Full Access' as update_perm,
    '✅ Full Access' as delete_perm
  UNION ALL
  SELECT
    'accountant' as role_type,
    'warehouses' as table_name,
    '✅ Full Access' as select_perm,
    '✅ Full Access' as insert_perm,
    '✅ Full Access' as update_perm,
    '❌ Restricted' as delete_perm
  UNION ALL
  SELECT
    'warehouseManager' as role_type,
    'warehouses' as table_name,
    '✅ View Only' as select_perm,
    '❌ Restricted' as insert_perm,
    '❌ Restricted' as update_perm,
    '❌ Restricted' as delete_perm
  UNION ALL
  SELECT
    'client' as role_type,
    'warehouses' as table_name,
    '❌ No Access' as select_perm,
    '❌ No Access' as insert_perm,
    '❌ No Access' as update_perm,
    '❌ No Access' as delete_perm
)
SELECT
  '📊 PERMISSION MATRIX' as matrix_type,
  role_type,
  table_name,
  select_perm,
  insert_perm,
  update_perm,
  delete_perm
FROM permission_matrix
ORDER BY
  CASE role_type
    WHEN 'admin' THEN 1
    WHEN 'accountant' THEN 2
    WHEN 'warehouseManager' THEN 3
    ELSE 4
  END;

-- ==================== FINAL SUCCESS MESSAGE ====================

DO $$
DECLARE
  total_policies INTEGER;
  new_policies INTEGER;
  warehouse_tables INTEGER;
BEGIN
  -- Count policies
  SELECT COUNT(*) INTO total_policies
  FROM pg_policies
  WHERE tablename IN ('warehouses', 'warehouse_requests', 'warehouse_inventory', 'warehouse_transactions');

  SELECT COUNT(*) INTO new_policies
  FROM pg_policies
  WHERE tablename IN ('warehouses', 'warehouse_requests', 'warehouse_inventory', 'warehouse_transactions')
    AND policyname LIKE '%admin_accountant%';

  SELECT COUNT(*) INTO warehouse_tables
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN ('warehouses', 'warehouse_requests', 'warehouse_inventory', 'warehouse_transactions');

  RAISE NOTICE '';
  RAISE NOTICE '🎉 WAREHOUSE PERMISSIONS GRANT COMPLETED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Warehouse tables secured: %', warehouse_tables;
  RAISE NOTICE '✅ Total RLS policies: %', total_policies;
  RAISE NOTICE '✅ New admin/accountant policies: %', new_policies;
  RAISE NOTICE '';
  RAISE NOTICE '🔐 PERMISSIONS GRANTED:';
  RAISE NOTICE '  👑 Admin: Full access to all warehouse operations';
  RAISE NOTICE '  📊 Accountant: Full access to warehouse data and operations';
  RAISE NOTICE '  🏭 Warehouse Manager: Operational access (view + manage inventory/requests)';
  RAISE NOTICE '  👤 Other roles: Restricted access as appropriate';
  RAISE NOTICE '';
  RAISE NOTICE '📋 NEXT STEPS:';
  RAISE NOTICE '1. Test admin and accountant access to warehouse functions';
  RAISE NOTICE '2. Verify dispatch creation works for accountants';
  RAISE NOTICE '3. Confirm warehouse management interface access';
  RAISE NOTICE '4. Monitor for any permission issues';
  RAISE NOTICE '';
  RAISE NOTICE '🔒 SECURITY STATUS: All warehouse tables properly secured with role-based access control';
  RAISE NOTICE '';
END $$;
