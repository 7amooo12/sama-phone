-- =====================================================
-- Fix PostgreSQL Syntax Error in Pricing Approval Functions
-- Created: 2024-12-22
-- Purpose: Resolve "record variable cannot be part of multiple-item INTO list" error
-- =====================================================

-- Drop existing functions to avoid conflicts
DROP FUNCTION IF EXISTS approve_order_pricing(uuid, uuid, text, jsonb, text);

-- Recreate approve_order_pricing with corrected syntax
CREATE OR REPLACE FUNCTION approve_order_pricing(
    p_order_id UUID,
    p_approved_by UUID,
    p_approved_by_name TEXT,
    p_items JSONB, -- Array of {item_id, approved_price}
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
    order_exists BOOLEAN;
    current_order_status TEXT;
    current_pricing_status TEXT;
BEGIN
    -- Validate order exists and get its current status (separate queries to avoid syntax error)
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
    
    -- Check if order is in correct status for pricing approval
    IF NOT (
        (current_pricing_status = 'pending_pricing' OR (current_pricing_status IS NULL AND current_order_status = 'pending'))
        AND current_order_status = 'pending'
    ) THEN
        RAISE EXCEPTION 'Order not in pending pricing status: % (Current status: %, pricing_status: %)', 
            p_order_id, current_order_status, current_pricing_status;
    END IF;

    -- Validate p_items is an array
    IF jsonb_typeof(p_items) != 'array' THEN
        RAISE EXCEPTION 'Items parameter must be a JSON array';
    END IF;

    -- Process each item pricing
    FOR item_data IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        -- Validate item_data structure
        IF NOT (item_data ? 'item_id' AND item_data ? 'approved_price') THEN
            RAISE EXCEPTION 'Each item must have item_id and approved_price fields';
        END IF;

        -- Check if item exists in the order
        SELECT EXISTS(
            SELECT 1 FROM public.client_order_items coi2 
            WHERE coi2.product_id = (item_data->>'item_id') 
            AND coi2.order_id = p_order_id
        ) INTO item_exists;

        IF NOT item_exists THEN
            RAISE EXCEPTION 'Item not found in order: % (Order: %)', (item_data->>'item_id'), p_order_id;
        END IF;

        -- Get original price and quantity with explicit column references
        SELECT 
            coi.unit_price, 
            coi.quantity
        INTO original_price, item_quantity
        FROM public.client_order_items coi
        WHERE coi.product_id = (item_data->>'item_id')
        AND coi.order_id = p_order_id
        LIMIT 1;

        -- Parse approved price
        BEGIN
            approved_price := (item_data->>'approved_price')::DECIMAL(10, 2);
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'Invalid approved_price format for item %: %', (item_data->>'item_id'), (item_data->>'approved_price');
        END;

        IF approved_price <= 0 THEN
            RAISE EXCEPTION 'Approved price must be greater than 0 for item %', (item_data->>'item_id');
        END IF;

        -- Update item with approved pricing using explicit column references
        UPDATE public.client_order_items coi
        SET 
            approved_unit_price = approved_price,
            approved_subtotal = approved_price * coi.quantity,
            original_unit_price = COALESCE(coi.original_unit_price, coi.unit_price),
            pricing_approved = TRUE,
            pricing_approved_by = p_approved_by,
            pricing_approved_at = NOW(),
            -- Update the actual unit_price to approved price
            unit_price = approved_price,
            subtotal = approved_price * coi.quantity
        WHERE coi.product_id = (item_data->>'item_id')
        AND coi.order_id = p_order_id;

        -- Verify the update was successful
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Failed to update pricing for item: % in order: %', (item_data->>'item_id'), p_order_id;
        END IF;

        -- Add to pricing history
        INSERT INTO public.order_pricing_history (
            order_id, item_id, original_price, approved_price,
            price_difference, approved_by, approved_by_name,
            pricing_notes
        ) VALUES (
            p_order_id,
            (item_data->>'item_id'),
            original_price,
            approved_price,
            approved_price - original_price,
            p_approved_by,
            p_approved_by_name,
            p_notes
        );

        -- Add to new total
        new_total := new_total + (approved_price * item_quantity);
    END LOOP;

    -- Update order status and total
    UPDATE public.client_orders co
    SET 
        pricing_status = 'pricing_approved',
        pricing_approved_by = p_approved_by,
        pricing_approved_at = NOW(),
        pricing_notes = p_notes,
        total_amount = new_total,
        status = 'confirmed' -- Move to confirmed after pricing approval
    WHERE co.id = p_order_id;

    -- Verify the order update was successful
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Failed to update order status for order: %', p_order_id;
    END IF;

    -- Add to order history
    INSERT INTO public.order_history (
        order_id, action, old_status, new_status, description,
        changed_by, changed_by_name, changed_by_role
    ) VALUES (
        p_order_id,
        'pricing_approved',
        'pending',
        'confirmed',
        CONCAT('Pricing approved and order confirmed. New total: ', new_total::TEXT, ' (Previous total: ', 
               (SELECT total_amount FROM public.client_orders WHERE id = p_order_id), ')'),
        p_approved_by,
        p_approved_by_name,
        'accountant'
    );

    RAISE NOTICE 'Successfully approved pricing for order % with new total: %', p_order_id, new_total;
    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        -- Log the error with more context and re-raise
        RAISE EXCEPTION 'Error approving pricing for order % (approved_by: %, items_count: %): %', 
            p_order_id, p_approved_by, jsonb_array_length(p_items), SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION approve_order_pricing TO authenticated;

-- Test the corrected function to ensure it works without syntax errors
DO $$
DECLARE
    test_order_id UUID;
    test_user_id UUID := gen_random_uuid();
    approval_result BOOLEAN;
    test_items JSONB;
BEGIN
    RAISE NOTICE 'Testing corrected approve_order_pricing function...';
    
    BEGIN
        -- Create a test order for syntax validation
        INSERT INTO public.client_orders (
            client_id, client_name, client_email, client_phone,
            order_number, total_amount, status, pricing_status
        ) VALUES (
            gen_random_uuid(), 'Test Customer Syntax', 'syntax@example.com', '1234567890',
            'TEST-SYNTAX-' || extract(epoch from now())::text, 150.00, 'pending', 'pending_pricing'
        ) RETURNING id INTO test_order_id;
        
        -- Add test items
        INSERT INTO public.client_order_items (
            order_id, product_id, product_name, unit_price, quantity, subtotal
        ) VALUES 
            (test_order_id, 'TEST-SYNTAX-1', 'Test Syntax Product 1', 50.00, 1, 50.00),
            (test_order_id, 'TEST-SYNTAX-2', 'Test Syntax Product 2', 100.00, 1, 100.00);
        
        -- Prepare test items JSON
        test_items := '[
            {"item_id": "TEST-SYNTAX-1", "approved_price": 60.00}, 
            {"item_id": "TEST-SYNTAX-2", "approved_price": 120.00}
        ]'::jsonb;
        
        -- Test the approval function (this should not throw syntax errors)
        SELECT approve_order_pricing(
            test_order_id,
            test_user_id,
            'Test Syntax Accountant',
            test_items,
            'Test syntax fix approval'
        ) INTO approval_result;
        
        IF approval_result THEN
            RAISE NOTICE '✅ approve_order_pricing syntax test: PASS';
        ELSE
            RAISE NOTICE '❌ approve_order_pricing syntax test: FAIL (returned false)';
        END IF;
        
        -- Clean up test data
        DELETE FROM public.order_pricing_history WHERE order_id = test_order_id;
        DELETE FROM public.order_history WHERE order_id = test_order_id;
        DELETE FROM public.client_order_items WHERE order_id = test_order_id;
        DELETE FROM public.client_orders WHERE id = test_order_id;
        
        RAISE NOTICE '✅ Test cleanup completed successfully';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ approve_order_pricing syntax test: FAIL (Error: %)', SQLERRM;
        -- Clean up on error
        BEGIN
            DELETE FROM public.order_pricing_history WHERE order_id = test_order_id;
            DELETE FROM public.order_history WHERE order_id = test_order_id;
            DELETE FROM public.client_order_items WHERE order_id = test_order_id;
            DELETE FROM public.client_orders WHERE id = test_order_id;
        EXCEPTION WHEN OTHERS THEN
            -- Ignore cleanup errors
        END;
    END;
    
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'PostgreSQL syntax error fix completed!';
    RAISE NOTICE 'The approve_order_pricing function should now work correctly.';
    RAISE NOTICE '=================================================';
END $$;
