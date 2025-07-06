-- 🧪 TEST: Authentication Context Fix for Inventory Search
-- Test that auth.uid() returns the correct user ID during database queries
-- This should resolve the RLS policy blocking issue for Product ID "131"

-- =====================================================
-- STEP 1: VERIFY CURRENT AUTH CONTEXT
-- =====================================================

SELECT '🔍 STEP 1: Current Authentication Context' as test_step;

-- Check current user context
SELECT 
    '👤 Current Auth Context' as test_type,
    auth.uid() as current_user_id,
    CASE 
        WHEN auth.uid() IS NULL THEN '❌ NULL - RLS policies will block access'
        ELSE '✅ Valid - RLS policies should work'
    END as auth_status;

-- Check user profile access
SELECT 
    '👤 User Profile Access Test' as test_type,
    up.id,
    up.email,
    up.name,
    up.role,
    up.status
FROM user_profiles up
WHERE up.id = auth.uid();

-- =====================================================
-- STEP 2: TEST WAREHOUSE_INVENTORY ACCESS
-- =====================================================

SELECT '📦 STEP 2: Warehouse Inventory Access Test' as test_step;

-- Test basic warehouse_inventory access
SELECT 
    '📦 Basic Inventory Access' as test_type,
    COUNT(*) as total_records_visible
FROM warehouse_inventory;

-- Test specific product access (Product ID "131")
SELECT 
    '🎯 Product 131 Access Test' as test_type,
    wi.id,
    wi.warehouse_id,
    wi.product_id,
    wi.quantity,
    wi.last_updated
FROM warehouse_inventory wi
WHERE wi.product_id = '131';

-- =====================================================
-- STEP 3: TEST GLOBAL INVENTORY QUERY
-- =====================================================

SELECT '🌍 STEP 3: Global Inventory Query Test' as test_step;

-- Test the exact query used by GlobalInventoryService
SELECT 
    '🔍 GlobalInventoryService Query Simulation' as test_type,
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
    AND wi.quantity > 0;

-- Test with LEFT JOIN for products (as modified in the service)
SELECT 
    '🔗 With Products LEFT JOIN Test' as test_type,
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

-- =====================================================
-- STEP 4: RLS POLICY VERIFICATION
-- =====================================================

SELECT '🔒 STEP 4: RLS Policy Verification' as test_step;

-- Check if RLS is enabled on warehouse_inventory
SELECT 
    '🔒 RLS Status Check' as test_type,
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename = 'warehouse_inventory';

-- List active RLS policies on warehouse_inventory
SELECT 
    '📋 Active RLS Policies' as test_type,
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'warehouse_inventory';

-- =====================================================
-- STEP 5: COMPREHENSIVE DIAGNOSIS
-- =====================================================

SELECT '💡 STEP 5: Comprehensive Diagnosis' as test_step;

-- Final diagnosis query
WITH auth_check AS (
    SELECT 
        auth.uid() IS NOT NULL as has_auth_context,
        EXISTS(SELECT 1 FROM user_profiles WHERE id = auth.uid()) as user_profile_exists,
        (SELECT role FROM user_profiles WHERE id = auth.uid()) as user_role,
        (SELECT status FROM user_profiles WHERE id = auth.uid()) as user_status
),
inventory_check AS (
    SELECT 
        EXISTS(SELECT 1 FROM warehouse_inventory WHERE product_id = '131') as product_exists,
        EXISTS(SELECT 1 FROM warehouse_inventory wi JOIN warehouses w ON wi.warehouse_id = w.id WHERE wi.product_id = '131' AND w.is_active = true) as active_warehouse_exists,
        EXISTS(SELECT 1 FROM warehouse_inventory wi JOIN warehouses w ON wi.warehouse_id = w.id WHERE wi.product_id = '131' AND w.is_active = true AND wi.quantity > 0) as has_available_stock
)
SELECT 
    '🎯 FINAL DIAGNOSIS' as result,
    ac.*,
    ic.*,
    CASE 
        WHEN NOT ac.has_auth_context THEN '❌ CRITICAL: No auth context - RLS blocking access'
        WHEN NOT ac.user_profile_exists THEN '❌ CRITICAL: User profile not found'
        WHEN ac.user_role NOT IN ('admin', 'owner', 'accountant', 'warehouseManager') THEN '❌ CRITICAL: Insufficient role permissions'
        WHEN ac.user_status != 'approved' THEN '❌ CRITICAL: User status not approved'
        WHEN NOT ic.product_exists THEN '❌ DATA: Product 131 not found in inventory'
        WHEN NOT ic.active_warehouse_exists THEN '⚠️ DATA: Product exists but no active warehouses'
        WHEN NOT ic.has_available_stock THEN '⚠️ DATA: Product exists but no available stock'
        ELSE '✅ SUCCESS: All conditions met - inventory search should work'
    END as diagnosis
FROM auth_check ac, inventory_check ic;

-- =====================================================
-- STEP 6: EXPECTED RESULTS
-- =====================================================

SELECT '📊 STEP 6: Expected Results Summary' as test_step;

-- What we expect to see for a successful fix:
SELECT 
    '✅ Expected Results for Successful Fix:' as summary,
    '1. auth.uid() should return a valid UUID' as check_1,
    '2. User profile should be found with appropriate role' as check_2,
    '3. warehouse_inventory should show records for product 131' as check_3,
    '4. Global inventory query should return available stock' as check_4,
    '5. Final diagnosis should show SUCCESS status' as check_5;

-- Test completion message
SELECT '🎉 Authentication Context Fix Test Completed!' as test_status;
