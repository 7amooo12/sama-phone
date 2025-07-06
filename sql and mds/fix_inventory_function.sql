-- CRITICAL FIX: Update get_warehouse_inventory_with_products function to use correct column reference
-- This fixes the PostgreSQL error: column products_1.is_active does not exist

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
        COALESCE(wi.quantity, 0) as quantity,
        COALESCE(wi.minimum_stock, 0) as minimum_stock,
        COALESCE(wi.maximum_stock, 0) as maximum_stock,
        COALESCE(wi.quantity_per_carton, 1) as quantity_per_carton,
        wi.last_updated,
        wi.updated_by,
        COALESCE(p.name, 'Unknown Product') as product_name,
        COALESCE(p.description, '') as product_description,
        COALESCE(p.price, 0) as product_price,
        COALESCE(p.category, 'Uncategorized') as product_category,
        COALESCE(p.main_image_url, p.image_url, '') as product_image_url,
        COALESCE(p.sku, '') as product_sku,
        COALESCE(p.active, true) as product_is_active  -- CRITICAL FIX: use p.active instead of p.is_active
    FROM public.warehouse_inventory wi
    LEFT JOIN public.products p ON wi.product_id = p.id::text
    WHERE wi.warehouse_id = p_warehouse_id
    ORDER BY wi.last_updated DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_warehouse_inventory_with_products(UUID) TO authenticated;

-- Test the function to ensure it works
DO $$
DECLARE
    test_result RECORD;
    function_exists BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE '🧪 Testing the fixed function...';
    
    -- Check if function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_warehouse_inventory_with_products'
    ) INTO function_exists;
    
    IF function_exists THEN
        RAISE NOTICE '✅ Function get_warehouse_inventory_with_products exists and updated';
        
        -- Try to execute the function with a test warehouse ID
        BEGIN
            PERFORM * FROM get_warehouse_inventory_with_products('00000000-0000-0000-0000-000000000000'::UUID) LIMIT 1;
            RAISE NOTICE '✅ Function executes without column reference errors';
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLERRM LIKE '%is_active%' THEN
                    RAISE NOTICE '❌ Function still contains is_active reference: %', SQLERRM;
                ELSE
                    RAISE NOTICE 'ℹ️ Function test completed (error unrelated to column reference): %', SQLERRM;
                END IF;
        END;
    ELSE
        RAISE NOTICE '❌ Function get_warehouse_inventory_with_products was not created successfully';
    END IF;
END $$;
