-- 🔧 SIMPLE ROLE CORRECTION - NO DEPENDENCIES
-- Fix hima@sama.com role from warehouseManager to accountant

-- ==================== CURRENT STATE CHECK ====================

-- Show current user state
SELECT 
  '🔍 BEFORE CORRECTION' as status,
  id,
  email,
  name,
  role,
  status,
  updated_at
FROM user_profiles 
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';

-- ==================== AUDIT LOG (CONSOLE) ====================

-- Log the role change for audit purposes
DO $$
DECLARE
  user_record RECORD;
BEGIN
  -- Get current user data for logging
  SELECT * INTO user_record 
  FROM user_profiles 
  WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';
  
  IF user_record.id IS NOT NULL THEN
    RAISE NOTICE '';
    RAISE NOTICE '📋 ROLE CHANGE AUDIT LOG:';
    RAISE NOTICE '========================';
    RAISE NOTICE 'Timestamp: %', NOW();
    RAISE NOTICE 'User ID: %', user_record.id;
    RAISE NOTICE 'Email: %', user_record.email;
    RAISE NOTICE 'Name: %', user_record.name;
    RAISE NOTICE 'Current Role: %', user_record.role;
    RAISE NOTICE 'Target Role: accountant';
    RAISE NOTICE 'Reason: Correcting incorrect warehouseManager assignment';
    RAISE NOTICE 'Status: %', user_record.status;
    RAISE NOTICE '========================';
    RAISE NOTICE '';
  ELSE
    RAISE NOTICE '❌ ERROR: User not found with ID 4ac083bc-3e05-4456-8579-0877d2627b15';
    RAISE NOTICE 'Cannot proceed with role correction';
  END IF;
END $$;

-- ==================== APPLY ROLE CORRECTION ====================

-- Change role from warehouseManager to accountant
UPDATE user_profiles 
SET 
  role = 'accountant',
  updated_at = NOW()
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15'
  AND role = 'warehouseManager';

-- Log the result
DO $$
DECLARE
  affected_rows INTEGER;
BEGIN
  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  
  RAISE NOTICE '';
  RAISE NOTICE '🔧 ROLE CORRECTION RESULT:';
  RAISE NOTICE '=========================';
  
  IF affected_rows = 1 THEN
    RAISE NOTICE '✅ SUCCESS: Role changed from warehouseManager to accountant';
    RAISE NOTICE '   User: hima@sama.com';
    RAISE NOTICE '   ID: 4ac083bc-3e05-4456-8579-0877d2627b15';
    RAISE NOTICE '   Timestamp: %', NOW();
  ELSIF affected_rows = 0 THEN
    RAISE NOTICE '⚠️ NO CHANGES: User may already have accountant role or not exist';
    RAISE NOTICE '   Check user exists and currently has warehouseManager role';
  ELSE
    RAISE NOTICE '🚨 UNEXPECTED: % rows affected (should be 1)', affected_rows;
  END IF;
  RAISE NOTICE '';
END $$;

-- ==================== VERIFICATION ====================

-- Show corrected user state
SELECT 
  '✅ AFTER CORRECTION' as status,
  id,
  email,
  name,
  role,
  status,
  updated_at
FROM user_profiles 
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';

-- ==================== PERMISSION TEST ====================

-- Test that accountant role has proper permissions
DO $$
DECLARE
  user_id UUID := '4ac083bc-3e05-4456-8579-0877d2627b15';
  user_record RECORD;
  warehouse_requests_access BOOLEAN;
  accounting_access BOOLEAN;
BEGIN
  -- Get user details
  SELECT * INTO user_record FROM user_profiles WHERE id = user_id;
  
  -- Test warehouse requests access (should work for accountant)
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_profiles.id = user_id
      AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
      AND user_profiles.status = 'approved'
  ) INTO warehouse_requests_access;
  
  -- Test general accounting access
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_profiles.id = user_id
      AND user_profiles.role IN ('admin', 'owner', 'accountant')
      AND user_profiles.status = 'approved'
  ) INTO accounting_access;
  
  RAISE NOTICE '';
  RAISE NOTICE '🧪 PERMISSION VERIFICATION:';
  RAISE NOTICE '===========================';
  RAISE NOTICE 'User: % (%)', user_record.email, user_record.role;
  RAISE NOTICE 'Status: %', user_record.status;
  RAISE NOTICE '';
  RAISE NOTICE 'Access Tests:';
  RAISE NOTICE '  Warehouse Requests: %', 
    CASE WHEN warehouse_requests_access THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
  RAISE NOTICE '  Accounting Functions: %', 
    CASE WHEN accounting_access THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
  RAISE NOTICE '';
  
  IF user_record.role = 'accountant' THEN
    RAISE NOTICE '✅ ROLE CORRECTION SUCCESSFUL';
    RAISE NOTICE '📋 User now has appropriate accountant permissions';
    RAISE NOTICE '🔒 Warehouse management access removed';
  ELSE
    RAISE NOTICE '❌ ROLE CORRECTION FAILED';
    RAISE NOTICE '   Current role: %', user_record.role;
    RAISE NOTICE '   Expected role: accountant';
  END IF;
  RAISE NOTICE '';
END $$;

-- ==================== ROLE DISTRIBUTION CHECK ====================

-- Show current role distribution
SELECT 
  '📊 ROLE DISTRIBUTION' as info_type,
  role,
  COUNT(*) as user_count,
  STRING_AGG(email, ', ') as users
FROM user_profiles 
GROUP BY role
ORDER BY role;

-- ==================== FINAL STATUS ====================

DO $$
DECLARE
  user_record RECORD;
  correction_successful BOOLEAN := FALSE;
BEGIN
  -- Final verification
  SELECT * INTO user_record 
  FROM user_profiles 
  WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';
  
  correction_successful := (user_record.role = 'accountant');
  
  RAISE NOTICE '';
  RAISE NOTICE '🎉 ROLE CORRECTION SUMMARY:';
  RAISE NOTICE '==========================';
  
  IF correction_successful THEN
    RAISE NOTICE '✅ SUCCESS: Role correction completed';
    RAISE NOTICE '   Email: %', user_record.email;
    RAISE NOTICE '   Role: % (corrected)', user_record.role;
    RAISE NOTICE '   Status: %', user_record.status;
    RAISE NOTICE '';
    RAISE NOTICE '📋 NEXT STEPS:';
    RAISE NOTICE '1. Test user login and dashboard access';
    RAISE NOTICE '2. Verify accountant functions work properly';
    RAISE NOTICE '3. Confirm no warehouse management access';
    RAISE NOTICE '4. Test dispatch creation with accountant role';
  ELSE
    RAISE NOTICE '❌ FAILED: Role correction unsuccessful';
    RAISE NOTICE '   Current role: %', COALESCE(user_record.role, 'USER NOT FOUND');
    RAISE NOTICE '   Expected role: accountant';
    RAISE NOTICE '   Manual intervention required';
  END IF;
  RAISE NOTICE '';
END $$;
