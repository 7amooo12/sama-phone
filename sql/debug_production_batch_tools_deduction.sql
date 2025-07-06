-- =====================================================
-- DEBUG PRODUCTION BATCH TOOLS DEDUCTION
-- =====================================================
-- This script helps diagnose why manufacturing tools aren't being deducted

-- 1. Enhanced update_production_batch_quantity function with detailed logging
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
    v_recipe_count INTEGER := 0;
    v_tools_updated INTEGER := 0;
    v_debug_info JSONB := '[]'::jsonb;
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

    -- Count available recipes for this product
    SELECT COUNT(*) INTO v_recipe_count
    FROM production_recipes pr
    JOIN manufacturing_tools mt ON pr.tool_id = mt.id
    WHERE pr.product_id = v_batch_record.product_id;

    -- Add debug info about recipes found
    v_debug_info := v_debug_info || jsonb_build_object(
        'product_id', v_batch_record.product_id,
        'recipes_found', v_recipe_count,
        'quantity_difference', v_quantity_difference
    );

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
            
            -- Add debug info for each recipe
            v_debug_info := v_debug_info || jsonb_build_object(
                'tool_id', v_recipe.tool_id,
                'tool_name', v_recipe.tool_name,
                'quantity_required_per_unit', v_recipe.quantity_required,
                'current_stock', v_recipe.current_stock,
                'required_for_increase', v_required_quantity
            );
            
            IF v_recipe.current_stock < v_required_quantity THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'error', 'مخزون غير كافي من الأداة: ' || v_recipe.tool_name || 
                            ' (متوفر: ' || v_recipe.current_stock || ', مطلوب: ' || v_required_quantity || ')',
                    'debug_info', v_debug_info
                );
            END IF;
        END LOOP;

        -- Deduct materials from inventory
        FOR v_recipe IN
            SELECT pr.tool_id, pr.quantity_required, mt.quantity as current_stock, mt.name as tool_name
            FROM production_recipes pr
            JOIN manufacturing_tools mt ON pr.tool_id = mt.id
            WHERE pr.product_id = v_batch_record.product_id
        LOOP
            v_required_quantity := v_recipe.quantity_required * v_quantity_difference;
            v_new_tool_stock := v_recipe.current_stock - v_required_quantity;

            -- Update tool quantity with detailed logging
            BEGIN
                PERFORM update_tool_quantity(
                    v_recipe.tool_id,
                    v_new_tool_stock,
                    'production',
                    'تحديث كمية دفعة الإنتاج رقم ' || p_batch_id::TEXT || 
                    CASE WHEN p_notes IS NOT NULL THEN ' - ' || p_notes ELSE '' END,
                    p_batch_id
                );
                
                v_tools_updated := v_tools_updated + 1;
                
                -- Add success info to debug
                v_debug_info := v_debug_info || jsonb_build_object(
                    'tool_updated', v_recipe.tool_name,
                    'old_stock', v_recipe.current_stock,
                    'new_stock', v_new_tool_stock,
                    'deducted_amount', v_required_quantity
                );
                
            EXCEPTION
                WHEN OTHERS THEN
                    -- Add error info to debug
                    v_debug_info := v_debug_info || jsonb_build_object(
                        'tool_update_error', v_recipe.tool_name,
                        'error_message', SQLERRM
                    );
                    
                    RETURN jsonb_build_object(
                        'success', false,
                        'error', 'فشل في تحديث كمية الأداة: ' || v_recipe.tool_name || ' - ' || SQLERRM,
                        'debug_info', v_debug_info
                    );
            END;
        END LOOP;
    END IF;

    -- Update the production batch
    UPDATE production_batches
    SET 
        units_produced = p_new_quantity,
        notes = COALESCE(p_notes, notes),
        updated_at = NOW()
    WHERE id = p_batch_id;

    RETURN jsonb_build_object(
        'success', true,
        'batch_id', p_batch_id,
        'old_quantity', v_batch_record.units_produced,
        'new_quantity', p_new_quantity,
        'quantity_difference', v_quantity_difference,
        'recipes_found', v_recipe_count,
        'tools_updated', v_tools_updated,
        'message', 'تم تحديث كمية دفعة الإنتاج بنجاح',
        'debug_info', v_debug_info
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في تحديث دفعة الإنتاج: ' || SQLERRM,
            'error_code', SQLSTATE,
            'debug_info', v_debug_info
        );
END;
$$;

-- 2. Function to check production recipes for a specific product
CREATE OR REPLACE FUNCTION debug_production_recipes(p_product_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_recipes JSONB;
    v_recipe_count INTEGER;
BEGIN
    -- Get all recipes for the product
    SELECT 
        COUNT(*) as recipe_count,
        jsonb_agg(
            jsonb_build_object(
                'recipe_id', pr.id,
                'tool_id', pr.tool_id,
                'tool_name', mt.name,
                'quantity_required', pr.quantity_required,
                'current_tool_stock', mt.quantity,
                'tool_unit', mt.unit,
                'created_at', pr.created_at
            )
        ) as recipes
    INTO v_recipe_count, v_recipes
    FROM production_recipes pr
    JOIN manufacturing_tools mt ON pr.tool_id = mt.id
    WHERE pr.product_id = p_product_id;

    RETURN jsonb_build_object(
        'product_id', p_product_id,
        'recipe_count', COALESCE(v_recipe_count, 0),
        'recipes', COALESCE(v_recipes, '[]'::jsonb)
    );
END;
$$;

-- 3. Function to check manufacturing tools status
CREATE OR REPLACE FUNCTION debug_manufacturing_tools()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tools JSONB;
    v_tool_count INTEGER;
BEGIN
    SELECT 
        COUNT(*) as tool_count,
        jsonb_agg(
            jsonb_build_object(
                'tool_id', mt.id,
                'tool_name', mt.name,
                'current_quantity', mt.quantity,
                'initial_stock', mt.initial_stock,
                'unit', mt.unit,
                'updated_at', mt.updated_at
            )
        ) as tools
    INTO v_tool_count, v_tools
    FROM manufacturing_tools mt
    ORDER BY mt.name;

    RETURN jsonb_build_object(
        'tool_count', COALESCE(v_tool_count, 0),
        'tools', COALESCE(v_tools, '[]'::jsonb)
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION update_production_batch_quantity(INTEGER, DECIMAL(10,2), TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION debug_production_recipes(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION debug_manufacturing_tools() TO authenticated;

-- 4. Function to create sample production recipes for testing
CREATE OR REPLACE FUNCTION create_sample_production_recipes()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_product_ids INTEGER[];
    v_tool_ids INTEGER[];
    v_recipes_created INTEGER := 0;
    v_product_id INTEGER;
    v_tool_id INTEGER;
BEGIN
    -- Get current user ID
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المستخدم غير مصرح له بالوصول'
        );
    END IF;

    -- Get available product IDs from production_batches
    SELECT ARRAY_AGG(DISTINCT product_id) INTO v_product_ids
    FROM production_batches
    LIMIT 10;

    -- Get available tool IDs from manufacturing_tools
    SELECT ARRAY_AGG(id) INTO v_tool_ids
    FROM manufacturing_tools
    LIMIT 10;

    -- Check if we have both products and tools
    IF v_product_ids IS NULL OR array_length(v_product_ids, 1) = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'لا توجد منتجات في دفعات الإنتاج'
        );
    END IF;

    IF v_tool_ids IS NULL OR array_length(v_tool_ids, 1) = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'لا توجد أدوات تصنيع متاحة'
        );
    END IF;

    -- Create sample recipes (each product uses 1-3 tools)
    FOREACH v_product_id IN ARRAY v_product_ids
    LOOP
        -- Skip if recipes already exist for this product
        IF EXISTS (SELECT 1 FROM production_recipes WHERE product_id = v_product_id) THEN
            CONTINUE;
        END IF;

        -- Add 1-3 tools per product
        FOR i IN 1..LEAST(3, array_length(v_tool_ids, 1))
        LOOP
            v_tool_id := v_tool_ids[i];

            -- Insert recipe with random quantity between 0.5 and 3.0
            INSERT INTO production_recipes (product_id, tool_id, quantity_required, created_by)
            VALUES (
                v_product_id,
                v_tool_id,
                ROUND((0.5 + random() * 2.5)::numeric, 2), -- Random between 0.5 and 3.0
                v_user_id
            )
            ON CONFLICT (product_id, tool_id) DO NOTHING;

            IF FOUND THEN
                v_recipes_created := v_recipes_created + 1;
            END IF;
        END LOOP;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'recipes_created', v_recipes_created,
        'products_processed', array_length(v_product_ids, 1),
        'tools_available', array_length(v_tool_ids, 1),
        'message', 'تم إنشاء ' || v_recipes_created || ' وصفة إنتاج تجريبية'
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في إنشاء وصفات الإنتاج: ' || SQLERRM
        );
END;
$$;

-- Grant permission
GRANT EXECUTE ON FUNCTION create_sample_production_recipes() TO authenticated;

-- Test message
DO $$
BEGIN
    RAISE NOTICE '✅ Enhanced production batch function with debugging deployed';
    RAISE NOTICE '🔍 New debug functions available:';
    RAISE NOTICE '   - debug_production_recipes(product_id) - Check recipes for a product';
    RAISE NOTICE '   - debug_manufacturing_tools() - Check all manufacturing tools';
    RAISE NOTICE '   - create_sample_production_recipes() - Create sample recipes for testing';
    RAISE NOTICE '📊 The update function now returns detailed debug information';
    RAISE NOTICE '🚀 To test: SELECT create_sample_production_recipes();';
END $$;
