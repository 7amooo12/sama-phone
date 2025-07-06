-- =====================================================
-- Debug Inventory Loading Issues
-- =====================================================
-- This script helps debug why quantity_per_carton is not loading correctly

-- 1. Check if the database function exists and what it returns
SELECT 
    proname as function_name,
    pg_get_function_arguments(oid) as arguments,
    pg_get_function_result(oid) as return_type
FROM pg_proc 
WHERE proname = 'get_warehouse_inventory_with_products';

-- 2. Check the warehouse_inventory table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'warehouse_inventory'
ORDER BY ordinal_position;

-- 3. Check sample data from warehouse_inventory table
SELECT 
    id,
    warehouse_id,
    product_id,
    quantity,
    quantity_per_carton,
    last_updated
FROM warehouse_inventory 
LIMIT 5;

-- 4. Test the database function directly (if it exists)
-- Replace 'your-warehouse-id' with an actual warehouse ID
DO $$
DECLARE
    test_warehouse_id UUID;
    function_exists BOOLEAN;
BEGIN
    -- Get a real warehouse ID for testing
    SELECT id INTO test_warehouse_id 
    FROM warehouses 
    LIMIT 1;
    
    -- Check if function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'get_warehouse_inventory_with_products'
    ) INTO function_exists;
    
    IF function_exists AND test_warehouse_id IS NOT NULL THEN
        RAISE NOTICE 'Testing function with warehouse ID: %', test_warehouse_id;
        
        -- Test the function
        PERFORM * FROM get_warehouse_inventory_with_products(test_warehouse_id);
        
        RAISE NOTICE 'Function executed successfully';
    ELSE
        IF NOT function_exists THEN
            RAISE NOTICE 'Function get_warehouse_inventory_with_products does not exist';
        END IF;
        
        IF test_warehouse_id IS NULL THEN
            RAISE NOTICE 'No warehouses found for testing';
        END IF;
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error testing function: %', SQLERRM;
END $$;

-- 5. Check if there are any NULL quantity_per_carton values
SELECT 
    COUNT(*) as total_records,
    COUNT(quantity_per_carton) as records_with_carton_data,
    COUNT(*) - COUNT(quantity_per_carton) as null_carton_records,
    AVG(quantity_per_carton) as avg_carton_qty
FROM warehouse_inventory;

-- 6. Show records with NULL or problematic quantity_per_carton values
SELECT 
    id,
    warehouse_id,
    product_id,
    quantity,
    quantity_per_carton,
    CASE 
        WHEN quantity_per_carton IS NULL THEN 'NULL'
        WHEN quantity_per_carton <= 0 THEN 'ZERO_OR_NEGATIVE'
        ELSE 'OK'
    END as carton_status
FROM warehouse_inventory 
WHERE quantity_per_carton IS NULL 
   OR quantity_per_carton <= 0
LIMIT 10;

-- 7. Create or update the database function if it doesn't exist or is missing quantity_per_carton
CREATE OR REPLACE FUNCTION get_warehouse_inventory_with_products(p_warehouse_id UUID)
RETURNS TABLE (
    inventory_id UUID,
    warehouse_id UUID,
    product_id TEXT,
    quantity INTEGER,
    minimum_stock INTEGER,
    maximum_stock INTEGER,
    quantity_per_carton INTEGER,
    last_updated TIMESTAMPTZ,
    updated_by UUID,
    product_name TEXT,
    product_description TEXT,
    product_price DECIMAL,
    product_category TEXT,
    product_image_url TEXT,
    product_sku TEXT,
    product_is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wi.id as inventory_id,
        wi.warehouse_id,
        wi.product_id,
        wi.quantity,
        wi.minimum_stock,
        wi.maximum_stock,
        wi.quantity_per_carton,
        wi.last_updated,
        wi.updated_by,
        p.name as product_name,
        p.description as product_description,
        p.price as product_price,
        p.category as product_category,
        p.image_url as product_image_url,
        p.sku as product_sku,
        p.active as product_is_active
    FROM warehouse_inventory wi
    LEFT JOIN products p ON wi.product_id = p.id::text
    WHERE wi.warehouse_id = p_warehouse_id
    ORDER BY wi.last_updated DESC;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_warehouse_inventory_with_products(UUID) TO authenticated;

-- 8. Test the updated function
DO $$
DECLARE
    test_warehouse_id UUID;
    rec RECORD;
BEGIN
    -- Get a real warehouse ID for testing
    SELECT id INTO test_warehouse_id 
    FROM warehouses 
    LIMIT 1;
    
    IF test_warehouse_id IS NOT NULL THEN
        RAISE NOTICE 'Testing updated function with warehouse ID: %', test_warehouse_id;
        
        -- Test the function and show results
        FOR rec IN 
            SELECT * FROM get_warehouse_inventory_with_products(test_warehouse_id)
            LIMIT 3
        LOOP
            RAISE NOTICE 'Product: %, Quantity: %, Carton Qty: %, Product Name: %', 
                         rec.product_id, rec.quantity, rec.quantity_per_carton, rec.product_name;
        END LOOP;
    ELSE
        RAISE NOTICE 'No warehouses found for testing';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error testing updated function: %', SQLERRM;
END $$;
