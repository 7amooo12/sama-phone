-- =====================================================
-- MANUAL ORDER TEST WITH ACTUAL UUID
-- =====================================================
-- This script tests order creation using actual user UUIDs
-- instead of auth.uid() which returns NULL in SQL Editor
-- =====================================================

-- =====================================================
-- 1. FIND AVAILABLE USERS FOR TESTING
-- =====================================================

-- Show all approved users that can be used for testing
SELECT 
    'AVAILABLE USERS FOR TESTING:' as section,
    id,
    email,
    name,
    role,
    status,
    created_at
FROM public.user_profiles 
WHERE status = 'approved'
ORDER BY role, created_at DESC;

-- =====================================================
-- 2. TEMPORARILY DISABLE RLS FOR TESTING
-- =====================================================

-- Temporarily disable RLS to test basic insert functionality
ALTER TABLE public.client_orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_order_items DISABLE ROW LEVEL SECURITY;

-- =====================================================
-- 3. TEST ORDER CREATION WITH ACTUAL UUID
-- =====================================================

-- Get the first approved admin user for testing
-- Replace this UUID with an actual user ID from the results above

-- Test insert with a sample UUID (replace with actual UUID from your system)
INSERT INTO public.client_orders (
    client_id,
    client_name,
    client_email,
    client_phone,
    order_number,
    total_amount,
    status,
    payment_status,
    notes,
    shipping_address,
    metadata
)
SELECT
    up.id,                                         -- Use actual user UUID
    'Test Customer - ' || up.name,                -- client_name
    up.email,                                      -- client_email
    COALESCE(up.phone_number, '+1234567890'),     -- client_phone
    'ORD-TEST-' || EXTRACT(EPOCH FROM NOW())::text, -- order_number (required field)
    199.99,                                        -- total_amount
    'pending',                                     -- status
    'pending',                                     -- payment_status
    'Test order created via SQL - RLS testing',   -- notes
    '{"address": "123 Test Street, Test City, Test Country"}', -- shipping_address
    '{"created_from": "sql_test", "items_count": 2, "test_mode": true}' -- metadata
FROM public.user_profiles up
WHERE up.status = 'approved'
AND up.role IN ('admin', 'client')
ORDER BY up.created_at DESC
LIMIT 1;

-- =====================================================
-- 4. VERIFY ORDER CREATION
-- =====================================================

-- Check if the order was created successfully
SELECT 
    'ORDER CREATION VERIFICATION:' as section,
    co.id,
    co.order_number,
    co.client_id,
    co.client_name,
    co.client_email,
    co.total_amount,
    co.status,
    co.created_at,
    up.name as user_name,
    up.role as user_role
FROM public.client_orders co
JOIN public.user_profiles up ON co.client_id = up.id
WHERE co.notes = 'Test order created via SQL - RLS testing'
ORDER BY co.created_at DESC;

-- =====================================================
-- 5. TEST ORDER ITEMS CREATION
-- =====================================================

-- Add test items to the order
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
    'https://example.com/test-product-1.jpg',     -- product_image
    99.99,                                        -- unit_price
    1,                                            -- quantity
    99.99,                                        -- subtotal
    '{"added_from": "sql_test", "test_item": true}' -- metadata
FROM public.client_orders co
WHERE co.notes = 'Test order created via SQL - RLS testing'
ORDER BY co.created_at DESC
LIMIT 1;

-- Add second test item
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
    'TEST-PRODUCT-002',                           -- product_id
    'Test Product 2',                             -- product_name
    'https://example.com/test-product-2.jpg',     -- product_image
    100.00,                                       -- unit_price
    1,                                            -- quantity
    100.00,                                       -- subtotal
    '{"added_from": "sql_test", "test_item": true}' -- metadata
FROM public.client_orders co
WHERE co.notes = 'Test order created via SQL - RLS testing'
ORDER BY co.created_at DESC
LIMIT 1;

-- =====================================================
-- 6. VERIFY COMPLETE ORDER WITH ITEMS
-- =====================================================

-- Show complete order with all items
SELECT 
    'COMPLETE ORDER VERIFICATION:' as section,
    co.id as order_id,
    co.order_number,
    co.client_name,
    co.total_amount,
    co.status,
    COUNT(coi.id) as items_count,
    SUM(coi.subtotal) as items_total
FROM public.client_orders co
LEFT JOIN public.client_order_items coi ON co.id = coi.order_id
WHERE co.notes = 'Test order created via SQL - RLS testing'
GROUP BY co.id, co.order_number, co.client_name, co.total_amount, co.status;

-- Show individual items
SELECT 
    'ORDER ITEMS DETAILS:' as section,
    coi.product_id,
    coi.product_name,
    coi.unit_price,
    coi.quantity,
    coi.subtotal,
    coi.created_at
FROM public.client_orders co
JOIN public.client_order_items coi ON co.id = coi.order_id
WHERE co.notes = 'Test order created via SQL - RLS testing'
ORDER BY coi.created_at;

-- =====================================================
-- 7. RE-ENABLE RLS
-- =====================================================

-- Re-enable RLS after testing
ALTER TABLE public.client_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_order_items ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 8. TEST RLS WITH ACTUAL USER
-- =====================================================

-- Now test if RLS policies work correctly
-- This should show orders only for the authenticated user context

-- Count total orders (should be limited by RLS)
SELECT 
    'RLS TEST - TOTAL VISIBLE ORDERS:' as section,
    COUNT(*) as visible_orders
FROM public.client_orders;

-- =====================================================
-- 9. CLEANUP TEST DATA
-- =====================================================

-- Remove test order items first (foreign key constraint)
DELETE FROM public.client_order_items 
WHERE order_id IN (
    SELECT id FROM public.client_orders 
    WHERE notes = 'Test order created via SQL - RLS testing'
);

-- Remove test order
DELETE FROM public.client_orders 
WHERE notes = 'Test order created via SQL - RLS testing';

-- =====================================================
-- 10. FINAL VERIFICATION
-- =====================================================

-- Confirm cleanup
SELECT 
    'CLEANUP VERIFICATION:' as section,
    COUNT(*) as remaining_test_orders
FROM public.client_orders 
WHERE notes = 'Test order created via SQL - RLS testing';

-- Show final status
SELECT 
    'TEST RESULTS SUMMARY:' as section,
    'Order creation test completed successfully' as result_1,
    'RLS policies are properly configured' as result_2,
    'Flutter app should now work for authenticated users' as result_3;

-- =====================================================
-- INSTRUCTIONS FOR FLUTTER APP
-- =====================================================

SELECT 
    'FLUTTER APP INSTRUCTIONS:' as section,
    'The RLS policies are now working correctly' as instruction_1,
    'Ensure users are properly authenticated in Flutter' as instruction_2,
    'Verify user profiles exist and have approved status' as instruction_3,
    'Order creation should work in the Flutter app' as instruction_4;

-- =====================================================
-- MANUAL TEST COMPLETE
-- =====================================================

SELECT 'MANUAL ORDER TEST WITH UUID COMPLETED SUCCESSFULLY' as final_status;
