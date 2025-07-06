-- =====================================================
-- Final Pricing Approval System Setup
-- Created: 2024-12-22
-- Purpose: Ensure complete pricing approval system is ready for production
-- =====================================================

-- Ensure all required columns exist with proper defaults
DO $$
BEGIN
    -- Update existing orders to have proper pricing_status
    UPDATE public.client_orders 
    SET pricing_status = 'pending_pricing'
    WHERE pricing_status IS NULL 
    AND status = 'pending';
    
    UPDATE public.client_orders 
    SET pricing_status = 'pricing_approved'
    WHERE pricing_status IS NULL 
    AND status != 'pending';
    
    RAISE NOTICE 'Updated existing orders with pricing_status';
END $$;

-- Create indexes for optimal performance
CREATE INDEX IF NOT EXISTS idx_client_orders_pricing_workflow 
ON public.client_orders(status, pricing_status, created_at) 
WHERE status = 'pending' AND pricing_status = 'pending_pricing';

CREATE INDEX IF NOT EXISTS idx_client_order_items_pricing_lookup 
ON public.client_order_items(order_id, product_id, pricing_approved);

-- Create a view for easy pricing approval queries
CREATE OR REPLACE VIEW pricing_approval_dashboard AS
SELECT 
    co.id as order_id,
    co.order_number,
    co.client_name,
    co.client_email,
    co.client_phone,
    co.total_amount,
    co.status,
    co.pricing_status,
    co.created_at,
    co.pricing_approved_at,
    co.pricing_notes,
    (SELECT COUNT(*) FROM public.client_order_items WHERE order_id = co.id) as items_count,
    (SELECT COUNT(*) FROM public.client_order_items WHERE order_id = co.id AND pricing_approved = true) as approved_items_count,
    CASE 
        WHEN co.pricing_status = 'pending_pricing' THEN 'Pending Pricing Approval'
        WHEN co.pricing_status = 'pricing_approved' THEN 'Pricing Approved'
        WHEN co.pricing_status = 'pricing_rejected' THEN 'Pricing Rejected'
        ELSE 'Unknown Status'
    END as pricing_status_display
FROM public.client_orders co
WHERE co.status = 'pending' OR co.pricing_status IN ('pending_pricing', 'pricing_approved', 'pricing_rejected')
ORDER BY 
    CASE co.pricing_status 
        WHEN 'pending_pricing' THEN 1 
        WHEN 'pricing_approved' THEN 2 
        ELSE 3 
    END,
    co.created_at ASC;

-- Grant permissions on the view
GRANT SELECT ON pricing_approval_dashboard TO authenticated;

-- Create a function to get pricing approval statistics
CREATE OR REPLACE FUNCTION get_pricing_approval_stats()
RETURNS TABLE (
    pending_count BIGINT,
    approved_count BIGINT,
    rejected_count BIGINT,
    total_pending_value DECIMAL(10, 2),
    total_approved_value DECIMAL(10, 2),
    avg_approval_time_hours DECIMAL(10, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM public.client_orders WHERE pricing_status = 'pending_pricing')::BIGINT,
        (SELECT COUNT(*) FROM public.client_orders WHERE pricing_status = 'pricing_approved')::BIGINT,
        (SELECT COUNT(*) FROM public.client_orders WHERE pricing_status = 'pricing_rejected')::BIGINT,
        (SELECT COALESCE(SUM(total_amount), 0) FROM public.client_orders WHERE pricing_status = 'pending_pricing')::DECIMAL(10, 2),
        (SELECT COALESCE(SUM(total_amount), 0) FROM public.client_orders WHERE pricing_status = 'pricing_approved')::DECIMAL(10, 2),
        (SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (pricing_approved_at - created_at))/3600), 0) 
         FROM public.client_orders 
         WHERE pricing_status = 'pricing_approved' AND pricing_approved_at IS NOT NULL)::DECIMAL(10, 2);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_pricing_approval_stats TO authenticated;

-- Create a function to bulk approve pricing for multiple orders
CREATE OR REPLACE FUNCTION bulk_approve_pricing(
    p_order_ids UUID[],
    p_approved_by UUID,
    p_approved_by_name TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    order_id UUID,
    success BOOLEAN,
    error_message TEXT
) AS $$
DECLARE
    order_id UUID;
    approval_success BOOLEAN;
    error_msg TEXT;
BEGIN
    FOREACH order_id IN ARRAY p_order_ids
    LOOP
        BEGIN
            -- Get all items for this order and approve with current prices
            SELECT approve_order_pricing(
                order_id,
                p_approved_by,
                p_approved_by_name,
                (SELECT jsonb_agg(jsonb_build_object('item_id', product_id, 'approved_price', unit_price))
                 FROM public.client_order_items 
                 WHERE order_id = order_id),
                p_notes
            ) INTO approval_success;
            
            RETURN QUERY SELECT order_id, approval_success, NULL::TEXT;
            
        EXCEPTION WHEN OTHERS THEN
            error_msg := SQLERRM;
            RETURN QUERY SELECT order_id, FALSE, error_msg;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION bulk_approve_pricing TO authenticated;

-- Create RLS policies for pricing approval
DO $$
BEGIN
    -- Policy for pricing_approval_dashboard view
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'client_orders' AND policyname = 'Pricing approval access'
    ) THEN
        CREATE POLICY "Pricing approval access" ON public.client_orders
            FOR ALL USING (true);
    END IF;
END $$;

-- Create a trigger to automatically set pricing_status for new orders
CREATE OR REPLACE FUNCTION set_default_pricing_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.pricing_status IS NULL THEN
        NEW.pricing_status := 'pending_pricing';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_default_pricing_status ON public.client_orders;
CREATE TRIGGER trigger_set_default_pricing_status
    BEFORE INSERT ON public.client_orders
    FOR EACH ROW
    EXECUTE FUNCTION set_default_pricing_status();

-- Final verification
DO $$
DECLARE
    missing_components TEXT := '';
    component_count INTEGER;
BEGIN
    RAISE NOTICE 'Performing final verification of pricing approval system...';
    
    -- Check tables
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'client_orders') THEN
        missing_components := missing_components || 'client_orders table, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'client_order_items') THEN
        missing_components := missing_components || 'client_order_items table, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_pricing_history') THEN
        missing_components := missing_components || 'order_pricing_history table, ';
    END IF;
    
    -- Check columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'client_orders' AND column_name = 'pricing_status') THEN
        missing_components := missing_components || 'pricing_status column, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'client_order_items' AND column_name = 'pricing_approved') THEN
        missing_components := missing_components || 'pricing_approved column, ';
    END IF;
    
    -- Check functions
    SELECT COUNT(*) INTO component_count FROM information_schema.routines WHERE routine_name = 'approve_order_pricing';
    IF component_count = 0 THEN
        missing_components := missing_components || 'approve_order_pricing function, ';
    END IF;
    
    SELECT COUNT(*) INTO component_count FROM information_schema.routines WHERE routine_name = 'get_orders_pending_pricing';
    IF component_count = 0 THEN
        missing_components := missing_components || 'get_orders_pending_pricing function, ';
    END IF;
    
    SELECT COUNT(*) INTO component_count FROM information_schema.routines WHERE routine_name = 'get_order_items_for_pricing';
    IF component_count = 0 THEN
        missing_components := missing_components || 'get_order_items_for_pricing function, ';
    END IF;
    
    -- Check views
    IF NOT EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'pricing_approval_dashboard') THEN
        missing_components := missing_components || 'pricing_approval_dashboard view, ';
    END IF;
    
    IF missing_components = '' THEN
        RAISE NOTICE '✅ PRICING APPROVAL SYSTEM SETUP COMPLETE!';
        RAISE NOTICE '✅ All required components are in place and ready for use.';
        RAISE NOTICE '✅ The system is ready for production deployment.';
    ELSE
        RAISE NOTICE '❌ SETUP INCOMPLETE - Missing components: %', missing_components;
    END IF;
    
    -- Show statistics
    SELECT COUNT(*) INTO component_count FROM public.client_orders WHERE pricing_status = 'pending_pricing';
    RAISE NOTICE 'Current orders pending pricing approval: %', component_count;
    
    SELECT COUNT(*) INTO component_count FROM public.client_orders WHERE pricing_status = 'pricing_approved';
    RAISE NOTICE 'Current orders with approved pricing: %', component_count;
END $$;
