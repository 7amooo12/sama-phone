-- =====================================================
-- SIMPLE WAREHOUSE MANAGER SETUP
-- =====================================================
-- This script creates warehouse manager profiles for existing auth users
-- Follow the steps below in order

-- =====================================================
-- STEP 1: CREATE AUTH USERS FIRST (Do this in Supabase Auth UI)
-- =====================================================
/*
Before running this SQL script, create these users in Supabase Auth UI:

1. Go to Supabase Dashboard → Authentication → Users
2. Click "Create User" for each of these:

User 1:
- Email: warehouse@samastore.com
- Password: temp123
- Email Confirmed: ✅ Yes

User 2:
- Email: warehouse1@samastore.com
- Password: temp123
- Email Confirmed: ✅ Yes

User 3:
- Email: warehouse2@samastore.com
- Password: temp123
- Email Confirmed: ✅ Yes

Then run this SQL script.
*/

-- =====================================================
-- STEP 2: CREATE USER PROFILES (Run this SQL)
-- =====================================================

-- Create warehouse manager profile for warehouse@samastore.com
DO $$
DECLARE
  auth_user_id UUID;
BEGIN
  -- Find the auth user
  SELECT id INTO auth_user_id 
  FROM auth.users 
  WHERE email = 'warehouse@samastore.com';
  
  IF auth_user_id IS NOT NULL THEN
    -- Create or update profile
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
    )
    ON CONFLICT (id) DO UPDATE SET
      role = 'warehouseManager',
      status = 'approved',
      updated_at = NOW();
    
    RAISE NOTICE '✅ Created/Updated warehouse manager: warehouse@samastore.com';
  ELSE
    RAISE NOTICE '❌ Auth user not found: warehouse@samastore.com';
    RAISE NOTICE '📋 Please create this user in Supabase Auth UI first';
  END IF;
END $$;

-- Create warehouse manager profile for warehouse1@samastore.com
DO $$
DECLARE
  auth_user_id UUID;
BEGIN
  SELECT id INTO auth_user_id 
  FROM auth.users 
  WHERE email = 'warehouse1@samastore.com';
  
  IF auth_user_id IS NOT NULL THEN
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
    )
    ON CONFLICT (id) DO UPDATE SET
      role = 'warehouseManager',
      status = 'approved',
      updated_at = NOW();
    
    RAISE NOTICE '✅ Created/Updated warehouse manager: warehouse1@samastore.com';
  ELSE
    RAISE NOTICE '❌ Auth user not found: warehouse1@samastore.com';
  END IF;
END $$;

-- Create warehouse manager profile for warehouse2@samastore.com
DO $$
DECLARE
  auth_user_id UUID;
BEGIN
  SELECT id INTO auth_user_id 
  FROM auth.users 
  WHERE email = 'warehouse2@samastore.com';
  
  IF auth_user_id IS NOT NULL THEN
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
    )
    ON CONFLICT (id) DO UPDATE SET
      role = 'warehouseManager',
      status = 'approved',
      updated_at = NOW();
    
    RAISE NOTICE '✅ Created/Updated warehouse manager: warehouse2@samastore.com';
  ELSE
    RAISE NOTICE '❌ Auth user not found: warehouse2@samastore.com';
  END IF;
END $$;

-- =====================================================
-- STEP 3: CREATE WAREHOUSE TABLES
-- =====================================================

-- Create warehouses table
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

-- Add manager_id column if warehouses table already exists without it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'warehouses'
    AND column_name = 'manager_id'
  ) THEN
    ALTER TABLE warehouses ADD COLUMN manager_id UUID REFERENCES user_profiles(id);
    RAISE NOTICE '✅ Added manager_id column to existing warehouses table';
  ELSE
    RAISE NOTICE 'ℹ️ manager_id column already exists in warehouses table';
  END IF;
END $$;

-- Create warehouse inventory table
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

-- Create warehouse transactions table
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

-- Create withdrawal requests table
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

-- =====================================================
-- STEP 4: CREATE SAMPLE WAREHOUSES
-- =====================================================

-- Insert main warehouse
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

-- Insert secondary warehouse
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

-- =====================================================
-- STEP 5: VERIFICATION
-- =====================================================

-- Check created users
SELECT 
  email,
  name,
  role,
  status,
  created_at
FROM user_profiles 
WHERE role = 'warehouseManager'
ORDER BY email;

-- Check created warehouses
SELECT 
  w.name,
  w.location,
  up.name as manager_name,
  w.status,
  w.capacity
FROM warehouses w
LEFT JOIN user_profiles up ON w.manager_id = up.id
ORDER BY w.name;

-- Final success message
DO $$
DECLARE
  user_count INTEGER;
  warehouse_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO user_count FROM user_profiles WHERE role = 'warehouseManager';
  SELECT COUNT(*) INTO warehouse_count FROM warehouses;
  
  RAISE NOTICE '';
  RAISE NOTICE '🎉 === WAREHOUSE MANAGER SETUP COMPLETED ===';
  RAISE NOTICE '✅ Created % warehouse manager users', user_count;
  RAISE NOTICE '✅ Created % warehouses', warehouse_count;
  RAISE NOTICE '';
  RAISE NOTICE '📋 Test Credentials:';
  RAISE NOTICE '   Email: warehouse@samastore.com';
  RAISE NOTICE '   Password: temp123';
  RAISE NOTICE '   Role: warehouseManager';
  RAISE NOTICE '';
  RAISE NOTICE '🚀 Next Steps:';
  RAISE NOTICE '   1. Test login in Flutter app';
  RAISE NOTICE '   2. Verify dashboard loads correctly';
  RAISE NOTICE '   3. Check warehouse management features';
END $$;
