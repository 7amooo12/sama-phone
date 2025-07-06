-- =====================================================
-- WAREHOUSE MANAGER ROLE SETUP FOR SMARTBIZTRACKER
-- =====================================================
-- This script creates a complete warehouse manager user account
-- with proper role assignment and permissions

-- Step 1: Add unique constraint on email if it doesn't exist
-- This is required for the ON CONFLICT clause to work
DO $$
BEGIN
  -- Check if unique constraint on email already exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'user_profiles_email_key'
    AND table_name = 'user_profiles'
  ) THEN
    -- Add unique constraint on email column
    ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_email_key UNIQUE (email);
    RAISE NOTICE 'Added unique constraint on email column';
  ELSE
    RAISE NOTICE 'Unique constraint on email already exists';
  END IF;
END $$;

-- Step 2: Create the warehouse manager user profile
-- Note: The auth user should be created through Supabase Auth UI or API
-- This script only creates the user profile in the user_profiles table

INSERT INTO user_profiles (
  id,
  email,
  name,
  phone_number,
  role,
  status,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'warehouse@samastore.com',
  'مدير المخزن الرئيسي',
  '+966501234567',
  'warehouseManager',
  'approved',
  NOW(),
  NOW()
) ON CONFLICT (email) DO UPDATE SET
  role = EXCLUDED.role,
  status = EXCLUDED.status,
  updated_at = NOW();

-- Step 3: Create additional warehouse manager accounts for testing
INSERT INTO user_profiles (
  id,
  email,
  name,
  phone,
  role,
  status,
  created_at,
  updated_at
) VALUES
(
  gen_random_uuid(),
  'warehouse1@samastore.com',
  'مدير المخزن الفرعي الأول',
  '+966501234568',
  'warehouseManager',
  'approved',
  NOW(),
  NOW()
),
(
  gen_random_uuid(),
  'warehouse2@samastore.com',
  'مدير مخزن الطوارئ',
  '+966501234569',
  'warehouseManager',
  'approved',
  NOW(),
  NOW()
) ON CONFLICT (email) DO UPDATE SET
  role = EXCLUDED.role,
  status = EXCLUDED.status,
  updated_at = NOW();

-- Step 4: Verify the warehouse manager role exists in the enum
-- This is just a check query - run this to verify
SELECT 
  email,
  name,
  role,
  status,
  created_at
FROM user_profiles 
WHERE role = 'warehouseManager';

-- Step 4: Create RLS policies for warehouse manager access
-- Enable RLS on user_profiles if not already enabled
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Policy for warehouse managers to read their own profile
CREATE POLICY "warehouse_managers_can_read_own_profile" ON user_profiles
  FOR SELECT
  USING (
    auth.uid() = id AND role = 'warehouseManager'
  );

-- Policy for warehouse managers to update their own profile
CREATE POLICY "warehouse_managers_can_update_own_profile" ON user_profiles
  FOR UPDATE
  USING (
    auth.uid() = id AND role = 'warehouseManager'
  );

-- Step 5: Create warehouse-specific tables if they don't exist
-- Warehouses table
CREATE TABLE IF NOT EXISTS warehouses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  location TEXT,
  manager_id UUID REFERENCES user_profiles(id),
  capacity INTEGER DEFAULT 0,
  current_stock INTEGER DEFAULT 0,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Warehouse inventory table
CREATE TABLE IF NOT EXISTS warehouse_inventory (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  warehouse_id UUID REFERENCES warehouses(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL,
  quantity INTEGER DEFAULT 0,
  min_stock_level INTEGER DEFAULT 10,
  max_stock_level INTEGER DEFAULT 1000,
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_by UUID REFERENCES user_profiles(id)
);

-- Warehouse transactions table
CREATE TABLE IF NOT EXISTS warehouse_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  warehouse_id UUID REFERENCES warehouses(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('in', 'out', 'transfer', 'adjustment')),
  quantity INTEGER NOT NULL,
  reference_number TEXT,
  notes TEXT,
  created_by UUID REFERENCES user_profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Withdrawal requests table
CREATE TABLE IF NOT EXISTS withdrawal_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  warehouse_id UUID REFERENCES warehouses(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL,
  requested_quantity INTEGER NOT NULL,
  approved_quantity INTEGER DEFAULT 0,
  requester_id UUID REFERENCES user_profiles(id),
  approver_id UUID REFERENCES user_profiles(id),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
  request_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  approval_date TIMESTAMP WITH TIME ZONE,
  completion_date TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  rejection_reason TEXT
);

-- Step 6: Create RLS policies for warehouse tables
-- Warehouses table policies
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "warehouse_managers_can_read_warehouses" ON warehouses
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
      AND role IN ('warehouseManager', 'admin', 'owner')
    )
  );

CREATE POLICY "warehouse_managers_can_manage_assigned_warehouses" ON warehouses
  FOR ALL
  USING (
    manager_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() 
      AND role IN ('admin', 'owner')
    )
  );

-- Warehouse inventory policies
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "warehouse_managers_can_manage_inventory" ON warehouse_inventory
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM warehouses w
      JOIN user_profiles u ON u.id = auth.uid()
      WHERE w.id = warehouse_inventory.warehouse_id
      AND (w.manager_id = auth.uid() OR u.role IN ('admin', 'owner'))
    )
  );

-- Warehouse transactions policies
ALTER TABLE warehouse_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "warehouse_managers_can_manage_transactions" ON warehouse_transactions
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM warehouses w
      JOIN user_profiles u ON u.id = auth.uid()
      WHERE w.id = warehouse_transactions.warehouse_id
      AND (w.manager_id = auth.uid() OR u.role IN ('admin', 'owner'))
    )
  );

-- Withdrawal requests policies
ALTER TABLE withdrawal_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_can_create_withdrawal_requests" ON withdrawal_requests
  FOR INSERT
  WITH CHECK (requester_id = auth.uid());

CREATE POLICY "warehouse_managers_can_manage_withdrawal_requests" ON withdrawal_requests
  FOR ALL
  USING (
    requester_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM warehouses w
      JOIN user_profiles u ON u.id = auth.uid()
      WHERE w.id = withdrawal_requests.warehouse_id
      AND (w.manager_id = auth.uid() OR u.role IN ('admin', 'owner'))
    )
  );

-- Step 7: Insert sample warehouse data
INSERT INTO warehouses (name, location, manager_id, capacity, current_stock, status) 
SELECT 
  'المخزن الرئيسي',
  'الرياض - حي الملك فهد',
  up.id,
  10000,
  0,
  'active'
FROM user_profiles up 
WHERE up.email = 'warehouse@samastore.com'
ON CONFLICT DO NOTHING;

INSERT INTO warehouses (name, location, manager_id, capacity, current_stock, status) 
SELECT 
  'المخزن الفرعي',
  'جدة - حي الروضة',
  up.id,
  5000,
  0,
  'active'
FROM user_profiles up 
WHERE up.email = 'warehouse1@samastore.com'
ON CONFLICT DO NOTHING;

-- Step 8: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_warehouse_id ON warehouse_inventory(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_product_id ON warehouse_inventory(product_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_warehouse_id ON warehouse_transactions(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_created_at ON warehouse_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_warehouse_id ON withdrawal_requests(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_status ON withdrawal_requests(status);

-- Step 9: Create functions for warehouse operations
-- Function to update warehouse current stock
CREATE OR REPLACE FUNCTION update_warehouse_current_stock()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE warehouses 
  SET current_stock = (
    SELECT COALESCE(SUM(quantity), 0)
    FROM warehouse_inventory 
    WHERE warehouse_id = NEW.warehouse_id
  ),
  updated_at = NOW()
  WHERE id = NEW.warehouse_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update warehouse stock
DROP TRIGGER IF EXISTS trigger_update_warehouse_stock ON warehouse_inventory;
CREATE TRIGGER trigger_update_warehouse_stock
  AFTER INSERT OR UPDATE OR DELETE ON warehouse_inventory
  FOR EACH ROW
  EXECUTE FUNCTION update_warehouse_current_stock();

-- Step 10: Verification queries
-- Run these to verify the setup
/*
-- Check if warehouse manager users were created
SELECT email, name, role, status FROM user_profiles WHERE role = 'warehouseManager';

-- Check if warehouses were created
SELECT w.name, w.location, up.name as manager_name, w.status 
FROM warehouses w
LEFT JOIN user_profiles up ON w.manager_id = up.id;

-- Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'withdrawal_requests');
*/

-- Final success message
DO $$
BEGIN
  RAISE NOTICE 'Warehouse Manager setup completed successfully!';
  RAISE NOTICE 'Test credentials:';
  RAISE NOTICE 'Email: warehouse@samastore.com';
  RAISE NOTICE 'Password: temp123 (set this in Supabase Auth)';
  RAISE NOTICE 'Role: warehouseManager';
  RAISE NOTICE 'Status: approved';
END $$;
