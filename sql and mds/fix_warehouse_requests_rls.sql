-- 🔧 FIX WAREHOUSE REQUESTS RLS POLICY
-- Emergency fix for warehouse manager dispatch creation issue

-- ==================== BACKUP CURRENT POLICY ====================

-- Show current policy before fixing
SELECT 
  '📋 CURRENT POLICY BACKUP' as backup_type,
  policyname,
  cmd,
  with_check
FROM pg_policies 
WHERE tablename = 'warehouse_requests' AND cmd = 'INSERT';

-- ==================== DROP AND RECREATE INSERT POLICY ====================

-- Drop the problematic INSERT policy
DROP POLICY IF EXISTS "secure_requests_insert" ON warehouse_requests;

-- Create a more robust INSERT policy with better error handling
CREATE POLICY "warehouse_requests_insert_fixed" ON warehouse_requests
  FOR INSERT
  WITH CHECK (
    -- Ensure user is authenticated
    auth.uid() IS NOT NULL 
    AND
    -- Check user has proper role and status
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
    AND
    -- Ensure requested_by field matches authenticated user
    (requested_by = auth.uid() OR requested_by IS NULL)
  );

-- ==================== VERIFY THE FIX ====================

-- Test the new policy
DO $$
DECLARE
  current_user_id UUID;
  user_role TEXT;
  user_status TEXT;
  policy_test_result BOOLEAN;
BEGIN
  -- Get current user
  SELECT auth.uid() INTO current_user_id;
  
  IF current_user_id IS NOT NULL THEN
    -- Get user details
    SELECT role, status INTO user_role, user_status
    FROM user_profiles 
    WHERE id = current_user_id;
    
    -- Test the new policy condition
    SELECT (
      current_user_id IS NOT NULL 
      AND
      EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE user_profiles.id = current_user_id
          AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
          AND user_profiles.status = 'approved'
      )
    ) INTO policy_test_result;
    
    RAISE NOTICE '🧪 NEW POLICY TEST:';
    RAISE NOTICE '   User ID: %', current_user_id;
    RAISE NOTICE '   User Role: %', user_role;
    RAISE NOTICE '   User Status: %', user_status;
    RAISE NOTICE '   Policy Result: %', 
      CASE WHEN policy_test_result THEN '✅ SHOULD ALLOW' ELSE '❌ WILL BLOCK' END;
      
  ELSE
    RAISE NOTICE '❌ No authenticated user for testing';
  END IF;
END $$;

-- ==================== ALTERNATIVE: TEMPORARY PERMISSIVE POLICY ====================

-- If the above doesn't work, create a temporary more permissive policy for debugging
-- (Uncomment if needed)

/*
-- Drop the fixed policy if it's still not working
DROP POLICY IF EXISTS "warehouse_requests_insert_fixed" ON warehouse_requests;

-- Create a temporary very permissive policy for debugging
CREATE POLICY "warehouse_requests_insert_debug" ON warehouse_requests
  FOR INSERT
  WITH CHECK (
    -- Only require authentication, no role check for now
    auth.uid() IS NOT NULL
  );

-- Log the temporary fix
DO $$
BEGIN
  RAISE NOTICE '⚠️ TEMPORARY DEBUG POLICY APPLIED';
  RAISE NOTICE '🔓 This policy only requires authentication';
  RAISE NOTICE '📋 Use this to test if the issue is with role checking';
  RAISE NOTICE '🔒 Remember to restore proper security after testing';
END $$;
*/

-- ==================== VERIFY ALL POLICIES ====================

-- Show all current policies for warehouse_requests
SELECT 
  '✅ FINAL POLICY VERIFICATION' as verification_type,
  policyname,
  cmd,
  permissive,
  CASE 
    WHEN with_check LIKE '%auth.uid()%' THEN '✅ HAS AUTH CHECK'
    ELSE '❌ NO AUTH CHECK'
  END as auth_check,
  CASE 
    WHEN with_check LIKE '%user_profiles%' THEN '✅ HAS ROLE CHECK'
    ELSE '❌ NO ROLE CHECK'
  END as role_check
FROM pg_policies 
WHERE tablename = 'warehouse_requests'
ORDER BY cmd, policyname;

-- ==================== INSTRUCTIONS ====================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '📋 NEXT STEPS:';
  RAISE NOTICE '1. Test warehouse dispatch creation again';
  RAISE NOTICE '2. If still failing, uncomment the debug policy above';
  RAISE NOTICE '3. Check application logs for any other RLS errors';
  RAISE NOTICE '4. Verify the requested_by field is being set correctly';
  RAISE NOTICE '5. Ensure warehouse manager user has approved status';
  RAISE NOTICE '';
  RAISE NOTICE '🔍 If issue persists, the problem might be:';
  RAISE NOTICE '   - Application not setting requested_by = auth.uid()';
  RAISE NOTICE '   - User profile role/status mismatch';
  RAISE NOTICE '   - Missing required fields in INSERT statement';
  RAISE NOTICE '';
END $$;
