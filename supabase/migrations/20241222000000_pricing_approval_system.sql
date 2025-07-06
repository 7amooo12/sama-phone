-- =====================================================
-- Pricing Approval System Migration
-- Created: 2024-12-22
-- Purpose: Add sophisticated pricing approval workflow
-- =====================================================

-- Note: Pricing approval columns are now handled by the fix migration
-- This ensures compatibility with existing database structures

-- Create function to approve order pricing
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
BEGIN
    -- Validate order exists and is in pending_pricing status
    IF NOT EXISTS (
        SELECT 1 FROM public.client_orders 
        WHERE id = p_order_id AND pricing_status = 'pending_pricing'
    ) THEN
        RAISE EXCEPTION 'Order not found or not in pending pricing status';
    END IF;

    -- Process each item pricing
    FOR item_data IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        -- Get original price
        SELECT unit_price INTO original_price
        FROM public.client_order_items
        WHERE id = (item_data->>'item_id')::UUID;

        approved_price := (item_data->>'approved_price')::DECIMAL(10, 2);

        -- Update item with approved pricing
        UPDATE public.client_order_items
        SET 
            approved_unit_price = approved_price,
            approved_subtotal = approved_price * quantity,
            original_unit_price = unit_price,
            pricing_approved = TRUE,
            pricing_approved_by = p_approved_by,
            pricing_approved_at = NOW()
        WHERE id = (item_data->>'item_id')::UUID;

        -- Add to pricing history
        INSERT INTO public.order_pricing_history (
            order_id, item_id, original_price, approved_price,
            price_difference, approved_by, approved_by_name,
            pricing_notes
        ) VALUES (
            p_order_id,
            (item_data->>'item_id')::UUID,
            original_price,
            approved_price,
            approved_price - original_price,
            p_approved_by,
            p_approved_by_name,
            p_notes
        );

        -- Add to new total
        SELECT new_total + (approved_price * quantity) INTO new_total
        FROM public.client_order_items
        WHERE id = (item_data->>'item_id')::UUID;
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
    PERFORM add_order_history(
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
END;
$$ LANGUAGE plpgsql;

-- Create function to get orders pending pricing approval
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
    WHERE co.pricing_status = 'pending_pricing'
    AND co.status = 'pending'
    ORDER BY co.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Create function to get order items for pricing
CREATE OR REPLACE FUNCTION get_order_items_for_pricing(p_order_id UUID)
RETURNS TABLE (
    item_id UUID,
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
        coi.id,
        coi.product_id,
        coi.product_name,
        coi.product_image,
        coi.quantity,
        coi.unit_price,
        coi.subtotal,
        coi.pricing_approved
    FROM public.client_order_items coi
    WHERE coi.order_id = p_order_id
    ORDER BY coi.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Add indexes for pricing status
CREATE INDEX IF NOT EXISTS idx_client_orders_pricing_status ON public.client_orders(pricing_status);
CREATE INDEX IF NOT EXISTS idx_client_orders_pricing_approved_by ON public.client_orders(pricing_approved_by);

-- Update existing orders to have pricing_status
UPDATE public.client_orders 
SET pricing_status = CASE 
    WHEN status = 'pending' THEN 'pending_pricing'
    ELSE 'pricing_approved'
END
WHERE pricing_status IS NULL;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION approve_order_pricing TO authenticated;
GRANT EXECUTE ON FUNCTION get_orders_pending_pricing TO authenticated;
GRANT EXECUTE ON FUNCTION get_order_items_for_pricing TO authenticated;
