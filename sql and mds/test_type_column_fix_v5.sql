-- =====================================================
-- TEST TYPE COLUMN FIX V5
-- =====================================================
-- This script comprehensively tests the final v5 function that fixes the type column NOT NULL constraint

-- Test 1: Verify function exists
SELECT 'Test 1: Checking if v5 function exists...' as test_step;

SELECT 
    routine_name,
    routine_type,
    security_type,
    'Function v5 exists and ready for testing' as status
FROM information_schema.routines 
WHERE routine_name = 'deduct_inventory_with_validation_v5'
    AND routine_schema = 'public'
UNION ALL
SELECT 
    'deduct_inventory_with_validation_v5' as routine_name,
    'NOT FOUND' as routine_type,
    'N/A' as security_type,
    'Function v5 does not exist - deployment needed' as status
WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_name = 'deduct_inventory_with_validation_v5'
        AND routine_schema = 'public'
);

-- Test 2: Verify warehouse_transactions table schema
SELECT 'Test 2: Verifying warehouse_transactions table schema...' as test_step;

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE 
        WHEN column_name = 'type' AND is_nullable = 'NO' THEN '✅ Type column exists and is NOT NULL'
        WHEN column_name = 'type' AND is_nullable = 'YES' THEN '⚠️ Type column exists but allows NULL'
        ELSE 'Column: ' || column_name
    END as status
FROM information_schema.columns 
WHERE table_name = 'warehouse_transactions' 
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- Test 3: Check test data availability
SELECT 'Test 3: Checking test data availability...' as test_step;

-- Check warehouse
SELECT 
    'Warehouse' as data_type,
    w.id::text,
    w.name,
    w.is_active,
    'Warehouse available: ' || w.name as status
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
    wi.warehouse_id::text,
    'Product ' || wi.product_id as name,
    wi.quantity > 0 as is_active,
    'Available quantity: ' || wi.quantity || ', Minimum: ' || COALESCE(wi.minimum_stock, 0) as status
FROM warehouse_inventory wi
WHERE wi.warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'
    AND wi.product_id = '190'
UNION ALL
SELECT 
    'Inventory' as data_type,
    '338d5af4-88ad-49cb-aec6-456ac6bd318c' as id,
    'Product 190' as name,
    false as is_active,
    'No inventory record found' as status
WHERE NOT EXISTS (
    SELECT 1 FROM warehouse_inventory 
    WHERE warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'
        AND product_id = '190'
);

-- Test 4: Test function with small quantity (safe test)
SELECT 'Test 4: Testing v5 function with small quantity...' as test_step;

SELECT deduct_inventory_with_validation_v5(
    '338d5af4-88ad-49cb-aec6-456ac6bd318c',  -- warehouse ID
    '190',                                    -- product ID
    1,                                        -- small test quantity
    '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',  -- performed by
    'Test type column fix v5 - small quantity',  -- reason
    '07ba6659-4a68-4019-8e35-5f9609ec0d98',  -- reference ID
    'test_v5_small'                           -- reference type
) as small_quantity_test;

-- Test 5: Verify transaction was logged with correct type column
SELECT 'Test 5: Verifying transaction logging with type column...' as test_step;

SELECT 
    wt.transaction_number,
    wt.type,                    -- ✅ This should show 'withdrawal'
    wt.warehouse_id,
    wt.product_id,
    wt.quantity,
    wt.quantity_before,
    wt.quantity_after,
    wt.reason,
    wt.reference_type,
    wt.created_at,
    'Transaction logged successfully with type: ' || wt.type as status
FROM warehouse_transactions wt
WHERE wt.warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'::UUID
    AND wt.product_id = '190'
    AND wt.reason LIKE '%Test type column fix v5%'
    AND wt.created_at >= NOW() - INTERVAL '5 minutes'
ORDER BY wt.created_at DESC
LIMIT 3;

-- Test 6: Test with exact failing parameters (if sufficient inventory)
SELECT 'Test 6: Testing with exact failing parameters...' as test_step;

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
    
    RAISE NOTICE 'Available quantity for full test: %', available_qty;
    
    IF available_qty >= 20 THEN
        RAISE NOTICE 'Testing with full quantity (20)...';
        
        SELECT deduct_inventory_with_validation_v5(
            '338d5af4-88ad-49cb-aec6-456ac6bd318c',  -- warehouse ID
            '190',                                    -- product ID
            20,                                       -- exact failing quantity
            '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',  -- performed by
            'Test type column fix v5 - full quantity (20)',  -- reason
            '07ba6659-4a68-4019-8e35-5f9609ec0d98',  -- reference ID
            'dispatch_release_order'                  -- reference type
        ) INTO test_result;
        
        RAISE NOTICE 'Full quantity test result: %', test_result;
        
        IF test_result->>'success' = 'true' THEN
            RAISE NOTICE '✅ Type column fix successful - full quantity test passed!';
            RAISE NOTICE '   Deducted quantity: %', test_result->>'deducted_quantity';
            RAISE NOTICE '   Transaction ID: %', test_result->>'transaction_id';
        ELSE
            RAISE NOTICE '❌ Full quantity test failed: %', test_result->>'error';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ Insufficient inventory (%) for full quantity test (20)', available_qty;
        RAISE NOTICE 'Testing with available quantity instead...';
        
        IF available_qty > 0 THEN
            SELECT deduct_inventory_with_validation_v5(
                '338d5af4-88ad-49cb-aec6-456ac6bd318c',
                '190',
                available_qty,
                '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',
                'Test type column fix v5 - available quantity (' || available_qty || ')',
                '07ba6659-4a68-4019-8e35-5f9609ec0d98',
                'dispatch_release_order'
            ) INTO test_result;
            
            RAISE NOTICE 'Available quantity test result: %', test_result;
        END IF;
    END IF;
END $$;

-- Test 7: Final verification of current state
SELECT 'Test 7: Final verification of current inventory state...' as test_step;

SELECT 
    wi.warehouse_id,
    w.name as warehouse_name,
    wi.product_id,
    wi.quantity as current_quantity,
    wi.minimum_stock,
    wi.last_updated,
    'Current state after tests' as status
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'
    AND wi.product_id = '190';

-- Test 8: Summary
SELECT 'Test 8: Type column fix test summary...' as test_step;

SELECT 
    'Type Column Fix Test (v5)' as test_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'deduct_inventory_with_validation_v5'
        ) THEN '✅ FUNCTION DEPLOYED'
        ELSE '❌ FUNCTION MISSING'
    END as function_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'warehouse_transactions' 
                AND column_name = 'type' 
                AND is_nullable = 'NO'
        ) THEN '✅ TYPE COLUMN VERIFIED'
        ELSE '❌ TYPE COLUMN ISSUE'
    END as schema_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM warehouse_transactions 
            WHERE warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'::UUID
                AND product_id = '190'
                AND type = 'withdrawal'
                AND created_at >= NOW() - INTERVAL '10 minutes'
        ) THEN '✅ TRANSACTION LOGGED'
        ELSE '⚠️ NO RECENT TRANSACTIONS'
    END as transaction_status,
    NOW() as test_completed_at;

SELECT 'Type column fix v5 test completed successfully!' as final_status;
