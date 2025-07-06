-- 🔍 DEBUG RLS POLICY VIOLATION FOR WAREHOUSE DISPATCH
-- Investigating why user 4ac083bc-3e05-4456-8579-0877d2627b15 cannot create dispatch requests

-- ==================== USER PROFILE VERIFICATION ====================

-- Check the specific user's profile and permissions
SELECT 
  '👤 USER PROFILE CHECK' as check_type,
  id,
  email,
  name,
  role,
  status,
  created_at,
  updated_at
FROM user_profiles 
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';

-- Check if this is the warehouse@samastore.com user we just fixed
SELECT 
  '🔍 EMAIL VERIFICATION' as check_type,
  id,
  email,
  role,
  status,
  CASE 
    WHEN email = 'warehouse@samastore.com' THEN '✅ WAREHOUSE USER'
    ELSE '❓ OTHER USER'
  END as user_type
FROM user_profiles 
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';

-- ==================== RLS POLICY ANALYSIS ====================

-- Check current RLS policies for warehouse_requests table
SELECT 
  '🛡️ CURRENT RLS POLICIES' as policy_check,
  policyname,
  cmd,
  permissive,
  roles,
  with_check,
  qual
FROM pg_policies 
WHERE tablename = 'warehouse_requests' AND cmd = 'INSERT'
ORDER BY policyname;

-- ==================== POLICY CONDITION TESTING ====================

-- Test the specific policy condition against our user
DO $$
DECLARE
  user_id UUID := '4ac083bc-3e05-4456-8579-0877d2627b15';
  user_role TEXT;
  user_status TEXT;
  user_email TEXT;
  auth_check BOOLEAN;
  role_check BOOLEAN;
  status_check BOOLEAN;
  overall_check BOOLEAN;
BEGIN
  -- Get user details
  SELECT role, status, email INTO user_role, user_status, user_email
  FROM user_profiles 
  WHERE id = user_id;
  
  -- Test individual policy conditions
  
  -- 1. Authentication check (simulating auth.uid())
  auth_check := (user_id IS NOT NULL);
  
  -- 2. Role check
  role_check := (user_role IN ('admin', 'owner', 'accountant', 'warehouseManager'));
  
  -- 3. Status check
  status_check := (user_status = 'approved');
  
  -- 4. Overall policy check
  overall_check := (
    auth_check AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = user_id
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );
  
  RAISE NOTICE '';
  RAISE NOTICE '🧪 POLICY CONDITION TESTING:';
  RAISE NOTICE '================================';
  RAISE NOTICE 'User ID: %', user_id;
  RAISE NOTICE 'Email: %', user_email;
  RAISE NOTICE 'Role: %', user_role;
  RAISE NOTICE 'Status: %', user_status;
  RAISE NOTICE '';
  RAISE NOTICE 'Policy Condition Tests:';
  RAISE NOTICE '1. Auth Check (user_id IS NOT NULL): %', auth_check;
  RAISE NOTICE '2. Role Check (role in allowed list): %', role_check;
  RAISE NOTICE '3. Status Check (status = approved): %', status_check;
  RAISE NOTICE '4. Overall Policy Check: %', overall_check;
  RAISE NOTICE '';
  
  IF NOT overall_check THEN
    RAISE NOTICE '🚨 POLICY VIOLATION REASONS:';
    IF NOT auth_check THEN
      RAISE NOTICE '   ❌ Authentication failed';
    END IF;
    IF NOT role_check THEN
      RAISE NOTICE '   ❌ Role not in allowed list: % (allowed: admin, owner, accountant, warehouseManager)', user_role;
    END IF;
    IF NOT status_check THEN
      RAISE NOTICE '   ❌ Status not approved: %', user_status;
    END IF;
  ELSE
    RAISE NOTICE '✅ Policy should allow this user - investigating other issues';
  END IF;
  RAISE NOTICE '';
END $$;

-- ==================== AUTH.UID() SIMULATION TEST ====================

-- Test what happens when we simulate the actual INSERT with auth context
DO $$
DECLARE
  test_user_id UUID := '4ac083bc-3e05-4456-8579-0877d2627b15';
  policy_result BOOLEAN;
BEGIN
  -- Simulate the exact policy condition from warehouse_requests_insert_fixed
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_profiles.id = test_user_id  -- This simulates auth.uid()
      AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
      AND user_profiles.status = 'approved'
  ) INTO policy_result;
  
  RAISE NOTICE '🔐 AUTH.UID() SIMULATION TEST:';
  RAISE NOTICE 'Simulating auth.uid() = %', test_user_id;
  RAISE NOTICE 'Policy result: %', policy_result;
  
  IF policy_result THEN
    RAISE NOTICE '✅ Policy should allow INSERT - RLS issue may be elsewhere';
  ELSE
    RAISE NOTICE '❌ Policy correctly blocks INSERT - user does not meet requirements';
  END IF;
  RAISE NOTICE '';
END $$;

-- ==================== REQUESTED_BY FIELD ANALYSIS ====================

-- Test the requested_by condition from the policy
DO $$
DECLARE
  test_user_id UUID := '4ac083bc-3e05-4456-8579-0877d2627b15';
  requested_by_check BOOLEAN;
BEGIN
  -- Test the requested_by condition: (requested_by = auth.uid() OR requested_by IS NULL)
  -- From the logs: requested_by: 4ac083bc-3e05-4456-8579-0877d2627b15
  
  requested_by_check := (test_user_id = test_user_id OR test_user_id IS NULL);
  
  RAISE NOTICE '📋 REQUESTED_BY FIELD TEST:';
  RAISE NOTICE 'requested_by value: %', test_user_id;
  RAISE NOTICE 'auth.uid() simulation: %', test_user_id;
  RAISE NOTICE 'Condition (requested_by = auth.uid() OR requested_by IS NULL): %', requested_by_check;
  RAISE NOTICE '';
END $$;

-- ==================== POLICY DEBUGGING ====================

-- Check if there are multiple conflicting policies
SELECT 
  '⚠️ POLICY CONFLICTS CHECK' as conflict_check,
  COUNT(*) as insert_policy_count,
  STRING_AGG(policyname, ', ') as policy_names
FROM pg_policies 
WHERE tablename = 'warehouse_requests' AND cmd = 'INSERT';

-- Check if RLS is enabled on the table
SELECT 
  '🔒 RLS STATUS CHECK' as rls_check,
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'warehouse_requests';

-- ==================== ALTERNATIVE POLICY TEST ====================

-- Create a temporary more permissive policy for testing
-- (This will help us isolate the issue)

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🧪 CREATING TEMPORARY DEBUG POLICY:';
  RAISE NOTICE 'This will help isolate the RLS issue';
  RAISE NOTICE '';
END $$;

-- Drop existing policy temporarily
DROP POLICY IF EXISTS "warehouse_requests_insert_fixed" ON warehouse_requests;

-- Create a very permissive debug policy
CREATE POLICY "warehouse_requests_insert_debug" ON warehouse_requests
  FOR INSERT
  WITH CHECK (
    -- Only require authentication, no role/status checks
    auth.uid() IS NOT NULL
  );

-- Test the debug policy
DO $$
DECLARE
  test_user_id UUID := '4ac083bc-3e05-4456-8579-0877d2627b15';
  debug_policy_result BOOLEAN;
BEGIN
  -- Test the debug policy condition
  debug_policy_result := (test_user_id IS NOT NULL);
  
  RAISE NOTICE '🔧 DEBUG POLICY TEST:';
  RAISE NOTICE 'Debug policy condition (auth.uid() IS NOT NULL): %', debug_policy_result;
  
  IF debug_policy_result THEN
    RAISE NOTICE '✅ Debug policy should allow INSERT';
    RAISE NOTICE '📋 Try creating dispatch request now to test';
  ELSE
    RAISE NOTICE '❌ Even debug policy fails - authentication issue';
  END IF;
  RAISE NOTICE '';
END $$;

-- ==================== INSTRUCTIONS ====================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '📋 DEBUGGING INSTRUCTIONS:';
  RAISE NOTICE '========================';
  RAISE NOTICE '1. Review the test results above';
  RAISE NOTICE '2. Try creating a dispatch request with the debug policy';
  RAISE NOTICE '3. If debug policy works, the issue is in role/status checks';
  RAISE NOTICE '4. If debug policy fails, the issue is with auth.uid()';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️ IMPORTANT:';
  RAISE NOTICE 'The debug policy is TEMPORARY and INSECURE';
  RAISE NOTICE 'It must be replaced with proper security after testing';
  RAISE NOTICE '';
  RAISE NOTICE '🔄 TO RESTORE SECURE POLICY:';
  RAISE NOTICE 'Run the restore_secure_rls_policy.sql script after testing';
  RAISE NOTICE '';
END $$;
