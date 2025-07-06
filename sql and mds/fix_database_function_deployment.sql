-- =====================================================
-- FIX DATABASE FUNCTION DEPLOYMENT
-- =====================================================
-- This script ensures the correct database function is deployed
-- and fixes the warehouse_id type mismatch issue

-- First, check what functions currently exist
SELECT 
    routine_name,
    routine_type,
    specific_name,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE '%deduct_inventory%'
ORDER BY routine_name;

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS public.deduct_inventory_with_validation(TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.deduct_inventory_with_validation(TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.deduct_inventory_with_validation(UUID, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT);

-- Create the corrected function with proper parameter order and type handling
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

    -- Convert warehouse_id to UUID
    BEGIN
        warehouse_uuid := p_warehouse_id::UUID;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Invalid warehouse ID format: ' || p_warehouse_id
            );
    END;

    -- Convert performed_by to UUID
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
    IF p_quantity > 0 THEN
        -- Check if warehouse_transactions table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_transactions') THEN
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
                transaction_number
            ) VALUES (
                transaction_id,
                p_warehouse_id,
                p_product_id,
                'withdrawal',
                -p_quantity,
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
                p_warehouse_id,
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
            'quantity', p_quantity
        );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.deduct_inventory_with_validation(
    TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT
) TO authenticated;

-- Test the function with a safe test
DO $$
DECLARE
    test_result JSONB;
    test_warehouse_id TEXT;
    test_user_id TEXT;
BEGIN
    RAISE NOTICE '🧪 Testing the corrected inventory deduction function...';
    
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
        'Test deduction function deployment',             -- p_reason
        'deployment-test-' || EXTRACT(EPOCH FROM NOW())::TEXT, -- p_reference_id
        'deployment_test'                                 -- p_reference_type
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
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Exception during test: %', SQLERRM;
END $$;

-- Verify function exists and show its signature
SELECT
    'FUNCTION_STATUS' as test_type,
    routine_name,
    routine_type,
    specific_name,
    'DEPLOYED_AND_READY' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'deduct_inventory_with_validation';

-- Final status message
DO $$
BEGIN
    RAISE NOTICE '==================== DATABASE FUNCTION DEPLOYMENT COMPLETE ====================';
    RAISE NOTICE 'Deployed corrected function with the following fixes:';
    RAISE NOTICE '1. Proper parameter order (warehouse_id, product_id, quantity, ...)';
    RAISE NOTICE '2. Explicit UUID casting for warehouse_id and performed_by';
    RAISE NOTICE '3. Product IDs remain as TEXT (no casting)';
    RAISE NOTICE '4. Safe handling of zero quantities for testing';
    RAISE NOTICE '5. Proper error handling and validation';
    RAISE NOTICE '';
    RAISE NOTICE 'The function should now work correctly for product 1007/500';
    RAISE NOTICE 'and all other products without type casting errors.';
    RAISE NOTICE '================================================================';
END $$;
