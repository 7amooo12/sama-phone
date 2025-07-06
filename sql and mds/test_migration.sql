-- Test script to verify the warehouse_requests status constraint fix
-- This script can be run in Supabase SQL Editor to test the migration

-- Step 1: Check current constraint definition
SELECT
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conname = 'warehouse_requests_status_valid';

-- Alternative check using information_schema
SELECT
    tc.constraint_name,
    tc.table_name,
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
WHERE tc.constraint_name = 'warehouse_requests_status_valid'
AND tc.table_name = 'warehouse_requests'
AND tc.table_schema = 'public';

-- Step 2: Test inserting records with new status values
-- This should work after the migration

-- Test 1: Insert with 'processing' status (should work after migration)
INSERT INTO warehouse_requests (
    request_number,
    type,
    status,
    reason,
    requested_by,
    warehouse_id
) VALUES (
    'TEST_PROCESSING_001',
    'withdrawal',
    'processing',
    'Test processing status',
    (SELECT id FROM auth.users LIMIT 1),
    NULL
) ON CONFLICT (request_number) DO NOTHING;

-- Test 2: Insert with 'completed' status (should work after migration)
INSERT INTO warehouse_requests (
    request_number,
    type,
    status,
    reason,
    requested_by,
    warehouse_id
) VALUES (
    'TEST_COMPLETED_001',
    'withdrawal',
    'completed',
    'Test completed status',
    (SELECT id FROM auth.users LIMIT 1),
    NULL
) ON CONFLICT (request_number) DO NOTHING;

-- Test 3: Try to insert with invalid status (should fail)
-- Uncomment the following to test constraint validation:
/*
INSERT INTO warehouse_requests (
    request_number,
    type,
    status,
    reason,
    requested_by,
    warehouse_id
) VALUES (
    'TEST_INVALID_001',
    'withdrawal',
    'invalid_status',
    'Test invalid status',
    (SELECT id FROM auth.users LIMIT 1),
    NULL
);
*/

-- Step 3: Verify the test records were created
SELECT 
    request_number,
    status,
    created_at
FROM warehouse_requests 
WHERE request_number LIKE 'TEST_%'
ORDER BY created_at DESC;

-- Step 4: Clean up test records
DELETE FROM warehouse_requests 
WHERE request_number LIKE 'TEST_%';

-- Step 5: Final verification - show all allowed status values
SELECT 
    'Constraint allows these status values:' as info,
    pg_get_constraintdef(oid) as allowed_values
FROM pg_constraint 
WHERE conname = 'warehouse_requests_status_valid';
