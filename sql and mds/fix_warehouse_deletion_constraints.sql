-- =====================================================
-- IMMEDIATE FIX FOR WAREHOUSE DELETION CONSTRAINTS
-- =====================================================
-- This script removes the foreign key constraint preventing warehouse deletion
-- and enables global withdrawal requests without warehouse dependencies

-- Step 1: Remove the foreign key constraint that's preventing warehouse deletion
DO $$
DECLARE
    constraint_name TEXT;
    constraint_record RECORD;
BEGIN
    -- Find all foreign key constraints from warehouse_requests to warehouses
    FOR constraint_record IN 
        SELECT tc.constraint_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'warehouse_requests' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND ccu.table_name = 'warehouses'
        AND kcu.column_name = 'warehouse_id'
    LOOP
        BEGIN
            EXECUTE 'ALTER TABLE warehouse_requests DROP CONSTRAINT ' || constraint_record.constraint_name;
            RAISE NOTICE 'Dropped constraint: %', constraint_record.constraint_name;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Could not drop constraint %: %', constraint_record.constraint_name, SQLERRM;
        END;
    END LOOP;
    
    -- Also try the common constraint names directly
    BEGIN
        ALTER TABLE warehouse_requests DROP CONSTRAINT IF EXISTS warehouse_requests_warehouse_id_fkey;
        RAISE NOTICE 'Dropped warehouse_requests_warehouse_id_fkey if it existed';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    
    BEGIN
        ALTER TABLE warehouse_requests DROP CONSTRAINT IF EXISTS fk_warehouse_requests_warehouse_id;
        RAISE NOTICE 'Dropped fk_warehouse_requests_warehouse_id if it existed';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
END $$;

-- Step 2: Make warehouse_id nullable to allow global requests
ALTER TABLE warehouse_requests ALTER COLUMN warehouse_id DROP NOT NULL;

-- Step 3: Add columns for global request support
ALTER TABLE warehouse_requests ADD COLUMN IF NOT EXISTS is_global_request BOOLEAN DEFAULT false;
ALTER TABLE warehouse_requests ADD COLUMN IF NOT EXISTS processing_metadata JSONB DEFAULT '{}'::jsonb;

-- Step 4: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_warehouse_requests_global 
ON warehouse_requests(is_global_request) WHERE is_global_request = true;

CREATE INDEX IF NOT EXISTS idx_warehouse_requests_processing_metadata 
ON warehouse_requests USING gin(processing_metadata);

-- Step 5: Update existing requests to mark them as traditional (non-global)
UPDATE warehouse_requests 
SET is_global_request = false 
WHERE is_global_request IS NULL;

-- Step 6: Create a simple function to convert existing requests to global
CREATE OR REPLACE FUNCTION convert_request_to_global(p_request_id TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE warehouse_requests 
    SET 
        warehouse_id = NULL,
        is_global_request = true,
        processing_metadata = COALESCE(processing_metadata, '{}'::jsonb) || jsonb_build_object(
            'converted_to_global', true,
            'converted_at', NOW()::text,
            'original_warehouse_id', warehouse_id
        )
    WHERE id = p_request_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Create a function to check if warehouse can be deleted (updated version)
CREATE OR REPLACE FUNCTION can_delete_warehouse_v2(p_warehouse_id TEXT)
RETURNS TABLE (
    can_delete BOOLEAN,
    blocking_reason TEXT,
    active_requests INTEGER,
    inventory_items INTEGER,
    recent_transactions INTEGER
) AS $$
DECLARE
    v_active_requests INTEGER := 0;
    v_inventory_items INTEGER := 0;
    v_recent_transactions INTEGER := 0;
    v_can_delete BOOLEAN := TRUE;
    v_blocking_reasons TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Check for active requests (only non-global ones matter now)
    SELECT COUNT(*)
    INTO v_active_requests
    FROM warehouse_requests
    WHERE warehouse_id = p_warehouse_id
    AND status NOT IN ('completed', 'cancelled')
    AND (is_global_request = false OR is_global_request IS NULL);
    
    -- Check inventory items with stock
    SELECT COUNT(*)
    INTO v_inventory_items
    FROM warehouse_inventory
    WHERE warehouse_id = p_warehouse_id
    AND quantity > 0;
    
    -- Check recent transactions (last 7 days)
    SELECT COUNT(*)
    INTO v_recent_transactions
    FROM warehouse_transactions
    WHERE warehouse_id = p_warehouse_id
    AND performed_at > NOW() - INTERVAL '7 days';
    
    -- Determine blocking factors
    IF v_active_requests > 0 THEN
        v_can_delete := FALSE;
        v_blocking_reasons := array_append(v_blocking_reasons, v_active_requests || ' طلب نشط غير عالمي');
    END IF;
    
    IF v_inventory_items > 0 THEN
        v_can_delete := FALSE;
        v_blocking_reasons := array_append(v_blocking_reasons, v_inventory_items || ' منتج بمخزون');
    END IF;
    
    -- Recent transactions are just a warning, not blocking
    
    -- Return results
    RETURN QUERY SELECT 
        v_can_delete,
        CASE 
            WHEN array_length(v_blocking_reasons, 1) > 0 THEN array_to_string(v_blocking_reasons, ', ')
            ELSE 'يمكن حذف المخزن'
        END,
        v_active_requests,
        v_inventory_items,
        v_recent_transactions;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Create a safe warehouse deletion function
CREATE OR REPLACE FUNCTION safe_delete_warehouse(p_warehouse_id TEXT)
RETURNS JSONB AS $$
DECLARE
    v_check_result RECORD;
    v_user_role TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles 
    WHERE id = auth.uid() AND status = 'approved';
    
    IF v_user_role NOT IN ('admin', 'owner') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'غير مصرح لك بحذف المخازن'
        );
    END IF;
    
    -- Check if warehouse can be deleted
    SELECT * INTO v_check_result
    FROM can_delete_warehouse_v2(p_warehouse_id);
    
    IF NOT v_check_result.can_delete THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'لا يمكن حذف المخزن: ' || v_check_result.blocking_reason,
            'details', jsonb_build_object(
                'active_requests', v_check_result.active_requests,
                'inventory_items', v_check_result.inventory_items,
                'recent_transactions', v_check_result.recent_transactions
            )
        );
    END IF;
    
    -- Convert any remaining non-global requests to global
    UPDATE warehouse_requests 
    SET 
        warehouse_id = NULL,
        is_global_request = true,
        processing_metadata = COALESCE(processing_metadata, '{}'::jsonb) || jsonb_build_object(
            'auto_converted_on_deletion', true,
            'converted_at', NOW()::text,
            'original_warehouse_id', p_warehouse_id
        )
    WHERE warehouse_id = p_warehouse_id
    AND status IN ('completed', 'cancelled')
    AND (is_global_request = false OR is_global_request IS NULL);
    
    -- Delete empty inventory records
    DELETE FROM warehouse_inventory 
    WHERE warehouse_id = p_warehouse_id AND quantity = 0;
    
    -- Delete old transactions (older than 30 days)
    DELETE FROM warehouse_transactions 
    WHERE warehouse_id = p_warehouse_id 
    AND performed_at < NOW() - INTERVAL '30 days';
    
    -- Finally delete the warehouse
    DELETE FROM warehouses WHERE id = p_warehouse_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم حذف المخزن بنجاح',
        'converted_requests', (
            SELECT COUNT(*) FROM warehouse_requests 
            WHERE processing_metadata->>'original_warehouse_id' = p_warehouse_id
        )
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في حذف المخزن: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 9: Grant necessary permissions
GRANT EXECUTE ON FUNCTION convert_request_to_global(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION can_delete_warehouse_v2(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION safe_delete_warehouse(TEXT) TO authenticated;

-- Step 10: Create RLS policies for the functions
-- (Functions already have SECURITY DEFINER, so they run with elevated privileges)

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check if foreign key constraints are removed
/*
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_name = 'warehouse_requests' 
AND tc.constraint_type = 'FOREIGN KEY'
AND ccu.table_name = 'warehouses';
*/

-- Check if warehouse_id is now nullable
/*
SELECT column_name, is_nullable, data_type 
FROM information_schema.columns 
WHERE table_name = 'warehouse_requests' AND column_name = 'warehouse_id';
*/

-- Test the new deletion function
/*
SELECT safe_delete_warehouse('77510647-5f3b-49e9-8a8a-bcd8e77eaecd');
*/

-- Check warehouse deletion constraints
/*
SELECT * FROM can_delete_warehouse_v2('77510647-5f3b-49e9-8a8a-bcd8e77eaecd');
*/

-- Convert a specific request to global
/*
SELECT convert_request_to_global('your-request-id-here');
*/
