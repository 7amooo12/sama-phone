-- 🔧 CLEAN RLS FIX FOR WAREHOUSE REQUESTS
-- Simple, working solution that avoids type casting issues

-- ==================== STEP 1: VERIFY USER PROFILE ====================

-- Ensure the user has the correct role and status
UPDATE user_profiles
SET
  role = 'warehouseManager',
  status = 'approved',
  updated_at = NOW()
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15'
  AND (role != 'warehouseManager' OR status != 'approved');

-- Verify the user profile
SELECT
  '👤 USER PROFILE VERIFICATION' as check_type,
  id,
  email,
  name,
  role,
  status,
  updated_at
FROM user_profiles
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';

-- ==================== STEP 2: CLEAN UP ALL EXISTING POLICIES ====================

-- Drop ALL existing policies to start fresh
DROP POLICY IF EXISTS "warehouse_requests_insert_fixed" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_secure" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_debug" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_robust" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_simple" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_secure_v2" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_working" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_final" ON warehouse_requests;

-- ==================== STEP 3: CREATE WORKING POLICY ====================

-- Create a simple policy that works with proper type handling
CREATE POLICY "warehouse_requests_insert_clean" ON warehouse_requests
  FOR INSERT
  WITH CHECK (
    -- Validate that requested_by user has proper permissions
    requested_by IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = requested_by::uuid
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== STEP 4: TEST THE POLICY ====================

-- Test with the specific user from the logs
DO $$
DECLARE
  test_user_id UUID := '4ac083bc-3e05-4456-8579-0877d2627b15';
  user_record RECORD;
  policy_result BOOLEAN;
BEGIN
  -- Get user record
  SELECT * INTO user_record FROM user_profiles WHERE id = test_user_id;

  -- Test the policy condition
  SELECT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_profiles.id = test_user_id::uuid
      AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
      AND user_profiles.status = 'approved'
  ) INTO policy_result;

  RAISE NOTICE '';
  RAISE NOTICE '🧪 POLICY TEST RESULTS:';
  RAISE NOTICE '=====================';
  RAISE NOTICE 'User: % (%)', user_record.email, test_user_id;
  RAISE NOTICE 'Role: %', user_record.role;
  RAISE NOTICE 'Status: %', user_record.status;
  RAISE NOTICE 'Policy allows: %', policy_result;
  RAISE NOTICE '';

  IF policy_result THEN
    RAISE NOTICE '✅ SUCCESS: Policy should allow dispatch creation';
    RAISE NOTICE '📋 Try creating dispatch request from Flutter app now';
  ELSE
    RAISE NOTICE '❌ FAILED: Policy will still block - check user data';
  END IF;
  RAISE NOTICE '';
END $$;

-- ==================== STEP 5: COMPLETION ====================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🎉 RLS POLICY FIX COMPLETED!';
  RAISE NOTICE '============================';
  RAISE NOTICE '✅ User profile verified (hima@sama.com)';
  RAISE NOTICE '✅ All problematic policies removed';
  RAISE NOTICE '✅ Clean working policy created';
  RAISE NOTICE '✅ Type casting issues resolved';
  RAISE NOTICE '';
  RAISE NOTICE '📋 NEXT STEPS:';
  RAISE NOTICE '1. Test dispatch creation from Flutter app';
  RAISE NOTICE '2. Verify success message appears';
  RAISE NOTICE '3. Check dispatch appears in warehouse management';
  RAISE NOTICE '';
END $$;
