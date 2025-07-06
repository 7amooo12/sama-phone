-- تحسين تتبع طلبات الصرف وعرض المنتجات
-- Enhance dispatch tracking and product display

-- Step 1: Add invoice_id column to warehouse_requests for better tracking
DO $$
BEGIN
    -- Add invoice_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_requests' 
        AND column_name = 'invoice_id'
    ) THEN
        ALTER TABLE public.warehouse_requests 
        ADD COLUMN invoice_id TEXT;
        
        -- Add index for better performance
        CREATE INDEX idx_warehouse_requests_invoice_id 
        ON public.warehouse_requests(invoice_id);
    END IF;
END $$;

-- Step 2: Create view for enhanced dispatch details with product information
CREATE OR REPLACE VIEW warehouse_dispatch_details AS
SELECT 
    wr.id,
    wr.request_number,
    wr.type,
    wr.status,
    wr.reason,
    wr.requested_by,
    wr.approved_by,
    wr.executed_by,
    wr.requested_at,
    wr.approved_at,
    wr.executed_at,
    wr.notes,
    wr.warehouse_id,
    wr.target_warehouse_id,
    wr.invoice_id,
    w.name as warehouse_name,
    w.address as warehouse_address,
    tw.name as target_warehouse_name,
    requester.name as requester_name,
    requester.email as requester_email,
    approver.name as approver_name,
    approver.email as approver_email,
    executor.name as executor_name,
    executor.email as executor_email,
    -- Aggregate item information
    COALESCE(
        json_agg(
            json_build_object(
                'id', wri.id,
                'product_id', wri.product_id,
                'quantity', wri.quantity,
                'notes', wri.notes,
                'product_name', p.name,
                'product_category', p.category,
                'product_price', p.price,
                'product_image_url', p.image_url,
                'product_sku', p.sku
            ) ORDER BY wri.id
        ) FILTER (WHERE wri.id IS NOT NULL),
        '[]'::json
    ) as items
FROM public.warehouse_requests wr
LEFT JOIN public.warehouses w ON wr.warehouse_id = w.id
LEFT JOIN public.warehouses tw ON wr.target_warehouse_id = tw.id
LEFT JOIN public.user_profiles requester ON wr.requested_by = requester.id
LEFT JOIN public.user_profiles approver ON wr.approved_by = approver.id
LEFT JOIN public.user_profiles executor ON wr.executed_by = executor.id
LEFT JOIN public.warehouse_request_items wri ON wr.id = wri.request_id
LEFT JOIN public.products p ON wri.product_id = p.id
GROUP BY 
    wr.id, wr.request_number, wr.type, wr.status, wr.reason,
    wr.requested_by, wr.approved_by, wr.executed_by,
    wr.requested_at, wr.approved_at, wr.executed_at,
    wr.notes, wr.warehouse_id, wr.target_warehouse_id, wr.invoice_id,
    w.name, w.address, tw.name,
    requester.name, requester.email,
    approver.name, approver.email,
    executor.name, executor.email;

-- Step 3: Create function to get dispatch by invoice ID
CREATE OR REPLACE FUNCTION get_dispatch_by_invoice_id(p_invoice_id TEXT)
RETURNS TABLE (
    dispatch_id UUID,
    request_number TEXT,
    type TEXT,
    status TEXT,
    reason TEXT,
    requested_by UUID,
    requested_at TIMESTAMPTZ,
    warehouse_id UUID,
    warehouse_name TEXT,
    items JSON
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wdd.id,
        wdd.request_number,
        wdd.type,
        wdd.status,
        wdd.reason,
        wdd.requested_by,
        wdd.requested_at,
        wdd.warehouse_id,
        wdd.warehouse_name,
        wdd.items
    FROM warehouse_dispatch_details wdd
    WHERE wdd.invoice_id = p_invoice_id
    OR wdd.reason LIKE '%' || p_invoice_id || '%'
    ORDER BY wdd.requested_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create function to update dispatch with invoice ID
CREATE OR REPLACE FUNCTION link_dispatch_to_invoice(
    p_request_id UUID,
    p_invoice_id TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.warehouse_requests
    SET invoice_id = p_invoice_id
    WHERE id = p_request_id;
    
    RETURN FOUND;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create function for enhanced dispatch creation with invoice linking
CREATE OR REPLACE FUNCTION create_dispatch_from_invoice(
    p_invoice_id TEXT,
    p_customer_name TEXT,
    p_total_amount DECIMAL,
    p_warehouse_id UUID,
    p_requested_by UUID,
    p_notes TEXT DEFAULT NULL,
    p_items JSON DEFAULT '[]'::json
)
RETURNS TABLE (
    dispatch_id UUID,
    request_number TEXT,
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_request_id UUID;
    v_request_number TEXT;
    v_item JSON;
    v_item_count INTEGER := 0;
BEGIN
    -- Generate request number
    v_request_number := 'WD' || 
                       TO_CHAR(NOW(), 'YYYYMMDD') || '-' || 
                       LPAD(EXTRACT(EPOCH FROM NOW())::TEXT, 6, '0');
    
    -- Create main dispatch request
    INSERT INTO public.warehouse_requests (
        request_number,
        type,
        status,
        reason,
        requested_by,
        notes,
        warehouse_id,
        invoice_id,
        requested_at
    ) VALUES (
        v_request_number,
        'withdrawal',
        'pending',
        'صرف فاتورة: ' || p_customer_name || ' - ' || p_total_amount || ' جنيه',
        p_requested_by,
        p_notes,
        p_warehouse_id,
        p_invoice_id,
        NOW()
    ) RETURNING id INTO v_request_id;
    
    -- Add items if provided
    IF p_items IS NOT NULL AND json_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM json_array_elements(p_items)
        LOOP
            INSERT INTO public.warehouse_request_items (
                request_id,
                product_id,
                quantity,
                notes
            ) VALUES (
                v_request_id,
                (v_item->>'product_id')::TEXT,
                COALESCE((v_item->>'quantity')::INTEGER, 0),
                COALESCE(v_item->>'notes', (v_item->>'product_name')::TEXT || ' - ' || COALESCE((v_item->>'unit_price')::TEXT, '0') || ' جنيه')
            );
            
            v_item_count := v_item_count + 1;
        END LOOP;
    END IF;
    
    RETURN QUERY SELECT 
        v_request_id,
        v_request_number,
        TRUE,
        'تم إنشاء طلب الصرف بنجاح مع ' || v_item_count || ' منتج';
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            NULL::TEXT,
            FALSE,
            'خطأ في إنشاء طلب الصرف: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Create function to get dispatch statistics
CREATE OR REPLACE FUNCTION get_dispatch_statistics(
    p_warehouse_id UUID DEFAULT NULL,
    p_date_from DATE DEFAULT NULL,
    p_date_to DATE DEFAULT NULL
)
RETURNS TABLE (
    total_requests INTEGER,
    pending_requests INTEGER,
    approved_requests INTEGER,
    executed_requests INTEGER,
    rejected_requests INTEGER,
    cancelled_requests INTEGER,
    total_items INTEGER,
    from_invoices INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_requests,
        COUNT(*) FILTER (WHERE status = 'pending')::INTEGER as pending_requests,
        COUNT(*) FILTER (WHERE status = 'approved')::INTEGER as approved_requests,
        COUNT(*) FILTER (WHERE status = 'executed')::INTEGER as executed_requests,
        COUNT(*) FILTER (WHERE status = 'rejected')::INTEGER as rejected_requests,
        COUNT(*) FILTER (WHERE status = 'cancelled')::INTEGER as cancelled_requests,
        COALESCE(SUM(
            (SELECT COUNT(*) FROM public.warehouse_request_items wri WHERE wri.request_id = wr.id)
        ), 0)::INTEGER as total_items,
        COUNT(*) FILTER (WHERE invoice_id IS NOT NULL)::INTEGER as from_invoices
    FROM public.warehouse_requests wr
    WHERE (p_warehouse_id IS NULL OR warehouse_id = p_warehouse_id)
    AND (p_date_from IS NULL OR DATE(requested_at) >= p_date_from)
    AND (p_date_to IS NULL OR DATE(requested_at) <= p_date_to);
END;
$$ LANGUAGE plpgsql;

-- Step 7: Grant permissions for new functions and views
GRANT SELECT ON warehouse_dispatch_details TO authenticated;
GRANT EXECUTE ON FUNCTION get_dispatch_by_invoice_id(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION link_dispatch_to_invoice(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION create_dispatch_from_invoice(TEXT, TEXT, DECIMAL, UUID, UUID, TEXT, JSON) TO authenticated;
GRANT EXECUTE ON FUNCTION get_dispatch_statistics(UUID, DATE, DATE) TO authenticated;

-- Step 8: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_warehouse_requests_status_date 
ON public.warehouse_requests(status, requested_at);

CREATE INDEX IF NOT EXISTS idx_warehouse_requests_warehouse_status 
ON public.warehouse_requests(warehouse_id, status);

CREATE INDEX IF NOT EXISTS idx_warehouse_request_items_request_product 
ON public.warehouse_request_items(request_id, product_id);

-- Step 9: Update existing requests to extract invoice IDs from reason field
DO $$
DECLARE
    req RECORD;
    invoice_id_match TEXT;
BEGIN
    FOR req IN 
        SELECT id, reason 
        FROM public.warehouse_requests 
        WHERE invoice_id IS NULL 
        AND reason LIKE '%INV-%'
    LOOP
        -- Extract invoice ID from reason using regex
        invoice_id_match := substring(req.reason FROM 'INV-[0-9]+');
        
        IF invoice_id_match IS NOT NULL THEN
            UPDATE public.warehouse_requests 
            SET invoice_id = invoice_id_match 
            WHERE id = req.id;
        END IF;
    END LOOP;
END $$;

-- Step 10: Create trigger to automatically extract invoice ID from reason
CREATE OR REPLACE FUNCTION extract_invoice_id_from_reason()
RETURNS TRIGGER AS $$
BEGIN
    -- If invoice_id is not set but reason contains an invoice ID, extract it
    IF NEW.invoice_id IS NULL AND NEW.reason IS NOT NULL THEN
        NEW.invoice_id := substring(NEW.reason FROM 'INV-[0-9]+');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and create new one
DROP TRIGGER IF EXISTS trigger_extract_invoice_id ON public.warehouse_requests;
CREATE TRIGGER trigger_extract_invoice_id
    BEFORE INSERT OR UPDATE ON public.warehouse_requests
    FOR EACH ROW
    EXECUTE FUNCTION extract_invoice_id_from_reason();
