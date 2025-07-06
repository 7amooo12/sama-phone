-- =====================================================
-- Carton/Box Tracking Enhancement Migration Script (Simplified)
-- =====================================================
-- This is a simplified version that focuses on core functionality
-- Date: 2025-06-15
-- Version: 1.1 (Simplified)

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
-- 2. Create performance indexes
-- =====================================================

-- Create index on quantity_per_carton for efficient carton calculations
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_quantity_per_carton 
ON warehouse_inventory(quantity_per_carton);

-- Create composite index for warehouse-specific carton calculations
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_carton_calc 
ON warehouse_inventory(warehouse_id, quantity, quantity_per_carton);

-- =====================================================
-- 3. Update existing records with default carton values
-- =====================================================

-- Set default quantity_per_carton for existing records
-- This provides reasonable defaults for existing inventory
UPDATE warehouse_inventory 
SET quantity_per_carton = 1
WHERE quantity_per_carton IS NULL OR quantity_per_carton = 0;

-- =====================================================
-- 4. Create helper function for carton calculations
-- =====================================================

-- Drop function if exists to ensure clean recreation
DROP FUNCTION IF EXISTS calculate_cartons(integer, integer);

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

-- =====================================================
-- 5. Grant necessary permissions
-- =====================================================

-- Grant permissions to authenticated users for the new function
GRANT EXECUTE ON FUNCTION calculate_cartons(integer, integer) TO authenticated;

-- =====================================================
-- 6. Verification
-- =====================================================

-- Verify the migration was successful
DO $$
DECLARE
    column_exists BOOLEAN;
    function_exists BOOLEAN;
BEGIN
    -- Check column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_inventory' 
        AND column_name = 'quantity_per_carton'
    ) INTO column_exists;
    
    -- Check function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'calculate_cartons'
    ) INTO function_exists;
    
    -- Report results
    RAISE NOTICE 'Migration Verification Results:';
    RAISE NOTICE '- Column quantity_per_carton exists: %', column_exists;
    RAISE NOTICE '- calculate_cartons function exists: %', function_exists;
    
    -- Ensure all components were created successfully
    IF NOT (column_exists AND function_exists) THEN
        RAISE EXCEPTION 'Migration verification failed. Please check the logs above.';
    END IF;
    
    RAISE NOTICE 'Simplified migration completed successfully! ✅';
END $$;

-- Commit the transaction
COMMIT;

-- =====================================================
-- Usage Examples
-- =====================================================

/*
-- Example queries after migration:

-- 1. Calculate cartons for a specific product
SELECT 
    product_id,
    quantity,
    quantity_per_carton,
    calculate_cartons(quantity, quantity_per_carton) as cartons_needed
FROM warehouse_inventory 
WHERE warehouse_id = 'your-warehouse-id';

-- 2. Update quantity per carton for a product
UPDATE warehouse_inventory 
SET quantity_per_carton = 24, updated_by = 'user-id'
WHERE warehouse_id = 'warehouse-id' AND product_id = 'product-id';

-- 3. Get total cartons for a specific warehouse
SELECT 
    w.name,
    SUM(calculate_cartons(wi.quantity, wi.quantity_per_carton)) as total_cartons
FROM warehouses w
JOIN warehouse_inventory wi ON w.id = wi.warehouse_id
WHERE w.id = 'warehouse-id'
GROUP BY w.name;
*/
