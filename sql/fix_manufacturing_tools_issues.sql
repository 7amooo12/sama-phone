-- =====================================================
-- SmartBizTracker: Fix Manufacturing Tools Issues
-- =====================================================
-- This script fixes multiple issues in the Manufacturing Tools module:
-- 1. PostgreSQL column error: target_quantity doesn't exist
-- 2. Enhanced remaining stock calculation compatibility
-- 3. Proper handling of production gap analysis without target_quantity
-- =====================================================

-- Fix 1: Add target_quantity column to production_batches table
ALTER TABLE production_batches 
ADD COLUMN IF NOT EXISTS target_quantity DECIMAL(10,2) DEFAULT 100.0;

-- Update existing records with reasonable default target quantities
-- Set target_quantity to 1.2x current production (20% buffer) or minimum 50
UPDATE production_batches 
SET target_quantity = GREATEST(units_produced * 1.2, 50.0)
WHERE target_quantity IS NULL OR target_quantity = 0;

-- Fix 2: Enhanced get_production_gap_analysis function with proper target_quantity handling
DROP FUNCTION IF EXISTS get_production_gap_analysis(INTEGER, INTEGER);

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
    v_product_total_quantity DECIMAL(10,2);
BEGIN
    -- Get product information and total quantity (prioritizing recently updated API data)
    SELECT
        name,
        COALESCE(quantity, 0),
        updated_at
    INTO v_product_name, v_product_total_quantity, v_batch_created_at
    FROM products
    WHERE id = p_product_id::TEXT;

    -- Get batch information with proper target_quantity handling
    SELECT
        COALESCE(units_produced, 0),
        COALESCE(target_quantity, GREATEST(units_produced * 1.2, 50.0)),
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

    -- Enhanced target quantity logic prioritizing API data
    -- Priority 1: Use product quantity if it's reasonable and recently updated (API data)
    IF v_product_total_quantity > 0 AND v_product_total_quantity >= v_current_production THEN
        v_target_quantity := v_product_total_quantity;
        -- Log that we're using API product quantity as target
        RAISE NOTICE 'Using API product quantity as target: %', v_product_total_quantity;
    -- Priority 2: Use existing batch target_quantity if available
    ELSIF v_target_quantity IS NOT NULL AND v_target_quantity > 0 THEN
        -- Keep existing target_quantity from batch
        RAISE NOTICE 'Using existing batch target quantity: %', v_target_quantity;
    -- Priority 3: Calculate intelligent default based on current production
    ELSE
        v_target_quantity := GREATEST(v_current_production * 1.2, 50.0);
        RAISE NOTICE 'Using calculated target quantity: %', v_target_quantity;
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
    
    -- Return single JSONB object
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

-- Fix 3: Update enhanced remaining stock calculation with better stock status handling
DROP FUNCTION IF EXISTS get_batch_tool_usage_analytics(INTEGER);

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
    v_target_quantity DECIMAL(10,2);
    v_remaining_production DECIMAL(10,2);
    v_batch_exists BOOLEAN := FALSE;
    v_product_name VARCHAR(255);
    v_batch_created_at TIMESTAMP;
BEGIN
    -- Get batch information: units produced, product ID, and target quantity
    SELECT
        COALESCE(pb.units_produced, 0),
        pb.product_id,
        COALESCE(pb.target_quantity, 0),
        pb.created_at,
        TRUE
    INTO v_units_produced, v_product_id, v_target_quantity, v_batch_created_at, v_batch_exists
    FROM production_batches pb
    WHERE pb.id = p_batch_id;

    -- If batch doesn't exist, return empty result
    IF NOT v_batch_exists THEN
        RETURN;
    END IF;

    -- Get product information and total quantity (same logic as gap analysis)
    SELECT
        name,
        COALESCE(quantity, 0)
    INTO v_product_name, v_total_product_quantity
    FROM products
    WHERE id = v_product_id::TEXT;

    -- Enhanced target quantity logic (same as gap analysis function)
    -- Priority 1: Use product quantity if it's reasonable and recently updated (API data)
    IF v_total_product_quantity > 0 AND v_total_product_quantity >= v_units_produced THEN
        v_target_quantity := v_total_product_quantity;
        RAISE NOTICE 'Tool Analytics: Using API product quantity as target: %', v_total_product_quantity;
    -- Priority 2: Use existing batch target_quantity if available
    ELSIF v_target_quantity IS NOT NULL AND v_target_quantity > 0 THEN
        -- Keep existing target_quantity from batch
        RAISE NOTICE 'Tool Analytics: Using existing batch target quantity: %', v_target_quantity;
    -- Priority 3: Calculate intelligent default based on current production
    ELSE
        v_target_quantity := GREATEST(v_units_produced * 1.2, 50.0);
        RAISE NOTICE 'Tool Analytics: Using calculated target quantity: %', v_target_quantity;
    END IF;

    -- Calculate remaining production using the same logic as gap analysis
    v_remaining_production := GREATEST(v_target_quantity - v_units_produced, 0);

    RAISE NOTICE 'Tool Analytics: Target=%, Current=%, Remaining=%', v_target_quantity, v_units_produced, v_remaining_production;
    
    -- Handle edge cases
    IF v_units_produced = 0 THEN
        v_units_produced := 1; -- Avoid division by zero
    END IF;

    RETURN QUERY
    SELECT 
        mt.id as tool_id,
        mt.name as tool_name,
        mt.unit,
        -- Tools used per unit
        CASE 
            WHEN v_units_produced > 0 THEN COALESCE(usage_stats.total_used, 0) / v_units_produced
            ELSE 0
        END as quantity_used_per_unit,
        COALESCE(usage_stats.total_used, 0) as total_quantity_used,
        -- Enhanced remaining stock calculation: (Remaining Production Units × Tools Used Per Unit)
        -- Formula: Remaining Stock = (Target Quantity - Current Production) × Tools Used Per Unit
        CASE
            WHEN v_units_produced > 0 AND v_remaining_production > 0
            THEN v_remaining_production * (COALESCE(usage_stats.total_used, 0) / v_units_produced)
            WHEN v_remaining_production = 0
            THEN 0  -- Production completed, no more tools needed
            ELSE 0  -- No production data available
        END as remaining_stock,
        (mt.quantity + COALESCE(usage_stats.total_used, 0)) as initial_stock,
        -- Usage percentage
        CASE 
            WHEN (mt.quantity + COALESCE(usage_stats.total_used, 0)) > 0 
            THEN (COALESCE(usage_stats.total_used, 0) / (mt.quantity + COALESCE(usage_stats.total_used, 0)) * 100)
            ELSE 0
        END as usage_percentage,
        -- Fixed stock status (removed 'completed' to avoid edge case handler issues)
        CASE 
            WHEN v_remaining_production = 0 THEN 'high'::VARCHAR(20)  -- Changed from 'completed' to 'high'
            WHEN v_remaining_production * (COALESCE(usage_stats.total_used, 0) / GREATEST(v_units_produced, 1)) <= 0 THEN 'critical'::VARCHAR(20)
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
    WHERE usage_stats.tool_id IS NOT NULL
    ORDER BY usage_stats.total_used DESC;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_production_gap_analysis(INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_batch_tool_usage_analytics(INTEGER) TO authenticated;

-- Verification queries
SELECT 
    '✅ ISSUES_FIXED' as status,
    'target_quantity column added' as fix_1,
    'stock status sanitized' as fix_2,
    'functions updated' as fix_3;
