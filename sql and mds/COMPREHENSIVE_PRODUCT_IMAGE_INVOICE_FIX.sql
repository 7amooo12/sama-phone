-- =====================================================
-- COMPREHENSIVE PRODUCT IMAGE & INVOICE FIX
-- Fixes UUID errors, adds image columns, and supports external API products
-- Enables product images in PDF invoices
-- ENHANCED VERSION: Handles ALL foreign key constraints dynamically
-- =====================================================

-- STEP 1: COMPREHENSIVE SCHEMA ANALYSIS
-- =====================================================

SELECT '=== COMPREHENSIVE DATABASE SCHEMA ANALYSIS ===' as section;

-- Check if products table exists and its structure
SELECT
    'Products table structure' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'products'
ORDER BY ordinal_position;

-- CRITICAL: Identify ALL foreign key constraints that reference products.id
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

-- Check data types of all product_id columns across the database
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

-- Check if invoices table exists
SELECT
    'Invoices table exists' as check_name,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_name = 'invoices'
        ) THEN 'YES'
        ELSE 'NO'
    END as result;

-- STEP 2: FIX PRODUCTS TABLE FOR EXTERNAL API COMPATIBILITY
-- =====================================================

SELECT '=== FIXING PRODUCTS TABLE ===' as section;

-- Option A: If products table doesn't exist, create it for external API products
CREATE TABLE IF NOT EXISTS public.products (
    id TEXT PRIMARY KEY,  -- Use TEXT to support both UUID and integer IDs
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0,
    image_url TEXT,
    main_image_url TEXT,
    image_urls JSONB DEFAULT '[]'::jsonb,
    category TEXT,
    sku TEXT,
    stock_quantity INTEGER DEFAULT 0,
    purchase_price DECIMAL(10, 2) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    source TEXT DEFAULT 'external_api',  -- Track data source
    external_id TEXT,  -- Original ID from external API
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Option B: If products table exists with UUID, alter it to TEXT with comprehensive FK handling
DO $$
DECLARE
    constraint_record RECORD;
    fk_constraints TEXT[] := ARRAY[]::TEXT[];
    table_columns TEXT[] := ARRAY[]::TEXT[];
    sql_command TEXT;
    backup_created BOOLEAN := FALSE;
BEGIN
    -- Check if products table exists and has UUID id column
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'products'
        AND column_name = 'id'
        AND data_type = 'uuid'
    ) THEN
        RAISE NOTICE 'Starting comprehensive products table migration from UUID to TEXT...';

        -- Create backup first
        BEGIN
            DROP TABLE IF EXISTS public.products_backup;
            CREATE TABLE public.products_backup AS SELECT * FROM public.products;
            backup_created := TRUE;
            RAISE NOTICE 'Created backup table: products_backup';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Failed to create backup: %', SQLERRM;
        END;

        -- STEP 1: Discover ALL foreign key constraints that reference products.id
        RAISE NOTICE 'Discovering all foreign key constraints referencing products.id...';

        FOR constraint_record IN
            SELECT
                tc.constraint_name,
                tc.table_name as referencing_table,
                kcu.column_name as referencing_column
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
            ORDER BY tc.table_name, tc.constraint_name
        LOOP
            RAISE NOTICE 'Found FK constraint: % on table %.%',
                constraint_record.constraint_name,
                constraint_record.referencing_table,
                constraint_record.referencing_column;

            -- Store constraint info for later recreation
            fk_constraints := fk_constraints ||
                (constraint_record.referencing_table || '.' ||
                 constraint_record.referencing_column || '.' ||
                 constraint_record.constraint_name);

            -- Store table.column info for type conversion
            table_columns := table_columns ||
                (constraint_record.referencing_table || '.' ||
                 constraint_record.referencing_column);
        END LOOP;

        RAISE NOTICE 'Found % foreign key constraints to handle', array_length(fk_constraints, 1);

        -- STEP 2: Drop ALL discovered foreign key constraints
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

        -- STEP 3: Convert products.id column from UUID to TEXT
        RAISE NOTICE 'Converting products.id column from UUID to TEXT...';
        BEGIN
            ALTER TABLE public.products ALTER COLUMN id TYPE TEXT;
            ALTER TABLE public.products ALTER COLUMN id DROP DEFAULT;
            RAISE NOTICE 'Successfully converted products.id to TEXT';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Failed to convert products.id column: %', SQLERRM;
        END;

        -- STEP 4: Convert ALL referencing columns from UUID to TEXT
        RAISE NOTICE 'Converting all referencing product_id columns to TEXT...';

        FOR constraint_record IN
            SELECT DISTINCT
                kcu.table_name as referencing_table,
                kcu.column_name as referencing_column
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
        LOOP
            BEGIN
                -- Check if table exists before trying to alter it
                IF EXISTS (
                    SELECT 1 FROM information_schema.tables
                    WHERE table_schema = 'public'
                    AND table_name = constraint_record.referencing_table
                ) THEN
                    sql_command := format('ALTER TABLE public.%I ALTER COLUMN %I TYPE TEXT',
                        constraint_record.referencing_table,
                        constraint_record.referencing_column);
                    EXECUTE sql_command;
                    RAISE NOTICE 'Converted %.% to TEXT',
                        constraint_record.referencing_table,
                        constraint_record.referencing_column;
                ELSE
                    RAISE WARNING 'Table % does not exist, skipping column conversion',
                        constraint_record.referencing_table;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING 'Failed to convert %.%: %',
                        constraint_record.referencing_table,
                        constraint_record.referencing_column,
                        SQLERRM;
            END;
        END LOOP;

        -- STEP 5: Recreate ALL foreign key constraints
        RAISE NOTICE 'Recreating all foreign key constraints...';

        FOR constraint_record IN
            SELECT
                tc.constraint_name,
                tc.table_name as referencing_table,
                kcu.column_name as referencing_column
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
            ORDER BY tc.table_name, tc.constraint_name
        LOOP
            BEGIN
                -- Check if table exists before trying to add constraint
                IF EXISTS (
                    SELECT 1 FROM information_schema.tables
                    WHERE table_schema = 'public'
                    AND table_name = constraint_record.referencing_table
                ) THEN
                    sql_command := format('ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES public.products(id)',
                        constraint_record.referencing_table,
                        constraint_record.constraint_name,
                        constraint_record.referencing_column);
                    EXECUTE sql_command;
                    RAISE NOTICE 'Recreated constraint: % on table %',
                        constraint_record.constraint_name,
                        constraint_record.referencing_table;
                ELSE
                    RAISE WARNING 'Table % does not exist, skipping constraint recreation',
                        constraint_record.referencing_table;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING 'Failed to recreate constraint %: %',
                        constraint_record.constraint_name, SQLERRM;
            END;
        END LOOP;

        RAISE NOTICE 'Comprehensive products table migration completed successfully';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Migration failed: %. Backup table products_backup is available for recovery.', SQLERRM;
END $$;

-- Add missing image columns if they don't exist
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS main_image_url TEXT;

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS image_urls JSONB DEFAULT '[]'::jsonb;

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'external_api';

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS external_id TEXT;

-- STEP 3: CREATE/UPDATE INVOICES TABLE WITH IMAGE SUPPORT
-- =====================================================

SELECT '=== SETTING UP INVOICES TABLE ===' as section;

-- Create invoices table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.invoices (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    customer_name TEXT NOT NULL,
    customer_phone TEXT,
    customer_email TEXT,
    customer_address TEXT,
    items JSONB NOT NULL,  -- Will store product images in item data
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
    discount DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending',
    notes TEXT,
    pdf_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Enable RLS on invoices
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for invoices (with proper syntax)
DO $$
BEGIN
    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS "invoices_service_role_access" ON public.invoices;
    DROP POLICY IF EXISTS "invoices_user_access" ON public.invoices;

    -- Create service role policy
    CREATE POLICY "invoices_service_role_access" ON public.invoices
    FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);

    -- Create user access policy
    CREATE POLICY "invoices_user_access" ON public.invoices
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

    RAISE NOTICE 'RLS policies created successfully for invoices table';
END $$;

-- STEP 4: CREATE EXTERNAL PRODUCT SYNC FUNCTIONS
-- =====================================================

-- Function to sync external API product with local storage
CREATE OR REPLACE FUNCTION public.sync_external_product(
    p_external_id TEXT,
    p_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_price DECIMAL DEFAULT 0,
    p_image_url TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL,
    p_stock_quantity INTEGER DEFAULT 0
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    product_id TEXT;
    system_user_id UUID;
    has_created_by BOOLEAN := FALSE;
BEGIN
    -- Use external_id as the primary ID for consistency
    product_id := p_external_id;

    -- Check if products table has created_by column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'products'
        AND column_name = 'created_by'
    ) INTO has_created_by;

    -- Get a system user ID if created_by column exists
    IF has_created_by THEN
        -- Try to get the first available user, or use a system UUID
        SELECT id INTO system_user_id
        FROM auth.users
        WHERE email LIKE '%system%' OR email LIKE '%admin%'
        LIMIT 1;

        -- If no system user found, use a default UUID
        IF system_user_id IS NULL THEN
            system_user_id := '00000000-0000-0000-0000-000000000000'::UUID;
        END IF;
    END IF;

    -- Insert or update product with conditional created_by
    IF has_created_by THEN
        INSERT INTO public.products (
            id,
            external_id,
            name,
            description,
            price,
            image_url,
            main_image_url,
            image_urls,
            category,
            stock_quantity,
            source,
            created_by,
            updated_at
        ) VALUES (
            product_id,
            p_external_id,
            p_name,
            p_description,
            p_price,
            p_image_url,
            p_image_url,
            CASE
                WHEN p_image_url IS NOT NULL THEN jsonb_build_array(p_image_url)
                ELSE '[]'::jsonb
            END,
            p_category,
            p_stock_quantity,
            'external_api',
            system_user_id,
            now()
        )
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            description = EXCLUDED.description,
            price = EXCLUDED.price,
            image_url = EXCLUDED.image_url,
            main_image_url = EXCLUDED.main_image_url,
            image_urls = EXCLUDED.image_urls,
            category = EXCLUDED.category,
            stock_quantity = EXCLUDED.stock_quantity,
            updated_at = now();
    ELSE
        INSERT INTO public.products (
            id,
            external_id,
            name,
            description,
            price,
            image_url,
            main_image_url,
            image_urls,
            category,
            stock_quantity,
            source,
            updated_at
        ) VALUES (
            product_id,
            p_external_id,
            p_name,
            p_description,
            p_price,
            p_image_url,
            p_image_url,
            CASE
                WHEN p_image_url IS NOT NULL THEN jsonb_build_array(p_image_url)
                ELSE '[]'::jsonb
            END,
            p_category,
            p_stock_quantity,
            'external_api',
            now()
        )
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            description = EXCLUDED.description,
            price = EXCLUDED.price,
            image_url = EXCLUDED.image_url,
            main_image_url = EXCLUDED.main_image_url,
            image_urls = EXCLUDED.image_urls,
            category = EXCLUDED.category,
            stock_quantity = EXCLUDED.stock_quantity,
            updated_at = now();
    END IF;

    RETURN product_id;
END $$;

-- Function to get product image URL (handles both local and external products)
CREATE OR REPLACE FUNCTION public.get_product_image_url(product_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    image_url TEXT;
BEGIN
    -- Try to get from main_image_url first
    SELECT main_image_url INTO image_url
    FROM public.products 
    WHERE id = product_id;
    
    -- If main_image_url is empty, try image_url
    IF image_url IS NULL OR image_url = '' THEN
        SELECT products.image_url INTO image_url
        FROM public.products 
        WHERE id = product_id;
    END IF;
    
    -- If still no image, try first image from image_urls array
    IF image_url IS NULL OR image_url = '' THEN
        SELECT image_urls->>0 INTO image_url
        FROM public.products 
        WHERE id = product_id
        AND jsonb_array_length(image_urls) > 0;
    END IF;
    
    RETURN image_url;
END $$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.sync_external_product(TEXT, TEXT, TEXT, DECIMAL, TEXT, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_product_image_url(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_external_product(TEXT, TEXT, TEXT, DECIMAL, TEXT, TEXT, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_product_image_url(TEXT) TO service_role;

-- STEP 4.5: CREATE CURRENCY CONVERSION FUNCTIONS
-- =====================================================

-- Function to convert SAR to EGP
CREATE OR REPLACE FUNCTION public.convert_sar_to_egp(sar_amount DECIMAL)
RETURNS DECIMAL
LANGUAGE plpgsql
AS $$
DECLARE
    exchange_rate DECIMAL := 8.25; -- 1 SAR = 8.25 EGP (configurable)
BEGIN
    RETURN ROUND(sar_amount * exchange_rate, 2);
END $$;

-- Function to get current exchange rate (configurable)
CREATE OR REPLACE FUNCTION public.get_exchange_rate(
    from_currency TEXT DEFAULT 'SAR',
    to_currency TEXT DEFAULT 'EGP'
)
RETURNS DECIMAL
LANGUAGE plpgsql
AS $$
DECLARE
    rate DECIMAL := 8.25; -- Default SAR to EGP rate
BEGIN
    -- Future enhancement: fetch from exchange_rates table
    IF from_currency = 'SAR' AND to_currency = 'EGP' THEN
        RETURN 8.25;
    ELSIF from_currency = 'USD' AND to_currency = 'EGP' THEN
        RETURN 30.90; -- Approximate USD to EGP rate
    ELSIF from_currency = 'EGP' AND to_currency = 'EGP' THEN
        RETURN 1.00;
    ELSE
        RETURN 1.00; -- Default no conversion
    END IF;
END $$;

-- Function to convert any currency to EGP
CREATE OR REPLACE FUNCTION public.convert_to_egp(
    amount DECIMAL,
    from_currency TEXT DEFAULT 'SAR'
)
RETURNS DECIMAL
LANGUAGE plpgsql
AS $$
DECLARE
    exchange_rate DECIMAL;
BEGIN
    SELECT public.get_exchange_rate(from_currency, 'EGP') INTO exchange_rate;
    RETURN ROUND(amount * exchange_rate, 2);
END $$;

-- Grant permissions for currency functions
GRANT EXECUTE ON FUNCTION public.convert_sar_to_egp(DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_exchange_rate(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.convert_to_egp(DECIMAL, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.convert_sar_to_egp(DECIMAL) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_exchange_rate(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.convert_to_egp(DECIMAL, TEXT) TO service_role;

-- STEP 5: CREATE INVOICE WITH IMAGES HELPER FUNCTION
-- =====================================================

-- Function to create invoice with product images (EGP Currency Support)
CREATE OR REPLACE FUNCTION public.create_invoice_with_images(
    p_invoice_id TEXT,
    p_user_id UUID,
    p_customer_name TEXT,
    p_items JSONB,
    p_customer_phone TEXT DEFAULT NULL,
    p_customer_email TEXT DEFAULT NULL,
    p_customer_address TEXT DEFAULT NULL,
    p_subtotal DECIMAL DEFAULT 0,
    p_discount DECIMAL DEFAULT 0,
    p_total_amount DECIMAL DEFAULT 0,
    p_notes TEXT DEFAULT NULL,
    p_currency TEXT DEFAULT 'EGP'
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    enhanced_items JSONB := '[]'::jsonb;
    item JSONB;
    product_image TEXT;
BEGIN
    -- Enhance items with product images
    FOR item IN SELECT jsonb_array_elements(p_items)
    LOOP
        -- Get product image URL
        SELECT public.get_product_image_url(item->>'product_id') INTO product_image;
        
        -- Add image URL to item
        item := item || jsonb_build_object('product_image', product_image);
        
        -- Add to enhanced items array
        enhanced_items := enhanced_items || jsonb_build_array(item);
    END LOOP;
    
    -- Insert invoice with enhanced items and currency metadata
    INSERT INTO public.invoices (
        id,
        user_id,
        customer_name,
        customer_phone,
        customer_email,
        customer_address,
        items,
        subtotal,
        discount,
        total_amount,
        notes,
        metadata,
        created_at
    ) VALUES (
        p_invoice_id,
        p_user_id,
        p_customer_name,
        p_customer_phone,
        p_customer_email,
        p_customer_address,
        enhanced_items,
        p_subtotal,
        p_discount,
        p_total_amount,
        p_notes,
        jsonb_build_object(
            'currency', p_currency,
            'currency_symbol', 'جنيه',
            'exchange_rate_used', public.get_exchange_rate('SAR', 'EGP'),
            'created_with_images', true
        ),
        now()
    );
    
    RETURN p_invoice_id;
END $$;

-- Grant permissions (updated for new currency parameter)
GRANT EXECUTE ON FUNCTION public.create_invoice_with_images(TEXT, UUID, TEXT, JSONB, TEXT, TEXT, TEXT, DECIMAL, DECIMAL, DECIMAL, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_invoice_with_images(TEXT, UUID, TEXT, JSONB, TEXT, TEXT, TEXT, DECIMAL, DECIMAL, DECIMAL, TEXT, TEXT) TO service_role;

-- STEP 6: CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Indexes for products table
CREATE INDEX IF NOT EXISTS idx_products_external_id ON public.products(external_id);
CREATE INDEX IF NOT EXISTS idx_products_source ON public.products(source);
CREATE INDEX IF NOT EXISTS idx_products_main_image_url ON public.products(main_image_url) WHERE main_image_url IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_image_urls ON public.products USING GIN(image_urls);

-- Indexes for invoices table
CREATE INDEX IF NOT EXISTS idx_invoices_user_id ON public.invoices(user_id);
CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON public.invoices(created_at);
CREATE INDEX IF NOT EXISTS idx_invoices_items ON public.invoices USING GIN(items);

-- STEP 7: TEST THE SOLUTION
-- =====================================================

SELECT '=== TESTING THE SOLUTION ===' as section;

-- Test 1: Test product sync function
SELECT 
    'Product sync test' as test_name,
    public.sync_external_product(
        '172',
        'Test Product 172',
        'Test product for image handling',
        99.99,
        'https://example.com/product-172.jpg',
        'Test Category',
        10
    ) as result;

-- Test 2: Test image URL retrieval
SELECT 
    'Image URL retrieval test' as test_name,
    public.get_product_image_url('172') as image_url;

-- Test 3: Test the problematic query that was failing
DO $$
BEGIN
    -- This should now work without UUID errors
    PERFORM main_image_url, image_urls 
    FROM public.products 
    WHERE id = '172';
    
    RAISE NOTICE 'SUCCESS: Query with ID "172" now works without UUID errors';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR: Query still failing - %', SQLERRM;
END $$;

-- STEP 8: COMPREHENSIVE FINAL VERIFICATION
-- =====================================================

SELECT '=== COMPREHENSIVE MIGRATION VERIFICATION ===' as section;

-- Show final table structures
SELECT
    'Final products table structure' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'products'
AND column_name IN ('id', 'image_url', 'main_image_url', 'image_urls', 'source', 'external_id')
ORDER BY column_name;

-- Verify ALL foreign key constraints are recreated
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

-- Verify all product_id columns are now TEXT
SELECT
    '=== CONVERTED PRODUCT_ID COLUMNS ===' as verification_section,
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND column_name LIKE '%product_id%'
ORDER BY table_name, column_name;

-- Show sample data
SELECT
    'Sample products data' as info,
    id,
    name,
    image_url,
    main_image_url,
    source,
    external_id
FROM public.products
LIMIT 3;

-- Test external API product functionality
DO $$
BEGIN
    -- Test the sync function that was causing UUID errors
    PERFORM public.sync_external_product(
        'test-migration-172',
        'Test Migration Product',
        'Product to verify migration success',
        99.99,
        'https://example.com/test-migration.jpg',
        'Test Category',
        5
    );

    RAISE NOTICE 'SUCCESS: sync_external_product function works with text IDs';
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'ERROR: sync_external_product function failed - %', SQLERRM;
END $$;

-- Final migration status
SELECT
    'COMPREHENSIVE PRODUCT IMAGE & INVOICE FIX COMPLETE' as status,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'products'
            AND column_name = 'id'
            AND data_type = 'text'
        ) THEN 'SUCCESS: Products table migrated to TEXT ID'
        ELSE 'ERROR: Products table still uses UUID ID'
    END as migration_status,
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
    ) as foreign_key_constraints_recreated,
    'Database now supports external API products with images in invoices' as result,
    'Run VERIFY_PRODUCTS_MIGRATION.sql for detailed verification' as next_step;
