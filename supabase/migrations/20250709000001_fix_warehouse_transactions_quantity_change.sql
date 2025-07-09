-- إصلاح مشكلة quantity_change في جدول warehouse_transactions
-- Fix quantity_change issue in warehouse_transactions table

-- Step 1: Ensure quantity_change column exists and is NOT NULL
DO $$
BEGIN
    -- Check if quantity_change column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_transactions' 
        AND column_name = 'quantity_change'
    ) THEN
        -- Add the column if it doesn't exist
        ALTER TABLE public.warehouse_transactions ADD COLUMN quantity_change INTEGER;
        
        -- Update existing records to calculate quantity_change
        UPDATE public.warehouse_transactions 
        SET quantity_change = quantity_after - quantity_before
        WHERE quantity_change IS NULL;
        
        -- Make it NOT NULL after updating
        ALTER TABLE public.warehouse_transactions ALTER COLUMN quantity_change SET NOT NULL;
        
        RAISE NOTICE '✅ Added quantity_change column to warehouse_transactions table';
    ELSE
        -- Column exists, ensure existing NULL values are fixed
        UPDATE public.warehouse_transactions 
        SET quantity_change = quantity_after - quantity_before
        WHERE quantity_change IS NULL;
        
        -- Ensure it's NOT NULL
        ALTER TABLE public.warehouse_transactions ALTER COLUMN quantity_change SET NOT NULL;
        
        RAISE NOTICE '✅ Fixed NULL values in quantity_change column';
    END IF;
END $$;

-- Step 2: Update the update_warehouse_inventory function to include quantity_change
CREATE OR REPLACE FUNCTION update_warehouse_inventory(
    p_warehouse_id UUID,
    p_product_id TEXT,
    p_quantity_change INTEGER,
    p_performed_by UUID,
    p_reason TEXT,
    p_reference_id TEXT DEFAULT NULL,
    p_reference_type TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    current_quantity INTEGER := 0;
    new_quantity INTEGER;
    transaction_type TEXT;
    transaction_number TEXT;
BEGIN
    -- التحقق من وجود المنتج في المخزن
    SELECT quantity INTO current_quantity
    FROM public.warehouse_inventory
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    
    -- إذا لم يوجد المنتج، إنشاؤه بكمية 0
    IF NOT FOUND THEN
        INSERT INTO public.warehouse_inventory (
            warehouse_id,
            product_id,
            quantity,
            minimum_stock,
            maximum_stock,
            updated_by
        ) VALUES (
            p_warehouse_id,
            p_product_id,
            0,
            0,
            NULL,
            p_performed_by
        );
        current_quantity := 0;
    END IF;
    
    -- حساب الكمية الجديدة
    new_quantity := current_quantity + p_quantity_change;
    
    -- التأكد من أن الكمية الجديدة ليست سالبة
    IF new_quantity < 0 THEN
        RAISE EXCEPTION 'الكمية الجديدة لا يمكن أن تكون سالبة. الكمية الحالية: %, التغيير المطلوب: %', current_quantity, p_quantity_change;
    END IF;
    
    -- تحديث المخزون
    UPDATE public.warehouse_inventory
    SET quantity = new_quantity,
        last_updated = NOW(),
        updated_by = p_performed_by
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    
    -- تحديد نوع المعاملة
    IF p_quantity_change > 0 THEN
        transaction_type := 'stock_in';
    ELSIF p_quantity_change < 0 THEN
        transaction_type := 'stock_out';
    ELSE
        transaction_type := 'adjustment';
    END IF;
    
    -- توليد رقم المعاملة
    transaction_number := generate_warehouse_transaction_number();
    
    -- إنشاء سجل المعاملة مع quantity_change
    INSERT INTO public.warehouse_transactions (
        transaction_number,
        type,
        warehouse_id,
        product_id,
        quantity,
        quantity_change,
        quantity_before,
        quantity_after,
        reason,
        reference_id,
        reference_type,
        performed_by
    ) VALUES (
        transaction_number,
        transaction_type,
        p_warehouse_id,
        p_product_id,
        ABS(p_quantity_change),
        p_quantity_change,
        current_quantity,
        new_quantity,
        p_reason,
        p_reference_id,
        p_reference_type,
        p_performed_by
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Grant permissions
GRANT EXECUTE ON FUNCTION update_warehouse_inventory(UUID, TEXT, INTEGER, UUID, TEXT, TEXT, TEXT) TO authenticated;

RAISE NOTICE '✅ Fixed warehouse_transactions quantity_change constraint violation issue';
