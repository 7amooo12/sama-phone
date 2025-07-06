-- =====================================================
-- PRODUCTS MIGRATION VERIFICATION SCRIPT
-- Verifies the comprehensive products table migration
-- Checks all foreign key constraints and data integrity
-- =====================================================

-- STEP 1: PRE-MIGRATION ANALYSIS
-- =====================================================

SELECT '=== PRE-MIGRATION ANALYSIS ===' as section;

-- Check current products table structure
SELECT 
    'Current products table structure' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'products'
ORDER BY ordinal_position;

-- Identify ALL foreign key constraints referencing products.id
SELECT 
    '=== ALL FOREIGN KEY CONSTRAINTS REFERENCING PRODUCTS ===' as analysis_section,
    tc.constraint_name,
    tc.table_name as referencing_table,
    kcu.column_name as referencing_column,
    ccu.table_name as referenced_table,
    ccu.column_name as referenced_column,
    tc.constraint_type
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

-- Check data types of all product_id columns
SELECT 
    '=== PRODUCT_ID COLUMN TYPES ACROSS DATABASE ===' as analysis_section,
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND column_name LIKE '%product_id%'
ORDER BY table_name, column_name;

-- Count existing data in related tables
SELECT
    '=== DATA COUNT IN RELATED TABLES ===' as data_analysis,
    'products' as table_name,
    COUNT(*) as record_count
FROM public.products
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'products' AND table_schema = 'public')

UNION ALL

SELECT
    '=== DATA COUNT IN RELATED TABLES ===' as data_analysis,
    'favorites' as table_name,
    COUNT(*) as record_count
FROM public.favorites
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'favorites' AND table_schema = 'public')

UNION ALL

SELECT
    '=== DATA COUNT IN RELATED TABLES ===' as data_analysis,
    'order_items' as table_name,
    COUNT(*) as record_count
FROM public.order_items
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_items' AND table_schema = 'public')

UNION ALL

SELECT
    '=== DATA COUNT IN RELATED TABLES ===' as data_analysis,
    'client_order_items' as table_name,
    COUNT(*) as record_count
FROM public.client_order_items
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'client_order_items' AND table_schema = 'public');

-- STEP 2: MIGRATION READINESS CHECK
-- =====================================================

-- Check for potential data issues that could cause migration problems
DO $$
DECLARE
    products_count INTEGER := 0;
    favorites_count INTEGER := 0;
    order_items_count INTEGER := 0;
    client_order_items_count INTEGER := 0;
    orphaned_favorites INTEGER := 0;
    orphaned_order_items INTEGER := 0;
    orphaned_client_order_items INTEGER := 0;
BEGIN
    RAISE NOTICE '=== MIGRATION READINESS CHECK ===';

    -- Get table counts with existence checks
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'products' AND table_schema = 'public') THEN
        SELECT COUNT(*) INTO products_count FROM public.products;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'favorites' AND table_schema = 'public') THEN
        SELECT COUNT(*) INTO favorites_count FROM public.favorites;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_items' AND table_schema = 'public') THEN
        SELECT COUNT(*) INTO order_items_count FROM public.order_items;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'client_order_items' AND table_schema = 'public') THEN
        SELECT COUNT(*) INTO client_order_items_count FROM public.client_order_items;
    END IF;
    
    RAISE NOTICE 'Table counts - Products: %, Favorites: %, Order Items: %, Client Order Items: %', 
        products_count, favorites_count, order_items_count, client_order_items_count;
    
    -- Check for orphaned records in favorites (with type-safe comparison)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'favorites' AND table_schema = 'public') THEN
        BEGIN
            -- Try TEXT comparison first (post-migration scenario)
            SELECT COUNT(*) INTO orphaned_favorites
            FROM public.favorites f
            WHERE NOT EXISTS (
                SELECT 1 FROM public.products p
                WHERE p.id = f.product_id::text
            );
        EXCEPTION
            WHEN OTHERS THEN
                BEGIN
                    -- Fallback to UUID comparison (pre-migration scenario)
                    SELECT COUNT(*) INTO orphaned_favorites
                    FROM public.favorites f
                    WHERE NOT EXISTS (
                        SELECT 1 FROM public.products p
                        WHERE p.id::uuid = f.product_id
                    );
                EXCEPTION
                    WHEN OTHERS THEN
                        -- If both fail, try direct comparison (same types)
                        SELECT COUNT(*) INTO orphaned_favorites
                        FROM public.favorites f
                        WHERE NOT EXISTS (
                            SELECT 1 FROM public.products p
                            WHERE p.id = f.product_id
                        );
                END;
        END;

        IF orphaned_favorites > 0 THEN
            RAISE WARNING 'Found % orphaned records in favorites table', orphaned_favorites;
        END IF;
    END IF;

    -- Check for orphaned records in order_items (with type-safe comparison)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_items' AND table_schema = 'public') THEN
        BEGIN
            -- Try TEXT comparison first (post-migration scenario)
            SELECT COUNT(*) INTO orphaned_order_items
            FROM public.order_items oi
            WHERE NOT EXISTS (
                SELECT 1 FROM public.products p
                WHERE p.id = oi.product_id::text
            );
        EXCEPTION
            WHEN OTHERS THEN
                BEGIN
                    -- Fallback to UUID comparison (pre-migration scenario)
                    SELECT COUNT(*) INTO orphaned_order_items
                    FROM public.order_items oi
                    WHERE NOT EXISTS (
                        SELECT 1 FROM public.products p
                        WHERE p.id::uuid = oi.product_id
                    );
                EXCEPTION
                    WHEN OTHERS THEN
                        -- If both fail, try direct comparison (same types)
                        SELECT COUNT(*) INTO orphaned_order_items
                        FROM public.order_items oi
                        WHERE NOT EXISTS (
                            SELECT 1 FROM public.products p
                            WHERE p.id = oi.product_id
                        );
                END;
        END;

        IF orphaned_order_items > 0 THEN
            RAISE WARNING 'Found % orphaned records in order_items table', orphaned_order_items;
        END IF;
    END IF;

    -- Check for orphaned records in client_order_items (with type-safe comparison)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'client_order_items' AND table_schema = 'public') THEN
        BEGIN
            -- Try TEXT comparison first (post-migration scenario)
            SELECT COUNT(*) INTO orphaned_client_order_items
            FROM public.client_order_items coi
            WHERE NOT EXISTS (
                SELECT 1 FROM public.products p
                WHERE p.id = coi.product_id::text
            );
        EXCEPTION
            WHEN OTHERS THEN
                BEGIN
                    -- Fallback to UUID comparison (pre-migration scenario)
                    SELECT COUNT(*) INTO orphaned_client_order_items
                    FROM public.client_order_items coi
                    WHERE NOT EXISTS (
                        SELECT 1 FROM public.products p
                        WHERE p.id::uuid = coi.product_id
                    );
                EXCEPTION
                    WHEN OTHERS THEN
                        -- If both fail, try direct comparison (same types)
                        SELECT COUNT(*) INTO orphaned_client_order_items
                        FROM public.client_order_items coi
                        WHERE NOT EXISTS (
                            SELECT 1 FROM public.products p
                            WHERE p.id = coi.product_id
                        );
                END;
        END;

        IF orphaned_client_order_items > 0 THEN
            RAISE WARNING 'Found % orphaned records in client_order_items table', orphaned_client_order_items;
        END IF;
    END IF;
    
    IF orphaned_favorites = 0 AND orphaned_order_items = 0 AND orphaned_client_order_items = 0 THEN
        RAISE NOTICE 'SUCCESS: No orphaned records found. Migration should proceed safely.';
    ELSE
        RAISE WARNING 'WARNING: Found orphaned records. Consider cleaning up before migration.';
    END IF;
END $$;

-- STEP 3: POST-MIGRATION VERIFICATION
-- =====================================================

-- This section should be run AFTER the migration script

SELECT '=== POST-MIGRATION VERIFICATION ===' as section;

-- Verify products table structure after migration
SELECT 
    'Post-migration products table structure' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'products'
AND column_name IN ('id', 'image_url', 'main_image_url', 'image_urls', 'source', 'external_id')
ORDER BY column_name;

-- Verify all foreign key constraints are recreated
SELECT 
    '=== RECREATED FOREIGN KEY CONSTRAINTS ===' as verification_section,
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

-- Test external API product insertion
DO $$
BEGIN
    -- Test inserting a product with text ID
    INSERT INTO public.products (
        id, name, description, price, image_url, main_image_url, 
        source, external_id, created_at
    ) VALUES (
        'test-external-172',
        'Test External Product',
        'Test product for verification',
        99.99,
        'https://example.com/test-product.jpg',
        'https://example.com/test-product.jpg',
        'external_api',
        '172',
        NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        updated_at = NOW();
    
    RAISE NOTICE 'SUCCESS: External API product insertion works';
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'ERROR: External API product insertion failed - %', SQLERRM;
END $$;

-- Test querying with text ID (the original problem)
DO $$
DECLARE
    test_image_url TEXT;
    test_image_urls JSONB;
BEGIN
    -- This was the failing query
    SELECT main_image_url, image_urls 
    INTO test_image_url, test_image_urls
    FROM public.products 
    WHERE id = 'test-external-172';
    
    RAISE NOTICE 'SUCCESS: Query with text ID works. Image URL: %, Image URLs: %', 
        test_image_url, test_image_urls;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'ERROR: Query with text ID still failing - %', SQLERRM;
END $$;

-- Final verification message
SELECT 
    'MIGRATION VERIFICATION COMPLETE' as status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'products'
            AND column_name = 'id'
            AND data_type = 'text'
        ) THEN 'SUCCESS: Products table migrated to TEXT ID'
        ELSE 'WARNING: Products table still uses UUID ID'
    END as products_migration_status,
    (
        SELECT COUNT(*)
        FROM information_schema.table_constraints AS tc 
        JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY' 
        AND ccu.table_name = 'products'
        AND ccu.column_name = 'id'
        AND tc.table_schema = 'public'
    ) as foreign_key_constraints_count;
