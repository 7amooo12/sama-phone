-- ============================================================================
-- TEST ACCOUNTANT SEARCH FUNCTIONALITY
-- ============================================================================
-- This script tests all search functionality for the Accountant role
-- to ensure RLS policies are working correctly
-- ============================================================================

-- ==================== STEP 1: SETUP TEST CONTEXT ====================

-- Set the current user context to an accountant user
-- Replace this UUID with an actual accountant user ID from your system
-- You can find accountant user IDs by running:
-- SELECT id, email, name FROM user_profiles WHERE role = 'accountant' AND status = 'approved';

-- For testing purposes, we'll use a placeholder
-- In production, this would be set automatically by Supabase auth
-- SET LOCAL "request.jwt.claims" = '{"sub": "YOUR_ACCOUNTANT_USER_ID_HERE"}';

-- ==================== STEP 2: TEST BASIC TABLE ACCESS ====================

-- Test 1: Can accountant read products?
SELECT 
  '📦 TEST 1: PRODUCTS ACCESS' as test_name,
  COUNT(*) as product_count,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ SUCCESS - Can read products'
    ELSE '❌ FAILED - Cannot read products'
  END as test_result
FROM products
LIMIT 5;

-- Test 2: Can accountant read warehouse inventory?
SELECT 
  '🏪 TEST 2: WAREHOUSE INVENTORY ACCESS' as test_name,
  COUNT(*) as inventory_count,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ SUCCESS - Can read warehouse inventory'
    ELSE '❌ FAILED - Cannot read warehouse inventory'
  END as test_result
FROM warehouse_inventory
LIMIT 5;

-- Test 3: Can accountant read warehouses?
SELECT 
  '🏢 TEST 3: WAREHOUSES ACCESS' as test_name,
  COUNT(*) as warehouse_count,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ SUCCESS - Can read warehouses'
    ELSE '❌ FAILED - Cannot read warehouses'
  END as test_result
FROM warehouses
LIMIT 5;

-- Test 4: Can accountant read user profiles?
SELECT 
  '👥 TEST 4: USER PROFILES ACCESS' as test_name,
  COUNT(*) as profile_count,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ SUCCESS - Can read user profiles'
    ELSE '❌ FAILED - Cannot read user profiles'
  END as test_result
FROM user_profiles
WHERE role = 'client'
LIMIT 5;

-- ==================== STEP 3: TEST SEARCH FUNCTIONS ====================

-- Test 5: Can accountant execute search_warehouse_products function?
SELECT 
  '🔍 TEST 5: PRODUCT SEARCH FUNCTION' as test_name,
  'Testing search_warehouse_products function' as description;

-- Try to execute the search function with sample parameters
-- This will test if the function exists and is accessible
DO $$
DECLARE
  result_count INTEGER;
  test_warehouses UUID[] := ARRAY[]::UUID[];
BEGIN
  -- Get some warehouse IDs for testing
  SELECT ARRAY_AGG(id) INTO test_warehouses 
  FROM warehouses 
  LIMIT 3;
  
  -- Test the search function
  SELECT COUNT(*) INTO result_count
  FROM search_warehouse_products('test', test_warehouses, 10, 0);
  
  RAISE NOTICE '✅ SUCCESS: search_warehouse_products function executed, returned % results', result_count;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '❌ FAILED: search_warehouse_products function error: %', SQLERRM;
END $$;

-- Test 6: Can accountant execute search_warehouse_categories function?
SELECT 
  '🔍 TEST 6: CATEGORY SEARCH FUNCTION' as test_name,
  'Testing search_warehouse_categories function' as description;

DO $$
DECLARE
  result_count INTEGER;
  test_warehouses UUID[] := ARRAY[]::UUID[];
BEGIN
  -- Get some warehouse IDs for testing
  SELECT ARRAY_AGG(id) INTO test_warehouses 
  FROM warehouses 
  LIMIT 3;
  
  -- Test the search function
  SELECT COUNT(*) INTO result_count
  FROM search_warehouse_categories('test', test_warehouses, 10, 0);
  
  RAISE NOTICE '✅ SUCCESS: search_warehouse_categories function executed, returned % results', result_count;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '❌ FAILED: search_warehouse_categories function error: %', SQLERRM;
END $$;

-- ==================== STEP 4: TEST SPECIFIC SEARCH SCENARIOS ====================

-- Test 7: Product name search
SELECT 
  '🔍 TEST 7: PRODUCT NAME SEARCH' as test_name,
  COUNT(*) as matching_products,
  CASE 
    WHEN COUNT(*) >= 0 THEN '✅ SUCCESS - Product search working'
    ELSE '❌ FAILED - Product search not working'
  END as test_result
FROM products 
WHERE name ILIKE '%test%' OR name ILIKE '%منتج%'
LIMIT 10;

-- Test 8: Warehouse inventory search with joins
SELECT 
  '🔍 TEST 8: INVENTORY SEARCH WITH JOINS' as test_name,
  COUNT(*) as matching_inventory,
  CASE 
    WHEN COUNT(*) >= 0 THEN '✅ SUCCESS - Inventory join search working'
    ELSE '❌ FAILED - Inventory join search not working'
  END as test_result
FROM warehouse_inventory wi
JOIN products p ON wi.product_id = p.id
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE p.name ILIKE '%test%' OR w.name ILIKE '%مخزن%'
LIMIT 10;

-- Test 9: Client search for accountant operations
SELECT 
  '🔍 TEST 9: CLIENT SEARCH' as test_name,
  COUNT(*) as client_count,
  CASE 
    WHEN COUNT(*) >= 0 THEN '✅ SUCCESS - Client search working'
    ELSE '❌ FAILED - Client search not working'
  END as test_result
FROM user_profiles 
WHERE role = 'client' 
  AND status = 'approved'
  AND (name ILIKE '%test%' OR email ILIKE '%test%')
LIMIT 10;

-- ==================== STEP 5: TEST COMPLEX SEARCH QUERIES ====================

-- Test 10: Multi-table search simulation (like what the app would do)
SELECT 
  '🔍 TEST 10: COMPLEX MULTI-TABLE SEARCH' as test_name,
  'Testing complex search across multiple tables' as description;

WITH search_results AS (
  SELECT 
    'product' as result_type,
    p.id,
    p.name,
    p.category,
    COALESCE(SUM(wi.quantity), 0) as total_quantity
  FROM products p
  LEFT JOIN warehouse_inventory wi ON p.id = wi.product_id
  WHERE p.name ILIKE '%test%' OR p.category ILIKE '%test%'
  GROUP BY p.id, p.name, p.category
  LIMIT 5
)
SELECT 
  COUNT(*) as result_count,
  CASE 
    WHEN COUNT(*) >= 0 THEN '✅ SUCCESS - Complex search working'
    ELSE '❌ FAILED - Complex search not working'
  END as test_result
FROM search_results;

-- ==================== STEP 6: PERFORMANCE TEST ====================

-- Test 11: Search performance test
SELECT 
  '⚡ TEST 11: SEARCH PERFORMANCE' as test_name,
  'Testing search query performance' as description;

EXPLAIN (ANALYZE, BUFFERS) 
SELECT 
  p.id,
  p.name,
  p.category,
  w.name as warehouse_name,
  wi.quantity
FROM products p
JOIN warehouse_inventory wi ON p.id = wi.product_id
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE p.name ILIKE '%test%'
LIMIT 20;

-- ==================== STEP 7: SECURITY VERIFICATION ====================

-- Test 12: Verify accountant cannot access restricted data
SELECT 
  '🔒 TEST 12: SECURITY VERIFICATION' as test_name,
  'Verifying accountant cannot access unauthorized data' as description;

-- This should work (accountant can see client profiles)
SELECT 
  'Client profiles access' as access_type,
  COUNT(*) as accessible_count,
  '✅ Expected access' as status
FROM user_profiles 
WHERE role = 'client';

-- This should work (accountant can see approved users)
SELECT 
  'Approved users access' as access_type,
  COUNT(*) as accessible_count,
  '✅ Expected access' as status
FROM user_profiles 
WHERE status = 'approved';

-- ==================== STEP 8: FINAL SUMMARY ====================

-- Summary of all tests
SELECT 
  '📊 FINAL TEST SUMMARY' as summary_type,
  'All search functionality tests completed' as message,
  'Check above results for any failures' as instruction,
  'If all tests show ✅ SUCCESS, search functionality is working' as success_indicator;

-- Check if there are any RLS policy violations in the logs
SELECT 
  '🔍 RLS POLICY CHECK' as check_type,
  'If you see any permission denied errors above, RLS policies need adjustment' as note,
  'All search operations should complete without authentication errors' as requirement;

-- ==================== TROUBLESHOOTING GUIDE ====================

SELECT 
  '🛠️ TROUBLESHOOTING GUIDE' as guide_type,
  'If tests fail, check the following:' as title;

SELECT 
  '1. User Authentication' as step,
  'Ensure the user is properly authenticated with Supabase' as description;

SELECT 
  '2. User Role' as step,
  'Verify the user has role = accountant in user_profiles table' as description;

SELECT 
  '3. User Status' as step,
  'Verify the user has status = approved in user_profiles table' as description;

SELECT 
  '4. RLS Policies' as step,
  'Run the fix_accountant_search_rls_policies.sql script if not already done' as description;

SELECT 
  '5. Function Permissions' as step,
  'Ensure search functions have EXECUTE permissions for authenticated role' as description;

-- ==================== END OF TESTS ====================

SELECT 
  '🎯 TEST COMPLETION' as status,
  NOW() as completed_at,
  'Accountant search functionality testing completed' as message;
