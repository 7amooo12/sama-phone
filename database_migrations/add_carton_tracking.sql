-- =====================================================
-- Carton/Box Tracking Enhancement Migration Script
-- =====================================================
-- This script adds carton tracking functionality to the warehouse management system
-- Date: 2025-06-15
-- Version: 1.0

-- Begin transaction for atomic migration
BEGIN;

-- =====================================================
-- 1. Add quantity_per_carton column to warehouse_inventory table
-- =====================================================

-- Check if column already exists to ensure idempotent migration
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
-- 2. Create index for performance optimization
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
-- 3. Update existing records with default carton values
-- =====================================================

-- Set default quantity_per_carton for existing records based on product categories
-- This provides reasonable defaults for existing inventory
UPDATE warehouse_inventory 
SET quantity_per_carton = CASE 
    -- Electronics and small items: 1 per carton
    WHEN EXISTS (
        SELECT 1 FROM products p 
        WHERE p.id = warehouse_inventory.product_id 
        AND (LOWER(p.category) LIKE '%electronic%' OR LOWER(p.category) LIKE '%phone%')
    ) THEN 1
    
    -- Food and consumables: 12 per carton (common packaging)
    WHEN EXISTS (
        SELECT 1 FROM products p 
        WHERE p.id = warehouse_inventory.product_id 
        AND (LOWER(p.category) LIKE '%food%' OR LOWER(p.category) LIKE '%drink%')
    ) THEN 12
    
    -- Clothing and textiles: 6 per carton
    WHEN EXISTS (
        SELECT 1 FROM products p 
        WHERE p.id = warehouse_inventory.product_id 
        AND (LOWER(p.category) LIKE '%cloth%' OR LOWER(p.category) LIKE '%fashion%')
    ) THEN 6
    
    -- Default: 1 per carton for unknown categories
    ELSE 1
END
WHERE quantity_per_carton = 1; -- Only update records that still have default value

-- Log update completion
DO $$
BEGIN
    RAISE NOTICE 'Updated existing inventory records with intelligent carton defaults';
END $$;

-- =====================================================
-- 4. Create helper function for carton calculations
-- =====================================================

-- Use CREATE OR REPLACE instead of DROP to avoid dependency issues

-- Create function to calculate number of cartons needed
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

-- Log function creation success
DO $$
BEGIN
    RAISE NOTICE 'Created calculate_cartons helper function';
END $$;

-- =====================================================
-- 5. Create view for warehouse carton statistics
-- =====================================================

-- Drop view if exists to ensure clean recreation
DROP VIEW IF EXISTS warehouse_carton_stats;

-- Create view for easy carton statistics retrieval
CREATE VIEW warehouse_carton_stats AS
SELECT 
    w.id as warehouse_id,
    w.name as warehouse_name,
    COUNT(wi.id) as total_products,
    COALESCE(SUM(wi.quantity), 0) as total_quantity,
    COALESCE(SUM(calculate_cartons(wi.quantity, wi.quantity_per_carton)), 0) as total_cartons,
    COALESCE(AVG(wi.quantity_per_carton), 0) as avg_quantity_per_carton,
    COUNT(CASE WHEN wi.quantity > 0 THEN 1 END) as products_in_stock,
    COUNT(CASE WHEN wi.quantity = 0 THEN 1 END) as products_out_of_stock
FROM warehouses w
LEFT JOIN warehouse_inventory wi ON w.id = wi.warehouse_id
WHERE w.is_active = true
GROUP BY w.id, w.name;

-- Log view creation success
DO $$
BEGIN
    RAISE NOTICE 'Created warehouse_carton_stats view';
END $$;

-- =====================================================
-- 6. Update RLS policies for new column
-- =====================================================

-- The existing RLS policies on warehouse_inventory table will automatically
-- apply to the new column since they are table-level policies

-- =====================================================
-- 7. Create audit trigger for carton changes
-- =====================================================

-- Create audit function for carton tracking changes
CREATE OR REPLACE FUNCTION audit_carton_changes() 
RETURNS TRIGGER AS $$
BEGIN
    -- Log significant carton configuration changes
    IF TG_OP = 'UPDATE' AND OLD.quantity_per_carton != NEW.quantity_per_carton THEN
        INSERT INTO audit_log (
            table_name,
            operation,
            record_id,
            old_values,
            new_values,
            changed_by,
            changed_at
        ) VALUES (
            'warehouse_inventory',
            'CARTON_CONFIG_UPDATE',
            NEW.id,
            jsonb_build_object(
                'old_quantity_per_carton', OLD.quantity_per_carton,
                'old_calculated_cartons', calculate_cartons(OLD.quantity, OLD.quantity_per_carton)
            ),
            jsonb_build_object(
                'new_quantity_per_carton', NEW.quantity_per_carton,
                'new_calculated_cartons', calculate_cartons(NEW.quantity, NEW.quantity_per_carton)
            ),
            NEW.updated_by,
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger only if audit_log table exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'audit_log') THEN
        -- Drop trigger if exists
        DROP TRIGGER IF EXISTS trg_audit_carton_changes ON warehouse_inventory;
        
        -- Create trigger
        CREATE TRIGGER trg_audit_carton_changes
            AFTER UPDATE ON warehouse_inventory
            FOR EACH ROW
            EXECUTE FUNCTION audit_carton_changes();
            
        RAISE NOTICE 'Created audit trigger for carton tracking changes';
    ELSE
        RAISE NOTICE 'Audit log table not found, skipping audit trigger creation';
    END IF;
END $$;

-- =====================================================
-- 8. Grant necessary permissions
-- =====================================================

-- Grant permissions to authenticated users for the new function and view
GRANT EXECUTE ON FUNCTION calculate_cartons(integer, integer) TO authenticated;
GRANT SELECT ON warehouse_carton_stats TO authenticated;

-- =====================================================
-- 9. Validation and verification with UUID type handling
-- =====================================================

-- Verify the migration was successful
DO $$
DECLARE
    column_exists BOOLEAN;
    index_count INTEGER;
    function_exists BOOLEAN;
    view_exists BOOLEAN;
    test_warehouse_id UUID;
    test_product_id UUID;
    inserted_carton_qty INTEGER;
    calculated_cartons INTEGER;
BEGIN
    -- Check column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'warehouse_inventory'
        AND column_name = 'quantity_per_carton'
    ) INTO column_exists;

    -- Check indexes exist
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes
    WHERE tablename = 'warehouse_inventory'
    AND indexname LIKE '%carton%';

    -- Check function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'calculate_cartons'
    ) INTO function_exists;

    -- Check view exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_name = 'warehouse_carton_stats'
    ) INTO view_exists;

    -- Report results
    RAISE NOTICE 'Migration Verification Results:';
    RAISE NOTICE '- Column quantity_per_carton exists: %', column_exists;
    RAISE NOTICE '- Carton-related indexes created: %', index_count;
    RAISE NOTICE '- calculate_cartons function exists: %', function_exists;
    RAISE NOTICE '- warehouse_carton_stats view exists: %', view_exists;

    -- Ensure all components were created successfully
    IF NOT (column_exists AND index_count >= 2 AND function_exists AND view_exists) THEN
        RAISE EXCEPTION 'Migration verification failed. Please check the logs above.';
    END IF;

    -- Additional test with proper UUID handling
    IF column_exists AND function_exists THEN
        -- Generate test UUIDs
        test_warehouse_id := gen_random_uuid();
        test_product_id := gen_random_uuid();

        BEGIN
            -- Clean up any existing test data (with proper UUID casting)
            DELETE FROM warehouse_inventory
            WHERE warehouse_id = test_warehouse_id
            AND product_id = test_product_id;

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
                25,  -- 25 items
                6,   -- 6 per carton = should be 5 cartons (25/6 = 4.17 -> ceil = 5)
                'migration-test'
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
                RAISE NOTICE '✅ CARTON TEST PASSED: Functionality working correctly';
                RAISE NOTICE '   - Inserted quantity_per_carton: %', inserted_carton_qty;
                RAISE NOTICE '   - Calculated cartons for 25 items: %', calculated_cartons;
            ELSE
                RAISE NOTICE '❌ CARTON TEST FAILED: Issues detected';
                RAISE NOTICE '   - Expected quantity_per_carton: 6, Got: %', inserted_carton_qty;
                RAISE NOTICE '   - Expected cartons: 5, Got: %', calculated_cartons;
            END IF;

            -- Clean up test data (with proper UUID types)
            DELETE FROM warehouse_inventory
            WHERE warehouse_id = test_warehouse_id
            AND product_id = test_product_id;

        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '⚠️ Carton test failed with error: %', SQLERRM;
            -- Try to clean up even if test failed
            BEGIN
                DELETE FROM warehouse_inventory
                WHERE warehouse_id = test_warehouse_id
                AND product_id = test_product_id;
            EXCEPTION WHEN OTHERS THEN
                -- Ignore cleanup errors
            END;
        END;
    END IF;

    RAISE NOTICE 'Migration completed successfully! ✅';
END $$;

-- Commit the transaction
COMMIT;

-- =====================================================
-- 10. Usage Examples and Documentation
-- =====================================================

/*
-- Example queries after migration:

-- 1. Get carton statistics for all warehouses
SELECT * FROM warehouse_carton_stats;

-- 2. Calculate cartons for a specific product
SELECT 
    product_id,
    quantity,
    quantity_per_carton,
    calculate_cartons(quantity, quantity_per_carton) as cartons_needed
FROM warehouse_inventory 
WHERE warehouse_id = 'your-warehouse-id';

-- 3. Update quantity per carton for a product
UPDATE warehouse_inventory 
SET quantity_per_carton = 24, updated_by = 'user-id'
WHERE warehouse_id = 'warehouse-id' AND product_id = 'product-id';

-- 4. Get total cartons for a specific warehouse
SELECT 
    w.name,
    SUM(calculate_cartons(wi.quantity, wi.quantity_per_carton)) as total_cartons
FROM warehouses w
JOIN warehouse_inventory wi ON w.id = wi.warehouse_id
WHERE w.id = 'warehouse-id'
GROUP BY w.name;
*/
