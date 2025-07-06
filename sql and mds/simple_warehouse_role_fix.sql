-- 🔧 SIMPLE WAREHOUSE USER ROLE FIX
-- Quick fix for warehouse@samastore.com role issue

-- ==================== CURRENT STATE CHECK ====================

-- Check current role assignment
SELECT 
  '🔍 BEFORE FIX' as status,
  email,
  name,
  role,
  status,
  created_at,
  updated_at
FROM user_profiles 
WHERE email = 'warehouse@samastore.com';

-- ==================== APPLY THE FIX ====================

-- Update the role from "admin" to "warehouseManager"
UPDATE user_profiles 
SET 
  role = 'warehouseManager',
  updated_at = NOW()
WHERE email = 'warehouse@samastore.com' 
  AND role = 'admin';

-- ==================== VERIFICATION ====================

-- Verify the fix was applied
SELECT 
  '✅ AFTER FIX' as status,
  email,
  name,
  role,
  status,
  created_at,
  updated_at
FROM user_profiles 
WHERE email = 'warehouse@samastore.com';

-- ==================== SECURITY CHECK ====================

-- Check for any other suspicious admin assignments
SELECT 
  '🚨 OTHER SUSPICIOUS ADMIN USERS' as check_type,
  email,
  name,
  role,
  status,
  CASE 
    WHEN email LIKE '%warehouse%' OR name LIKE '%warehouse%' THEN '🚨 SUSPICIOUS'
    WHEN email LIKE '%admin%' OR email LIKE '%owner%' OR email LIKE '%sama%' THEN '✅ LEGITIMATE'
    ELSE '❓ REVIEW NEEDED'
  END as assessment
FROM user_profiles 
WHERE role = 'admin'
ORDER BY email;

-- ==================== ROLE DISTRIBUTION ====================

-- Show current role distribution
SELECT 
  '📊 ROLE DISTRIBUTION' as info_type,
  role,
  COUNT(*) as user_count,
  STRING_AGG(email, ', ') as users
FROM user_profiles 
GROUP BY role
ORDER BY role;

-- ==================== SUCCESS MESSAGE ====================

DO $$
DECLARE
  warehouse_user_role TEXT;
  fix_applied BOOLEAN := FALSE;
BEGIN
  -- Check if the fix was successful
  SELECT role INTO warehouse_user_role
  FROM user_profiles 
  WHERE email = 'warehouse@samastore.com';
  
  IF warehouse_user_role = 'warehouseManager' THEN
    fix_applied := TRUE;
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '🔧 WAREHOUSE USER ROLE FIX RESULTS:';
  RAISE NOTICE '================================';
  
  IF fix_applied THEN
    RAISE NOTICE '✅ SUCCESS: warehouse@samastore.com role fixed';
    RAISE NOTICE '   Old role: admin';
    RAISE NOTICE '   New role: warehouseManager';
    RAISE NOTICE '   User will now be routed to warehouse manager dashboard';
    RAISE NOTICE '   User will have appropriate warehouse management permissions';
  ELSE
    RAISE NOTICE '❌ FAILED: Role was not updated';
    RAISE NOTICE '   Current role: %', warehouse_user_role;
    RAISE NOTICE '   Manual intervention may be required';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '📋 NEXT STEPS:';
  RAISE NOTICE '1. Test login with warehouse@samastore.com';
  RAISE NOTICE '2. Verify user is routed to warehouse manager dashboard';
  RAISE NOTICE '3. Confirm user has warehouse permissions only (not admin)';
  RAISE NOTICE '4. Monitor for any other incorrect role assignments';
  RAISE NOTICE '';
END $$;
