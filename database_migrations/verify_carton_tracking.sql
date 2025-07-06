-- =====================================================
-- Carton Tracking Migration Verification Script
-- =====================================================
-- This script verifies that the carton tracking migration was applied successfully
-- Date: 2025-06-15
-- Compatible with: PostgreSQL/Supabase

-- =====================================================
-- 1. VERIFY NEW COLUMN EXISTS
-- =====================================================

SELECT 
    'Column Verification' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'warehouse_inventory' 
            AND column_name = 'quantity_per_carton'
        ) THEN '✅ PASS: quantity_per_carton column exists'
        ELSE '❌ FAIL: quantity_per_carton column missing'
    END as status;

-- Get detailed column information
SELECT 
    'Column Details' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'warehouse_inventory' 
AND column_name = 'quantity_per_carton';

-- =====================================================
-- 2. CHECK CONSTRAINTS
-- =====================================================

SELECT 
    'Constraint Verification' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.table_constraints tc
            JOIN information_schema.constraint_column_usage ccu 
                ON tc.constraint_name = ccu.constraint_name
            WHERE tc.table_name = 'warehouse_inventory'
            AND tc.constraint_type = 'CHECK'
            AND tc.constraint_name = 'chk_quantity_per_carton_positive'
        ) THEN '✅ PASS: Check constraint exists'
        ELSE '❌ FAIL: Check constraint missing'
    END as status;

-- Get constraint details
SELECT 
    'Constraint Details' as check_type,
    tc.constraint_name,
    tc.constraint_type,
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc 
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name = 'warehouse_inventory'
AND tc.constraint_name = 'chk_quantity_per_carton_positive';

-- =====================================================
-- 3. VERIFY INDEXES
-- =====================================================

SELECT 
    'Index Verification' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE tablename = 'warehouse_inventory' 
            AND indexname = 'idx_warehouse_inventory_quantity_per_carton'
        ) THEN '✅ PASS: quantity_per_carton index exists'
        ELSE '❌ FAIL: quantity_per_carton index missing'
    END as status
UNION ALL
SELECT 
    'Index Verification' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE tablename = 'warehouse_inventory' 
            AND indexname = 'idx_warehouse_inventory_carton_calc'
        ) THEN '✅ PASS: carton calculation index exists'
        ELSE '❌ FAIL: carton calculation index missing'
    END as status;

-- Get detailed index information
SELECT 
    'Index Details' as check_type,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'warehouse_inventory' 
AND indexname LIKE '%carton%'
ORDER BY indexname;

-- =====================================================
-- 4. VALIDATE FUNCTION
-- =====================================================

SELECT 
    'Function Verification' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE p.proname = 'calculate_cartons'
            AND n.nspname = 'public'
        ) THEN '✅ PASS: calculate_cartons function exists'
        ELSE '❌ FAIL: calculate_cartons function missing'
    END as status;

-- Get function details
SELECT 
    'Function Details' as check_type,
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type,
    p.provolatile as volatility
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'calculate_cartons'
AND n.nspname = 'public';

-- =====================================================
-- 5. TEST FUNCTION FUNCTIONALITY
-- =====================================================

SELECT 
    'Function Test' as check_type,
    'Test Case' as test_name,
    quantity,
    quantity_per_carton,
    calculate_cartons(quantity, quantity_per_carton) as calculated_cartons,
    CEIL(quantity::DECIMAL / quantity_per_carton::DECIMAL) as expected_cartons,
    CASE 
        WHEN calculate_cartons(quantity, quantity_per_carton) = CEIL(quantity::DECIMAL / quantity_per_carton::DECIMAL)
        THEN '✅ PASS'
        ELSE '❌ FAIL'
    END as test_result
FROM (
    VALUES 
        (9, 2),   -- Should return 5 cartons
        (10, 3),  -- Should return 4 cartons  
        (8, 4),   -- Should return 2 cartons
        (0, 1),   -- Should return 0 cartons
        (15, 1)   -- Should return 15 cartons
) AS test_data(quantity, quantity_per_carton);

-- =====================================================
-- 6. CHECK VIEW EXISTS
-- =====================================================

SELECT 
    'View Verification' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.views 
            WHERE table_name = 'warehouse_carton_stats'
        ) THEN '✅ PASS: warehouse_carton_stats view exists'
        ELSE '❌ FAIL: warehouse_carton_stats view missing'
    END as status;

-- Get view definition
SELECT 
    'View Details' as check_type,
    table_name,
    view_definition
FROM information_schema.views 
WHERE table_name = 'warehouse_carton_stats';

-- =====================================================
-- 7. TEST VIEW FUNCTIONALITY
-- =====================================================

-- Test if view returns data (limit to 3 rows for verification)
SELECT 
    'View Test' as check_type,
    warehouse_id,
    warehouse_name,
    total_products,
    total_quantity,
    total_cartons,
    avg_quantity_per_carton
FROM warehouse_carton_stats 
LIMIT 3;

-- =====================================================
-- 8. SAMPLE DATA VERIFICATION
-- =====================================================

-- Check sample records from warehouse_inventory
SELECT 
    'Sample Data' as check_type,
    id,
    warehouse_id,
    product_id,
    quantity,
    quantity_per_carton,
    CASE 
        WHEN quantity_per_carton > 0 
        THEN calculate_cartons(quantity, quantity_per_carton)
        ELSE 0
    END as calculated_cartons
FROM warehouse_inventory 
WHERE quantity_per_carton IS NOT NULL
LIMIT 5;

-- Check data distribution
SELECT 
    'Data Distribution' as check_type,
    quantity_per_carton,
    COUNT(*) as record_count,
    ROUND(AVG(quantity), 2) as avg_quantity,
    SUM(calculate_cartons(quantity, quantity_per_carton)) as total_cartons
FROM warehouse_inventory 
WHERE quantity_per_carton IS NOT NULL
GROUP BY quantity_per_carton
ORDER BY quantity_per_carton;

-- =====================================================
-- 9. PERMISSIONS VERIFICATION
-- =====================================================

-- Check function permissions
SELECT 
    'Permission Check' as check_type,
    'calculate_cartons function' as object_name,
    CASE 
        WHEN has_function_privilege('authenticated', 'calculate_cartons(integer, integer)', 'EXECUTE')
        THEN '✅ PASS: authenticated role has EXECUTE permission'
        ELSE '❌ FAIL: authenticated role missing EXECUTE permission'
    END as status;

-- Check view permissions  
SELECT 
    'Permission Check' as check_type,
    'warehouse_carton_stats view' as object_name,
    CASE 
        WHEN has_table_privilege('authenticated', 'warehouse_carton_stats', 'SELECT')
        THEN '✅ PASS: authenticated role has SELECT permission'
        ELSE '❌ FAIL: authenticated role missing SELECT permission'
    END as status;

-- =====================================================
-- 10. OVERALL MIGRATION STATUS
-- =====================================================

SELECT 
    'MIGRATION SUMMARY' as check_type,
    CASE 
        WHEN (
            -- Column exists
            EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouse_inventory' AND column_name = 'quantity_per_carton')
            AND
            -- Constraint exists
            EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name = 'warehouse_inventory' AND constraint_name = 'chk_quantity_per_carton_positive')
            AND
            -- Indexes exist
            EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'warehouse_inventory' AND indexname = 'idx_warehouse_inventory_quantity_per_carton')
            AND
            EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'warehouse_inventory' AND indexname = 'idx_warehouse_inventory_carton_calc')
            AND
            -- Function exists
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'calculate_cartons')
            AND
            -- View exists
            EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'warehouse_carton_stats')
        ) THEN '🎉 SUCCESS: All migration components are present and functional!'
        ELSE '⚠️  WARNING: Some migration components may be missing. Check individual results above.'
    END as overall_status;

-- =====================================================
-- 11. TROUBLESHOOTING QUERIES
-- =====================================================

-- Check for any NULL values in quantity_per_carton
SELECT
    'Data Quality Check' as check_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN quantity_per_carton IS NULL THEN 1 END) as null_carton_values,
    COUNT(CASE WHEN quantity_per_carton = 0 THEN 1 END) as zero_carton_values,
    COUNT(CASE WHEN quantity_per_carton < 0 THEN 1 END) as negative_carton_values
FROM warehouse_inventory;

-- Check for constraint violations
SELECT
    'Constraint Violations' as check_type,
    id,
    warehouse_id,
    product_id,
    quantity_per_carton,
    'Invalid carton value' as issue
FROM warehouse_inventory
WHERE quantity_per_carton IS NULL
   OR quantity_per_carton <= 0
LIMIT 5;

-- Check table structure
SELECT
    'Table Structure' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'warehouse_inventory'
ORDER BY ordinal_position;
