-- Quick fix for products table schema issues
-- Run this in Supabase SQL Editor

-- Step 1: Add missing columns if they don't exist
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

    -- Add active column if missing (rename is_active if it exists)
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

    -- Add manufacturer column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products' AND column_name = 'manufacturer' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN manufacturer TEXT;
        RAISE NOTICE 'Added manufacturer column to products table';
    END IF;

    -- Add barcode column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products' AND column_name = 'barcode' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN barcode TEXT;
        RAISE NOTICE 'Added barcode column to products table';
    END IF;

    -- Add sale_price column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products' AND column_name = 'sale_price' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN sale_price DECIMAL(10, 2);
        RAISE NOTICE 'Added sale_price column to products table';
    END IF;

    -- Add original_price column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products' AND column_name = 'original_price' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN original_price DECIMAL(10, 2);
        RAISE NOTICE 'Added original_price column to products table';
    END IF;

    -- Add discount_price column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products' AND column_name = 'discount_price' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN discount_price DECIMAL(10, 2);
        RAISE NOTICE 'Added discount_price column to products table';
    END IF;

    -- Add purchase_price column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products' AND column_name = 'purchase_price' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN purchase_price DECIMAL(10, 2);
        RAISE NOTICE 'Added purchase_price column to products table';
    END IF;

    -- Add sku column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products' AND column_name = 'sku' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN sku TEXT;
        RAISE NOTICE 'Added sku column to products table';
    END IF;

    -- Add external_id column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'external_id' AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN external_id TEXT;
        RAISE NOTICE 'Added external_id column to products table';
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

    -- Ensure quantity column exists (rename stock_quantity if needed)
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

END $$;

-- Step 2: Update RLS policies for products table
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "المنتجات قابلة للقراءة من قبل الجميع" ON public.products;
DROP POLICY IF EXISTS "المنتجات قابلة للإنشاء من قبل المستخدمين المصرح لهم" ON public.products;
DROP POLICY IF EXISTS "المنتجات قابلة للتحديث من قبل المستخدمين المصرح لهم" ON public.products;

-- Create new policies
CREATE POLICY "المنتجات قابلة للقراءة من قبل الجميع"
    ON public.products FOR SELECT
    USING (true);

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

-- Step 3: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_products_active ON public.products(active) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_products_source ON public.products(source);
CREATE INDEX IF NOT EXISTS idx_products_external_id ON public.products(external_id);

-- Step 4: Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON public.products TO authenticated;

-- Verify the changes
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'products' 
AND table_schema = 'public'
ORDER BY ordinal_position;
