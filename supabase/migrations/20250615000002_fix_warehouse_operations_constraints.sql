-- إصلاح قيود عمليات المخازن وتحسين إدارة المنتجات
-- Fix warehouse operations constraints and improve product management

-- Step 1: Update warehouse_transactions table constraints
-- Remove the overly restrictive quantity_positive constraint and replace with better logic
DO $$
BEGIN
    -- Drop the existing constraint if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name = 'warehouse_transactions_quantity_positive'
        AND table_name = 'warehouse_transactions'
    ) THEN
        ALTER TABLE public.warehouse_transactions 
        DROP CONSTRAINT warehouse_transactions_quantity_positive;
    END IF;
    
    -- Add new constraint that allows positive quantities for all transaction types
    ALTER TABLE public.warehouse_transactions 
    ADD CONSTRAINT warehouse_transactions_quantity_valid 
    CHECK (quantity > 0);
    
    -- Add constraint for quantity_before and quantity_after to be non-negative
    ALTER TABLE public.warehouse_transactions 
    ADD CONSTRAINT warehouse_transactions_quantities_non_negative 
    CHECK (quantity_before >= 0 AND quantity_after >= 0);
END $$;

-- Step 2: Create function to ensure product exists before warehouse operations
CREATE OR REPLACE FUNCTION ensure_product_exists(
    p_product_id TEXT,
    p_product_name TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    product_exists BOOLEAN := FALSE;
BEGIN
    -- Check if product already exists
    SELECT EXISTS(
        SELECT 1 FROM public.products WHERE id = p_product_id
    ) INTO product_exists;
    
    IF product_exists THEN
        RETURN TRUE;
    END IF;
    
    -- Create default product if it doesn't exist
    INSERT INTO public.products (
        id,
        name,
        description,
        price,
        category,
        sku,
        active,
        quantity,
        images,
        minimum_stock,
        reorder_point,
        created_at,
        updated_at
    ) VALUES (
        p_product_id,
        COALESCE(p_product_name, 'منتج ' || p_product_id),
        'منتج تم إنشاؤه تلقائياً من نظام المخازن',
        0.0,
        'عام',
        'AUTO-' || p_product_id,
        true,
        0,
        '[]'::jsonb,
        10,
        10,
        NOW(),
        NOW()
    );
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return false
        RAISE WARNING 'Failed to create product %: %', p_product_id, SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Create function for safe warehouse inventory updates
CREATE OR REPLACE FUNCTION update_warehouse_inventory_safe(
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
    new_quantity INTEGER := 0;
    inventory_exists BOOLEAN := FALSE;
    transaction_type TEXT;
BEGIN
    -- Ensure product exists first
    IF NOT ensure_product_exists(p_product_id) THEN
        RAISE EXCEPTION 'فشل في التأكد من وجود المنتج: %', p_product_id;
    END IF;
    
    -- Check if inventory record exists
    SELECT quantity INTO current_quantity
    FROM public.warehouse_inventory
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    
    inventory_exists := FOUND;
    
    IF NOT inventory_exists THEN
        current_quantity := 0;
    END IF;
    
    -- Calculate new quantity
    new_quantity := current_quantity + p_quantity_change;
    
    -- Validate new quantity is not negative
    IF new_quantity < 0 THEN
        RAISE EXCEPTION 'الكمية الجديدة لا يمكن أن تكون سالبة. الكمية الحالية: %, التغيير: %', current_quantity, p_quantity_change;
    END IF;
    
    -- Determine transaction type
    IF p_quantity_change > 0 THEN
        transaction_type := 'addition';
    ELSE
        transaction_type := 'withdrawal';
    END IF;
    
    -- Create transaction record (always with positive quantity)
    INSERT INTO public.warehouse_transactions (
        warehouse_id,
        product_id,
        quantity,
        quantity_before,
        quantity_after,
        type,
        reason,
        performed_by,
        reference_id,
        reference_type,
        created_at
    ) VALUES (
        p_warehouse_id,
        p_product_id,
        ABS(p_quantity_change), -- Always positive
        current_quantity,
        new_quantity,
        transaction_type,
        p_reason,
        p_performed_by,
        p_reference_id,
        p_reference_type,
        NOW()
    );
    
    -- Update or create inventory record
    IF inventory_exists THEN
        IF new_quantity = 0 THEN
            -- Remove inventory record if quantity becomes zero
            DELETE FROM public.warehouse_inventory
            WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
        ELSE
            -- Update existing inventory
            UPDATE public.warehouse_inventory
            SET 
                quantity = new_quantity,
                last_updated = NOW(),
                updated_by = p_performed_by
            WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
        END IF;
    ELSE
        -- Create new inventory record (only if quantity > 0)
        IF new_quantity > 0 THEN
            INSERT INTO public.warehouse_inventory (
                warehouse_id,
                product_id,
                quantity,
                minimum_stock,
                maximum_stock,
                updated_by,
                last_updated
            ) VALUES (
                p_warehouse_id,
                p_product_id,
                new_quantity,
                10, -- Default minimum stock
                NULL, -- No maximum stock limit
                p_performed_by,
                NOW()
            );
        END IF;
    END IF;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'خطأ في تحديث المخزون: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create function for safe product removal from warehouse
CREATE OR REPLACE FUNCTION remove_product_from_warehouse_safe(
    p_warehouse_id UUID,
    p_product_id TEXT,
    p_performed_by UUID,
    p_reason TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    current_quantity INTEGER := 0;
    inventory_exists BOOLEAN := FALSE;
BEGIN
    -- Check if inventory record exists
    SELECT quantity INTO current_quantity
    FROM public.warehouse_inventory
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    
    inventory_exists := FOUND;
    
    IF NOT inventory_exists THEN
        RAISE EXCEPTION 'المنتج غير موجود في هذا المخزن';
    END IF;
    
    -- Create withdrawal transaction for the full quantity
    INSERT INTO public.warehouse_transactions (
        warehouse_id,
        product_id,
        quantity,
        quantity_before,
        quantity_after,
        type,
        reason,
        performed_by,
        reference_type,
        created_at
    ) VALUES (
        p_warehouse_id,
        p_product_id,
        current_quantity, -- Positive quantity withdrawn
        current_quantity,
        0,
        'withdrawal',
        p_reason,
        p_performed_by,
        'manual_removal',
        NOW()
    );
    
    -- Remove inventory record
    DELETE FROM public.warehouse_inventory
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'خطأ في حذف المنتج من المخزن: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Grant permissions for the new functions
GRANT EXECUTE ON FUNCTION ensure_product_exists(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION update_warehouse_inventory_safe(UUID, TEXT, INTEGER, UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_product_from_warehouse_safe(UUID, TEXT, UUID, TEXT) TO authenticated;

-- Step 6: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_warehouse_product 
ON public.warehouse_inventory(warehouse_id, product_id);

CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_warehouse_product_type 
ON public.warehouse_transactions(warehouse_id, product_id, type);

CREATE INDEX IF NOT EXISTS idx_products_active_name 
ON public.products(active, name) WHERE active = true;

-- Step 7: Update RLS policies for better product management
-- Allow authenticated users to create products for warehouse operations
DROP POLICY IF EXISTS "المنتجات قابلة للإنشاء من قبل المستخدمين المصرح لهم" ON public.products;
CREATE POLICY "المنتجات قابلة للإنشاء من قبل المستخدمين المصرح لهم"
    ON public.products FOR INSERT
    WITH CHECK (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() 
                AND status = 'approved'
                AND role IN ('admin', 'owner', 'warehouse_manager', 'warehouseManager', 'accountant')
            )
        )
    );

-- Step 8: Create helpful view for warehouse operations monitoring
CREATE OR REPLACE VIEW warehouse_operations_summary AS
SELECT 
    wt.warehouse_id,
    w.name as warehouse_name,
    wt.product_id,
    p.name as product_name,
    p.category,
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE wt.type = 'addition') as additions,
    COUNT(*) FILTER (WHERE wt.type = 'withdrawal') as withdrawals,
    SUM(wt.quantity) FILTER (WHERE wt.type = 'addition') as total_added,
    SUM(wt.quantity) FILTER (WHERE wt.type = 'withdrawal') as total_withdrawn,
    MAX(wt.created_at) as last_transaction,
    COALESCE(wi.quantity, 0) as current_quantity
FROM public.warehouse_transactions wt
LEFT JOIN public.warehouses w ON wt.warehouse_id = w.id
LEFT JOIN public.products p ON wt.product_id = p.id
LEFT JOIN public.warehouse_inventory wi ON wt.warehouse_id = wi.warehouse_id AND wt.product_id = wi.product_id
GROUP BY wt.warehouse_id, w.name, wt.product_id, p.name, p.category, wi.quantity
ORDER BY w.name, p.name;

-- Grant access to the view
GRANT SELECT ON warehouse_operations_summary TO authenticated;
