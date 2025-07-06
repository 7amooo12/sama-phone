-- =====================================================
-- Carton Tracking Migration - Final Clean Version
-- =====================================================
-- This script adds carton tracking functionality with proper syntax
-- Date: 2025-06-15
-- Version: 1.3 (Final)

-- Begin transaction
BEGIN;

-- =====================================================
-- 1. Add quantity_per_carton column
-- =====================================================

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_inventory' 
        AND column_name = 'quantity_per_carton'
    ) THEN
        ALTER TABLE warehouse_inventory 
        ADD COLUMN quantity_per_carton INTEGER NOT NULL DEFAULT 1;
        
        ALTER TABLE warehouse_inventory 
        ADD CONSTRAINT chk_quantity_per_carton_positive 
        CHECK (quantity_per_carton > 0);
        
        RAISE NOTICE 'Added quantity_per_carton column';
    ELSE
        RAISE NOTICE 'Column quantity_per_carton already exists';
    END IF;
END $$;

-- =====================================================
-- 2. Create indexes
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_quantity_per_carton 
ON warehouse_inventory(quantity_per_carton);

CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_carton_calc 
ON warehouse_inventory(warehouse_id, quantity, quantity_per_carton);

DO $$
BEGIN
    RAISE NOTICE 'Created performance indexes';
END $$;

-- =====================================================
-- 3. Update existing records
-- =====================================================

UPDATE warehouse_inventory 
SET quantity_per_carton = 1
WHERE quantity_per_carton IS NULL OR quantity_per_carton = 0;

DO $$
BEGIN
    RAISE NOTICE 'Updated existing records with default values';
END $$;

-- =====================================================
-- 4. Create calculation function
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_cartons(
    total_quantity INTEGER,
    quantity_per_carton INTEGER
) RETURNS INTEGER AS $$
BEGIN
    IF total_quantity IS NULL OR total_quantity <= 0 THEN
        RETURN 0;
    END IF;
    
    IF quantity_per_carton IS NULL OR quantity_per_carton <= 0 THEN
        RETURN total_quantity;
    END IF;
    
    RETURN CEIL(total_quantity::DECIMAL / quantity_per_carton::DECIMAL)::INTEGER;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION calculate_cartons(integer, integer) TO authenticated;

DO $$
BEGIN
    RAISE NOTICE 'Created calculate_cartons function';
END $$;

-- =====================================================
-- 5. Create statistics view
-- =====================================================

DROP VIEW IF EXISTS warehouse_carton_stats;

CREATE VIEW warehouse_carton_stats AS
SELECT 
    w.id as warehouse_id,
    w.name as warehouse_name,
    w.address as warehouse_address,
    COUNT(wi.id) as total_products,
    COALESCE(SUM(wi.quantity), 0) as total_quantity,
    COALESCE(SUM(calculate_cartons(wi.quantity, wi.quantity_per_carton)), 0) as total_cartons,
    COALESCE(AVG(wi.quantity_per_carton), 0) as avg_quantity_per_carton
FROM warehouses w
LEFT JOIN warehouse_inventory wi ON w.id = wi.warehouse_id
GROUP BY w.id, w.name, w.address
ORDER BY w.name;

GRANT SELECT ON warehouse_carton_stats TO authenticated;

DO $$
BEGIN
    RAISE NOTICE 'Created warehouse_carton_stats view';
END $$;

-- =====================================================
-- 6. Test functionality
-- =====================================================

DO $$
DECLARE
    test_warehouse_id UUID;
    test_product_id UUID;
    test_result INTEGER;
BEGIN
    -- Test the function
    SELECT calculate_cartons(25, 6) INTO test_result;
    
    IF test_result = 5 THEN
        RAISE NOTICE '✅ Function test passed: 25 items / 6 per carton = % cartons', test_result;
    ELSE
        RAISE NOTICE '❌ Function test failed: expected 5, got %', test_result;
    END IF;
    
    -- Test database operations with UUIDs
    test_warehouse_id := gen_random_uuid();
    test_product_id := gen_random_uuid();
    
    BEGIN
        INSERT INTO warehouse_inventory (
            warehouse_id,
            product_id,
            quantity,
            quantity_per_carton,
            updated_by
        ) VALUES (
            test_warehouse_id,
            test_product_id,
            30,
            8,
            'test-user'
        );
        
        -- Verify insertion
        IF EXISTS (
            SELECT 1 FROM warehouse_inventory 
            WHERE warehouse_id = test_warehouse_id 
            AND product_id = test_product_id
            AND quantity_per_carton = 8
        ) THEN
            RAISE NOTICE '✅ Database test passed: Record inserted correctly';
        ELSE
            RAISE NOTICE '❌ Database test failed: Record not found or incorrect';
        END IF;
        
        -- Cleanup
        DELETE FROM warehouse_inventory 
        WHERE warehouse_id = test_warehouse_id 
        AND product_id = test_product_id;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Database test failed: %', SQLERRM;
        -- Try cleanup
        BEGIN
            DELETE FROM warehouse_inventory 
            WHERE warehouse_id = test_warehouse_id 
            AND product_id = test_product_id;
        EXCEPTION WHEN OTHERS THEN
            -- Ignore cleanup errors
        END;
    END;
END $$;

-- =====================================================
-- 7. Final verification
-- =====================================================

DO $$
DECLARE
    column_exists BOOLEAN;
    function_exists BOOLEAN;
    view_exists BOOLEAN;
    total_records INTEGER;
    records_with_cartons INTEGER;
BEGIN
    -- Check components
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
    
    -- Check data
    SELECT COUNT(*) INTO total_records FROM warehouse_inventory;
    SELECT COUNT(*) INTO records_with_cartons 
    FROM warehouse_inventory 
    WHERE quantity_per_carton IS NOT NULL AND quantity_per_carton > 0;
    
    -- Report results
    RAISE NOTICE '📊 FINAL VERIFICATION:';
    RAISE NOTICE '- Column exists: %', column_exists;
    RAISE NOTICE '- Function exists: %', function_exists;
    RAISE NOTICE '- View exists: %', view_exists;
    RAISE NOTICE '- Total inventory records: %', total_records;
    RAISE NOTICE '- Records with carton data: %', records_with_cartons;
    
    IF column_exists AND function_exists AND view_exists THEN
        RAISE NOTICE '🎉 MIGRATION COMPLETED SUCCESSFULLY!';
    ELSE
        RAISE EXCEPTION 'Migration failed - missing components';
    END IF;
END $$;

-- Commit transaction
COMMIT;
