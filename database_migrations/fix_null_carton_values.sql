-- =====================================================
-- Fix NULL quantity_per_carton Values
-- =====================================================
-- This script fixes any existing records with NULL quantity_per_carton values

BEGIN;

-- 1. Check current state
DO $$
DECLARE
    total_records INTEGER;
    null_records INTEGER;
    zero_records INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_records FROM warehouse_inventory;
    SELECT COUNT(*) INTO null_records FROM warehouse_inventory WHERE quantity_per_carton IS NULL;
    SELECT COUNT(*) INTO zero_records FROM warehouse_inventory WHERE quantity_per_carton = 0;
    
    RAISE NOTICE 'Current state:';
    RAISE NOTICE '- Total records: %', total_records;
    RAISE NOTICE '- NULL quantity_per_carton: %', null_records;
    RAISE NOTICE '- Zero quantity_per_carton: %', zero_records;
END $$;

-- 2. Update NULL values to 1
UPDATE warehouse_inventory 
SET quantity_per_carton = 1 
WHERE quantity_per_carton IS NULL;

-- 3. Update zero values to 1
UPDATE warehouse_inventory 
SET quantity_per_carton = 1 
WHERE quantity_per_carton = 0;

-- 4. Ensure the column has a NOT NULL constraint and default value
ALTER TABLE warehouse_inventory 
ALTER COLUMN quantity_per_carton SET NOT NULL;

ALTER TABLE warehouse_inventory 
ALTER COLUMN quantity_per_carton SET DEFAULT 1;

-- 5. Add check constraint if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'warehouse_inventory' 
        AND constraint_name = 'chk_quantity_per_carton_positive'
    ) THEN
        ALTER TABLE warehouse_inventory 
        ADD CONSTRAINT chk_quantity_per_carton_positive 
        CHECK (quantity_per_carton > 0);
        
        RAISE NOTICE 'Added check constraint for quantity_per_carton';
    ELSE
        RAISE NOTICE 'Check constraint already exists';
    END IF;
END $$;

-- 6. Verify the fix
DO $$
DECLARE
    total_records INTEGER;
    null_records INTEGER;
    zero_records INTEGER;
    min_carton INTEGER;
    max_carton INTEGER;
    avg_carton NUMERIC;
BEGIN
    SELECT 
        COUNT(*),
        COUNT(CASE WHEN quantity_per_carton IS NULL THEN 1 END),
        COUNT(CASE WHEN quantity_per_carton = 0 THEN 1 END),
        MIN(quantity_per_carton),
        MAX(quantity_per_carton),
        AVG(quantity_per_carton)
    INTO total_records, null_records, zero_records, min_carton, max_carton, avg_carton
    FROM warehouse_inventory;
    
    RAISE NOTICE 'After fix:';
    RAISE NOTICE '- Total records: %', total_records;
    RAISE NOTICE '- NULL quantity_per_carton: %', null_records;
    RAISE NOTICE '- Zero quantity_per_carton: %', zero_records;
    RAISE NOTICE '- Min quantity_per_carton: %', min_carton;
    RAISE NOTICE '- Max quantity_per_carton: %', max_carton;
    RAISE NOTICE '- Avg quantity_per_carton: %', ROUND(avg_carton, 2);
    
    IF null_records = 0 AND zero_records = 0 THEN
        RAISE NOTICE '✅ All records now have valid quantity_per_carton values';
    ELSE
        RAISE NOTICE '❌ Some records still have invalid values';
    END IF;
END $$;

-- 7. Show sample of fixed records
SELECT 
    'Sample Records' as info,
    id,
    product_id,
    quantity,
    quantity_per_carton,
    CEIL(quantity::DECIMAL / quantity_per_carton::DECIMAL) as calculated_cartons
FROM warehouse_inventory 
LIMIT 5;

COMMIT;

RAISE NOTICE '🎉 Fix completed successfully!';
