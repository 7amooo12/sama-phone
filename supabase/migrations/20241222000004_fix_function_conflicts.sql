-- =====================================================
-- Fix Function Conflicts for Pricing Approval System
-- Created: 2024-12-22
-- Purpose: Resolve PostgreSQL function signature conflicts
-- =====================================================

-- Drop existing conflicting functions first
DROP FUNCTION IF EXISTS get_order_items_for_pricing(uuid);
DROP FUNCTION IF EXISTS get_orders_pending_pricing();
DROP FUNCTION IF EXISTS approve_order_pricing(uuid, uuid, text, jsonb, text);

-- Recreate get_order_items_for_pricing with correct signature
CREATE OR REPLACE FUNCTION get_order_items_for_pricing(p_order_id UUID)
RETURNS TABLE (
    item_id TEXT,
    product_id TEXT,
    product_name TEXT,
    product_image TEXT,
    quantity INTEGER,
    unit_price DECIMAL(10, 2),
    subtotal DECIMAL(10, 2),
    pricing_approved BOOLEAN,
    approved_unit_price DECIMAL(10, 2),
    approved_subtotal DECIMAL(10, 2),
    original_unit_price DECIMAL(10, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        coi.product_id::TEXT as item_id,
        coi.product_id::TEXT,
        coi.product_name::TEXT,
        COALESCE(coi.product_image, '')::TEXT,
        coi.quantity::INTEGER,
        coi.unit_price::DECIMAL(10, 2),
        coi.subtotal::DECIMAL(10, 2),
        COALESCE(coi.pricing_approved, FALSE)::BOOLEAN,
        coi.approved_unit_price::DECIMAL(10, 2),
        coi.approved_subtotal::DECIMAL(10, 2),
        coi.original_unit_price::DECIMAL(10, 2)
    FROM public.client_order_items coi
    WHERE coi.order_id = p_order_id
    ORDER BY coi.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate get_orders_pending_pricing with correct signature
CREATE OR REPLACE FUNCTION get_orders_pending_pricing()
RETURNS TABLE (
    order_id UUID,
    order_number TEXT,
    client_name TEXT,
    client_email TEXT,
    client_phone TEXT,
    total_amount DECIMAL(10, 2),
    items_count BIGINT,
    created_at TIMESTAMP WITH TIME ZONE,
    pricing_status TEXT,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        co.id::UUID,
        COALESCE(co.order_number, '')::TEXT,
        COALESCE(co.client_name, '')::TEXT,
        COALESCE(co.client_email, '')::TEXT,
        COALESCE(co.client_phone, '')::TEXT,
        COALESCE(co.total_amount, 0)::DECIMAL(10, 2),
        (SELECT COUNT(*) FROM public.client_order_items coi WHERE coi.order_id = co.id)::BIGINT,
        co.created_at::TIMESTAMP WITH TIME ZONE,
        COALESCE(co.pricing_status, 'pending_pricing')::TEXT,
        co.status::TEXT
    FROM public.client_orders co
    WHERE (
        co.pricing_status = 'pending_pricing' 
        OR (co.pricing_status IS NULL AND co.status = 'pending')
    )
    AND co.status = 'pending'
    ORDER BY co.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate approve_order_pricing with enhanced error handling
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
BEGIN
    -- Validate order exists and is in correct status
    SELECT EXISTS(
        SELECT 1 FROM public.client_orders 
        WHERE id = p_order_id 
        AND (pricing_status = 'pending_pricing' OR (pricing_status IS NULL AND status = 'pending'))
        AND status = 'pending'
    ) INTO order_exists;
    
    IF NOT order_exists THEN
        RAISE EXCEPTION 'Order not found or not in pending pricing status: %', p_order_id;
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

        -- Get original price and quantity
        SELECT 
            unit_price, 
            quantity,
            EXISTS(SELECT 1 FROM public.client_order_items WHERE product_id = (item_data->>'item_id') AND order_id = p_order_id)
        INTO original_price, item_quantity, item_exists
        FROM public.client_order_items
        WHERE product_id = (item_data->>'item_id')
        AND order_id = p_order_id
        LIMIT 1;

        IF NOT item_exists THEN
            RAISE EXCEPTION 'Item not found in order: % (Order: %)', (item_data->>'item_id'), p_order_id;
        END IF;

        -- Parse approved price
        BEGIN
            approved_price := (item_data->>'approved_price')::DECIMAL(10, 2);
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'Invalid approved_price format for item %: %', (item_data->>'item_id'), (item_data->>'approved_price');
        END;

        IF approved_price <= 0 THEN
            RAISE EXCEPTION 'Approved price must be greater than 0 for item %', (item_data->>'item_id');
        END IF;

        -- Update item with approved pricing
        UPDATE public.client_order_items
        SET 
            approved_unit_price = approved_price,
            approved_subtotal = approved_price * quantity,
            original_unit_price = COALESCE(original_unit_price, unit_price),
            pricing_approved = TRUE,
            pricing_approved_by = p_approved_by,
            pricing_approved_at = NOW(),
            -- Update the actual unit_price to approved price
            unit_price = approved_price,
            subtotal = approved_price * quantity
        WHERE product_id = (item_data->>'item_id')
        AND order_id = p_order_id;

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
    UPDATE public.client_orders
    SET 
        pricing_status = 'pricing_approved',
        pricing_approved_by = p_approved_by,
        pricing_approved_at = NOW(),
        pricing_notes = p_notes,
        total_amount = new_total,
        status = 'confirmed' -- Move to confirmed after pricing approval
    WHERE id = p_order_id;

    -- Add to order history
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

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error and re-raise
        RAISE EXCEPTION 'Error approving pricing for order %: %', p_order_id, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on all functions
GRANT EXECUTE ON FUNCTION approve_order_pricing TO authenticated;
GRANT EXECUTE ON FUNCTION get_orders_pending_pricing TO authenticated;
GRANT EXECUTE ON FUNCTION get_order_items_for_pricing TO authenticated;

-- Test the functions to ensure they work
DO $$
DECLARE
    test_result RECORD;
    function_count INTEGER;
BEGIN
    -- Test get_orders_pending_pricing function
    SELECT COUNT(*) INTO function_count FROM get_orders_pending_pricing();
    RAISE NOTICE 'get_orders_pending_pricing function test: PASS (returned % rows)', function_count;
    
    -- Test function exists
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'get_order_items_for_pricing') THEN
        RAISE NOTICE 'get_order_items_for_pricing function: EXISTS';
    ELSE
        RAISE NOTICE 'get_order_items_for_pricing function: MISSING';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'approve_order_pricing') THEN
        RAISE NOTICE 'approve_order_pricing function: EXISTS';
    ELSE
        RAISE NOTICE 'approve_order_pricing function: MISSING';
    END IF;
    
    RAISE NOTICE 'Function conflict resolution completed successfully!';
END $$;
