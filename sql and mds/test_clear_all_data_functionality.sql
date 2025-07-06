-- اختبار وظيفة مسح جميع بيانات الصرف
-- Test clear all data functionality

-- ==================== STEP 1: CHECK CURRENT DATA ====================

-- Check current warehouse requests count
SELECT 
    'Current warehouse requests count:' as info,
    COUNT(*) as total_requests
FROM warehouse_requests;

-- Check current warehouse request items count
SELECT 
    'Current warehouse request items count:' as info,
    COUNT(*) as total_items
FROM warehouse_request_items;

-- Show sample data before deletion
SELECT 
    'Sample warehouse requests before deletion:' as info,
    request_number,
    status,
    type,
    reason,
    requested_at
FROM warehouse_requests 
ORDER BY requested_at DESC 
LIMIT 5;

-- ==================== STEP 2: TEST CASCADING DELETE ====================

-- Check if foreign key constraints exist for cascading delete
SELECT 
    'Foreign key constraints for cascading delete:' as info,
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name = 'warehouse_request_items'
    AND ccu.table_name = 'warehouse_requests';

-- ==================== STEP 3: CREATE TEST DATA ====================

-- Create test warehouse requests and items for deletion testing
DO $$
DECLARE
    test_request_id_1 UUID;
    test_request_id_2 UUID;
    test_user_id UUID;
BEGIN
    -- Get a test user
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        -- Create test request 1
        INSERT INTO warehouse_requests (
            request_number,
            type,
            status,
            reason,
            requested_by
        ) VALUES (
            'TEST_CLEAR_' || extract(epoch from now())::text,
            'manual',
            'pending',
            'Test request for clear all data functionality',
            test_user_id
        ) RETURNING id INTO test_request_id_1;
        
        -- Create test request 2
        INSERT INTO warehouse_requests (
            request_number,
            type,
            status,
            reason,
            requested_by
        ) VALUES (
            'TEST_CLEAR_2_' || extract(epoch from now())::text,
            'manual',
            'processing',
            'Second test request for clear all data functionality',
            test_user_id
        ) RETURNING id INTO test_request_id_2;
        
        -- Add items to test request 1
        INSERT INTO warehouse_request_items (
            request_id,
            product_id,
            quantity,
            notes
        ) VALUES 
        (test_request_id_1, '1', 10, 'Test item 1'),
        (test_request_id_1, '2', 5, 'Test item 2');
        
        -- Add items to test request 2
        INSERT INTO warehouse_request_items (
            request_id,
            product_id,
            quantity,
            notes
        ) VALUES 
        (test_request_id_2, '3', 15, 'Test item 3'),
        (test_request_id_2, '4', 8, 'Test item 4');
        
        RAISE NOTICE '✅ Created test data: 2 requests with 4 items total';
        RAISE NOTICE 'Test request 1 ID: %', test_request_id_1;
        RAISE NOTICE 'Test request 2 ID: %', test_request_id_2;
    ELSE
        RAISE NOTICE '❌ No test user found - cannot create test data';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error creating test data: %', SQLERRM;
END $$;

-- ==================== STEP 4: VERIFY TEST DATA CREATION ====================

-- Check updated counts after test data creation
SELECT 
    'Updated warehouse requests count after test data:' as info,
    COUNT(*) as total_requests
FROM warehouse_requests;

SELECT 
    'Updated warehouse request items count after test data:' as info,
    COUNT(*) as total_items
FROM warehouse_request_items;

-- Show test requests
SELECT 
    'Test requests created:' as info,
    request_number,
    status,
    type,
    reason
FROM warehouse_requests 
WHERE request_number LIKE 'TEST_CLEAR%'
ORDER BY requested_at DESC;

-- ==================== STEP 5: TEST THE CLEAR ALL FUNCTION ====================

-- Simulate the clear all data operation
DO $$
DECLARE
    initial_requests_count INTEGER;
    initial_items_count INTEGER;
    final_requests_count INTEGER;
    final_items_count INTEGER;
BEGIN
    -- Get initial counts
    SELECT COUNT(*) INTO initial_requests_count FROM warehouse_requests;
    SELECT COUNT(*) INTO initial_items_count FROM warehouse_request_items;
    
    RAISE NOTICE '📊 Initial counts - Requests: %, Items: %', initial_requests_count, initial_items_count;
    
    -- Perform the clear operation (same as the service method)
    DELETE FROM warehouse_requests 
    WHERE id != '00000000-0000-0000-0000-000000000000'; -- Delete all records
    
    -- Get final counts
    SELECT COUNT(*) INTO final_requests_count FROM warehouse_requests;
    SELECT COUNT(*) INTO final_items_count FROM warehouse_request_items;
    
    RAISE NOTICE '📊 Final counts - Requests: %, Items: %', final_requests_count, final_items_count;
    
    -- Verify the operation
    IF final_requests_count = 0 AND final_items_count = 0 THEN
        RAISE NOTICE '✅ Clear all data operation successful!';
        RAISE NOTICE '✅ Deleted % requests and % items', initial_requests_count, initial_items_count;
        RAISE NOTICE '✅ Cascading delete worked correctly - all items were deleted automatically';
    ELSE
        RAISE NOTICE '❌ Clear all data operation failed!';
        RAISE NOTICE '❌ Remaining requests: %, Remaining items: %', final_requests_count, final_items_count;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error during clear all data test: %', SQLERRM;
END $$;

-- ==================== STEP 6: VERIFY FINAL STATE ====================

-- Final verification
SELECT 
    'Final warehouse requests count:' as info,
    COUNT(*) as total_requests
FROM warehouse_requests;

SELECT 
    'Final warehouse request items count:' as info,
    COUNT(*) as total_items
FROM warehouse_request_items;

-- Check if any orphaned items exist (should be 0 if cascading delete works)
SELECT 
    'Orphaned items check:' as info,
    COUNT(*) as orphaned_items_count
FROM warehouse_request_items wri
LEFT JOIN warehouse_requests wr ON wri.request_id = wr.id
WHERE wr.id IS NULL;

-- ==================== STEP 7: PERFORMANCE TEST ====================

-- Test performance with larger dataset
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    duration INTERVAL;
    test_user_id UUID;
    i INTEGER;
BEGIN
    -- Get a test user
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        RAISE NOTICE '🚀 Starting performance test - creating 100 requests with 500 items...';
        
        start_time := clock_timestamp();
        
        -- Create 100 test requests with 5 items each
        FOR i IN 1..100 LOOP
            INSERT INTO warehouse_requests (
                request_number,
                type,
                status,
                reason,
                requested_by
            ) VALUES (
                'PERF_TEST_' || i || '_' || extract(epoch from now())::text,
                'manual',
                'pending',
                'Performance test request ' || i,
                test_user_id
            );
            
            -- Add 5 items to each request
            INSERT INTO warehouse_request_items (
                request_id,
                product_id,
                quantity,
                notes
            ) 
            SELECT 
                (SELECT id FROM warehouse_requests WHERE request_number = 'PERF_TEST_' || i || '_' || extract(epoch from now())::text),
                ((i % 10) + 1)::TEXT,
                (i % 20) + 1,
                'Performance test item ' || j
            FROM generate_series(1, 5) j;
        END LOOP;
        
        end_time := clock_timestamp();
        duration := end_time - start_time;
        
        RAISE NOTICE '✅ Created 100 requests with 500 items in %ms', EXTRACT(milliseconds FROM duration);
        
        -- Test deletion performance
        start_time := clock_timestamp();
        
        DELETE FROM warehouse_requests 
        WHERE id != '00000000-0000-0000-0000-000000000000';
        
        end_time := clock_timestamp();
        duration := end_time - start_time;
        
        RAISE NOTICE '✅ Deleted all requests and items in %ms', EXTRACT(milliseconds FROM duration);
        
        -- Verify deletion
        SELECT COUNT(*) INTO i FROM warehouse_requests;
        IF i = 0 THEN
            RAISE NOTICE '✅ Performance test successful - all data cleared';
        ELSE
            RAISE NOTICE '❌ Performance test failed - % requests remaining', i;
        END IF;
        
    ELSE
        RAISE NOTICE '❌ No test user found - skipping performance test';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error during performance test: %', SQLERRM;
END $$;

-- ==================== STEP 8: SUMMARY ====================

SELECT 
    'Clear All Data Functionality Test Completed!' as summary,
    'Check the notices above for detailed results.' as instruction,
    'The functionality should work correctly if all tests show ✅ SUCCESS.' as conclusion;
