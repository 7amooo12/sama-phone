-- =====================================================
-- Verify Pricing Approval System Setup
-- Created: 2024-12-22
-- Purpose: Verify all components of pricing approval system are working
-- =====================================================

-- Drop existing functions to avoid conflicts
DROP FUNCTION IF EXISTS approve_order_pricing(uuid, uuid, text, jsonb, text);
DROP FUNCTION IF EXISTS get_orders_pending_pricing();
DROP FUNCTION IF EXISTS get_order_items_for_pricing(uuid);

-- Create or replace the approve_order_pricing function
CREATE OR REPLACE FUNCTION approve_order_pricing(
    p_order_id UUID,
    p_approved_by UUID,
    p_approved_by_name TEXT,
    p_items JSONB, -- Array of {item_id, approved_price}
    p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    item_record RECORD;
    item_data JSONB;
    original_price DECIMAL(10, 2);
    approved_price DECIMAL(10, 2);
    new_total DECIMAL(10, 2) := 0;
    item_quantity INTEGER;
BEGIN
    -- Validate order exists and is in pending_pricing status
    IF NOT EXISTS (
        SELECT 1 FROM public.client_orders 
        WHERE id = p_order_id AND (pricing_status = 'pending_pricing' OR status = 'pending')
    ) THEN
        RAISE EXCEPTION 'Order not found or not in pending pricing status';
    END IF;

    -- Process each item pricing
    FOR item_data IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        -- Get original price and quantity
        SELECT unit_price, quantity INTO original_price, item_quantity
        FROM public.client_order_items
        WHERE product_id = (item_data->>'item_id')::TEXT
        AND order_id = p_order_id;

        IF original_price IS NULL THEN
            RAISE EXCEPTION 'Item not found: %', (item_data->>'item_id')::TEXT;
        END IF;

        approved_price := (item_data->>'approved_price')::DECIMAL(10, 2);

        -- Update item with approved pricing
        UPDATE public.client_order_items
        SET 
            approved_unit_price = approved_price,
            approved_subtotal = approved_price * quantity,
            original_unit_price = unit_price,
            pricing_approved = TRUE,
            pricing_approved_by = p_approved_by,
            pricing_approved_at = NOW(),
            -- Update the actual unit_price to approved price
            unit_price = approved_price,
            subtotal = approved_price * quantity
        WHERE product_id = (item_data->>'item_id')::TEXT
        AND order_id = p_order_id;

        -- Add to pricing history
        INSERT INTO public.order_pricing_history (
            order_id, item_id, original_price, approved_price,
            price_difference, approved_by, approved_by_name,
            pricing_notes
        ) VALUES (
            p_order_id,
            (item_data->>'item_id')::TEXT,
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
        'Pricing approved and order confirmed',
        p_approved_by,
        p_approved_by_name,
        'accountant'
    );

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error approving pricing: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create or replace function to get orders pending pricing approval
CREATE OR REPLACE FUNCTION get_orders_pending_pricing()
RETURNS TABLE (
    order_id UUID,
    order_number TEXT,
    client_name TEXT,
    client_email TEXT,
    client_phone TEXT,
    total_amount DECIMAL(10, 2),
    items_count INTEGER,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        co.id,
        co.order_number,
        co.client_name,
        co.client_email,
        co.client_phone,
        co.total_amount,
        (SELECT COUNT(*)::INTEGER FROM public.client_order_items WHERE order_id = co.id),
        co.created_at
    FROM public.client_orders co
    WHERE (co.pricing_status = 'pending_pricing' OR (co.pricing_status IS NULL AND co.status = 'pending'))
    AND co.status = 'pending'
    ORDER BY co.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create or replace function to get order items for pricing
CREATE OR REPLACE FUNCTION get_order_items_for_pricing(p_order_id UUID)
RETURNS TABLE (
    item_id TEXT,
    product_id TEXT,
    product_name TEXT,
    product_image TEXT,
    quantity INTEGER,
    unit_price DECIMAL(10, 2),
    subtotal DECIMAL(10, 2),
    pricing_approved BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        coi.product_id,
        coi.product_id,
        coi.product_name,
        coi.product_image,
        coi.quantity,
        coi.unit_price,
        coi.subtotal,
        COALESCE(coi.pricing_approved, FALSE)
    FROM public.client_order_items coi
    WHERE coi.order_id = p_order_id
    ORDER BY coi.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION approve_order_pricing TO authenticated;
GRANT EXECUTE ON FUNCTION get_orders_pending_pricing TO authenticated;
GRANT EXECUTE ON FUNCTION get_order_items_for_pricing TO authenticated;

-- Create RLS policies for pricing approval tables
DO $$
BEGIN
    -- Policy for order_pricing_history
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'order_pricing_history' AND policyname = 'Users can view pricing history'
    ) THEN
        CREATE POLICY "Users can view pricing history" ON public.order_pricing_history
            FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'order_pricing_history' AND policyname = 'Authenticated users can insert pricing history'
    ) THEN
        CREATE POLICY "Authenticated users can insert pricing history" ON public.order_pricing_history
            FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
    END IF;
END $$;

-- Verify the setup by checking if all required columns exist
DO $$
DECLARE
    missing_columns TEXT := '';
BEGIN
    -- Check client_orders columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'client_orders' AND column_name = 'pricing_status') THEN
        missing_columns := missing_columns || 'client_orders.pricing_status, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'client_order_items' AND column_name = 'pricing_approved') THEN
        missing_columns := missing_columns || 'client_order_items.pricing_approved, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_pricing_history') THEN
        missing_columns := missing_columns || 'order_pricing_history table, ';
    END IF;
    
    IF missing_columns != '' THEN
        RAISE NOTICE 'Missing components: %', missing_columns;
    ELSE
        RAISE NOTICE 'Pricing approval system setup completed successfully!';
    END IF;
END $$;
