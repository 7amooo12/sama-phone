-- =====================================================
-- MANUAL INSERT TEST FOR CLIENT ORDERS
-- =====================================================
-- This script manually tests the exact insert that's failing
-- in the SupabaseOrdersService.createOrder method
-- =====================================================

-- =====================================================
-- 1. CHECK CURRENT USER STATUS
-- =====================================================

-- Show current user authentication
SELECT 
    'Current User ID:' as info,
    auth.uid() as user_id;

-- Show user profile
SELECT 
    'User Profile:' as info,
    id,
    name,
    email,
    role,
    status,
    created_at
FROM public.user_profiles 
WHERE id = auth.uid();

-- =====================================================
-- 2. CHECK EXISTING ORDERS
-- =====================================================

-- Count existing orders for current user
SELECT 
    'Existing Orders Count:' as info,
    COUNT(*) as order_count
FROM public.client_orders 
WHERE client_id = auth.uid();

-- =====================================================
-- 3. TEST THE EXACT INSERT FROM FLUTTER APP
-- =====================================================

-- This is the exact insert that SupabaseOrdersService.createOrder performs
-- Based on the orderData structure in the Flutter code

INSERT INTO public.client_orders (
    client_id,
    client_name,
    client_email,
    client_phone,
    total_amount,
    status,
    payment_status,
    notes,
    shipping_address,
    metadata
) VALUES (
    auth.uid(),                                    -- client_id from Flutter
    'Manual Test Customer',                        -- client_name
    'manual.test@example.com',                     -- client_email
    '+1234567890',                                 -- client_phone
    150.75,                                        -- total_amount
    'pending',                                     -- status
    'pending',                                     -- payment_status
    'Manual test order for RLS debugging',        -- notes
    '{"address": "123 Test Street, Test City"}',  -- shipping_address (JSONB)
    '{"created_from": "manual_test", "items_count": 2, "test": true}'  -- metadata (JSONB)
);

-- =====================================================
-- 4. VERIFY THE INSERT WORKED
-- =====================================================

-- Check if the order was created
SELECT 
    'Insert Verification:' as info,
    id,
    client_id,
    client_name,
    total_amount,
    status,
    order_number,
    created_at
FROM public.client_orders 
WHERE client_id = auth.uid() 
AND notes = 'Manual test order for RLS debugging'
ORDER BY created_at DESC 
LIMIT 1;

-- =====================================================
-- 5. TEST ORDER ITEMS INSERT
-- =====================================================

-- Get the order ID for testing order items
-- This simulates the second part of the Flutter createOrder method

INSERT INTO public.client_order_items (
    order_id,
    product_id,
    product_name,
    product_image,
    unit_price,
    quantity,
    subtotal,
    metadata
) 
SELECT 
    co.id,                                         -- order_id
    'TEST-PRODUCT-001',                           -- product_id
    'Test Product 1',                             -- product_name
    'https://example.com/test-image.jpg',         -- product_image
    75.00,                                        -- unit_price
    2,                                            -- quantity
    150.00,                                       -- subtotal
    '{"added_from": "manual_test"}'               -- metadata
FROM public.client_orders co
WHERE co.client_id = auth.uid() 
AND co.notes = 'Manual test order for RLS debugging'
ORDER BY co.created_at DESC 
LIMIT 1;

-- =====================================================
-- 6. VERIFY COMPLETE ORDER CREATION
-- =====================================================

-- Show the complete order with items
SELECT 
    'Complete Order Verification:' as info,
    co.id as order_id,
    co.order_number,
    co.client_name,
    co.total_amount,
    co.status,
    COUNT(coi.id) as items_count
FROM public.client_orders co
LEFT JOIN public.client_order_items coi ON co.id = coi.order_id
WHERE co.client_id = auth.uid() 
AND co.notes = 'Manual test order for RLS debugging'
GROUP BY co.id, co.order_number, co.client_name, co.total_amount, co.status;

-- =====================================================
-- 7. CLEANUP TEST DATA
-- =====================================================

-- Remove test order items first (due to foreign key constraint)
DELETE FROM public.client_order_items 
WHERE order_id IN (
    SELECT id FROM public.client_orders 
    WHERE client_id = auth.uid() 
    AND notes = 'Manual test order for RLS debugging'
);

-- Remove test order
DELETE FROM public.client_orders 
WHERE client_id = auth.uid() 
AND notes = 'Manual test order for RLS debugging';

-- =====================================================
-- 8. FINAL VERIFICATION
-- =====================================================

-- Confirm cleanup
SELECT 
    'Cleanup Verification:' as info,
    COUNT(*) as remaining_test_orders
FROM public.client_orders 
WHERE client_id = auth.uid() 
AND notes = 'Manual test order for RLS debugging';

-- Show final status
SELECT 
    'Manual Insert Test Status:' as info,
    CASE 
        WHEN auth.uid() IS NULL THEN 'FAILED: No authenticated user'
        WHEN NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid()) THEN 'FAILED: No user profile'
        ELSE 'COMPLETED: Check results above for success/failure details'
    END as status;

-- =====================================================
-- MANUAL TEST COMPLETE
-- =====================================================

SELECT 'MANUAL INSERT TEST COMPLETED' as final_status;
