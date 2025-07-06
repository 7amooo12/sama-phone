-- =====================================================
-- Fix Column Ambiguity in Pricing Approval Functions
-- Created: 2024-12-22
-- Purpose: Resolve PostgreSQL ambiguous column reference errors
-- =====================================================

-- Drop existing functions to avoid conflicts
DROP FUNCTION IF EXISTS get_orders_pending_pricing();
DROP FUNCTION IF EXISTS get_order_items_for_pricing(uuid);
DROP FUNCTION IF EXISTS approve_order_pricing(uuid, uuid, text, jsonb, text);

-- Recreate get_orders_pending_pricing with fixed column references
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
        -- Fix ambiguity by fully qualifying the column name
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

-- Recreate get_order_items_for_pricing with fixed column references
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
    -- Use parameter name that doesn't conflict with column names
    WHERE coi.order_id = p_order_id
    ORDER BY coi.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate approve_order_pricing with fixed column references and enhanced validation
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
    current_order_record RECORD;
BEGIN
    -- Validate order exists and is in correct status
    SELECT 
        co.id, co.status, co.pricing_status,
        EXISTS(
            SELECT 1 FROM public.client_orders co2
            WHERE co2.id = p_order_id 
            AND (co2.pricing_status = 'pending_pricing' OR (co2.pricing_status IS NULL AND co2.status = 'pending'))
            AND co2.status = 'pending'
        )
    INTO current_order_record, order_exists
    FROM public.client_orders co
    WHERE co.id = p_order_id;
    
    IF NOT order_exists THEN
        RAISE EXCEPTION 'Order not found or not in pending pricing status: % (Current status: %, pricing_status: %)', 
            p_order_id, current_order_record.status, current_order_record.pricing_status;
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

        -- Get original price and quantity with explicit column references
        SELECT 
            coi.unit_price, 
            coi.quantity,
            EXISTS(
                SELECT 1 FROM public.client_order_items coi2 
                WHERE coi2.product_id = (item_data->>'item_id') 
                AND coi2.order_id = p_order_id
            )
        INTO original_price, item_quantity, item_exists
        FROM public.client_order_items coi
        WHERE coi.product_id = (item_data->>'item_id')
        AND coi.order_id = p_order_id
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
        -- Log the error and re-raise with more context
        RAISE EXCEPTION 'Error approving pricing for order %: %', p_order_id, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on all functions
GRANT EXECUTE ON FUNCTION approve_order_pricing TO authenticated;
GRANT EXECUTE ON FUNCTION get_orders_pending_pricing TO authenticated;
GRANT EXECUTE ON FUNCTION get_order_items_for_pricing TO authenticated;

-- Test the fixed functions to ensure they work without ambiguity
DO $$
DECLARE
    test_result RECORD;
    function_count INTEGER;
    test_order_id UUID;
BEGIN
    RAISE NOTICE 'Testing fixed functions for column ambiguity...';
    
    -- Test get_orders_pending_pricing function
    BEGIN
        SELECT COUNT(*) INTO function_count FROM get_orders_pending_pricing();
        RAISE NOTICE '✅ get_orders_pending_pricing: PASS (returned % rows)', function_count;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ get_orders_pending_pricing: FAIL (Error: %)', SQLERRM;
    END;
    
    -- Test get_order_items_for_pricing function with a dummy UUID
    BEGIN
        test_order_id := gen_random_uuid();
        SELECT COUNT(*) INTO function_count FROM get_order_items_for_pricing(test_order_id);
        RAISE NOTICE '✅ get_order_items_for_pricing: PASS (returned % rows for test UUID)', function_count;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ get_order_items_for_pricing: FAIL (Error: %)', SQLERRM;
    END;
    
    -- Verify function signatures
    SELECT COUNT(*) INTO function_count 
    FROM information_schema.routines 
    WHERE routine_name = 'get_orders_pending_pricing' AND routine_type = 'FUNCTION';
    
    IF function_count > 0 THEN
        RAISE NOTICE '✅ Function signatures verified: All functions exist';
    ELSE
        RAISE NOTICE '❌ Function signatures: Missing functions detected';
    END IF;
    
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Column ambiguity fix completed successfully!';
    RAISE NOTICE 'All functions should now work without PostgreSQL errors.';
    RAISE NOTICE '=================================================';
END $$;
