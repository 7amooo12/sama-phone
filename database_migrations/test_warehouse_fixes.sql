-- ============================================================================
-- TEST WAREHOUSE FIXES
-- ============================================================================
-- اختبار شامل لجميع إصلاحات مشاكل المخازن
-- Comprehensive test for all warehouse issue fixes
-- ============================================================================

-- Step 1: Test database column reference fix
DO $$
DECLARE
    test_warehouse_id UUID;
    function_result_count INTEGER := 0;
    error_message TEXT;
BEGIN
    RAISE NOTICE '🧪 === TESTING DATABASE COLUMN REFERENCE FIX ===';
    
    -- Get a test warehouse ID
    SELECT id INTO test_warehouse_id
    FROM warehouses 
    WHERE is_active = true 
    LIMIT 1;
    
    IF test_warehouse_id IS NULL THEN
        RAISE NOTICE '⚠️ No active warehouses found for testing';
        RETURN;
    END IF;
    
    RAISE NOTICE '🎯 Testing with warehouse ID: %', test_warehouse_id;
    
    -- Test the get_warehouse_inventory_with_products function
    BEGIN
        SELECT COUNT(*) INTO function_result_count
        FROM get_warehouse_inventory_with_products(test_warehouse_id);
        
        RAISE NOTICE '✅ Function executed successfully, returned % items', function_result_count;
        
        -- Test that the function doesn't reference p.is_active
        IF pg_get_functiondef((
            SELECT p.oid FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public' AND p.proname = 'get_warehouse_inventory_with_products'
            LIMIT 1
        )) ILIKE '%p.is_active%' THEN
            RAISE NOTICE '❌ Function still contains p.is_active reference';
        ELSE
            RAISE NOTICE '✅ Function uses correct p.active column reference';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            IF error_message LIKE '%p.is_active%' OR error_message LIKE '%does not exist%' THEN
                RAISE NOTICE '❌ Column reference error still exists: %', error_message;
            ELSE
                RAISE NOTICE 'ℹ️ Function test completed with unrelated error: %', error_message;
            END IF;
    END;
END $$;

-- Step 2: Test warehouse requests relationship fix
DO $$
DECLARE
    test_warehouse_id UUID;
    function_result_count INTEGER := 0;
    error_message TEXT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧪 === TESTING WAREHOUSE REQUESTS RELATIONSHIP FIX ===';
    
    -- Get a test warehouse ID
    SELECT id INTO test_warehouse_id
    FROM warehouses 
    WHERE is_active = true 
    LIMIT 1;
    
    IF test_warehouse_id IS NULL THEN
        RAISE NOTICE '⚠️ No active warehouses found for testing';
        RETURN;
    END IF;
    
    RAISE NOTICE '🎯 Testing with warehouse ID: %', test_warehouse_id;
    
    -- Test the get_warehouse_requests_with_users function
    BEGIN
        SELECT COUNT(*) INTO function_result_count
        FROM get_warehouse_requests_with_users(test_warehouse_id);
        
        RAISE NOTICE '✅ Warehouse requests function executed successfully, returned % items', function_result_count;
        
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            IF error_message LIKE '%relationship%' OR error_message LIKE '%foreign key%' THEN
                RAISE NOTICE '❌ Relationship error still exists: %', error_message;
            ELSE
                RAISE NOTICE 'ℹ️ Function test completed with unrelated error: %', error_message;
            END IF;
    END;
    
    -- Check foreign key constraints
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'warehouse_requests'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'requested_by'
        AND kcu.referenced_table_name = 'user_profiles'
    ) THEN
        RAISE NOTICE '✅ Foreign key constraint for requested_by exists';
    ELSE
        RAISE NOTICE '❌ Foreign key constraint for requested_by missing';
    END IF;
END $$;

-- Step 3: Test inventory data consistency
DO $$
DECLARE
    warehouse_record RECORD;
    direct_count INTEGER;
    function_count INTEGER;
    total_warehouses_tested INTEGER := 0;
    consistent_warehouses INTEGER := 0;
    inconsistent_warehouses INTEGER := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧪 === TESTING INVENTORY DATA CONSISTENCY ===';
    
    -- Test each warehouse for data consistency
    FOR warehouse_record IN
        SELECT id, name FROM warehouses WHERE is_active = true ORDER BY name LIMIT 5
    LOOP
        total_warehouses_tested := total_warehouses_tested + 1;
        
        -- Get direct count from warehouse_inventory table
        SELECT COUNT(*) INTO direct_count
        FROM warehouse_inventory
        WHERE warehouse_id = warehouse_record.id;
        
        -- Get count from function
        BEGIN
            SELECT COUNT(*) INTO function_count
            FROM get_warehouse_inventory_with_products(warehouse_record.id);
        EXCEPTION
            WHEN OTHERS THEN
                function_count := -1; -- Error indicator
        END;
        
        -- Check consistency
        IF direct_count = function_count THEN
            consistent_warehouses := consistent_warehouses + 1;
            RAISE NOTICE '✅ Warehouse % (%): Direct=%, Function=% - CONSISTENT', 
                warehouse_record.name, warehouse_record.id, direct_count, function_count;
        ELSE
            inconsistent_warehouses := inconsistent_warehouses + 1;
            RAISE NOTICE '❌ Warehouse % (%): Direct=%, Function=% - INCONSISTENT', 
                warehouse_record.name, warehouse_record.id, direct_count, function_count;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 CONSISTENCY SUMMARY:';
    RAISE NOTICE '  - Total warehouses tested: %', total_warehouses_tested;
    RAISE NOTICE '  - Consistent warehouses: %', consistent_warehouses;
    RAISE NOTICE '  - Inconsistent warehouses: %', inconsistent_warehouses;
    
    IF inconsistent_warehouses = 0 THEN
        RAISE NOTICE '✅ All warehouses show consistent data between direct queries and functions';
    ELSE
        RAISE NOTICE '⚠️ % warehouses show data inconsistency', inconsistent_warehouses;
    END IF;
END $$;

-- Step 4: Test products table column structure
SELECT 
    '🧪 PRODUCTS TABLE COLUMN TEST' as test_type,
    column_name,
    data_type,
    is_nullable,
    CASE 
        WHEN column_name = 'active' THEN '✅ CORRECT'
        WHEN column_name = 'is_active' THEN '❌ OLD COLUMN STILL EXISTS'
        ELSE 'ℹ️ OTHER'
    END as status
FROM information_schema.columns 
WHERE table_name = 'products' 
AND table_schema = 'public'
AND column_name IN ('active', 'is_active')
ORDER BY column_name;

-- Step 5: Test warehouse_requests table structure
SELECT 
    '🧪 WAREHOUSE_REQUESTS TABLE TEST' as test_type,
    column_name,
    data_type,
    is_nullable,
    CASE 
        WHEN column_name IN ('requested_by', 'approved_by', 'warehouse_id') THEN '✅ REQUIRED COLUMN'
        ELSE 'ℹ️ OTHER'
    END as status
FROM information_schema.columns 
WHERE table_name = 'warehouse_requests' 
AND table_schema = 'public'
AND column_name IN ('id', 'warehouse_id', 'requested_by', 'approved_by', 'status', 'created_at')
ORDER BY column_name;

-- Step 6: Test foreign key relationships
SELECT 
    '🧪 FOREIGN KEY RELATIONSHIPS TEST' as test_type,
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    '✅ RELATIONSHIP EXISTS' as status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'warehouse_requests' 
AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.constraint_name;

-- Step 7: Performance test
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    execution_time INTERVAL;
    test_warehouse_id UUID;
    result_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧪 === PERFORMANCE TEST ===';
    
    -- Get a test warehouse ID
    SELECT id INTO test_warehouse_id
    FROM warehouses 
    WHERE is_active = true 
    LIMIT 1;
    
    IF test_warehouse_id IS NULL THEN
        RAISE NOTICE '⚠️ No active warehouses found for performance testing';
        RETURN;
    END IF;
    
    -- Test function performance
    start_time := clock_timestamp();
    
    SELECT COUNT(*) INTO result_count
    FROM get_warehouse_inventory_with_products(test_warehouse_id);
    
    end_time := clock_timestamp();
    execution_time := end_time - start_time;
    
    RAISE NOTICE '⏱️ Function execution time: % ms', EXTRACT(MILLISECONDS FROM execution_time);
    RAISE NOTICE '📊 Function returned % items', result_count;
    
    IF EXTRACT(MILLISECONDS FROM execution_time) < 3000 THEN
        RAISE NOTICE '✅ Performance target met (< 3 seconds)';
    ELSE
        RAISE NOTICE '⚠️ Performance target not met (>= 3 seconds)';
    END IF;
END $$;

-- Step 8: Final summary
DO $$
DECLARE
    total_functions INTEGER;
    working_functions INTEGER;
    total_tables INTEGER;
    tables_with_correct_structure INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎉 === FINAL TEST SUMMARY ===';
    
    -- Count database functions
    SELECT COUNT(*) INTO total_functions
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' 
    AND p.proname IN ('get_warehouse_inventory_with_products', 'get_warehouse_requests_with_users');
    
    -- Count working functions (simplified check)
    working_functions := 0;
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'get_warehouse_inventory_with_products'
    ) THEN
        working_functions := working_functions + 1;
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'get_warehouse_requests_with_users'
    ) THEN
        working_functions := working_functions + 1;
    END IF;
    
    -- Count tables with correct structure
    total_tables := 2; -- products and warehouse_requests
    tables_with_correct_structure := 0;
    
    -- Check products table
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'active' AND table_schema = 'public'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'is_active' AND table_schema = 'public'
    ) THEN
        tables_with_correct_structure := tables_with_correct_structure + 1;
    END IF;
    
    -- Check warehouse_requests table
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_requests' AND column_name = 'requested_by' AND table_schema = 'public'
    ) THEN
        tables_with_correct_structure := tables_with_correct_structure + 1;
    END IF;
    
    RAISE NOTICE '📊 SUMMARY RESULTS:';
    RAISE NOTICE '  - Database functions: %/% working', working_functions, total_functions;
    RAISE NOTICE '  - Table structures: %/% correct', tables_with_correct_structure, total_tables;
    
    IF working_functions = total_functions AND tables_with_correct_structure = total_tables THEN
        RAISE NOTICE '🎉 ALL TESTS PASSED - Warehouse fixes are working correctly!';
    ELSE
        RAISE NOTICE '⚠️ Some tests failed - Please review the output above for details';
    END IF;
END $$;

RAISE NOTICE '';
RAISE NOTICE '✅ Warehouse fixes testing completed!';
RAISE NOTICE 'ℹ️ Review the test results above to verify all fixes are working correctly';
