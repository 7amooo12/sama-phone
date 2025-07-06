-- اختبار تحسينات البحث في المخازن
-- Test warehouse search improvements

-- First, apply the corrected migration
-- Execute the corrected migration file: supabase/migrations/20250615000004_create_warehouse_search_functions.sql

-- Test 1: Search for specific product ID "688"
SELECT 'Testing search for product ID "688"...' as test_status;

-- Get a sample warehouse ID for testing
DO $$
DECLARE
    sample_warehouse_id UUID;
    test_result RECORD;
    result_count INTEGER := 0;
BEGIN
    -- Get first active warehouse
    SELECT id INTO sample_warehouse_id 
    FROM warehouses 
    WHERE is_active = true 
    LIMIT 1;
    
    IF sample_warehouse_id IS NOT NULL THEN
        RAISE NOTICE 'Testing with warehouse ID: %', sample_warehouse_id;
        
        -- Test search for "688"
        RAISE NOTICE '=== Testing search for "688" ===';
        FOR test_result IN 
            SELECT * FROM search_warehouse_products(
                '688'::TEXT, 
                ARRAY[sample_warehouse_id], 
                20, 
                0
            )
        LOOP
            result_count := result_count + 1;
            RAISE NOTICE 'Result %: Product ID=%, Name=%, SKU=%', 
                result_count, test_result.product_id, test_result.product_name, test_result.product_sku;
        END LOOP;
        
        RAISE NOTICE 'Total results for "688": %', result_count;
        
        -- Reset counter for next test
        result_count := 0;
        
        -- Test search for "6880"
        RAISE NOTICE '=== Testing search for "6880" ===';
        FOR test_result IN 
            SELECT * FROM search_warehouse_products(
                '6880'::TEXT, 
                ARRAY[sample_warehouse_id], 
                20, 
                0
            )
        LOOP
            result_count := result_count + 1;
            RAISE NOTICE 'Result %: Product ID=%, Name=%, SKU=%', 
                result_count, test_result.product_id, test_result.product_name, test_result.product_sku;
        END LOOP;
        
        RAISE NOTICE 'Total results for "6880": %', result_count;
        
        -- Reset counter for next test
        result_count := 0;
        
        -- Test empty search (should return all products)
        RAISE NOTICE '=== Testing empty search ===';
        FOR test_result IN 
            SELECT * FROM search_warehouse_products(
                ''::TEXT, 
                ARRAY[sample_warehouse_id], 
                5, 
                0
            )
        LOOP
            result_count := result_count + 1;
            RAISE NOTICE 'Result %: Product ID=%, Name=%', 
                result_count, test_result.product_id, test_result.product_name;
        END LOOP;
        
        RAISE NOTICE 'Total results for empty search (limited to 5): %', result_count;
        
    ELSE
        RAISE NOTICE 'No active warehouses found for testing';
    END IF;
END $$;

-- Test 2: Verify function exists
SELECT 'Verifying search function exists...' as test_status;

SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'search_warehouse_products';

-- Test 3: Check sample warehouse inventory data
SELECT 'Checking sample warehouse inventory...' as test_status;

SELECT 
    wi.product_id,
    wi.quantity,
    w.name as warehouse_name,
    COALESCE(
        (SELECT name FROM products WHERE id = wi.product_id LIMIT 1),
        'منتج ' || wi.product_id
    ) as product_name
FROM warehouse_inventory wi
INNER JOIN warehouses w ON wi.warehouse_id = w.id
WHERE w.is_active = true 
AND wi.quantity > 0
ORDER BY wi.product_id
LIMIT 10;

SELECT 'Search function testing completed!' as final_status;
