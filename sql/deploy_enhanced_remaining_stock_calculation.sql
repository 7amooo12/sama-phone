-- =====================================================
-- SmartBizTracker: Enhanced Remaining Stock Calculation
-- =====================================================
-- This script implements the new "Remaining Stock" calculation for the
-- Manufacturing Tools Tracking module in Production Batch Details Screen
--
-- Formula: Remaining Stock = (Total Product Quantity - Current Production) × Tools Used Per Unit
-- Target: Used Manufacturing Tools Section (أدوات التصنيع المستخدمة)
-- =====================================================

-- Drop existing function to ensure clean deployment
DROP FUNCTION IF EXISTS get_batch_tool_usage_analytics(INTEGER);

-- Enhanced Function: Production-based remaining stock calculation
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
    v_batch_exists BOOLEAN := FALSE;
BEGIN
    -- Get batch information: units produced and product ID
    SELECT 
        COALESCE(pb.units_produced, 0),
        pb.product_id,
        TRUE
    INTO v_units_produced, v_product_id, v_batch_exists
    FROM production_batches pb
    WHERE pb.id = p_batch_id;
    
    -- If batch doesn't exist, return empty result
    IF NOT v_batch_exists THEN
        RETURN;
    END IF;
    
    -- Get total product quantity from products table
    -- Cast INTEGER product_id to TEXT to match products.id
    SELECT COALESCE(p.quantity, 0)
    INTO v_total_product_quantity
    FROM products p
    WHERE p.id = v_product_id::TEXT;
    
    -- Calculate remaining production needed
    -- Ensure it's never negative (handle over-production)
    v_remaining_production := GREATEST(v_total_product_quantity - v_units_produced, 0);
    
    -- Handle edge cases
    IF v_units_produced = 0 THEN
        v_units_produced := 1; -- Avoid division by zero
    END IF;
    
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
        -- 🎯 NEW CALCULATION: Remaining Stock = Remaining Production × Tools Used Per Unit
        CASE 
            WHEN v_units_produced > 0 AND v_remaining_production > 0 
            THEN v_remaining_production * (COALESCE(usage_stats.total_used, 0) / v_units_produced)
            ELSE 0
        END as remaining_stock,
        -- Initial stock (for reference - raw tool inventory + used)
        (mt.quantity + COALESCE(usage_stats.total_used, 0)) as initial_stock,
        -- Usage percentage based on actual tool inventory
        CASE 
            WHEN (mt.quantity + COALESCE(usage_stats.total_used, 0)) > 0 
            THEN (COALESCE(usage_stats.total_used, 0) / (mt.quantity + COALESCE(usage_stats.total_used, 0)) * 100)
            ELSE 0
        END as usage_percentage,
        -- Stock status based on calculated remaining stock
        CASE 
            WHEN v_remaining_production = 0 THEN 'completed'::VARCHAR(20)
            WHEN v_remaining_production * (COALESCE(usage_stats.total_used, 0) / GREATEST(v_units_produced, 1)) <= 0 THEN 'out_of_stock'::VARCHAR(20)
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
    WHERE usage_stats.tool_id IS NOT NULL -- Only tools used in this batch
    ORDER BY usage_stats.total_used DESC;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_batch_tool_usage_analytics(INTEGER) TO authenticated;

-- =====================================================
-- VERIFICATION QUERIES FOR TESTING
-- =====================================================

-- 1. Verify function deployment
SELECT 
    '✅ FUNCTION_DEPLOYED' as status,
    routine_name,
    'Enhanced calculation ready' as message
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'get_batch_tool_usage_analytics';

-- 2. Test calculation components for Batch ID 13
SELECT 
    '🧮 CALCULATION_TEST_BATCH_13' as test_type,
    pb.id as batch_id,
    pb.product_id,
    pb.units_produced as current_production,
    p.quantity as total_product_quantity,
    GREATEST(p.quantity - pb.units_produced, 0) as remaining_production,
    CASE 
        WHEN p.quantity IS NULL THEN '❌ Product not found in products table'
        WHEN pb.units_produced IS NULL THEN '❌ Batch not found'
        WHEN (p.quantity - pb.units_produced) < 0 THEN '⚠️ Over-production detected'
        ELSE '✅ Ready for calculation'
    END as status
FROM production_batches pb
LEFT JOIN products p ON pb.product_id::TEXT = p.id
WHERE pb.id = 13;

-- 3. Test calculation components for Product ID 185
SELECT 
    '🧮 CALCULATION_TEST_PRODUCT_185' as test_type,
    pb.id as batch_id,
    pb.product_id,
    pb.units_produced as current_production,
    p.quantity as total_product_quantity,
    GREATEST(p.quantity - pb.units_produced, 0) as remaining_production,
    'Formula: ' || GREATEST(p.quantity - pb.units_produced, 0) || ' × tools_per_unit = remaining_stock' as formula
FROM production_batches pb
LEFT JOIN products p ON pb.product_id::TEXT = p.id
WHERE pb.product_id = 185
LIMIT 1;

-- 4. Test the enhanced function with actual data
-- Uncomment to test with your data:
-- SELECT 
--     '🔧 ENHANCED_FUNCTION_TEST' as test_type,
--     tool_name,
--     quantity_used_per_unit,
--     remaining_stock,
--     stock_status
-- FROM get_batch_tool_usage_analytics(13) 
-- LIMIT 5;

-- Success message
SELECT 
    '🎉 DEPLOYMENT_COMPLETE' as status,
    'Enhanced remaining stock calculation deployed' as message,
    'Test in Production Batch Details Screen' as next_step,
    'Target: Used Manufacturing Tools Section' as target_section;
