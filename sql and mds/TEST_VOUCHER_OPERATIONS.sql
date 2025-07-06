-- =====================================================
-- VOUCHER OPERATIONS TEST SCRIPT
-- Run this after VOUCHER_RLS_POLICY_FIX.sql to verify functionality
-- =====================================================

-- STEP 1: CHECK CURRENT VOUCHER TABLE STATE
-- =====================================================

SELECT 
    '=== VOUCHER TABLE ANALYSIS ===' as info;

-- Check if tables exist and RLS is enabled
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('vouchers', 'client_vouchers')
ORDER BY tablename;

-- Check current voucher count
SELECT 
    'Current voucher count' as metric,
    COUNT(*) as count
FROM public.vouchers;

-- Check current client voucher count
SELECT 
    'Current client voucher count' as metric,
    COUNT(*) as count
FROM public.client_vouchers;

-- STEP 2: TEST VOUCHER CODE GENERATION FUNCTION
-- =====================================================

SELECT 
    '=== TESTING VOUCHER CODE GENERATION ===' as test_section;

-- Test the voucher code generation function
DO $$
DECLARE
    generated_code TEXT;
BEGIN
    SELECT public.generate_voucher_code() INTO generated_code;
    RAISE NOTICE 'Generated voucher code: %', generated_code;
    
    -- Verify code format
    IF generated_code ~ '^VOUCHER-[0-9]{8}-[A-Z0-9]{6}$' THEN
        RAISE NOTICE '✅ Voucher code format is correct';
    ELSE
        RAISE NOTICE '❌ Voucher code format is incorrect: %', generated_code;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Voucher code generation failed: %', SQLERRM;
END $$;

-- STEP 3: TEST VOUCHER CREATION (SIMULATED)
-- =====================================================

SELECT 
    '=== TESTING VOUCHER CREATION ===' as test_section;

-- Test voucher creation with sample data
DO $$
DECLARE
    test_code TEXT;
    test_voucher_id UUID := gen_random_uuid();
    current_user_id UUID;
BEGIN
    -- Get current user ID (if authenticated)
    SELECT auth.uid() INTO current_user_id;
    
    IF current_user_id IS NULL THEN
        RAISE NOTICE 'ℹ️ No authenticated user - using sample UUID for test';
        current_user_id := gen_random_uuid();
    END IF;
    
    -- Generate test voucher code
    SELECT public.generate_voucher_code() INTO test_code;
    
    -- Test voucher data (similar to what Flutter app would send)
    INSERT INTO public.vouchers (
        id,
        code,
        name,
        description,
        type,
        target_id,
        target_name,
        discount_percentage,
        expiration_date,
        is_active,
        created_by,
        metadata
    ) VALUES (
        test_voucher_id,
        test_code,
        'Test Voucher - RLS Verification',
        'This is a test voucher created to verify RLS policies',
        'product',
        'test-product-123',
        'Test Product',
        15,
        now() + interval '30 days',
        true,
        current_user_id,
        '{"test": true, "created_by_script": true}'::jsonb
    );
    
    RAISE NOTICE '✅ Test voucher created successfully with ID: %', test_voucher_id;
    RAISE NOTICE '   Code: %', test_code;
    
    -- Verify the voucher was created
    IF EXISTS (SELECT 1 FROM public.vouchers WHERE id = test_voucher_id) THEN
        RAISE NOTICE '✅ Voucher verification PASSED - voucher exists in database';
    ELSE
        RAISE NOTICE '❌ Voucher verification FAILED - voucher not found';
    END IF;
    
    -- Clean up test data
    DELETE FROM public.vouchers WHERE id = test_voucher_id;
    RAISE NOTICE 'ℹ️ Test voucher cleaned up';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Voucher creation test FAILED: %', SQLERRM;
        RAISE NOTICE '   This indicates RLS policy issues that need fixing';
END $$;

-- STEP 4: TEST CLIENT VOUCHER ASSIGNMENT
-- =====================================================

SELECT 
    '=== TESTING CLIENT VOUCHER ASSIGNMENT ===' as test_section;

DO $$
DECLARE
    test_voucher_id UUID := gen_random_uuid();
    test_client_voucher_id UUID := gen_random_uuid();
    test_code TEXT;
    current_user_id UUID;
    test_client_id UUID := gen_random_uuid();
BEGIN
    -- Get current user ID
    SELECT auth.uid() INTO current_user_id;
    
    IF current_user_id IS NULL THEN
        current_user_id := gen_random_uuid();
    END IF;
    
    -- Create a test voucher first
    SELECT public.generate_voucher_code() INTO test_code;
    
    INSERT INTO public.vouchers (
        id, code, name, type, target_id, target_name,
        discount_percentage, expiration_date, created_by
    ) VALUES (
        test_voucher_id, test_code, 'Test Assignment Voucher',
        'category', 'test-category', 'Test Category',
        20, now() + interval '30 days', current_user_id
    );
    
    -- Test client voucher assignment
    INSERT INTO public.client_vouchers (
        id,
        voucher_id,
        client_id,
        status,
        assigned_by,
        metadata
    ) VALUES (
        test_client_voucher_id,
        test_voucher_id,
        test_client_id,
        'active',
        current_user_id,
        '{"test_assignment": true}'::jsonb
    );
    
    RAISE NOTICE '✅ Client voucher assignment test PASSED';
    
    -- Clean up
    DELETE FROM public.client_vouchers WHERE id = test_client_voucher_id;
    DELETE FROM public.vouchers WHERE id = test_voucher_id;
    RAISE NOTICE 'ℹ️ Test data cleaned up';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Client voucher assignment test FAILED: %', SQLERRM;
END $$;

-- STEP 5: TEST ROLE-BASED ACCESS FUNCTION
-- =====================================================

SELECT 
    '=== TESTING ROLE-BASED ACCESS FUNCTION ===' as test_section;

-- Test the can_manage_vouchers function
SELECT 
    'can_manage_vouchers() result' as test_name,
    public.can_manage_vouchers() as result;

-- STEP 6: PERFORMANCE VERIFICATION
-- =====================================================

SELECT 
    '=== PERFORMANCE VERIFICATION ===' as test_section;

-- These operations should complete quickly without hanging
EXPLAIN (ANALYZE, BUFFERS) 
SELECT COUNT(*) FROM public.vouchers;

EXPLAIN (ANALYZE, BUFFERS) 
SELECT COUNT(*) FROM public.client_vouchers;

-- STEP 7: FINAL VERIFICATION SUMMARY
-- =====================================================

SELECT 
    '=== FINAL VERIFICATION SUMMARY ===' as summary;

-- Count policies
SELECT 
    'Total voucher policies' as metric,
    COUNT(*) as count
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'vouchers';

SELECT 
    'Total client_voucher policies' as metric,
    COUNT(*) as count
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'client_vouchers';

-- Check for any remaining problematic policies
SELECT 
    'Policies with user_profiles references' as check_name,
    COUNT(*) as count
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('vouchers', 'client_vouchers')
AND (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%');

-- Success message
SELECT 
    '🎯 VOUCHER OPERATIONS TEST COMPLETE' as status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE schemaname = 'public' 
            AND tablename IN ('vouchers', 'client_vouchers')
            AND (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%')
        ) THEN '⚠️ Some policies still reference user_profiles - may cause issues'
        ELSE '✅ All policies are safe - voucher operations should work'
    END as result;
