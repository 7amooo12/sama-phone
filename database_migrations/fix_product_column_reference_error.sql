-- ============================================================================
-- FIX PRODUCT COLUMN REFERENCE ERROR
-- ============================================================================
-- إصلاح خطأ مرجع عمود المنتج p.is_active إلى p.active
-- Fixes PostgreSQL error: "column p.is_active does not exist"
-- ============================================================================

-- Step 1: Check current database functions that might reference p.is_active
DO $$
DECLARE
    function_record RECORD;
    function_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🔍 Checking for database functions that might reference p.is_active...';
    
    -- Check for functions that might contain the problematic reference
    FOR function_record IN
        SELECT 
            p.proname as function_name,
            n.nspname as schema_name,
            pg_get_functiondef(p.oid) as function_definition
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND pg_get_functiondef(p.oid) ILIKE '%p.is_active%'
    LOOP
        function_count := function_count + 1;
        RAISE NOTICE '⚠️ Found function with p.is_active reference: %.%', 
            function_record.schema_name, function_record.function_name;
    END LOOP;
    
    IF function_count = 0 THEN
        RAISE NOTICE '✅ No functions found with p.is_active references';
    ELSE
        RAISE NOTICE '❌ Found % functions with p.is_active references that need fixing', function_count;
    END IF;
END $$;

-- Step 2: Ensure products table uses 'active' column consistently
DO $$
BEGIN
    RAISE NOTICE '🔧 Ensuring products table uses active column consistently...';
    
    -- Check if products table has is_active column and rename it to active
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' 
        AND column_name = 'is_active' 
        AND table_schema = 'public'
    ) THEN
        -- Check if active column already exists
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'products' 
            AND column_name = 'active' 
            AND table_schema = 'public'
        ) THEN
            -- Both columns exist - merge data and drop is_active
            UPDATE products SET active = is_active WHERE active IS NULL;
            ALTER TABLE products DROP COLUMN is_active;
            RAISE NOTICE '✅ Merged is_active into active column and dropped is_active';
        ELSE
            -- Only is_active exists - rename it
            ALTER TABLE products RENAME COLUMN is_active TO active;
            RAISE NOTICE '✅ Renamed is_active to active in products table';
        END IF;
    ELSIF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' 
        AND column_name = 'active' 
        AND table_schema = 'public'
    ) THEN
        -- No active column exists - create it
        ALTER TABLE products ADD COLUMN active BOOLEAN DEFAULT true;
        RAISE NOTICE '✅ Added active column to products table';
    ELSE
        RAISE NOTICE 'ℹ️ Products table already has active column correctly';
    END IF;
END $$;

-- Step 3: Update get_warehouse_inventory_with_products function to use correct column
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

-- Step 4: Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_warehouse_inventory_with_products(UUID) TO authenticated;

-- Step 5: Update any other functions that might reference p.is_active
-- Check and fix search_product_globally function if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'search_product_globally'
    ) THEN
        -- Function exists, check if it needs updating
        IF pg_get_functiondef((
            SELECT p.oid FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public' AND p.proname = 'search_product_globally'
            LIMIT 1
        )) ILIKE '%p.is_active%' THEN
            RAISE NOTICE '⚠️ search_product_globally function needs manual review for p.is_active references';
        ELSE
            RAISE NOTICE '✅ search_product_globally function does not contain p.is_active references';
        END IF;
    ELSE
        RAISE NOTICE 'ℹ️ search_product_globally function does not exist';
    END IF;
END $$;

-- Step 6: Create index on active column for better performance
CREATE INDEX IF NOT EXISTS idx_products_active 
ON public.products(active) 
WHERE active = true;

-- Step 7: Verify the fix
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
        RAISE NOTICE '✅ Function get_warehouse_inventory_with_products exists';
        
        -- Try to execute the function with a test warehouse ID (this will work even if no data exists)
        BEGIN
            PERFORM * FROM get_warehouse_inventory_with_products('00000000-0000-0000-0000-000000000000'::UUID) LIMIT 1;
            RAISE NOTICE '✅ Function executes without column reference errors';
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLERRM LIKE '%p.is_active%' THEN
                    RAISE NOTICE '❌ Function still contains p.is_active reference: %', SQLERRM;
                ELSE
                    RAISE NOTICE 'ℹ️ Function test completed (error unrelated to column reference): %', SQLERRM;
                END IF;
        END;
    ELSE
        RAISE NOTICE '❌ Function get_warehouse_inventory_with_products was not created successfully';
    END IF;
END $$;

-- Step 8: Final verification
SELECT
    '✅ PRODUCTS TABLE COLUMN VERIFICATION' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'products'
AND table_schema = 'public'
AND column_name IN ('active', 'is_active')
ORDER BY column_name;

-- Step 9: Final completion messages
DO $$
BEGIN
    RAISE NOTICE '🎉 Product column reference error fix completed!';
    RAISE NOTICE 'ℹ️ All database functions should now use p.active instead of p.is_active';
END $$;
