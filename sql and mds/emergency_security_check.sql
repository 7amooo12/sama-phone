-- 🚨 EMERGENCY SECURITY CHECK
-- Critical investigation of warehouse manager role corruption

-- 1. Check current state of warehouse@samastore.com
SELECT 
  '🔍 WAREHOUSE USER CHECK' as check_type,
  id,
  email,
  name,
  role,
  status,
  created_at,
  updated_at
FROM user_profiles 
WHERE email = 'warehouse@samastore.com';

-- 2. Check for any recent role changes
SELECT 
  '📊 RECENT ROLE CHANGES' as check_type,
  email,
  role,
  status,
  updated_at,
  created_at,
  CASE 
    WHEN updated_at > created_at THEN 'MODIFIED'
    ELSE 'ORIGINAL'
  END as modification_status
FROM user_profiles 
WHERE email = 'warehouse@samastore.com'
   OR role = 'admin'
   OR role = 'warehouseManager'
ORDER BY updated_at DESC;

-- 3. Check for any admin users that might be corrupted
SELECT 
  '🔴 ADMIN USERS AUDIT' as check_type,
  id,
  email,
  name,
  role,
  status,
  updated_at
FROM user_profiles 
WHERE role = 'admin'
ORDER BY updated_at DESC;

-- 4. Check for warehouse managers
SELECT 
  '🟣 WAREHOUSE MANAGERS AUDIT' as check_type,
  id,
  email,
  name,
  role,
  status,
  updated_at
FROM user_profiles 
WHERE role = 'warehouseManager' OR role = 'warehouse_manager'
ORDER BY updated_at DESC;

-- 5. Check for any permission-related tables
SELECT 
  '🔐 PERMISSION TABLES CHECK' as check_type,
  table_name,
  table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND (table_name LIKE '%permission%' 
       OR table_name LIKE '%role%' 
       OR table_name LIKE '%access%')
ORDER BY table_name;

-- 6. Check RLS policies on user_profiles
SELECT 
  '🛡️ RLS POLICIES CHECK' as check_type,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- 7. Emergency fix: Restore warehouse@samastore.com to correct role
DO $$
DECLARE
  warehouse_user_id UUID;
  current_role TEXT;
BEGIN
  -- Get current state
  SELECT id, role INTO warehouse_user_id, current_role
  FROM user_profiles 
  WHERE email = 'warehouse@samastore.com';
  
  IF warehouse_user_id IS NOT NULL THEN
    RAISE NOTICE '🔍 Found user: % with role: %', warehouse_user_id, current_role;
    
    -- If role is corrupted (admin instead of warehouseManager)
    IF current_role = 'admin' THEN
      RAISE NOTICE '🚨 SECURITY BREACH DETECTED: warehouse user has admin role!';
      
      -- Restore correct role
      UPDATE user_profiles 
      SET 
        role = 'warehouseManager',
        updated_at = NOW()
      WHERE id = warehouse_user_id;
      
      RAISE NOTICE '✅ EMERGENCY FIX: Restored warehouse@samastore.com to warehouseManager role';
    ELSE
      RAISE NOTICE '✅ Role is correct: %', current_role;
    END IF;
  ELSE
    RAISE NOTICE '❌ User warehouse@samastore.com not found';
  END IF;
END $$;

-- 8. Final verification
SELECT 
  '✅ FINAL VERIFICATION' as check_type,
  id,
  email,
  name,
  role,
  status,
  updated_at
FROM user_profiles 
WHERE email = 'warehouse@samastore.com';

-- 9. Check for any audit logs or history tables
SELECT 
  '📋 AUDIT TABLES CHECK' as check_type,
  table_name
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND (table_name LIKE '%audit%' 
       OR table_name LIKE '%log%' 
       OR table_name LIKE '%history%')
ORDER BY table_name;
