-- =====================================================
-- DATABASE SCHEMA MODIFICATIONS FOR GLOBAL WITHDRAWAL SYSTEM
-- =====================================================
-- These modifications remove warehouse dependencies from withdrawal requests
-- and enable global inventory search with automatic deduction

-- 1. Modify warehouse_requests table to make warehouse_id optional
-- First, check if the foreign key constraint exists and remove it
DO $$
BEGIN
    -- Drop foreign key constraint if it exists (try multiple possible names)
    BEGIN
        ALTER TABLE warehouse_requests DROP CONSTRAINT IF EXISTS warehouse_requests_warehouse_id_fkey;
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    BEGIN
        ALTER TABLE warehouse_requests DROP CONSTRAINT IF EXISTS fk_warehouse_requests_warehouse_id;
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    -- Also try to find and drop any constraint that references warehouses
    DECLARE
        constraint_name TEXT;
    BEGIN
        SELECT tc.constraint_name INTO constraint_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'warehouse_requests'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND ccu.table_name = 'warehouses'
        LIMIT 1;

        IF constraint_name IS NOT NULL THEN
            EXECUTE 'ALTER TABLE warehouse_requests DROP CONSTRAINT ' || constraint_name;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
END $$;

-- Make warehouse_id nullable to allow global withdrawal requests
ALTER TABLE warehouse_requests ALTER COLUMN warehouse_id DROP NOT NULL;

-- Add a new column to indicate if this is a global withdrawal request
ALTER TABLE warehouse_requests ADD COLUMN IF NOT EXISTS is_global_request BOOLEAN DEFAULT false;

-- Add metadata column for storing allocation and processing information
ALTER TABLE warehouse_requests ADD COLUMN IF NOT EXISTS processing_metadata JSONB DEFAULT '{}'::jsonb;

-- Add index for global requests
CREATE INDEX IF NOT EXISTS idx_warehouse_requests_global 
ON warehouse_requests(is_global_request) WHERE is_global_request = true;

-- Add index for processing metadata
CREATE INDEX IF NOT EXISTS idx_warehouse_requests_processing_metadata 
ON warehouse_requests USING gin(processing_metadata);

-- 2. Create a new table for tracking warehouse allocations per request
-- First, check the data type of warehouse_requests.id
DO $$
DECLARE
    id_data_type TEXT;
BEGIN
    SELECT data_type INTO id_data_type
    FROM information_schema.columns
    WHERE table_name = 'warehouse_requests' AND column_name = 'id';

    -- Create table with correct data type for request_id
    IF id_data_type = 'uuid' THEN
        CREATE TABLE IF NOT EXISTS warehouse_request_allocations (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            request_id UUID NOT NULL,
            warehouse_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            allocated_quantity INTEGER NOT NULL CHECK (allocated_quantity > 0),
            deducted_quantity INTEGER DEFAULT 0 CHECK (deducted_quantity >= 0),
            allocation_strategy TEXT NOT NULL DEFAULT 'balanced',
            allocation_priority INTEGER DEFAULT 1,
            allocation_reason TEXT,
            status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW(),
            processed_at TIMESTAMP,
            processed_by TEXT,
            UNIQUE(request_id, warehouse_id, product_id)
        );
    ELSE
        CREATE TABLE IF NOT EXISTS warehouse_request_allocations (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            request_id TEXT NOT NULL,
            warehouse_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            allocated_quantity INTEGER NOT NULL CHECK (allocated_quantity > 0),
            deducted_quantity INTEGER DEFAULT 0 CHECK (deducted_quantity >= 0),
            allocation_strategy TEXT NOT NULL DEFAULT 'balanced',
            allocation_priority INTEGER DEFAULT 1,
            allocation_reason TEXT,
            status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW(),
            processed_at TIMESTAMP,
            processed_by TEXT,
            UNIQUE(request_id, warehouse_id, product_id)
        );
    END IF;
END $$;

-- Enable RLS on allocations table
ALTER TABLE warehouse_request_allocations ENABLE ROW LEVEL SECURITY;

-- RLS policy for warehouse request allocations - read access
CREATE POLICY "warehouse_request_allocations_read" ON warehouse_request_allocations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.status = 'approved'
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager', 'accountant', 'worker')
        )
    );

-- RLS policy for warehouse request allocations - insert/update access
CREATE POLICY "warehouse_request_allocations_write" ON warehouse_request_allocations
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.status = 'approved'
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager', 'accountant')
        )
    );

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON warehouse_request_allocations TO authenticated;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_warehouse_request_allocations_request_id 
ON warehouse_request_allocations(request_id);

CREATE INDEX IF NOT EXISTS idx_warehouse_request_allocations_warehouse_id 
ON warehouse_request_allocations(warehouse_id);

CREATE INDEX IF NOT EXISTS idx_warehouse_request_allocations_product_id 
ON warehouse_request_allocations(product_id);

CREATE INDEX IF NOT EXISTS idx_warehouse_request_allocations_status 
ON warehouse_request_allocations(status);

-- 3. Create function to automatically process global withdrawal requests
CREATE OR REPLACE FUNCTION process_global_withdrawal_request(
    p_request_id TEXT,
    p_allocation_strategy TEXT DEFAULT 'balanced',
    p_performed_by TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_request_record RECORD;
    v_item_record RECORD;
    v_warehouse_record RECORD;
    v_allocation_record RECORD;
    v_total_processed INTEGER := 0;
    v_total_requested INTEGER := 0;
    v_items_processed INTEGER := 0;
    v_items_successful INTEGER := 0;
    v_allocations_created INTEGER := 0;
    v_deductions_successful INTEGER := 0;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_warehouses_involved TEXT[] := ARRAY[]::TEXT[];
    v_performed_by TEXT;
    v_user_role TEXT;
    v_remaining_quantity INTEGER;
    v_allocate_quantity INTEGER;
    v_deduction_result JSONB;
BEGIN
    -- Check user authorization and get user ID
    SELECT role INTO v_user_role
    FROM user_profiles 
    WHERE id = auth.uid() AND status = 'approved';
    
    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager', 'accountant') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'غير مصرح لك بمعالجة طلبات السحب العالمية'
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
    
    -- Mark request as global if not already marked
    UPDATE warehouse_requests 
    SET is_global_request = true,
        processing_metadata = COALESCE(processing_metadata, '{}'::jsonb) || jsonb_build_object(
            'processing_started_at', NOW()::text,
            'processing_started_by', v_performed_by,
            'allocation_strategy', p_allocation_strategy
        )
    WHERE id = p_request_id;
    
    -- Process each item in the request
    FOR v_item_record IN 
        SELECT wri.*, p.name as product_name, p.sku as product_sku
        FROM warehouse_request_items wri
        LEFT JOIN products p ON wri.product_id = p.id
        WHERE wri.request_id = p_request_id
    LOOP
        v_items_processed := v_items_processed + 1;
        v_total_requested := v_total_requested + v_item_record.quantity;
        v_remaining_quantity := v_item_record.quantity;
        
        -- Find warehouses with available inventory for this product
        FOR v_warehouse_record IN 
            SELECT 
                wi.warehouse_id,
                w.name as warehouse_name,
                COALESCE(w.priority, 0) as warehouse_priority,
                wi.quantity as available_quantity,
                COALESCE(wi.minimum_stock, 0) as minimum_stock,
                GREATEST(0, wi.quantity - COALESCE(wi.minimum_stock, 0)) as allocatable_quantity
            FROM warehouse_inventory wi
            JOIN warehouses w ON wi.warehouse_id = w.id
            WHERE wi.product_id = v_item_record.product_id
                AND w.is_active = true
                AND wi.quantity > 0
                AND wi.quantity > COALESCE(wi.minimum_stock, 0)
            ORDER BY 
                CASE p_allocation_strategy
                    WHEN 'priority_based' THEN COALESCE(w.priority, 0)
                    WHEN 'highest_stock' THEN wi.quantity
                    WHEN 'lowest_stock' THEN -wi.quantity
                    ELSE GREATEST(0, wi.quantity - COALESCE(wi.minimum_stock, 0))
                END DESC,
                wi.quantity DESC
        LOOP
            IF v_remaining_quantity <= 0 THEN
                EXIT;
            END IF;
            
            -- Calculate allocation quantity for this warehouse
            v_allocate_quantity := LEAST(v_remaining_quantity, v_warehouse_record.allocatable_quantity);
            
            IF v_allocate_quantity > 0 THEN
                -- Create allocation record
                INSERT INTO warehouse_request_allocations (
                    request_id,
                    warehouse_id,
                    product_id,
                    allocated_quantity,
                    allocation_strategy,
                    allocation_priority,
                    allocation_reason,
                    status,
                    created_at,
                    processed_by
                ) VALUES (
                    p_request_id,
                    v_warehouse_record.warehouse_id,
                    v_item_record.product_id,
                    v_allocate_quantity,
                    p_allocation_strategy,
                    v_allocations_created + 1,
                    'تخصيص تلقائي - ' || p_allocation_strategy || ' - ' || v_warehouse_record.warehouse_name,
                    'pending',
                    NOW(),
                    v_performed_by
                );
                
                v_allocations_created := v_allocations_created + 1;
                v_remaining_quantity := v_remaining_quantity - v_allocate_quantity;
                
                -- Add warehouse to involved list if not already there
                IF NOT (v_warehouse_record.warehouse_id = ANY(v_warehouses_involved)) THEN
                    v_warehouses_involved := array_append(v_warehouses_involved, v_warehouse_record.warehouse_id);
                END IF;
            END IF;
        END LOOP;
        
        -- Check if item was fully allocated
        IF v_remaining_quantity = 0 THEN
            v_items_successful := v_items_successful + 1;
        ELSE
            v_errors := array_append(v_errors, 
                'لم يتم تخصيص ' || v_remaining_quantity || ' من المنتج ' || 
                COALESCE(v_item_record.product_name, v_item_record.product_id) || 
                ' - مخزون غير كافي'
            );
        END IF;
    END LOOP;
    
    -- Now process the allocations (deduct inventory)
    FOR v_allocation_record IN 
        SELECT * FROM warehouse_request_allocations 
        WHERE request_id = p_request_id AND status = 'pending'
        ORDER BY allocation_priority
    LOOP
        -- Update allocation status to processing
        UPDATE warehouse_request_allocations 
        SET status = 'processing', updated_at = NOW()
        WHERE id = v_allocation_record.id;
        
        -- Perform inventory deduction
        SELECT deduct_inventory_with_validation(
            v_allocation_record.warehouse_id,
            v_allocation_record.product_id,
            v_allocation_record.allocated_quantity,
            v_performed_by,
            'سحب تلقائي عالمي للطلب ' || p_request_id,
            p_request_id,
            'global_withdrawal_request'
        ) INTO v_deduction_result;
        
        IF (v_deduction_result->>'success')::BOOLEAN THEN
            -- Update allocation as completed
            UPDATE warehouse_request_allocations 
            SET 
                status = 'completed',
                deducted_quantity = v_allocation_record.allocated_quantity,
                processed_at = NOW(),
                updated_at = NOW()
            WHERE id = v_allocation_record.id;
            
            v_deductions_successful := v_deductions_successful + 1;
            v_total_processed := v_total_processed + v_allocation_record.allocated_quantity;
        ELSE
            -- Update allocation as failed
            UPDATE warehouse_request_allocations 
            SET 
                status = 'failed',
                updated_at = NOW()
            WHERE id = v_allocation_record.id;
            
            v_errors := array_append(v_errors, 
                'فشل خصم ' || v_allocation_record.allocated_quantity || 
                ' من المخزن ' || v_allocation_record.warehouse_id || 
                ': ' || (v_deduction_result->>'error')
            );
        END IF;
    END LOOP;
    
    -- Update request metadata with processing results
    UPDATE warehouse_requests
    SET 
        processing_metadata = COALESCE(processing_metadata, '{}'::jsonb) || jsonb_build_object(
            'processing_completed_at', NOW()::text,
            'processing_success', array_length(v_errors, 1) IS NULL,
            'items_processed', v_items_processed,
            'items_successful', v_items_successful,
            'total_requested', v_total_requested,
            'total_processed', v_total_processed,
            'allocations_created', v_allocations_created,
            'deductions_successful', v_deductions_successful,
            'warehouses_involved', v_warehouses_involved,
            'processing_errors', v_errors,
            'allocation_strategy', p_allocation_strategy
        ),
        updated_at = NOW()
    WHERE id = p_request_id;
    
    -- Log the global processing
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
        'global_withdrawal_processed',
        jsonb_build_object(
            'request_id', p_request_id,
            'allocation_strategy', p_allocation_strategy,
            'items_processed', v_items_processed,
            'items_successful', v_items_successful,
            'total_requested', v_total_requested,
            'total_processed', v_total_processed,
            'allocations_created', v_allocations_created,
            'deductions_successful', v_deductions_successful,
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
        'is_global_request', true,
        'allocation_strategy', p_allocation_strategy,
        'items_processed', v_items_processed,
        'items_successful', v_items_successful,
        'total_requested', v_total_requested,
        'total_processed', v_total_processed,
        'allocations_created', v_allocations_created,
        'deductions_successful', v_deductions_successful,
        'warehouses_involved', v_warehouses_involved,
        'processing_percentage', CASE WHEN v_total_requested > 0 THEN (v_total_processed::DECIMAL / v_total_requested * 100) ELSE 0 END,
        'errors', v_errors
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Rollback any pending allocations
        UPDATE warehouse_request_allocations 
        SET status = 'failed', updated_at = NOW()
        WHERE request_id = p_request_id AND status = 'processing';
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في معالجة طلب السحب العالمي: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create trigger to automatically process completed withdrawal requests
CREATE OR REPLACE FUNCTION trigger_global_withdrawal_processing()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process if status changed to 'completed' and it's a withdrawal request
    IF NEW.status = 'completed' AND OLD.status != 'completed' AND NEW.type = 'withdrawal' THEN
        -- Schedule async processing (in a real implementation, this would be queued)
        -- For now, we'll mark it for processing
        NEW.processing_metadata = COALESCE(NEW.processing_metadata, '{}'::jsonb) || jsonb_build_object(
            'auto_processing_triggered', true,
            'triggered_at', NOW()::text,
            'triggered_by', auth.uid()::text
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS trigger_auto_process_withdrawal ON warehouse_requests;
CREATE TRIGGER trigger_auto_process_withdrawal
    BEFORE UPDATE ON warehouse_requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_global_withdrawal_processing();

-- 5. Function to get allocation details for a request
CREATE OR REPLACE FUNCTION get_request_allocation_details(p_request_id TEXT)
RETURNS TABLE (
    allocation_id UUID,
    warehouse_id TEXT,
    warehouse_name TEXT,
    product_id TEXT,
    product_name TEXT,
    allocated_quantity INTEGER,
    deducted_quantity INTEGER,
    allocation_strategy TEXT,
    allocation_priority INTEGER,
    allocation_reason TEXT,
    status TEXT,
    created_at TIMESTAMP,
    processed_at TIMESTAMP
) AS $$
DECLARE
    v_user_role TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles 
    WHERE id = auth.uid() AND status = 'approved';
    
    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager', 'accountant', 'worker') THEN
        RAISE EXCEPTION 'غير مصرح لك بالوصول لتفاصيل التخصيص';
    END IF;

    RETURN QUERY
    SELECT 
        wra.id as allocation_id,
        wra.warehouse_id,
        w.name as warehouse_name,
        wra.product_id,
        p.name as product_name,
        wra.allocated_quantity,
        wra.deducted_quantity,
        wra.allocation_strategy,
        wra.allocation_priority,
        wra.allocation_reason,
        wra.status,
        wra.created_at,
        wra.processed_at
    FROM warehouse_request_allocations wra
    LEFT JOIN warehouses w ON wra.warehouse_id = w.id
    LEFT JOIN products p ON wra.product_id = p.id
    WHERE wra.request_id = p_request_id
    ORDER BY wra.allocation_priority, wra.created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Update existing warehouse deletion constraints function
CREATE OR REPLACE FUNCTION check_warehouse_deletion_constraints_v2(p_warehouse_id TEXT)
RETURNS TABLE (
    can_delete BOOLEAN,
    active_requests INTEGER,
    global_allocations INTEGER,
    inventory_items INTEGER,
    total_quantity INTEGER,
    recent_transactions INTEGER,
    blocking_reason TEXT
) AS $$
DECLARE
    v_active_requests INTEGER := 0;
    v_global_allocations INTEGER := 0;
    v_inventory_items INTEGER := 0;
    v_total_quantity INTEGER := 0;
    v_recent_transactions INTEGER := 0;
    v_can_delete BOOLEAN := TRUE;
    v_blocking_reasons TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Check traditional active requests (warehouse-specific)
    SELECT COUNT(*)
    INTO v_active_requests
    FROM warehouse_requests
    WHERE warehouse_id = p_warehouse_id
    AND status NOT IN ('completed', 'cancelled');
    
    -- Check global allocations (new constraint)
    SELECT COUNT(*)
    INTO v_global_allocations
    FROM warehouse_request_allocations
    WHERE warehouse_id = p_warehouse_id
    AND status IN ('pending', 'processing');
    
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
        v_blocking_reasons := array_append(v_blocking_reasons, v_active_requests || ' طلب نشط مرتبط بالمخزن');
    END IF;
    
    IF v_global_allocations > 0 THEN
        v_can_delete := FALSE;
        v_blocking_reasons := array_append(v_blocking_reasons, v_global_allocations || ' تخصيص عالمي نشط');
    END IF;
    
    IF v_inventory_items > 0 THEN
        v_can_delete := FALSE;
        v_blocking_reasons := array_append(v_blocking_reasons, v_inventory_items || ' منتج في المخزون');
    END IF;
    
    -- Return results
    RETURN QUERY SELECT 
        v_can_delete,
        v_active_requests,
        v_global_allocations,
        v_inventory_items,
        v_total_quantity,
        v_recent_transactions,
        CASE 
            WHEN array_length(v_blocking_reasons, 1) > 0 THEN array_to_string(v_blocking_reasons, ', ')
            ELSE 'لا توجد عوامل مانعة'
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- TESTING AND VERIFICATION QUERIES
-- =====================================================

-- Test the schema modifications
/*
-- Check if warehouse_id is now nullable
SELECT column_name, is_nullable, data_type 
FROM information_schema.columns 
WHERE table_name = 'warehouse_requests' AND column_name = 'warehouse_id';

-- Check new columns
SELECT column_name, data_type, column_default
FROM information_schema.columns 
WHERE table_name = 'warehouse_requests' 
AND column_name IN ('is_global_request', 'processing_metadata');

-- Test global withdrawal processing
SELECT process_global_withdrawal_request('test-request-id', 'balanced');

-- Check allocation details
SELECT * FROM get_request_allocation_details('test-request-id');

-- Test updated deletion constraints
SELECT * FROM check_warehouse_deletion_constraints_v2('77510647-5f3b-49e9-8a8a-bcd8e77eaecd');
*/
