-- =====================================================
-- Test Function Fixes for Pricing Approval System
-- Created: 2024-12-22
-- Purpose: Verify all functions work correctly after conflict resolution
-- =====================================================

-- Test 1: Verify all functions exist with correct signatures
DO $$
DECLARE
    function_count INTEGER;
BEGIN
    RAISE NOTICE 'Testing Function Existence and Signatures...';
    
    -- Check approve_order_pricing function
    SELECT COUNT(*) INTO function_count
    FROM information_schema.routines 
    WHERE routine_name = 'approve_order_pricing' 
    AND routine_type = 'FUNCTION';
    
    IF function_count > 0 THEN
        RAISE NOTICE '✅ approve_order_pricing function: EXISTS';
    ELSE
        RAISE NOTICE '❌ approve_order_pricing function: MISSING';
    END IF;
    
    -- Check get_orders_pending_pricing function
    SELECT COUNT(*) INTO function_count
    FROM information_schema.routines 
    WHERE routine_name = 'get_orders_pending_pricing' 
    AND routine_type = 'FUNCTION';
    
    IF function_count > 0 THEN
        RAISE NOTICE '✅ get_orders_pending_pricing function: EXISTS';
    ELSE
        RAISE NOTICE '❌ get_orders_pending_pricing function: MISSING';
    END IF;
    
    -- Check get_order_items_for_pricing function
    SELECT COUNT(*) INTO function_count
    FROM information_schema.routines 
    WHERE routine_name = 'get_order_items_for_pricing' 
    AND routine_type = 'FUNCTION';
    
    IF function_count > 0 THEN
        RAISE NOTICE '✅ get_order_items_for_pricing function: EXISTS';
    ELSE
        RAISE NOTICE '❌ get_order_items_for_pricing function: MISSING';
    END IF;
END $$;

-- Test 2: Test get_orders_pending_pricing function
DO $$
DECLARE
    test_order_id UUID;
    pending_orders_count INTEGER;
    test_result RECORD;
BEGIN
    RAISE NOTICE 'Testing get_orders_pending_pricing function...';
    
    BEGIN
        -- Create a test order with pending pricing
        INSERT INTO public.client_orders (
            client_id, client_name, client_email, client_phone,
            order_number, total_amount, status, pricing_status
        ) VALUES (
            gen_random_uuid(), 'Test Customer', 'test@example.com', '1234567890',
            'TEST-PENDING-' || extract(epoch from now())::text, 100.00, 'pending', 'pending_pricing'
        ) RETURNING id INTO test_order_id;
        
        -- Add a test item
        INSERT INTO public.client_order_items (
            order_id, product_id, product_name, unit_price, quantity, subtotal
        ) VALUES (
            test_order_id, 'TEST-PRODUCT-1', 'Test Product', 50.00, 2, 100.00
        );
        
        -- Test the function
        SELECT COUNT(*) INTO pending_orders_count 
        FROM get_orders_pending_pricing() 
        WHERE order_id = test_order_id;
        
        IF pending_orders_count > 0 THEN
            RAISE NOTICE '✅ get_orders_pending_pricing: PASS (found test order)';
            
            -- Test return structure
            SELECT * INTO test_result 
            FROM get_orders_pending_pricing() 
            WHERE order_id = test_order_id 
            LIMIT 1;
            
            IF test_result.client_name = 'Test Customer' AND test_result.total_amount = 100.00 THEN
                RAISE NOTICE '✅ get_orders_pending_pricing return structure: PASS';
            ELSE
                RAISE NOTICE '❌ get_orders_pending_pricing return structure: FAIL';
            END IF;
        ELSE
            RAISE NOTICE '❌ get_orders_pending_pricing: FAIL (test order not found)';
        END IF;
        
        -- Clean up
        DELETE FROM public.client_order_items WHERE order_id = test_order_id;
        DELETE FROM public.client_orders WHERE id = test_order_id;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ get_orders_pending_pricing: FAIL (Error: %)', SQLERRM;
        -- Clean up on error
        DELETE FROM public.client_order_items WHERE order_id = test_order_id;
        DELETE FROM public.client_orders WHERE id = test_order_id;
    END;
END $$;

-- Test 3: Test get_order_items_for_pricing function
DO $$
DECLARE
    test_order_id UUID;
    items_count INTEGER;
    test_item RECORD;
BEGIN
    RAISE NOTICE 'Testing get_order_items_for_pricing function...';
    
    BEGIN
        -- Create a test order
        INSERT INTO public.client_orders (
            client_id, client_name, client_email, client_phone,
            order_number, total_amount, status, pricing_status
        ) VALUES (
            gen_random_uuid(), 'Test Customer 2', 'test2@example.com', '1234567890',
            'TEST-ITEMS-' || extract(epoch from now())::text, 150.00, 'pending', 'pending_pricing'
        ) RETURNING id INTO test_order_id;
        
        -- Add test items
        INSERT INTO public.client_order_items (
            order_id, product_id, product_name, product_image, unit_price, quantity, subtotal
        ) VALUES 
            (test_order_id, 'TEST-PRODUCT-1', 'Test Product 1', 'test1.jpg', 50.00, 1, 50.00),
            (test_order_id, 'TEST-PRODUCT-2', 'Test Product 2', 'test2.jpg', 100.00, 1, 100.00);
        
        -- Test the function
        SELECT COUNT(*) INTO items_count 
        FROM get_order_items_for_pricing(test_order_id);
        
        IF items_count = 2 THEN
            RAISE NOTICE '✅ get_order_items_for_pricing count: PASS (found % items)', items_count;
            
            -- Test return structure
            SELECT * INTO test_item 
            FROM get_order_items_for_pricing(test_order_id) 
            WHERE product_id = 'TEST-PRODUCT-1' 
            LIMIT 1;
            
            IF test_item.product_name = 'Test Product 1' AND test_item.unit_price = 50.00 THEN
                RAISE NOTICE '✅ get_order_items_for_pricing return structure: PASS';
            ELSE
                RAISE NOTICE '❌ get_order_items_for_pricing return structure: FAIL';
            END IF;
        ELSE
            RAISE NOTICE '❌ get_order_items_for_pricing count: FAIL (expected 2, got %)', items_count;
        END IF;
        
        -- Clean up
        DELETE FROM public.client_order_items WHERE order_id = test_order_id;
        DELETE FROM public.client_orders WHERE id = test_order_id;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ get_order_items_for_pricing: FAIL (Error: %)', SQLERRM;
        -- Clean up on error
        DELETE FROM public.client_order_items WHERE order_id = test_order_id;
        DELETE FROM public.client_orders WHERE id = test_order_id;
    END;
END $$;

-- Test 4: Test approve_order_pricing function
DO $$
DECLARE
    test_order_id UUID;
    test_user_id UUID := gen_random_uuid();
    approval_result BOOLEAN;
    updated_order RECORD;
    pricing_history_count INTEGER;
BEGIN
    RAISE NOTICE 'Testing approve_order_pricing function...';
    
    BEGIN
        -- Create a test order
        INSERT INTO public.client_orders (
            client_id, client_name, client_email, client_phone,
            order_number, total_amount, status, pricing_status
        ) VALUES (
            gen_random_uuid(), 'Test Customer 3', 'test3@example.com', '1234567890',
            'TEST-APPROVAL-' || extract(epoch from now())::text, 150.00, 'pending', 'pending_pricing'
        ) RETURNING id INTO test_order_id;
        
        -- Add test items
        INSERT INTO public.client_order_items (
            order_id, product_id, product_name, unit_price, quantity, subtotal
        ) VALUES 
            (test_order_id, 'TEST-PRODUCT-1', 'Test Product 1', 50.00, 1, 50.00),
            (test_order_id, 'TEST-PRODUCT-2', 'Test Product 2', 100.00, 1, 100.00);
        
        -- Test the approval function
        SELECT approve_order_pricing(
            test_order_id,
            test_user_id,
            'Test Accountant',
            '[{"item_id": "TEST-PRODUCT-1", "approved_price": 60.00}, {"item_id": "TEST-PRODUCT-2", "approved_price": 120.00}]'::jsonb,
            'Test pricing approval'
        ) INTO approval_result;
        
        IF approval_result THEN
            RAISE NOTICE '✅ approve_order_pricing execution: PASS';
            
            -- Verify order was updated
            SELECT * INTO updated_order 
            FROM public.client_orders 
            WHERE id = test_order_id;
            
            IF updated_order.pricing_status = 'pricing_approved' 
               AND updated_order.status = 'confirmed' 
               AND updated_order.total_amount = 180.00 THEN
                RAISE NOTICE '✅ approve_order_pricing order update: PASS';
            ELSE
                RAISE NOTICE '❌ approve_order_pricing order update: FAIL (status: %, total: %)', 
                    updated_order.pricing_status, updated_order.total_amount;
            END IF;
            
            -- Verify pricing history was created
            SELECT COUNT(*) INTO pricing_history_count 
            FROM public.order_pricing_history 
            WHERE order_id = test_order_id;
            
            IF pricing_history_count = 2 THEN
                RAISE NOTICE '✅ approve_order_pricing history creation: PASS';
            ELSE
                RAISE NOTICE '❌ approve_order_pricing history creation: FAIL (expected 2, got %)', pricing_history_count;
            END IF;
            
        ELSE
            RAISE NOTICE '❌ approve_order_pricing execution: FAIL (returned false)';
        END IF;
        
        -- Clean up
        DELETE FROM public.order_pricing_history WHERE order_id = test_order_id;
        DELETE FROM public.order_history WHERE order_id = test_order_id;
        DELETE FROM public.client_order_items WHERE order_id = test_order_id;
        DELETE FROM public.client_orders WHERE id = test_order_id;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ approve_order_pricing: FAIL (Error: %)', SQLERRM;
        -- Clean up on error
        DELETE FROM public.order_pricing_history WHERE order_id = test_order_id;
        DELETE FROM public.order_history WHERE order_id = test_order_id;
        DELETE FROM public.client_order_items WHERE order_id = test_order_id;
        DELETE FROM public.client_orders WHERE id = test_order_id;
    END;
END $$;

RAISE NOTICE '=================================================';
RAISE NOTICE 'Function Fix Tests Completed!';
RAISE NOTICE 'All functions should now work without conflicts.';
RAISE NOTICE 'If any tests show FAIL, please check the error messages.';
RAISE NOTICE '=================================================';
