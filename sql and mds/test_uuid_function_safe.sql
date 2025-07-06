-- =====================================================
-- SAFE UUID FUNCTION DEPLOYMENT TEST
-- =====================================================
-- This script safely tests the deployment of the new UUID-fixed function
-- with proper error handling and schema validation

-- Test 1: Check if the function exists
SELECT 'Test 1: Checking if function exists...' as test_step;

SELECT 
    routine_name,
    routine_type,
    security_type,
    'Function exists and is ready for use' as status
FROM information_schema.routines 
WHERE routine_name = 'deduct_inventory_with_validation_v2'
    AND routine_schema = 'public'
UNION ALL
SELECT 
    'deduct_inventory_with_validation_v2' as routine_name,
    'NOT FOUND' as routine_type,
    'N/A' as security_type,
    'Function does not exist - deployment needed' as status
WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_name = 'deduct_inventory_with_validation_v2'
        AND routine_schema = 'public'
);

-- Test 2: Check warehouse_transactions table schema
SELECT 'Test 2: Checking warehouse_transactions table schema...' as test_step;

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'warehouse_transactions' 
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- Test 3: Check if test warehouse and product exist
SELECT 'Test 3: Checking test data availability...' as test_step;

-- Check if test warehouse exists
SELECT 
    'Warehouse Check' as check_type,
    id,
    name,
    is_active,
    CASE 
        WHEN is_active THEN 'Available for testing'
        ELSE 'Warehouse exists but inactive'
    END as status
FROM warehouses 
WHERE id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'
UNION ALL
SELECT 
    'Warehouse Check' as check_type,
    '338d5af4-88ad-49cb-aec6-456ac6bd318c' as id,
    'NOT FOUND' as name,
    false as is_active,
    'Test warehouse not found' as status
WHERE NOT EXISTS (
    SELECT 1 FROM warehouses 
    WHERE id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'
);

-- Check if test product exists in inventory
SELECT 'Test 4: Checking product inventory...' as test_step;

SELECT 
    wi.warehouse_id,
    w.name as warehouse_name,
    wi.product_id,
    wi.quantity,
    COALESCE(wi.minimum_stock, 0) as minimum_stock,
    wi.last_updated,
    CASE 
        WHEN wi.quantity > 0 THEN 'Available for deduction test'
        ELSE 'No stock available for testing'
    END as test_status
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '190'
    AND w.is_active = true
ORDER BY wi.quantity DESC;

-- Test 5: Safe function test with minimal parameters
SELECT 'Test 5: Testing function with safe parameters...' as test_step;

-- Only test if the function exists
DO $$
DECLARE
    function_exists boolean;
    test_result jsonb;
BEGIN
    -- Check if function exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'deduct_inventory_with_validation_v2'
            AND routine_schema = 'public'
    ) INTO function_exists;
    
    IF function_exists THEN
        RAISE NOTICE 'Function exists, testing with minimal quantity...';
        
        -- Test with quantity 0 to avoid affecting real inventory
        SELECT deduct_inventory_with_validation_v2(
            '338d5af4-88ad-49cb-aec6-456ac6bd318c',  -- warehouse UUID
            '190',                                    -- product ID
            0,                                        -- quantity (0 for safe testing)
            '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',  -- user UUID
            'Safe deployment test - zero quantity',   -- reason
            'test-safe-' || extract(epoch from now())::text,  -- reference ID
            'deployment_test'                         -- reference type
        ) INTO test_result;
        
        RAISE NOTICE 'Test result: %', test_result;
        
        IF test_result->>'success' = 'false' AND test_result->>'error_detail' = 'INVALID_QUANTITY' THEN
            RAISE NOTICE '✅ Function working correctly - properly rejected zero quantity';
        ELSIF test_result->>'success' = 'false' THEN
            RAISE NOTICE '⚠️ Function returned error: %', test_result->>'error';
        ELSE
            RAISE NOTICE '✅ Function executed successfully';
        END IF;
    ELSE
        RAISE NOTICE '❌ Function does not exist - deployment required';
    END IF;
END $$;

-- Test 6: Check recent transactions (safe query)
SELECT 'Test 6: Checking recent transactions...' as test_step;

-- Use a safe query that only selects columns that commonly exist
SELECT 
    COALESCE(transaction_number, id::text) as transaction_ref,
    warehouse_id,
    product_id,
    quantity,
    reason,
    created_at
FROM warehouse_transactions
WHERE product_id = '190'
    AND created_at >= NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC
LIMIT 5;

-- Test 7: Summary
SELECT 'Test 7: Deployment test summary...' as test_step;

SELECT 
    'UUID Function Deployment Test' as test_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'deduct_inventory_with_validation_v2'
        ) THEN '✅ PASSED'
        ELSE '❌ FAILED'
    END as function_deployment_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM warehouses 
            WHERE id = '338d5af4-88ad-49cb-aec6-456ac6bd318c' 
                AND is_active = true
        ) THEN '✅ AVAILABLE'
        ELSE '⚠️ NOT AVAILABLE'
    END as test_warehouse_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM warehouse_inventory 
            WHERE product_id = '190' AND quantity > 0
        ) THEN '✅ AVAILABLE'
        ELSE '⚠️ NO STOCK'
    END as test_product_status,
    NOW() as test_completed_at;

SELECT 'UUID function deployment test completed!' as final_status;
