-- 🔍 COMPREHENSIVE RLS ANALYSIS FOR WAREHOUSE DISPATCH ISSUE
-- Deep dive into the RLS policy violation

-- ==================== STEP 1: USER VERIFICATION ====================

-- Check the exact user profile
WITH user_analysis AS (
  SELECT 
    id,
    email,
    name,
    role,
    status,
    created_at,
    updated_at,
    CASE 
      WHEN role IN ('admin', 'owner', 'accountant', 'warehouseManager') THEN 'AUTHORIZED'
      ELSE 'NOT_AUTHORIZED'
    END as role_authorization,
    CASE 
      WHEN status = 'approved' THEN 'APPROVED'
      ELSE 'NOT_APPROVED'
    END as status_authorization
  FROM user_profiles 
  WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15'
)
SELECT 
  '👤 USER ANALYSIS' as analysis_type,
  *,
  CASE 
    WHEN role_authorization = 'AUTHORIZED' AND status_authorization = 'APPROVED' 
    THEN '✅ SHOULD_PASS_RLS'
    ELSE '❌ SHOULD_FAIL_RLS'
  END as expected_rls_result
FROM user_analysis;

-- ==================== STEP 2: POLICY EXAMINATION ====================

-- Get the exact policy definition
SELECT 
  '🛡️ CURRENT POLICY DEFINITION' as policy_info,
  policyname,
  cmd,
  permissive,
  roles,
  with_check as policy_condition
FROM pg_policies 
WHERE tablename = 'warehouse_requests' AND cmd = 'INSERT';

-- ==================== STEP 3: AUTH.UID() CONTEXT ISSUE ====================

-- The main issue might be that auth.uid() is NULL during the INSERT
-- This happens when the Supabase client context is not properly set

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🔍 POTENTIAL ROOT CAUSE ANALYSIS:';
  RAISE NOTICE '================================';
  RAISE NOTICE '';
  RAISE NOTICE '❓ HYPOTHESIS 1: auth.uid() returns NULL';
  RAISE NOTICE '   - Supabase client context not properly set during INSERT';
  RAISE NOTICE '   - Flutter app not passing authentication context to database';
  RAISE NOTICE '   - Session expired or invalid';
  RAISE NOTICE '';
  RAISE NOTICE '❓ HYPOTHESIS 2: User profile data mismatch';
  RAISE NOTICE '   - User exists but role/status incorrect';
  RAISE NOTICE '   - Recent role change not reflected in session';
  RAISE NOTICE '';
  RAISE NOTICE '❓ HYPOTHESIS 3: Policy condition too strict';
  RAISE NOTICE '   - Multiple conditions causing unexpected failures';
  RAISE NOTICE '   - requested_by field validation issue';
  RAISE NOTICE '';
END $$;

-- ==================== STEP 4: MANUAL POLICY TEST ====================

-- Test the policy condition manually with known values
DO $$
DECLARE
  test_user_id UUID := '4ac083bc-3e05-4456-8579-0877d2627b15';
  user_exists BOOLEAN;
  role_valid BOOLEAN;
  status_valid BOOLEAN;
  combined_check BOOLEAN;
  user_record RECORD;
BEGIN
  -- Get user record
  SELECT * INTO user_record FROM user_profiles WHERE id = test_user_id;
  
  IF user_record.id IS NULL THEN
    RAISE NOTICE '❌ USER NOT FOUND: %', test_user_id;
    RETURN;
  END IF;
  
  -- Test individual conditions
  user_exists := (user_record.id IS NOT NULL);
  role_valid := (user_record.role IN ('admin', 'owner', 'accountant', 'warehouseManager'));
  status_valid := (user_record.status = 'approved');
  
  -- Test the exact EXISTS condition from the policy
  SELECT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE user_profiles.id = test_user_id
      AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
      AND user_profiles.status = 'approved'
  ) INTO combined_check;
  
  RAISE NOTICE '';
  RAISE NOTICE '🧪 MANUAL POLICY TEST RESULTS:';
  RAISE NOTICE '=============================';
  RAISE NOTICE 'User ID: %', test_user_id;
  RAISE NOTICE 'Email: %', user_record.email;
  RAISE NOTICE 'Name: %', user_record.name;
  RAISE NOTICE 'Role: %', user_record.role;
  RAISE NOTICE 'Status: %', user_record.status;
  RAISE NOTICE '';
  RAISE NOTICE 'Individual Condition Tests:';
  RAISE NOTICE '  User exists: %', user_exists;
  RAISE NOTICE '  Role valid: % (role: %)', role_valid, user_record.role;
  RAISE NOTICE '  Status valid: % (status: %)', status_valid, user_record.status;
  RAISE NOTICE '';
  RAISE NOTICE 'Combined EXISTS check: %', combined_check;
  RAISE NOTICE '';
  
  IF combined_check THEN
    RAISE NOTICE '✅ POLICY SHOULD ALLOW: User meets all requirements';
    RAISE NOTICE '🔍 ISSUE LIKELY: auth.uid() context problem in Flutter app';
  ELSE
    RAISE NOTICE '❌ POLICY CORRECTLY BLOCKS: User does not meet requirements';
    IF NOT role_valid THEN
      RAISE NOTICE '   ❌ Invalid role: % (expected: admin, owner, accountant, warehouseManager)', user_record.role;
    END IF;
    IF NOT status_valid THEN
      RAISE NOTICE '   ❌ Invalid status: % (expected: approved)', user_record.status;
    END IF;
  END IF;
  RAISE NOTICE '';
END $$;

-- ==================== STEP 5: RECOMMENDED SOLUTIONS ====================

DO $$
DECLARE
  user_record RECORD;
  should_pass BOOLEAN;
BEGIN
  SELECT * INTO user_record FROM user_profiles WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';
  
  should_pass := (
    user_record.id IS NOT NULL AND
    user_record.role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND
    user_record.status = 'approved'
  );
  
  RAISE NOTICE '';
  RAISE NOTICE '💡 RECOMMENDED SOLUTIONS:';
  RAISE NOTICE '========================';
  
  IF should_pass THEN
    RAISE NOTICE '';
    RAISE NOTICE '✅ USER PROFILE IS CORRECT - Issue is likely technical:';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 SOLUTION 1: Fix auth.uid() context';
    RAISE NOTICE '   - Ensure Supabase client passes authentication context';
    RAISE NOTICE '   - Verify session is valid during INSERT operation';
    RAISE NOTICE '   - Check Flutter app authentication state';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 SOLUTION 2: Temporary debug policy';
    RAISE NOTICE '   - Use debug_rls_policy_violation.sql to create permissive policy';
    RAISE NOTICE '   - Test if dispatch creation works with minimal security';
    RAISE NOTICE '   - Restore secure policy after confirming auth context';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 SOLUTION 3: Add logging to policy';
    RAISE NOTICE '   - Create policy with RAISE NOTICE for debugging';
    RAISE NOTICE '   - Log auth.uid() value during policy evaluation';
    RAISE NOTICE '';
  ELSE
    RAISE NOTICE '';
    RAISE NOTICE '❌ USER PROFILE NEEDS CORRECTION:';
    RAISE NOTICE '   Current role: %', user_record.role;
    RAISE NOTICE '   Current status: %', user_record.status;
    RAISE NOTICE '   Required role: admin, owner, accountant, or warehouseManager';
    RAISE NOTICE '   Required status: approved';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 SOLUTION: Fix user profile data';
    RAISE NOTICE '   UPDATE user_profiles SET role = ''warehouseManager'', status = ''approved''';
    RAISE NOTICE '   WHERE id = ''%'';', user_record.id;
    RAISE NOTICE '';
  END IF;
  
  RAISE NOTICE '📋 IMMEDIATE NEXT STEPS:';
  RAISE NOTICE '1. Run debug_rls_policy_violation.sql';
  RAISE NOTICE '2. Test dispatch creation with debug policy';
  RAISE NOTICE '3. If successful, issue is auth.uid() context';
  RAISE NOTICE '4. If still fails, investigate Flutter app authentication';
  RAISE NOTICE '5. Restore secure policy after fixing root cause';
  RAISE NOTICE '';
END $$;
