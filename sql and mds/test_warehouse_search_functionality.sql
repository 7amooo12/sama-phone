-- اختبار وظائف البحث في المخازن
-- Test warehouse search functionality

-- Step 1: Verify search functions exist
SELECT 
    'Checking search functions...' as test_step,
    COUNT(*) as function_count
FROM pg_proc 
WHERE proname IN ('search_warehouse_products', 'search_warehouse_categories', 'get_accessible_warehouse_ids');

-- Step 2: Test get_accessible_warehouse_ids function
DO $$
DECLARE
    test_user_id UUID;
    accessible_warehouses UUID[];
BEGIN
    -- Get a test user
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        -- Test the function
        SELECT get_accessible_warehouse_ids(test_user_id) INTO accessible_warehouses;
        
        RAISE NOTICE '✅ User % has access to % warehouses', test_user_id, array_length(accessible_warehouses, 1);
        RAISE NOTICE 'Accessible warehouses: %', accessible_warehouses;
    ELSE
        RAISE NOTICE '⚠️ No test user found';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error testing get_accessible_warehouse_ids: %', SQLERRM;
END $$;

-- Step 3: Test search_warehouse_products function
DO $$
DECLARE
    test_user_id UUID;
    accessible_warehouses UUID[];
    search_results RECORD;
    result_count INTEGER := 0;
BEGIN
    -- Get a test user and their accessible warehouses
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        SELECT get_accessible_warehouse_ids(test_user_id) INTO accessible_warehouses;
        
        IF array_length(accessible_warehouses, 1) > 0 THEN
            -- Test product search with empty query (should return all products)
            FOR search_results IN 
                SELECT * FROM search_warehouse_products('', accessible_warehouses, 5, 0)
            LOOP
                result_count := result_count + 1;
                RAISE NOTICE 'Product %: % (SKU: %, Quantity: %)', 
                    result_count, 
                    search_results.product_name, 
                    search_results.product_sku, 
                    search_results.total_quantity;
            END LOOP;
            
            RAISE NOTICE '✅ Found % products in search test', result_count;
            
            -- Test with specific search term
            result_count := 0;
            FOR search_results IN 
                SELECT * FROM search_warehouse_products('%منتج%', accessible_warehouses, 3, 0)
            LOOP
                result_count := result_count + 1;
                RAISE NOTICE 'Search result %: %', result_count, search_results.product_name;
            END LOOP;
            
            RAISE NOTICE '✅ Found % products matching "منتج"', result_count;
        ELSE
            RAISE NOTICE '⚠️ No accessible warehouses for user';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No test user found';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error testing search_warehouse_products: %', SQLERRM;
END $$;

-- Step 4: Test search_warehouse_categories function
DO $$
DECLARE
    test_user_id UUID;
    accessible_warehouses UUID[];
    category_results RECORD;
    result_count INTEGER := 0;
BEGIN
    -- Get a test user and their accessible warehouses
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        SELECT get_accessible_warehouse_ids(test_user_id) INTO accessible_warehouses;
        
        IF array_length(accessible_warehouses, 1) > 0 THEN
            -- Test category search
            FOR category_results IN 
                SELECT * FROM search_warehouse_categories('', accessible_warehouses, 5, 0)
            LOOP
                result_count := result_count + 1;
                RAISE NOTICE 'Category %: % (% products, % total quantity)', 
                    result_count, 
                    category_results.category_name, 
                    category_results.product_count, 
                    category_results.total_quantity;
            END LOOP;
            
            RAISE NOTICE '✅ Found % categories in search test', result_count;
        ELSE
            RAISE NOTICE '⚠️ No accessible warehouses for user';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No test user found';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error testing search_warehouse_categories: %', SQLERRM;
END $$;

-- Step 5: Test warehouse_product_search_view
DO $$
DECLARE
    view_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO view_count FROM warehouse_product_search_view LIMIT 10;
    RAISE NOTICE '✅ warehouse_product_search_view contains % records', view_count;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error testing warehouse_product_search_view: %', SQLERRM;
END $$;

-- Step 6: Test performance of search functions
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    duration INTERVAL;
    test_user_id UUID;
    accessible_warehouses UUID[];
    result_count INTEGER;
BEGIN
    -- Get test data
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    SELECT get_accessible_warehouse_ids(test_user_id) INTO accessible_warehouses;
    
    IF array_length(accessible_warehouses, 1) > 0 THEN
        -- Test product search performance
        start_time := clock_timestamp();
        
        SELECT COUNT(*) INTO result_count 
        FROM search_warehouse_products('%', accessible_warehouses, 50, 0);
        
        end_time := clock_timestamp();
        duration := end_time - start_time;
        
        RAISE NOTICE '⏱️ Product search performance: % results in %ms', 
            result_count, 
            EXTRACT(milliseconds FROM duration);
        
        -- Test category search performance
        start_time := clock_timestamp();
        
        SELECT COUNT(*) INTO result_count 
        FROM search_warehouse_categories('%', accessible_warehouses, 20, 0);
        
        end_time := clock_timestamp();
        duration := end_time - start_time;
        
        RAISE NOTICE '⏱️ Category search performance: % results in %ms', 
            result_count, 
            EXTRACT(milliseconds FROM duration);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error testing search performance: %', SQLERRM;
END $$;

-- Step 7: Verify indexes exist
SELECT 
    'Checking search indexes...' as test_step,
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE indexname IN (
    'idx_warehouse_inventory_product_search',
    'idx_warehouse_inventory_last_updated',
    'idx_warehouses_active'
);

-- Step 8: Test RLS policies (Row Level Security)
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename IN ('warehouse_inventory', 'warehouses')
    AND policyname LIKE '%warehouse%';
    
    RAISE NOTICE '🔒 Found % RLS policies for warehouse tables', policy_count;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error checking RLS policies: %', SQLERRM;
END $$;

-- Step 9: Summary
SELECT 
    'Search functionality test completed!' as summary,
    'Check the notices above for detailed results.' as instruction,
    'All functions should execute without errors for the search to work properly.' as note;
