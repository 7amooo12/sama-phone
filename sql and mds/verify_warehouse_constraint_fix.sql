-- Verification script to check if the warehouse_requests status constraint fix worked
-- Run this in Supabase SQL Editor after applying the fix

-- 1. Check if the constraint exists and what values it allows
SELECT 
    'warehouse_requests_status_valid constraint definition:' as info,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conname = 'warehouse_requests_status_valid';

-- 2. Test that 'processing' status is now allowed
DO $$
BEGIN
    -- Try to insert a test record with 'processing' status (requires approval fields)
    INSERT INTO warehouse_requests (
        request_number,
        type,
        status,
        reason,
        requested_by,
        approved_at,
        approved_by
    ) VALUES (
        'VERIFY_PROCESSING_' || extract(epoch from now())::text,
        'withdrawal',
        'processing',
        'Verification test for processing status',
        (SELECT id FROM auth.users LIMIT 1),
        now(),
        (SELECT id FROM auth.users LIMIT 1)
    );

    RAISE NOTICE '✅ SUCCESS: processing status is now allowed';

    -- Clean up the test record
    DELETE FROM warehouse_requests
    WHERE request_number LIKE 'VERIFY_PROCESSING_%';

EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '❌ FAILED: processing status is still not allowed - constraint not fixed';
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ ERROR: %', SQLERRM;
END $$;

-- 3. Test that 'completed' status is now allowed
DO $$
BEGIN
    -- Try to insert a test record with 'completed' status (requires approval and execution fields)
    INSERT INTO warehouse_requests (
        request_number,
        type,
        status,
        reason,
        requested_by,
        approved_at,
        approved_by,
        executed_at,
        executed_by
    ) VALUES (
        'VERIFY_COMPLETED_' || extract(epoch from now())::text,
        'withdrawal',
        'completed',
        'Verification test for completed status',
        (SELECT id FROM auth.users LIMIT 1),
        now(),
        (SELECT id FROM auth.users LIMIT 1),
        now(),
        (SELECT id FROM auth.users LIMIT 1)
    );

    RAISE NOTICE '✅ SUCCESS: completed status is now allowed';

    -- Clean up the test record
    DELETE FROM warehouse_requests
    WHERE request_number LIKE 'VERIFY_COMPLETED_%';

EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '❌ FAILED: completed status is still not allowed - constraint not fixed';
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ ERROR: %', SQLERRM;
END $$;

-- 4. Test that invalid status is still rejected
DO $$
BEGIN
    -- Try to insert a test record with invalid status
    INSERT INTO warehouse_requests (
        request_number,
        type,
        status,
        reason,
        requested_by
    ) VALUES (
        'VERIFY_INVALID_' || extract(epoch from now())::text,
        'withdrawal',
        'invalid_status',
        'Verification test for invalid status',
        (SELECT id FROM auth.users LIMIT 1)
    );
    
    RAISE NOTICE '❌ UNEXPECTED: invalid status was allowed - constraint too permissive';
    
    -- Clean up if somehow it was inserted
    DELETE FROM warehouse_requests 
    WHERE request_number LIKE 'VERIFY_INVALID_%';
    
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '✅ SUCCESS: invalid status is correctly rejected';
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ ERROR: %', SQLERRM;
END $$;

-- 5. Show summary
SELECT 
    'Constraint verification completed. Check the notices above for results.' as summary,
    'If all tests show SUCCESS, the constraint fix is working correctly.' as instruction;
