-- إصلاح صلاحيات المخازن وقيود المفاتيح الخارجية
-- Fix warehouse permissions and foreign key constraints

-- Step 1: Update RLS policies for warehouse creation to support both role formats
DROP POLICY IF EXISTS "المخازن قابلة للإنشاء من قبل المديرين" ON public.warehouses;
CREATE POLICY "المخازن قابلة للإنشاء من قبل المديرين"
    ON public.warehouses FOR INSERT
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

-- Step 2: Update RLS policies for warehouse updates
DROP POLICY IF EXISTS "المخازن قابلة للتحديث من قبل المديرين" ON public.warehouses;
CREATE POLICY "المخازن قابلة للتحديث من قبل المديرين"
    ON public.warehouses FOR UPDATE
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

-- Step 3: Update RLS policies for warehouse deletion
DROP POLICY IF EXISTS "المخازن قابلة للحذف من قبل المديرين" ON public.warehouses;
CREATE POLICY "المخازن قابلة للحذف من قبل المديرين"
    ON public.warehouses FOR DELETE
    USING (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid() 
                AND status = 'approved'
                AND role IN ('admin', 'owner')  -- Only admin and owner can delete warehouses
            )
        )
    );

-- Step 4: Add function to safely check warehouse deletion constraints
CREATE OR REPLACE FUNCTION check_warehouse_deletion_constraints(p_warehouse_id UUID)
RETURNS TABLE (
    can_delete BOOLEAN,
    active_requests INTEGER,
    inventory_items INTEGER,
    total_quantity INTEGER,
    blocking_reason TEXT
) AS $$
DECLARE
    request_count INTEGER := 0;
    active_request_count INTEGER := 0;
    inventory_count INTEGER := 0;
    total_qty INTEGER := 0;
    reason TEXT := '';
BEGIN
    -- Check warehouse requests
    SELECT COUNT(*) INTO request_count
    FROM public.warehouse_requests
    WHERE warehouse_id = p_warehouse_id;
    
    SELECT COUNT(*) INTO active_request_count
    FROM public.warehouse_requests
    WHERE warehouse_id = p_warehouse_id
    AND status NOT IN ('completed', 'cancelled');
    
    -- Check warehouse inventory
    SELECT COUNT(*), COALESCE(SUM(quantity), 0) INTO inventory_count, total_qty
    FROM public.warehouse_inventory
    WHERE warehouse_id = p_warehouse_id;
    
    -- Determine if deletion is allowed
    IF active_request_count > 0 THEN
        reason := format('يحتوي على %s طلب نشط', active_request_count);
        RETURN QUERY SELECT false, active_request_count, inventory_count, total_qty, reason;
    ELSIF inventory_count > 0 THEN
        reason := format('يحتوي على %s منتج في المخزون', inventory_count);
        RETURN QUERY SELECT false, active_request_count, inventory_count, total_qty, reason;
    ELSE
        reason := 'يمكن الحذف بأمان';
        RETURN QUERY SELECT true, active_request_count, inventory_count, total_qty, reason;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Add function for safe warehouse deletion
CREATE OR REPLACE FUNCTION safe_delete_warehouse(p_warehouse_id UUID)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    deleted_transactions INTEGER,
    deleted_requests INTEGER
) AS $$
DECLARE
    can_delete_result RECORD;
    deleted_trans_count INTEGER := 0;
    deleted_req_count INTEGER := 0;
BEGIN
    -- Check if warehouse can be deleted
    SELECT * INTO can_delete_result
    FROM check_warehouse_deletion_constraints(p_warehouse_id)
    LIMIT 1;
    
    IF NOT can_delete_result.can_delete THEN
        RETURN QUERY SELECT false, 
            format('لا يمكن حذف المخزن: %s', can_delete_result.blocking_reason),
            0, 0;
        RETURN;
    END IF;
    
    -- Delete completed/cancelled warehouse requests
    DELETE FROM public.warehouse_requests
    WHERE warehouse_id = p_warehouse_id
    AND status IN ('completed', 'cancelled');
    
    GET DIAGNOSTICS deleted_req_count = ROW_COUNT;
    
    -- Delete warehouse transactions (historical data)
    DELETE FROM public.warehouse_transactions
    WHERE warehouse_id = p_warehouse_id;
    
    GET DIAGNOSTICS deleted_trans_count = ROW_COUNT;
    
    -- Delete empty inventory records
    DELETE FROM public.warehouse_inventory
    WHERE warehouse_id = p_warehouse_id
    AND quantity = 0;
    
    -- Finally delete the warehouse
    DELETE FROM public.warehouses
    WHERE id = p_warehouse_id;
    
    RETURN QUERY SELECT true,
        format('تم حذف المخزن بنجاح. حُذف %s معاملة و %s طلب', 
               deleted_trans_count, deleted_req_count),
        deleted_trans_count,
        deleted_req_count;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Update foreign key constraints to be more flexible
-- Drop existing constraints if they exist
DO $$
BEGIN
    -- Drop warehouse_requests foreign key constraint
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'warehouse_requests_warehouse_id_fkey' 
        AND table_name = 'warehouse_requests'
    ) THEN
        ALTER TABLE public.warehouse_requests 
        DROP CONSTRAINT warehouse_requests_warehouse_id_fkey;
    END IF;
    
    -- Add new constraint with better handling
    ALTER TABLE public.warehouse_requests 
    ADD CONSTRAINT warehouse_requests_warehouse_id_fkey 
    FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(id) 
    ON DELETE RESTRICT;  -- Prevent deletion if there are active requests
    
    -- Drop warehouse_inventory foreign key constraint
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'warehouse_inventory_warehouse_id_fkey' 
        AND table_name = 'warehouse_inventory'
    ) THEN
        ALTER TABLE public.warehouse_inventory 
        DROP CONSTRAINT warehouse_inventory_warehouse_id_fkey;
    END IF;
    
    -- Add new constraint with CASCADE for empty inventory
    ALTER TABLE public.warehouse_inventory 
    ADD CONSTRAINT warehouse_inventory_warehouse_id_fkey 
    FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(id) 
    ON DELETE RESTRICT;  -- Prevent deletion if there's inventory
    
    -- Drop warehouse_transactions foreign key constraint
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'warehouse_transactions_warehouse_id_fkey' 
        AND table_name = 'warehouse_transactions'
    ) THEN
        ALTER TABLE public.warehouse_transactions 
        DROP CONSTRAINT warehouse_transactions_warehouse_id_fkey;
    END IF;
    
    -- Add new constraint with CASCADE for transactions (historical data)
    ALTER TABLE public.warehouse_transactions 
    ADD CONSTRAINT warehouse_transactions_warehouse_id_fkey 
    FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(id) 
    ON DELETE CASCADE;  -- Allow deletion of historical transactions
END $$;

-- Step 7: Grant permissions for the new functions
GRANT EXECUTE ON FUNCTION check_warehouse_deletion_constraints(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION safe_delete_warehouse(UUID) TO authenticated;

-- Step 8: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_warehouse_requests_warehouse_id_status 
ON public.warehouse_requests(warehouse_id, status);

CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_warehouse_id_quantity 
ON public.warehouse_inventory(warehouse_id, quantity);

CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_warehouse_id 
ON public.warehouse_transactions(warehouse_id);

-- Step 9: Add helpful view for warehouse management
CREATE OR REPLACE VIEW warehouse_management_summary AS
SELECT 
    w.id,
    w.name,
    w.address,
    w.is_active,
    w.created_at,
    COALESCE(req_stats.total_requests, 0) as total_requests,
    COALESCE(req_stats.active_requests, 0) as active_requests,
    COALESCE(inv_stats.total_products, 0) as total_products,
    COALESCE(inv_stats.total_quantity, 0) as total_quantity,
    COALESCE(trans_stats.total_transactions, 0) as total_transactions,
    CASE 
        WHEN COALESCE(req_stats.active_requests, 0) > 0 OR COALESCE(inv_stats.total_quantity, 0) > 0 
        THEN false 
        ELSE true 
    END as can_be_deleted
FROM public.warehouses w
LEFT JOIN (
    SELECT 
        warehouse_id,
        COUNT(*) as total_requests,
        COUNT(*) FILTER (WHERE status NOT IN ('completed', 'cancelled')) as active_requests
    FROM public.warehouse_requests
    GROUP BY warehouse_id
) req_stats ON w.id = req_stats.warehouse_id
LEFT JOIN (
    SELECT 
        warehouse_id,
        COUNT(*) as total_products,
        SUM(quantity) as total_quantity
    FROM public.warehouse_inventory
    GROUP BY warehouse_id
) inv_stats ON w.id = inv_stats.warehouse_id
LEFT JOIN (
    SELECT 
        warehouse_id,
        COUNT(*) as total_transactions
    FROM public.warehouse_transactions
    GROUP BY warehouse_id
) trans_stats ON w.id = trans_stats.warehouse_id;

-- Grant access to the view
GRANT SELECT ON warehouse_management_summary TO authenticated;
