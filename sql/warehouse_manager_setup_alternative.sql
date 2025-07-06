-- =====================================================
-- WAREHOUSE MANAGER ROLE SETUP FOR SMARTBIZTRACKER
-- ALTERNATIVE VERSION (Works with existing auth users)
-- =====================================================
-- This script creates warehouse manager profiles for existing auth users
-- or provides instructions for creating auth users first

-- IMPORTANT: This script requires auth users to exist first!
-- Create auth users in Supabase Auth UI before running this script:
-- 1. warehouse@samastore.com
-- 2. warehouse1@samastore.com
-- 3. warehouse2@samastore.com

-- Step 1: Create warehouse manager profile for existing auth user
DO $$
DECLARE
  auth_user_id UUID;
BEGIN
  -- Find existing auth user by email
  SELECT id INTO auth_user_id
  FROM auth.users
  WHERE email = 'warehouse@samastore.com';

  IF auth_user_id IS NOT NULL THEN
    -- Check if profile already exists
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth_user_id) THEN
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
        auth_user_id,
        'warehouse@samastore.com',
        'مدير المخزن الرئيسي',
        '+966501234567',
        'warehouseManager',
        'approved',
        NOW(),
        NOW()
      );
      RAISE NOTICE '✅ Created warehouse manager profile: warehouse@samastore.com';
    ELSE
      -- Update existing profile
      UPDATE user_profiles
      SET
        role = 'warehouseManager',
        status = 'approved',
        updated_at = NOW()
      WHERE id = auth_user_id;
      RAISE NOTICE '✅ Updated existing profile: warehouse@samastore.com';
    END IF;
  ELSE
    RAISE NOTICE '❌ Auth user not found: warehouse@samastore.com';
    RAISE NOTICE '📋 Please create this user in Supabase Auth UI first';
  END IF;
END $$;

-- Step 2: Create additional warehouse manager profiles
DO $$
DECLARE
  auth_user_id UUID;
BEGIN
  -- Create warehouse1@samastore.com profile
  SELECT id INTO auth_user_id
  FROM auth.users
  WHERE email = 'warehouse1@samastore.com';

  IF auth_user_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth_user_id) THEN
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
        auth_user_id,
        'warehouse1@samastore.com',
        'مدير المخزن الفرعي الأول',
        '+966501234568',
        'warehouseManager',
        'approved',
        NOW(),
        NOW()
      );
      RAISE NOTICE '✅ Created warehouse manager profile: warehouse1@samastore.com';
    ELSE
      UPDATE user_profiles
      SET
        role = 'warehouseManager',
        status = 'approved',
        updated_at = NOW()
      WHERE id = auth_user_id;
      RAISE NOTICE '✅ Updated existing profile: warehouse1@samastore.com';
    END IF;
  ELSE
    RAISE NOTICE '❌ Auth user not found: warehouse1@samastore.com';
  END IF;

  -- Create warehouse2@samastore.com profile
  SELECT id INTO auth_user_id
  FROM auth.users
  WHERE email = 'warehouse2@samastore.com';

  IF auth_user_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth_user_id) THEN
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
        auth_user_id,
        'warehouse2@samastore.com',
        'مدير مخزن الطوارئ',
        '+966501234569',
        'warehouseManager',
        'approved',
        NOW(),
        NOW()
      );
      RAISE NOTICE '✅ Created warehouse manager profile: warehouse2@samastore.com';
    ELSE
      UPDATE user_profiles
      SET
        role = 'warehouseManager',
        status = 'approved',
        updated_at = NOW()
      WHERE id = auth_user_id;
      RAISE NOTICE '✅ Updated existing profile: warehouse2@samastore.com';
    END IF;
  ELSE
    RAISE NOTICE '❌ Auth user not found: warehouse2@samastore.com';
  END IF;
END $$;

-- Step 3: Verify the warehouse manager accounts were created
SELECT 
  email,
  name,
  role,
  status,
  created_at
FROM user_profiles 
WHERE role = 'warehouseManager'
ORDER BY email;

-- Step 4: Create warehouse-specific tables if they don't exist
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

-- Add missing columns to existing warehouses table
DO $$
BEGIN
  -- Add manager_id column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'warehouses'
    AND column_name = 'manager_id'
  ) THEN
    ALTER TABLE warehouses ADD COLUMN manager_id UUID REFERENCES user_profiles(id);
    RAISE NOTICE '✅ Added manager_id column to warehouses table';
  ELSE
    RAISE NOTICE 'ℹ️ manager_id column already exists in warehouses table';
  END IF;

  -- Add location column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'warehouses'
    AND column_name = 'location'
  ) THEN
    ALTER TABLE warehouses ADD COLUMN location TEXT;
    RAISE NOTICE '✅ Added location column to warehouses table';
  ELSE
    RAISE NOTICE 'ℹ️ location column already exists in warehouses table';
  END IF;

  -- Add capacity column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'warehouses'
    AND column_name = 'capacity'
  ) THEN
    ALTER TABLE warehouses ADD COLUMN capacity INTEGER DEFAULT 0;
    RAISE NOTICE '✅ Added capacity column to warehouses table';
  ELSE
    RAISE NOTICE 'ℹ️ capacity column already exists in warehouses table';
  END IF;

  -- Add current_stock column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'warehouses'
    AND column_name = 'current_stock'
  ) THEN
    ALTER TABLE warehouses ADD COLUMN current_stock INTEGER DEFAULT 0;
    RAISE NOTICE '✅ Added current_stock column to warehouses table';
  ELSE
    RAISE NOTICE 'ℹ️ current_stock column already exists in warehouses table';
  END IF;

  -- Add status column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'warehouses'
    AND column_name = 'status'
  ) THEN
    ALTER TABLE warehouses ADD COLUMN status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance'));
    RAISE NOTICE '✅ Added status column to warehouses table';
  ELSE
    RAISE NOTICE 'ℹ️ status column already exists in warehouses table';
  END IF;
END $$;

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

-- Step 5: Create RLS policies for warehouse tables
-- Enable RLS on user_profiles if not already enabled
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Warehouses table policies
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist to avoid conflicts
DROP POLICY IF EXISTS "warehouse_managers_can_read_warehouses" ON warehouses;
DROP POLICY IF EXISTS "warehouse_managers_can_manage_assigned_warehouses" ON warehouses;

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

DROP POLICY IF EXISTS "warehouse_managers_can_manage_inventory" ON warehouse_inventory;

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

DROP POLICY IF EXISTS "warehouse_managers_can_manage_transactions" ON warehouse_transactions;

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

DROP POLICY IF EXISTS "users_can_create_withdrawal_requests" ON withdrawal_requests;
DROP POLICY IF EXISTS "warehouse_managers_can_manage_withdrawal_requests" ON withdrawal_requests;

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

-- Step 6: Insert sample warehouse data (conditional)
DO $$
BEGIN
  -- Insert main warehouse if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM warehouses WHERE name = 'المخزن الرئيسي') THEN
    INSERT INTO warehouses (name, location, manager_id, capacity, current_stock, status) 
    SELECT 
      'المخزن الرئيسي',
      'الرياض - حي الملك فهد',
      up.id,
      10000,
      0,
      'active'
    FROM user_profiles up 
    WHERE up.email = 'warehouse@samastore.com';
    RAISE NOTICE 'Created main warehouse';
  END IF;

  -- Insert secondary warehouse if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM warehouses WHERE name = 'المخزن الفرعي') THEN
    INSERT INTO warehouses (name, location, manager_id, capacity, current_stock, status) 
    SELECT 
      'المخزن الفرعي',
      'جدة - حي الروضة',
      up.id,
      5000,
      0,
      'active'
    FROM user_profiles up 
    WHERE up.email = 'warehouse1@samastore.com';
    RAISE NOTICE 'Created secondary warehouse';
  END IF;
END $$;

-- Step 7: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_warehouse_id ON warehouse_inventory(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_product_id ON warehouse_inventory(product_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_warehouse_id ON warehouse_transactions(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_created_at ON warehouse_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_warehouse_id ON withdrawal_requests(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_status ON withdrawal_requests(status);

-- Step 8: Final verification and success message
DO $$
DECLARE
  warehouse_count INTEGER;
  user_count INTEGER;
BEGIN
  -- Count created users
  SELECT COUNT(*) INTO user_count FROM user_profiles WHERE role = 'warehouseManager';
  
  -- Count created warehouses
  SELECT COUNT(*) INTO warehouse_count FROM warehouses;
  
  RAISE NOTICE '=== WAREHOUSE MANAGER SETUP COMPLETED ===';
  RAISE NOTICE 'Created % warehouse manager users', user_count;
  RAISE NOTICE 'Created % warehouses', warehouse_count;
  RAISE NOTICE '';
  RAISE NOTICE 'Test credentials:';
  RAISE NOTICE 'Email: warehouse@samastore.com';
  RAISE NOTICE 'Password: temp123 (set this in Supabase Auth)';
  RAISE NOTICE 'Role: warehouseManager';
  RAISE NOTICE 'Status: approved';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '1. Create auth users in Supabase Auth UI';
  RAISE NOTICE '2. Test login in Flutter app';
  RAISE NOTICE '3. Verify dashboard loads correctly';
END $$;
