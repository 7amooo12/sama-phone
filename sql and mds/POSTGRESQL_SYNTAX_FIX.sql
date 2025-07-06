-- =====================================================
-- POSTGRESQL SYNTAX FIX FOR SUPABASE
-- Fixes syntax errors in the comprehensive product image fix
-- Specifically addresses RLS policy creation issues
-- =====================================================

-- STEP 1: FIX RLS POLICIES WITH PROPER SYNTAX
-- =====================================================

SELECT '=== FIXING RLS POLICIES SYNTAX ===' as section;

-- Enable RLS on invoices table (safe to run multiple times)
DO $$
BEGIN
    -- Check if table exists before enabling RLS
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'invoices'
    ) THEN
        ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'RLS enabled on invoices table';
    ELSE
        RAISE NOTICE 'Invoices table does not exist yet';
    END IF;
END $$;

-- Create RLS policies with proper PostgreSQL syntax
DO $$
BEGIN
    -- Check if invoices table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'invoices'
    ) THEN
        -- Drop existing policies if they exist (safe operation)
        DROP POLICY IF EXISTS "invoices_service_role_access" ON public.invoices;
        DROP POLICY IF EXISTS "invoices_user_access" ON public.invoices;
        DROP POLICY IF EXISTS "invoices_admin_access" ON public.invoices;
        DROP POLICY IF EXISTS "invoices_owner_access" ON public.invoices;
        
        -- Create service role policy (full access)
        CREATE POLICY "invoices_service_role_access" ON public.invoices
        FOR ALL TO service_role
        USING (true)
        WITH CHECK (true);
        
        -- Create authenticated user policy (own invoices only)
        CREATE POLICY "invoices_user_access" ON public.invoices
        FOR ALL TO authenticated
        USING (user_id = auth.uid())
        WITH CHECK (user_id = auth.uid());
        
        RAISE NOTICE 'RLS policies created successfully for invoices table';
    ELSE
        RAISE NOTICE 'Invoices table does not exist - policies will be created after table creation';
    END IF;
END $$;

-- STEP 2: FIX PRODUCTS TABLE RLS (IF NEEDED)
-- =====================================================

-- Enable RLS on products table
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'products'
    ) THEN
        ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
        
        -- Drop existing policies
        DROP POLICY IF EXISTS "products_service_role_access" ON public.products;
        DROP POLICY IF EXISTS "products_authenticated_access" ON public.products;
        
        -- Create service role policy (full access)
        CREATE POLICY "products_service_role_access" ON public.products
        FOR ALL TO service_role
        USING (true)
        WITH CHECK (true);
        
        -- Create authenticated user policy (read access)
        CREATE POLICY "products_authenticated_access" ON public.products
        FOR SELECT TO authenticated
        USING (true);
        
        RAISE NOTICE 'RLS policies created successfully for products table';
    ELSE
        RAISE NOTICE 'Products table does not exist yet';
    END IF;
END $$;

-- STEP 3: CREATE SAFE INDEX CREATION
-- =====================================================

-- Create indexes with error handling
DO $$
BEGIN
    -- Products table indexes
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'products' AND table_schema = 'public') THEN
        -- Create indexes one by one with error handling
        BEGIN
            CREATE INDEX IF NOT EXISTS idx_products_external_id ON public.products(external_id);
            RAISE NOTICE 'Created index: idx_products_external_id';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Index idx_products_external_id already exists or error: %', SQLERRM;
        END;
        
        BEGIN
            CREATE INDEX IF NOT EXISTS idx_products_source ON public.products(source);
            RAISE NOTICE 'Created index: idx_products_source';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Index idx_products_source already exists or error: %', SQLERRM;
        END;
        
        BEGIN
            CREATE INDEX IF NOT EXISTS idx_products_main_image_url ON public.products(main_image_url) 
            WHERE main_image_url IS NOT NULL;
            RAISE NOTICE 'Created index: idx_products_main_image_url';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Index idx_products_main_image_url already exists or error: %', SQLERRM;
        END;
        
        BEGIN
            CREATE INDEX IF NOT EXISTS idx_products_image_urls ON public.products USING GIN(image_urls);
            RAISE NOTICE 'Created index: idx_products_image_urls';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Index idx_products_image_urls already exists or error: %', SQLERRM;
        END;
    END IF;
    
    -- Invoices table indexes
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'invoices' AND table_schema = 'public') THEN
        BEGIN
            CREATE INDEX IF NOT EXISTS idx_invoices_user_id ON public.invoices(user_id);
            RAISE NOTICE 'Created index: idx_invoices_user_id';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Index idx_invoices_user_id already exists or error: %', SQLERRM;
        END;
        
        BEGIN
            CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON public.invoices(created_at);
            RAISE NOTICE 'Created index: idx_invoices_created_at';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Index idx_invoices_created_at already exists or error: %', SQLERRM;
        END;
        
        BEGIN
            CREATE INDEX IF NOT EXISTS idx_invoices_items ON public.invoices USING GIN(items);
            RAISE NOTICE 'Created index: idx_invoices_items';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Index idx_invoices_items already exists or error: %', SQLERRM;
        END;
    END IF;
END $$;

-- STEP 4: VERIFY SYNTAX FIX
-- =====================================================

-- Test that policies were created successfully
SELECT 
    'RLS Policies Verification' as test_name,
    schemaname,
    tablename,
    policyname,
    permissive,
    roles
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('invoices', 'products')
ORDER BY tablename, policyname;

-- Test that indexes were created successfully
SELECT 
    'Indexes Verification' as test_name,
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public' 
AND tablename IN ('invoices', 'products')
AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- Final verification message
SELECT 
    'POSTGRESQL SYNTAX FIX COMPLETE' as status,
    'RLS policies and indexes created with proper syntax' as result,
    'Run the main comprehensive fix script after this' as next_step;
