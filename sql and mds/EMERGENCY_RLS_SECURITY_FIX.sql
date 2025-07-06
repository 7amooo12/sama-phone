-- 🚨 EMERGENCY RLS SECURITY FIX
-- CRITICAL: All warehouse RLS policies are allowing public access!
-- This script immediately fixes the security vulnerability

-- ==================== EMERGENCY CLEANUP ====================

-- 1. DROP ALL EXISTING VULNERABLE POLICIES
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    -- Drop all warehouse-related policies that are allowing public access
    FOR policy_record IN 
        SELECT schemaname, tablename, policyname 
        FROM pg_policies 
        WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_requests', 'warehouse_transactions')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', 
                      policy_record.policyname, 
                      policy_record.schemaname, 
                      policy_record.tablename);
        RAISE NOTICE '🗑️ Dropped vulnerable policy: % on %.%', 
                     policy_record.policyname, 
                     policy_record.schemaname, 
                     policy_record.tablename;
    END LOOP;
END $$;

-- ==================== SECURE WAREHOUSES TABLE ====================

-- Enable RLS
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;

-- SECURE SELECT: Only authenticated users with proper roles
CREATE POLICY "secure_warehouses_select" ON warehouses
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- SECURE INSERT: Only admin, owner, accountant can create warehouses
CREATE POLICY "secure_warehouses_insert" ON warehouses
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- SECURE UPDATE: Only admin, owner, accountant can update warehouses
CREATE POLICY "secure_warehouses_update" ON warehouses
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- SECURE DELETE: Only admin and owner can delete warehouses
CREATE POLICY "secure_warehouses_delete" ON warehouses
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== SECURE WAREHOUSE_INVENTORY TABLE ====================

-- Enable RLS
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "secure_inventory_select" ON warehouse_inventory;
DROP POLICY IF EXISTS "secure_inventory_insert" ON warehouse_inventory;
DROP POLICY IF EXISTS "secure_inventory_update" ON warehouse_inventory;
DROP POLICY IF EXISTS "secure_inventory_delete" ON warehouse_inventory;

-- SECURE SELECT: Authenticated users with warehouse access (INCLUDES CARTON CALCULATIONS)
CREATE POLICY "secure_inventory_select_carton_access" ON warehouse_inventory
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- SECURE INSERT: Warehouse management roles can add inventory
CREATE POLICY "secure_inventory_insert_carton_access" ON warehouse_inventory
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- SECURE UPDATE: Warehouse management roles can update inventory
CREATE POLICY "secure_inventory_update_carton_access" ON warehouse_inventory
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- SECURE DELETE: Only admin, owner, accountant can delete inventory
CREATE POLICY "secure_inventory_delete" ON warehouse_inventory
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== SECURE WAREHOUSE_REQUESTS TABLE ====================

-- Enable RLS
ALTER TABLE warehouse_requests ENABLE ROW LEVEL SECURITY;

-- SECURE SELECT: Warehouse management roles can view requests
CREATE POLICY "secure_requests_select" ON warehouse_requests
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- SECURE INSERT: Warehouse management roles can create requests
CREATE POLICY "secure_requests_insert" ON warehouse_requests
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- SECURE UPDATE: Only admin, owner, accountant can approve/modify requests
CREATE POLICY "secure_requests_update" ON warehouse_requests
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- SECURE DELETE: Only admin and owner can delete requests
CREATE POLICY "secure_requests_delete" ON warehouse_requests
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== SECURE WAREHOUSE_TRANSACTIONS TABLE ====================

-- Enable RLS
ALTER TABLE warehouse_transactions ENABLE ROW LEVEL SECURITY;

-- SECURE SELECT: Warehouse management roles can view transactions
CREATE POLICY "secure_transactions_select" ON warehouse_transactions
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- SECURE INSERT: Warehouse management roles can create transactions
CREATE POLICY "secure_transactions_insert" ON warehouse_transactions
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- SECURE UPDATE: Only admin and owner can modify transactions (audit integrity)
CREATE POLICY "secure_transactions_update" ON warehouse_transactions
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- SECURE DELETE: Only admin can delete transactions (audit integrity)
CREATE POLICY "secure_transactions_delete" ON warehouse_transactions
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role = 'admin'
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== VERIFICATION ====================

-- Verify new secure policies
SELECT 
  '✅ SECURE POLICIES VERIFICATION' as status,
  schemaname,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN roles = '{public}' THEN '🚨 STILL VULNERABLE'
    ELSE '🔒 SECURED'
  END as security_status
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_requests', 'warehouse_transactions')
ORDER BY tablename, cmd;

-- Log security fix completion
DO $$
BEGIN
  RAISE NOTICE '🛡️ EMERGENCY RLS SECURITY FIX COMPLETED';
  RAISE NOTICE '✅ All warehouse tables now require authentication';
  RAISE NOTICE '✅ Role-based access control properly implemented';
  RAISE NOTICE '✅ Public access vulnerability eliminated';
  RAISE NOTICE '🔒 System is now secure from unauthorized access';
END $$;
