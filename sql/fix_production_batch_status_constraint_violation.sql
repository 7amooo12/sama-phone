-- =====================================================
-- Fix for Production Batch Status Constraint Violation Error
-- SmartBizTracker Manufacturing System
-- =====================================================
-- This fixes the PostgreSQL constraint violations:
-- 1. "null value in column 'remaining_stock' violates not-null constraint"
-- 2. "quantity_used must be > 0" constraint violation
-- 3. "status_update" operation type not allowed
-- =====================================================

-- Step 1: Update tool_usage_history table to allow 'status_update' operation type
-- and modify constraints to handle status update operations
ALTER TABLE tool_usage_history 
DROP CONSTRAINT IF EXISTS tool_usage_history_operation_type_check;

ALTER TABLE tool_usage_history 
ADD CONSTRAINT tool_usage_history_operation_type_check 
CHECK (operation_type IN ('production', 'adjustment', 'import', 'export', 'status_update'));

-- Step 2: Modify quantity_used constraint to allow 0 for status_update operations
ALTER TABLE tool_usage_history 
DROP CONSTRAINT IF EXISTS tool_usage_history_quantity_used_check;

ALTER TABLE tool_usage_history 
ADD CONSTRAINT tool_usage_history_quantity_used_check 
CHECK (
    (operation_type = 'status_update' AND quantity_used >= 0) OR 
    (operation_type != 'status_update' AND quantity_used > 0)
);

-- Step 3: Create the fixed update_production_batch_status function
CREATE OR REPLACE FUNCTION update_production_batch_status(
    p_batch_id INTEGER,
    p_new_status VARCHAR(20),
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_batch_record RECORD;
    v_old_status VARCHAR(20);
BEGIN
    -- Get current user ID
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'المستخدم غير مصرح له بالوصول';
    END IF;

    -- Validate input parameters
    IF p_batch_id IS NULL OR p_batch_id <= 0 THEN
        RAISE EXCEPTION 'معرف دفعة الإنتاج غير صحيح';
    END IF;

    IF p_new_status IS NULL OR p_new_status NOT IN ('pending', 'in_progress', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'حالة الدفعة غير صحيحة. الحالات المسموحة: pending, in_progress, completed, cancelled';
    END IF;

    -- Get current batch information
    SELECT 
        pb.id,
        pb.product_id,
        pb.units_produced,
        pb.status,
        pb.notes,
        pb.warehouse_manager_id,
        pb.completion_date,
        pb.created_at
    INTO v_batch_record
    FROM production_batches pb
    WHERE pb.id = p_batch_id;

    -- Check if batch exists
    IF v_batch_record.id IS NULL THEN
        RAISE EXCEPTION 'دفعة الإنتاج غير موجودة';
    END IF;

    -- Store old status for logging
    v_old_status := v_batch_record.status;

    -- Prevent unnecessary updates
    IF v_old_status = p_new_status THEN
        RETURN jsonb_build_object(
            'success', true,
            'batch_id', p_batch_id,
            'old_status', v_old_status,
            'new_status', p_new_status,
            'updated_at', NOW(),
            'message', 'الحالة لم تتغير - نفس الحالة الحالية'
        );
    END IF;

    -- Update production batch status
    UPDATE production_batches
    SET 
        status = p_new_status,
        notes = COALESCE(p_notes, notes),
        updated_at = NOW(),
        -- Set completion_date when status changes to 'completed'
        completion_date = CASE 
            WHEN p_new_status = 'completed' AND v_old_status != 'completed' 
            THEN NOW() 
            ELSE completion_date 
        END
    WHERE id = p_batch_id;

    -- FIXED: Log the status change with proper constraint-compliant values
    INSERT INTO tool_usage_history (
        tool_id, 
        batch_id, 
        quantity_used,      -- Set to 0 for status updates (allowed by new constraint)
        remaining_stock,    -- Set to 0 for status updates (satisfies NOT NULL and >= 0)
        operation_type, 
        notes, 
        warehouse_manager_id
    ) VALUES (
        NULL,               -- No specific tool for status changes
        p_batch_id,
        0,                  -- No quantity used for status updates (now allowed)
        0,                  -- No remaining stock change for status updates (satisfies constraints)
        'status_update',    -- Now allowed operation type
        'تغيير حالة دفعة الإنتاج من "' || v_old_status || '" إلى "' || p_new_status || '"' ||
        CASE WHEN p_notes IS NOT NULL THEN ' - ' || p_notes ELSE '' END,
        v_user_id
    );

    RETURN jsonb_build_object(
        'success', true,
        'batch_id', p_batch_id,
        'old_status', v_old_status,
        'new_status', p_new_status,
        'updated_at', NOW(),
        'message', 'تم تحديث حالة دفعة الإنتاج بنجاح'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'message', 'فشل في تحديث حالة دفعة الإنتاج'
        );
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION update_production_batch_status(INTEGER, VARCHAR(20), TEXT) TO authenticated;

-- Test notification
DO $$
BEGIN
    RAISE NOTICE '✅ Fixed update_production_batch_status function with constraint compliance';
    RAISE NOTICE '🔧 Added status_update to allowed operation types';
    RAISE NOTICE '🔧 Modified quantity_used constraint to allow 0 for status_update operations';
    RAISE NOTICE '🔧 Added proper remaining_stock value (0) for status update operations';
    RAISE NOTICE '📋 Function available: update_production_batch_status(batch_id, new_status, notes)';
    RAISE NOTICE '🚀 Production batch status updates should now work without constraint violations';
    RAISE NOTICE '📊 Valid status transitions: in_progress -> completed, pending -> in_progress, etc.';
END $$;
