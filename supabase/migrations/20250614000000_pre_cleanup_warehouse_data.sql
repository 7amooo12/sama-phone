-- تنظيف البيانات قبل إضافة قيود المفاتيح الخارجية
-- Pre-cleanup for warehouse data before adding foreign key constraints

-- Step 1: Create temporary products table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.products (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0,
    sale_price DECIMAL(10, 2),
    stock_quantity INTEGER DEFAULT 0,
    category TEXT,
    image_url TEXT,
    main_image_url TEXT,
    image_urls JSONB DEFAULT '[]'::jsonb,
    sku TEXT,
    barcode TEXT,
    manufacturer TEXT,
    supplier TEXT,
    active BOOLEAN DEFAULT true,
    source TEXT DEFAULT 'external_api',
    external_id TEXT,
    purchase_price DECIMAL(10, 2) DEFAULT 0,
    original_price DECIMAL(10, 2),
    discount_price DECIMAL(10, 2),
    minimum_stock INTEGER DEFAULT 10,
    reorder_point INTEGER DEFAULT 10,
    tags JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_by UUID REFERENCES auth.users(id), -- Nullable for system-generated products
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Step 2: Make created_by nullable if it exists with NOT NULL constraint
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products'
        AND column_name = 'created_by'
        AND is_nullable = 'NO'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ALTER COLUMN created_by DROP NOT NULL;
        RAISE NOTICE 'Made created_by column nullable for system-generated products';
    END IF;
END $$;

-- Step 3: Enable RLS on products table
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Step 4: Create basic RLS policy for products
DROP POLICY IF EXISTS "Products are viewable by authenticated users" ON public.products;
CREATE POLICY "Products are viewable by authenticated users"
    ON public.products FOR SELECT
    USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Products are manageable by admins" ON public.products;
CREATE POLICY "Products are manageable by admins"
    ON public.products FOR ALL
    USING (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() AND role IN ('admin', 'owner', 'accountant', 'warehouse_manager')
            )
        )
    );

-- Step 5: Identify and create missing products
DO $$
DECLARE
    missing_product_record RECORD;
    created_count INTEGER := 0;
BEGIN
    RAISE NOTICE 'Starting pre-cleanup: identifying missing products...';
    
    -- Check if warehouse_inventory table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_inventory' AND table_schema = 'public') THEN
        
        -- Create missing products from warehouse_inventory
        FOR missing_product_record IN 
            SELECT DISTINCT wi.product_id
            FROM public.warehouse_inventory wi
            LEFT JOIN public.products p ON wi.product_id = p.id
            WHERE p.id IS NULL AND wi.product_id IS NOT NULL
        LOOP
            INSERT INTO public.products (
                id, name, description, price, stock_quantity, category, 
                source, active, sku, created_at, updated_at
            ) VALUES (
                missing_product_record.product_id,
                'منتج ' || missing_product_record.product_id,
                'منتج من API خارجي تم إنشاؤه تلقائياً لحل مشكلة المراجع المفقودة',
                0.00,
                0,
                'مستورد',
                'external_api',
                true,
                'API-' || missing_product_record.product_id,
                now(),
                now()
            ) ON CONFLICT (id) DO UPDATE SET
                description = 'منتج من API خارجي تم إنشاؤه تلقائياً لحل مشكلة المراجع المفقودة',
                source = 'external_api',
                updated_at = now();
            
            created_count := created_count + 1;
        END LOOP;
        
        RAISE NOTICE 'Created % missing products from warehouse_inventory', created_count;
    END IF;
    
    -- Reset counter for warehouse_request_items
    created_count := 0;
    
    -- Check if warehouse_request_items table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_request_items' AND table_schema = 'public') THEN
        
        -- Create missing products from warehouse_request_items
        FOR missing_product_record IN 
            SELECT DISTINCT wri.product_id
            FROM public.warehouse_request_items wri
            LEFT JOIN public.products p ON wri.product_id = p.id
            WHERE p.id IS NULL AND wri.product_id IS NOT NULL
        LOOP
            INSERT INTO public.products (
                id, name, description, price, stock_quantity, category, 
                source, active, sku, created_at, updated_at
            ) VALUES (
                missing_product_record.product_id,
                'منتج ' || missing_product_record.product_id,
                'منتج من API خارجي تم إنشاؤه تلقائياً لحل مشكلة المراجع المفقودة',
                0.00,
                0,
                'مستورد',
                'external_api',
                true,
                'API-' || missing_product_record.product_id,
                now(),
                now()
            ) ON CONFLICT (id) DO NOTHING;
            
            created_count := created_count + 1;
        END LOOP;
        
        RAISE NOTICE 'Created % missing products from warehouse_request_items', created_count;
    END IF;
    
    -- Reset counter for warehouse_transactions
    created_count := 0;
    
    -- Check if warehouse_transactions table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_transactions' AND table_schema = 'public') THEN
        
        -- Create missing products from warehouse_transactions
        FOR missing_product_record IN 
            SELECT DISTINCT wt.product_id
            FROM public.warehouse_transactions wt
            LEFT JOIN public.products p ON wt.product_id = p.id
            WHERE p.id IS NULL AND wt.product_id IS NOT NULL
        LOOP
            INSERT INTO public.products (
                id, name, description, price, stock_quantity, category, 
                source, active, sku, created_at, updated_at
            ) VALUES (
                missing_product_record.product_id,
                'منتج ' || missing_product_record.product_id,
                'منتج من API خارجي تم إنشاؤه تلقائياً لحل مشكلة المراجع المفقودة',
                0.00,
                0,
                'مستورد',
                'external_api',
                true,
                'API-' || missing_product_record.product_id,
                now(),
                now()
            ) ON CONFLICT (id) DO NOTHING;
            
            created_count := created_count + 1;
        END LOOP;
        
        RAISE NOTICE 'Created % missing products from warehouse_transactions', created_count;
    END IF;
    
    RAISE NOTICE 'Pre-cleanup completed successfully';
END $$;

-- Step 6: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_products_active ON public.products(active);
CREATE INDEX IF NOT EXISTS idx_products_source ON public.products(source);
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);

-- Step 7: Insert some common test products to ensure the system works
INSERT INTO public.products (id, name, description, price, stock_quantity, category, source, active) 
VALUES 
    ('1', 'منتج تجريبي 1', 'وصف المنتج التجريبي الأول', 100.00, 50, 'عام', 'manual', true),
    ('2', 'منتج تجريبي 2', 'وصف المنتج التجريبي الثاني', 200.00, 30, 'عام', 'manual', true),
    ('160', 'منتج خارجي 160', 'منتج من API خارجي', 150.00, 25, 'مستورد', 'external_api', true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    stock_quantity = EXCLUDED.stock_quantity,
    category = EXCLUDED.category,
    source = EXCLUDED.source,
    active = EXCLUDED.active,
    updated_at = now();

-- Step 8: Verify data integrity
DO $$
DECLARE
    orphaned_count INTEGER;
    total_products INTEGER;
BEGIN
    -- Count total products
    SELECT COUNT(*) INTO total_products FROM public.products;
    RAISE NOTICE 'Total products in database: %', total_products;
    
    -- Check for remaining orphaned records in warehouse_inventory
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_inventory' AND table_schema = 'public') THEN
        SELECT COUNT(*) INTO orphaned_count
        FROM public.warehouse_inventory wi
        LEFT JOIN public.products p ON wi.product_id = p.id
        WHERE p.id IS NULL;
        
        RAISE NOTICE 'Orphaned warehouse_inventory records: %', orphaned_count;
        
        IF orphaned_count > 0 THEN
            RAISE WARNING 'Still have % orphaned warehouse_inventory records after cleanup', orphaned_count;
        END IF;
    END IF;
    
    -- Check for remaining orphaned records in warehouse_request_items
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_request_items' AND table_schema = 'public') THEN
        SELECT COUNT(*) INTO orphaned_count
        FROM public.warehouse_request_items wri
        LEFT JOIN public.products p ON wri.product_id = p.id
        WHERE p.id IS NULL;
        
        RAISE NOTICE 'Orphaned warehouse_request_items records: %', orphaned_count;
    END IF;
    
    -- Check for remaining orphaned records in warehouse_transactions
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_transactions' AND table_schema = 'public') THEN
        SELECT COUNT(*) INTO orphaned_count
        FROM public.warehouse_transactions wt
        LEFT JOIN public.products p ON wt.product_id = p.id
        WHERE p.id IS NULL;
        
        RAISE NOTICE 'Orphaned warehouse_transactions records: %', orphaned_count;
    END IF;
    
    RAISE NOTICE 'Data integrity verification completed';
END $$;
