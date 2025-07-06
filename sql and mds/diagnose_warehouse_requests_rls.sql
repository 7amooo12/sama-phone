-- 🔍 DIAGNOSE WAREHOUSE REQUESTS RLS POLICY ISSUE
-- Check why warehouse manager cannot create dispatch requests

-- 1. Check current RLS policies for warehouse_requests
SELECT 
  '🔍 WAREHOUSE_REQUESTS POLICIES' as check_type,
  policyname,
  cmd,
  qual as using_condition,
  with_check as with_check_condition
FROM pg_policies 
WHERE tablename = 'warehouse_requests'
ORDER BY cmd, policyname;

-- 2. Check current user authentication and role
SELECT 
  '👤 CURRENT USER CHECK' as check_type,
  auth.uid() as user_id,
  CASE 
    WHEN auth.uid() IS NULL THEN '❌ NOT AUTHENTICATED'
    ELSE '✅ AUTHENTICATED'
  END as auth_status;

-- 3. Check user profile and role
SELECT 
  '📋 USER PROFILE CHECK' as check_type,
  up.id,
  up.email,
  up.name,
  up.role,
  up.status,
  CASE 
    WHEN up.role = 'warehouseManager' AND up.status = 'approved' 
    THEN '✅ SHOULD HAVE WAREHOUSE ACCESS'
    ELSE '❌ INSUFFICIENT PERMISSIONS'
  END as expected_access
FROM user_profiles up
WHERE up.id = auth.uid();

-- 4. Test the specific INSERT condition that's failing
DO $$
DECLARE
  current_user_id UUID;
  user_role TEXT;
  user_status TEXT;
  policy_result BOOLEAN;
BEGIN
  -- Get current user details
  SELECT auth.uid() INTO current_user_id;
  
  IF current_user_id IS NOT NULL THEN
    SELECT role, status INTO user_role, user_status
    FROM user_profiles 
    WHERE id = current_user_id;
    
    -- Test the policy condition manually
    SELECT EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = current_user_id
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    ) INTO policy_result;
    
    RAISE NOTICE '🧪 POLICY TEST RESULTS:';
    RAISE NOTICE '   User ID: %', current_user_id;
    RAISE NOTICE '   User Role: %', user_role;
    RAISE NOTICE '   User Status: %', user_status;
    RAISE NOTICE '   Policy Should Allow: %', policy_result;
    
    IF NOT policy_result THEN
      RAISE NOTICE '❌ POLICY BLOCKING: User does not meet INSERT requirements';
      IF user_role NOT IN ('admin', 'owner', 'accountant', 'warehouseManager') THEN
        RAISE NOTICE '   Issue: Role "%" not in allowed list', user_role;
      END IF;
      IF user_status != 'approved' THEN
        RAISE NOTICE '   Issue: Status "%" is not approved', user_status;
      END IF;
    ELSE
      RAISE NOTICE '✅ POLICY SHOULD ALLOW: User meets all requirements';
    END IF;
  ELSE
    RAISE NOTICE '❌ NO AUTHENTICATED USER';
  END IF;
END $$;

-- 5. Check if there are conflicting policies
SELECT 
  '⚠️ POLICY CONFLICTS CHECK' as check_type,
  COUNT(*) as total_insert_policies,
  STRING_AGG(policyname, ', ') as policy_names
FROM pg_policies 
WHERE tablename = 'warehouse_requests' AND cmd = 'INSERT';

-- 6. Check table structure for any missing columns
SELECT 
  '📊 TABLE STRUCTURE CHECK' as check_type,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'warehouse_requests'
  AND column_name IN ('id', 'requested_by', 'warehouse_id', 'status', 'created_at')
ORDER BY ordinal_position;

-- 7. Emergency fix: Create a more permissive policy for warehouse managers
-- First, let's see what the current policy looks like exactly
SELECT 
  '🔧 CURRENT INSERT POLICY DETAILS' as check_type,
  policyname,
  permissive,
  roles,
  cmd,
  with_check
FROM pg_policies 
WHERE tablename = 'warehouse_requests' 
  AND cmd = 'INSERT';

-- 8. Suggest fix based on findings
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '💡 SUGGESTED FIXES:';
  RAISE NOTICE '1. Verify user has warehouseManager role and approved status';
  RAISE NOTICE '2. Check if policy WITH CHECK condition is too restrictive';
  RAISE NOTICE '3. Ensure auth.uid() is properly set during request creation';
  RAISE NOTICE '4. Consider temporarily relaxing policy for testing';
  RAISE NOTICE '5. Check if requested_by field is being set correctly';
  RAISE NOTICE '';
END $$;
