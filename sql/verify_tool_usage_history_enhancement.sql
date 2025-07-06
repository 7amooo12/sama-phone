-- =====================================================
-- SmartBizTracker: Tool Usage History Enhancement Verification
-- =====================================================
-- This script verifies that the enhanced tool usage history function
-- is working correctly and returns product information
-- =====================================================

-- 1. Verify function signature and return type
SELECT 
    p.proname as function_name,
    pg_get_function_result(p.oid) as return_type,
    pg_get_function_arguments(p.oid) as arguments,
    p.prosecdef as is_security_definer
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
  AND p.proname = 'get_tool_usage_history';

-- 2. Check if required tables exist and have data
SELECT 
    'manufacturing_tools' as table_name,
    COUNT(*) as record_count
FROM manufacturing_tools
UNION ALL
SELECT 
    'tool_usage_history' as table_name,
    COUNT(*) as record_count
FROM tool_usage_history
UNION ALL
SELECT 
    'production_batches' as table_name,
    COUNT(*) as record_count
FROM production_batches
UNION ALL
SELECT 
    'products' as table_name,
    COUNT(*) as record_count
FROM products;

-- 3. Test function execution with sample data
SELECT 
    id,
    tool_name,
    batch_id,
    product_id,
    product_name,
    quantity_used,
    operation_type,
    usage_date
FROM get_tool_usage_history(NULL, 10, 0)
ORDER BY usage_date DESC;

-- 4. Check for any usage history records with product information
SELECT 
    tuh.id,
    mt.name as tool_name,
    tuh.batch_id,
    pb.product_id,
    p.name as product_name,
    tuh.operation_type,
    tuh.usage_date
FROM tool_usage_history tuh
JOIN manufacturing_tools mt ON tuh.tool_id = mt.id
LEFT JOIN production_batches pb ON tuh.batch_id = pb.id
LEFT JOIN products p ON pb.product_id = p.id
WHERE tuh.operation_type = 'production'
ORDER BY tuh.usage_date DESC
LIMIT 5;

-- 5. Verify permissions are set correctly
SELECT 
    p.proname,
    r.rolname,
    a.privilege_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
JOIN information_schema.routine_privileges a ON a.routine_name = p.proname
JOIN pg_roles r ON r.rolname = a.grantee
WHERE n.nspname = 'public' 
  AND p.proname = 'get_tool_usage_history'
  AND r.rolname IN ('authenticated', 'service_role');

-- =====================================================
-- EXPECTED RESULTS CHECKLIST
-- =====================================================
-- ✅ Function exists with correct signature including product_id and product_name
-- ✅ Function has SECURITY DEFINER privilege
-- ✅ Function returns data with product information when available
-- ✅ Permissions are granted to authenticated and service_role
-- ✅ Tool usage history shows actual product names for production operations
-- =====================================================

-- =====================================================
-- TROUBLESHOOTING QUERIES
-- =====================================================
-- If issues are found, run these queries for debugging:

-- Check if there are any production batches linked to tool usage
SELECT 
    COUNT(*) as linked_batches,
    COUNT(DISTINCT tuh.tool_id) as tools_with_usage,
    COUNT(DISTINCT pb.product_id) as products_in_batches
FROM tool_usage_history tuh
LEFT JOIN production_batches pb ON tuh.batch_id = pb.id
WHERE tuh.operation_type = 'production';

-- Check for orphaned tool usage records (batch_id exists but no matching production_batch)
SELECT 
    tuh.id,
    tuh.batch_id,
    tuh.tool_id,
    tuh.operation_type
FROM tool_usage_history tuh
LEFT JOIN production_batches pb ON tuh.batch_id = pb.id
WHERE tuh.batch_id IS NOT NULL 
  AND pb.id IS NULL;

-- Check for production batches without product information
SELECT 
    pb.id,
    pb.product_id,
    p.name as product_name
FROM production_batches pb
LEFT JOIN products p ON pb.product_id = p.id
WHERE p.id IS NULL
LIMIT 5;
