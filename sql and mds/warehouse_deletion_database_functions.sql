-- =====================================================
-- WAREHOUSE DELETION MANAGEMENT DATABASE FUNCTIONS
-- =====================================================
-- These functions support the enhanced warehouse deletion workflow
-- with comprehensive analysis and safe cleanup operations

-- 1. Enhanced warehouse deletion constraints check
-- This function provides detailed analysis of what's blocking warehouse deletion
CREATE OR REPLACE FUNCTION check_warehouse_deletion_constraints(p_warehouse_id TEXT)
RETURNS TABLE (
    can_delete BOOLEAN,
    active_requests INTEGER,
    inventory_items INTEGER,
    total_quantity INTEGER,
    recent_transactions INTEGER,
    blocking_reason TEXT
) AS $$
DECLARE
    v_active_requests INTEGER := 0;
    v_inventory_items INTEGER := 0;
    v_total_quantity INTEGER := 0;
    v_recent_transactions INTEGER := 0;
    v_can_delete BOOLEAN := TRUE;
    v_blocking_reasons TEXT[] := ARRAY[]::TEXT[];
    v_user_role TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles
    WHERE id = auth.uid() AND status = 'approved';

    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager') THEN
        RAISE EXCEPTION 'غير مصرح لك بالوصول لهذه الوظيفة';
    END IF;
    -- Check active requests
    SELECT COUNT(*)
    INTO v_active_requests
    FROM warehouse_requests
    WHERE warehouse_id = p_warehouse_id
    AND status NOT IN ('completed', 'cancelled');
    
    -- Check inventory items
    SELECT COUNT(*), COALESCE(SUM(quantity), 0)
    INTO v_inventory_items, v_total_quantity
    FROM warehouse_inventory
    WHERE warehouse_id = p_warehouse_id;
    
    -- Check recent transactions (last 30 days)
    SELECT COUNT(*)
    INTO v_recent_transactions
    FROM warehouse_transactions
    WHERE warehouse_id = p_warehouse_id
    AND performed_at > NOW() - INTERVAL '30 days';
    
    -- Determine blocking factors
    IF v_active_requests > 0 THEN
        v_can_delete := FALSE;
        v_blocking_reasons := array_append(v_blocking_reasons, v_active_requests || ' طلب نشط');
    END IF;
    
    IF v_inventory_items > 0 THEN
        v_can_delete := FALSE;
        v_blocking_reasons := array_append(v_blocking_reasons, v_inventory_items || ' منتج في المخزون');
    END IF;
    
    -- Return results
    RETURN QUERY SELECT 
        v_can_delete,
        v_active_requests,
        v_inventory_items,
        v_total_quantity,
        v_recent_transactions,
        CASE 
            WHEN array_length(v_blocking_reasons, 1) > 0 THEN array_to_string(v_blocking_reasons, ', ')
            ELSE 'لا توجد عوامل مانعة'
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Get detailed warehouse requests for deletion analysis
CREATE OR REPLACE FUNCTION get_warehouse_active_requests(p_warehouse_id TEXT)
RETURNS TABLE (
    request_id TEXT,
    request_type TEXT,
    status TEXT,
    reason TEXT,
    requested_by TEXT,
    requester_name TEXT,
    requester_email TEXT,
    created_at TIMESTAMP,
    age_in_days INTEGER
) AS $$
DECLARE
    v_user_role TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles
    WHERE id = auth.uid() AND status = 'approved';

    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager', 'accountant') THEN
        RAISE EXCEPTION 'غير مصرح لك بالوصول لهذه الوظيفة';
    END IF;
    RETURN QUERY
    SELECT 
        wr.id,
        wr.type,
        wr.status,
        COALESCE(wr.reason, '') as reason,
        wr.requested_by,
        COALESCE(up.name, 'غير معروف') as requester_name,
        COALESCE(up.email, '') as requester_email,
        wr.created_at,
        EXTRACT(DAY FROM NOW() - wr.created_at)::INTEGER as age_in_days
    FROM warehouse_requests wr
    LEFT JOIN user_profiles up ON wr.requested_by = up.id
    WHERE wr.warehouse_id = p_warehouse_id
    AND wr.status NOT IN ('completed', 'cancelled')
    ORDER BY wr.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Cancel warehouse request with audit logging
CREATE OR REPLACE FUNCTION cancel_warehouse_request(
    p_request_id TEXT,
    p_cancelled_by TEXT DEFAULT NULL,
    p_cancellation_reason TEXT DEFAULT 'إلغاء لحذف المخزن'
)
RETURNS BOOLEAN AS $$
DECLARE
    v_warehouse_id TEXT;
    v_request_type TEXT;
    v_user_role TEXT;
    v_cancelled_by TEXT;
BEGIN
    -- Check user authorization and get user ID
    SELECT role INTO v_user_role
    FROM user_profiles
    WHERE id = auth.uid() AND status = 'approved';

    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager') THEN
        RAISE EXCEPTION 'غير مصرح لك بإلغاء الطلبات';
    END IF;

    -- Use current user if no cancelled_by provided
    v_cancelled_by := COALESCE(p_cancelled_by, auth.uid()::TEXT);
    -- Get request details for logging
    SELECT warehouse_id, type
    INTO v_warehouse_id, v_request_type
    FROM warehouse_requests
    WHERE id = p_request_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'الطلب غير موجود: %', p_request_id;
    END IF;
    
    -- Update request status
    UPDATE warehouse_requests
    SET 
        status = 'cancelled',
        updated_at = NOW(),
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'cancelled_by', v_cancelled_by,
            'cancellation_reason', p_cancellation_reason,
            'cancelled_at', NOW()::text,
            'cancelled_for_warehouse_deletion', true
        )
    WHERE id = p_request_id;
    
    -- Log the cancellation
    INSERT INTO warehouse_deletion_audit_log (
        warehouse_id,
        action_type,
        action_details,
        performed_by,
        performed_at
    ) VALUES (
        v_warehouse_id,
        'request_cancelled',
        jsonb_build_object(
            'request_id', p_request_id,
            'request_type', v_request_type,
            'reason', p_cancellation_reason
        ),
        v_cancelled_by,
        NOW()
    );
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'فشل في إلغاء الطلب: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Archive warehouse transactions before deletion
CREATE OR REPLACE FUNCTION archive_warehouse_transactions(
    p_warehouse_id TEXT,
    p_archived_by TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_archived_count INTEGER := 0;
    v_user_role TEXT;
    v_archived_by TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles
    WHERE id = auth.uid() AND status = 'approved';

    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager') THEN
        RAISE EXCEPTION 'غير مصرح لك بأرشفة المعاملات';
    END IF;

    -- Use current user if no archived_by provided
    v_archived_by := COALESCE(p_archived_by, auth.uid()::TEXT);
    -- Create archive table if it doesn't exist
    CREATE TABLE IF NOT EXISTS warehouse_transactions_archive (
        LIKE warehouse_transactions INCLUDING ALL,
        archived_at TIMESTAMP DEFAULT NOW(),
        archived_by TEXT,
        archive_reason TEXT DEFAULT 'warehouse_deletion'
    );
    
    -- Copy transactions to archive
    INSERT INTO warehouse_transactions_archive (
        id, warehouse_id, product_id, type, quantity_change, 
        quantity_before, quantity_after, performed_by, performed_at,
        reason, reference_id, reference_type, transaction_number,
        created_at, updated_at, metadata,
        archived_at, archived_by, archive_reason
    )
    SELECT 
        id, warehouse_id, product_id, type, quantity_change,
        quantity_before, quantity_after, performed_by, performed_at,
        reason, reference_id, reference_type, transaction_number,
        created_at, updated_at, metadata,
        NOW(), v_archived_by, 'warehouse_deletion'
    FROM warehouse_transactions
    WHERE warehouse_id = p_warehouse_id;
    
    GET DIAGNOSTICS v_archived_count = ROW_COUNT;
    
    -- Log the archiving
    INSERT INTO warehouse_deletion_audit_log (
        warehouse_id,
        action_type,
        action_details,
        performed_by,
        performed_at
    ) VALUES (
        p_warehouse_id,
        'transactions_archived',
        jsonb_build_object(
            'archived_count', v_archived_count,
            'archive_table', 'warehouse_transactions_archive'
        ),
        v_archived_by,
        NOW()
    );

    RETURN v_archived_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Safe warehouse cleanup with cascading options
CREATE OR REPLACE FUNCTION cleanup_warehouse_for_deletion(
    p_warehouse_id TEXT,
    p_performed_by TEXT DEFAULT NULL,
    p_cleanup_options JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB := '{}'::jsonb;
    v_cancelled_requests INTEGER := 0;
    v_archived_transactions INTEGER := 0;
    v_moved_inventory INTEGER := 0;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_target_warehouse_id TEXT;
    v_force_delete BOOLEAN := FALSE;
    v_user_role TEXT;
    v_performed_by TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles
    WHERE id = auth.uid() AND status = 'approved';

    IF v_user_role NOT IN ('admin', 'owner') THEN
        RAISE EXCEPTION 'غير مصرح لك بتنظيف المخازن للحذف';
    END IF;

    -- Use current user if no performed_by provided
    v_performed_by := COALESCE(p_performed_by, auth.uid()::TEXT);
    -- Parse cleanup options
    v_target_warehouse_id := p_cleanup_options->>'target_warehouse_id';
    v_force_delete := COALESCE((p_cleanup_options->>'force_delete')::BOOLEAN, FALSE);
    
    -- Start cleanup process
    BEGIN
        -- 1. Cancel active requests
        SELECT COUNT(*)
        INTO v_cancelled_requests
        FROM warehouse_requests
        WHERE warehouse_id = p_warehouse_id
        AND status NOT IN ('completed', 'cancelled');
        
        UPDATE warehouse_requests
        SET 
            status = 'cancelled',
            updated_at = NOW(),
            metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
                'cancelled_by', v_performed_by,
                'cancellation_reason', 'تنظيف لحذف المخزن',
                'cancelled_at', NOW()::text
            )
        WHERE warehouse_id = p_warehouse_id
        AND status NOT IN ('completed', 'cancelled');
        
    EXCEPTION
        WHEN OTHERS THEN
            v_errors := array_append(v_errors, 'فشل في إلغاء الطلبات: ' || SQLERRM);
    END;
    
    -- 2. Archive transactions
    BEGIN
        v_archived_transactions := archive_warehouse_transactions(p_warehouse_id, v_performed_by);
    EXCEPTION
        WHEN OTHERS THEN
            v_errors := array_append(v_errors, 'فشل في أرشفة المعاملات: ' || SQLERRM);
    END;
    
    -- 3. Handle inventory
    BEGIN
        IF v_target_warehouse_id IS NOT NULL THEN
            -- Move inventory to target warehouse
            INSERT INTO warehouse_inventory (warehouse_id, product_id, quantity, minimum_stock, maximum_stock)
            SELECT 
                v_target_warehouse_id,
                product_id,
                quantity,
                minimum_stock,
                maximum_stock
            FROM warehouse_inventory
            WHERE warehouse_id = p_warehouse_id
            ON CONFLICT (warehouse_id, product_id) 
            DO UPDATE SET 
                quantity = warehouse_inventory.quantity + EXCLUDED.quantity,
                updated_at = NOW();
                
            GET DIAGNOSTICS v_moved_inventory = ROW_COUNT;
            
        ELSIF v_force_delete THEN
            -- Force delete inventory (with warning)
            SELECT COUNT(*) INTO v_moved_inventory FROM warehouse_inventory WHERE warehouse_id = p_warehouse_id;
        END IF;
        
        -- Delete inventory records
        DELETE FROM warehouse_inventory WHERE warehouse_id = p_warehouse_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            v_errors := array_append(v_errors, 'فشل في معالجة المخزون: ' || SQLERRM);
    END;
    
    -- Build result
    v_result := jsonb_build_object(
        'success', array_length(v_errors, 1) IS NULL,
        'cancelled_requests', v_cancelled_requests,
        'archived_transactions', v_archived_transactions,
        'processed_inventory_items', v_moved_inventory,
        'errors', v_errors,
        'cleanup_options', p_cleanup_options
    );
    
    -- Log cleanup completion
    INSERT INTO warehouse_deletion_audit_log (
        warehouse_id,
        action_type,
        action_details,
        performed_by,
        performed_at
    ) VALUES (
        p_warehouse_id,
        'cleanup_completed',
        v_result,
        v_performed_by,
        NOW()
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Create audit log table for warehouse deletion tracking
CREATE TABLE IF NOT EXISTS warehouse_deletion_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    warehouse_id TEXT NOT NULL,
    action_type TEXT NOT NULL, -- 'analysis', 'request_cancelled', 'transactions_archived', 'cleanup_completed', 'deletion_completed'
    action_details JSONB,
    performed_by TEXT,
    performed_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_warehouse_deletion_audit_warehouse_id 
ON warehouse_deletion_audit_log(warehouse_id);

CREATE INDEX IF NOT EXISTS idx_warehouse_deletion_audit_performed_at 
ON warehouse_deletion_audit_log(performed_at);

CREATE INDEX IF NOT EXISTS idx_warehouse_deletion_audit_action_type 
ON warehouse_deletion_audit_log(action_type);

-- 7. Get warehouse deletion audit trail
CREATE OR REPLACE FUNCTION get_warehouse_deletion_audit_trail(p_warehouse_id TEXT)
RETURNS TABLE (
    action_type TEXT,
    action_details JSONB,
    performed_by TEXT,
    performed_at TIMESTAMP
) AS $$
DECLARE
    v_user_role TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles
    WHERE id = auth.uid() AND status = 'approved';

    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager', 'accountant') THEN
        RAISE EXCEPTION 'غير مصرح لك بالوصول لسجل التدقيق';
    END IF;
    RETURN QUERY
    SELECT 
        wdal.action_type,
        wdal.action_details,
        wdal.performed_by,
        wdal.performed_at
    FROM warehouse_deletion_audit_log wdal
    WHERE wdal.warehouse_id = p_warehouse_id
    ORDER BY wdal.performed_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Supabase-compatible RLS policies and permissions
-- Enable RLS on audit log table
ALTER TABLE warehouse_deletion_audit_log ENABLE ROW LEVEL SECURITY;

-- RLS policy for warehouse deletion audit log - read access
CREATE POLICY "warehouse_deletion_audit_read" ON warehouse_deletion_audit_log
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.status = 'approved'
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager', 'accountant')
        )
    );

-- RLS policy for warehouse deletion audit log - insert access
CREATE POLICY "warehouse_deletion_audit_insert" ON warehouse_deletion_audit_log
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.status = 'approved'
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager')
        )
    );

-- Grant basic table permissions to authenticated users (RLS will control access)
GRANT SELECT, INSERT ON warehouse_deletion_audit_log TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Create archive table with RLS if it doesn't exist
CREATE TABLE IF NOT EXISTS warehouse_transactions_archive (
    LIKE warehouse_transactions INCLUDING ALL,
    archived_at TIMESTAMP DEFAULT NOW(),
    archived_by TEXT,
    archive_reason TEXT DEFAULT 'warehouse_deletion'
);

-- Enable RLS on archive table
ALTER TABLE warehouse_transactions_archive ENABLE ROW LEVEL SECURITY;

-- RLS policy for archive table - read access
CREATE POLICY "warehouse_transactions_archive_read" ON warehouse_transactions_archive
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.status = 'approved'
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager', 'accountant')
        )
    );

-- Grant basic permissions (RLS controls access)
GRANT SELECT ON warehouse_transactions_archive TO authenticated;

-- =====================================================
-- FORCE DELETION WITH AUTOMATIC ORDER TRANSFER FUNCTIONS
-- =====================================================

-- 6. Get available target warehouses for order transfer
CREATE OR REPLACE FUNCTION get_available_target_warehouses(
    p_source_warehouse_id TEXT,
    p_exclude_empty BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    warehouse_id TEXT,
    warehouse_name TEXT,
    warehouse_location TEXT,
    total_capacity INTEGER,
    current_inventory_count INTEGER,
    available_capacity INTEGER,
    suitability_score INTEGER
) AS $$
DECLARE
    v_user_role TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles
    WHERE id = auth.uid() AND status = 'approved';

    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager') THEN
        RAISE EXCEPTION 'غير مصرح لك بالوصول لهذه الوظيفة';
    END IF;

    RETURN QUERY
    SELECT
        w.id::TEXT,
        w.name,
        COALESCE(w.location, 'غير محدد'),
        COALESCE(w.capacity, 1000) as total_cap,
        COALESCE(inv_count.count, 0) as current_inv,
        GREATEST(0, COALESCE(w.capacity, 1000) - COALESCE(inv_count.count, 0)) as available_cap,
        -- Suitability score based on capacity and current load
        CASE
            WHEN COALESCE(inv_count.count, 0) = 0 THEN 100
            WHEN COALESCE(w.capacity, 1000) > COALESCE(inv_count.count, 0) * 2 THEN 80
            WHEN COALESCE(w.capacity, 1000) > COALESCE(inv_count.count, 0) THEN 60
            ELSE 40
        END as suitability
    FROM warehouses w
    LEFT JOIN (
        SELECT
            warehouse_id,
            COUNT(*) as count
        FROM warehouse_inventory
        WHERE quantity > 0
        GROUP BY warehouse_id
    ) inv_count ON w.id::TEXT = inv_count.warehouse_id
    WHERE w.id::TEXT != p_source_warehouse_id
    AND w.status = 'active'
    AND (NOT p_exclude_empty OR COALESCE(inv_count.count, 0) > 0 OR COALESCE(w.capacity, 1000) > 100)
    ORDER BY suitability DESC, available_cap DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Validate order transfer feasibility
CREATE OR REPLACE FUNCTION validate_order_transfer(
    p_source_warehouse_id TEXT,
    p_target_warehouse_id TEXT,
    p_order_ids TEXT[] DEFAULT NULL
)
RETURNS TABLE (
    is_valid BOOLEAN,
    transferable_orders INTEGER,
    blocked_orders INTEGER,
    validation_errors TEXT[],
    transfer_summary JSONB
) AS $$
DECLARE
    v_user_role TEXT;
    v_transferable_count INTEGER := 0;
    v_blocked_count INTEGER := 0;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_target_warehouse_exists BOOLEAN := FALSE;
    v_summary JSONB;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles
    WHERE id = auth.uid() AND status = 'approved';

    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager') THEN
        RAISE EXCEPTION 'غير مصرح لك بالوصول لهذه الوظيفة';
    END IF;

    -- Check if target warehouse exists and is active
    SELECT EXISTS(
        SELECT 1 FROM warehouses
        WHERE id::TEXT = p_target_warehouse_id
        AND status = 'active'
    ) INTO v_target_warehouse_exists;

    IF NOT v_target_warehouse_exists THEN
        v_errors := array_append(v_errors, 'المخزن الهدف غير موجود أو غير نشط');
    END IF;

    -- Count transferable and blocked orders
    IF p_order_ids IS NULL THEN
        -- Count all active orders in source warehouse
        SELECT
            COUNT(*) FILTER (WHERE status IN ('pending', 'approved', 'in_progress')),
            COUNT(*) FILTER (WHERE status NOT IN ('pending', 'approved', 'in_progress'))
        INTO v_transferable_count, v_blocked_count
        FROM warehouse_requests
        WHERE warehouse_id = p_source_warehouse_id;
    ELSE
        -- Count specific orders
        SELECT
            COUNT(*) FILTER (WHERE status IN ('pending', 'approved', 'in_progress')),
            COUNT(*) FILTER (WHERE status NOT IN ('pending', 'approved', 'in_progress'))
        INTO v_transferable_count, v_blocked_count
        FROM warehouse_requests
        WHERE warehouse_id = p_source_warehouse_id
        AND id = ANY(p_order_ids);
    END IF;

    -- Build summary
    v_summary := jsonb_build_object(
        'source_warehouse_id', p_source_warehouse_id,
        'target_warehouse_id', p_target_warehouse_id,
        'total_orders_checked', v_transferable_count + v_blocked_count,
        'transferable_orders', v_transferable_count,
        'blocked_orders', v_blocked_count,
        'target_warehouse_valid', v_target_warehouse_exists
    );

    RETURN QUERY SELECT
        (array_length(v_errors, 1) IS NULL AND v_target_warehouse_exists),
        v_transferable_count,
        v_blocked_count,
        v_errors,
        v_summary;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Example usage queries:

-- Check if warehouse can be deleted
-- SELECT * FROM check_warehouse_deletion_constraints('77510647-5f3b-49e9-8a8a-bcd8e77eaecd');

-- Get available target warehouses
-- SELECT * FROM get_available_target_warehouses('77510647-5f3b-49e9-8a8a-bcd8e77eaecd');

-- Validate order transfer
-- SELECT * FROM validate_order_transfer('source-warehouse-id', 'target-warehouse-id');

-- Get active requests for a warehouse
-- SELECT * FROM get_warehouse_active_requests('77510647-5f3b-49e9-8a8a-bcd8e77eaecd');

-- Cancel a specific request
-- SELECT cancel_warehouse_request('request-id', 'user-id', 'إلغاء لحذف المخزن');

-- 8. Execute automatic order transfer
CREATE OR REPLACE FUNCTION execute_order_transfer(
    p_source_warehouse_id TEXT,
    p_target_warehouse_id TEXT,
    p_order_ids TEXT[] DEFAULT NULL,
    p_performed_by TEXT DEFAULT NULL,
    p_transfer_reason TEXT DEFAULT 'نقل طلبات لحذف المخزن'
)
RETURNS JSONB AS $$
DECLARE
    v_user_role TEXT;
    v_performed_by TEXT;
    v_transferred_count INTEGER := 0;
    v_failed_count INTEGER := 0;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_validation_result RECORD;
    v_order_record RECORD;
    v_transfer_id TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles
    WHERE id = auth.uid() AND status = 'approved';

    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager') THEN
        RAISE EXCEPTION 'غير مصرح لك بتنفيذ نقل الطلبات';
    END IF;

    -- Use current user if no performed_by provided
    v_performed_by := COALESCE(p_performed_by, auth.uid()::TEXT);

    -- Validate transfer first
    SELECT * INTO v_validation_result
    FROM validate_order_transfer(p_source_warehouse_id, p_target_warehouse_id, p_order_ids);

    IF NOT v_validation_result.is_valid THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'فشل في التحقق من صحة النقل',
            'validation_errors', array_to_json(v_validation_result.validation_errors),
            'transferred_count', 0,
            'failed_count', 0
        );
    END IF;

    -- Generate transfer ID for tracking
    v_transfer_id := gen_random_uuid()::TEXT;

    -- Transfer orders
    FOR v_order_record IN
        SELECT id, request_number, status, requested_by
        FROM warehouse_requests
        WHERE warehouse_id = p_source_warehouse_id
        AND status IN ('pending', 'approved', 'in_progress')
        AND (p_order_ids IS NULL OR id = ANY(p_order_ids))
    LOOP
        BEGIN
            -- Update warehouse_id for the order
            UPDATE warehouse_requests
            SET
                warehouse_id = p_target_warehouse_id,
                updated_at = NOW(),
                metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
                    'transferred_from', p_source_warehouse_id,
                    'transfer_id', v_transfer_id,
                    'transfer_reason', p_transfer_reason,
                    'transferred_by', v_performed_by,
                    'transferred_at', NOW()
                )
            WHERE id = v_order_record.id;

            v_transferred_count := v_transferred_count + 1;

            -- Log the transfer
            INSERT INTO warehouse_deletion_audit_log (
                warehouse_id,
                action_type,
                action_details,
                performed_by,
                performed_at
            ) VALUES (
                p_source_warehouse_id,
                'order_transferred',
                jsonb_build_object(
                    'order_id', v_order_record.id,
                    'order_number', v_order_record.request_number,
                    'target_warehouse_id', p_target_warehouse_id,
                    'transfer_id', v_transfer_id,
                    'reason', p_transfer_reason
                ),
                v_performed_by,
                NOW()
            );

        EXCEPTION WHEN OTHERS THEN
            v_failed_count := v_failed_count + 1;
            v_errors := array_append(v_errors,
                format('فشل في نقل الطلب %s: %s', v_order_record.request_number, SQLERRM));
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'success', v_transferred_count > 0,
        'transferred_count', v_transferred_count,
        'failed_count', v_failed_count,
        'transfer_id', v_transfer_id,
        'errors', array_to_json(v_errors),
        'summary', jsonb_build_object(
            'source_warehouse_id', p_source_warehouse_id,
            'target_warehouse_id', p_target_warehouse_id,
            'total_processed', v_transferred_count + v_failed_count,
            'success_rate',
                CASE
                    WHEN (v_transferred_count + v_failed_count) > 0
                    THEN round((v_transferred_count::DECIMAL / (v_transferred_count + v_failed_count)) * 100, 2)
                    ELSE 0
                END
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cleanup warehouse for deletion
-- SELECT cleanup_warehouse_for_deletion(
--     '77510647-5f3b-49e9-8a8a-bcd8e77eaecd',
--     'user-id',
--     '{"force_delete": true}'::jsonb
-- );

-- 9. Force delete warehouse with automatic order transfer
CREATE OR REPLACE FUNCTION force_delete_warehouse_with_transfer(
    p_warehouse_id TEXT,
    p_target_warehouse_id TEXT,
    p_performed_by TEXT DEFAULT NULL,
    p_force_options JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB AS $$
DECLARE
    v_user_role TEXT;
    v_performed_by TEXT;
    v_warehouse_name TEXT;
    v_transfer_result JSONB;
    v_cleanup_result JSONB;
    v_deletion_successful BOOLEAN := FALSE;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_start_time TIMESTAMP := NOW();
    v_operation_id TEXT;
BEGIN
    -- Check user authorization (only admin and owner can force delete)
    SELECT role INTO v_user_role
    FROM user_profiles
    WHERE id = auth.uid() AND status = 'approved';

    IF v_user_role NOT IN ('admin', 'owner') THEN
        RAISE EXCEPTION 'غير مصرح لك بالحذف القسري للمخازن';
    END IF;

    -- Use current user if no performed_by provided
    v_performed_by := COALESCE(p_performed_by, auth.uid()::TEXT);
    v_operation_id := gen_random_uuid()::TEXT;

    -- Get warehouse name for logging
    SELECT name INTO v_warehouse_name
    FROM warehouses
    WHERE id::TEXT = p_warehouse_id;

    IF v_warehouse_name IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المخزن غير موجود',
            'operation_id', v_operation_id
        );
    END IF;

    -- Log start of force deletion
    INSERT INTO warehouse_deletion_audit_log (
        warehouse_id,
        action_type,
        action_details,
        performed_by,
        performed_at
    ) VALUES (
        p_warehouse_id,
        'force_deletion_started',
        jsonb_build_object(
            'warehouse_name', v_warehouse_name,
            'target_warehouse_id', p_target_warehouse_id,
            'operation_id', v_operation_id,
            'force_options', p_force_options
        ),
        v_performed_by,
        v_start_time
    );

    -- Step 1: Transfer orders to target warehouse
    BEGIN
        SELECT execute_order_transfer(
            p_warehouse_id,
            p_target_warehouse_id,
            NULL, -- Transfer all orders
            v_performed_by,
            'نقل طلبات للحذف القسري للمخزن'
        ) INTO v_transfer_result;

        IF NOT (v_transfer_result->>'success')::BOOLEAN THEN
            v_errors := array_append(v_errors, 'فشل في نقل الطلبات: ' || (v_transfer_result->>'error'));
        END IF;

    EXCEPTION WHEN OTHERS THEN
        v_errors := array_append(v_errors, 'خطأ في نقل الطلبات: ' || SQLERRM);
        v_transfer_result := jsonb_build_object('success', false, 'error', SQLERRM);
    END;

    -- Step 2: Cleanup warehouse (inventory, transactions, etc.)
    BEGIN
        SELECT cleanup_warehouse_for_deletion(
            p_warehouse_id,
            v_performed_by,
            p_force_options || jsonb_build_object('force_delete', true)
        ) INTO v_cleanup_result;

        IF NOT (v_cleanup_result->>'success')::BOOLEAN THEN
            v_errors := array_append(v_errors, 'فشل في تنظيف المخزن: ' || (v_cleanup_result->>'message'));
        END IF;

    EXCEPTION WHEN OTHERS THEN
        v_errors := array_append(v_errors, 'خطأ في تنظيف المخزن: ' || SQLERRM);
        v_cleanup_result := jsonb_build_object('success', false, 'message', SQLERRM);
    END;

    -- Step 3: Delete the warehouse itself
    BEGIN
        DELETE FROM warehouses WHERE id::TEXT = p_warehouse_id;
        v_deletion_successful := TRUE;

    EXCEPTION WHEN OTHERS THEN
        v_errors := array_append(v_errors, 'فشل في حذف المخزن: ' || SQLERRM);
        v_deletion_successful := FALSE;
    END;

    -- Log completion
    INSERT INTO warehouse_deletion_audit_log (
        warehouse_id,
        action_type,
        action_details,
        performed_by,
        performed_at
    ) VALUES (
        p_warehouse_id,
        CASE WHEN v_deletion_successful THEN 'force_deletion_completed' ELSE 'force_deletion_failed' END,
        jsonb_build_object(
            'warehouse_name', v_warehouse_name,
            'operation_id', v_operation_id,
            'success', v_deletion_successful,
            'duration_seconds', EXTRACT(EPOCH FROM (NOW() - v_start_time)),
            'transfer_result', v_transfer_result,
            'cleanup_result', v_cleanup_result,
            'errors', array_to_json(v_errors)
        ),
        v_performed_by,
        NOW()
    );

    RETURN jsonb_build_object(
        'success', v_deletion_successful,
        'operation_id', v_operation_id,
        'warehouse_name', v_warehouse_name,
        'duration_seconds', EXTRACT(EPOCH FROM (NOW() - v_start_time)),
        'transfer_result', v_transfer_result,
        'cleanup_result', v_cleanup_result,
        'errors', array_to_json(v_errors),
        'summary', jsonb_build_object(
            'orders_transferred', COALESCE((v_transfer_result->>'transferred_count')::INTEGER, 0),
            'cleanup_successful', COALESCE((v_cleanup_result->>'success')::BOOLEAN, false),
            'warehouse_deleted', v_deletion_successful,
            'total_errors', array_length(v_errors, 1)
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute order transfer
-- SELECT execute_order_transfer('source-warehouse-id', 'target-warehouse-id');

-- Force delete warehouse with order transfer
-- SELECT force_delete_warehouse_with_transfer('warehouse-id', 'target-warehouse-id');

-- Get audit trail
-- SELECT * FROM get_warehouse_deletion_audit_trail('77510647-5f3b-49e9-8a8a-bcd8e77eaecd');
