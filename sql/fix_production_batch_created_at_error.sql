-- =====================================================
-- Fix for Production Batch Created_At Column Error
-- SmartBizTracker Manufacturing System
-- =====================================================
-- This fixes the PostgreSQL error: column "created_at" does not exist
-- The issue is in the create_production_batch_in_progress function
-- which references 'created_at' but the tool_usage_history table uses 'usage_date'
-- =====================================================

-- Function to create production batch with 'in_progress' status (FIXED VERSION)
CREATE OR REPLACE FUNCTION create_production_batch_in_progress(
    p_product_id INTEGER,
    p_units_produced DECIMAL(10,2),
    p_notes TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_batch_id INTEGER;
    v_user_id UUID;
    v_recipe RECORD;
    v_required_quantity DECIMAL(10,2);
    v_new_tool_stock DECIMAL(10,2);
BEGIN
    -- Get current user ID
    SELECT auth.uid() INTO v_user_id;
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'المستخدم غير مصرح له';
    END IF;

    -- Validate input parameters
    IF p_product_id IS NULL OR p_product_id <= 0 THEN
        RAISE EXCEPTION 'معرف المنتج غير صحيح';
    END IF;
    
    IF p_units_produced IS NULL OR p_units_produced <= 0 THEN
        RAISE EXCEPTION 'كمية الإنتاج يجب أن تكون أكبر من صفر';
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

    -- FIXED: Update tool usage history with the actual batch_id
    -- Changed 'created_at' to 'usage_date' to match the actual column name
    UPDATE tool_usage_history 
    SET batch_id = v_batch_id 
    WHERE batch_id IS NULL 
      AND usage_date >= NOW() - INTERVAL '1 minute'  -- FIXED: changed from created_at to usage_date
      AND notes LIKE '%منتج رقم ' || p_product_id::TEXT || '%';

    RETURN v_batch_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'فشل في إنشاء دفعة الإنتاج: %', SQLERRM;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION create_production_batch_in_progress(INTEGER, DECIMAL(10,2), TEXT) TO authenticated;

-- Test notification
DO $$
BEGIN
    RAISE NOTICE '✅ Fixed create_production_batch_in_progress function';
    RAISE NOTICE '🔧 Changed created_at to usage_date in tool_usage_history update';
    RAISE NOTICE '📋 Function available: create_production_batch_in_progress(product_id, units_produced, notes)';
    RAISE NOTICE '🚀 Production batch creation should now work without column errors';
END $$;
