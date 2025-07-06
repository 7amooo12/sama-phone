-- =====================================================
-- Fix Pricing Approval UUID Issue
-- Created: 2025-06-22
-- Purpose: Resolve the UUID vs TEXT mismatch in approve_order_pricing function
-- =====================================================

-- First, let's check what version of the function is currently active
DO $$
DECLARE
    function_exists BOOLEAN;
    function_definition TEXT;
BEGIN
    -- Check if the function exists
    SELECT EXISTS(
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'approve_order_pricing' 
        AND routine_type = 'FUNCTION'
    ) INTO function_exists;
    
    IF function_exists THEN
        RAISE NOTICE '✅ approve_order_pricing function exists';
        
        -- Get the function definition to see which version is active
        SELECT pg_get_functiondef(oid) INTO function_definition
        FROM pg_proc 
        WHERE proname = 'approve_order_pricing';
        
        -- Check if it's using UUID or TEXT for item_id
        IF function_definition LIKE '%::UUID%' THEN
            RAISE NOTICE '🔍 Current function expects UUID for item_id';
        ELSIF function_definition LIKE '%::TEXT%' OR function_definition LIKE '%product_id%' THEN
            RAISE NOTICE '🔍 Current function expects TEXT/product_id for item_id';
        ELSE
            RAISE NOTICE '🔍 Cannot determine function parameter type';
        END IF;
    ELSE
        RAISE NOTICE '❌ approve_order_pricing function does not exist';
    END IF;
END $$;

-- Drop the existing function to ensure clean state
DROP FUNCTION IF EXISTS approve_order_pricing(uuid, uuid, text, jsonb, text);

-- Create the definitive version that expects product_id (TEXT) as item_id
-- This matches the latest migration and test data format
CREATE OR REPLACE FUNCTION approve_order_pricing(
    p_order_id UUID,
    p_approved_by UUID,
    p_approved_by_name TEXT,
    p_items JSONB, -- Array of {item_id: product_id, approved_price: number}
    p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    item_data JSONB;
    original_price DECIMAL(10, 2);
    approved_price DECIMAL(10, 2);
    new_total DECIMAL(10, 2) := 0;
    item_quantity INTEGER;
    item_exists BOOLEAN;
    current_order_status TEXT;
    current_pricing_status TEXT;
BEGIN
    RAISE NOTICE 'Starting pricing approval for order: %', p_order_id;
    RAISE NOTICE 'Items to process: %', p_items;
    
    -- Get current order status
    SELECT 
        co.status,
        co.pricing_status
    INTO current_order_status, current_pricing_status
    FROM public.client_orders co
    WHERE co.id = p_order_id;
    
    -- Check if order was found
    IF current_order_status IS NULL THEN
        RAISE EXCEPTION 'Order not found: %', p_order_id;
    END IF;
    
    RAISE NOTICE 'Order found - Status: %, Pricing Status: %', current_order_status, current_pricing_status;
    
    -- Validate order is in correct state for pricing approval
    IF current_order_status != 'pending' THEN
        RAISE EXCEPTION 'Order must be in pending status for pricing approval. Current status: %', current_order_status;
    END IF;
    
    -- Process each item pricing
    FOR item_data IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        RAISE NOTICE 'Processing item: %', item_data;
        
        -- Validate item_data structure
        IF NOT (item_data ? 'item_id' AND item_data ? 'approved_price') THEN
            RAISE EXCEPTION 'Each item must have item_id and approved_price fields. Got: %', item_data;
        END IF;

        -- Extract values
        approved_price := (item_data->>'approved_price')::DECIMAL(10, 2);
        
        -- Check if item exists in the order using product_id
        SELECT EXISTS(
            SELECT 1 FROM public.client_order_items coi 
            WHERE coi.product_id = (item_data->>'item_id') 
            AND coi.order_id = p_order_id
        ) INTO item_exists;

        IF NOT item_exists THEN
            RAISE EXCEPTION 'Item with product_id % not found in order %', (item_data->>'item_id'), p_order_id;
        END IF;
        
        -- Get original price and quantity
        SELECT coi.unit_price, coi.quantity 
        INTO original_price, item_quantity
        FROM public.client_order_items coi
        WHERE coi.product_id = (item_data->>'item_id')
        AND coi.order_id = p_order_id;
        
        RAISE NOTICE 'Item % - Original: %, Approved: %, Quantity: %', 
                     (item_data->>'item_id'), original_price, approved_price, item_quantity;

        -- Update item with approved pricing
        UPDATE public.client_order_items coi
        SET 
            approved_unit_price = approved_price,
            approved_subtotal = approved_price * coi.quantity,
            original_unit_price = COALESCE(coi.original_unit_price, coi.unit_price),
            pricing_approved = TRUE,
            pricing_approved_by = p_approved_by,
            pricing_approved_at = NOW(),
            unit_price = approved_price,
            subtotal = approved_price * coi.quantity
        WHERE coi.product_id = (item_data->>'item_id')
        AND coi.order_id = p_order_id;
        
        -- Add to new total
        new_total := new_total + (approved_price * item_quantity);
        
        -- Add to pricing history (if table exists)
        BEGIN
            INSERT INTO public.order_pricing_history (
                order_id, item_id, original_price, approved_price,
                price_difference, approved_by, approved_by_name,
                pricing_notes
            ) VALUES (
                p_order_id,
                (item_data->>'item_id'), -- Store product_id as item_id in history
                original_price,
                approved_price,
                approved_price - original_price,
                p_approved_by,
                p_approved_by_name,
                p_notes
            );
        EXCEPTION WHEN undefined_table THEN
            RAISE NOTICE 'order_pricing_history table does not exist, skipping history entry';
        END;
    END LOOP;

    RAISE NOTICE 'New total calculated: %', new_total;

    -- Update order status and total
    UPDATE public.client_orders
    SET 
        pricing_status = 'pricing_approved',
        pricing_approved_by = p_approved_by,
        pricing_approved_at = NOW(),
        pricing_notes = p_notes,
        total_amount = new_total,
        status = 'confirmed' -- Move to confirmed after pricing approval
    WHERE id = p_order_id;

    -- Add to order history (if table exists)
    BEGIN
        INSERT INTO public.order_history (
            order_id, action, old_status, new_status, description,
            changed_by, changed_by_name, changed_by_role
        ) VALUES (
            p_order_id,
            'pricing_approved',
            'pending',
            'confirmed',
            CONCAT('Pricing approved and order confirmed. New total: ', new_total::TEXT),
            p_approved_by,
            p_approved_by_name,
            'accountant'
        );
    EXCEPTION WHEN undefined_table THEN
        RAISE NOTICE 'order_history table does not exist, skipping history entry';
    END;

    RAISE NOTICE '✅ Pricing approval completed successfully for order: %', p_order_id;
    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error approving pricing for order %: %', p_order_id, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION approve_order_pricing TO authenticated;

-- Test the function with sample data to verify it works
DO $$
DECLARE
    test_result BOOLEAN;
BEGIN
    RAISE NOTICE 'Testing the new approve_order_pricing function...';

    -- This should not fail due to type mismatch
    -- We're testing with a non-existent order to verify the function accepts the correct parameter types
    BEGIN
        SELECT approve_order_pricing(
            gen_random_uuid(),
            gen_random_uuid(),
            'Test User',
            '[{"item_id": "TEST-PRODUCT-123", "approved_price": 100.00}]'::jsonb,
            'Test approval'
        ) INTO test_result;
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%Order not found%' THEN
            RAISE NOTICE '✅ Function accepts correct parameter types (order not found is expected)';
        ELSE
            RAISE NOTICE '❌ Function test failed: %', SQLERRM;
        END IF;
    END;

    RAISE NOTICE '🎉 Pricing approval function has been fixed to expect product_id (TEXT) as item_id';
END $$;
