-- 🧪 DEBUG CARTON CALCULATION ACCESS FOR ALL USER ROLES
-- This script tests carton calculation access and data for Admin, Accountant, and Business Owner roles

-- =====================================================
-- STEP 1: CURRENT USER VERIFICATION
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
-- STEP 2: TEST WAREHOUSE_INVENTORY ACCESS
-- =====================================================

SELECT '📦 === WAREHOUSE INVENTORY ACCESS TEST ===' as test_step;

-- Test basic access to warehouse_inventory table
SELECT 
    '📦 BASIC INVENTORY ACCESS' as access_test,
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

-- =====================================================
-- STEP 3: DETAILED CARTON CALCULATION TEST
-- =====================================================

SELECT '🧮 === DETAILED CARTON CALCULATION TEST ===' as test_step;

-- Sample carton calculations with detailed breakdown
SELECT 
    '🧮 SAMPLE CARTON CALCULATIONS' as calculation_test,
    wi.warehouse_id,
    w.name as warehouse_name,
    wi.product_id,
    wi.quantity,
    wi.quantity_per_carton,
    CASE 
        WHEN wi.quantity_per_carton > 0 THEN CEIL(wi.quantity::DECIMAL / wi.quantity_per_carton)
        ELSE 0
    END as calculated_cartons,
    CASE 
        WHEN wi.quantity_per_carton > 0 THEN 
            CONCAT(wi.quantity, ' ÷ ', wi.quantity_per_carton, ' = ', CEIL(wi.quantity::DECIMAL / wi.quantity_per_carton), ' كرتونة')
        ELSE 'لا يمكن حساب الكراتين'
    END as calculation_formula
FROM warehouse_inventory wi
LEFT JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.quantity > 0 AND wi.quantity_per_carton > 0
ORDER BY wi.warehouse_id, wi.product_id
LIMIT 10;

-- =====================================================
-- STEP 4: WAREHOUSE-LEVEL CARTON AGGREGATION TEST
-- =====================================================

SELECT '🏭 === WAREHOUSE-LEVEL CARTON AGGREGATION TEST ===' as test_step;

-- Test warehouse-level carton totals (this is what should appear in warehouse cards)
SELECT 
    '🏭 WAREHOUSE CARTON TOTALS' as aggregation_test,
    w.id as warehouse_id,
    w.name as warehouse_name,
    COUNT(wi.id) as total_products,
    COALESCE(SUM(wi.quantity), 0) as total_quantity,
    COALESCE(SUM(
        CASE 
            WHEN wi.quantity_per_carton > 0 THEN CEIL(wi.quantity::DECIMAL / wi.quantity_per_carton)
            ELSE 0
        END
    ), 0) as total_cartons,
    CASE 
        WHEN COALESCE(SUM(
            CASE 
                WHEN wi.quantity_per_carton > 0 THEN CEIL(wi.quantity::DECIMAL / wi.quantity_per_carton)
                ELSE 0
            END
        ), 0) > 0 THEN '✅ CARTONS CALCULATED'
        ELSE '❌ NO CARTONS'
    END as carton_status
FROM warehouses w
LEFT JOIN warehouse_inventory wi ON w.id = wi.warehouse_id
WHERE w.is_active = true
GROUP BY w.id, w.name
ORDER BY w.name;

-- =====================================================
-- STEP 5: RLS POLICY VERIFICATION
-- =====================================================

SELECT '🛡️ === RLS POLICY VERIFICATION ===' as test_step;

-- Check current RLS policies for warehouse_inventory
SELECT 
    '🛡️ WAREHOUSE_INVENTORY POLICIES' as policy_check,
    policyname,
    cmd as operation,
    CASE 
        WHEN qual LIKE '%admin%' AND qual LIKE '%accountant%' AND qual LIKE '%owner%' THEN '✅ ALL ROLES INCLUDED'
        WHEN qual LIKE '%admin%' OR qual LIKE '%accountant%' OR qual LIKE '%owner%' THEN '⚠️ PARTIAL ROLES'
        ELSE '❌ MISSING ROLES'
    END as role_coverage,
    CASE 
        WHEN qual LIKE '%approved%' THEN '✅ APPROVAL CHECK'
        ELSE '⚠️ NO APPROVAL CHECK'
    END as approval_check
FROM pg_policies 
WHERE tablename = 'warehouse_inventory'
AND schemaname = 'public'
ORDER BY cmd, policyname;

-- =====================================================
-- STEP 6: COMPREHENSIVE ACCESS SUMMARY
-- =====================================================

SELECT '📊 === COMPREHENSIVE ACCESS SUMMARY ===' as summary_step;

-- Create a comprehensive access report
WITH access_summary AS (
    SELECT 
        (SELECT COUNT(*) FROM warehouses WHERE is_active = true) as active_warehouse_count,
        (SELECT COUNT(*) FROM warehouse_inventory) as inventory_count,
        (SELECT COUNT(*) FROM warehouse_inventory WHERE quantity > 0 AND quantity_per_carton > 0) as carton_calculable_count,
        (SELECT SUM(
            CASE 
                WHEN quantity_per_carton > 0 THEN CEIL(quantity::DECIMAL / quantity_per_carton)
                ELSE 0
            END
        ) FROM warehouse_inventory WHERE quantity > 0) as total_system_cartons
),
user_info AS (
    SELECT 
        COALESCE(role, 'unknown') as user_role,
        COALESCE(status, 'unknown') as user_status,
        COALESCE(name, 'unknown') as user_name
    FROM user_profiles 
    WHERE id = auth.uid()
)
SELECT 
    '📊 FINAL ACCESS SUMMARY' as summary_type,
    ui.user_name,
    ui.user_role,
    ui.user_status,
    acs.active_warehouse_count,
    acs.inventory_count,
    acs.carton_calculable_count,
    acs.total_system_cartons,
    CASE 
        WHEN ui.user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND ui.user_status = 'approved'
            AND acs.active_warehouse_count > 0 AND acs.carton_calculable_count > 0
        THEN '✅ FULL CARTON ACCESS - SHOULD WORK'
        WHEN ui.user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND ui.user_status = 'approved'
            AND acs.active_warehouse_count > 0 AND acs.carton_calculable_count = 0
        THEN '⚠️ ACCESS OK BUT NO CARTON DATA'
        WHEN ui.user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND ui.user_status != 'approved'
        THEN '❌ ROLE OK BUT USER NOT APPROVED'
        WHEN ui.user_role NOT IN ('admin', 'owner', 'accountant', 'warehouseManager')
        THEN '❌ ROLE DOES NOT HAVE WAREHOUSE ACCESS'
        ELSE '❌ UNKNOWN ISSUE'
    END as overall_diagnosis,
    CASE 
        WHEN ui.user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND ui.user_status = 'approved'
            AND acs.active_warehouse_count > 0 AND acs.carton_calculable_count > 0
        THEN 'Carton totals should display in warehouse cards. If not, check Flutter app data binding.'
        WHEN ui.user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND ui.user_status = 'approved'
            AND acs.active_warehouse_count > 0 AND acs.carton_calculable_count = 0
        THEN 'Add products with quantity_per_carton > 0 to warehouses to see carton totals.'
        WHEN ui.user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND ui.user_status != 'approved'
        THEN 'User needs approval in user_profiles table (status = approved).'
        WHEN ui.user_role NOT IN ('admin', 'owner', 'accountant', 'warehouseManager')
        THEN 'User role needs to be admin, owner, accountant, or warehouseManager.'
        ELSE 'Check authentication and user_profiles table data.'
    END as recommendation
FROM access_summary acs, user_info ui;

SELECT '🎯 === CARTON CALCULATION ACCESS DEBUG COMPLETED ===' as completion_message;
