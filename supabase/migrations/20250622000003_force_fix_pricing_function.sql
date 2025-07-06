-- =====================================================
-- Force Fix Pricing Approval Function
-- Created: 2025-06-22
-- Purpose: Immediately fix the UUID vs TEXT issue in approve_order_pricing
-- =====================================================

-- Drop ALL versions of the function to ensure clean state
DROP FUNCTION IF EXISTS approve_order_pricing(uuid, uuid, text, jsonb, text);
DROP FUNCTION IF EXISTS approve_order_pricing(uuid, uuid, text, jsonb);

-- Create the correct version that expects TEXT (product_id) for item_id
CREATE OR REPLACE FUNCTION approve_order_pricing(
    p_order_id UUID,
    p_approved_by UUID,
    p_approved_by_name TEXT,
    p_items JSONB, -- Array of {item_id: product_id (TEXT), approved_price: number}
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
BEGIN
    -- Validate order exists and is in correct state
    IF NOT EXISTS (
        SELECT 1 FROM public.client_orders 
        WHERE id = p_order_id AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'Order not found or not in pending status: %', p_order_id;
    END IF;
    
    -- Process each item pricing
    FOR item_data IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        -- Validate item_data structure
        IF NOT (item_data ? 'item_id' AND item_data ? 'approved_price') THEN
            RAISE EXCEPTION 'Each item must have item_id and approved_price fields';
        END IF;

        -- Extract approved price
        approved_price := (item_data->>'approved_price')::DECIMAL(10, 2);
        
        -- Check if item exists using product_id (TEXT)
        SELECT EXISTS(
            SELECT 1 FROM public.client_order_items 
            WHERE product_id = (item_data->>'item_id') 
            AND order_id = p_order_id
        ) INTO item_exists;

        IF NOT item_exists THEN
            RAISE EXCEPTION 'Item with product_id % not found in order %', 
                (item_data->>'item_id'), p_order_id;
        END IF;
        
        -- Get original price and quantity using product_id (TEXT)
        SELECT unit_price, quantity 
        INTO original_price, item_quantity
        FROM public.client_order_items
        WHERE product_id = (item_data->>'item_id')
        AND order_id = p_order_id;

        -- Update item with approved pricing using product_id (TEXT)
        UPDATE public.client_order_items
        SET 
            approved_unit_price = approved_price,
            approved_subtotal = approved_price * quantity,
            original_unit_price = COALESCE(original_unit_price, unit_price),
            pricing_approved = TRUE,
            pricing_approved_by = p_approved_by,
            pricing_approved_at = NOW(),
            unit_price = approved_price,
            subtotal = approved_price * quantity
        WHERE product_id = (item_data->>'item_id')  -- Using product_id (TEXT)
        AND order_id = p_order_id;
        
        -- Add to new total
        new_total := new_total + (approved_price * item_quantity);
    END LOOP;

    -- Update order status and total
    UPDATE public.client_orders
    SET 
        pricing_status = 'pricing_approved',
        pricing_approved_by = p_approved_by,
        pricing_approved_at = NOW(),
        pricing_notes = p_notes,
        total_amount = new_total,
        status = 'confirmed'
    WHERE id = p_order_id;

    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error approving pricing for order %: %', p_order_id, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION approve_order_pricing TO authenticated;

-- Test the function to verify it works with TEXT parameters
DO $$
DECLARE
    test_order_id UUID;
    test_user_id UUID := gen_random_uuid();
    test_result BOOLEAN;
BEGIN
    -- Create a test order
    INSERT INTO public.client_orders (
        client_id, client_name, client_email, client_phone,
        order_number, total_amount, status, pricing_status
    ) VALUES (
        gen_random_uuid(), 'Test Customer', 'test@example.com', '1234567890',
        'TEST-' || extract(epoch from now())::text, 100.00, 'pending', 'pending_pricing'
    ) RETURNING id INTO test_order_id;
    
    -- Add a test item
    INSERT INTO public.client_order_items (
        order_id, product_id, product_name, unit_price, quantity, subtotal
    ) VALUES (
        test_order_id, 'TEST-PRODUCT-123', 'Test Product', 50.00, 2, 100.00
    );
    
    -- Test the function with TEXT item_id
    SELECT approve_order_pricing(
        test_order_id,
        test_user_id,
        'Test User',
        '[{"item_id": "TEST-PRODUCT-123", "approved_price": 60.00}]'::jsonb,
        'Test approval'
    ) INTO test_result;
    
    IF test_result THEN
        RAISE NOTICE '✅ Function test PASSED - accepts TEXT item_id correctly';
    ELSE
        RAISE NOTICE '❌ Function test FAILED - returned false';
    END IF;
    
    -- Clean up test data
    DELETE FROM public.client_order_items WHERE order_id = test_order_id;
    DELETE FROM public.client_orders WHERE id = test_order_id;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Function test FAILED with error: %', SQLERRM;
    -- Clean up on error
    BEGIN
        DELETE FROM public.client_order_items WHERE order_id = test_order_id;
        DELETE FROM public.client_orders WHERE id = test_order_id;
    EXCEPTION WHEN OTHERS THEN
        -- Ignore cleanup errors
    END;
END $$;
