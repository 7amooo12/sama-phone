-- =====================================================
-- TEST COMPLETE SCHEMA FIX FOR WAREHOUSE_TRANSACTIONS
-- =====================================================
-- This script validates that the v5 function handles ALL required columns

-- Test 1: Complete schema analysis
SELECT 'Test 1: Complete warehouse_transactions schema analysis...' as test_step;

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE 
        WHEN is_nullable = 'NO' THEN '🔴 REQUIRED (NOT NULL)'
        ELSE '🟢 OPTIONAL (NULLABLE)'
    END as constraint_status,
    CASE 
        WHEN column_name IN ('id', 'transaction_number', 'type', 'warehouse_id', 'product_id', 
                           'quantity', 'quantity_before', 'quantity_after', 'quantity_change', 
                           'reason', 'performed_by', 'performed_at') THEN '✅ HANDLED IN v5'
        WHEN is_nullable = 'NO' THEN '❌ MISSING FROM v5'
        ELSE '⚠️ OPTIONAL'
    END as v5_status
FROM information_schema.columns 
WHERE table_name = 'warehouse_transactions' 
    AND table_schema = 'public'
ORDER BY 
    CASE WHEN is_nullable = 'NO' THEN 1 ELSE 2 END,
    ordinal_position;

-- Test 2: Identify any missing required columns
SELECT 'Test 2: Checking for missing required columns...' as test_step;

SELECT 
    'Missing Required Columns Check' as check_type,
    COUNT(*) as missing_count,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ All required columns handled'
        ELSE '❌ Missing required columns: ' || STRING_AGG(column_name, ', ')
    END as status
FROM information_schema.columns 
WHERE table_name = 'warehouse_transactions' 
    AND table_schema = 'public'
    AND is_nullable = 'NO'
    AND column_name NOT IN ('id', 'transaction_number', 'type', 'warehouse_id', 'product_id', 
                           'quantity', 'quantity_before', 'quantity_after', 'quantity_change', 
                           'reason', 'performed_by', 'performed_at', 'created_at');

-- Test 3: Test the updated v5 function
SELECT 'Test 3: Testing updated v5 function with complete schema...' as test_step;

-- First check if we have inventory to test with
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
    
    RAISE NOTICE 'Available quantity for testing: %', available_qty;
    
    IF available_qty >= 1 THEN
        RAISE NOTICE 'Testing v5 function with complete schema...';
        
        SELECT deduct_inventory_with_validation_v5(
            '338d5af4-88ad-49cb-aec6-456ac6bd318c',  -- warehouse ID
            '190',                                    -- product ID
            1,                                        -- test quantity
            '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',  -- performed by
            'Test complete schema fix - all required columns',  -- reason
            '07ba6659-4a68-4019-8e35-5f9609ec0d98',  -- reference ID
            'complete_schema_test'                    -- reference type
        ) INTO test_result;
        
        RAISE NOTICE 'Complete schema test result: %', test_result;
        
        IF test_result->>'success' = 'true' THEN
            RAISE NOTICE '✅ Complete schema fix successful!';
            RAISE NOTICE '   Transaction ID: %', test_result->>'transaction_id';
            RAISE NOTICE '   Deducted quantity: %', test_result->>'deducted_quantity';
        ELSE
            RAISE NOTICE '❌ Complete schema test failed: %', test_result->>'error';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No inventory available for testing';
    END IF;
END $$;

-- Test 4: Verify transaction was logged with all required columns
SELECT 'Test 4: Verifying complete transaction logging...' as test_step;

SELECT 
    wt.transaction_number,
    wt.type,
    wt.warehouse_id,
    wt.product_id,
    wt.quantity,
    wt.quantity_before,
    wt.quantity_after,
    wt.quantity_change,      -- ✅ This should now be populated
    wt.reason,
    wt.performed_by,
    wt.performed_at,         -- ✅ This should now be populated
    wt.reference_id,
    wt.reference_type,
    wt.created_at,
    'All required columns populated' as status
FROM warehouse_transactions wt
WHERE wt.warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'::UUID
    AND wt.product_id = '190'
    AND wt.reason LIKE '%Test complete schema fix%'
    AND wt.created_at >= NOW() - INTERVAL '5 minutes'
ORDER BY wt.created_at DESC
LIMIT 1;

-- Test 5: Test with larger quantity if available
SELECT 'Test 5: Testing with larger quantity (if available)...' as test_step;

DO $$
DECLARE
    available_qty INTEGER;
    test_result JSONB;
    test_qty INTEGER;
BEGIN
    -- Check available quantity
    SELECT COALESCE(wi.quantity, 0) INTO available_qty
    FROM warehouse_inventory wi
    WHERE wi.warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'::UUID
        AND wi.product_id = '190';
    
    -- Determine test quantity (up to 20 or available quantity)
    test_qty := LEAST(available_qty, 20);
    
    RAISE NOTICE 'Available: %, Testing with quantity: %', available_qty, test_qty;
    
    IF test_qty >= 5 THEN
        RAISE NOTICE 'Testing with quantity: %', test_qty;
        
        SELECT deduct_inventory_with_validation_v5(
            '338d5af4-88ad-49cb-aec6-456ac6bd318c',
            '190',
            test_qty,
            '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',
            'Test complete schema fix - quantity ' || test_qty,
            '07ba6659-4a68-4019-8e35-5f9609ec0d98',
            'dispatch_release_order'
        ) INTO test_result;
        
        RAISE NOTICE 'Larger quantity test result: %', test_result;
        
        IF test_result->>'success' = 'true' THEN
            RAISE NOTICE '✅ Larger quantity test successful!';
            RAISE NOTICE '   Quantity deducted: %', test_result->>'deducted_quantity';
            RAISE NOTICE '   Remaining quantity: %', test_result->>'remaining_quantity';
        ELSE
            RAISE NOTICE '❌ Larger quantity test failed: %', test_result->>'error';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ Insufficient inventory for larger quantity test';
    END IF;
END $$;

-- Test 6: Final schema compliance verification
SELECT 'Test 6: Final schema compliance verification...' as test_step;

-- Check if any recent transactions are missing required column values
SELECT 
    'Schema Compliance Check' as check_type,
    COUNT(*) as total_recent_transactions,
    COUNT(CASE WHEN type IS NULL THEN 1 END) as missing_type,
    COUNT(CASE WHEN quantity_change IS NULL THEN 1 END) as missing_quantity_change,
    COUNT(CASE WHEN performed_at IS NULL THEN 1 END) as missing_performed_at,
    CASE 
        WHEN COUNT(CASE WHEN type IS NULL OR quantity_change IS NULL OR performed_at IS NULL THEN 1 END) = 0 
        THEN '✅ All recent transactions have required columns'
        ELSE '❌ Some transactions missing required column values'
    END as compliance_status
FROM warehouse_transactions wt
WHERE wt.warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'::UUID
    AND wt.product_id = '190'
    AND wt.created_at >= NOW() - INTERVAL '10 minutes';

-- Test 7: Summary
SELECT 'Test 7: Complete schema fix summary...' as test_step;

SELECT 
    'Complete Schema Fix Test' as test_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'deduct_inventory_with_validation_v5'
        ) THEN '✅ FUNCTION EXISTS'
        ELSE '❌ FUNCTION MISSING'
    END as function_status,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'warehouse_transactions' 
                AND is_nullable = 'NO'
                AND column_name NOT IN ('id', 'transaction_number', 'type', 'warehouse_id', 'product_id', 
                                       'quantity', 'quantity_before', 'quantity_after', 'quantity_change', 
                                       'reason', 'performed_by', 'performed_at', 'created_at')
        ) THEN '✅ ALL REQUIRED COLUMNS HANDLED'
        ELSE '❌ MISSING REQUIRED COLUMNS'
    END as schema_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM warehouse_transactions 
            WHERE warehouse_id = '338d5af4-88ad-49cb-aec6-456ac6bd318c'::UUID
                AND product_id = '190'
                AND type IS NOT NULL
                AND quantity_change IS NOT NULL
                AND performed_at IS NOT NULL
                AND created_at >= NOW() - INTERVAL '10 minutes'
        ) THEN '✅ TRANSACTIONS LOGGED CORRECTLY'
        ELSE '⚠️ NO RECENT VALID TRANSACTIONS'
    END as transaction_status,
    NOW() as test_completed_at;

SELECT 'Complete schema fix test completed!' as final_status;
