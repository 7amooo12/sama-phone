-- =====================================================
-- GLOBAL INVENTORY MANAGEMENT DATABASE FUNCTIONS
-- =====================================================
-- These functions support automated inventory deduction and global search

-- 1. Function to deduct inventory with validation and transaction logging
CREATE OR REPLACE FUNCTION deduct_inventory_with_validation(
    p_warehouse_id TEXT,
    p_product_id TEXT,
    p_quantity INTEGER,
    p_performed_by TEXT,
    p_reason TEXT,
    p_reference_id TEXT DEFAULT NULL,
    p_reference_type TEXT DEFAULT 'manual'
)
RETURNS JSONB AS $$
DECLARE
    v_current_quantity INTEGER := 0;
    v_minimum_stock INTEGER := 0;
    v_new_quantity INTEGER := 0;
    v_transaction_id TEXT;
    v_user_role TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles 
    WHERE id = auth.uid() AND status = 'approved';
    
    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager', 'accountant') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'غير مصرح لك بخصم المخزون'
        );
    END IF;

    -- Get current inventory
    SELECT quantity, minimum_stock
    INTO v_current_quantity, v_minimum_stock
    FROM warehouse_inventory
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المنتج غير موجود في هذا المخزن'
        );
    END IF;
    
    -- Validate quantity
    IF p_quantity <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'الكمية يجب أن تكون أكبر من صفر'
        );
    END IF;
    
    IF v_current_quantity < p_quantity THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'الكمية المطلوبة (' || p_quantity || ') أكبر من المتاح (' || v_current_quantity || ')'
        );
    END IF;
    
    -- Calculate new quantity
    v_new_quantity := v_current_quantity - p_quantity;
    
    -- Update inventory
    UPDATE warehouse_inventory
    SET 
        quantity = v_new_quantity,
        last_updated = NOW(),
        updated_at = NOW()
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    
    -- Create transaction record
    v_transaction_id := gen_random_uuid()::TEXT;
    
    INSERT INTO warehouse_transactions (
        id,
        warehouse_id,
        product_id,
        type,
        quantity_change,
        quantity_before,
        quantity_after,
        performed_by,
        performed_at,
        reason,
        reference_id,
        reference_type,
        transaction_number,
        created_at,
        updated_at
    ) VALUES (
        v_transaction_id,
        p_warehouse_id,
        p_product_id,
        'withdrawal',
        -p_quantity,
        v_current_quantity,
        v_new_quantity,
        p_performed_by,
        NOW(),
        p_reason,
        p_reference_id,
        p_reference_type,
        'TXN-' || EXTRACT(EPOCH FROM NOW())::BIGINT || '-' || SUBSTRING(v_transaction_id, 1, 8),
        NOW(),
        NOW()
    );
    
    -- Log the deduction for audit
    INSERT INTO global_inventory_audit_log (
        warehouse_id,
        product_id,
        action_type,
        action_details,
        performed_by,
        performed_at
    ) VALUES (
        p_warehouse_id,
        p_product_id,
        'inventory_deduction',
        jsonb_build_object(
            'quantity_deducted', p_quantity,
            'quantity_before', v_current_quantity,
            'quantity_after', v_new_quantity,
            'reason', p_reason,
            'reference_id', p_reference_id,
            'reference_type', p_reference_type,
            'transaction_id', v_transaction_id,
            'minimum_stock_warning', v_new_quantity <= v_minimum_stock
        ),
        p_performed_by,
        NOW()
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_transaction_id,
        'quantity_before', v_current_quantity,
        'quantity_after', v_new_quantity,
        'remaining_quantity', v_new_quantity,
        'minimum_stock_warning', v_new_quantity <= v_minimum_stock,
        'deducted_quantity', p_quantity
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في خصم المخزون: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Function to search for product availability across all warehouses
CREATE OR REPLACE FUNCTION search_product_globally(
    p_product_id TEXT,
    p_requested_quantity INTEGER DEFAULT 1,
    p_exclude_warehouses TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS TABLE (
    warehouse_id TEXT,
    warehouse_name TEXT,
    warehouse_priority INTEGER,
    available_quantity INTEGER,
    minimum_stock INTEGER,
    maximum_stock INTEGER,
    can_allocate INTEGER,
    last_updated TIMESTAMP
) AS $$
DECLARE
    v_user_role TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles 
    WHERE id = auth.uid() AND status = 'approved';
    
    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager', 'accountant', 'worker') THEN
        RAISE EXCEPTION 'غير مصرح لك بالبحث في المخزون العالمي';
    END IF;

    RETURN QUERY
    SELECT 
        wi.warehouse_id,
        w.name as warehouse_name,
        COALESCE(w.priority, 0) as warehouse_priority,
        wi.quantity as available_quantity,
        COALESCE(wi.minimum_stock, 0) as minimum_stock,
        COALESCE(wi.maximum_stock, 0) as maximum_stock,
        GREATEST(0, wi.quantity - COALESCE(wi.minimum_stock, 0)) as can_allocate,
        wi.last_updated
    FROM warehouse_inventory wi
    JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE wi.product_id = p_product_id
        AND w.is_active = true
        AND wi.quantity > 0
        AND NOT (wi.warehouse_id = ANY(p_exclude_warehouses))
    ORDER BY 
        COALESCE(w.priority, 0) DESC,
        wi.quantity DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Function to process withdrawal request automatically
CREATE OR REPLACE FUNCTION process_withdrawal_request_auto(
    p_request_id TEXT,
    p_performed_by TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_request_record RECORD;
    v_item_record RECORD;
    v_search_result RECORD;
    v_deduction_result JSONB;
    v_total_processed INTEGER := 0;
    v_total_requested INTEGER := 0;
    v_items_processed INTEGER := 0;
    v_items_successful INTEGER := 0;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_warehouses_involved TEXT[] := ARRAY[]::TEXT[];
    v_performed_by TEXT;
    v_user_role TEXT;
BEGIN
    -- Check user authorization and get user ID
    SELECT role INTO v_user_role
    FROM user_profiles 
    WHERE id = auth.uid() AND status = 'approved';
    
    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'غير مصرح لك بمعالجة طلبات السحب'
        );
    END IF;
    
    -- Use current user if no performed_by provided
    v_performed_by := COALESCE(p_performed_by, auth.uid()::TEXT);
    
    -- Get withdrawal request details
    SELECT * INTO v_request_record
    FROM warehouse_requests
    WHERE id = p_request_id AND type = 'withdrawal';
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'طلب السحب غير موجود'
        );
    END IF;
    
    IF v_request_record.status != 'completed' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'طلب السحب ليس في حالة مكتمل: ' || v_request_record.status
        );
    END IF;
    
    -- Process each item in the request
    FOR v_item_record IN 
        SELECT wri.*, p.name as product_name
        FROM warehouse_request_items wri
        LEFT JOIN products p ON wri.product_id = p.id
        WHERE wri.request_id = p_request_id
    LOOP
        v_items_processed := v_items_processed + 1;
        v_total_requested := v_total_requested + v_item_record.quantity;
        
        -- Search for product availability
        SELECT 
            SUM(available_quantity) as total_available,
            SUM(can_allocate) as total_allocatable
        INTO v_search_result
        FROM search_product_globally(v_item_record.product_id, v_item_record.quantity);
        
        IF v_search_result.total_allocatable >= v_item_record.quantity THEN
            -- Process deduction from warehouses
            DECLARE
                v_remaining_quantity INTEGER := v_item_record.quantity;
                v_warehouse_record RECORD;
            BEGIN
                FOR v_warehouse_record IN 
                    SELECT * FROM search_product_globally(v_item_record.product_id, v_item_record.quantity)
                    WHERE can_allocate > 0
                    ORDER BY warehouse_priority DESC, available_quantity DESC
                LOOP
                    IF v_remaining_quantity <= 0 THEN
                        EXIT;
                    END IF;
                    
                    DECLARE
                        v_deduct_quantity INTEGER := LEAST(v_remaining_quantity, v_warehouse_record.can_allocate);
                    BEGIN
                        -- Deduct from this warehouse
                        SELECT deduct_inventory_with_validation(
                            v_warehouse_record.warehouse_id,
                            v_item_record.product_id,
                            v_deduct_quantity,
                            v_performed_by,
                            'سحب تلقائي للطلب ' || p_request_id || ' - ' || COALESCE(v_item_record.product_name, v_item_record.product_id),
                            p_request_id,
                            'withdrawal_request'
                        ) INTO v_deduction_result;
                        
                        IF (v_deduction_result->>'success')::BOOLEAN THEN
                            v_remaining_quantity := v_remaining_quantity - v_deduct_quantity;
                            v_total_processed := v_total_processed + v_deduct_quantity;
                            v_warehouses_involved := array_append(v_warehouses_involved, v_warehouse_record.warehouse_id);
                        ELSE
                            v_errors := array_append(v_errors, 
                                'فشل خصم ' || v_deduct_quantity || ' من المخزن ' || v_warehouse_record.warehouse_name || 
                                ': ' || (v_deduction_result->>'error')
                            );
                        END IF;
                    END;
                END LOOP;
                
                IF v_remaining_quantity = 0 THEN
                    v_items_successful := v_items_successful + 1;
                ELSE
                    v_errors := array_append(v_errors, 
                        'لم يتم خصم ' || v_remaining_quantity || ' من المنتج ' || 
                        COALESCE(v_item_record.product_name, v_item_record.product_id)
                    );
                END IF;
            END;
        ELSE
            v_errors := array_append(v_errors, 
                'المخزون غير كافي للمنتج ' || COALESCE(v_item_record.product_name, v_item_record.product_id) || 
                ' - متاح: ' || COALESCE(v_search_result.total_allocatable, 0) || 
                ', مطلوب: ' || v_item_record.quantity
            );
        END IF;
    END LOOP;
    
    -- Update request metadata
    UPDATE warehouse_requests
    SET 
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'auto_processed', true,
            'processing_success', array_length(v_errors, 1) IS NULL,
            'processed_at', NOW()::text,
            'processed_by', v_performed_by,
            'items_processed', v_items_processed,
            'items_successful', v_items_successful,
            'total_requested', v_total_requested,
            'total_processed', v_total_processed,
            'warehouses_involved', v_warehouses_involved,
            'processing_errors', v_errors
        ),
        updated_at = NOW()
    WHERE id = p_request_id;
    
    -- Log the processing
    INSERT INTO global_inventory_audit_log (
        warehouse_id,
        product_id,
        action_type,
        action_details,
        performed_by,
        performed_at
    ) VALUES (
        NULL, -- Global operation
        NULL, -- Multiple products
        'withdrawal_request_processed',
        jsonb_build_object(
            'request_id', p_request_id,
            'items_processed', v_items_processed,
            'items_successful', v_items_successful,
            'total_requested', v_total_requested,
            'total_processed', v_total_processed,
            'warehouses_involved', v_warehouses_involved,
            'errors_count', array_length(v_errors, 1),
            'success', array_length(v_errors, 1) IS NULL
        ),
        v_performed_by,
        NOW()
    );
    
    RETURN jsonb_build_object(
        'success', array_length(v_errors, 1) IS NULL,
        'request_id', p_request_id,
        'items_processed', v_items_processed,
        'items_successful', v_items_successful,
        'total_requested', v_total_requested,
        'total_processed', v_total_processed,
        'warehouses_involved', v_warehouses_involved,
        'errors', v_errors,
        'processing_percentage', CASE WHEN v_total_requested > 0 THEN (v_total_processed::DECIMAL / v_total_requested * 100) ELSE 0 END
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في معالجة طلب السحب: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create audit log table for global inventory operations
CREATE TABLE IF NOT EXISTS global_inventory_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    warehouse_id TEXT, -- NULL for global operations
    product_id TEXT,   -- NULL for multi-product operations
    action_type TEXT NOT NULL, -- 'inventory_deduction', 'global_search', 'withdrawal_request_processed'
    action_details JSONB,
    performed_by TEXT,
    performed_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Enable RLS on audit log table
ALTER TABLE global_inventory_audit_log ENABLE ROW LEVEL SECURITY;

-- RLS policy for global inventory audit log - read access
CREATE POLICY "global_inventory_audit_read" ON global_inventory_audit_log
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.status = 'approved'
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager', 'accountant')
        )
    );

-- RLS policy for global inventory audit log - insert access
CREATE POLICY "global_inventory_audit_insert" ON global_inventory_audit_log
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.status = 'approved'
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager', 'accountant')
        )
    );

-- Grant permissions
GRANT SELECT, INSERT ON global_inventory_audit_log TO authenticated;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_global_inventory_audit_warehouse_id 
ON global_inventory_audit_log(warehouse_id);

CREATE INDEX IF NOT EXISTS idx_global_inventory_audit_product_id 
ON global_inventory_audit_log(product_id);

CREATE INDEX IF NOT EXISTS idx_global_inventory_audit_performed_at 
ON global_inventory_audit_log(performed_at);

CREATE INDEX IF NOT EXISTS idx_global_inventory_audit_action_type 
ON global_inventory_audit_log(action_type);

-- 5. Function to get global inventory summary for a product
CREATE OR REPLACE FUNCTION get_product_global_inventory_summary(p_product_id TEXT)
RETURNS TABLE (
    total_quantity INTEGER,
    total_warehouses INTEGER,
    warehouses_with_stock INTEGER,
    warehouses_low_stock INTEGER,
    warehouses_out_of_stock INTEGER,
    average_stock_per_warehouse DECIMAL,
    last_updated TIMESTAMP
) AS $$
DECLARE
    v_user_role TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles 
    WHERE id = auth.uid() AND status = 'approved';
    
    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager', 'accountant', 'worker') THEN
        RAISE EXCEPTION 'غير مصرح لك بالوصول لملخص المخزون العالمي';
    END IF;

    RETURN QUERY
    SELECT 
        COALESCE(SUM(wi.quantity), 0)::INTEGER as total_quantity,
        COUNT(*)::INTEGER as total_warehouses,
        COUNT(CASE WHEN wi.quantity > 0 THEN 1 END)::INTEGER as warehouses_with_stock,
        COUNT(CASE WHEN wi.quantity > 0 AND wi.quantity <= COALESCE(wi.minimum_stock, 0) THEN 1 END)::INTEGER as warehouses_low_stock,
        COUNT(CASE WHEN wi.quantity = 0 THEN 1 END)::INTEGER as warehouses_out_of_stock,
        CASE WHEN COUNT(CASE WHEN wi.quantity > 0 THEN 1 END) > 0 
             THEN (SUM(CASE WHEN wi.quantity > 0 THEN wi.quantity ELSE 0 END)::DECIMAL / COUNT(CASE WHEN wi.quantity > 0 THEN 1 END))
             ELSE 0 
        END as average_stock_per_warehouse,
        MAX(wi.last_updated) as last_updated
    FROM warehouse_inventory wi
    JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE wi.product_id = p_product_id
        AND w.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- TESTING QUERIES
-- =====================================================

-- Test global product search
/*
SELECT * FROM search_product_globally('your-product-id-here', 10);
*/

-- Test inventory deduction
/*
SELECT deduct_inventory_with_validation(
    'warehouse-id',
    'product-id', 
    5,
    'user-id',
    'Test deduction',
    'test-ref-123',
    'test'
);
*/

-- Test withdrawal request processing
/*
SELECT process_withdrawal_request_auto('withdrawal-request-id');
*/

-- Get product global summary
/*
SELECT * FROM get_product_global_inventory_summary('your-product-id-here');
*/

-- Check audit logs
/*
SELECT * FROM global_inventory_audit_log 
WHERE action_type = 'inventory_deduction' 
ORDER BY performed_at DESC 
LIMIT 10;
*/
