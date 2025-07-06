-- =====================================================
-- Carton/Box Tracking Enhancement Migration Script (UUID-Safe)
-- =====================================================
-- This version properly handles UUID types for warehouse_id and product_id
-- Date: 2025-06-15
-- Version: 1.2 (UUID-Safe)

-- Begin transaction for atomic migration
BEGIN;

-- =====================================================
-- 1. Check existing table structure and data types
-- =====================================================

DO $$
DECLARE
    warehouse_id_type TEXT;
    product_id_type TEXT;
    table_exists BOOLEAN;
BEGIN
    -- Check if table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'warehouse_inventory'
    ) INTO table_exists;
    
    IF NOT table_exists THEN
        RAISE EXCEPTION 'Table warehouse_inventory does not exist. Please create it first.';
    END IF;
    
    -- Check data types
    SELECT data_type INTO warehouse_id_type
    FROM information_schema.columns 
    WHERE table_name = 'warehouse_inventory' 
    AND column_name = 'warehouse_id';
    
    SELECT data_type INTO product_id_type
    FROM information_schema.columns 
    WHERE table_name = 'warehouse_inventory' 
    AND column_name = 'product_id';
    
    RAISE NOTICE 'Table structure check:';
    RAISE NOTICE '- warehouse_id type: %', warehouse_id_type;
    RAISE NOTICE '- product_id type: %', product_id_type;
    
    -- Verify UUID types
    IF warehouse_id_type != 'uuid' OR product_id_type != 'uuid' THEN
        RAISE WARNING 'Expected UUID types but found: warehouse_id=%, product_id=%', 
                      warehouse_id_type, product_id_type;
    END IF;
END $$;

-- =====================================================
-- 2. Add quantity_per_carton column if it doesn't exist
-- =====================================================

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_inventory' 
        AND column_name = 'quantity_per_carton'
    ) THEN
        -- Add the new column with proper constraints
        ALTER TABLE warehouse_inventory 
        ADD COLUMN quantity_per_carton INTEGER NOT NULL DEFAULT 1;
        
        -- Add check constraint to ensure positive values
        ALTER TABLE warehouse_inventory 
        ADD CONSTRAINT chk_quantity_per_carton_positive 
        CHECK (quantity_per_carton > 0);
        
        RAISE NOTICE 'Added quantity_per_carton column to warehouse_inventory table';
    ELSE
        RAISE NOTICE 'Column quantity_per_carton already exists in warehouse_inventory table';
    END IF;
END $$;

-- =====================================================
-- 3. Create performance indexes
-- =====================================================

-- Create index on quantity_per_carton for efficient carton calculations
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_quantity_per_carton
ON warehouse_inventory(quantity_per_carton);

-- Create composite index for warehouse-specific carton calculations
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_carton_calc
ON warehouse_inventory(warehouse_id, quantity, quantity_per_carton);

-- Log index creation success
DO $$
BEGIN
    RAISE NOTICE 'Created performance indexes for carton tracking';
END $$;

-- =====================================================
-- 4. Update existing records with default carton values
-- =====================================================

-- Set default quantity_per_carton for existing records
UPDATE warehouse_inventory
SET quantity_per_carton = 1
WHERE quantity_per_carton IS NULL OR quantity_per_carton = 0;

-- Log update completion
DO $$
BEGIN
    RAISE NOTICE 'Updated existing records with default carton values';
END $$;

-- =====================================================
-- 5. Create helper function for carton calculations
-- =====================================================

-- Create or replace function (no need to drop since we use CREATE OR REPLACE)
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

-- Log function creation success
DO $$
BEGIN
    RAISE NOTICE 'Created calculate_cartons function with proper permissions';
END $$;

-- =====================================================
-- 6. Create warehouse carton statistics view
-- =====================================================

-- Drop view if exists to ensure clean recreation (this is safe since views don't have dependencies)
DROP VIEW IF EXISTS warehouse_carton_stats;

-- Create comprehensive view for warehouse carton statistics
CREATE VIEW warehouse_carton_stats AS
SELECT 
    w.id as warehouse_id,
    w.name as warehouse_name,
    w.address as warehouse_address,
    COUNT(wi.id) as total_products,
    COALESCE(SUM(wi.quantity), 0) as total_quantity,
    COALESCE(SUM(calculate_cartons(wi.quantity, wi.quantity_per_carton)), 0) as total_cartons,
    COALESCE(AVG(wi.quantity_per_carton), 0) as avg_quantity_per_carton,
    COUNT(CASE WHEN wi.quantity <= 0 THEN 1 END) as out_of_stock_products,
    COUNT(CASE WHEN wi.quantity > 0 AND wi.quantity <= COALESCE(wi.minimum_stock, 0) THEN 1 END) as low_stock_products
FROM warehouses w
LEFT JOIN warehouse_inventory wi ON w.id = wi.warehouse_id
GROUP BY w.id, w.name, w.address
ORDER BY w.name;

-- Grant permissions on the view
GRANT SELECT ON warehouse_carton_stats TO authenticated;

-- Log view creation success
DO $$
BEGIN
    RAISE NOTICE 'Created warehouse_carton_stats view with proper permissions';
END $$;

-- =====================================================
-- 7. UUID-Safe Testing and Verification
-- =====================================================

DO $$
DECLARE
    test_warehouse_id UUID;
    test_product_id UUID;
    inserted_carton_qty INTEGER;
    calculated_cartons INTEGER;
    column_exists BOOLEAN;
    function_exists BOOLEAN;
    view_exists BOOLEAN;
BEGIN
    -- Verification checks
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_inventory' 
        AND column_name = 'quantity_per_carton'
    ) INTO column_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'calculate_cartons'
    ) INTO function_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'warehouse_carton_stats'
    ) INTO view_exists;
    
    RAISE NOTICE 'Migration Verification Results:';
    RAISE NOTICE '- Column quantity_per_carton exists: %', column_exists;
    RAISE NOTICE '- calculate_cartons function exists: %', function_exists;
    RAISE NOTICE '- warehouse_carton_stats view exists: %', view_exists;
    
    -- UUID-safe functional test
    IF column_exists AND function_exists THEN
        -- Generate proper test UUIDs
        test_warehouse_id := gen_random_uuid();
        test_product_id := gen_random_uuid();
        
        BEGIN
            -- Insert test record with UUID types
            INSERT INTO warehouse_inventory (
                warehouse_id,
                product_id,
                quantity,
                quantity_per_carton,
                updated_by
            ) VALUES (
                test_warehouse_id,
                test_product_id,
                30,  -- 30 items
                8,   -- 8 per carton = should be 4 cartons (30/8 = 3.75 -> ceil = 4)
                'migration-test'
            );
            
            -- Verify the data
            SELECT quantity_per_carton INTO inserted_carton_qty
            FROM warehouse_inventory 
            WHERE warehouse_id = test_warehouse_id 
            AND product_id = test_product_id;
            
            -- Calculate cartons
            SELECT calculate_cartons(30, 8) INTO calculated_cartons;
            
            -- Check results
            IF inserted_carton_qty = 8 AND calculated_cartons = 4 THEN
                RAISE NOTICE '✅ UUID-SAFE TEST PASSED: All functionality working correctly';
                RAISE NOTICE '   - Inserted quantity_per_carton: %', inserted_carton_qty;
                RAISE NOTICE '   - Calculated cartons for 30 items: %', calculated_cartons;
            ELSE
                RAISE NOTICE '❌ UUID-SAFE TEST FAILED: Issues detected';
                RAISE NOTICE '   - Expected quantity_per_carton: 8, Got: %', inserted_carton_qty;
                RAISE NOTICE '   - Expected cartons: 4, Got: %', calculated_cartons;
            END IF;
            
            -- Clean up test data with proper UUID handling
            DELETE FROM warehouse_inventory 
            WHERE warehouse_id = test_warehouse_id 
            AND product_id = test_product_id;
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '⚠️ UUID-safe test failed: %', SQLERRM;
            -- Attempt cleanup
            BEGIN
                DELETE FROM warehouse_inventory 
                WHERE warehouse_id = test_warehouse_id 
                AND product_id = test_product_id;
            EXCEPTION WHEN OTHERS THEN
                -- Ignore cleanup errors
            END;
        END;
    END IF;
    
    -- Final verification
    IF column_exists AND function_exists AND view_exists THEN
        RAISE NOTICE '🎉 UUID-SAFE MIGRATION COMPLETED SUCCESSFULLY!';
    ELSE
        RAISE EXCEPTION 'Migration verification failed. Some components are missing.';
    END IF;
END $$;

-- Commit the transaction
COMMIT;
