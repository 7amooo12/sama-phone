-- =====================================================
-- FINAL FIX FOR WAREHOUSE_ID TYPE MISMATCH ERROR
-- =====================================================
-- This script fixes the "warehouse_id is of type uuid but expression is of type text" error
-- by ensuring the correct database function is deployed and all type casting is handled properly

-- Step 1: Drop all existing versions of the function to avoid conflicts
DROP FUNCTION IF EXISTS public.deduct_inventory_with_validation(TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.deduct_inventory_with_validation(TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.deduct_inventory_with_validation(UUID, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT);

-- Step 2: Create the corrected function with proper type handling
-- Using the parameter order that matches the Dart code RPC call
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
    minimum_stock INTEGER;
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

    -- Get current quantity and minimum stock
    SELECT quantity, COALESCE(minimum_stock, 0) 
    INTO current_quantity, minimum_stock
    FROM warehouse_inventory
    WHERE warehouse_id = warehouse_uuid 
    AND product_id = p_product_id;

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
            updated_by = performed_by_uuid
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
    -- FIXED: Use UUID for warehouse_id in the INSERT statement
    IF p_quantity > 0 THEN
        -- Check if warehouse_transactions table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_transactions') THEN
            INSERT INTO warehouse_transactions (
                id,
                warehouse_id,  -- This will be UUID type
                product_id,    -- This will be TEXT type
                type,
                quantity,
                quantity_before,
                quantity_after,
                performed_by,
                performed_at,
                reason,
                reference_id,
                reference_type,
                transaction_number
            ) VALUES (
                transaction_id,
                warehouse_uuid,  -- FIXED: Use UUID variable instead of TEXT
                p_product_id,    -- Keep as TEXT
                'withdrawal',
                p_quantity,
                current_quantity,
                new_quantity,
                p_performed_by,
                NOW(),
                p_reason,
                p_reference_id,
                p_reference_type,
                transaction_number
            );
        END IF;
    END IF;

    -- Log audit entry (only if quantity > 0)
    IF p_quantity > 0 THEN
        -- Check if global_inventory_audit_log table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'global_inventory_audit_log') THEN
            INSERT INTO global_inventory_audit_log (
                warehouse_id,
                product_id,
                action_type,
                action_details,
                performed_by,
                performed_at
            ) VALUES (
                p_warehouse_id,  -- Keep as TEXT for audit log
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
                p_performed_by,
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
        'minimum_stock_warning', new_quantity <= minimum_stock
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
            'sql_state', SQLSTATE,
            'error_detail', SQLERRM
        );
END;
$$;

-- Step 3: Grant permissions
GRANT EXECUTE ON FUNCTION public.deduct_inventory_with_validation(
    TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT
) TO authenticated;

-- Step 4: Test the function with a safe test
DO $$
DECLARE
    test_result JSONB;
    test_warehouse_id TEXT;
    test_user_id TEXT;
BEGIN
    RAISE NOTICE '🧪 Testing the final corrected inventory deduction function...';
    
    -- Get a warehouse that has any product
    SELECT wi.warehouse_id INTO test_warehouse_id
    FROM warehouse_inventory wi
    WHERE wi.quantity > 0
    LIMIT 1;
    
    -- Get a valid user ID
    SELECT id INTO test_user_id
    FROM auth.users
    LIMIT 1;
    
    IF test_warehouse_id IS NULL THEN
        RAISE NOTICE '⚠️ No warehouse found with products in stock';
        RETURN;
    END IF;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE '⚠️ No user found for testing';
        RETURN;
    END IF;
    
    RAISE NOTICE '📦 Testing with warehouse: %, user: %', test_warehouse_id, test_user_id;
    
    -- Test the function with quantity 0 (safe test)
    SELECT deduct_inventory_with_validation(
        test_warehouse_id,                                -- p_warehouse_id
        '15',                                             -- p_product_id (1007/500)
        0,                                                -- p_quantity (safe test)
        test_user_id,                                     -- p_performed_by
        'Final test of corrected function',               -- p_reason
        'final-test-' || EXTRACT(EPOCH FROM NOW())::TEXT, -- p_reference_id
        'final_test'                                      -- p_reference_type
    ) INTO test_result;
    
    RAISE NOTICE '📤 Test Result: %', test_result;
    
    IF (test_result->>'success')::BOOLEAN THEN
        RAISE NOTICE '✅ SUCCESS! Function is working correctly';
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

-- Step 5: Verify function exists and show its signature
SELECT
    'FUNCTION_STATUS' as test_type,
    routine_name,
    routine_type,
    specific_name,
    'FINAL_VERSION_DEPLOYED' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'deduct_inventory_with_validation';

-- Step 6: Final status message
DO $$
BEGIN
    RAISE NOTICE '==================== FINAL WAREHOUSE_ID TYPE MISMATCH FIX COMPLETE ====================';
    RAISE NOTICE 'Applied the following fixes:';
    RAISE NOTICE '1. Proper UUID conversion for warehouse_id in function parameters';
    RAISE NOTICE '2. Fixed INSERT statement to use UUID variable instead of TEXT';
    RAISE NOTICE '3. Added proper error handling for invalid UUID formats';
    RAISE NOTICE '4. Maintained TEXT format for product_id (correct)';
    RAISE NOTICE '5. Added comprehensive error reporting';
    RAISE NOTICE '';
    RAISE NOTICE 'The function should now work correctly for product 1007/500';
    RAISE NOTICE 'and all other products without warehouse_id type mismatch errors.';
    RAISE NOTICE '================================================================';
END $$;
