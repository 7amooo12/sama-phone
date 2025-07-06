-- =====================================================
-- PRODUCTION BATCH MANAGEMENT DATABASE FUNCTIONS
-- =====================================================
-- These functions support production batch quantity updates and inventory management

-- 1. Function to update production batch quantity with inventory management
CREATE OR REPLACE FUNCTION update_production_batch_quantity(
    p_batch_id INTEGER,
    p_new_quantity DECIMAL(10,2),
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_batch_record RECORD;
    v_quantity_difference DECIMAL(10,2);
    v_recipe RECORD;
    v_required_quantity DECIMAL(10,2);
    v_current_tool_stock DECIMAL(10,2);
    v_new_tool_stock DECIMAL(10,2);
    v_batch_id INTEGER;
BEGIN
    -- Get current user ID
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المستخدم غير مصرح له بالوصول'
        );
    END IF;

    -- Validate input parameters
    IF p_batch_id IS NULL OR p_batch_id <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'معرف دفعة الإنتاج غير صحيح'
        );
    END IF;

    IF p_new_quantity IS NULL OR p_new_quantity <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'الكمية الجديدة يجب أن تكون أكبر من صفر'
        );
    END IF;

    -- Get current batch information
    SELECT * INTO v_batch_record
    FROM production_batches
    WHERE id = p_batch_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'دفعة الإنتاج غير موجودة'
        );
    END IF;

    -- Calculate quantity difference
    v_quantity_difference := p_new_quantity - v_batch_record.units_produced;

    -- If quantity is being increased, check material availability and deduct
    IF v_quantity_difference > 0 THEN
        -- Check if we have enough materials for the increase
        FOR v_recipe IN
            SELECT pr.tool_id, pr.quantity_required, mt.quantity as current_stock, mt.name as tool_name
            FROM production_recipes pr
            JOIN manufacturing_tools mt ON pr.tool_id = mt.id
            WHERE pr.product_id = v_batch_record.product_id
        LOOP
            v_required_quantity := v_recipe.quantity_required * v_quantity_difference;
            
            IF v_recipe.current_stock < v_required_quantity THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'error', 'مخزون غير كافي من الأداة: ' || v_recipe.tool_name || 
                            ' (متوفر: ' || v_recipe.current_stock || ', مطلوب: ' || v_required_quantity || ')'
                );
            END IF;
        END LOOP;

        -- Deduct materials from inventory
        FOR v_recipe IN
            SELECT pr.tool_id, pr.quantity_required, mt.quantity as current_stock
            FROM production_recipes pr
            JOIN manufacturing_tools mt ON pr.tool_id = mt.id
            WHERE pr.product_id = v_batch_record.product_id
        LOOP
            v_required_quantity := v_recipe.quantity_required * v_quantity_difference;
            v_new_tool_stock := v_recipe.current_stock - v_required_quantity;

            -- Update tool quantity
            PERFORM update_tool_quantity(
                v_recipe.tool_id,
                v_new_tool_stock,
                'production',
                'تحديث كمية دفعة الإنتاج رقم ' || p_batch_id::TEXT ||
                CASE WHEN p_notes IS NOT NULL THEN ' - ' || p_notes ELSE '' END,
                p_batch_id
            );
        END LOOP;
    END IF;

    -- Update the production batch
    UPDATE production_batches
    SET 
        units_produced = p_new_quantity,
        notes = COALESCE(p_notes, notes),
        updated_at = NOW()
    WHERE id = p_batch_id;

    -- Add the increased quantity to product inventory (if quantity increased)
    IF v_quantity_difference > 0 THEN
        -- This will be handled by a separate function call from the application
        -- to add inventory to the appropriate warehouse
        NULL;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'batch_id', p_batch_id,
        'old_quantity', v_batch_record.units_produced,
        'new_quantity', p_new_quantity,
        'quantity_difference', v_quantity_difference,
        'message', 'تم تحديث كمية دفعة الإنتاج بنجاح'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في تحديث دفعة الإنتاج: ' || SQLERRM,
            'error_code', SQLSTATE
        );
END;
$$;

-- 2. Function to get warehouse locations for a product
CREATE OR REPLACE FUNCTION get_product_warehouse_locations(
    p_product_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_locations JSONB;
BEGIN
    -- Get current user ID
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المستخدم غير مصرح له بالوصول'
        );
    END IF;

    -- Get warehouse locations with stock quantities
    SELECT jsonb_agg(
        jsonb_build_object(
            'warehouse_id', wi.warehouse_id,
            'warehouse_name', w.name,
            'warehouse_address', w.address,
            'quantity', wi.quantity,
            'minimum_stock', wi.minimum_stock,
            'maximum_stock', wi.maximum_stock,
            'stock_status', 
                CASE 
                    WHEN wi.quantity = 0 THEN 'نفد المخزون'
                    WHEN wi.quantity <= COALESCE(wi.minimum_stock, 10) THEN 'مخزون منخفض'
                    ELSE 'متوفر'
                END,
            'last_updated', wi.last_updated
        )
    ) INTO v_locations
    FROM warehouse_inventory wi
    INNER JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE wi.product_id = p_product_id
    AND w.is_active = true
    ORDER BY wi.quantity DESC;

    RETURN jsonb_build_object(
        'success', true,
        'product_id', p_product_id,
        'locations', COALESCE(v_locations, '[]'::jsonb),
        'total_locations', COALESCE(jsonb_array_length(v_locations), 0)
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في جلب مواقع المنتج: ' || SQLERRM
        );
END;
$$;

-- 3. Function to add inventory to product after production increase
CREATE OR REPLACE FUNCTION add_production_inventory_to_warehouse(
    p_product_id TEXT,
    p_quantity INTEGER,
    p_warehouse_id UUID DEFAULT NULL,
    p_batch_id INTEGER DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_target_warehouse_id UUID;
    v_warehouse_name TEXT;
    v_current_quantity INTEGER := 0;
    v_new_quantity INTEGER;
    v_transaction_result JSONB;
BEGIN
    -- Get current user ID
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المستخدم غير مصرح له بالوصول'
        );
    END IF;

    -- Validate input
    IF p_product_id IS NULL OR p_quantity <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'معرف المنتج أو الكمية غير صحيحة'
        );
    END IF;

    -- Determine target warehouse
    IF p_warehouse_id IS NOT NULL THEN
        v_target_warehouse_id := p_warehouse_id;
    ELSE
        -- Find the warehouse with the highest stock for this product
        SELECT wi.warehouse_id INTO v_target_warehouse_id
        FROM warehouse_inventory wi
        INNER JOIN warehouses w ON wi.warehouse_id = w.id
        WHERE wi.product_id = p_product_id
        AND w.is_active = true
        ORDER BY wi.quantity DESC
        LIMIT 1;

        -- If no existing inventory, use the first active warehouse
        IF v_target_warehouse_id IS NULL THEN
            SELECT id INTO v_target_warehouse_id
            FROM warehouses
            WHERE is_active = true
            ORDER BY created_at ASC
            LIMIT 1;
        END IF;
    END IF;

    -- Validate warehouse exists
    SELECT name INTO v_warehouse_name
    FROM warehouses
    WHERE id = v_target_warehouse_id AND is_active = true;

    IF v_warehouse_name IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المخزن المحدد غير موجود أو غير نشط'
        );
    END IF;

    -- Get current quantity in warehouse
    SELECT quantity INTO v_current_quantity
    FROM warehouse_inventory
    WHERE warehouse_id = v_target_warehouse_id AND product_id = p_product_id;

    v_current_quantity := COALESCE(v_current_quantity, 0);
    v_new_quantity := v_current_quantity + p_quantity;

    -- Update or insert inventory record
    INSERT INTO warehouse_inventory (
        warehouse_id, product_id, quantity, last_updated, updated_by
    ) VALUES (
        v_target_warehouse_id, p_product_id, v_new_quantity, NOW(), v_user_id
    )
    ON CONFLICT (warehouse_id, product_id)
    DO UPDATE SET
        quantity = v_new_quantity,
        last_updated = NOW(),
        updated_by = v_user_id;

    -- Create transaction record
    INSERT INTO warehouse_transactions (
        transaction_number,
        type,
        warehouse_id,
        product_id,
        quantity,
        quantity_before,
        quantity_after,
        reason,
        reference_id,
        reference_type,
        performed_by
    ) VALUES (
        'TXN-' || EXTRACT(EPOCH FROM NOW())::BIGINT || '-' || SUBSTRING(gen_random_uuid()::TEXT, 1, 8),
        'stock_in',
        v_target_warehouse_id,
        p_product_id,
        p_quantity,
        v_current_quantity,
        v_new_quantity,
        COALESCE(p_notes, 'إضافة مخزون من الإنتاج' || 
                CASE WHEN p_batch_id IS NOT NULL THEN ' - دفعة رقم ' || p_batch_id::TEXT ELSE '' END),
        CASE WHEN p_batch_id IS NOT NULL THEN p_batch_id::TEXT ELSE NULL END,
        'production',
        v_user_id
    );

    RETURN jsonb_build_object(
        'success', true,
        'warehouse_id', v_target_warehouse_id,
        'warehouse_name', v_warehouse_name,
        'product_id', p_product_id,
        'quantity_added', p_quantity,
        'quantity_before', v_current_quantity,
        'quantity_after', v_new_quantity,
        'message', 'تم إضافة ' || p_quantity || ' وحدة إلى مخزن ' || v_warehouse_name
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في إضافة المخزون: ' || SQLERRM,
            'error_code', SQLSTATE
        );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION update_production_batch_quantity(INTEGER, DECIMAL(10,2), TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_product_warehouse_locations(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION add_production_inventory_to_warehouse(TEXT, INTEGER, UUID, INTEGER, TEXT) TO authenticated;
