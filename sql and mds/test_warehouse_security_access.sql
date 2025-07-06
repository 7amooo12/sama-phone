-- 🧪 WAREHOUSE SECURITY ACCESS TEST
-- Practical test to verify RLS policies are actually working

-- ==================== TEST SETUP ====================

-- First, let's see what user we're testing as
SELECT 
  '👤 CURRENT USER TEST' as test_type,
  auth.uid() as current_user_id,
  CASE 
    WHEN auth.uid() IS NULL THEN '❌ NOT AUTHENTICATED'
    ELSE '✅ AUTHENTICATED'
  END as auth_status;

-- Check if current user has a profile
SELECT 
  '📋 USER PROFILE TEST' as test_type,
  up.id,
  up.email,
  up.name,
  up.role,
  up.status,
  CASE 
    WHEN up.role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND up.status = 'approved' 
    THEN '✅ AUTHORIZED FOR WAREHOUSES'
    ELSE '❌ NOT AUTHORIZED'
  END as warehouse_access
FROM user_profiles up
WHERE up.id = auth.uid();

-- ==================== WAREHOUSE ACCESS TESTS ====================

-- Test 1: Can we SELECT from warehouses?
DO $$
DECLARE
  warehouse_count INTEGER;
  test_result TEXT;
BEGIN
  BEGIN
    SELECT COUNT(*) INTO warehouse_count FROM warehouses;
    test_result := format('✅ SUCCESS: Found %s warehouses', warehouse_count);
  EXCEPTION 
    WHEN insufficient_privilege THEN
      test_result := '🔒 BLOCKED: Insufficient privileges (RLS working)';
    WHEN OTHERS THEN
      test_result := format('❓ ERROR: %s', SQLERRM);
  END;
  
  RAISE NOTICE '🧪 WAREHOUSE SELECT TEST: %', test_result;
END $$;

-- Test 2: Can we INSERT into warehouses?
DO $$
DECLARE
  test_result TEXT;
  current_user_id UUID;
BEGIN
  -- Get current user ID
  SELECT auth.uid() INTO current_user_id;

  BEGIN
    INSERT INTO warehouses (name, address, description, created_by)
    VALUES ('Test Warehouse', 'Test Address', 'Security Test', current_user_id);
    test_result := '✅ SUCCESS: Warehouse created (user has INSERT permission)';

    -- Clean up test data
    DELETE FROM warehouses WHERE name = 'Test Warehouse' AND description = 'Security Test';
  EXCEPTION
    WHEN insufficient_privilege THEN
      test_result := '🔒 BLOCKED: Cannot create warehouse (RLS working correctly)';
    WHEN OTHERS THEN
      test_result := '❓ ERROR: ' || SQLERRM;
  END;

  RAISE NOTICE '🧪 WAREHOUSE INSERT TEST: %', test_result;
END $$;

-- ==================== INVENTORY ACCESS TESTS ====================

-- Test 3: Can we SELECT from warehouse_inventory?
DO $$
DECLARE
  inventory_count INTEGER;
  test_result TEXT;
BEGIN
  BEGIN
    SELECT COUNT(*) INTO inventory_count FROM warehouse_inventory;
    test_result := '✅ SUCCESS: Found ' || inventory_count || ' inventory items';
  EXCEPTION
    WHEN insufficient_privilege THEN
      test_result := '🔒 BLOCKED: Insufficient privileges (RLS working)';
    WHEN OTHERS THEN
      test_result := '❓ ERROR: ' || SQLERRM;
  END;

  RAISE NOTICE '🧪 INVENTORY SELECT TEST: %', test_result;
END $$;

-- ==================== REQUEST ACCESS TESTS ====================

-- Test 4: Can we SELECT from warehouse_requests?
DO $$
DECLARE
  request_count INTEGER;
  test_result TEXT;
BEGIN
  BEGIN
    SELECT COUNT(*) INTO request_count FROM warehouse_requests;
    test_result := '✅ SUCCESS: Found ' || request_count || ' requests';
  EXCEPTION
    WHEN insufficient_privilege THEN
      test_result := '🔒 BLOCKED: Insufficient privileges (RLS working)';
    WHEN OTHERS THEN
      test_result := '❓ ERROR: ' || SQLERRM;
  END;

  RAISE NOTICE '🧪 REQUESTS SELECT TEST: %', test_result;
END $$;

-- ==================== TRANSACTION ACCESS TESTS ====================

-- Test 5: Can we SELECT from warehouse_transactions?
DO $$
DECLARE
  transaction_count INTEGER;
  test_result TEXT;
BEGIN
  BEGIN
    SELECT COUNT(*) INTO transaction_count FROM warehouse_transactions;
    test_result := format('✅ SUCCESS: Found %s transactions', transaction_count);
  EXCEPTION 
    WHEN insufficient_privilege THEN
      test_result := '🔒 BLOCKED: Insufficient privileges (RLS working)';
    WHEN OTHERS THEN
      test_result := format('❓ ERROR: %s', SQLERRM);
  END;
  
  RAISE NOTICE '🧪 TRANSACTIONS SELECT TEST: %', test_result;
END $$;

-- ==================== POLICY CONDITION VERIFICATION ====================

-- Verify our policies have the correct security conditions
SELECT 
  '🔍 POLICY SECURITY VERIFICATION' as check_type,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%') 
     AND (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%')
    THEN '✅ SECURE (has auth + role checks)'
    WHEN (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%')
    THEN '⚠️ PARTIAL (has auth, missing role check)'
    ELSE '🚨 VULNERABLE (missing auth check)'
  END as security_assessment
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_requests', 'warehouse_transactions')
  AND policyname LIKE 'secure_%'
ORDER BY tablename, cmd;

-- ==================== FINAL SECURITY SUMMARY ====================

-- Provide overall security assessment
WITH security_summary AS (
  SELECT 
    COUNT(*) as total_policies,
    COUNT(CASE WHEN (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%') 
                AND (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%')
               THEN 1 END) as secure_policies,
    COUNT(CASE WHEN NOT (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%')
               THEN 1 END) as vulnerable_policies
  FROM pg_policies 
  WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_requests', 'warehouse_transactions')
    AND policyname LIKE 'secure_%'
)
SELECT 
  '📊 FINAL SECURITY ASSESSMENT' as assessment_type,
  total_policies,
  secure_policies,
  vulnerable_policies,
  CASE 
    WHEN vulnerable_policies = 0 AND secure_policies = total_policies 
    THEN '✅ SYSTEM FULLY SECURED'
    WHEN vulnerable_policies = 0 
    THEN '⚠️ SYSTEM PARTIALLY SECURED'
    ELSE '🚨 SYSTEM HAS VULNERABILITIES'
  END as overall_status,
  CASE 
    WHEN vulnerable_policies = 0 AND secure_policies = total_policies 
    THEN 'All warehouse tables properly protected with authentication and role-based access control'
    ELSE 'Some policies may need attention'
  END as recommendation
FROM security_summary;

-- ==================== INSTRUCTIONS ====================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '📋 SECURITY TEST INSTRUCTIONS:';
  RAISE NOTICE '1. Run this script as different user types (admin, warehouse manager, unauthorized user)';
  RAISE NOTICE '2. Check the test results above';
  RAISE NOTICE '3. Expected behavior:';
  RAISE NOTICE '   - Authorized users: Should see SUCCESS messages';
  RAISE NOTICE '   - Unauthorized users: Should see BLOCKED messages';
  RAISE NOTICE '   - Anonymous users: Should see BLOCKED messages';
  RAISE NOTICE '4. If all tests show appropriate results, RLS is working correctly';
  RAISE NOTICE '';
END $$;
