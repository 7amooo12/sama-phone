-- =====================================================
-- Production Batch Status Management Functions
-- SmartBizTracker Manufacturing System
-- =====================================================

-- Function to create production batch with 'in_progress' status
CREATE OR REPLACE FUNCTION create_production_batch_in_progress(
    p_product_id INTEGER,
    p_units_produced DECIMAL(10,2),
    p_notes TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_batch_id INTEGER;
    v_user_id UUID;
    v_recipe RECORD;
    v_required_quantity DECIMAL(10,2);
    v_new_tool_stock DECIMAL(10,2);
BEGIN
    -- Get current user ID
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'المستخدم غير مصرح له بالوصول';
    END IF;

    -- Validate input parameters
    IF p_product_id IS NULL OR p_product_id <= 0 THEN
        RAISE EXCEPTION 'معرف المنتج غير صحيح';
    END IF;

    IF p_units_produced IS NULL OR p_units_produced <= 0 THEN
        RAISE EXCEPTION 'عدد الوحدات المنتجة يجب أن يكون أكبر من صفر';
    END IF;

    -- Check if production recipes exist for this product
    IF NOT EXISTS (
        SELECT 1 FROM production_recipes 
        WHERE product_id = p_product_id
    ) THEN
        RAISE EXCEPTION 'لا توجد وصفة إنتاج لهذا المنتج';
    END IF;

    -- Check if sufficient materials are available
    FOR v_recipe IN
        SELECT pr.tool_id, pr.quantity_required, mt.quantity as current_stock, mt.name as tool_name
        FROM production_recipes pr
        JOIN manufacturing_tools mt ON pr.tool_id = mt.id
        WHERE pr.product_id = p_product_id
    LOOP
        v_required_quantity := v_recipe.quantity_required * p_units_produced;
        
        IF v_recipe.current_stock < v_required_quantity THEN
            RAISE EXCEPTION 'مخزون غير كافي من الأداة: % (متوفر: %, مطلوب: %)', 
                v_recipe.tool_name, v_recipe.current_stock, v_required_quantity;
        END IF;
    END LOOP;

    -- Deduct materials from manufacturing tools inventory
    FOR v_recipe IN
        SELECT pr.tool_id, pr.quantity_required, mt.quantity as current_stock
        FROM production_recipes pr
        JOIN manufacturing_tools mt ON pr.tool_id = mt.id
        WHERE pr.product_id = p_product_id
    LOOP
        v_required_quantity := v_recipe.quantity_required * p_units_produced;
        v_new_tool_stock := v_recipe.current_stock - v_required_quantity;

        -- Update tool quantity using 'production' operation type
        PERFORM update_tool_quantity(
            v_recipe.tool_id,
            v_new_tool_stock,
            'production',
            'بدء إنتاج دفعة جديدة - منتج رقم ' || p_product_id::TEXT || 
            CASE WHEN p_notes IS NOT NULL THEN ' - ' || p_notes ELSE '' END,
            NULL -- batch_id will be set after creation
        );
    END LOOP;

    -- Create production batch record with 'in_progress' status
    INSERT INTO production_batches (
        product_id, units_produced, warehouse_manager_id, status, notes
    ) VALUES (
        p_product_id, p_units_produced, v_user_id, 'in_progress', p_notes
    ) RETURNING id INTO v_batch_id;

    -- Update tool usage history with the actual batch_id
    UPDATE tool_usage_history 
    SET batch_id = v_batch_id 
    WHERE batch_id IS NULL 
      AND created_at >= NOW() - INTERVAL '1 minute'
      AND notes LIKE '%منتج رقم ' || p_product_id::TEXT || '%';

    RETURN v_batch_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'فشل في إنشاء دفعة الإنتاج: %', SQLERRM;
END;
$$;

-- Function to update production batch status from 'in_progress' to 'completed'
CREATE OR REPLACE FUNCTION update_production_batch_status(
    p_batch_id INTEGER,
    p_new_status VARCHAR(20),
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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
    SELECT * INTO v_batch_record
    FROM production_batches
    WHERE id = p_batch_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'دفعة الإنتاج غير موجودة';
    END IF;

    v_old_status := v_batch_record.status;

    -- Validate status transition
    IF v_old_status = 'completed' AND p_new_status != 'completed' THEN
        RAISE EXCEPTION 'لا يمكن تغيير حالة دفعة مكتملة';
    END IF;

    IF v_old_status = 'cancelled' AND p_new_status != 'cancelled' THEN
        RAISE EXCEPTION 'لا يمكن تغيير حالة دفعة ملغية';
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

    -- Log the status change
    INSERT INTO tool_usage_history (
        tool_id, batch_id, quantity_used, operation_type, notes, created_by
    ) VALUES (
        NULL, -- No specific tool for status changes
        p_batch_id,
        0, -- No quantity change for status updates
        'status_update',
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
GRANT EXECUTE ON FUNCTION create_production_batch_in_progress(INTEGER, DECIMAL(10,2), TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION update_production_batch_status(INTEGER, VARCHAR(20), TEXT) TO authenticated;

-- Test notification
DO $$
BEGIN
    RAISE NOTICE '✅ Production batch status management functions created successfully';
    RAISE NOTICE '📋 Functions available:';
    RAISE NOTICE '   - create_production_batch_in_progress(product_id, units_produced, notes)';
    RAISE NOTICE '   - update_production_batch_status(batch_id, new_status, notes)';
    RAISE NOTICE '🔧 Status transitions: in_progress -> completed';
    RAISE NOTICE '📊 Valid statuses: pending, in_progress, completed, cancelled';
END $$;
