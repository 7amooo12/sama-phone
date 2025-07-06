-- 🧪 TEST WAREHOUSE ACCESS BY ROLE
-- Comprehensive testing script to verify access patterns for different user roles

-- ==================== STEP 1: IDENTIFY TEST USERS ====================

-- Show all users with their roles for testing
SELECT 
  '👥 AVAILABLE TEST USERS' as info,
  id,
  email,
  name,
  role,
  status,
  CASE 
    WHEN role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND status = 'approved' 
    THEN '✅ SHOULD HAVE ACCESS'
    ELSE '❌ NO ACCESS EXPECTED'
  END as expected_access
FROM user_profiles 
ORDER BY role, email;

-- ==================== STEP 2: TEST SPECIFIC USER ACCESS ====================

-- Test access for a specific admin user (replace with actual admin user ID)
-- Example: SELECT * FROM test_user_warehouse_access('ADMIN_USER_ID_HERE');

-- Test access for a specific owner user (replace with actual owner user ID)
-- Example: SELECT * FROM test_user_warehouse_access('OWNER_USER_ID_HERE');

-- Test access for a specific accountant user (replace with actual accountant user ID)
-- Example: SELECT * FROM test_user_warehouse_access('ACCOUNTANT_USER_ID_HERE');

-- Test access for a specific warehouse manager user (replace with actual warehouse manager user ID)
-- Example: SELECT * FROM test_user_warehouse_access('WAREHOUSE_MANAGER_USER_ID_HERE');

-- ==================== STEP 3: MANUAL ACCESS TESTS ====================

-- Test 1: Check if we can see warehouses (should work for all authorized roles)
SELECT 
  '🏢 WAREHOUSES ACCESS TEST' as test_name,
  COUNT(*) as warehouse_count,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ ACCESS GRANTED'
    ELSE '❌ ACCESS DENIED'
  END as result
FROM warehouses;

-- Test 2: Check if we can see warehouse inventory (should work for all authorized roles)
SELECT 
  '📦 WAREHOUSE INVENTORY ACCESS TEST' as test_name,
  COUNT(*) as inventory_count,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ ACCESS GRANTED'
    ELSE '❌ ACCESS DENIED OR NO DATA'
  END as result
FROM warehouse_inventory;

-- Test 3: Check if we can see warehouse transactions (should work for all authorized roles)
SELECT 
  '📊 WAREHOUSE TRANSACTIONS ACCESS TEST' as test_name,
  COUNT(*) as transaction_count,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ ACCESS GRANTED'
    ELSE '❌ ACCESS DENIED OR NO DATA'
  END as result
FROM warehouse_transactions;

-- Test 4: Check if we can see warehouse requests (should work for all authorized roles)
SELECT 
  '📋 WAREHOUSE REQUESTS ACCESS TEST' as test_name,
  COUNT(*) as request_count,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ ACCESS GRANTED'
    ELSE '❌ ACCESS DENIED OR NO DATA'
  END as result
FROM warehouse_requests;

-- ==================== STEP 4: DETAILED DATA INSPECTION ====================

-- Show sample warehouse data
SELECT 
  '🏢 SAMPLE WAREHOUSE DATA' as info,
  id,
  name,
  address,
  is_active,
  created_by,
  manager_id,
  created_at
FROM warehouses 
ORDER BY created_at DESC 
LIMIT 3;

-- Show sample inventory data
SELECT 
  '📦 SAMPLE INVENTORY DATA' as info,
  wi.id,
  wi.warehouse_id,
  wi.product_id,
  wi.quantity,
  w.name as warehouse_name
FROM warehouse_inventory wi
LEFT JOIN warehouses w ON wi.warehouse_id = w.id
ORDER BY wi.last_updated DESC 
LIMIT 3;

-- Show sample transaction data
SELECT 
  '📊 SAMPLE TRANSACTION DATA' as info,
  wt.id,
  wt.warehouse_id,
  wt.product_id,
  wt.transaction_type,
  wt.quantity,
  w.name as warehouse_name
FROM warehouse_transactions wt
LEFT JOIN warehouses w ON wt.warehouse_id = w.id
ORDER BY wt.performed_at DESC 
LIMIT 3;

-- ==================== STEP 5: ROLE-SPECIFIC TESTS ====================

-- Test admin role access (if current user is admin)
DO $$
DECLARE
    current_user_role TEXT;
    test_result TEXT;
BEGIN
    -- Get current user role
    SELECT role INTO current_user_role
    FROM user_profiles 
    WHERE id = auth.uid();
    
    IF current_user_role = 'admin' THEN
        -- Test admin-specific operations
        BEGIN
            -- Try to access all warehouse data
            PERFORM COUNT(*) FROM warehouses;
            PERFORM COUNT(*) FROM warehouse_inventory;
            PERFORM COUNT(*) FROM warehouse_transactions;
            PERFORM COUNT(*) FROM warehouse_requests;
            
            RAISE NOTICE '✅ ADMIN ACCESS TEST: All warehouse tables accessible';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ ADMIN ACCESS TEST FAILED: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'ℹ️ Current user role: % (not admin, skipping admin-specific tests)', current_user_role;
    END IF;
END $$;

-- Test owner role access (if current user is owner)
DO $$
DECLARE
    current_user_role TEXT;
BEGIN
    SELECT role INTO current_user_role
    FROM user_profiles 
    WHERE id = auth.uid();
    
    IF current_user_role = 'owner' THEN
        BEGIN
            PERFORM COUNT(*) FROM warehouses;
            PERFORM COUNT(*) FROM warehouse_inventory;
            PERFORM COUNT(*) FROM warehouse_transactions;
            PERFORM COUNT(*) FROM warehouse_requests;
            
            RAISE NOTICE '✅ OWNER ACCESS TEST: All warehouse tables accessible';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ OWNER ACCESS TEST FAILED: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'ℹ️ Current user role: % (not owner, skipping owner-specific tests)', current_user_role;
    END IF;
END $$;

-- Test accountant role access (if current user is accountant)
DO $$
DECLARE
    current_user_role TEXT;
BEGIN
    SELECT role INTO current_user_role
    FROM user_profiles 
    WHERE id = auth.uid();
    
    IF current_user_role = 'accountant' THEN
        BEGIN
            PERFORM COUNT(*) FROM warehouses;
            PERFORM COUNT(*) FROM warehouse_inventory;
            PERFORM COUNT(*) FROM warehouse_transactions;
            PERFORM COUNT(*) FROM warehouse_requests;
            
            RAISE NOTICE '✅ ACCOUNTANT ACCESS TEST: All warehouse tables accessible';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ ACCOUNTANT ACCESS TEST FAILED: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'ℹ️ Current user role: % (not accountant, skipping accountant-specific tests)', current_user_role;
    END IF;
END $$;

-- Test warehouse manager role access (if current user is warehouse manager)
DO $$
DECLARE
    current_user_role TEXT;
BEGIN
    SELECT role INTO current_user_role
    FROM user_profiles 
    WHERE id = auth.uid();
    
    IF current_user_role = 'warehouseManager' THEN
        BEGIN
            PERFORM COUNT(*) FROM warehouses;
            PERFORM COUNT(*) FROM warehouse_inventory;
            PERFORM COUNT(*) FROM warehouse_transactions;
            PERFORM COUNT(*) FROM warehouse_requests;
            
            RAISE NOTICE '✅ WAREHOUSE MANAGER ACCESS TEST: All warehouse tables accessible';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ WAREHOUSE MANAGER ACCESS TEST FAILED: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'ℹ️ Current user role: % (not warehouseManager, skipping warehouse manager-specific tests)', current_user_role;
    END IF;
END $$;

-- ==================== STEP 6: CURRENT USER CONTEXT ====================

-- Show current user context for debugging
SELECT 
  '🔍 CURRENT USER CONTEXT' as info,
  auth.uid() as current_user_id,
  up.email,
  up.name,
  up.role,
  up.status,
  CASE 
    WHEN up.role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND up.status = 'approved' 
    THEN '✅ SHOULD HAVE WAREHOUSE ACCESS'
    ELSE '❌ NO WAREHOUSE ACCESS EXPECTED'
  END as access_expectation
FROM user_profiles up
WHERE up.id = auth.uid();

-- ==================== STEP 7: SUMMARY ====================

SELECT 
  '📋 TEST SUMMARY' as info,
  'Run this script while authenticated as different user roles to test access patterns' as instruction,
  'Check the RAISE NOTICE messages in the output for detailed test results' as note;
