-- ============================================================================
-- FIX COLUMN NAMES CONSISTENCY
-- ============================================================================
-- This script standardizes column names across all tables to fix the
-- is_active vs active inconsistency that's causing debugging errors

-- 1. Check current column names in all relevant tables
DO $$
BEGIN
    RAISE NOTICE '🔍 Checking current column names...';
    
    -- Check products table
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'products' AND table_schema = 'public') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'active' AND table_schema = 'public') THEN
            RAISE NOTICE '✅ products table uses "active" column';
        ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'is_active' AND table_schema = 'public') THEN
            RAISE NOTICE '⚠️ products table uses "is_active" column - needs standardization';
        ELSE
            RAISE NOTICE '❌ products table has no active/is_active column';
        END IF;
    ELSE
        RAISE NOTICE '❌ products table does not exist';
    END IF;
    
    -- Check warehouses table
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouses' AND table_schema = 'public') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'is_active' AND table_schema = 'public') THEN
            RAISE NOTICE '✅ warehouses table uses "is_active" column';
        ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'active' AND table_schema = 'public') THEN
            RAISE NOTICE '⚠️ warehouses table uses "active" column - needs standardization';
        ELSE
            RAISE NOTICE '❌ warehouses table has no active/is_active column';
        END IF;
    ELSE
        RAISE NOTICE '❌ warehouses table does not exist';
    END IF;
END $$;

-- 2. Standardize products table to use "active" column
DO $$
BEGIN
    RAISE NOTICE '🔧 Standardizing products table...';
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'products' AND table_schema = 'public') THEN
        -- If products table has is_active, rename it to active
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'is_active' AND table_schema = 'public') THEN
            -- Check if active column already exists
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'active' AND table_schema = 'public') THEN
                -- Both columns exist - copy data and drop is_active
                UPDATE products SET active = is_active WHERE active IS NULL;
                ALTER TABLE products DROP COLUMN is_active;
                RAISE NOTICE '✅ Merged is_active into active column and dropped is_active';
            ELSE
                -- Only is_active exists - rename it
                ALTER TABLE products RENAME COLUMN is_active TO active;
                RAISE NOTICE '✅ Renamed is_active to active in products table';
            END IF;
        ELSIF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'active' AND table_schema = 'public') THEN
            -- No active column exists - create it
            ALTER TABLE products ADD COLUMN active BOOLEAN DEFAULT true;
            RAISE NOTICE '✅ Added active column to products table';
        ELSE
            RAISE NOTICE 'ℹ️ products table already has active column';
        END IF;
    END IF;
END $$;

-- 3. Standardize warehouses table to use "is_active" column
DO $$
BEGIN
    RAISE NOTICE '🔧 Standardizing warehouses table...';
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouses' AND table_schema = 'public') THEN
        -- If warehouses table has active, rename it to is_active
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'active' AND table_schema = 'public') THEN
            -- Check if is_active column already exists
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'is_active' AND table_schema = 'public') THEN
                -- Both columns exist - copy data and drop active
                UPDATE warehouses SET is_active = active WHERE is_active IS NULL;
                ALTER TABLE warehouses DROP COLUMN active;
                RAISE NOTICE '✅ Merged active into is_active column and dropped active';
            ELSE
                -- Only active exists - rename it
                ALTER TABLE warehouses RENAME COLUMN active TO is_active;
                RAISE NOTICE '✅ Renamed active to is_active in warehouses table';
            END IF;
        ELSIF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'is_active' AND table_schema = 'public') THEN
            -- No is_active column exists - create it
            ALTER TABLE warehouses ADD COLUMN is_active BOOLEAN DEFAULT true;
            RAISE NOTICE '✅ Added is_active column to warehouses table';
        ELSE
            RAISE NOTICE 'ℹ️ warehouses table already has is_active column';
        END IF;
    END IF;
END $$;

-- 4. Update any other tables to follow the standard
DO $$
DECLARE
    table_record RECORD;
BEGIN
    RAISE NOTICE '🔧 Checking other tables for consistency...';
    
    -- Check all tables that might have active/is_active columns
    FOR table_record IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_type = 'BASE TABLE'
        AND table_name NOT IN ('products', 'warehouses')
    LOOP
        -- Check if table has both active and is_active columns
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = table_record.table_name 
            AND column_name = 'active' 
            AND table_schema = 'public'
        ) AND EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = table_record.table_name 
            AND column_name = 'is_active' 
            AND table_schema = 'public'
        ) THEN
            RAISE NOTICE '⚠️ Table % has both active and is_active columns', table_record.table_name;
        END IF;
    END LOOP;
END $$;

-- 5. Verify the final state
SELECT 
    'FINAL_VERIFICATION' as test_type,
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name IN ('products', 'warehouses')
AND column_name IN ('active', 'is_active')
ORDER BY table_name, column_name;

-- 6. Test the standardized columns
DO $$
DECLARE
    products_count INTEGER := 0;
    warehouses_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🧪 Testing standardized columns...';
    
    -- Test products.active
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'products' AND table_schema = 'public') THEN
        SELECT COUNT(*) INTO products_count FROM products WHERE active = true;
        RAISE NOTICE '✅ products.active query works: % active products', products_count;
    END IF;
    
    -- Test warehouses.is_active
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouses' AND table_schema = 'public') THEN
        SELECT COUNT(*) INTO warehouses_count FROM warehouses WHERE is_active = true;
        RAISE NOTICE '✅ warehouses.is_active query works: % active warehouses', warehouses_count;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error testing columns: %', SQLERRM;
END $$;

-- 7. Summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================== COLUMN STANDARDIZATION COMPLETE ====================';
    RAISE NOTICE 'Column naming standards applied:';
    RAISE NOTICE '• products table: uses "active" column';
    RAISE NOTICE '• warehouses table: uses "is_active" column';
    RAISE NOTICE '• Other tables: checked for consistency';
    RAISE NOTICE '';
    RAISE NOTICE 'Update your queries to use:';
    RAISE NOTICE '• SELECT * FROM products WHERE active = true';
    RAISE NOTICE '• SELECT * FROM warehouses WHERE is_active = true';
    RAISE NOTICE '';
    RAISE NOTICE 'The debug scripts should now work without column name errors.';
    RAISE NOTICE '================================================================';
END $$;
