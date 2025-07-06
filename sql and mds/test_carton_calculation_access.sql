-- 🧪 TEST CARTON CALCULATION ACCESS ACROSS USER ROLES
-- This script tests if Admin, Accountant, and Business Owner roles can access warehouse data for carton calculations

-- =====================================================
-- STEP 1: VERIFY CURRENT USER CONTEXT
-- =====================================================

SELECT '🔍 === CURRENT USER VERIFICATION ===' as test_step;

-- Check current authentication
SELECT 
    '👤 AUTHENTICATION CHECK' as check_type,
    auth.uid() as current_user_id,
    CASE 
        WHEN auth.uid() IS NULL THEN '❌ NOT AUTHENTICATED'
        ELSE '✅ AUTHENTICATED'
    END as auth_status;

-- Check current user profile
SELECT 
    '👤 USER PROFILE CHECK' as check_type,
    id,
    email,
    name,
    role,
    status,
    CASE 
        WHEN status = 'approved' THEN '✅ APPROVED'
        WHEN status = 'pending' THEN '⚠️ PENDING'
        ELSE '❌ NOT APPROVED'
    END as approval_status
FROM user_profiles 
WHERE id = auth.uid();

-- =====================================================
-- STEP 2: TEST WAREHOUSE ACCESS
-- =====================================================

SELECT '🏭 === WAREHOUSE ACCESS TEST ===' as test_step;

-- Test warehouse table access
SELECT 
    '🏭 WAREHOUSES ACCESS' as access_test,
    COUNT(*) as accessible_warehouses,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ CAN ACCESS WAREHOUSES'
        ELSE '❌ NO WAREHOUSE ACCESS'
    END as access_status
FROM warehouses;

-- =====================================================
-- STEP 3: TEST WAREHOUSE INVENTORY ACCESS (CRITICAL FOR CARTONS)
-- =====================================================

SELECT '📦 === WAREHOUSE INVENTORY ACCESS TEST ===' as test_step;

-- Test warehouse_inventory table access
SELECT 
    '📦 INVENTORY ACCESS' as access_test,
    COUNT(*) as accessible_inventory_items,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ CAN ACCESS INVENTORY'
        ELSE '❌ NO INVENTORY ACCESS'
    END as access_status
FROM warehouse_inventory;

-- Test carton calculation fields access
SELECT 
    '🧮 CARTON FIELDS ACCESS' as access_test,
    COUNT(*) as total_items,
    COUNT(CASE WHEN quantity IS NOT NULL THEN 1 END) as items_with_quantity,
    COUNT(CASE WHEN quantity_per_carton IS NOT NULL THEN 1 END) as items_with_carton_info,
    COUNT(CASE WHEN quantity > 0 AND quantity_per_carton > 0 THEN 1 END) as calculable_items,
    CASE 
        WHEN COUNT(CASE WHEN quantity > 0 AND quantity_per_carton > 0 THEN 1 END) > 0 
        THEN '✅ CAN CALCULATE CARTONS'
        ELSE '❌ CANNOT CALCULATE CARTONS'
    END as calculation_status
FROM warehouse_inventory;

-- Sample carton calculations (if data exists)
SELECT 
    '🧮 SAMPLE CARTON CALCULATIONS' as calculation_test,
    warehouse_id,
    product_id,
    quantity,
    quantity_per_carton,
    CASE 
        WHEN quantity_per_carton > 0 THEN CEIL(quantity::DECIMAL / quantity_per_carton)
        ELSE 0
    END as calculated_cartons
FROM warehouse_inventory
WHERE quantity > 0 AND quantity_per_carton > 0
LIMIT 5;

-- =====================================================
-- STEP 4: TEST WAREHOUSE TRANSACTIONS ACCESS
-- =====================================================

SELECT '📊 === WAREHOUSE TRANSACTIONS ACCESS TEST ===' as test_step;

-- Test warehouse_transactions table access
SELECT 
    '📊 TRANSACTIONS ACCESS' as access_test,
    COUNT(*) as accessible_transactions,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ CAN ACCESS TRANSACTIONS'
        ELSE '❌ NO TRANSACTIONS ACCESS'
    END as access_status
FROM warehouse_transactions;

-- =====================================================
-- STEP 5: TEST WAREHOUSE REQUESTS ACCESS
-- =====================================================

SELECT '📋 === WAREHOUSE REQUESTS ACCESS TEST ===' as test_step;

-- Test warehouse_requests table access
SELECT 
    '📋 REQUESTS ACCESS' as access_test,
    COUNT(*) as accessible_requests,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ CAN ACCESS REQUESTS'
        ELSE '❌ NO REQUESTS ACCESS'
    END as access_status
FROM warehouse_requests;

-- =====================================================
-- STEP 6: COMPREHENSIVE ACCESS SUMMARY
-- =====================================================

SELECT '📊 === COMPREHENSIVE ACCESS SUMMARY ===' as summary_step;

-- Create a comprehensive access report
WITH access_summary AS (
    SELECT 
        (SELECT COUNT(*) FROM warehouses) as warehouse_count,
        (SELECT COUNT(*) FROM warehouse_inventory) as inventory_count,
        (SELECT COUNT(*) FROM warehouse_transactions) as transaction_count,
        (SELECT COUNT(*) FROM warehouse_requests) as request_count,
        (SELECT COUNT(*) FROM warehouse_inventory WHERE quantity > 0 AND quantity_per_carton > 0) as carton_calculable_count
)
SELECT 
    '📊 ACCESS SUMMARY' as summary_type,
    warehouse_count,
    inventory_count,
    transaction_count,
    request_count,
    carton_calculable_count,
    CASE 
        WHEN warehouse_count > 0 AND inventory_count > 0 AND carton_calculable_count > 0 
        THEN '✅ FULL CARTON CALCULATION ACCESS'
        WHEN warehouse_count > 0 AND inventory_count > 0 
        THEN '⚠️ PARTIAL ACCESS (NO CARTON DATA)'
        WHEN warehouse_count > 0 
        THEN '⚠️ WAREHOUSE ACCESS ONLY'
        ELSE '❌ NO ACCESS'
    END as overall_status
FROM access_summary;

-- =====================================================
-- STEP 7: ROLE-SPECIFIC RECOMMENDATIONS
-- =====================================================

SELECT '💡 === ROLE-SPECIFIC RECOMMENDATIONS ===' as recommendations_step;

-- Get current user role and provide specific recommendations
WITH current_user_info AS (
    SELECT 
        COALESCE(role, 'unknown') as user_role,
        COALESCE(status, 'unknown') as user_status
    FROM user_profiles 
    WHERE id = auth.uid()
)
SELECT 
    '💡 RECOMMENDATIONS' as recommendation_type,
    user_role,
    user_status,
    CASE 
        WHEN user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND user_status = 'approved'
        THEN '✅ Role has proper access - carton calculations should work'
        WHEN user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND user_status != 'approved'
        THEN '⚠️ Role is correct but user needs approval'
        WHEN user_role NOT IN ('admin', 'owner', 'accountant', 'warehouseManager')
        THEN '❌ Role does not have warehouse access'
        ELSE '❌ Unknown user or role issue'
    END as recommendation
FROM current_user_info;

SELECT '🎯 === CARTON CALCULATION ACCESS TEST COMPLETED ===' as completion_message;
