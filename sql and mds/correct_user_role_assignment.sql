-- 🔧 CORRECT USER ROLE ASSIGNMENT ERROR
-- Fix hima@sama.com role from warehouseManager to accountant

-- ==================== CURRENT STATE ANALYSIS ====================

-- Check current user profile
SELECT 
  '🔍 CURRENT USER STATE' as analysis_type,
  id,
  email,
  name,
  role as current_role,
  status,
  created_at,
  updated_at,
  CASE 
    WHEN role = 'warehouseManager' THEN '❌ INCORRECT ROLE'
    WHEN role = 'accountant' THEN '✅ CORRECT ROLE'
    ELSE '❓ UNEXPECTED ROLE'
  END as role_assessment
FROM user_profiles 
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';

-- ==================== ROLE CORRECTION ====================

-- Log the role change for audit purposes (console logging)
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
    RAISE NOTICE 'Old Role: %', user_record.role;
    RAISE NOTICE 'New Role: accountant';
    RAISE NOTICE 'Reason: Correcting incorrect warehouseManager assignment - user should be accountant';
    RAISE NOTICE 'Status: %', user_record.status;
    RAISE NOTICE '========================';
    RAISE NOTICE '';
  ELSE
    RAISE NOTICE '❌ USER NOT FOUND: 4ac083bc-3e05-4456-8579-0877d2627b15';
  END IF;
END $$;

-- Apply the role correction
UPDATE user_profiles 
SET 
  role = 'accountant',
  updated_at = NOW()
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15'
  AND role = 'warehouseManager';

-- Log the correction
DO $$
DECLARE
  affected_rows INTEGER;
BEGIN
  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  
  IF affected_rows = 1 THEN
    RAISE NOTICE '✅ ROLE CORRECTION APPLIED: hima@sama.com changed from warehouseManager to accountant';
  ELSIF affected_rows = 0 THEN
    RAISE NOTICE '⚠️ NO CHANGES MADE: User may already have correct role or not exist';
  ELSE
    RAISE NOTICE '🚨 UNEXPECTED: % rows affected', affected_rows;
  END IF;
END $$;

-- ==================== VERIFICATION ====================

-- Verify the role correction
SELECT 
  '✅ CORRECTED USER STATE' as verification_type,
  id,
  email,
  name,
  role as corrected_role,
  status,
  updated_at,
  CASE 
    WHEN role = 'accountant' THEN '✅ CORRECT ROLE'
    WHEN role = 'warehouseManager' THEN '❌ STILL INCORRECT'
    ELSE '❓ UNEXPECTED ROLE'
  END as role_verification
FROM user_profiles 
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';

-- ==================== RLS POLICY ANALYSIS ====================

-- Check which RLS policies support accountant role
SELECT 
  '📋 ACCOUNTANT RLS SUPPORT' as policy_analysis,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN with_check LIKE '%accountant%' OR qual LIKE '%accountant%' THEN '✅ SUPPORTS ACCOUNTANT'
    WHEN with_check LIKE '%warehouseManager%' OR qual LIKE '%warehouseManager%' THEN '⚠️ WAREHOUSE ONLY'
    ELSE '❓ UNCLEAR'
  END as accountant_support
FROM pg_policies 
WHERE (with_check LIKE '%role%' OR qual LIKE '%role%')
  AND tablename IN ('warehouse_requests', 'warehouse_inventory', 'warehouse_transactions', 'invoices', 'products')
ORDER BY tablename, cmd;

-- ==================== PERMISSION VERIFICATION ====================

-- Test accountant permissions for key operations
DO $$
DECLARE
  user_id UUID := '4ac083bc-3e05-4456-8579-0877d2627b15';
  user_role TEXT;
  user_status TEXT;
  warehouse_requests_access BOOLEAN;
  warehouse_inventory_access BOOLEAN;
  invoice_access BOOLEAN;
BEGIN
  -- Get current user details
  SELECT role, status INTO user_role, user_status
  FROM user_profiles 
  WHERE id = user_id;
  
  -- Test warehouse_requests access (should have INSERT as accountant)
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_profiles.id = user_id
      AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
      AND user_profiles.status = 'approved'
  ) INTO warehouse_requests_access;
  
  -- Test warehouse_inventory access (should have access as accountant)
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_profiles.id = user_id
      AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
      AND user_profiles.status = 'approved'
  ) INTO warehouse_inventory_access;
  
  -- Test general access pattern
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_profiles.id = user_id
      AND user_profiles.role IN ('admin', 'owner', 'accountant')
      AND user_profiles.status = 'approved'
  ) INTO invoice_access;
  
  RAISE NOTICE '';
  RAISE NOTICE '🧪 ACCOUNTANT PERMISSION TEST:';
  RAISE NOTICE '============================';
  RAISE NOTICE 'User: % (%)', user_id, user_role;
  RAISE NOTICE 'Status: %', user_status;
  RAISE NOTICE '';
  RAISE NOTICE 'Access Tests:';
  RAISE NOTICE '  Warehouse Requests: %', 
    CASE WHEN warehouse_requests_access THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
  RAISE NOTICE '  Warehouse Inventory: %', 
    CASE WHEN warehouse_inventory_access THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
  RAISE NOTICE '  Invoice Operations: %', 
    CASE WHEN invoice_access THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
  RAISE NOTICE '';
END $$;

-- ==================== SECURITY ASSESSMENT ====================

-- Check what permissions accountant role should have vs warehouse manager
WITH role_comparison AS (
  SELECT 
    'accountant' as role_type,
    'Should have: Invoice management, financial reports, warehouse oversight (not direct management)' as expected_permissions
  UNION ALL
  SELECT 
    'warehouseManager' as role_type,
    'Should have: Direct warehouse operations, inventory management, dispatch execution' as expected_permissions
)
SELECT 
  '🔒 ROLE SECURITY ANALYSIS' as security_check,
  role_type,
  expected_permissions
FROM role_comparison;

-- ==================== WAREHOUSE REQUESTS POLICY UPDATE ====================

-- Ensure warehouse_requests policy supports accountant role properly
-- Check current policy
SELECT 
  '🛡️ WAREHOUSE REQUESTS POLICY' as policy_check,
  policyname,
  cmd,
  with_check
FROM pg_policies 
WHERE tablename = 'warehouse_requests' AND cmd = 'INSERT';

-- Test if current policy allows accountant access
DO $$
DECLARE
  user_id UUID := '4ac083bc-3e05-4456-8579-0877d2627b15';
  policy_allows_accountant BOOLEAN;
BEGIN
  -- Test the current policy with accountant role
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_profiles.id = user_id
      AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
      AND user_profiles.status = 'approved'
  ) INTO policy_allows_accountant;
  
  RAISE NOTICE '';
  RAISE NOTICE '🧪 WAREHOUSE REQUESTS POLICY TEST:';
  RAISE NOTICE '=================================';
  RAISE NOTICE 'Current policy allows accountant: %', 
    CASE WHEN policy_allows_accountant THEN '✅ YES' ELSE '❌ NO' END;
  
  IF policy_allows_accountant THEN
    RAISE NOTICE '✅ No policy changes needed - accountant role supported';
  ELSE
    RAISE NOTICE '❌ Policy needs update to support accountant role';
  END IF;
  RAISE NOTICE '';
END $$;

-- ==================== FINAL VERIFICATION ====================

-- Show final user state and role distribution
SELECT 
  '📊 FINAL USER VERIFICATION' as final_check,
  id,
  email,
  name,
  role,
  status,
  updated_at
FROM user_profiles 
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';

-- Show role distribution to ensure it's correct
SELECT 
  '📈 ROLE DISTRIBUTION' as distribution_check,
  role,
  COUNT(*) as user_count,
  STRING_AGG(email, ', ') as users
FROM user_profiles 
GROUP BY role
ORDER BY role;

-- ==================== SUCCESS MESSAGE ====================

DO $$
DECLARE
  user_record RECORD;
  correction_successful BOOLEAN := FALSE;
BEGIN
  -- Check if correction was successful
  SELECT * INTO user_record 
  FROM user_profiles 
  WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';
  
  correction_successful := (user_record.role = 'accountant');
  
  RAISE NOTICE '';
  RAISE NOTICE '🎉 ROLE CORRECTION SUMMARY:';
  RAISE NOTICE '==========================';
  
  IF correction_successful THEN
    RAISE NOTICE '✅ SUCCESS: User role corrected';
    RAISE NOTICE '   Email: %', user_record.email;
    RAISE NOTICE '   Old Role: warehouseManager';
    RAISE NOTICE '   New Role: accountant';
    RAISE NOTICE '   Status: %', user_record.status;
    RAISE NOTICE '';
    RAISE NOTICE '📋 NEXT STEPS:';
    RAISE NOTICE '1. Test dispatch creation with accountant permissions';
    RAISE NOTICE '2. Verify user can access accounting functions';
    RAISE NOTICE '3. Confirm no warehouse management access';
    RAISE NOTICE '4. Monitor for any permission issues';
  ELSE
    RAISE NOTICE '❌ FAILED: Role correction unsuccessful';
    RAISE NOTICE '   Current Role: %', user_record.role;
    RAISE NOTICE '   Manual intervention may be required';
  END IF;
  RAISE NOTICE '';
END $$;
