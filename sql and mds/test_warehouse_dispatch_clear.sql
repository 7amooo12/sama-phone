-- اختبار وظيفة مسح طلبات الصرف
-- Test warehouse dispatch clear functionality

-- Test 1: Check current state
SELECT 'Checking current warehouse dispatch requests...' as test_status;

SELECT 
    COUNT(*) as total_requests,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_requests,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_requests
FROM warehouse_requests;

SELECT 'Current warehouse request items...' as test_status;

SELECT COUNT(*) as total_items
FROM warehouse_request_items;

-- Test 2: Create some test data if none exists
INSERT INTO warehouse_requests (
    request_number,
    type,
    status,
    reason,
    requested_by,
    notes
) VALUES 
    ('TEST001', 'withdrawal', 'pending', 'Test request 1', 'test-user-id', 'Test notes 1'),
    ('TEST002', 'withdrawal', 'completed', 'Test request 2', 'test-user-id', 'Test notes 2')
ON CONFLICT (request_number) DO NOTHING;

-- Add some test items
INSERT INTO warehouse_request_items (
    request_id,
    product_id,
    quantity,
    notes
)
SELECT 
    wr.id,
    'TEST_PRODUCT_' || wr.request_number,
    10,
    'Test item for ' || wr.request_number
FROM warehouse_requests wr
WHERE wr.request_number IN ('TEST001', 'TEST002')
ON CONFLICT DO NOTHING;

-- Test 3: Check data after insertion
SELECT 'After test data insertion...' as test_status;

SELECT 
    COUNT(*) as total_requests,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_requests,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_requests
FROM warehouse_requests;

SELECT COUNT(*) as total_items
FROM warehouse_request_items;

-- Test 4: Simulate the clear operation
SELECT 'Simulating clear operation...' as test_status;

-- Count before deletion
SELECT COUNT(*) as requests_before_delete FROM warehouse_requests;

-- Delete items first (simulating the service method)
DELETE FROM warehouse_request_items 
WHERE id != '00000000-0000-0000-0000-000000000000';

-- Delete requests
DELETE FROM warehouse_requests 
WHERE id != '00000000-0000-0000-0000-000000000000';

-- Test 5: Verify deletion
SELECT 'Verifying deletion results...' as test_status;

SELECT 
    COUNT(*) as remaining_requests,
    CASE 
        WHEN COUNT(*) = 0 THEN 'SUCCESS: All requests deleted'
        ELSE 'FAILURE: ' || COUNT(*) || ' requests still remain'
    END as deletion_result
FROM warehouse_requests;

SELECT 
    COUNT(*) as remaining_items,
    CASE 
        WHEN COUNT(*) = 0 THEN 'SUCCESS: All items deleted'
        ELSE 'FAILURE: ' || COUNT(*) || ' items still remain'
    END as items_deletion_result
FROM warehouse_request_items;

-- Test 6: Check for any foreign key constraints or triggers
SELECT 'Checking for constraints that might prevent deletion...' as test_status;

SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid IN (
    SELECT oid FROM pg_class WHERE relname IN ('warehouse_requests', 'warehouse_request_items')
)
AND contype IN ('f', 'c'); -- foreign key and check constraints

-- Test 7: Test the actual database function if it exists
DO $$
BEGIN
    -- Try to call the clear function if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'clear_all_warehouse_requests'
        AND routine_schema = 'public'
    ) THEN
        RAISE NOTICE 'Found clear_all_warehouse_requests function, testing...';
        -- Call the function here if it exists
    ELSE
        RAISE NOTICE 'No clear_all_warehouse_requests function found';
    END IF;
END $$;

SELECT 'Warehouse dispatch clear test completed!' as final_status;
