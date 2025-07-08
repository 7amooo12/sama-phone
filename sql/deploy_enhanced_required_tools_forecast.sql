-- =====================================================
-- SmartBizTracker: Deploy Enhanced Required Tools Forecast Function
-- =====================================================
-- This script deploys the enhanced get_required_tools_forecast function
-- that supports the complete RequiredToolsForecast model with professional features
-- =====================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_required_tools_forecast(INTEGER, DECIMAL(10,2));

-- Enhanced get_required_tools_forecast function with complete RequiredToolsForecast model support
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

-- Add cost_per_unit column to manufacturing_tools table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'manufacturing_tools' 
        AND column_name = 'cost_per_unit'
    ) THEN
        ALTER TABLE manufacturing_tools 
        ADD COLUMN cost_per_unit DECIMAL(10,2) DEFAULT 0.0;
        
        -- Update existing records with default cost
        UPDATE manufacturing_tools 
        SET cost_per_unit = 10.0 
        WHERE cost_per_unit IS NULL OR cost_per_unit = 0;
        
        RAISE NOTICE 'Added cost_per_unit column to manufacturing_tools table';
    END IF;
END $$;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_production_recipes_product_id 
ON production_recipes(product_id);

CREATE INDEX IF NOT EXISTS idx_manufacturing_tools_id 
ON manufacturing_tools(id);

-- Verify function deployment
DO $$
DECLARE
    v_test_result JSONB;
BEGIN
    -- Test the function with a simple case
    SELECT get_required_tools_forecast(1, 0.0) INTO v_test_result;
    
    IF (v_test_result->>'success')::boolean = true THEN
        RAISE NOTICE 'Enhanced Required Tools Forecast function deployed successfully!';
    ELSE
        RAISE NOTICE 'Function deployment verification failed: %', v_test_result->>'error';
    END IF;
END $$;
