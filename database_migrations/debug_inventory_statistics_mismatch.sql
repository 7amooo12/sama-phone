-- ============================================================================
-- DEBUG INVENTORY STATISTICS MISMATCH
-- ============================================================================
-- تشخيص عدم تطابق إحصائيات المخزون مع بيانات المخزون الفعلية
-- Debug why warehouse statistics show products exist but inventory loading returns 0 items
-- ============================================================================

-- Step 1: Check warehouse inventory data directly
DO $$
DECLARE
    warehouse_record RECORD;
    inventory_count INTEGER;
    total_quantity INTEGER;
    function_result_count INTEGER;
BEGIN
    RAISE NOTICE '🔍 Checking warehouse inventory data consistency...';
    
    -- Loop through all warehouses
    FOR warehouse_record IN
        SELECT id, name FROM warehouses WHERE is_active = true ORDER BY name
    LOOP
        RAISE NOTICE '';
        RAISE NOTICE '🏭 Checking warehouse: % (ID: %)', warehouse_record.name, warehouse_record.id;
        
        -- Check direct warehouse_inventory table
        SELECT COUNT(*), COALESCE(SUM(quantity), 0)
        INTO inventory_count, total_quantity
        FROM warehouse_inventory
        WHERE warehouse_id = warehouse_record.id;
        
        RAISE NOTICE '📊 Direct table query:';
        RAISE NOTICE '  - Inventory items: %', inventory_count;
        RAISE NOTICE '  - Total quantity: %', total_quantity;
        
        -- Check get_warehouse_inventory_with_products function
        BEGIN
            SELECT COUNT(*)
            INTO function_result_count
            FROM get_warehouse_inventory_with_products(warehouse_record.id);
            
            RAISE NOTICE '🔧 Function query:';
            RAISE NOTICE '  - Function result count: %', function_result_count;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '❌ Function failed: %', SQLERRM;
                function_result_count := -1;
        END;
        
        -- Check for data consistency issues
        IF inventory_count > 0 AND function_result_count = 0 THEN
            RAISE NOTICE '⚠️ MISMATCH: Direct table shows % items but function returns 0', inventory_count;
        ELSIF inventory_count = 0 AND function_result_count > 0 THEN
            RAISE NOTICE '⚠️ MISMATCH: Direct table shows 0 items but function returns %', function_result_count;
        ELSIF inventory_count = function_result_count THEN
            RAISE NOTICE '✅ CONSISTENT: Both queries return % items', inventory_count;
        ELSE
            RAISE NOTICE '⚠️ MISMATCH: Direct table shows % items but function returns %', inventory_count, function_result_count;
        END IF;
    END LOOP;
END $$;

-- Step 2: Check for orphaned inventory items (items without valid products)
SELECT 
    '🔍 ORPHANED INVENTORY ITEMS' as check_type,
    COUNT(*) as orphaned_count,
    STRING_AGG(DISTINCT wi.product_id, ', ') as orphaned_product_ids
FROM warehouse_inventory wi
LEFT JOIN products p ON wi.product_id = p.id
WHERE p.id IS NULL;

-- Step 3: Check for products table issues
SELECT 
    '📦 PRODUCTS TABLE STATUS' as check_type,
    COUNT(*) as total_products,
    COUNT(*) FILTER (WHERE active = true) as active_products,
    COUNT(*) FILTER (WHERE active = false OR active IS NULL) as inactive_products
FROM products;

-- Step 4: Check warehouse_inventory table structure and data types
SELECT 
    '🏗️ WAREHOUSE_INVENTORY STRUCTURE' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'warehouse_inventory' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Step 5: Sample warehouse inventory data with product join
SELECT 
    '📋 SAMPLE INVENTORY WITH PRODUCTS' as check_type,
    wi.warehouse_id,
    w.name as warehouse_name,
    wi.product_id,
    wi.quantity,
    p.name as product_name,
    p.active as product_active,
    CASE 
        WHEN p.id IS NULL THEN 'ORPHANED'
        WHEN p.active = false THEN 'INACTIVE_PRODUCT'
        ELSE 'VALID'
    END as status
FROM warehouse_inventory wi
LEFT JOIN warehouses w ON wi.warehouse_id = w.id
LEFT JOIN products p ON wi.product_id = p.id
WHERE w.is_active = true
ORDER BY w.name, wi.product_id
LIMIT 20;

-- Step 6: Check for UUID vs TEXT type mismatches
DO $$
DECLARE
    warehouse_id_type TEXT;
    product_id_type TEXT;
BEGIN
    -- Check warehouse_id column type
    SELECT data_type INTO warehouse_id_type
    FROM information_schema.columns 
    WHERE table_name = 'warehouse_inventory' 
    AND column_name = 'warehouse_id' 
    AND table_schema = 'public';
    
    -- Check product_id column type
    SELECT data_type INTO product_id_type
    FROM information_schema.columns 
    WHERE table_name = 'warehouse_inventory' 
    AND column_name = 'product_id' 
    AND table_schema = 'public';
    
    RAISE NOTICE '🔍 Data type analysis:';
    RAISE NOTICE '  - warehouse_id type: %', warehouse_id_type;
    RAISE NOTICE '  - product_id type: %', product_id_type;
    
    -- Check products table id type
    SELECT data_type INTO product_id_type
    FROM information_schema.columns 
    WHERE table_name = 'products' 
    AND column_name = 'id' 
    AND table_schema = 'public';
    
    RAISE NOTICE '  - products.id type: %', product_id_type;
END $$;

-- Step 7: Test the get_warehouse_inventory_with_products function with detailed output
DO $$
DECLARE
    test_warehouse_id UUID;
    result_record RECORD;
    result_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🧪 Testing get_warehouse_inventory_with_products function...';
    
    -- Get a warehouse with inventory
    SELECT wi.warehouse_id INTO test_warehouse_id
    FROM warehouse_inventory wi
    JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE w.is_active = true
    GROUP BY wi.warehouse_id
    HAVING COUNT(*) > 0
    LIMIT 1;
    
    IF test_warehouse_id IS NOT NULL THEN
        RAISE NOTICE '🎯 Testing with warehouse ID: %', test_warehouse_id;
        
        -- Test the function
        FOR result_record IN
            SELECT * FROM get_warehouse_inventory_with_products(test_warehouse_id) LIMIT 5
        LOOP
            result_count := result_count + 1;
            RAISE NOTICE '📦 Item %: Product ID %, Quantity %, Product Name %', 
                result_count, 
                result_record.product_id, 
                result_record.quantity, 
                COALESCE(result_record.product_name, 'NULL');
        END LOOP;
        
        RAISE NOTICE '✅ Function returned % items', result_count;
    ELSE
        RAISE NOTICE '❌ No warehouse with inventory found for testing';
    END IF;
END $$;

-- Step 8: Check for RLS policy issues
SELECT 
    '🔒 RLS POLICIES CHECK' as check_type,
    schemaname,
    tablename,
    policyname,
    cmd,
    CASE 
        WHEN qual IS NOT NULL THEN 'HAS_USING_CLAUSE'
        ELSE 'NO_USING_CLAUSE'
    END as using_status,
    CASE 
        WHEN with_check IS NOT NULL THEN 'HAS_WITH_CHECK'
        ELSE 'NO_WITH_CHECK'
    END as with_check_status
FROM pg_policies 
WHERE tablename IN ('warehouse_inventory', 'products', 'warehouses')
ORDER BY tablename, cmd;

-- Step 9: Final summary and recommendations
DO $$
DECLARE
    total_warehouses INTEGER;
    warehouses_with_inventory INTEGER;
    total_inventory_items INTEGER;
    orphaned_items INTEGER;
BEGIN
    -- Get summary statistics
    SELECT COUNT(*) INTO total_warehouses FROM warehouses WHERE is_active = true;
    
    SELECT COUNT(DISTINCT warehouse_id) INTO warehouses_with_inventory 
    FROM warehouse_inventory wi
    JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE w.is_active = true;
    
    SELECT COUNT(*) INTO total_inventory_items 
    FROM warehouse_inventory wi
    JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE w.is_active = true;
    
    SELECT COUNT(*) INTO orphaned_items
    FROM warehouse_inventory wi
    LEFT JOIN products p ON wi.product_id = p.id
    WHERE p.id IS NULL;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 SUMMARY REPORT:';
    RAISE NOTICE '==================';
    RAISE NOTICE '🏭 Total active warehouses: %', total_warehouses;
    RAISE NOTICE '📦 Warehouses with inventory: %', warehouses_with_inventory;
    RAISE NOTICE '📋 Total inventory items: %', total_inventory_items;
    RAISE NOTICE '🚫 Orphaned inventory items: %', orphaned_items;
    
    IF orphaned_items > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️ ISSUE DETECTED: % orphaned inventory items found', orphaned_items;
        RAISE NOTICE '💡 RECOMMENDATION: Run fix_orphaned_product_references() function';
    END IF;
    
    IF warehouses_with_inventory = 0 AND total_warehouses > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠️ ISSUE DETECTED: No warehouses have inventory despite warehouses existing';
        RAISE NOTICE '💡 RECOMMENDATION: Check data import and RLS policies';
    END IF;
END $$;

RAISE NOTICE '';
RAISE NOTICE '🎉 Inventory statistics mismatch diagnosis completed!';
RAISE NOTICE 'ℹ️ Review the output above to identify the root cause of the mismatch';
