-- =====================================================
-- WAREHOUSE MANAGER FINAL FIX
-- =====================================================
-- This script works with the existing warehouses table structure
-- and creates warehouse manager profiles safely

-- Step 1: Verify table structure
DO $$
BEGIN
  RAISE NOTICE '🔍 Checking warehouses table structure...';
  
  -- Check if manager_id column exists
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'warehouses' AND column_name = 'manager_id'
  ) THEN
    RAISE NOTICE '✅ manager_id column exists in warehouses table';
  ELSE
    RAISE NOTICE '❌ manager_id column missing from warehouses table';
  END IF;
END $$;

-- Step 2: Create warehouse manager profiles for existing auth users
DO $$
DECLARE
  auth_user_id UUID;
BEGIN
  RAISE NOTICE '👤 Creating warehouse manager profiles...';
  
  -- Create profile for warehouse@samastore.com
  SELECT id INTO auth_user_id 
  FROM auth.users 
  WHERE email = 'warehouse@samastore.com';
  
  IF auth_user_id IS NOT NULL THEN
    INSERT INTO public.user_profiles (
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
    
    RAISE NOTICE '✅ Created/Updated: warehouse@samastore.com';
  ELSE
    RAISE NOTICE '❌ Auth user not found: warehouse@samastore.com';
    RAISE NOTICE '📋 Please create this user in Supabase Auth UI first';
  END IF;
  
  -- Create profile for warehouse1@samastore.com
  SELECT id INTO auth_user_id 
  FROM auth.users 
  WHERE email = 'warehouse1@samastore.com';
  
  IF auth_user_id IS NOT NULL THEN
    INSERT INTO public.user_profiles (
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
    
    RAISE NOTICE '✅ Created/Updated: warehouse1@samastore.com';
  ELSE
    RAISE NOTICE '❌ Auth user not found: warehouse1@samastore.com';
  END IF;
  
  -- Create profile for warehouse2@samastore.com
  SELECT id INTO auth_user_id 
  FROM auth.users 
  WHERE email = 'warehouse2@samastore.com';
  
  IF auth_user_id IS NOT NULL THEN
    INSERT INTO public.user_profiles (
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
    
    RAISE NOTICE '✅ Created/Updated: warehouse2@samastore.com';
  ELSE
    RAISE NOTICE '❌ Auth user not found: warehouse2@samastore.com';
  END IF;
END $$;

-- Step 3: Create sample warehouses using explicit schema reference
DO $$
DECLARE
  manager_user_id UUID;
BEGIN
  RAISE NOTICE '🏭 Creating sample warehouses...';
  
  -- Create main warehouse
  SELECT id INTO manager_user_id 
  FROM public.user_profiles 
  WHERE email = 'warehouse@samastore.com' AND role = 'warehouseManager';
  
  IF manager_user_id IS NOT NULL THEN
    INSERT INTO public.warehouses (
      name,
      address,
      description,
      location,
      manager_id,
      capacity,
      current_stock,
      status,
      is_active,
      created_by
    ) VALUES (
      'المخزن الرئيسي',
      'الرياض - حي الملك فهد',
      'المخزن الرئيسي للشركة',
      'الرياض - حي الملك فهد',
      manager_user_id,
      10000,
      0,
      'active',
      true,
      manager_user_id
    )
    ON CONFLICT (name) DO UPDATE SET
      manager_id = EXCLUDED.manager_id,
      updated_at = NOW();
    
    RAISE NOTICE '✅ Created/Updated main warehouse';
  ELSE
    RAISE NOTICE '❌ Warehouse manager not found for main warehouse';
  END IF;
  
  -- Create secondary warehouse
  SELECT id INTO manager_user_id 
  FROM public.user_profiles 
  WHERE email = 'warehouse1@samastore.com' AND role = 'warehouseManager';
  
  IF manager_user_id IS NOT NULL THEN
    INSERT INTO public.warehouses (
      name,
      address,
      description,
      location,
      manager_id,
      capacity,
      current_stock,
      status,
      is_active,
      created_by
    ) VALUES (
      'المخزن الفرعي',
      'جدة - حي الروضة',
      'المخزن الفرعي للشركة',
      'جدة - حي الروضة',
      manager_user_id,
      5000,
      0,
      'active',
      true,
      manager_user_id
    )
    ON CONFLICT (name) DO UPDATE SET
      manager_id = EXCLUDED.manager_id,
      updated_at = NOW();
    
    RAISE NOTICE '✅ Created/Updated secondary warehouse';
  ELSE
    RAISE NOTICE '❌ Warehouse manager not found for secondary warehouse';
  END IF;
END $$;

-- Step 4: Create additional warehouse management tables
CREATE TABLE IF NOT EXISTS warehouse_inventory (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL,
  quantity INTEGER DEFAULT 0,
  min_stock_level INTEGER DEFAULT 10,
  max_stock_level INTEGER DEFAULT 1000,
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_by UUID REFERENCES public.user_profiles(id)
);

CREATE TABLE IF NOT EXISTS warehouse_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('in', 'out', 'transfer', 'adjustment')),
  quantity INTEGER NOT NULL,
  reference_number TEXT,
  notes TEXT,
  created_by UUID REFERENCES public.user_profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS withdrawal_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL,
  requested_quantity INTEGER NOT NULL,
  approved_quantity INTEGER DEFAULT 0,
  requester_id UUID REFERENCES public.user_profiles(id),
  approver_id UUID REFERENCES public.user_profiles(id),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
  request_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  approval_date TIMESTAMP WITH TIME ZONE,
  completion_date TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  rejection_reason TEXT
);

-- Step 5: Verification
DO $$
DECLARE
  user_count INTEGER;
  warehouse_count INTEGER;
BEGIN
  -- Count warehouse managers
  SELECT COUNT(*) INTO user_count 
  FROM public.user_profiles 
  WHERE role = 'warehouseManager';
  
  -- Count warehouses with managers
  SELECT COUNT(*) INTO warehouse_count 
  FROM public.warehouses 
  WHERE manager_id IS NOT NULL;
  
  RAISE NOTICE '';
  RAISE NOTICE '🎉 === WAREHOUSE MANAGER SETUP COMPLETED ===';
  RAISE NOTICE '✅ Warehouse manager users: %', user_count;
  RAISE NOTICE '✅ Warehouses with managers: %', warehouse_count;
  RAISE NOTICE '';
  RAISE NOTICE '📋 Test Credentials:';
  RAISE NOTICE '   Email: warehouse@samastore.com';
  RAISE NOTICE '   Password: temp123';
  RAISE NOTICE '   Role: warehouseManager';
  RAISE NOTICE '';
  RAISE NOTICE '🚀 Next Steps:';
  RAISE NOTICE '1. Test login in Flutter app';
  RAISE NOTICE '2. Verify warehouse manager dashboard loads';
  RAISE NOTICE '3. Check warehouse management features';
END $$;

-- Show created warehouse managers
SELECT 
  email,
  name,
  role,
  status
FROM public.user_profiles 
WHERE role = 'warehouseManager'
ORDER BY email;

-- Show warehouses with their managers
SELECT 
  w.name as warehouse_name,
  w.location,
  w.status,
  w.capacity,
  up.name as manager_name,
  up.email as manager_email
FROM public.warehouses w
LEFT JOIN public.user_profiles up ON w.manager_id = up.id
WHERE up.role = 'warehouseManager' OR w.manager_id IS NOT NULL
ORDER BY w.name;
