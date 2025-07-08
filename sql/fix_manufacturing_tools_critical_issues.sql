-- =====================================================
-- SmartBizTracker: Fix Manufacturing Tools Critical Issues
-- =====================================================
-- This script fixes critical issues in the Manufacturing Tools module:
-- 1. Create missing get_required_tools_forecast PostgreSQL function
-- 2. Fix SQL GROUP BY clause error in warehouse locations
-- 3. Ensure compatibility with enhanced remaining stock calculation
-- =====================================================

-- Fix 1: Enhanced get_required_tools_forecast function with complete RequiredToolsForecast model support
CREATE OR REPLACE FUNCTION get_required_tools_forecast(
    p_product_id INTEGER,
    p_remaining_pieces DECIMAL(10,2)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_tools_count INTEGER := 0;
    v_available_tools_count INTEGER := 0;
    v_unavailable_tools_count INTEGER := 0;
    v_can_complete_production BOOLEAN := true;
    v_available_tools TEXT[] := '{}';
    v_unavailable_tools TEXT[] := '{}';
    v_required_tools JSONB := '[]'::jsonb;
    v_total_cost DECIMAL(10,2) := 0.0;
    v_recipe_record RECORD;
    v_required_quantity DECIMAL(10,2);
    v_shortfall DECIMAL(10,2);
    v_availability_status VARCHAR(20);
    v_estimated_cost DECIMAL(10,2);
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
    IF p_product_id IS NULL OR p_remaining_pieces IS NULL OR p_remaining_pieces < 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'معاملات غير صحيحة'
        );
    END IF;

    -- Handle zero remaining pieces case
    IF p_remaining_pieces = 0 THEN
        RETURN jsonb_build_object(
            'success', true,
            'product_id', p_product_id,
            'remaining_pieces', 0.0,
            'required_tools', '[]'::jsonb,
            'can_complete_production', true,
            'unavailable_tools', '[]'::jsonb,
            'total_cost', 0.0
        );
    END IF;

    -- Check if production recipe exists for this product
    IF NOT EXISTS (SELECT 1 FROM production_recipes WHERE product_id = p_product_id) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'لا توجد وصفة إنتاج لهذا المنتج'
        );
    END IF;

    -- Build detailed tool requirements array matching RequiredToolItem model
    FOR v_recipe_record IN
        SELECT
            pr.tool_id,
            pr.quantity_required,
            mt.name as tool_name,
            mt.quantity as current_stock,
            mt.unit,
            COALESCE(mt.cost_per_unit, 0) as cost_per_unit
        FROM production_recipes pr
        JOIN manufacturing_tools mt ON pr.tool_id = mt.id
        WHERE pr.product_id = p_product_id
        ORDER BY mt.name
    LOOP
        v_tools_count := v_tools_count + 1;
        v_required_quantity := v_recipe_record.quantity_required * p_remaining_pieces;

        -- Calculate shortfall
        v_shortfall := GREATEST(0, v_required_quantity - v_recipe_record.current_stock);

        -- Determine availability status
        IF v_recipe_record.current_stock >= v_required_quantity THEN
            v_availability_status := 'available';
        ELSIF v_recipe_record.current_stock > 0 THEN
            v_availability_status := 'partial';
        ELSE
            v_availability_status := 'unavailable';
        END IF;

        -- Calculate estimated cost for shortfall
        v_estimated_cost := v_shortfall * v_recipe_record.cost_per_unit;
        v_total_cost := v_total_cost + v_estimated_cost;

        -- Add to required tools array with complete RequiredToolItem structure
        v_required_tools := v_required_tools || jsonb_build_object(
            'tool_id', v_recipe_record.tool_id,
            'tool_name', v_recipe_record.tool_name,
            'unit', v_recipe_record.unit,
            'quantity_per_unit', v_recipe_record.quantity_required,
            'total_quantity_needed', v_required_quantity,
            'available_stock', v_recipe_record.current_stock,
            'shortfall', v_shortfall,
            'is_available', v_recipe_record.current_stock >= v_required_quantity,
            'availability_status', v_availability_status,
            'estimated_cost', CASE WHEN v_estimated_cost > 0 THEN v_estimated_cost ELSE NULL END
        );

        -- Update availability counters
        IF v_recipe_record.current_stock >= v_required_quantity THEN
            v_available_tools_count := v_available_tools_count + 1;
            v_available_tools := v_available_tools || v_recipe_record.tool_name;
        ELSE
            v_unavailable_tools_count := v_unavailable_tools_count + 1;
            v_unavailable_tools := v_unavailable_tools || v_recipe_record.tool_name;
            v_can_complete_production := false;
        END IF;
    END LOOP;

    -- Return comprehensive forecast data matching RequiredToolsForecast model
    RETURN jsonb_build_object(
        'success', true,
        'product_id', p_product_id,
        'remaining_pieces', p_remaining_pieces,
        'required_tools', v_required_tools,
        'can_complete_production', v_can_complete_production,
        'unavailable_tools', v_unavailable_tools,
        'total_cost', v_total_cost,
        -- Additional metadata for debugging and analytics
        'tools_count', v_tools_count,
        'available_tools_count', v_available_tools_count,
        'unavailable_tools_count', v_unavailable_tools_count,
        'available_tools', v_available_tools,
        'forecast_generated_at', NOW()
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في توليد توقعات الأدوات: ' || SQLERRM,
            'error_code', SQLSTATE
        );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_required_tools_forecast(INTEGER, DECIMAL(10,2)) TO authenticated;

-- Fix 2: Create improved get_product_warehouse_locations function without GROUP BY issues
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

    -- Get warehouse locations with stock quantities (Fixed GROUP BY issue)
    SELECT jsonb_build_object(
        'success', true,
        'locations', COALESCE(
            jsonb_agg(
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
                ) ORDER BY wi.quantity DESC
            ),
            '[]'::jsonb
        )
    ) INTO v_locations
    FROM warehouse_inventory wi
    INNER JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE wi.product_id = p_product_id
    AND w.is_active = true;

    RETURN v_locations;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في جلب مواقع المنتج: ' || SQLERRM,
            'error_code', SQLSTATE
        );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_product_warehouse_locations(TEXT) TO authenticated;

-- Fix 3: Create helper function for RequiredToolsForecast model compatibility
CREATE OR REPLACE FUNCTION get_required_tools_forecast_simple(
    p_product_id INTEGER,
    p_remaining_pieces DECIMAL(10,2)
)
RETURNS TABLE (
    tools_count INTEGER,
    available_tools_count INTEGER,
    unavailable_tools_count INTEGER,
    can_complete_production BOOLEAN,
    available_tools TEXT[],
    unavailable_tools TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_forecast_data JSONB;
BEGIN
    -- Call the main forecast function
    v_forecast_data := get_required_tools_forecast(p_product_id, p_remaining_pieces);
    
    -- Check if successful
    IF (v_forecast_data->>'success')::boolean = false THEN
        RAISE EXCEPTION '%', v_forecast_data->>'error';
    END IF;
    
    -- Return structured data
    RETURN QUERY
    SELECT 
        (v_forecast_data->>'tools_count')::INTEGER,
        (v_forecast_data->>'available_tools_count')::INTEGER,
        (v_forecast_data->>'unavailable_tools_count')::INTEGER,
        (v_forecast_data->>'can_complete_production')::BOOLEAN,
        ARRAY(SELECT jsonb_array_elements_text(v_forecast_data->'available_tools')),
        ARRAY(SELECT jsonb_array_elements_text(v_forecast_data->'unavailable_tools'));
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_required_tools_forecast_simple(INTEGER, DECIMAL(10,2)) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION get_required_tools_forecast(INTEGER, DECIMAL(10,2)) IS 'Generate comprehensive tools forecast for remaining production pieces';
COMMENT ON FUNCTION get_product_warehouse_locations(TEXT) IS 'Get warehouse locations for a product without GROUP BY issues';
COMMENT ON FUNCTION get_required_tools_forecast_simple(INTEGER, DECIMAL(10,2)) IS 'Simplified tools forecast function for model compatibility';

-- Fix 4: Ensure products table has correct schema
DO $$
BEGIN
    -- Check if 'active' column exists, if not add it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products'
        AND column_name = 'active'
    ) THEN
        ALTER TABLE products ADD COLUMN active BOOLEAN DEFAULT true;
        RAISE NOTICE '✅ Added active column to products table';
    END IF;

    -- If 'is_active' column exists and 'active' doesn't have data, migrate it
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products'
        AND column_name = 'is_active'
    ) AND EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products'
        AND column_name = 'active'
    ) THEN
        UPDATE products SET active = is_active WHERE active IS NULL;
        RAISE NOTICE '✅ Migrated is_active data to active column';
    END IF;
END $$;

-- Fix 5: Create index for better performance
CREATE INDEX IF NOT EXISTS idx_production_recipes_product_id ON production_recipes(product_id);
CREATE INDEX IF NOT EXISTS idx_manufacturing_tools_active ON manufacturing_tools(id) WHERE quantity > 0;
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_product_active ON warehouse_inventory(product_id) WHERE quantity > 0;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ MANUFACTURING_TOOLS_CRITICAL_ISSUES_FIXED: All PostgreSQL functions created successfully';
    RAISE NOTICE '✅ Database schema issues resolved';
    RAISE NOTICE '✅ Performance indexes created';
    RAISE NOTICE '✅ Ready for Manufacturing Tools module operation';
END $$;
