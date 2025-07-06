-- =====================================================
-- SmartBizTracker: Enhanced Tool Usage History Function
-- =====================================================
-- This script updates the get_tool_usage_history function to include
-- product information for better display in Manufacturing Tool Details screen
-- 
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Open Supabase SQL Editor
-- 2. Execute this entire script
-- 3. Verify the function works by testing tool usage history display
-- =====================================================

-- Step 1: Drop existing function to allow return type changes
DROP FUNCTION IF EXISTS get_tool_usage_history(INTEGER, INTEGER, INTEGER);

-- Step 2: Create enhanced function with product information
CREATE OR REPLACE FUNCTION get_tool_usage_history(
    p_tool_id INTEGER DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id INTEGER,
    tool_id INTEGER,
    tool_name VARCHAR(100),
    batch_id INTEGER,
    product_id INTEGER,
    product_name VARCHAR(255),
    quantity_used DECIMAL(10,2),
    remaining_stock DECIMAL(10,2),
    usage_date TIMESTAMP,
    warehouse_manager_name VARCHAR(255),
    operation_type VARCHAR(20),
    notes TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        tuh.id,
        tuh.tool_id,
        mt.name as tool_name,
        tuh.batch_id,
        pb.product_id,
        p.name as product_name,
        tuh.quantity_used,
        tuh.remaining_stock,
        tuh.usage_date,
        up.name as warehouse_manager_name,
        tuh.operation_type,
        tuh.notes
    FROM tool_usage_history tuh
    JOIN manufacturing_tools mt ON tuh.tool_id = mt.id
    LEFT JOIN user_profiles up ON tuh.warehouse_manager_id = up.id
    LEFT JOIN production_batches pb ON tuh.batch_id = pb.id
    -- Type casting fix: pb.product_id (INTEGER) to TEXT to match p.id (VARCHAR)
    LEFT JOIN products p ON pb.product_id::TEXT = p.id
    WHERE (p_tool_id IS NULL OR tuh.tool_id = p_tool_id)
    ORDER BY tuh.usage_date DESC
    LIMIT p_limit OFFSET p_offset;
$$;

-- Step 3: Verify data types to confirm the type casting fix
SELECT
    'production_batches.product_id' as column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'production_batches'
  AND column_name = 'product_id'
UNION ALL
SELECT
    'products.id' as column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'products'
  AND column_name = 'id';

-- Step 4: Test the function (optional - uncomment to test)
-- SELECT * FROM get_tool_usage_history(NULL, 5, 0);

-- Step 5: Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_tool_usage_history(INTEGER, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_tool_usage_history(INTEGER, INTEGER, INTEGER) TO service_role;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================
-- Run these queries to verify the deployment was successful:

-- 1. Check if function exists with correct signature
SELECT 
    p.proname as function_name,
    pg_get_function_result(p.oid) as return_type,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
  AND p.proname = 'get_tool_usage_history';

-- 2. Test function execution (will return empty if no data exists)
-- SELECT COUNT(*) as total_usage_records FROM get_tool_usage_history(NULL, 100, 0);

-- =====================================================
-- EXPECTED RESULTS
-- =====================================================
-- After successful deployment:
-- 1. Function should return product_id and product_name columns
-- 2. Manufacturing Tool Details screen should show "إنتاج: [Product Name]" 
--    instead of "دفعة الانتاج رقم X"
-- 3. Usage history should be more descriptive and user-friendly
-- =====================================================
