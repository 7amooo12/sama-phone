-- 🚨 CRITICAL INVESTIGATION: Why Product 131 Inventory Record is Not Accessible
-- Based on CSV data: Record EXISTS with sufficient quantity (4 units)
-- Record ID: e8acfbb6-b94d-4219-abf4-8912a23892a9
-- Warehouse ID: 338d5af4-88ad-49cb-aec6-456ac6bd318c
-- Product ID: 131, Quantity: 4

-- =====================================================
-- STEP 1: VERIFY RECORD EXISTS IN DATABASE
-- =====================================================

SELECT '🔍 STEP 1: Verify Record Exists' as investigation_step;

-- Direct query for the specific inventory record
SELECT 
    '📦 Direct Record Query' as test_type,
    *
FROM warehouse_inventory 
WHERE id = 'e8acfbb6-b94d-4219-abf4-8912a23892a9';

-- Query by product ID
SELECT 
    '🎯 Product ID Query' as test_type,
    *
FROM warehouse_inventory 
WHERE product_id = '131';

-- Query by warehouse and product combination
SELECT 
    '🏪 Warehouse + Product Query' as test_type,
    *
FROM warehouse_inventory 
WHERE warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'
    AND product_id = '131';

-- =====================================================
-- STEP 2: CHECK WAREHOUSE STATUS
-- =====================================================

SELECT '🏪 STEP 2: Warehouse Status Check' as investigation_step;

-- Verify warehouse is active
SELECT 
    '✅ Warehouse Active Status' as test_type,
    id,
    name,
    is_active,
    address,
    created_at
FROM warehouses 
WHERE id = '338d5af4-88ad-49cb-aec6-456ac6bd318c';

-- =====================================================
-- STEP 3: TEST EXACT GLOBAL INVENTORY QUERY
-- =====================================================

SELECT '🎯 STEP 3: Test Exact Global Inventory Query' as investigation_step;

-- Simulate the exact query from GlobalInventoryService
SELECT 
    '🔍 Exact GlobalInventoryService Query' as test_type,
    wi.id,
    wi.warehouse_id,
    wi.product_id,
    wi.quantity,
    wi.minimum_stock,
    wi.maximum_stock,
    wi.last_updated,
    w.id as warehouse_table_id,
    w.name,
    w.address,
    w.is_active,
    w.created_at
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '131'
    AND w.is_active = true
    AND wi.quantity > 0;

-- Test with INNER JOIN (as used in the service)
SELECT 
    '🔗 INNER JOIN Test' as test_type,
    wi.id,
    wi.warehouse_id,
    wi.product_id,
    wi.quantity,
    w.name as warehouse_name,
    w.is_active
FROM warehouse_inventory wi
INNER JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '131'
    AND w.is_active = true
    AND wi.quantity > 0;

-- =====================================================
-- STEP 4: RLS POLICY INVESTIGATION
-- =====================================================

SELECT '🔒 STEP 4: RLS Policy Investigation' as investigation_step;

-- Check current user context
SELECT 
    '👤 Current User Context' as test_type,
    auth.uid() as current_user_id;

-- Check user profile and permissions
SELECT 
    '👤 User Profile Check' as test_type,
    up.id,
    up.email,
    up.name,
    up.role,
    up.status
FROM user_profiles up
WHERE up.id = auth.uid();

-- Test RLS bypass with SECURITY DEFINER function
CREATE OR REPLACE FUNCTION test_inventory_access_bypass()
RETURNS TABLE (
    inventory_id UUID,
    warehouse_id UUID,
    product_id TEXT,
    quantity INTEGER,
    warehouse_name TEXT,
    warehouse_active BOOLEAN
) 
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wi.id as inventory_id,
        wi.warehouse_id,
        wi.product_id,
        wi.quantity,
        w.name as warehouse_name,
        w.is_active as warehouse_active
    FROM warehouse_inventory wi
    LEFT JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE wi.product_id = '131';
END;
$$ LANGUAGE plpgsql;

-- Test the bypass function
SELECT 
    '🔓 RLS Bypass Test' as test_type,
    *
FROM test_inventory_access_bypass();

-- =====================================================
-- STEP 5: DATA TYPE INVESTIGATION
-- =====================================================

SELECT '🔢 STEP 5: Data Type Investigation' as investigation_step;

-- Check data types of key columns
SELECT 
    '📊 Column Data Types' as test_type,
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE (table_name = 'warehouse_inventory' AND column_name IN ('product_id', 'warehouse_id'))
    OR (table_name = 'warehouses' AND column_name = 'id')
    OR (table_name = 'products' AND column_name = 'id')
ORDER BY table_name, column_name;

-- Test type conversion issues
SELECT 
    '🔄 Type Conversion Test' as test_type,
    wi.product_id,
    wi.product_id::TEXT as product_id_as_text,
    wi.warehouse_id,
    wi.warehouse_id::TEXT as warehouse_id_as_text,
    wi.quantity
FROM warehouse_inventory wi
WHERE wi.product_id = '131';

-- =====================================================
-- STEP 6: PRODUCTS TABLE JOIN TEST
-- =====================================================

SELECT '🔗 STEP 6: Products Table JOIN Test' as investigation_step;

-- Test LEFT JOIN with products table (as modified in the service)
SELECT 
    '🔗 LEFT JOIN with Products Test' as test_type,
    wi.id,
    wi.warehouse_id,
    wi.product_id,
    wi.quantity,
    w.name as warehouse_name,
    w.is_active,
    p.id as product_table_id,
    p.name as product_name
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
LEFT JOIN products p ON wi.product_id = p.id
WHERE wi.product_id = '131'
    AND w.is_active = true
    AND wi.quantity > 0;

-- Test if products table has the record
SELECT 
    '📦 Products Table Check' as test_type,
    *
FROM products 
WHERE id = '131';

-- =====================================================
-- STEP 7: TRANSACTION ISOLATION TEST
-- =====================================================

SELECT '⚡ STEP 7: Transaction Isolation Test' as investigation_step;

-- Test if the issue is related to transaction isolation
BEGIN;

SELECT 
    '🔒 Within Transaction Test' as test_type,
    wi.id,
    wi.warehouse_id,
    wi.product_id,
    wi.quantity,
    w.name as warehouse_name,
    w.is_active
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '131'
    AND w.is_active = true
    AND wi.quantity > 0;

COMMIT;

-- =====================================================
-- STEP 8: FINAL DIAGNOSIS
-- =====================================================

SELECT '💡 STEP 8: Final Diagnosis' as investigation_step;

-- Comprehensive diagnosis query
WITH diagnosis AS (
    SELECT 
        EXISTS(SELECT 1 FROM warehouse_inventory WHERE product_id = '131') as record_exists,
        EXISTS(SELECT 1 FROM warehouses WHERE id = '338d5af4-88ad-49cb-aec6-456ac6bd318c' AND is_active = true) as warehouse_active,
        EXISTS(SELECT 1 FROM warehouse_inventory wi JOIN warehouses w ON wi.warehouse_id = w.id WHERE wi.product_id = '131' AND w.is_active = true AND wi.quantity > 0) as query_should_work,
        (SELECT COUNT(*) FROM warehouse_inventory WHERE product_id = '131') as total_records,
        (SELECT role FROM user_profiles WHERE id = auth.uid()) as current_user_role,
        (SELECT status FROM user_profiles WHERE id = auth.uid()) as current_user_status
)
SELECT 
    '🎯 FINAL DIAGNOSIS' as result,
    *,
    CASE 
        WHEN NOT record_exists THEN '❌ Record does not exist in database'
        WHEN NOT warehouse_active THEN '⚠️ Warehouse is not active'
        WHEN NOT query_should_work THEN '🔍 Query filters are preventing access'
        WHEN current_user_role NOT IN ('admin', 'owner', 'accountant', 'warehouseManager') THEN '🔒 User role insufficient'
        WHEN current_user_status != 'approved' THEN '🔒 User status not approved'
        ELSE '✅ Should work - investigate application code'
    END as diagnosis
FROM diagnosis;

-- Cleanup
DROP FUNCTION IF EXISTS test_inventory_access_bypass();
