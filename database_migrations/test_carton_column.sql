-- =====================================================
-- Test Script to Verify Carton Tracking Column
-- =====================================================
-- Run this to check if the quantity_per_carton column exists and works

-- 1. Check if column exists
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'warehouse_inventory' 
AND column_name = 'quantity_per_carton';

-- 2. Check sample data
SELECT 
    id,
    warehouse_id,
    product_id,
    quantity,
    quantity_per_carton,
    CASE 
        WHEN quantity_per_carton > 0 
        THEN CEIL(quantity::DECIMAL / quantity_per_carton::DECIMAL)
        ELSE 0
    END as calculated_cartons
FROM warehouse_inventory 
LIMIT 5;

-- 3. Test inserting a record with carton data (with proper UUID handling)
DO $$
DECLARE
    test_warehouse_id UUID := gen_random_uuid();
    test_product_id UUID := gen_random_uuid();
BEGIN
    -- Insert test record with proper UUID types
    INSERT INTO warehouse_inventory (
        warehouse_id,
        product_id,
        quantity,
        quantity_per_carton,
        updated_by
    ) VALUES (
        test_warehouse_id,
        test_product_id,
        24,
        12,
        'test-user-id'
    )
    ON CONFLICT (warehouse_id, product_id)
    DO UPDATE SET
        quantity = EXCLUDED.quantity,
        quantity_per_carton = EXCLUDED.quantity_per_carton,
        updated_by = EXCLUDED.updated_by;

    -- 4. Verify the test record
    RAISE NOTICE 'Test record verification:';
    PERFORM warehouse_id, product_id, quantity, quantity_per_carton,
            CEIL(quantity::DECIMAL / quantity_per_carton::DECIMAL) as cartons
    FROM warehouse_inventory
    WHERE warehouse_id = test_warehouse_id
    AND product_id = test_product_id;

    -- Show the results
    FOR rec IN
        SELECT
            warehouse_id,
            product_id,
            quantity,
            quantity_per_carton,
            CEIL(quantity::DECIMAL / quantity_per_carton::DECIMAL) as cartons
        FROM warehouse_inventory
        WHERE warehouse_id = test_warehouse_id
        AND product_id = test_product_id
    LOOP
        RAISE NOTICE 'Warehouse: %, Product: %, Quantity: %, Per Carton: %, Total Cartons: %',
                     rec.warehouse_id, rec.product_id, rec.quantity, rec.quantity_per_carton, rec.cartons;
    END LOOP;

    -- 5. Clean up test record (with proper UUID types)
    DELETE FROM warehouse_inventory
    WHERE warehouse_id = test_warehouse_id
    AND product_id = test_product_id;

    RAISE NOTICE 'Test completed and cleaned up successfully';

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test failed with error: %', SQLERRM;
END $$;
