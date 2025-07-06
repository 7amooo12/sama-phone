-- =====================================================
-- TEST UUID FUNCTION DEPLOYMENT
-- =====================================================
-- This script tests the deployment of the new UUID-fixed function

-- Test 1: Check if the function exists
SELECT 
    routine_name,
    routine_type,
    security_type
FROM information_schema.routines 
WHERE routine_name = 'deduct_inventory_with_validation_v2'
    AND routine_schema = 'public';

-- Test 2: Test function with valid UUID parameters
SELECT 'Testing function with valid parameters...' as test_step;

SELECT deduct_inventory_with_validation_v2(
    '338d5af4-88ad-49cb-aec6-456ac6bd318c',  -- valid warehouse UUID
    '190',                                    -- product ID
    1,                                        -- quantity
    '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',  -- valid user UUID
    'Test UUID function deployment',          -- reason
    'test-deployment-' || extract(epoch from now())::text,  -- reference ID
    'test'                                    -- reference type
) as test_result;

-- Test 3: Test function with invalid warehouse UUID (should return error)
SELECT 'Testing function with invalid warehouse UUID...' as test_step;

SELECT deduct_inventory_with_validation_v2(
    'invalid-warehouse-id',                  -- invalid warehouse UUID
    '190',                                    -- product ID
    1,                                        -- quantity
    '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',  -- valid user UUID
    'Test invalid warehouse UUID',           -- reason
    'test-invalid-warehouse',                -- reference ID
    'test'                                    -- reference type
) as test_result;

-- Test 4: Test function with invalid user UUID (should return error)
SELECT 'Testing function with invalid user UUID...' as test_step;

SELECT deduct_inventory_with_validation_v2(
    '338d5af4-88ad-49cb-aec6-456ac6bd318c',  -- valid warehouse UUID
    '190',                                    -- product ID
    1,                                        -- quantity
    'invalid-user-id',                       -- invalid user UUID
    'Test invalid user UUID',               -- reason
    'test-invalid-user',                     -- reference ID
    'test'                                    -- reference type
) as test_result;

-- Test 5: Check warehouse_transactions table schema
SELECT 'Checking warehouse_transactions table schema...' as info;

SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'warehouse_transactions'
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- Test 6: Check warehouse inventory before and after
SELECT 'Current inventory for product 190...' as info;

SELECT 
    wi.warehouse_id,
    w.name as warehouse_name,
    wi.product_id,
    wi.quantity,
    wi.minimum_stock,
    wi.last_updated
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '190'
    AND w.is_active = true
ORDER BY wi.quantity DESC;

-- Test 7: Check recent transactions
SELECT 'Recent transactions for product 190...' as info;

SELECT
    wt.transaction_number,
    wt.warehouse_id,
    w.name as warehouse_name,
    wt.product_id,
    wt.quantity,
    wt.quantity_before,
    wt.quantity_after,
    wt.reason,
    wt.created_at
FROM warehouse_transactions wt
JOIN warehouses w ON wt.warehouse_id = w.id
WHERE wt.product_id = '190'
    AND wt.created_at >= NOW() - INTERVAL '1 hour'
ORDER BY wt.created_at DESC
LIMIT 10;

SELECT 'UUID function deployment test completed!' as status;
