-- 🔍 VERIFY: Inventory Deduction Authentication Fix
-- Cross-reference diagnostic results with actual inventory deduction failure

-- =====================================================
-- STEP 1: VERIFY AUTHENTICATION CONTEXT
-- =====================================================

SELECT '🔍 STEP 1: Authentication Context Verification' as test_step;

-- Check current auth context
SELECT 
    '👤 Current Auth Status' as test_type,
    auth.uid() as current_user_id,
    CASE 
        WHEN auth.uid() IS NULL THEN '❌ NULL - This explains the inventory access failure'
        ELSE '✅ Valid - Authentication context is working'
    END as auth_diagnosis;

-- =====================================================
-- STEP 2: PRODUCT 131 INVENTORY VERIFICATION
-- =====================================================

SELECT '📦 STEP 2: Product 131 Inventory Status' as test_step;

-- Check if Product 131 actually exists and has stock
SELECT 
    '🎯 Product 131 Inventory Check' as test_type,
    wi.warehouse_id,
    wi.product_id,
    wi.quantity,
    wi.minimum_stock,
    w.name as warehouse_name,
    w.is_active as warehouse_active
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '131'
ORDER BY wi.quantity DESC;

-- Check total available quantity for Product 131
SELECT 
    '📊 Product 131 Total Available' as test_type,
    SUM(wi.quantity) as total_available_quantity,
    COUNT(*) as warehouses_with_product,
    COUNT(CASE WHEN wi.quantity > 0 THEN 1 END) as warehouses_with_stock
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '131' AND w.is_active = true;

-- =====================================================
-- STEP 3: SIMULATE GLOBAL INVENTORY SERVICE QUERY
-- =====================================================

SELECT '🌍 STEP 3: Global Inventory Service Simulation' as test_step;

-- Simulate the exact query used by GlobalInventoryService
SELECT 
    '🔍 GlobalInventoryService Query Simulation' as test_type,
    wi.id,
    wi.warehouse_id,
    wi.product_id,
    wi.quantity,
    wi.minimum_stock,
    wi.maximum_stock,
    w.name as warehouse_name,
    w.is_active,
    CASE 
        WHEN wi.quantity > 0 THEN '✅ Available'
        ELSE '❌ No Stock'
    END as stock_status
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '131'
    AND w.is_active = true
ORDER BY wi.quantity DESC;

-- =====================================================
-- STEP 4: DIAGNOSE THE DEDUCTION FAILURE
-- =====================================================

SELECT '🚨 STEP 4: Deduction Failure Diagnosis' as test_step;

-- Comprehensive diagnosis
WITH auth_check AS (
    SELECT 
        auth.uid() IS NOT NULL as has_auth_context,
        (SELECT role FROM user_profiles WHERE id = auth.uid()) as user_role,
        (SELECT status FROM user_profiles WHERE id = auth.uid()) as user_status
),
inventory_check AS (
    SELECT 
        EXISTS(SELECT 1 FROM warehouse_inventory WHERE product_id = '131') as product_exists,
        COALESCE(SUM(wi.quantity), 0) as total_available,
        COUNT(CASE WHEN wi.quantity > 0 THEN 1 END) as warehouses_with_stock
    FROM warehouse_inventory wi
    JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE wi.product_id = '131' AND w.is_active = true
)
SELECT 
    '🎯 DEDUCTION FAILURE DIAGNOSIS' as result,
    ac.has_auth_context,
    ac.user_role,
    ac.user_status,
    ic.product_exists,
    ic.total_available,
    ic.warehouses_with_stock,
    CASE 
        WHEN NOT ac.has_auth_context THEN '❌ CRITICAL: Authentication context lost - RLS blocking access'
        WHEN ac.user_role NOT IN ('admin', 'owner', 'accountant', 'warehouseManager') THEN '❌ CRITICAL: Insufficient role permissions'
        WHEN ac.user_status != 'approved' THEN '❌ CRITICAL: User status not approved'
        WHEN NOT ic.product_exists THEN '❌ DATA: Product 131 not found in any warehouse'
        WHEN ic.total_available = 0 THEN '⚠️ DATA: Product 131 exists but has zero stock across all warehouses'
        WHEN ic.warehouses_with_stock = 0 THEN '⚠️ DATA: Product 131 exists but no warehouses have available stock'
        ELSE '✅ SUCCESS: Product has available stock - issue may be in service logic'
    END as diagnosis,
    CASE 
        WHEN NOT ac.has_auth_context THEN 'Re-run authentication context fix and ensure user is properly logged in'
        WHEN ic.total_available = 0 THEN 'Check if Product 131 actually has stock or if this is expected behavior'
        WHEN ic.warehouses_with_stock = 0 THEN 'Verify warehouse activation status and stock levels'
        ELSE 'Check IntelligentInventoryDeductionService for authentication state preservation issues'
    END as recommended_action
FROM auth_check ac, inventory_check ic;

-- =====================================================
-- STEP 5: AUTHENTICATION STATE PRESERVATION TEST
-- =====================================================

SELECT '🔐 STEP 5: Authentication State Preservation Test' as test_step;

-- Test if authentication context is maintained during complex queries
SELECT 
    '🔄 Auth Context Stability Test' as test_type,
    auth.uid() as auth_before_query,
    (
        SELECT auth.uid() 
        FROM warehouse_inventory wi 
        JOIN warehouses w ON wi.warehouse_id = w.id 
        WHERE wi.product_id = '131' 
        LIMIT 1
    ) as auth_during_query,
    auth.uid() as auth_after_query,
    CASE 
        WHEN auth.uid() IS NULL THEN '❌ Authentication context is NULL'
        WHEN (SELECT auth.uid() FROM warehouse_inventory wi JOIN warehouses w ON wi.warehouse_id = w.id WHERE wi.product_id = '131' LIMIT 1) IS NULL THEN '❌ Authentication lost during query'
        ELSE '✅ Authentication context preserved'
    END as stability_status;

SELECT '🎉 Inventory Deduction Authentication Verification Completed!' as test_status;
