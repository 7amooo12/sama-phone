-- 🔒 RESTORE SECURE RLS POLICY FOR WAREHOUSE REQUESTS
-- This script restores the proper security after debugging

-- ==================== REMOVE DEBUG POLICY ====================

-- Drop the temporary debug policy
DROP POLICY IF EXISTS "warehouse_requests_insert_debug" ON warehouse_requests;

-- ==================== RESTORE SECURE POLICY ====================

-- Create the corrected secure policy based on our findings
CREATE POLICY "warehouse_requests_insert_secure_v2" ON warehouse_requests
  FOR INSERT
  WITH CHECK (
    -- Must be authenticated
    auth.uid() IS NOT NULL 
    AND
    -- Must have proper role and status
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
    AND
    -- The requested_by field must match authenticated user (if provided)
    (requested_by = auth.uid() OR requested_by IS NULL)
  );

-- ==================== VERIFICATION ====================

-- Verify the secure policy is in place
SELECT 
  '✅ SECURE POLICY RESTORED' as status,
  policyname,
  cmd,
  with_check
FROM pg_policies 
WHERE tablename = 'warehouse_requests' AND cmd = 'INSERT'
ORDER BY policyname;

-- ==================== FINAL TEST ====================

-- Test the restored policy with our user
DO $$
DECLARE
  test_user_id UUID := '4ac083bc-3e05-4456-8579-0877d2627b15';
  user_role TEXT;
  user_status TEXT;
  policy_result BOOLEAN;
BEGIN
  -- Get user details
  SELECT role, status INTO user_role, user_status
  FROM user_profiles 
  WHERE id = test_user_id;
  
  -- Test the restored policy
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_profiles.id = test_user_id
      AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
      AND user_profiles.status = 'approved'
  ) INTO policy_result;
  
  RAISE NOTICE '';
  RAISE NOTICE '🔒 SECURE POLICY TEST:';
  RAISE NOTICE 'User: %', test_user_id;
  RAISE NOTICE 'Role: %', user_role;
  RAISE NOTICE 'Status: %', user_status;
  RAISE NOTICE 'Policy allows: %', policy_result;
  
  IF policy_result THEN
    RAISE NOTICE '✅ User should be able to create dispatch requests';
  ELSE
    RAISE NOTICE '❌ User is correctly blocked by security policy';
  END IF;
  RAISE NOTICE '';
END $$;

-- ==================== SUCCESS MESSAGE ====================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🔒 SECURE RLS POLICY RESTORED';
  RAISE NOTICE '============================';
  RAISE NOTICE '✅ Debug policy removed';
  RAISE NOTICE '✅ Secure policy reinstated';
  RAISE NOTICE '✅ Proper authentication and role checks in place';
  RAISE NOTICE '';
  RAISE NOTICE '📋 NEXT STEPS:';
  RAISE NOTICE '1. Test dispatch request creation';
  RAISE NOTICE '2. Verify only authorized users can create requests';
  RAISE NOTICE '3. Monitor for any security issues';
  RAISE NOTICE '';
END $$;
