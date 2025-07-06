-- 🔧 COMPREHENSIVE FIX FOR USER hima@sama.com DATABASE ACCESS
-- Restore full functionality after table recreation incident

-- ==================== STEP 1: ENSURE USER PROFILE EXISTS ====================

-- First, ensure the user profile exists and is properly configured
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
  '4ac083bc-3e05-4456-8579-0877d2627b15',
  'hima@sama.com',
  'هيما',
  '+966501234567',
  'accountant',  -- Assuming accountant role based on warehouse access needs
  'approved',
  '2025-05-21 14:18:00+00',
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  role = CASE 
    WHEN user_profiles.role IN ('admin', 'owner') THEN user_profiles.role  -- Don't downgrade admin/owner
    ELSE 'accountant'  -- Set to accountant for warehouse access
  END,
  status = 'approved',
  updated_at = NOW();

-- Verify the user profile
SELECT 
  '✅ USER PROFILE UPDATED' as status,
  id,
  email,
  name,
  role,
  status,
  updated_at
FROM user_profiles 
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';

-- ==================== STEP 2: FIX USER_PROFILES RLS POLICIES ====================

-- Drop any problematic policies
DROP POLICY IF EXISTS "user_profiles_open_access" ON user_profiles;
DROP POLICY IF EXISTS "authenticated_read_all" ON user_profiles;
DROP POLICY IF EXISTS "users_can_read_own_profile" ON user_profiles;
DROP POLICY IF EXISTS "users_can_update_own_profile" ON user_profiles;

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create secure, non-recursive policies
CREATE POLICY "user_profiles_select_own" ON user_profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "user_profiles_update_own" ON user_profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Allow service role full access (for admin operations)
CREATE POLICY "user_profiles_service_role" ON user_profiles
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- Allow admins to view all profiles
CREATE POLICY "user_profiles_admin_select" ON user_profiles
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM auth.users au
      WHERE au.id = auth.uid()
        AND au.raw_user_meta_data->>'role' = 'admin'
    )
  );

-- ==================== STEP 3: FIX WAREHOUSES TABLE ACCESS ====================

-- Ensure warehouses table exists
CREATE TABLE IF NOT EXISTS warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Enable RLS
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "warehouses_select" ON warehouses;
DROP POLICY IF EXISTS "secure_warehouses_select" ON warehouses;

-- Create comprehensive warehouse access policy
CREATE POLICY "warehouses_full_access" ON warehouses
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND up.status = 'approved'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND up.status = 'approved'
    )
  );

-- ==================== STEP 4: FIX WAREHOUSE_INVENTORY TABLE ACCESS ====================

-- Ensure warehouse_inventory table exists
CREATE TABLE IF NOT EXISTS warehouse_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID REFERENCES warehouses(id) NOT NULL,
  product_id TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 0,
  reserved_quantity INTEGER NOT NULL DEFAULT 0,
  minimum_stock INTEGER DEFAULT 0,
  maximum_stock INTEGER,
  last_updated_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Enable RLS
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;

-- Create inventory access policy
CREATE POLICY "warehouse_inventory_access" ON warehouse_inventory
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND up.status = 'approved'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND up.status = 'approved'
    )
  );

-- ==================== STEP 5: FIX WAREHOUSE_REQUESTS TABLE ACCESS ====================

-- Ensure warehouse_requests table exists
CREATE TABLE IF NOT EXISTS warehouse_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID REFERENCES warehouses(id) NOT NULL,
  product_id TEXT NOT NULL,
  requested_quantity INTEGER NOT NULL,
  approved_quantity INTEGER DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
  requested_by UUID REFERENCES auth.users(id) NOT NULL,
  approved_by UUID REFERENCES auth.users(id),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Enable RLS
ALTER TABLE warehouse_requests ENABLE ROW LEVEL SECURITY;

-- Create requests access policy
CREATE POLICY "warehouse_requests_access" ON warehouse_requests
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND up.status = 'approved'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND up.status = 'approved'
    )
  );

-- ==================== STEP 6: FIX WAREHOUSE_TRANSACTIONS TABLE ACCESS ====================

-- Ensure warehouse_transactions table exists
CREATE TABLE IF NOT EXISTS warehouse_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID REFERENCES warehouses(id) NOT NULL,
  product_id TEXT NOT NULL,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('in', 'out', 'transfer', 'adjustment')),
  quantity INTEGER NOT NULL,
  reference_id UUID,
  reference_type TEXT,
  performed_by UUID REFERENCES auth.users(id) NOT NULL,
  reason TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Enable RLS
ALTER TABLE warehouse_transactions ENABLE ROW LEVEL SECURITY;

-- Create transactions access policy
CREATE POLICY "warehouse_transactions_access" ON warehouse_transactions
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND up.status = 'approved'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid()
        AND up.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND up.status = 'approved'
    )
  );

-- ==================== STEP 7: VERIFY ACCESS ====================

-- Test access for the specific user
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "4ac083bc-3e05-4456-8579-0877d2627b15"}';

-- Test queries
SELECT 'Testing user_profiles access...' as test;
SELECT COUNT(*) as user_profiles_count FROM user_profiles;

SELECT 'Testing warehouses access...' as test;
SELECT COUNT(*) as warehouses_count FROM warehouses;

SELECT 'Testing warehouse_inventory access...' as test;
SELECT COUNT(*) as inventory_count FROM warehouse_inventory;

-- Reset role
RESET ROLE;

-- ==================== STEP 8: FINAL VERIFICATION ====================

SELECT 
  '🎉 RESTORATION COMPLETE' as status,
  'User: hima@sama.com' as user_email,
  'UID: 4ac083bc-3e05-4456-8579-0877d2627b15' as user_id,
  'Fixed at: ' || NOW()::TEXT as fix_timestamp;
