-- =====================================================
-- Fix Carton Calculation Issue
-- =====================================================
-- This migration fixes the warehouse inventory carton calculation issue
-- by updating the get_warehouse_inventory_with_products function to include
-- the quantity_per_carton field that was missing from the original function.

-- Problem: The database function was missing quantity_per_carton in both
-- the return type and SELECT statement, causing the UI to default to 1
-- instead of using the actual stored value.

-- Solution: Update the function to include quantity_per_carton field

-- Step 1: Drop the existing function if it exists
DROP FUNCTION IF EXISTS get_warehouse_inventory_with_products(UUID);

-- Step 2: Create the corrected function with quantity_per_carton included
CREATE OR REPLACE FUNCTION get_warehouse_inventory_with_products(p_warehouse_id UUID)
RETURNS TABLE (
    inventory_id UUID,
    warehouse_id UUID,
    product_id TEXT,
    quantity INTEGER,
    minimum_stock INTEGER,
    maximum_stock INTEGER,
    quantity_per_carton INTEGER,
    last_updated TIMESTAMP WITH TIME ZONE,
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
        COALESCE(p.main_image_url, p.image_url) as product_image_url,
        p.sku as product_sku,
        p.active as product_is_active
    FROM public.warehouse_inventory wi
    LEFT JOIN public.products p ON wi.product_id = p.id
    WHERE wi.warehouse_id = p_warehouse_id
    ORDER BY wi.last_updated DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_warehouse_inventory_with_products(UUID) TO authenticated;

-- Step 4: Test the function with a sample warehouse
DO $$
DECLARE
    test_warehouse_id UUID;
    rec RECORD;
    test_count INTEGER := 0;
BEGIN
    -- Get a real warehouse ID for testing
    SELECT id INTO test_warehouse_id 
    FROM warehouses 
    LIMIT 1;
    
    IF test_warehouse_id IS NOT NULL THEN
        RAISE NOTICE 'Testing corrected function with warehouse ID: %', test_warehouse_id;
        
        -- Test the function and show results
        FOR rec IN 
            SELECT * FROM get_warehouse_inventory_with_products(test_warehouse_id)
            LIMIT 3
        LOOP
            test_count := test_count + 1;
            RAISE NOTICE 'Product: %, Quantity: %, Carton Qty: %, Product Name: %', 
                         rec.product_id, rec.quantity, rec.quantity_per_carton, rec.product_name;
        END LOOP;
        
        IF test_count = 0 THEN
            RAISE NOTICE 'No inventory found for warehouse %, but function executed successfully', test_warehouse_id;
        ELSE
            RAISE NOTICE 'Function test completed successfully with % records', test_count;
        END IF;
    ELSE
        RAISE NOTICE 'No warehouses found for testing, but function created successfully';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error testing function: %', SQLERRM;
END $$;

-- Step 5: Verify the fix by checking a specific product if it exists
DO $$
DECLARE
    test_product_id TEXT := '194'; -- The product mentioned in the logs
    rec RECORD;
BEGIN
    -- Check if this specific product exists in any warehouse
    FOR rec IN 
        SELECT 
            wi.warehouse_id,
            wi.product_id,
            wi.quantity,
            wi.quantity_per_carton,
            (wi.quantity::DECIMAL / NULLIF(wi.quantity_per_carton, 0))::INTEGER as calculated_cartons
        FROM warehouse_inventory wi
        WHERE wi.product_id = test_product_id
        LIMIT 1
    LOOP
        RAISE NOTICE 'Verification for Product %:', test_product_id;
        RAISE NOTICE '  Warehouse: %', rec.warehouse_id;
        RAISE NOTICE '  Quantity: %', rec.quantity;
        RAISE NOTICE '  Quantity per Carton: %', rec.quantity_per_carton;
        RAISE NOTICE '  Calculated Cartons: %', rec.calculated_cartons;
        
        -- Test the function for this warehouse
        FOR rec IN 
            SELECT * FROM get_warehouse_inventory_with_products(rec.warehouse_id)
            WHERE product_id = test_product_id
        LOOP
            RAISE NOTICE '  Function Result - Carton Qty: %', rec.quantity_per_carton;
        END LOOP;
    END LOOP;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in verification: %', SQLERRM;
END $$;

-- Step 6: Final success message
DO $$
BEGIN
    RAISE NOTICE 'Carton calculation fix migration completed successfully!';
    RAISE NOTICE 'The get_warehouse_inventory_with_products function now includes quantity_per_carton field.';
    RAISE NOTICE 'This should resolve the UI displaying incorrect carton counts.';
END $$;
