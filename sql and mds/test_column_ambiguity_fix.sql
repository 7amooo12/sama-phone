-- =====================================================
-- TEST COLUMN AMBIGUITY FIX
-- =====================================================
-- This script tests the fix for the "column reference minimum_stock is ambiguous" error

-- Test 1: Check if the new function exists
SELECT 'Test 1: Checking if v3 function exists...' as test_step;

SELECT 
    routine_name,
    routine_type,
    security_type,
    'Function v3 exists and ready for testing' as status
FROM information_schema.routines 
WHERE routine_name = 'deduct_inventory_with_validation_v3'
    AND routine_schema = 'public'
UNION ALL
SELECT 
    'deduct_inventory_with_validation_v3' as routine_name,
    'NOT FOUND' as routine_type,
    'N/A' as security_type,
    'Function v3 does not exist - deployment needed' as status
WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_name = 'deduct_inventory_with_validation_v3'
        AND routine_schema = 'public'
);

-- Test 2: Check warehouse and product data
SELECT 'Test 2: Checking test data availability...' as test_step;

-- Check warehouse
SELECT 
    'Warehouse' as data_type,
    w.id,
    w.name,
    w.is_active,
    'Warehouse available for testing' as status
FROM warehouses w
WHERE w.id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'
UNION ALL
SELECT 
    'Warehouse' as data_type,
    '338d5af4-88ad-49cb-aec6-456ac6bd318c' as id,
    'NOT FOUND' as name,
    false as is_active,
    'Test warehouse not found' as status
WHERE NOT EXISTS (
    SELECT 1 FROM warehouses 
    WHERE id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'
);

-- Check inventory
SELECT 
    'Inventory' as data_type,
    wi.warehouse_id::text as id,
    w.name,
    wi.quantity > 0 as is_active,
    'Product inventory: ' || wi.quantity || ' available, minimum: ' || COALESCE(wi.minimum_stock, 0) as status
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'
    AND wi.product_id = '190'
UNION ALL
SELECT 
    'Inventory' as data_type,
    '338d5af4-88ad-49cb-aec6-456ac6bd318c' as id,
    'Product 190' as name,
    false as is_active,
    'No inventory record found for product 190' as status
WHERE NOT EXISTS (
    SELECT 1 FROM warehouse_inventory 
    WHERE warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'
        AND product_id = '190'
);

-- Test 3: Test the function with small quantity (safe test)
SELECT 'Test 3: Testing function with small quantity...' as test_step;

-- Test with quantity 1 to avoid affecting large inventory
SELECT deduct_inventory_with_validation_v3(
    '338d5af4-88ad-49cb-aec6-456ac6bd318c',  -- warehouse ID (test)
    '190',                                    -- product ID (توزيع ذكي)
    1,                                        -- small quantity for testing
    '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',  -- performed by
    'Test column ambiguity fix - small quantity',  -- reason
    '07ba6659-4a68-4019-8e35-5f9609ec0d98',  -- reference ID
    'test_column_fix'                         -- reference type
) as small_quantity_test_result;

-- Test 4: Test with the exact failing parameters (if inventory allows)
SELECT 'Test 4: Testing with exact failing parameters...' as test_step;

-- Only run this test if there's sufficient inventory
DO $$
DECLARE
    available_qty INTEGER;
    test_result JSONB;
BEGIN
    -- Check available quantity
    SELECT COALESCE(wi.quantity, 0) INTO available_qty
    FROM warehouse_inventory wi
    WHERE wi.warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'::UUID
        AND wi.product_id = '190';
    
    RAISE NOTICE 'Available quantity: %', available_qty;
    
    IF available_qty >= 20 THEN
        RAISE NOTICE 'Testing with full quantity (20)...';
        
        SELECT deduct_inventory_with_validation_v3(
            '338d5af4-88ad-49cb-aec6-456ac6bd318c',  -- warehouse ID
            '190',                                    -- product ID
            20,                                       -- exact failing quantity
            '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',  -- performed by
            'Test column ambiguity fix - full quantity',  -- reason
            '07ba6659-4a68-4019-8e35-5f9609ec0d98',  -- reference ID
            'dispatch_release_order'                  -- reference type
        ) INTO test_result;
        
        RAISE NOTICE 'Full quantity test result: %', test_result;
        
        IF test_result->>'success' = 'true' THEN
            RAISE NOTICE '✅ Column ambiguity fix successful - full quantity test passed';
        ELSE
            RAISE NOTICE '❌ Full quantity test failed: %', test_result->>'error';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ Insufficient inventory (%) for full quantity test (20)', available_qty;
    END IF;
END $$;

-- Test 5: Check recent transactions to verify logging
SELECT 'Test 5: Checking recent transactions...' as test_step;

SELECT 
    wt.transaction_number,
    wt.warehouse_id,
    wt.product_id,
    wt.quantity,
    wt.quantity_before,
    wt.quantity_after,
    wt.reason,
    wt.created_at
FROM warehouse_transactions wt
WHERE wt.warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'::UUID
    AND wt.product_id = '190'
    AND wt.created_at >= NOW() - INTERVAL '10 minutes'
ORDER BY wt.created_at DESC
LIMIT 5;

-- Test 6: Verify current inventory state
SELECT 'Test 6: Current inventory state after tests...' as test_step;

SELECT 
    wi.warehouse_id,
    w.name as warehouse_name,
    wi.product_id,
    wi.quantity,
    wi.minimum_stock,
    wi.last_updated,
    wi.updated_by
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'
    AND wi.product_id = '190';

-- Test 7: Summary
SELECT 'Test 7: Column ambiguity fix test summary...' as test_step;

SELECT 
    'Column Ambiguity Fix Test' as test_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'deduct_inventory_with_validation_v3'
        ) THEN '✅ FUNCTION DEPLOYED'
        ELSE '❌ FUNCTION MISSING'
    END as function_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM warehouses 
            WHERE id = '338d5af4-88ad-49cb-aec6-456ac6bd318c' 
                AND is_active = true
        ) THEN '✅ WAREHOUSE AVAILABLE'
        ELSE '⚠️ WAREHOUSE ISSUE'
    END as warehouse_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM warehouse_inventory 
            WHERE warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'::UUID
                AND product_id = '190' 
                AND quantity > 0
        ) THEN '✅ INVENTORY AVAILABLE'
        ELSE '⚠️ NO INVENTORY'
    END as inventory_status,
    NOW() as test_completed_at;

SELECT 'Column ambiguity fix test completed!' as final_status;
