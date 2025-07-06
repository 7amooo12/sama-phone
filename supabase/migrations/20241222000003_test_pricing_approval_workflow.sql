-- =====================================================
-- Test Pricing Approval Workflow
-- Created: 2024-12-22
-- Purpose: Test the complete pricing approval system workflow
-- =====================================================

-- Test 1: Verify all required tables and columns exist
DO $$
DECLARE
    test_result TEXT := 'PASS';
    missing_items TEXT := '';
BEGIN
    RAISE NOTICE 'Starting Pricing Approval System Tests...';
    
    -- Test client_orders table columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'client_orders' AND column_name = 'pricing_status') THEN
        test_result := 'FAIL';
        missing_items := missing_items || 'client_orders.pricing_status, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'client_orders' AND column_name = 'pricing_approved_by') THEN
        test_result := 'FAIL';
        missing_items := missing_items || 'client_orders.pricing_approved_by, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'client_orders' AND column_name = 'pricing_approved_at') THEN
        test_result := 'FAIL';
        missing_items := missing_items || 'client_orders.pricing_approved_at, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'client_orders' AND column_name = 'pricing_notes') THEN
        test_result := 'FAIL';
        missing_items := missing_items || 'client_orders.pricing_notes, ';
    END IF;
    
    -- Test client_order_items table columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'client_order_items' AND column_name = 'pricing_approved') THEN
        test_result := 'FAIL';
        missing_items := missing_items || 'client_order_items.pricing_approved, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'client_order_items' AND column_name = 'approved_unit_price') THEN
        test_result := 'FAIL';
        missing_items := missing_items || 'client_order_items.approved_unit_price, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'client_order_items' AND column_name = 'approved_subtotal') THEN
        test_result := 'FAIL';
        missing_items := missing_items || 'client_order_items.approved_subtotal, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'client_order_items' AND column_name = 'original_unit_price') THEN
        test_result := 'FAIL';
        missing_items := missing_items || 'client_order_items.original_unit_price, ';
    END IF;
    
    -- Test order_pricing_history table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_pricing_history') THEN
        test_result := 'FAIL';
        missing_items := missing_items || 'order_pricing_history table, ';
    END IF;
    
    -- Test functions
    IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'approve_order_pricing') THEN
        test_result := 'FAIL';
        missing_items := missing_items || 'approve_order_pricing function, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'get_orders_pending_pricing') THEN
        test_result := 'FAIL';
        missing_items := missing_items || 'get_orders_pending_pricing function, ';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'get_order_items_for_pricing') THEN
        test_result := 'FAIL';
        missing_items := missing_items || 'get_order_items_for_pricing function, ';
    END IF;
    
    RAISE NOTICE 'Test 1 - Schema Verification: % %', test_result, 
        CASE WHEN test_result = 'FAIL' THEN '(Missing: ' || missing_items || ')' ELSE '' END;
END $$;

-- Test 2: Test creating a test order with pricing_status
DO $$
DECLARE
    test_order_id UUID;
    test_item_id UUID;
    test_result TEXT := 'PASS';
BEGIN
    BEGIN
        -- Create a test order
        INSERT INTO public.client_orders (
            client_id, client_name, client_email, client_phone,
            order_number, total_amount, status, pricing_status
        ) VALUES (
            gen_random_uuid(), 'Test Customer', 'test@example.com', '1234567890',
            'TEST-' || extract(epoch from now())::text, 100.00, 'pending', 'pending_pricing'
        ) RETURNING id INTO test_order_id;
        
        -- Create a test order item
        INSERT INTO public.client_order_items (
            order_id, product_id, product_name, unit_price, quantity, subtotal
        ) VALUES (
            test_order_id, 'TEST-PRODUCT-1', 'Test Product', 50.00, 2, 100.00
        ) RETURNING id INTO test_item_id;
        
        RAISE NOTICE 'Test 2 - Order Creation: PASS (Order ID: %)', test_order_id;
        
        -- Clean up test data
        DELETE FROM public.client_order_items WHERE order_id = test_order_id;
        DELETE FROM public.client_orders WHERE id = test_order_id;
        
    EXCEPTION WHEN OTHERS THEN
        test_result := 'FAIL';
        RAISE NOTICE 'Test 2 - Order Creation: FAIL (Error: %)', SQLERRM;
    END;
END $$;

-- Test 3: Test the approve_order_pricing function
DO $$
DECLARE
    test_order_id UUID;
    test_user_id UUID := gen_random_uuid();
    test_result TEXT := 'PASS';
    approval_result BOOLEAN;
BEGIN
    BEGIN
        -- Create a test order
        INSERT INTO public.client_orders (
            client_id, client_name, client_email, client_phone,
            order_number, total_amount, status, pricing_status
        ) VALUES (
            gen_random_uuid(), 'Test Customer 2', 'test2@example.com', '1234567890',
            'TEST-' || extract(epoch from now())::text, 100.00, 'pending', 'pending_pricing'
        ) RETURNING id INTO test_order_id;
        
        -- Create test order items
        INSERT INTO public.client_order_items (
            order_id, product_id, product_name, unit_price, quantity, subtotal
        ) VALUES 
            (test_order_id, 'TEST-PRODUCT-1', 'Test Product 1', 50.00, 1, 50.00),
            (test_order_id, 'TEST-PRODUCT-2', 'Test Product 2', 30.00, 1, 30.00);
        
        -- Test the approval function
        SELECT approve_order_pricing(
            test_order_id,
            test_user_id,
            'Test Accountant',
            '[{"item_id": "TEST-PRODUCT-1", "approved_price": 55.00}, {"item_id": "TEST-PRODUCT-2", "approved_price": 35.00}]'::jsonb,
            'Test pricing approval'
        ) INTO approval_result;
        
        IF approval_result THEN
            RAISE NOTICE 'Test 3 - Pricing Approval Function: PASS';
        ELSE
            RAISE NOTICE 'Test 3 - Pricing Approval Function: FAIL (Function returned false)';
        END IF;
        
        -- Verify the results
        IF EXISTS (
            SELECT 1 FROM public.client_orders 
            WHERE id = test_order_id 
            AND pricing_status = 'pricing_approved' 
            AND status = 'confirmed'
            AND total_amount = 90.00
        ) THEN
            RAISE NOTICE 'Test 3a - Order Status Update: PASS';
        ELSE
            RAISE NOTICE 'Test 3a - Order Status Update: FAIL';
        END IF;
        
        IF EXISTS (
            SELECT 1 FROM public.client_order_items 
            WHERE order_id = test_order_id 
            AND pricing_approved = TRUE
        ) THEN
            RAISE NOTICE 'Test 3b - Item Pricing Update: PASS';
        ELSE
            RAISE NOTICE 'Test 3b - Item Pricing Update: FAIL';
        END IF;
        
        IF EXISTS (
            SELECT 1 FROM public.order_pricing_history 
            WHERE order_id = test_order_id
        ) THEN
            RAISE NOTICE 'Test 3c - Pricing History: PASS';
        ELSE
            RAISE NOTICE 'Test 3c - Pricing History: FAIL';
        END IF;
        
        -- Clean up test data
        DELETE FROM public.order_pricing_history WHERE order_id = test_order_id;
        DELETE FROM public.order_history WHERE order_id = test_order_id;
        DELETE FROM public.client_order_items WHERE order_id = test_order_id;
        DELETE FROM public.client_orders WHERE id = test_order_id;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Test 3 - Pricing Approval Function: FAIL (Error: %)', SQLERRM;
        -- Clean up on error
        DELETE FROM public.order_pricing_history WHERE order_id = test_order_id;
        DELETE FROM public.order_history WHERE order_id = test_order_id;
        DELETE FROM public.client_order_items WHERE order_id = test_order_id;
        DELETE FROM public.client_orders WHERE id = test_order_id;
    END;
END $$;

-- Test 4: Test the get_orders_pending_pricing function
DO $$
DECLARE
    test_order_id UUID;
    pending_count INTEGER;
BEGIN
    BEGIN
        -- Create a test pending order
        INSERT INTO public.client_orders (
            client_id, client_name, client_email, client_phone,
            order_number, total_amount, status, pricing_status
        ) VALUES (
            gen_random_uuid(), 'Test Customer 3', 'test3@example.com', '1234567890',
            'TEST-' || extract(epoch from now())::text, 100.00, 'pending', 'pending_pricing'
        ) RETURNING id INTO test_order_id;
        
        -- Test the function
        SELECT COUNT(*) INTO pending_count 
        FROM get_orders_pending_pricing() 
        WHERE order_id = test_order_id;
        
        IF pending_count > 0 THEN
            RAISE NOTICE 'Test 4 - Get Pending Orders Function: PASS';
        ELSE
            RAISE NOTICE 'Test 4 - Get Pending Orders Function: FAIL';
        END IF;
        
        -- Clean up
        DELETE FROM public.client_orders WHERE id = test_order_id;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Test 4 - Get Pending Orders Function: FAIL (Error: %)', SQLERRM;
        DELETE FROM public.client_orders WHERE id = test_order_id;
    END;
END $$;

RAISE NOTICE 'Pricing Approval System Tests Completed!';
RAISE NOTICE '=================================================';
RAISE NOTICE 'If all tests show PASS, the system is ready for use.';
RAISE NOTICE 'If any tests show FAIL, please check the error messages and fix the issues.';
RAISE NOTICE '=================================================';
