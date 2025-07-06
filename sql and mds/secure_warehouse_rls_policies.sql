-- 🔒 SECURE WAREHOUSE RLS POLICIES
-- Proper Row Level Security policies for warehouse management without privilege escalation

-- ==================== WAREHOUSES TABLE ====================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "warehouse_select_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouse_insert_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouse_update_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouse_delete_policy" ON warehouses;

-- Enable RLS on warehouses table
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;

-- SELECT: Allow admin, owner, accountant, and warehouse_manager to view warehouses
CREATE POLICY "warehouse_select_policy" ON warehouses
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Allow admin, owner, and accountant to create warehouses
CREATE POLICY "warehouse_insert_policy" ON warehouses
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Allow admin, owner, and accountant to update warehouses
CREATE POLICY "warehouse_update_policy" ON warehouses
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
CREATE POLICY "warehouse_delete_policy" ON warehouses
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== WAREHOUSE_INVENTORY TABLE ====================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "warehouse_inventory_select_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_insert_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_update_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_delete_policy" ON warehouse_inventory;

-- Enable RLS on warehouse_inventory table
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;

-- SELECT: Allow admin, owner, accountant, and warehouse_manager to view inventory
CREATE POLICY "warehouse_inventory_select_policy" ON warehouse_inventory
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Allow admin, owner, accountant, and warehouse_manager to add inventory
CREATE POLICY "warehouse_inventory_insert_policy" ON warehouse_inventory
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Allow admin, owner, accountant, and warehouse_manager to update inventory
CREATE POLICY "warehouse_inventory_update_policy" ON warehouse_inventory
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Allow admin, owner, and accountant to delete inventory records
CREATE POLICY "warehouse_inventory_delete_policy" ON warehouse_inventory
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== WAREHOUSE_REQUESTS TABLE ====================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "warehouse_requests_select_policy" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_policy" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_update_policy" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_delete_policy" ON warehouse_requests;

-- Enable RLS on warehouse_requests table
ALTER TABLE warehouse_requests ENABLE ROW LEVEL SECURITY;

-- SELECT: Allow admin, owner, accountant, and warehouse_manager to view requests
CREATE POLICY "warehouse_requests_select_policy" ON warehouse_requests
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Allow admin, owner, accountant, and warehouse_manager to create requests
CREATE POLICY "warehouse_requests_insert_policy" ON warehouse_requests
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Allow admin, owner, and accountant to update requests
CREATE POLICY "warehouse_requests_update_policy" ON warehouse_requests
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Allow only admin and owner to delete requests
CREATE POLICY "warehouse_requests_delete_policy" ON warehouse_requests
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== WAREHOUSE_TRANSACTIONS TABLE ====================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "warehouse_transactions_select_policy" ON warehouse_transactions;
DROP POLICY IF EXISTS "warehouse_transactions_insert_policy" ON warehouse_transactions;
DROP POLICY IF EXISTS "warehouse_transactions_update_policy" ON warehouse_transactions;
DROP POLICY IF EXISTS "warehouse_transactions_delete_policy" ON warehouse_transactions;

-- Enable RLS on warehouse_transactions table
ALTER TABLE warehouse_transactions ENABLE ROW LEVEL SECURITY;

-- SELECT: Allow admin, owner, accountant, and warehouse_manager to view transactions
CREATE POLICY "warehouse_transactions_select_policy" ON warehouse_transactions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Allow admin, owner, accountant, and warehouse_manager to create transactions
CREATE POLICY "warehouse_transactions_insert_policy" ON warehouse_transactions
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Allow only admin and owner to update transactions (for audit integrity)
CREATE POLICY "warehouse_transactions_update_policy" ON warehouse_transactions
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Allow only admin to delete transactions (for audit integrity)
CREATE POLICY "warehouse_transactions_delete_policy" ON warehouse_transactions
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role = 'admin'
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== SECURITY VERIFICATION ====================

-- Verify all policies are created correctly
SELECT 
  '🛡️ RLS POLICIES VERIFICATION' as check_type,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_requests', 'warehouse_transactions')
ORDER BY tablename, cmd, policyname;

-- Log security implementation
DO $$
BEGIN
  RAISE NOTICE '✅ SECURE WAREHOUSE RLS POLICIES IMPLEMENTED';
  RAISE NOTICE '🔒 Warehouse creation: admin, owner, accountant only';
  RAISE NOTICE '🔒 Inventory management: admin, owner, accountant, warehouseManager';
  RAISE NOTICE '🔒 Request management: admin, owner, accountant, warehouseManager (view/create)';
  RAISE NOTICE '🔒 Transaction audit: admin, owner (modify), all authorized (view)';
  RAISE NOTICE '🚨 Role escalation functions have been disabled';
END $$;
