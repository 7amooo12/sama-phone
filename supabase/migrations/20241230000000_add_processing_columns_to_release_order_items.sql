-- إضافة أعمدة المعالجة لجدول عناصر أذون الصرف
-- Add processing columns to warehouse_release_order_items table
-- This migration adds the missing columns that the WarehouseReleaseOrdersService expects

-- Add processing-related columns to warehouse_release_order_items table
DO $$
BEGIN
    -- Add processed_at column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_release_order_items' 
        AND column_name = 'processed_at'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.warehouse_release_order_items 
        ADD COLUMN processed_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE 'Added processed_at column to warehouse_release_order_items table';
    ELSE
        RAISE NOTICE 'processed_at column already exists in warehouse_release_order_items table';
    END IF;

    -- Add processed_by column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_release_order_items' 
        AND column_name = 'processed_by'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.warehouse_release_order_items 
        ADD COLUMN processed_by UUID REFERENCES auth.users(id);
        RAISE NOTICE 'Added processed_by column to warehouse_release_order_items table';
    ELSE
        RAISE NOTICE 'processed_by column already exists in warehouse_release_order_items table';
    END IF;

    -- Add processing_notes column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_release_order_items' 
        AND column_name = 'processing_notes'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.warehouse_release_order_items 
        ADD COLUMN processing_notes TEXT;
        RAISE NOTICE 'Added processing_notes column to warehouse_release_order_items table';
    ELSE
        RAISE NOTICE 'processing_notes column already exists in warehouse_release_order_items table';
    END IF;

    -- Add deduction_result column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_release_order_items' 
        AND column_name = 'deduction_result'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.warehouse_release_order_items 
        ADD COLUMN deduction_result JSONB DEFAULT '{}'::jsonb;
        RAISE NOTICE 'Added deduction_result column to warehouse_release_order_items table';
    ELSE
        RAISE NOTICE 'deduction_result column already exists in warehouse_release_order_items table';
    END IF;

END $$;

-- Create indexes for better performance on the new columns
CREATE INDEX IF NOT EXISTS idx_warehouse_release_order_items_processed_at 
    ON public.warehouse_release_order_items(processed_at);

CREATE INDEX IF NOT EXISTS idx_warehouse_release_order_items_processed_by 
    ON public.warehouse_release_order_items(processed_by);

-- Add comments for documentation
COMMENT ON COLUMN public.warehouse_release_order_items.processed_at IS 'تاريخ ووقت معالجة العنصر وخصم المخزون';
COMMENT ON COLUMN public.warehouse_release_order_items.processed_by IS 'معرف مدير المخزن الذي قام بمعالجة العنصر';
COMMENT ON COLUMN public.warehouse_release_order_items.processing_notes IS 'ملاحظات إضافية حول معالجة العنصر';
COMMENT ON COLUMN public.warehouse_release_order_items.deduction_result IS 'نتائج عملية خصم المخزون بصيغة JSON';

-- Log successful completion
SELECT 'تم إضافة أعمدة المعالجة بنجاح إلى جدول warehouse_release_order_items' as result;
