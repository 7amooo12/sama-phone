-- 🔍 COMPREHENSIVE DIAGNOSTIC: Product ID "131" Inventory Investigation
-- Investigate why product ID "131" (B713) shows quantity = 0 in warehouse inventory
-- Based on logs: Found 1 record in warehouse 338d5af4-88ad-49cb-aec6-456ac6bd318c with quantity: 0

-- =====================================================
-- STEP 1: VERIFY CURRENT INVENTORY DATA
-- =====================================================

SELECT '🔍 STEP 1: Current Inventory Data for Product 131' as diagnostic_step;

-- Check all warehouse_inventory records for product 131
SELECT 
    '📦 Warehouse Inventory Records for Product 131' as info,
    wi.id as inventory_record_id,
    wi.warehouse_id,
    wi.product_id,
    wi.quantity,
    wi.minimum_stock,
    wi.maximum_stock,
    wi.last_updated,
    wi.updated_by,
    w.name as warehouse_name,
    w.is_active as warehouse_active,
    w.address as warehouse_address
FROM warehouse_inventory wi
LEFT JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '131'
ORDER BY wi.last_updated DESC;

-- Check the specific warehouse mentioned in logs
SELECT 
    '🏪 Specific Warehouse Check: 338d5af4-88ad-49cb-aec6-456ac6bd318c' as info,
    wi.*,
    w.name as warehouse_name,
    w.is_active,
    w.address
FROM warehouse_inventory wi
LEFT JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'
    AND wi.product_id = '131';

-- =====================================================
-- STEP 2: CHECK WAREHOUSE STATUS
-- =====================================================

SELECT '🏪 STEP 2: Warehouse Status Check' as diagnostic_step;

-- Verify warehouse is active
SELECT 
    '✅ Warehouse Active Status' as info,
    id,
    name,
    is_active,
    address,
    created_at,
    updated_at
FROM warehouses 
WHERE id = '338d5af4-88ad-49cb-aec6-456ac6bd318c';

-- Check all warehouses that have product 131
SELECT 
    '📋 All Warehouses with Product 131' as info,
    w.id,
    w.name,
    w.is_active,
    wi.quantity,
    wi.last_updated
FROM warehouses w
JOIN warehouse_inventory wi ON w.id = wi.warehouse_id
WHERE wi.product_id = '131'
ORDER BY wi.quantity DESC;

-- =====================================================
-- STEP 3: PRODUCT DATA VERIFICATION
-- =====================================================

SELECT '📦 STEP 3: Product Data Verification' as diagnostic_step;

-- Check if product exists in products table
SELECT 
    '🔍 Product Table Check for ID 131' as info,
    p.*
FROM products p
WHERE p.id = '131';

-- Check for alternative product IDs (B713)
SELECT 
    '🔍 Alternative Product ID Check (B713)' as info,
    p.*
FROM products p
WHERE p.id = 'B713' 
    OR p.sku = 'B713' 
    OR p.name ILIKE '%B713%'
    OR p.barcode = 'B713';

-- =====================================================
-- STEP 4: INVENTORY HISTORY ANALYSIS
-- =====================================================

SELECT '📊 STEP 4: Inventory History Analysis' as diagnostic_step;

-- Check for any inventory transactions or updates
SELECT 
    '📈 Recent Inventory Updates for Product 131' as info,
    wi.warehouse_id,
    wi.product_id,
    wi.quantity,
    wi.last_updated,
    wi.updated_by,
    w.name as warehouse_name
FROM warehouse_inventory wi
LEFT JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '131'
ORDER BY wi.last_updated DESC;

-- Check if there are any audit logs or transaction records
-- (This assumes you have audit tables - adjust table names as needed)
SELECT 
    '📋 Checking for Audit/Transaction Records' as info,
    COUNT(*) as audit_records_found
FROM information_schema.tables 
WHERE table_name IN ('inventory_transactions', 'audit_log', 'warehouse_transactions')
    AND table_schema = 'public';

-- =====================================================
-- STEP 5: GLOBAL SEARCH SIMULATION
-- =====================================================

SELECT '🔍 STEP 5: Global Search Logic Simulation' as diagnostic_step;

-- Simulate the exact query used by GlobalInventoryService
SELECT 
    '🎯 Simulating Global Inventory Search Query' as info,
    wi.id,
    wi.warehouse_id,
    wi.product_id,
    wi.quantity,
    wi.minimum_stock,
    wi.maximum_stock,
    wi.last_updated,
    w.id as warehouse_table_id,
    w.name as warehouse_name,
    w.address,
    w.is_active,
    w.created_at as warehouse_created
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '131'
    AND w.is_active = true
    AND wi.quantity > 0;  -- This is the critical filter

-- Check what happens without the quantity > 0 filter
SELECT 
    '📊 Same Query WITHOUT quantity > 0 filter' as info,
    wi.id,
    wi.warehouse_id,
    wi.product_id,
    wi.quantity,
    wi.minimum_stock,
    wi.maximum_stock,
    wi.last_updated,
    w.name as warehouse_name,
    w.is_active
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '131'
    AND w.is_active = true;

-- =====================================================
-- STEP 6: RLS POLICY VERIFICATION
-- =====================================================

SELECT '🔒 STEP 6: RLS Policy Verification' as diagnostic_step;

-- Check current user and role
SELECT 
    '👤 Current User Context' as info,
    auth.uid() as current_user_id,
    up.email,
    up.name,
    up.role,
    up.status
FROM user_profiles up
WHERE up.id = auth.uid();

-- Test RLS policies by checking if we can see warehouse_inventory
SELECT 
    '🔒 RLS Policy Test - Can we see warehouse_inventory?' as info,
    COUNT(*) as total_inventory_records_visible
FROM warehouse_inventory;

-- Test specific warehouse access
SELECT 
    '🔒 RLS Policy Test - Specific warehouse access' as info,
    COUNT(*) as records_in_specific_warehouse
FROM warehouse_inventory wi
WHERE wi.warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c';

-- =====================================================
-- STEP 7: RECOMMENDATIONS BASED ON FINDINGS
-- =====================================================

SELECT '💡 STEP 7: Diagnostic Summary and Recommendations' as diagnostic_step;

-- Summary query to understand the issue
WITH inventory_summary AS (
    SELECT 
        wi.product_id,
        COUNT(*) as total_records,
        SUM(wi.quantity) as total_quantity,
        COUNT(CASE WHEN wi.quantity > 0 THEN 1 END) as records_with_stock,
        COUNT(CASE WHEN w.is_active = true THEN 1 END) as active_warehouses,
        COUNT(CASE WHEN w.is_active = true AND wi.quantity > 0 THEN 1 END) as active_warehouses_with_stock
    FROM warehouse_inventory wi
    LEFT JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE wi.product_id = '131'
    GROUP BY wi.product_id
)
SELECT 
    '📊 DIAGNOSTIC SUMMARY for Product 131' as summary,
    *,
    CASE 
        WHEN total_quantity = 0 THEN '❌ NO STOCK: Product has zero quantity in all warehouses'
        WHEN active_warehouses_with_stock = 0 THEN '⚠️ INACTIVE WAREHOUSES: Stock exists but warehouses are inactive'
        WHEN records_with_stock > 0 THEN '✅ STOCK AVAILABLE: Check query filters'
        ELSE '❓ UNKNOWN ISSUE: Further investigation needed'
    END as diagnosis
FROM inventory_summary;

-- Final recommendation
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM warehouse_inventory wi 
            JOIN warehouses w ON wi.warehouse_id = w.id 
            WHERE wi.product_id = '131' AND w.is_active = true AND wi.quantity > 0
        ) THEN '✅ SOLUTION: Stock is available - check application query logic'
        WHEN EXISTS (
            SELECT 1 FROM warehouse_inventory wi 
            WHERE wi.product_id = '131' AND wi.quantity > 0
        ) THEN '⚠️ SOLUTION: Stock exists but warehouses are inactive - activate warehouses'
        WHEN EXISTS (
            SELECT 1 FROM warehouse_inventory wi 
            WHERE wi.product_id = '131'
        ) THEN '❌ SOLUTION: Product exists but has zero stock - replenish inventory'
        ELSE '❓ SOLUTION: Product not found in inventory - add product to warehouse inventory'
    END as recommended_action;
