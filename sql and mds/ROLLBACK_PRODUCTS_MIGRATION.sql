-- =====================================================
-- PRODUCTS MIGRATION ROLLBACK SCRIPT
-- Rolls back the products table migration from TEXT to UUID
-- Use this ONLY if the migration needs to be reversed
-- =====================================================

-- WARNING: This script will restore the products table from backup
-- Make sure you have a valid backup before running this script

-- STEP 1: VERIFY BACKUP EXISTS
-- =====================================================

SELECT '=== ROLLBACK VERIFICATION ===' as section;

-- Check if backup table exists
SELECT 
    'Backup table check' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'products_backup'
        ) THEN 'BACKUP EXISTS ✅'
        ELSE 'NO BACKUP FOUND ❌'
    END as backup_status;

-- Show backup table structure
SELECT 
    'Backup table structure' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'products_backup'
ORDER BY ordinal_position;

-- Count records in backup
SELECT 
    'Backup record count' as info,
    COUNT(*) as record_count
FROM public.products_backup
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'products_backup' AND table_schema = 'public');

-- STEP 2: ROLLBACK EXECUTION
-- =====================================================

-- CRITICAL: Only run this if you need to rollback the migration
-- Uncomment the following DO block to execute the rollback

/*
DO $$
DECLARE
    constraint_record RECORD;
    sql_command TEXT;
BEGIN
    -- Check if backup exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'products_backup'
    ) THEN
        RAISE EXCEPTION 'ROLLBACK FAILED: No backup table found. Cannot proceed with rollback.';
    END IF;
    
    RAISE NOTICE 'Starting products table rollback from TEXT to UUID...';
    
    -- STEP 1: Drop all foreign key constraints that reference products.id
    RAISE NOTICE 'Dropping all foreign key constraints...';
    
    FOR constraint_record IN
        SELECT 
            tc.constraint_name,
            tc.table_name as referencing_table
        FROM information_schema.table_constraints AS tc 
        JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY' 
        AND ccu.table_name = 'products'
        AND ccu.column_name = 'id'
        AND tc.table_schema = 'public'
    LOOP
        BEGIN
            sql_command := format('ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I',
                constraint_record.referencing_table,
                constraint_record.constraint_name);
            EXECUTE sql_command;
            RAISE NOTICE 'Dropped constraint: % from table %', 
                constraint_record.constraint_name, 
                constraint_record.referencing_table;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Failed to drop constraint %: %', 
                    constraint_record.constraint_name, SQLERRM;
        END;
    END LOOP;
    
    -- STEP 2: Drop current products table
    RAISE NOTICE 'Dropping current products table...';
    DROP TABLE IF EXISTS public.products CASCADE;
    
    -- STEP 3: Restore from backup
    RAISE NOTICE 'Restoring products table from backup...';
    CREATE TABLE public.products AS SELECT * FROM public.products_backup;
    
    -- STEP 4: Recreate primary key constraint
    ALTER TABLE public.products ADD PRIMARY KEY (id);
    
    -- STEP 5: Convert referencing columns back to UUID
    RAISE NOTICE 'Converting referencing columns back to UUID...';
    
    -- Convert favorites.product_id back to UUID
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'favorites' AND table_schema = 'public') THEN
        BEGIN
            ALTER TABLE public.favorites ALTER COLUMN product_id TYPE UUID USING product_id::UUID;
            RAISE NOTICE 'Converted favorites.product_id back to UUID';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Failed to convert favorites.product_id: %', SQLERRM;
        END;
    END IF;
    
    -- Convert order_items.product_id back to UUID
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_items' AND table_schema = 'public') THEN
        BEGIN
            ALTER TABLE public.order_items ALTER COLUMN product_id TYPE UUID USING product_id::UUID;
            RAISE NOTICE 'Converted order_items.product_id back to UUID';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Failed to convert order_items.product_id: %', SQLERRM;
        END;
    END IF;
    
    -- Convert client_order_items.product_id back to UUID (if it was UUID before)
    -- Note: client_order_items might have been TEXT originally, so check first
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'client_order_items'
        AND column_name = 'product_id'
        AND data_type = 'text'
    ) THEN
        RAISE NOTICE 'client_order_items.product_id is TEXT - checking if it should be converted to UUID';
        -- Only convert if the backup shows it should be UUID
        -- This is a judgment call based on your original schema
    END IF;
    
    -- STEP 6: Recreate foreign key constraints
    RAISE NOTICE 'Recreating foreign key constraints...';
    
    -- Recreate favorites foreign key
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'favorites' AND table_schema = 'public') THEN
        BEGIN
            ALTER TABLE public.favorites 
            ADD CONSTRAINT favorites_product_id_fkey 
            FOREIGN KEY (product_id) REFERENCES public.products(id);
            RAISE NOTICE 'Recreated favorites_product_id_fkey constraint';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Failed to recreate favorites constraint: %', SQLERRM;
        END;
    END IF;
    
    -- Recreate order_items foreign key
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_items' AND table_schema = 'public') THEN
        BEGIN
            ALTER TABLE public.order_items 
            ADD CONSTRAINT order_items_product_id_fkey 
            FOREIGN KEY (product_id) REFERENCES public.products(id);
            RAISE NOTICE 'Recreated order_items_product_id_fkey constraint';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Failed to recreate order_items constraint: %', SQLERRM;
        END;
    END IF;
    
    -- Note: client_order_items might not need a foreign key if it was designed for external products
    
    -- STEP 7: Enable RLS if it was enabled before
    ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
    
    RAISE NOTICE 'Products table rollback completed successfully';
    RAISE NOTICE 'Backup table products_backup is still available for reference';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'ROLLBACK FAILED: %. Manual intervention may be required.', SQLERRM;
END $$;
*/

-- STEP 3: POST-ROLLBACK VERIFICATION
-- =====================================================

-- Verify rollback was successful
SELECT 
    'Post-rollback products table structure' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'products'
ORDER BY ordinal_position;

-- Verify foreign key constraints are restored
SELECT 
    '=== RESTORED FOREIGN KEY CONSTRAINTS ===' as verification_section,
    tc.constraint_name,
    tc.table_name as referencing_table,
    kcu.column_name as referencing_column,
    ccu.table_name as referenced_table,
    ccu.column_name as referenced_column
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND ccu.table_name = 'products'
AND ccu.column_name = 'id'
AND tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_name;

-- Final rollback verification
SELECT 
    'ROLLBACK VERIFICATION COMPLETE' as status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'products'
            AND column_name = 'id'
            AND data_type = 'uuid'
        ) THEN 'SUCCESS: Products table restored to UUID ID'
        ELSE 'WARNING: Products table is not using UUID ID'
    END as rollback_status;

-- CLEANUP INSTRUCTIONS
-- =====================================================

SELECT '=== CLEANUP INSTRUCTIONS ===' as section;

SELECT 
    'After successful rollback, you can optionally clean up:' as instruction,
    'DROP TABLE IF EXISTS public.products_backup;' as cleanup_command;
