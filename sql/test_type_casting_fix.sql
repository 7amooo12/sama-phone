-- =====================================================
-- SmartBizTracker: Type Casting Fix Validation
-- =====================================================
-- This script tests the type casting fix for the JOIN between
-- production_batches.product_id (INTEGER) and products.id (TEXT)
-- =====================================================

-- 1. Check data types of the columns involved in the JOIN
SELECT 
    table_name,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE (table_name = 'production_batches' AND column_name = 'product_id')
   OR (table_name = 'products' AND column_name = 'id')
ORDER BY table_name, column_name;

-- 2. Test the type casting directly
SELECT 
    pb.id as batch_id,
    pb.product_id,
    pb.product_id::TEXT as product_id_as_text,
    p.id as product_id_from_products,
    p.name as product_name
FROM production_batches pb
LEFT JOIN products p ON pb.product_id::TEXT = p.id
LIMIT 5;

-- 3. Check if there are any production batches with product_id values
SELECT 
    COUNT(*) as total_batches,
    COUNT(DISTINCT product_id) as unique_product_ids,
    MIN(product_id) as min_product_id,
    MAX(product_id) as max_product_id
FROM production_batches
WHERE product_id IS NOT NULL;

-- 4. Check if there are matching products for the product_ids in production_batches
SELECT 
    pb.product_id,
    pb.product_id::TEXT as product_id_text,
    CASE 
        WHEN p.id IS NOT NULL THEN 'MATCH FOUND'
        ELSE 'NO MATCH'
    END as match_status,
    p.name as product_name
FROM (
    SELECT DISTINCT product_id 
    FROM production_batches 
    WHERE product_id IS NOT NULL
    LIMIT 10
) pb
LEFT JOIN products p ON pb.product_id::TEXT = p.id;

-- 5. Test the enhanced function with the type casting fix
SELECT 
    'Function Test' as test_name,
    COUNT(*) as records_returned
FROM get_tool_usage_history(NULL, 10, 0);

-- 6. Test specific records with product information
SELECT 
    id,
    tool_name,
    batch_id,
    product_id,
    product_name,
    CASE 
        WHEN product_name IS NOT NULL THEN 'HAS PRODUCT NAME'
        WHEN product_id IS NOT NULL THEN 'HAS PRODUCT ID ONLY'
        ELSE 'NO PRODUCT INFO'
    END as product_info_status,
    operation_type,
    quantity_used
FROM get_tool_usage_history(NULL, 20, 0)
WHERE operation_type = 'production'
ORDER BY usage_date DESC;

-- =====================================================
-- EXPECTED RESULTS
-- =====================================================
-- 1. Data types should show:
--    - production_batches.product_id: integer
--    - products.id: character varying (text)
-- 
-- 2. Type casting test should return matching records
-- 
-- 3. Function should execute without errors
-- 
-- 4. Records with operation_type='production' should show product names
--    when available
-- =====================================================

-- =====================================================
-- TROUBLESHOOTING
-- =====================================================
-- If no product names are returned, check:

-- A. Are there any tool usage records linked to production batches?
SELECT 
    COUNT(*) as usage_records_with_batches
FROM tool_usage_history 
WHERE batch_id IS NOT NULL;

-- B. Are there any production batches with valid product_ids?
SELECT 
    COUNT(*) as batches_with_product_ids
FROM production_batches 
WHERE product_id IS NOT NULL;

-- C. Sample of actual data to verify the relationships
SELECT 
    'tool_usage_history' as source_table,
    tuh.id,
    tuh.batch_id,
    tuh.operation_type,
    pb.product_id,
    p.name as product_name
FROM tool_usage_history tuh
LEFT JOIN production_batches pb ON tuh.batch_id = pb.id
LEFT JOIN products p ON pb.product_id::TEXT = p.id
WHERE tuh.operation_type = 'production'
  AND tuh.batch_id IS NOT NULL
LIMIT 5;
