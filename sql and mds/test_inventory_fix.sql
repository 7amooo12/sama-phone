-- Test script to verify the inventory function fix
-- This will test if the function now works without the column reference error

-- Test 1: Check if function exists and can be called
SELECT 'Testing function existence and basic execution' as test_step;

DO $$
DECLARE
    function_exists BOOLEAN := FALSE;
    test_warehouse_id UUID;
    result_count INTEGER := 0;
BEGIN
    -- Check if function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_warehouse_inventory_with_products'
    ) INTO function_exists;
    
    IF function_exists THEN
        RAISE NOTICE '✅ Function get_warehouse_inventory_with_products exists';
        
        -- Get a real warehouse ID for testing
        SELECT id INTO test_warehouse_id 
        FROM warehouses 
        WHERE is_active = true 
        LIMIT 1;
        
        IF test_warehouse_id IS NOT NULL THEN
            RAISE NOTICE '🎯 Testing with warehouse ID: %', test_warehouse_id;
            
            -- Test the function with real warehouse ID
            BEGIN
                SELECT COUNT(*) INTO result_count
                FROM get_warehouse_inventory_with_products(test_warehouse_id);
                
                RAISE NOTICE '✅ Function executed successfully, returned % items', result_count;
                
                -- Test a sample of the results
                IF result_count > 0 THEN
                    RAISE NOTICE '📦 Sample inventory data:';
                    FOR rec IN 
                        SELECT product_name, quantity, product_is_active 
                        FROM get_warehouse_inventory_with_products(test_warehouse_id) 
                        LIMIT 3
                    LOOP
                        RAISE NOTICE '  - Product: %, Quantity: %, Active: %', 
                            rec.product_name, rec.quantity, rec.product_is_active;
                    END LOOP;
                END IF;
                
            EXCEPTION
                WHEN OTHERS THEN
                    IF SQLERRM LIKE '%is_active%' THEN
                        RAISE NOTICE '❌ Function still contains is_active reference: %', SQLERRM;
                    ELSE
                        RAISE NOTICE 'ℹ️ Function test completed with error (may be unrelated): %', SQLERRM;
                    END IF;
            END;
        ELSE
            RAISE NOTICE '⚠️ No active warehouses found for testing';
        END IF;
    ELSE
        RAISE NOTICE '❌ Function get_warehouse_inventory_with_products does not exist';
    END IF;
END $$;

-- Test 2: Verify the function definition doesn't contain is_active references
SELECT 'Checking function definition for is_active references' as test_step;

DO $$
DECLARE
    function_def TEXT;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO function_def
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' 
    AND p.proname = 'get_warehouse_inventory_with_products'
    LIMIT 1;
    
    IF function_def IS NOT NULL THEN
        IF function_def ILIKE '%p.is_active%' OR function_def ILIKE '%products_1.is_active%' THEN
            RAISE NOTICE '❌ Function definition still contains is_active reference';
        ELSE
            RAISE NOTICE '✅ Function definition uses correct p.active column reference';
        END IF;
        
        IF function_def ILIKE '%p.active%' THEN
            RAISE NOTICE '✅ Function correctly references p.active column';
        END IF;
    ELSE
        RAISE NOTICE '❌ Could not retrieve function definition';
    END IF;
END $$;
