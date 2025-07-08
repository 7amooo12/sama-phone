-- =====================================================
-- SmartBizTracker: Debug Remaining Stock Calculation
-- =====================================================
-- This script helps debug why remaining stock is showing 0
-- by providing detailed diagnostic information
-- =====================================================

-- Create a comprehensive diagnostic function
CREATE OR REPLACE FUNCTION debug_remaining_stock_calculation(
    p_batch_id INTEGER
)
RETURNS TABLE (
    debug_step TEXT,
    step_result TEXT,
    details TEXT,
    recommendation TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_units_produced DECIMAL(10,2);
    v_product_id INTEGER;
    v_total_product_quantity DECIMAL(10,2);
    v_remaining_production DECIMAL(10,2);
    v_batch_exists BOOLEAN := FALSE;
    v_product_exists BOOLEAN := FALSE;
    v_tools_used_count INTEGER := 0;
    v_total_tools_used DECIMAL(10,2) := 0;
BEGIN
    -- Step 1: Check if batch exists
    SELECT 
        COALESCE(pb.units_produced, 0),
        pb.product_id,
        TRUE
    INTO v_units_produced, v_product_id, v_batch_exists
    FROM production_batches pb
    WHERE pb.id = p_batch_id;
    
    RETURN QUERY
    SELECT 
        'Step 1: Batch Validation'::TEXT,
        CASE WHEN v_batch_exists THEN '✅ FOUND' ELSE '❌ NOT FOUND' END::TEXT,
        ('Batch ID: ' || p_batch_id || ', Product ID: ' || COALESCE(v_product_id::TEXT, 'NULL') || ', Units Produced: ' || COALESCE(v_units_produced::TEXT, 'NULL'))::TEXT,
        CASE WHEN NOT v_batch_exists THEN 'Create production batch with ID ' || p_batch_id ELSE 'Batch data is valid' END::TEXT;
    
    IF NOT v_batch_exists THEN
        RETURN;
    END IF;
    
    -- Step 2: Check if product exists
    SELECT COALESCE(p.quantity, 0), TRUE
    INTO v_total_product_quantity, v_product_exists
    FROM products p
    WHERE p.id = v_product_id::TEXT;
    
    RETURN QUERY
    SELECT 
        'Step 2: Product Validation'::TEXT,
        CASE WHEN v_product_exists THEN '✅ FOUND' ELSE '❌ NOT FOUND' END::TEXT,
        ('Product ID: ' || v_product_id || ', Total Quantity: ' || COALESCE(v_total_product_quantity::TEXT, 'NULL'))::TEXT,
        CASE WHEN NOT v_product_exists THEN 'Add product with ID ' || v_product_id || ' to products table' ELSE 'Product data is valid' END::TEXT;
    
    -- Step 3: Calculate remaining production
    v_remaining_production := GREATEST(COALESCE(v_total_product_quantity, 0) - COALESCE(v_units_produced, 0), 0);
    
    RETURN QUERY
    SELECT 
        'Step 3: Remaining Production Calculation'::TEXT,
        CASE WHEN v_remaining_production > 0 THEN '✅ POSITIVE' ELSE '⚠️ ZERO/NEGATIVE' END::TEXT,
        ('Formula: ' || COALESCE(v_total_product_quantity::TEXT, '0') || ' - ' || COALESCE(v_units_produced::TEXT, '0') || ' = ' || v_remaining_production::TEXT)::TEXT,
        CASE 
            WHEN v_remaining_production = 0 THEN 'Production is complete - remaining stock should be 0'
            WHEN v_remaining_production > 0 THEN 'Remaining production is positive - good for calculation'
            ELSE 'Check product quantity and units produced values'
        END::TEXT;
    
    -- Step 4: Check tool usage history
    SELECT 
        COUNT(*),
        COALESCE(SUM(tuh.quantity_used), 0)
    INTO v_tools_used_count, v_total_tools_used
    FROM tool_usage_history tuh
    WHERE tuh.batch_id = p_batch_id;
    
    RETURN QUERY
    SELECT 
        'Step 4: Tool Usage History'::TEXT,
        CASE WHEN v_tools_used_count > 0 THEN '✅ FOUND' ELSE '❌ NO USAGE' END::TEXT,
        ('Tools Used Count: ' || v_tools_used_count || ', Total Quantity Used: ' || v_total_tools_used)::TEXT,
        CASE 
            WHEN v_tools_used_count = 0 THEN 'No tools have been used in this batch - remaining stock will be 0'
            ELSE 'Tool usage data exists - calculation should work'
        END::TEXT;
    
    -- Step 5: Test the actual calculation
    IF v_tools_used_count > 0 AND v_remaining_production > 0 THEN
        DECLARE
            v_tools_per_unit DECIMAL(10,2);
            v_calculated_remaining DECIMAL(10,2);
        BEGIN
            -- Calculate tools used per unit
            v_tools_per_unit := v_total_tools_used / GREATEST(v_units_produced, 1);
            
            -- Calculate remaining stock
            v_calculated_remaining := v_remaining_production * v_tools_per_unit;
            
            RETURN QUERY
            SELECT 
                'Step 5: Calculation Test'::TEXT,
                CASE WHEN v_calculated_remaining > 0 THEN '✅ POSITIVE RESULT' ELSE '⚠️ ZERO RESULT' END::TEXT,
                ('Tools Per Unit: ' || v_tools_per_unit || ', Remaining Stock: ' || v_calculated_remaining || ' (Formula: ' || v_remaining_production || ' × ' || v_tools_per_unit || ')')::TEXT,
                CASE 
                    WHEN v_calculated_remaining > 0 THEN 'Calculation is working correctly'
                    ELSE 'Check why calculation results in zero'
                END::TEXT;
        END;
    ELSE
        RETURN QUERY
        SELECT 
            'Step 5: Calculation Test'::TEXT,
            '⚠️ SKIPPED'::TEXT,
            'Cannot calculate - missing tool usage or remaining production is zero'::TEXT,
            'Ensure tools are used in production and remaining production > 0'::TEXT;
    END IF;
    
    -- Step 6: Check current function result
    DECLARE
        v_function_result_count INTEGER := 0;
    BEGIN
        SELECT COUNT(*)
        INTO v_function_result_count
        FROM get_batch_tool_usage_analytics(p_batch_id);
        
        RETURN QUERY
        SELECT 
            'Step 6: Function Result Check'::TEXT,
            CASE WHEN v_function_result_count > 0 THEN '✅ RETURNS DATA' ELSE '❌ NO DATA' END::TEXT,
            ('Function returns ' || v_function_result_count || ' rows')::TEXT,
            CASE 
                WHEN v_function_result_count = 0 THEN 'Function returns no data - check WHERE clause and JOIN conditions'
                ELSE 'Function is returning data - check individual remaining_stock values'
            END::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY
            SELECT 
                'Step 6: Function Result Check'::TEXT,
                '❌ ERROR'::TEXT,
                ('Function error: ' || SQLERRM)::TEXT,
                'Fix function implementation errors'::TEXT;
    END;
END;
$$;

-- Create a detailed data inspection function
CREATE OR REPLACE FUNCTION inspect_batch_data(
    p_batch_id INTEGER
)
RETURNS TABLE (
    data_type TEXT,
    field_name TEXT,
    field_value TEXT,
    notes TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_batch_record RECORD;
    v_product_record RECORD;
BEGIN
    -- Get batch data
    SELECT * INTO v_batch_record
    FROM production_batches pb
    WHERE pb.id = p_batch_id;
    
    IF FOUND THEN
        RETURN QUERY
        SELECT 
            'Batch Data'::TEXT,
            'id'::TEXT,
            v_batch_record.id::TEXT,
            'Production batch identifier'::TEXT;
            
        RETURN QUERY
        SELECT 
            'Batch Data'::TEXT,
            'product_id'::TEXT,
            v_batch_record.product_id::TEXT,
            'Product being produced'::TEXT;
            
        RETURN QUERY
        SELECT 
            'Batch Data'::TEXT,
            'units_produced'::TEXT,
            COALESCE(v_batch_record.units_produced::TEXT, 'NULL'),
            'Current production count'::TEXT;
        
        -- Get product data
        SELECT * INTO v_product_record
        FROM products p
        WHERE p.id = v_batch_record.product_id::TEXT;
        
        IF FOUND THEN
            RETURN QUERY
            SELECT 
                'Product Data'::TEXT,
                'id'::TEXT,
                v_product_record.id::TEXT,
                'Product identifier'::TEXT;
                
            RETURN QUERY
            SELECT 
                'Product Data'::TEXT,
                'quantity'::TEXT,
                COALESCE(v_product_record.quantity::TEXT, 'NULL'),
                'Total product quantity target'::TEXT;
                
            RETURN QUERY
            SELECT 
                'Product Data'::TEXT,
                'name'::TEXT,
                COALESCE(v_product_record.name, 'NULL'),
                'Product name'::TEXT;
        ELSE
            RETURN QUERY
            SELECT 
                'Product Data'::TEXT,
                'ERROR'::TEXT,
                'Product not found'::TEXT,
                ('No product found with ID: ' || v_batch_record.product_id)::TEXT;
        END IF;
        
        -- Get tool usage data
        FOR v_batch_record IN 
            SELECT 
                tuh.tool_id,
                mt.name as tool_name,
                tuh.quantity_used,
                tuh.usage_date
            FROM tool_usage_history tuh
            LEFT JOIN manufacturing_tools mt ON tuh.tool_id = mt.id
            WHERE tuh.batch_id = p_batch_id
            ORDER BY tuh.usage_date DESC
        LOOP
            RETURN QUERY
            SELECT 
                'Tool Usage'::TEXT,
                ('Tool ' || v_batch_record.tool_id || ' (' || COALESCE(v_batch_record.tool_name, 'Unknown') || ')')::TEXT,
                ('Used: ' || v_batch_record.quantity_used || ' on ' || v_batch_record.usage_date)::TEXT,
                'Tool usage in this batch'::TEXT;
        END LOOP;
    ELSE
        RETURN QUERY
        SELECT 
            'Batch Data'::TEXT,
            'ERROR'::TEXT,
            'Batch not found'::TEXT,
            ('No batch found with ID: ' || p_batch_id)::TEXT;
    END IF;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION debug_remaining_stock_calculation(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION inspect_batch_data(INTEGER) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION debug_remaining_stock_calculation(INTEGER) IS 'Debug why remaining stock calculation returns 0 - provides step-by-step analysis';
COMMENT ON FUNCTION inspect_batch_data(INTEGER) IS 'Inspect all data related to a production batch for debugging purposes';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '🔍 DEBUG FUNCTIONS CREATED';
    RAISE NOTICE '📊 Use: SELECT * FROM debug_remaining_stock_calculation(20);';
    RAISE NOTICE '🔎 Use: SELECT * FROM inspect_batch_data(20);';
    RAISE NOTICE '🧪 Test with your batch ID to identify the issue';
END $$;
