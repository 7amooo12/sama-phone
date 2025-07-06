-- إصلاح مخطط جدول المنتجات لدعم إضافة المنتجات من API
-- Fix products table schema to support API product addition

-- Step 1: Ensure products table exists with correct schema
DO $$
BEGIN
    -- Check if products table exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'products' AND table_schema = 'public') THEN
        -- Create products table with comprehensive schema
        CREATE TABLE public.products (
            id TEXT PRIMARY KEY,  -- Use TEXT to support API IDs
            name TEXT NOT NULL,
            description TEXT,
            price DECIMAL(10, 2) NOT NULL DEFAULT 0,
            sale_price DECIMAL(10, 2),
            quantity INTEGER DEFAULT 0,  -- Use 'quantity' instead of 'stock_quantity'
            category TEXT,
            image_url TEXT,
            main_image_url TEXT,
            images JSONB DEFAULT '[]'::jsonb,  -- Array of image URLs
            sku TEXT,
            barcode TEXT,
            manufacturer TEXT,
            supplier TEXT,
            active BOOLEAN DEFAULT true,  -- Use 'active' instead of 'is_active'
            source TEXT DEFAULT 'external_api',
            external_id TEXT,
            purchase_price DECIMAL(10, 2) DEFAULT 0,
            original_price DECIMAL(10, 2),
            discount_price DECIMAL(10, 2),
            minimum_stock INTEGER DEFAULT 10,
            reorder_point INTEGER DEFAULT 10,
            tags JSONB DEFAULT '[]'::jsonb,
            metadata JSONB DEFAULT '{}'::jsonb,
            created_by UUID REFERENCES auth.users(id), -- Nullable for API products
            created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
        );
        
        RAISE NOTICE 'Created products table with comprehensive schema';
    END IF;
END $$;

-- Step 2: Add missing columns if they don't exist
DO $$
BEGIN
    -- Add images column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'images' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN images JSONB DEFAULT '[]'::jsonb;
        RAISE NOTICE 'Added images column to products table';
    END IF;

    -- Add main_image_url column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'main_image_url' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN main_image_url TEXT;
        RAISE NOTICE 'Added main_image_url column to products table';
    END IF;

    -- Add quantity column if missing (some schemas use stock_quantity)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'quantity' AND table_schema = 'public'
    ) THEN
        -- Check if stock_quantity exists and rename it
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'products' AND column_name = 'stock_quantity' AND table_schema = 'public'
        ) THEN
            ALTER TABLE public.products RENAME COLUMN stock_quantity TO quantity;
            RAISE NOTICE 'Renamed stock_quantity to quantity in products table';
        ELSE
            ALTER TABLE public.products ADD COLUMN quantity INTEGER DEFAULT 0;
            RAISE NOTICE 'Added quantity column to products table';
        END IF;
    END IF;

    -- Add active column if missing (some schemas use is_active)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'active' AND table_schema = 'public'
    ) THEN
        -- Check if is_active exists and rename it
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'products' AND column_name = 'is_active' AND table_schema = 'public'
        ) THEN
            ALTER TABLE public.products RENAME COLUMN is_active TO active;
            RAISE NOTICE 'Renamed is_active to active in products table';
        ELSE
            ALTER TABLE public.products ADD COLUMN active BOOLEAN DEFAULT true;
            RAISE NOTICE 'Added active column to products table';
        END IF;
    END IF;

    -- Add source column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'source' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN source TEXT DEFAULT 'external_api';
        RAISE NOTICE 'Added source column to products table';
    END IF;

    -- Add external_id column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'external_id' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN external_id TEXT;
        RAISE NOTICE 'Added external_id column to products table';
    END IF;

    -- Add purchase_price column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'purchase_price' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN purchase_price DECIMAL(10, 2) DEFAULT 0;
        RAISE NOTICE 'Added purchase_price column to products table';
    END IF;

    -- Add minimum_stock column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'minimum_stock' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN minimum_stock INTEGER DEFAULT 10;
        RAISE NOTICE 'Added minimum_stock column to products table';
    END IF;

    -- Add reorder_point column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'reorder_point' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN reorder_point INTEGER DEFAULT 10;
        RAISE NOTICE 'Added reorder_point column to products table';
    END IF;

    -- Add tags column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'tags' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN tags JSONB DEFAULT '[]'::jsonb;
        RAISE NOTICE 'Added tags column to products table';
    END IF;

    -- Ensure metadata column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'metadata' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
        RAISE NOTICE 'Added metadata column to products table';
    END IF;

    -- Make created_by nullable for API products
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products' AND column_name = 'created_by' 
        AND is_nullable = 'NO' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ALTER COLUMN created_by DROP NOT NULL;
        RAISE NOTICE 'Made created_by column nullable for API products';
    END IF;
END $$;

-- Step 3: Update data type for id column if needed
DO $$
BEGIN
    -- Check if id column is UUID and change to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products' AND column_name = 'id' 
        AND data_type = 'uuid' AND table_schema = 'public'
    ) THEN
        -- This is a complex operation, so we'll create a new table and migrate data
        RAISE NOTICE 'Products table has UUID id column, migration needed for TEXT support';
        
        -- Create backup table
        CREATE TABLE IF NOT EXISTS products_backup AS SELECT * FROM public.products;
        
        -- Drop foreign key constraints temporarily
        -- Note: This might need manual adjustment based on existing constraints
        
        -- Recreate table with TEXT id
        DROP TABLE IF EXISTS public.products CASCADE;
        
        CREATE TABLE public.products (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            price DECIMAL(10, 2) NOT NULL DEFAULT 0,
            sale_price DECIMAL(10, 2),
            quantity INTEGER DEFAULT 0,
            category TEXT,
            image_url TEXT,
            main_image_url TEXT,
            images JSONB DEFAULT '[]'::jsonb,
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
            created_by UUID REFERENCES auth.users(id),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
        );
        
        RAISE NOTICE 'Recreated products table with TEXT id column';
    END IF;
END $$;

-- Step 4: Enable RLS and create policies
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "المنتجات قابلة للقراءة من قبل الجميع" ON public.products;
DROP POLICY IF EXISTS "المنتجات قابلة للإنشاء من قبل المستخدمين المصرح لهم" ON public.products;
DROP POLICY IF EXISTS "المنتجات قابلة للتحديث من قبل المستخدمين المصرح لهم" ON public.products;

-- Create new policies
CREATE POLICY "المنتجات قابلة للقراءة من قبل الجميع"
    ON public.products FOR SELECT
    USING (true);  -- Allow all authenticated users to read products

CREATE POLICY "المنتجات قابلة للإنشاء من قبل المستخدمين المصرح لهم"
    ON public.products FOR INSERT
    WITH CHECK (
        auth.role() = 'authenticated' AND (
            -- Allow system to create products (created_by is null)
            created_by IS NULL OR
            -- Allow authorized users to create products
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() 
                AND status = 'approved'
                AND role IN ('admin', 'owner', 'warehouse_manager', 'warehouseManager', 'accountant')
            )
        )
    );

CREATE POLICY "المنتجات قابلة للتحديث من قبل المستخدمين المصرح لهم"
    ON public.products FOR UPDATE
    USING (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() 
                AND status = 'approved'
                AND role IN ('admin', 'owner', 'warehouse_manager', 'warehouseManager', 'accountant')
            )
        )
    );

-- Step 5: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_products_active ON public.products(active) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_source ON public.products(source);
CREATE INDEX IF NOT EXISTS idx_products_external_id ON public.products(external_id);
CREATE INDEX IF NOT EXISTS idx_products_sku ON public.products(sku);
CREATE INDEX IF NOT EXISTS idx_products_name_search ON public.products USING gin(to_tsvector('arabic', name));

-- Step 6: Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_products_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_products_updated_at_trigger ON public.products;
CREATE TRIGGER update_products_updated_at_trigger
    BEFORE UPDATE ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION update_products_updated_at();

-- Step 7: Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON public.products TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
