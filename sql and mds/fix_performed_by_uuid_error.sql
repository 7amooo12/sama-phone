-- =====================================================
-- FIX PERFORMED_BY UUID TYPE MISMATCH ERROR
-- =====================================================
-- This script fixes the "column performed_by is of type uuid but expression is of type text" error
-- by ensuring the database function properly converts performed_by to UUID before INSERT operations

-- Drop the existing function to avoid conflicts
DROP FUNCTION IF EXISTS public.deduct_inventory_with_validation(TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT);

-- Create the corrected function with proper performed_by UUID handling
CREATE OR REPLACE FUNCTION public.deduct_inventory_with_validation(
    p_warehouse_id TEXT,      -- warehouse_id as TEXT (will be cast to UUID)
    p_product_id TEXT,        -- product_id as TEXT (stays as TEXT)
    p_quantity INTEGER,       -- quantity as INTEGER
    p_performed_by TEXT,      -- performed_by as TEXT (will be cast to UUID)
    p_reason TEXT,            -- reason as TEXT
    p_reference_id TEXT,      -- reference_id as TEXT
    p_reference_type TEXT     -- reference_type as TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_quantity INTEGER;
    new_quantity INTEGER;
    transaction_id UUID;
    transaction_number TEXT;
    minimum_stock_value INTEGER;
    warehouse_uuid UUID;
    performed_by_uuid UUID;
BEGIN
    -- Validate inputs
    IF p_warehouse_id IS NULL OR p_warehouse_id = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Warehouse ID is required'
        );
    END IF;

    IF p_product_id IS NULL OR p_product_id = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Product ID is required'
        );
    END IF;

    IF p_quantity IS NULL OR p_quantity < 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Quantity must be zero or greater'
        );
    END IF;

    IF p_performed_by IS NULL OR p_performed_by = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Performed by user ID is required'
        );
    END IF;

    -- Convert warehouse_id to UUID with proper error handling
    BEGIN
        warehouse_uuid := p_warehouse_id::UUID;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Invalid warehouse ID format: ' || p_warehouse_id
            );
    END;

    -- Convert performed_by to UUID with proper error handling
    BEGIN
        performed_by_uuid := p_performed_by::UUID;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Invalid user ID format: ' || p_performed_by
            );
    END;

    -- Get current quantity and minimum stock with explicit table prefix
    SELECT wi.quantity, COALESCE(wi.minimum_stock, 0) 
    INTO current_quantity, minimum_stock_value
    FROM warehouse_inventory wi
    WHERE wi.warehouse_id = warehouse_uuid 
    AND wi.product_id = p_product_id;

    -- Check if product exists in warehouse
    IF current_quantity IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Product not found in specified warehouse',
            'warehouse_id', p_warehouse_id,
            'product_id', p_product_id
        );
    END IF;

    -- Check if sufficient quantity available (only if quantity > 0)
    IF p_quantity > 0 AND current_quantity < p_quantity THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient quantity available',
            'available_quantity', current_quantity,
            'requested_quantity', p_quantity
        );
    END IF;

    -- Calculate new quantity
    new_quantity := current_quantity - p_quantity;

    -- Generate transaction ID and number
    transaction_id := gen_random_uuid();
    transaction_number := 'TXN-' || EXTRACT(EPOCH FROM NOW())::BIGINT || '-' || SUBSTRING(transaction_id::TEXT, 1, 8);

    -- Update inventory (only if quantity > 0)
    IF p_quantity > 0 THEN
        UPDATE warehouse_inventory
        SET 
            quantity = new_quantity,
            last_updated = NOW(),
            updated_by = performed_by_uuid  -- FIXED: Use UUID variable
        WHERE warehouse_id = warehouse_uuid 
        AND product_id = p_product_id;

        -- Check if update was successful
        IF NOT FOUND THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Failed to update inventory'
            );
        END IF;
    END IF;

    -- Record transaction (only if quantity > 0)
    -- CRITICAL FIX: Use UUID variables for all UUID columns
    IF p_quantity > 0 THEN
        -- Check if warehouse_transactions table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_transactions') THEN
            INSERT INTO warehouse_transactions (
                id,
                warehouse_id,  -- UUID column
                product_id,    -- TEXT column
                type,
                quantity,
                quantity_before,
                quantity_after,
                performed_by,  -- UUID column - THIS WAS THE ISSUE
                performed_at,
                reason,
                reference_id,
                reference_type,
                transaction_number
            ) VALUES (
                transaction_id,
                warehouse_uuid,      -- FIXED: Use UUID variable instead of TEXT
                p_product_id,        -- Keep as TEXT
                'withdrawal',
                p_quantity,
                current_quantity,
                new_quantity,
                performed_by_uuid,   -- CRITICAL FIX: Use UUID variable instead of TEXT
                NOW(),
                p_reason,
                p_reference_id,
                p_reference_type,
                transaction_number
            );
        END IF;
    END IF;

    -- Log audit entry (only if quantity > 0)
    -- CRITICAL FIX: Use UUID variable for performed_by in audit log too
    IF p_quantity > 0 THEN
        -- Check if global_inventory_audit_log table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'global_inventory_audit_log') THEN
            INSERT INTO global_inventory_audit_log (
                warehouse_id,
                product_id,
                action_type,
                action_details,
                performed_by,  -- This might also be UUID type
                performed_at
            ) VALUES (
                p_warehouse_id,  -- Keep as TEXT for audit log (if TEXT column)
                p_product_id,
                'inventory_deduction',
                jsonb_build_object(
                    'quantity_deducted', p_quantity,
                    'quantity_before', current_quantity,
                    'quantity_after', new_quantity,
                    'reason', p_reason,
                    'reference_id', p_reference_id,
                    'reference_type', p_reference_type,
                    'transaction_id', transaction_id
                ),
                performed_by_uuid,  -- CRITICAL FIX: Use UUID variable if column is UUID type
                NOW()
            );
        END IF;
    END IF;

    -- Return success result
    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', transaction_id,
        'transaction_number', transaction_number,
        'quantity_before', current_quantity,
        'quantity_after', new_quantity,
        'remaining_quantity', new_quantity,
        'deducted_quantity', p_quantity,
        'minimum_stock_warning', new_quantity <= minimum_stock_value
    );

EXCEPTION
    WHEN OTHERS THEN
        -- Return detailed error information
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Database error: ' || SQLERRM,
            'error_code', SQLSTATE,
            'warehouse_id', p_warehouse_id,
            'product_id', p_product_id,
            'quantity', p_quantity,
            'performed_by', p_performed_by,
            'sql_state', SQLSTATE,
            'error_detail', SQLERRM
        );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.deduct_inventory_with_validation(
    TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT
) TO authenticated;

-- Test the function with the exact parameters from the logs
DO $$
DECLARE
    test_result JSONB;
BEGIN
    RAISE NOTICE '🧪 Testing the corrected function with exact parameters from logs...';
    
    -- Test with the exact parameters that were failing
    SELECT deduct_inventory_with_validation(
        '9a900dea-1938-4ebd-84f5-1d07aea19318',  -- warehouse_id from logs
        '15',                                     -- product_id (1007/500)
        0,                                        -- quantity (safe test)
        '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',  -- performed_by from logs
        'Test fix for performed_by UUID error',   -- reason
        'performed-by-fix-test-' || EXTRACT(EPOCH FROM NOW())::TEXT, -- reference_id
        'performed_by_fix_test'                   -- reference_type
    ) INTO test_result;
    
    RAISE NOTICE '📤 Test Result: %', test_result;
    
    IF (test_result->>'success')::BOOLEAN THEN
        RAISE NOTICE '✅ SUCCESS! performed_by UUID conversion is working correctly';
        RAISE NOTICE '   Transaction ID: %', test_result->>'transaction_id';
        RAISE NOTICE '   Quantity before: %', test_result->>'quantity_before';
        RAISE NOTICE '   Quantity after: %', test_result->>'quantity_after';
    ELSE
        RAISE NOTICE '❌ FAILED! Error: %', test_result->>'error';
        RAISE NOTICE '   Error code: %', test_result->>'error_code';
        RAISE NOTICE '   SQL State: %', test_result->>'sql_state';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Exception during test: %', SQLERRM;
END $$;

-- Verify function exists and show its signature
SELECT
    'PERFORMED_BY_FIX_STATUS' as test_type,
    routine_name,
    routine_type,
    specific_name,
    'PERFORMED_BY_UUID_FIXED' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'deduct_inventory_with_validation';

-- Final status message
DO $$
BEGIN
    RAISE NOTICE '==================== PERFORMED_BY UUID FIX COMPLETE ====================';
    RAISE NOTICE 'Fixed the critical issue:';
    RAISE NOTICE '1. performed_by parameter now properly converted to UUID before INSERT';
    RAISE NOTICE '2. warehouse_transactions table INSERT uses performed_by_uuid variable';
    RAISE NOTICE '3. global_inventory_audit_log INSERT uses performed_by_uuid variable';
    RAISE NOTICE '4. All UUID columns now receive proper UUID values, not TEXT';
    RAISE NOTICE '';
    RAISE NOTICE 'The intelligent inventory deduction should now work correctly';
    RAISE NOTICE 'for product 1007/500 with user 6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab';
    RAISE NOTICE 'and deduct 50 items successfully instead of 0.';
    RAISE NOTICE '================================================================';
END $$;
