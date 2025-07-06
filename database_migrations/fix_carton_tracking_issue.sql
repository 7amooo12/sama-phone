-- =====================================================
-- Fix Carton Tracking Issue
-- =====================================================
-- This script diagnoses and fixes common carton tracking issues

-- Begin transaction
BEGIN;

-- =====================================================
-- 1. DIAGNOSIS: Check if column exists
-- =====================================================

DO $$
DECLARE
    column_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_inventory' 
        AND column_name = 'quantity_per_carton'
    ) INTO column_exists;
    
    IF column_exists THEN
        RAISE NOTICE '✅ Column quantity_per_carton exists';
    ELSE
        RAISE NOTICE '❌ Column quantity_per_carton does NOT exist - adding it now';
        
        -- Add the column if it doesn't exist
        ALTER TABLE warehouse_inventory 
        ADD COLUMN quantity_per_carton INTEGER NOT NULL DEFAULT 1;
        
        -- Add check constraint
        ALTER TABLE warehouse_inventory 
        ADD CONSTRAINT chk_quantity_per_carton_positive 
        CHECK (quantity_per_carton > 0);
        
        RAISE NOTICE '✅ Added quantity_per_carton column';
    END IF;
END $$;

-- =====================================================
-- 2. FIX: Update any NULL or zero values
-- =====================================================

UPDATE warehouse_inventory 
SET quantity_per_carton = 1 
WHERE quantity_per_carton IS NULL OR quantity_per_carton <= 0;

-- =====================================================
-- 3. FIX: Ensure proper data types
-- =====================================================

-- Make sure the column is the right type
DO $$
BEGIN
    -- Check if column is INTEGER type
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_inventory' 
        AND column_name = 'quantity_per_carton'
        AND data_type = 'integer'
    ) THEN
        -- Convert to INTEGER if it's not
        ALTER TABLE warehouse_inventory 
        ALTER COLUMN quantity_per_carton TYPE INTEGER USING quantity_per_carton::INTEGER;
        
        RAISE NOTICE '✅ Fixed column data type to INTEGER';
    END IF;
END $$;

-- =====================================================
-- 4. CREATE INDEXES if they don't exist
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_quantity_per_carton 
ON warehouse_inventory(quantity_per_carton);

CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_carton_calc 
ON warehouse_inventory(warehouse_id, quantity, quantity_per_carton);

-- =====================================================
-- 5. CREATE FUNCTION if it doesn't exist
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_cartons(
    total_quantity INTEGER,
    quantity_per_carton INTEGER
) RETURNS INTEGER AS $$
BEGIN
    -- Handle edge cases
    IF total_quantity IS NULL OR total_quantity <= 0 THEN
        RETURN 0;
    END IF;
    
    IF quantity_per_carton IS NULL OR quantity_per_carton <= 0 THEN
        RETURN total_quantity; -- Assume 1 per carton if invalid
    END IF;
    
    -- Calculate cartons using ceiling function (always round up)
    RETURN CEIL(total_quantity::DECIMAL / quantity_per_carton::DECIMAL)::INTEGER;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Grant permissions
GRANT EXECUTE ON FUNCTION calculate_cartons(integer, integer) TO authenticated;

-- =====================================================
-- 6. TEST: Insert and verify a test record with proper UUID handling
-- =====================================================

DO $$
DECLARE
    test_warehouse_id UUID;
    test_product_id UUID;
    inserted_carton_qty INTEGER;
    calculated_cartons INTEGER;
    warehouse_id_type TEXT;
    product_id_type TEXT;
BEGIN
    -- First, check the actual data types of the columns
    SELECT data_type INTO warehouse_id_type
    FROM information_schema.columns
    WHERE table_name = 'warehouse_inventory'
    AND column_name = 'warehouse_id';

    SELECT data_type INTO product_id_type
    FROM information_schema.columns
    WHERE table_name = 'warehouse_inventory'
    AND column_name = 'product_id';

    RAISE NOTICE 'Column types - warehouse_id: %, product_id: %', warehouse_id_type, product_id_type;

    -- Generate proper UUIDs for testing
    test_warehouse_id := gen_random_uuid();
    test_product_id := gen_random_uuid();

    RAISE NOTICE 'Using test UUIDs - warehouse: %, product: %', test_warehouse_id, test_product_id;

    BEGIN
        -- Clean up any existing test data (with proper UUID types)
        DELETE FROM warehouse_inventory
        WHERE warehouse_id = test_warehouse_id
        AND product_id = test_product_id;

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
            25,  -- 25 items
            6,   -- 6 per carton = should be 5 cartons (25/6 = 4.17 -> ceil = 5)
            'test-user'
        );

        -- Verify the data was inserted correctly
        SELECT quantity_per_carton INTO inserted_carton_qty
        FROM warehouse_inventory
        WHERE warehouse_id = test_warehouse_id
        AND product_id = test_product_id;

        -- Calculate cartons using the function
        SELECT calculate_cartons(25, 6) INTO calculated_cartons;

        -- Check results
        IF inserted_carton_qty = 6 AND calculated_cartons = 5 THEN
            RAISE NOTICE '✅ TEST PASSED: Carton tracking is working correctly';
            RAISE NOTICE '   - Inserted quantity_per_carton: %', inserted_carton_qty;
            RAISE NOTICE '   - Calculated cartons for 25 items: %', calculated_cartons;
        ELSE
            RAISE NOTICE '❌ TEST FAILED: Carton tracking has issues';
            RAISE NOTICE '   - Expected quantity_per_carton: 6, Got: %', inserted_carton_qty;
            RAISE NOTICE '   - Expected cartons: 5, Got: %', calculated_cartons;
        END IF;

        -- Clean up test data (with proper UUID types)
        DELETE FROM warehouse_inventory
        WHERE warehouse_id = test_warehouse_id
        AND product_id = test_product_id;

        RAISE NOTICE '✅ Test data cleaned up successfully';

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ TEST ERROR: %', SQLERRM;
        RAISE NOTICE 'Error details: %', SQLSTATE;

        -- Try to clean up even if test failed
        BEGIN
            DELETE FROM warehouse_inventory
            WHERE warehouse_id = test_warehouse_id
            AND product_id = test_product_id;
            RAISE NOTICE 'Cleanup after error completed';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Cleanup after error failed: %', SQLERRM;
        END;
    END;

END $$;

-- =====================================================
-- 7. VERIFICATION: Show current status
-- =====================================================

DO $$
DECLARE
    total_records INTEGER;
    records_with_carton_data INTEGER;
    avg_carton_qty NUMERIC;
BEGIN
    -- Get statistics
    SELECT 
        COUNT(*),
        COUNT(CASE WHEN quantity_per_carton IS NOT NULL AND quantity_per_carton > 0 THEN 1 END),
        AVG(quantity_per_carton)
    INTO total_records, records_with_carton_data, avg_carton_qty
    FROM warehouse_inventory;
    
    RAISE NOTICE '📊 WAREHOUSE INVENTORY STATISTICS:';
    RAISE NOTICE '   - Total records: %', total_records;
    RAISE NOTICE '   - Records with carton data: %', records_with_carton_data;
    RAISE NOTICE '   - Average quantity per carton: %', ROUND(avg_carton_qty, 2);
    
    IF records_with_carton_data = total_records THEN
        RAISE NOTICE '✅ All records have valid carton data';
    ELSE
        RAISE NOTICE '⚠️  Some records may have invalid carton data';
    END IF;
END $$;

-- Commit the transaction
COMMIT;

-- Final success message
DO $$
BEGIN
    RAISE NOTICE '🎉 Carton tracking fix completed successfully!';
END $$;
