-- 🔍 CHECK WAREHOUSE MANAGER USER DATA
-- Script to verify warehouse@samastore.com user exists with correct role

-- Check if user exists in auth.users
SELECT 
  'AUTH USER CHECK' as check_type,
  id,
  email,
  email_confirmed,
  created_at
FROM auth.users 
WHERE email = 'warehouse@samastore.com';

-- Check if user profile exists with correct role
SELECT 
  'USER PROFILE CHECK' as check_type,
  id,
  email,
  name,
  role,
  status,
  created_at,
  updated_at
FROM user_profiles 
WHERE email = 'warehouse@samastore.com';

-- Check all warehouse manager users
SELECT 
  'ALL WAREHOUSE MANAGERS' as check_type,
  id,
  email,
  name,
  role,
  status,
  created_at
FROM user_profiles 
WHERE role = 'warehouseManager' OR role = 'warehouse_manager';

-- Check for any role inconsistencies
SELECT 
  'ROLE VARIATIONS CHECK' as check_type,
  role,
  COUNT(*) as count
FROM user_profiles 
WHERE role LIKE '%warehouse%' OR role LIKE '%manager%'
GROUP BY role;

-- Fix warehouse@samastore.com if needed
DO $$
DECLARE
  auth_user_id UUID;
BEGIN
  -- Get auth user ID
  SELECT id INTO auth_user_id 
  FROM auth.users 
  WHERE email = 'warehouse@samastore.com';
  
  IF auth_user_id IS NOT NULL THEN
    -- Update or insert user profile
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
    
    RAISE NOTICE '✅ Fixed/Updated: warehouse@samastore.com with role: warehouseManager';
  ELSE
    RAISE NOTICE '❌ Auth user not found: warehouse@samastore.com';
    RAISE NOTICE '📋 Please create this user in Supabase Auth UI first';
  END IF;
END $$;

-- Final verification
SELECT 
  'FINAL VERIFICATION' as check_type,
  up.id,
  up.email,
  up.name,
  up.role,
  up.status,
  au.email_confirmed
FROM user_profiles up
JOIN auth.users au ON up.id = au.id
WHERE up.email = 'warehouse@samastore.com';
