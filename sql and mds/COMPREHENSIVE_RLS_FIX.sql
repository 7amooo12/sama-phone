-- 🔧 COMPREHENSIVE RLS FIX FOR WAREHOUSE REQUESTS
-- Fix the RLS policy issue preventing warehouse managers from creating dispatch requests

-- ==================== DIAGNOSIS FIRST ====================

-- Check current user and their permissions
DO $$
DECLARE
  current_user_id UUID;
  user_email TEXT;
  user_role TEXT;
  user_status TEXT;
BEGIN
  SELECT auth.uid() INTO current_user_id;
  
  IF current_user_id IS NOT NULL THEN
    SELECT email, role, status INTO user_email, user_role, user_status
    FROM user_profiles 
    WHERE id = current_user_id;
    
    RAISE NOTICE '🔍 CURRENT USER DIAGNOSIS:';
    RAISE NOTICE '   User ID: %', current_user_id;
    RAISE NOTICE '   Email: %', user_email;
    RAISE NOTICE '   Role: %', user_role;
    RAISE NOTICE '   Status: %', user_status;
    
    -- Check if user should have access
    IF user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND user_status = 'approved' THEN
      RAISE NOTICE '   ✅ User SHOULD have warehouse request access';
    ELSE
      RAISE NOTICE '   ❌ User should NOT have access - Role: % Status: %', user_role, user_status;
    END IF;
  ELSE
    RAISE NOTICE '❌ No authenticated user found';
  END IF;
END $$;

-- ==================== FIX THE RLS POLICY ====================

-- Drop the current problematic policy
DROP POLICY IF EXISTS "secure_requests_insert" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_fixed" ON warehouse_requests;

-- Create a new, more robust INSERT policy
CREATE POLICY "warehouse_requests_insert_secure" ON warehouse_requests
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
    -- The requested_by field must match the authenticated user (if provided)
    -- OR be NULL (will be set by trigger or application)
    (requested_by = auth.uid() OR requested_by IS NULL)
  );

-- ==================== CREATE TRIGGER TO AUTO-SET REQUESTED_BY ====================

-- Create a trigger function to automatically set requested_by to auth.uid()
CREATE OR REPLACE FUNCTION set_requested_by_trigger()
RETURNS TRIGGER AS $$
BEGIN
  -- If requested_by is not set, set it to the current authenticated user
  IF NEW.requested_by IS NULL THEN
    NEW.requested_by := auth.uid();
  END IF;
  
  -- Ensure the requested_by matches the authenticated user (security check)
  IF NEW.requested_by != auth.uid() THEN
    RAISE EXCEPTION 'requested_by must match authenticated user';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS warehouse_requests_set_requested_by ON warehouse_requests;

-- Create the trigger
CREATE TRIGGER warehouse_requests_set_requested_by
  BEFORE INSERT ON warehouse_requests
  FOR EACH ROW
  EXECUTE FUNCTION set_requested_by_trigger();

-- ==================== ALTERNATIVE: MORE PERMISSIVE POLICY ====================

-- If the above still doesn't work, we can create a more permissive policy
-- that only checks authentication and role, without the requested_by constraint

-- Drop the strict policy
-- DROP POLICY IF EXISTS "warehouse_requests_insert_secure" ON warehouse_requests;

-- Create permissive policy (uncomment if needed)
/*
CREATE POLICY "warehouse_requests_insert_permissive" ON warehouse_requests
  FOR INSERT
  WITH CHECK (
    -- Only require authentication and proper role
    auth.uid() IS NOT NULL 
    AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );
*/

-- ==================== TEST THE FIX ====================

-- Test the new policy
DO $$
DECLARE
  current_user_id UUID;
  test_result BOOLEAN;
BEGIN
  SELECT auth.uid() INTO current_user_id;
  
  IF current_user_id IS NOT NULL THEN
    -- Test if the policy would allow insertion
    SELECT EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = current_user_id
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    ) INTO test_result;
    
    RAISE NOTICE '🧪 POLICY TEST RESULT: %', 
      CASE WHEN test_result THEN '✅ SHOULD ALLOW INSERT' ELSE '❌ WILL BLOCK INSERT' END;
  END IF;
END $$;

-- ==================== VERIFY ALL POLICIES ====================

-- Show all current policies for warehouse_requests
SELECT 
  '📋 CURRENT WAREHOUSE_REQUESTS POLICIES' as policy_check,
  policyname,
  cmd,
  permissive,
  CASE 
    WHEN with_check LIKE '%auth.uid()%' THEN '✅ AUTH'
    WHEN qual LIKE '%auth.uid()%' THEN '✅ AUTH'
    ELSE '❌ NO AUTH'
  END as has_auth,
  CASE 
    WHEN with_check LIKE '%user_profiles%' THEN '✅ ROLE'
    WHEN qual LIKE '%user_profiles%' THEN '✅ ROLE'
    ELSE '❌ NO ROLE'
  END as has_role_check
FROM pg_policies 
WHERE tablename = 'warehouse_requests'
ORDER BY cmd, policyname;

-- ==================== INSTRUCTIONS ====================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '📋 NEXT STEPS TO TEST:';
  RAISE NOTICE '1. Try creating a warehouse dispatch request again';
  RAISE NOTICE '2. If it still fails, check the application logs for the exact error';
  RAISE NOTICE '3. Verify that the Flutter app is passing the correct requestedBy value';
  RAISE NOTICE '4. The trigger will automatically set requested_by = auth.uid()';
  RAISE NOTICE '';
  RAISE NOTICE '🔍 IF STILL FAILING:';
  RAISE NOTICE '1. Uncomment the permissive policy above';
  RAISE NOTICE '2. Check if the issue is in the application code';
  RAISE NOTICE '3. Verify the user has warehouseManager role and approved status';
  RAISE NOTICE '';
  RAISE NOTICE '🔒 SECURITY NOTE:';
  RAISE NOTICE 'The trigger ensures requested_by always matches auth.uid()';
  RAISE NOTICE 'This prevents users from creating requests on behalf of others';
  RAISE NOTICE '';
END $$;
