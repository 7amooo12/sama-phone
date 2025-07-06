-- =====================================================
-- Quick Carton Tracking Verification
-- =====================================================
-- Run this for a fast check of migration status

-- 1. Quick Column Check
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'warehouse_inventory' 
            AND column_name = 'quantity_per_carton'
        ) THEN '✅ Column Added'
        ELSE '❌ Column Missing'
    END as column_status;

-- 2. Quick Function Test
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'calculate_cartons')
        THEN '✅ Function Created'
        ELSE '❌ Function Missing'
    END as function_status;

-- 3. Test Function with Sample Data
SELECT 
    calculate_cartons(10, 3) as test_result,
    CASE 
        WHEN calculate_cartons(10, 3) = 4 
        THEN '✅ Function Working'
        ELSE '❌ Function Error'
    END as function_test;

-- 4. Check Sample Data
SELECT 
    COUNT(*) as total_records,
    COUNT(CASE WHEN quantity_per_carton IS NOT NULL THEN 1 END) as records_with_carton_data,
    AVG(quantity_per_carton) as avg_carton_qty
FROM warehouse_inventory;

-- 5. Quick Index Check
SELECT 
    COUNT(*) as carton_indexes
FROM pg_indexes 
WHERE tablename = 'warehouse_inventory' 
AND indexname LIKE '%carton%';

-- 6. Overall Status
SELECT 
    CASE 
        WHEN (
            EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouse_inventory' AND column_name = 'quantity_per_carton')
            AND EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'calculate_cartons')
            AND calculate_cartons(10, 3) = 4
        ) THEN '🎉 MIGRATION SUCCESSFUL!'
        ELSE '⚠️ MIGRATION INCOMPLETE'
    END as migration_status;
