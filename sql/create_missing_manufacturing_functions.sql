-- =====================================================
-- SmartBizTracker: Missing Manufacturing Tools Functions
-- =====================================================
-- This script creates the missing PostgreSQL functions for the
-- Manufacturing Tools Tracking module:
-- 1. get_batch_tool_usage_analytics
-- 2. get_production_gap_analysis
-- =====================================================

-- Function 1: Get batch tool usage analytics
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
BEGIN
    -- Get units produced for this batch
    SELECT COALESCE(units_produced, 0) INTO v_units_produced
    FROM production_batches 
    WHERE id = p_batch_id;
    
    -- If no units produced, set to 1 to avoid division by zero
    IF v_units_produced = 0 THEN
        v_units_produced := 1;
    END IF;

    RETURN QUERY
    SELECT 
        mt.id as tool_id,
        mt.name as tool_name,
        mt.unit,
        CASE 
            WHEN v_units_produced > 0 THEN COALESCE(usage_stats.total_used, 0) / v_units_produced
            ELSE 0
        END as quantity_used_per_unit,
        COALESCE(usage_stats.total_used, 0) as total_quantity_used,
        mt.quantity as remaining_stock,
        (mt.quantity + COALESCE(usage_stats.total_used, 0)) as initial_stock,
        CASE 
            WHEN (mt.quantity + COALESCE(usage_stats.total_used, 0)) > 0 
            THEN (COALESCE(usage_stats.total_used, 0) / (mt.quantity + COALESCE(usage_stats.total_used, 0)) * 100)
            ELSE 0
        END as usage_percentage,
        CASE
            WHEN mt.quantity <= 0 THEN 'out_of_stock'::VARCHAR(20)
            WHEN mt.quantity <= 5 THEN 'low'::VARCHAR(20)
            WHEN mt.quantity <= 20 THEN 'medium'::VARCHAR(20)
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

-- Function 2: Get production gap analysis
CREATE OR REPLACE FUNCTION get_production_gap_analysis(
    p_product_id INTEGER,
    p_batch_id INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_product_name VARCHAR(255);
    v_current_production DECIMAL(10,2);
    v_target_quantity DECIMAL(10,2);
    v_remaining_pieces DECIMAL(10,2);
    v_completion_percentage DECIMAL(5,2);
    v_is_over_produced BOOLEAN;
    v_is_completed BOOLEAN;
    v_estimated_completion_date TIMESTAMP;
    v_batch_created_at TIMESTAMP;
    v_days_elapsed INTEGER;
    v_daily_production_rate DECIMAL(10,2);
BEGIN
    -- Get product information
    SELECT name INTO v_product_name
    FROM products 
    WHERE id = p_product_id::TEXT;
    
    -- Get batch information
    SELECT 
        COALESCE(units_produced, 0),
        COALESCE(target_quantity, 0),
        created_at
    INTO v_current_production, v_target_quantity, v_batch_created_at
    FROM production_batches 
    WHERE id = p_batch_id;
    
    -- Handle case where no data found
    IF v_product_name IS NULL THEN
        v_product_name := 'منتج غير محدد';
    END IF;
    
    IF v_current_production IS NULL THEN
        v_current_production := 0;
    END IF;
    
    IF v_target_quantity IS NULL THEN
        v_target_quantity := 0;
    END IF;
    
    -- Calculate remaining pieces
    v_remaining_pieces := v_target_quantity - v_current_production;
    
    -- Calculate completion percentage
    IF v_target_quantity > 0 THEN
        v_completion_percentage := (v_current_production / v_target_quantity) * 100;
    ELSE
        v_completion_percentage := 0;
    END IF;
    
    -- Determine if over-produced or completed
    v_is_over_produced := v_current_production > v_target_quantity;
    v_is_completed := v_current_production >= v_target_quantity;
    
    -- Calculate estimated completion date
    v_days_elapsed := EXTRACT(DAY FROM NOW() - v_batch_created_at);
    IF v_days_elapsed > 0 AND v_current_production > 0 AND v_remaining_pieces > 0 THEN
        v_daily_production_rate := v_current_production / v_days_elapsed;
        IF v_daily_production_rate > 0 THEN
            v_estimated_completion_date := NOW() + (v_remaining_pieces / v_daily_production_rate) * INTERVAL '1 day';
        END IF;
    END IF;
    
    RETURN jsonb_build_object(
        'product_id', p_product_id,
        'product_name', v_product_name,
        'current_production', v_current_production,
        'target_quantity', v_target_quantity,
        'remaining_pieces', v_remaining_pieces,
        'completion_percentage', v_completion_percentage,
        'is_over_produced', v_is_over_produced,
        'is_completed', v_is_completed,
        'estimated_completion_date', v_estimated_completion_date
    );
END;
$$;

-- Grant permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_batch_tool_usage_analytics(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_production_gap_analysis(INTEGER, INTEGER) TO authenticated;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- 1. Check if functions were created successfully
SELECT
    'DEPLOYMENT_STATUS' as check_type,
    routine_name,
    routine_type,
    'CREATED_SUCCESSFULLY' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('get_batch_tool_usage_analytics', 'get_production_gap_analysis')
ORDER BY routine_name;

-- 2. Show function signatures
SELECT
    'FUNCTION_SIGNATURES' as check_type,
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname IN ('get_batch_tool_usage_analytics', 'get_production_gap_analysis')
ORDER BY p.proname;

-- 3. Check required tables exist
SELECT
    'TABLE_DEPENDENCIES' as check_type,
    table_name,
    CASE
        WHEN table_name IN ('manufacturing_tools', 'tool_usage_history', 'production_batches', 'products')
        THEN 'REQUIRED_TABLE_EXISTS'
        ELSE 'OPTIONAL_TABLE'
    END as status
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('manufacturing_tools', 'tool_usage_history', 'production_batches', 'products')
ORDER BY table_name;

-- 4. Test functions with sample data (uncomment if you have test data)
-- SELECT 'TESTING_ANALYTICS_FUNCTION' as test_type, * FROM get_batch_tool_usage_analytics(13) LIMIT 3;
-- SELECT 'TESTING_GAP_ANALYSIS_FUNCTION' as test_type, * FROM get_production_gap_analysis(4, 13);

-- Final success message
SELECT
    '🎉 DEPLOYMENT COMPLETE' as status,
    'Manufacturing Tools functions are ready!' as message,
    'Next: Test in Flutter app' as next_step;
