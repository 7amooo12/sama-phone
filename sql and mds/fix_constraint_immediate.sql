-- IMMEDIATE FIX for warehouse_requests status constraint
-- Run this directly in Supabase SQL Editor to fix the constraint issue

-- Step 1: Check current constraint
SELECT 
    'Current constraint definition:' as info,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint 
WHERE conname = 'warehouse_requests_status_valid';

-- Step 2: Drop the existing constraint
ALTER TABLE public.warehouse_requests 
DROP CONSTRAINT IF EXISTS warehouse_requests_status_valid;

-- Step 3: Add the new constraint with all required status values
ALTER TABLE public.warehouse_requests 
ADD CONSTRAINT warehouse_requests_status_valid 
CHECK (status IN (
    'pending',      -- في الانتظار
    'approved',     -- موافق عليه  
    'rejected',     -- مرفوض
    'executed',     -- منفذ
    'cancelled',    -- ملغي
    'processing',   -- قيد المعالجة (NEW)
    'completed'     -- مكتمل (NEW)
));

-- Step 4: Update related constraints for timestamp fields
ALTER TABLE public.warehouse_requests 
DROP CONSTRAINT IF EXISTS warehouse_requests_approved_at_check;

ALTER TABLE public.warehouse_requests 
DROP CONSTRAINT IF EXISTS warehouse_requests_executed_at_check;

ALTER TABLE public.warehouse_requests 
ADD CONSTRAINT warehouse_requests_approved_at_check 
CHECK (
    (status IN ('approved', 'processing', 'executed', 'completed') AND approved_at IS NOT NULL AND approved_by IS NOT NULL) OR
    (status NOT IN ('approved', 'processing', 'executed', 'completed'))
);

ALTER TABLE public.warehouse_requests 
ADD CONSTRAINT warehouse_requests_executed_at_check 
CHECK (
    (status IN ('executed', 'completed') AND executed_at IS NOT NULL AND executed_by IS NOT NULL) OR
    (status NOT IN ('executed', 'completed'))
);

-- Step 5: Verify the fix
SELECT 
    'New constraint definition:' as info,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint 
WHERE conname = 'warehouse_requests_status_valid';

-- Step 6: Test the new constraint (optional)
-- Test inserting with 'processing' status (requires approval fields)
INSERT INTO warehouse_requests (
    request_number,
    type,
    status,
    reason,
    requested_by,
    approved_at,
    approved_by
) VALUES (
    'TEST_PROCESSING_' || extract(epoch from now())::text,
    'withdrawal',
    'processing',
    'Test processing status after constraint fix',
    (SELECT id FROM auth.users LIMIT 1),
    now(),
    (SELECT id FROM auth.users LIMIT 1)
) RETURNING request_number, status;

-- Test inserting with 'completed' status (requires both approval and execution fields)
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
    'TEST_COMPLETED_' || extract(epoch from now())::text,
    'withdrawal',
    'completed',
    'Test completed status after constraint fix',
    (SELECT id FROM auth.users LIMIT 1),
    now(),
    (SELECT id FROM auth.users LIMIT 1),
    now(),
    (SELECT id FROM auth.users LIMIT 1)
) RETURNING request_number, status;

-- Clean up test records
DELETE FROM warehouse_requests 
WHERE request_number LIKE 'TEST_%';

-- Final confirmation
SELECT 'Constraint fix completed successfully! The following status values are now allowed:' as result;
SELECT unnest(ARRAY['pending', 'approved', 'rejected', 'executed', 'cancelled', 'processing', 'completed']) as allowed_status_values;
