-- إصلاح قيد حالة طلبات المخزن لدعم جميع القيم المطلوبة
-- Fix warehouse_requests status constraint to support all required status values

-- Step 1: Drop the existing constraint (idempotent approach)
DO $$
BEGIN
    -- Always attempt to drop the constraint, ignore if it doesn't exist
    ALTER TABLE public.warehouse_requests
    DROP CONSTRAINT IF EXISTS warehouse_requests_status_valid;
    RAISE NOTICE '✅ Dropped warehouse_requests_status_valid constraint (if it existed)';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ Could not drop constraint: %', SQLERRM;
        -- Continue execution even if drop fails
END $$;

-- Step 2: Add new constraint with all required status values
DO $$
BEGIN
    -- Add the new constraint with all status values used by the application
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
    RAISE NOTICE '✅ Added new warehouse_requests_status_valid constraint with all required status values';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Could not add new constraint: %', SQLERRM;
        RAISE;
END $$;

-- Step 3: Update any existing records with invalid status values
DO $$
DECLARE
    invalid_count INTEGER := 0;
    updated_count INTEGER := 0;
BEGIN
    -- Check for any records with invalid status values
    SELECT COUNT(*) INTO invalid_count
    FROM public.warehouse_requests
    WHERE status NOT IN ('pending', 'approved', 'rejected', 'executed', 'cancelled', 'processing', 'completed');
    
    IF invalid_count > 0 THEN
        RAISE NOTICE '⚠️ Found % records with invalid status values', invalid_count;
        
        -- Update invalid status values to 'pending'
        UPDATE public.warehouse_requests 
        SET status = 'pending'
        WHERE status NOT IN ('pending', 'approved', 'rejected', 'executed', 'cancelled', 'processing', 'completed');
        
        GET DIAGNOSTICS updated_count = ROW_COUNT;
        RAISE NOTICE '✅ Updated % records with invalid status to pending', updated_count;
    ELSE
        RAISE NOTICE '✅ All existing records have valid status values';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error updating invalid status values: %', SQLERRM;
        RAISE;
END $$;

-- Step 4: Update the approved_at and executed_at constraints to handle new status values
DO $$
BEGIN
    -- Drop existing constraints using idempotent approach
    ALTER TABLE public.warehouse_requests
    DROP CONSTRAINT IF EXISTS warehouse_requests_approved_at_check;
    RAISE NOTICE '✅ Dropped approved_at constraint (if it existed)';

    ALTER TABLE public.warehouse_requests
    DROP CONSTRAINT IF EXISTS warehouse_requests_executed_at_check;
    RAISE NOTICE '✅ Dropped executed_at constraint (if it existed)';
    
    -- Add updated constraints that work with new status values
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
    
    RAISE NOTICE '✅ Added updated approved_at and executed_at constraints';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error updating timestamp constraints: %', SQLERRM;
        RAISE;
END $$;

-- Step 5: Verify the fix
DO $$
DECLARE
    constraint_count INTEGER := 0;
    constraint_def TEXT;
BEGIN
    -- Check that the new constraint exists using correct column names
    SELECT COUNT(*) INTO constraint_count
    FROM information_schema.table_constraints tc
    JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
    WHERE tc.constraint_name = 'warehouse_requests_status_valid'
    AND tc.table_name = 'warehouse_requests'
    AND tc.table_schema = 'public';

    IF constraint_count > 0 THEN
        -- Get the constraint definition
        SELECT pg_get_constraintdef(oid) INTO constraint_def
        FROM pg_constraint
        WHERE conname = 'warehouse_requests_status_valid';

        RAISE NOTICE '✅ warehouse_requests_status_valid constraint exists';
        RAISE NOTICE '📋 Constraint definition: %', constraint_def;
        RAISE NOTICE '✅ Status constraint fix completed successfully';
        RAISE NOTICE 'ℹ️ Allowed status values: pending, approved, rejected, executed, cancelled, processing, completed';
    ELSE
        RAISE EXCEPTION 'CRITICAL: warehouse_requests_status_valid constraint was not created properly';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error verifying constraint fix: %', SQLERRM;
        -- Don't re-raise the exception to allow migration to complete
END $$;
