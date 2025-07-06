-- Complete workflow test for warehouse dispatch requests
-- This script tests the entire status transition workflow after constraint fix

-- Step 1: Check current constraint definition
SELECT 
    'Current constraint definition:' as info,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint 
WHERE conname = 'warehouse_requests_status_valid';

-- Step 2: Create a test request with 'pending' status
DO $$
DECLARE
    test_request_id UUID;
    test_user_id UUID;
BEGIN
    -- Get a test user
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    -- Insert a test request with 'pending' status
    INSERT INTO warehouse_requests (
        request_number,
        type,
        status,
        reason,
        requested_by
    ) VALUES (
        'WORKFLOW_TEST_' || extract(epoch from now())::text,
        'withdrawal',
        'pending',
        'Complete workflow test request',
        test_user_id
    ) RETURNING id INTO test_request_id;
    
    RAISE NOTICE '✅ Step 2: Created test request with pending status: %', test_request_id;
    
    -- Step 3: Update to 'processing' status (should work with approval fields)
    UPDATE warehouse_requests 
    SET 
        status = 'processing',
        approved_by = test_user_id,
        approved_at = now()
    WHERE id = test_request_id;
    
    RAISE NOTICE '✅ Step 3: Updated request to processing status';
    
    -- Step 4: Update to 'completed' status (should work with execution fields)
    UPDATE warehouse_requests 
    SET 
        status = 'completed',
        executed_by = test_user_id,
        executed_at = now()
    WHERE id = test_request_id;
    
    RAISE NOTICE '✅ Step 4: Updated request to completed status';
    
    -- Step 5: Verify the final state
    PERFORM 1 FROM warehouse_requests 
    WHERE id = test_request_id 
    AND status = 'completed'
    AND approved_at IS NOT NULL
    AND approved_by IS NOT NULL
    AND executed_at IS NOT NULL
    AND executed_by IS NOT NULL;
    
    IF FOUND THEN
        RAISE NOTICE '✅ Step 5: Workflow completed successfully - all constraints satisfied';
    ELSE
        RAISE NOTICE '❌ Step 5: Workflow failed - constraints not satisfied';
    END IF;
    
    -- Step 6: Clean up
    DELETE FROM warehouse_requests WHERE id = test_request_id;
    RAISE NOTICE '✅ Step 6: Cleaned up test request';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Workflow test failed: %', SQLERRM;
        -- Clean up on error
        DELETE FROM warehouse_requests WHERE request_number LIKE 'WORKFLOW_TEST_%';
END $$;

-- Step 7: Test invalid status transitions
DO $$
DECLARE
    test_request_id UUID;
    test_user_id UUID;
BEGIN
    -- Get a test user
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    -- Create a pending request
    INSERT INTO warehouse_requests (
        request_number,
        type,
        status,
        reason,
        requested_by
    ) VALUES (
        'INVALID_TEST_' || extract(epoch from now())::text,
        'withdrawal',
        'pending',
        'Invalid transition test request',
        test_user_id
    ) RETURNING id INTO test_request_id;
    
    -- Try to update directly to 'completed' without going through 'processing'
    -- This should fail due to business logic validation (if implemented)
    UPDATE warehouse_requests 
    SET 
        status = 'completed',
        approved_by = test_user_id,
        approved_at = now(),
        executed_by = test_user_id,
        executed_at = now()
    WHERE id = test_request_id;
    
    RAISE NOTICE '⚠️ Direct pending->completed transition was allowed (check business logic)';
    
    -- Clean up
    DELETE FROM warehouse_requests WHERE id = test_request_id;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '✅ Direct pending->completed transition was blocked: %', SQLERRM;
        -- Clean up on error
        DELETE FROM warehouse_requests WHERE request_number LIKE 'INVALID_TEST_%';
END $$;

-- Step 8: Test constraint violations
DO $$
DECLARE
    test_user_id UUID;
BEGIN
    -- Get a test user
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    -- Try to insert 'processing' status without approval fields (should fail)
    INSERT INTO warehouse_requests (
        request_number,
        type,
        status,
        reason,
        requested_by
    ) VALUES (
        'VIOLATION_TEST_' || extract(epoch from now())::text,
        'withdrawal',
        'processing',
        'Constraint violation test',
        test_user_id
    );
    
    RAISE NOTICE '❌ Processing status without approval fields was allowed - constraint not working';
    
    -- Clean up if somehow it was inserted
    DELETE FROM warehouse_requests WHERE request_number LIKE 'VIOLATION_TEST_%';
    
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '✅ Processing status without approval fields was correctly rejected';
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ Unexpected error: %', SQLERRM;
END $$;

-- Final summary
SELECT 
    'Workflow test completed. Check the notices above for results.' as summary,
    'All steps should show SUCCESS (✅) for the constraint fix to be working correctly.' as instruction;
