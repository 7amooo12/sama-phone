-- Test script to verify the voucher discount constraint fix works
-- Run this after applying the fix_voucher_constraint.sql script

-- Test 1: Try to create a percentage voucher (should work)
DO $$
BEGIN
    -- This should succeed
    INSERT INTO public.vouchers (
        code, name, type, target_id, target_name, 
        discount_percentage, discount_type, discount_amount,
        expiration_date, created_by
    ) VALUES (
        'TEST-PERCENTAGE-001', 'Test Percentage Voucher', 'product', 'test-product-1', 'Test Product',
        20, 'percentage', NULL,
        NOW() + INTERVAL '30 days', auth.uid()
    );
    
    RAISE NOTICE 'SUCCESS: Percentage voucher created successfully';
    
    -- Clean up
    DELETE FROM public.vouchers WHERE code = 'TEST-PERCENTAGE-001';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ERROR: Failed to create percentage voucher: %', SQLERRM;
END $$;

-- Test 2: Try to create a fixed amount voucher (should work after fix)
DO $$
BEGIN
    -- This should succeed after the fix
    INSERT INTO public.vouchers (
        code, name, type, target_id, target_name, 
        discount_percentage, discount_type, discount_amount,
        expiration_date, created_by
    ) VALUES (
        'TEST-FIXED-001', 'Test Fixed Amount Voucher', 'product', 'test-product-2', 'Test Product 2',
        NULL, 'fixed_amount', 50.00,
        NOW() + INTERVAL '30 days', auth.uid()
    );
    
    RAISE NOTICE 'SUCCESS: Fixed amount voucher created successfully';
    
    -- Clean up
    DELETE FROM public.vouchers WHERE code = 'TEST-FIXED-001';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ERROR: Failed to create fixed amount voucher: %', SQLERRM;
END $$;

-- Test 3: Try to create an invalid percentage voucher (should fail)
DO $$
BEGIN
    -- This should fail (percentage > 100)
    INSERT INTO public.vouchers (
        code, name, type, target_id, target_name, 
        discount_percentage, discount_type, discount_amount,
        expiration_date, created_by
    ) VALUES (
        'TEST-INVALID-001', 'Test Invalid Voucher', 'product', 'test-product-3', 'Test Product 3',
        150, 'percentage', NULL,
        NOW() + INTERVAL '30 days', auth.uid()
    );
    
    RAISE NOTICE 'ERROR: Invalid percentage voucher was created (this should not happen)';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'SUCCESS: Invalid percentage voucher was correctly rejected: %', SQLERRM;
END $$;

-- Test 4: Try to create an invalid fixed amount voucher (should fail)
DO $$
BEGIN
    -- This should fail (no discount_amount)
    INSERT INTO public.vouchers (
        code, name, type, target_id, target_name, 
        discount_percentage, discount_type, discount_amount,
        expiration_date, created_by
    ) VALUES (
        'TEST-INVALID-002', 'Test Invalid Fixed Voucher', 'product', 'test-product-4', 'Test Product 4',
        NULL, 'fixed_amount', NULL,
        NOW() + INTERVAL '30 days', auth.uid()
    );
    
    RAISE NOTICE 'ERROR: Invalid fixed amount voucher was created (this should not happen)';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'SUCCESS: Invalid fixed amount voucher was correctly rejected: %', SQLERRM;
END $$;

-- Display current voucher table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'vouchers' 
    AND table_schema = 'public'
    AND column_name IN ('discount_percentage', 'discount_type', 'discount_amount')
ORDER BY ordinal_position;
