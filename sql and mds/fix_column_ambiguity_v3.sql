-- =====================================================
-- FIX COLUMN AMBIGUITY ERROR IN INVENTORY DEDUCTION
-- =====================================================
-- This script creates a new version of the deduct_inventory_with_validation function
-- that fixes the "column reference minimum_stock is ambiguous" error

-- Drop the old function if it exists
DROP FUNCTION IF EXISTS public.deduct_inventory_with_validation_v3(TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT);

-- Create the new function with proper column qualification
CREATE OR REPLACE FUNCTION public.deduct_inventory_with_validation_v3(
    p_warehouse_id TEXT,      -- warehouse_id as TEXT (will be cast to UUID)
    p_product_id TEXT,        -- product_id as TEXT (stays as TEXT)
    p_quantity INTEGER,       -- quantity as INTEGER
    p_performed_by TEXT,      -- performed_by as TEXT (will be cast to UUID)
    p_reason TEXT,            -- reason as TEXT
    p_reference_id TEXT,      -- reference_id as TEXT (optional)
    p_reference_type TEXT     -- reference_type as TEXT (optional)
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
    reference_uuid UUID;
BEGIN
    -- Input validation and logging
    RAISE NOTICE '🔄 بدء خصم المخزون - المخزن: %, المنتج: %, الكمية: %', p_warehouse_id, p_product_id, p_quantity;
    
    -- Validate and convert warehouse_id to UUID
    BEGIN
        warehouse_uuid := p_warehouse_id::UUID;
        RAISE NOTICE '✅ تم تحويل معرف المخزن إلى UUID: %', warehouse_uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE NOTICE '❌ معرف المخزن غير صحيح: %', p_warehouse_id;
            RETURN jsonb_build_object(
                'success', false,
                'error', 'معرف المخزن غير صحيح: ' || p_warehouse_id,
                'error_detail', 'INVALID_WAREHOUSE_ID'
            );
    END;
    
    -- Validate and convert performed_by to UUID
    BEGIN
        performed_by_uuid := p_performed_by::UUID;
        RAISE NOTICE '✅ تم تحويل معرف المنفذ إلى UUID: %', performed_by_uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE NOTICE '❌ معرف المنفذ غير صحيح: %', p_performed_by;
            RETURN jsonb_build_object(
                'success', false,
                'error', 'معرف المنفذ غير صحيح: ' || p_performed_by,
                'error_detail', 'INVALID_PERFORMED_BY_ID'
            );
    END;
    
    -- Convert reference_id to UUID if provided
    IF p_reference_id IS NOT NULL AND p_reference_id != '' THEN
        BEGIN
            reference_uuid := p_reference_id::UUID;
            RAISE NOTICE '✅ تم تحويل معرف المرجع إلى UUID: %', reference_uuid;
        EXCEPTION
            WHEN invalid_text_representation THEN
                -- If reference_id is not a valid UUID, keep it as text
                reference_uuid := NULL;
                RAISE NOTICE '⚠️ معرف المرجع ليس UUID صحيح، سيتم استخدامه كنص: %', p_reference_id;
        END;
    END IF;
    
    -- Validate quantity
    IF p_quantity <= 0 THEN
        RAISE NOTICE '❌ الكمية يجب أن تكون أكبر من صفر: %', p_quantity;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'الكمية يجب أن تكون أكبر من صفر: ' || p_quantity,
            'error_detail', 'INVALID_QUANTITY'
        );
    END IF;
    
    -- Check if warehouse exists and is active
    IF NOT EXISTS (
        SELECT 1 FROM warehouses w
        WHERE w.id = warehouse_uuid AND w.is_active = true
    ) THEN
        RAISE NOTICE '❌ المخزن غير موجود أو غير نشط: %', warehouse_uuid;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المخزن غير موجود أو غير نشط: ' || warehouse_uuid,
            'error_detail', 'WAREHOUSE_NOT_FOUND'
        );
    END IF;
    
    -- Get current inventory quantity and minimum stock with explicit table qualification
    SELECT 
        COALESCE(wi.quantity, 0),
        COALESCE(wi.minimum_stock, 0)
    INTO current_quantity, minimum_stock
    FROM warehouse_inventory wi
    WHERE wi.warehouse_id = warehouse_uuid AND wi.product_id = p_product_id;
    
    -- If product doesn't exist in warehouse, create it with 0 quantity
    IF current_quantity IS NULL THEN
        INSERT INTO warehouse_inventory (
            warehouse_id, 
            product_id, 
            quantity, 
            minimum_stock,
            last_updated,
            updated_by
        ) VALUES (
            warehouse_uuid,
            p_product_id,
            0,
            0,
            NOW(),
            performed_by_uuid
        );
        current_quantity := 0;
        minimum_stock := 0;
        RAISE NOTICE '📦 تم إنشاء سجل مخزون جديد للمنتج: %', p_product_id;
    END IF;
    
    RAISE NOTICE '📊 الكمية الحالية: %, الكمية المطلوبة: %, الحد الأدنى: %', current_quantity, p_quantity, minimum_stock;
    
    -- Check if sufficient quantity is available
    IF current_quantity < p_quantity THEN
        RAISE NOTICE '❌ كمية غير كافية - متاح: %, مطلوب: %', current_quantity, p_quantity;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'كمية غير كافية في المخزون',
            'error_detail', 'INSUFFICIENT_QUANTITY',
            'available_quantity', current_quantity,
            'requested_quantity', p_quantity,
            'shortage', p_quantity - current_quantity
        );
    END IF;
    
    -- Calculate new quantity
    new_quantity := current_quantity - p_quantity;
    
    -- Generate transaction ID and number
    transaction_id := gen_random_uuid();
    transaction_number := 'TXN-' || EXTRACT(EPOCH FROM NOW())::BIGINT || '-' || SUBSTRING(transaction_id::TEXT, 1, 8);
    
    -- Update inventory quantity
    UPDATE warehouse_inventory 
    SET 
        quantity = new_quantity,
        last_updated = NOW(),
        updated_by = performed_by_uuid
    WHERE warehouse_id = warehouse_uuid AND product_id = p_product_id;
    
    RAISE NOTICE '✅ تم تحديث المخزون - الكمية الجديدة: %', new_quantity;
    
    -- Log the transaction (removed transaction_type column as it doesn't exist)
    INSERT INTO warehouse_transactions (
        id,
        transaction_number,
        warehouse_id,
        product_id,
        quantity,
        quantity_before,
        quantity_after,
        performed_by,
        reason,
        reference_id,
        reference_type,
        created_at
    ) VALUES (
        transaction_id,
        transaction_number,
        warehouse_uuid,
        p_product_id,
        p_quantity,
        current_quantity,
        new_quantity,
        performed_by_uuid,
        p_reason,
        COALESCE(p_reference_id, transaction_id::TEXT),
        COALESCE(p_reference_type, 'manual'),
        NOW()
    );
    
    RAISE NOTICE '✅ تم تسجيل المعاملة: %', transaction_number;
    
    -- Return success response
    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', transaction_id,
        'transaction_number', transaction_number,
        'quantity_before', current_quantity,
        'quantity_after', new_quantity,
        'remaining_quantity', new_quantity,
        'deducted_quantity', p_quantity,
        'minimum_stock_warning', new_quantity <= minimum_stock,
        'warehouse_id', warehouse_uuid,
        'product_id', p_product_id
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ خطأ غير متوقع: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في خصم المخزون: ' || SQLERRM,
            'error_detail', SQLSTATE
        );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.deduct_inventory_with_validation_v3(TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.deduct_inventory_with_validation_v3(TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) TO service_role;

-- Test the function with the exact parameters from the failing logs
SELECT 'Testing function with problematic parameters...' as test_step;

SELECT deduct_inventory_with_validation_v3(
    '338d5af4-88ad-49cb-aec6-456ac6bd318c',  -- warehouse ID (test)
    '190',                                    -- product ID (توزيع ذكي)
    1,                                        -- small quantity for testing
    '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',  -- performed by
    'Test column ambiguity fix',              -- reason
    '07ba6659-4a68-4019-8e35-5f9609ec0d98',  -- reference ID
    'dispatch_release_order'                  -- reference type
) as test_result;

SELECT 'Column ambiguity fix function created successfully!' as status;
