-- =====================================================
-- SmartBizTracker: Enhanced Manufacturing Tools Calculation
-- =====================================================
-- This script modifies the get_batch_tool_usage_analytics function to implement
-- the new "Remaining Stock" calculation logic based on production data comparison.
--
-- New Formula: Remaining Stock = (Total Product Quantity - Current Production) × Tools Used Per Unit
-- =====================================================

-- Drop existing function to ensure clean deployment
DROP FUNCTION IF EXISTS get_batch_tool_usage_analytics(INTEGER);

-- Enhanced Function: Get batch tool usage analytics with production-based calculation
CREATE OR REPLACE FUNCTION get_batch_tool_usage_analytics(
    p_batch_id INTEGER
)
RETURNS TABLE (
    tool_id INTEGER,
    tool_name VARCHAR(100),
    unit VARCHAR(20),
    quantity_used_per_unit DECIMAL(10,2),
    total_quantity_used DECIMAL(10,2),
    remaining_stock DECIMAL(10,2),
    initial_stock DECIMAL(10,2),
    usage_percentage DECIMAL(5,2),
    stock_status VARCHAR(20),
    usage_history JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_units_produced DECIMAL(10,2);
    v_product_id INTEGER;
    v_total_product_quantity DECIMAL(10,2);
    v_remaining_production DECIMAL(10,2);
BEGIN
    -- Get batch information: units produced and product ID
    SELECT 
        COALESCE(pb.units_produced, 0),
        pb.product_id
    INTO v_units_produced, v_product_id
    FROM production_batches pb
    WHERE pb.id = p_batch_id;
    
    -- Get total product quantity from products table
    -- Note: production_batches.product_id (INTEGER) needs to be cast to TEXT to match products.id (TEXT)
    SELECT COALESCE(p.quantity, 0)
    INTO v_total_product_quantity
    FROM products p
    WHERE p.id = v_product_id::TEXT;
    
    -- Calculate remaining production needed
    v_remaining_production := GREATEST(v_total_product_quantity - v_units_produced, 0);
    
    -- If no units produced, set to 1 to avoid division by zero
    IF v_units_produced = 0 THEN
        v_units_produced := 1;
    END IF;
    
    -- If no product found or no total quantity, set defaults
    IF v_total_product_quantity IS NULL THEN
        v_total_product_quantity := 0;
        v_remaining_production := 0;
    END IF;

    RETURN QUERY
    SELECT 
        mt.id as tool_id,
        mt.name as tool_name,
        mt.unit,
        -- Tools used per unit (existing calculation)
        CASE 
            WHEN v_units_produced > 0 THEN COALESCE(usage_stats.total_used, 0) / v_units_produced
            ELSE 0
        END as quantity_used_per_unit,
        COALESCE(usage_stats.total_used, 0) as total_quantity_used,
        -- NEW CALCULATION: Remaining Stock = Remaining Production × Tools Used Per Unit
        CASE 
            WHEN v_units_produced > 0 AND v_remaining_production > 0 
            THEN v_remaining_production * (COALESCE(usage_stats.total_used, 0) / v_units_produced)
            ELSE 0
        END as remaining_stock,
        -- Initial stock calculation (for reference)
        (mt.quantity + COALESCE(usage_stats.total_used, 0)) as initial_stock,
        -- Usage percentage based on actual tool inventory
        CASE 
            WHEN (mt.quantity + COALESCE(usage_stats.total_used, 0)) > 0 
            THEN (COALESCE(usage_stats.total_used, 0) / (mt.quantity + COALESCE(usage_stats.total_used, 0)) * 100)
            ELSE 0
        END as usage_percentage,
        -- Stock status based on calculated remaining stock
        CASE 
            WHEN v_remaining_production * (COALESCE(usage_stats.total_used, 0) / GREATEST(v_units_produced, 1)) <= 0 THEN 'completed'::VARCHAR(20)
            WHEN v_remaining_production * (COALESCE(usage_stats.total_used, 0) / GREATEST(v_units_produced, 1)) <= 5 THEN 'low'::VARCHAR(20)
            WHEN v_remaining_production * (COALESCE(usage_stats.total_used, 0) / GREATEST(v_units_produced, 1)) <= 20 THEN 'medium'::VARCHAR(20)
            ELSE 'high'::VARCHAR(20)
        END as stock_status,
        COALESCE(usage_stats.usage_history, '[]'::jsonb) as usage_history
    FROM manufacturing_tools mt
    LEFT JOIN (
        SELECT 
            tuh.tool_id,
            SUM(tuh.quantity_used) as total_used,
            jsonb_agg(
                jsonb_build_object(
                    'id', tuh.id,
                    'batch_id', tuh.batch_id,
                    'quantity_used', tuh.quantity_used,
                    'usage_date', tuh.usage_date,
                    'notes', tuh.notes
                ) ORDER BY tuh.usage_date DESC
            ) as usage_history
        FROM tool_usage_history tuh
        WHERE tuh.batch_id = p_batch_id
        GROUP BY tuh.tool_id
    ) usage_stats ON mt.id = usage_stats.tool_id
    WHERE usage_stats.tool_id IS NOT NULL -- Only tools that were used in this batch
    ORDER BY usage_stats.total_used DESC;
END;
$$;

-- Grant permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_batch_tool_usage_analytics(INTEGER) TO authenticated;

-- =====================================================
-- VERIFICATION AND TESTING QUERIES
-- =====================================================

-- 1. Check if function was created successfully
SELECT 
    'ENHANCED_FUNCTION_STATUS' as check_type,
    routine_name,
    routine_type,
    'DEPLOYED_WITH_PRODUCTION_CALCULATION' as status
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'get_batch_tool_usage_analytics'
ORDER BY routine_name;

-- 2. Test the calculation logic with sample data
-- This query shows the calculation components for verification
SELECT 
    'CALCULATION_VERIFICATION' as test_type,
    pb.id as batch_id,
    pb.product_id,
    pb.units_produced as current_production,
    p.quantity as total_product_quantity,
    (p.quantity - pb.units_produced) as remaining_production,
    CASE 
        WHEN p.quantity IS NULL THEN 'PRODUCT_NOT_FOUND_IN_PRODUCTS_TABLE'
        WHEN pb.units_produced IS NULL THEN 'BATCH_NOT_FOUND'
        WHEN (p.quantity - pb.units_produced) < 0 THEN 'OVER_PRODUCTION_DETECTED'
        ELSE 'CALCULATION_READY'
    END as calculation_status
FROM production_batches pb
LEFT JOIN products p ON pb.product_id::TEXT = p.id
WHERE pb.id = 13  -- Test with batch ID 13
LIMIT 1;

-- 3. Test the enhanced function with batch ID 13 (example from requirements)
-- Uncomment the line below to test with actual data:
-- SELECT * FROM get_batch_tool_usage_analytics(13) LIMIT 5;

-- 4. Show calculation example for Product ID 185 (from requirements)
SELECT 
    'PRODUCT_185_EXAMPLE' as example_type,
    pb.id as batch_id,
    pb.product_id,
    pb.units_produced as current_production,
    p.quantity as total_product_quantity,
    (p.quantity - pb.units_produced) as remaining_production,
    'Formula: ' || (p.quantity - pb.units_produced) || ' × tools_used_per_unit = remaining_stock' as calculation_formula
FROM production_batches pb
LEFT JOIN products p ON pb.product_id::TEXT = p.id
WHERE pb.product_id = 185  -- Example Product ID from requirements
LIMIT 1;

-- Final success message
SELECT 
    '🎉 ENHANCED CALCULATION DEPLOYED' as status,
    'Remaining Stock = (Total Product Qty - Current Production) × Tools Used Per Unit' as formula,
    'Test with batch ID 13 and product ID 185' as test_instruction;
