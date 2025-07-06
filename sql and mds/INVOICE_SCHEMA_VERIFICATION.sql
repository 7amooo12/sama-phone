-- =====================================================
-- INVOICE SCHEMA VERIFICATION AND TESTING SCRIPT
-- =====================================================
-- Run this script AFTER the main schema setup to verify
-- that everything is working correctly
-- =====================================================

-- =====================================================
-- 1. VERIFY TABLE STRUCTURE
-- =====================================================

-- Check if invoices table exists and has correct structure
SELECT 'INVOICES TABLE STRUCTURE:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'invoices'
ORDER BY ordinal_position;

-- =====================================================
-- 2. VERIFY INDEXES
-- =====================================================

SELECT 'CREATED INDEXES:' as info;
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'invoices' 
AND schemaname = 'public'
ORDER BY indexname;

-- =====================================================
-- 3. VERIFY RLS POLICIES
-- =====================================================

SELECT 'ROW LEVEL SECURITY POLICIES:' as info;
SELECT 
    policyname,
    cmd as command,
    qual as using_expression,
    with_check as with_check_expression
FROM pg_policies 
WHERE tablename = 'invoices' 
AND schemaname = 'public'
ORDER BY policyname;

-- =====================================================
-- 4. VERIFY TRIGGERS AND FUNCTIONS
-- =====================================================

SELECT 'TRIGGERS ON INVOICES TABLE:' as info;
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'invoices' 
AND event_object_schema = 'public'
ORDER BY trigger_name;

SELECT 'CUSTOM FUNCTIONS CREATED:' as info;
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN (
    'calculate_invoice_total',
    'validate_invoice_items',
    'get_user_invoice_stats',
    'search_invoices_by_customer'
)
ORDER BY routine_name;

-- =====================================================
-- 5. VERIFY VIEWS
-- =====================================================

SELECT 'CREATED VIEWS:' as info;
SELECT 
    table_name as view_name,
    view_definition
FROM information_schema.views 
WHERE table_schema = 'public' 
AND table_name IN ('invoice_statistics', 'recent_invoices')
ORDER BY table_name;

-- =====================================================
-- 6. TEST CONSTRAINTS AND VALIDATIONS
-- =====================================================

-- Test 1: Try to insert invalid status (should fail)
SELECT 'TESTING CONSTRAINTS...' as info;

-- This should fail with constraint violation
DO $$
BEGIN
    BEGIN
        INSERT INTO public.invoices (
            id, user_id, customer_name, items, subtotal, status
        ) VALUES (
            'TEST-INVALID-STATUS',
            '00000000-0000-0000-0000-000000000000',
            'Test Customer',
            '[{"product_id": "1", "product_name": "Test", "quantity": 1, "unit_price": 100, "subtotal": 100}]'::jsonb,
            100,
            'invalid_status'
        );
        RAISE NOTICE '❌ ERROR: Invalid status constraint not working!';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE '✅ Status constraint working correctly';
    END;
END $$;

-- Test 2: Try to insert negative subtotal (should fail)
DO $$
BEGIN
    BEGIN
        INSERT INTO public.invoices (
            id, user_id, customer_name, items, subtotal
        ) VALUES (
            'TEST-NEGATIVE-AMOUNT',
            '00000000-0000-0000-0000-000000000000',
            'Test Customer',
            '[{"product_id": "1", "product_name": "Test", "quantity": 1, "unit_price": 100, "subtotal": 100}]'::jsonb,
            -100
        );
        RAISE NOTICE '❌ ERROR: Negative amount constraint not working!';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE '✅ Negative amount constraint working correctly';
    END;
END $$;

-- Test 3: Try to insert empty items array (should fail)
DO $$
BEGIN
    BEGIN
        INSERT INTO public.invoices (
            id, user_id, customer_name, items, subtotal
        ) VALUES (
            'TEST-EMPTY-ITEMS',
            '00000000-0000-0000-0000-000000000000',
            'Test Customer',
            '[]'::jsonb,
            100
        );
        RAISE NOTICE '❌ ERROR: Empty items validation not working!';
    EXCEPTION WHEN others THEN
        RAISE NOTICE '✅ Empty items validation working correctly';
    END;
END $$;

-- Test 4: Try to insert invalid items structure (should fail)
DO $$
BEGIN
    BEGIN
        INSERT INTO public.invoices (
            id, user_id, customer_name, items, subtotal
        ) VALUES (
            'TEST-INVALID-ITEMS',
            '00000000-0000-0000-0000-000000000000',
            'Test Customer',
            '[{"invalid": "structure"}]'::jsonb,
            100
        );
        RAISE NOTICE '❌ ERROR: Items structure validation not working!';
    EXCEPTION WHEN others THEN
        RAISE NOTICE '✅ Items structure validation working correctly';
    END;
END $$;

-- =====================================================
-- 7. TEST AUTOMATIC CALCULATIONS
-- =====================================================

-- Test automatic total_amount calculation
DO $$
DECLARE
    test_user_id UUID := '00000000-0000-0000-0000-000000000000';
    calculated_total NUMERIC;
BEGIN
    -- Insert a test invoice
    INSERT INTO public.invoices (
        id, user_id, customer_name, items, subtotal, discount
    ) VALUES (
        'TEST-CALCULATION',
        test_user_id,
        'Test Customer',
        '[{"product_id": "1", "product_name": "Test Product", "quantity": 2, "unit_price": 50.00, "subtotal": 100.00}]'::jsonb,
        100.00,
        10.00
    );
    
    -- Check if total_amount was calculated correctly (100 - 10 = 90)
    SELECT total_amount INTO calculated_total
    FROM public.invoices
    WHERE id = 'TEST-CALCULATION';
    
    IF calculated_total = 90.00 THEN
        RAISE NOTICE '✅ Automatic total calculation working correctly: %', calculated_total;
    ELSE
        RAISE NOTICE '❌ ERROR: Automatic total calculation failed. Expected: 90.00, Got: %', calculated_total;
    END IF;
    
    -- Clean up test data
    DELETE FROM public.invoices WHERE id = 'TEST-CALCULATION';
END $$;

-- =====================================================
-- 8. VERIFY PERMISSIONS
-- =====================================================

SELECT 'TABLE PERMISSIONS:' as info;
SELECT 
    grantee,
    privilege_type,
    is_grantable
FROM information_schema.table_privileges 
WHERE table_schema = 'public' 
AND table_name = 'invoices'
ORDER BY grantee, privilege_type;

-- =====================================================
-- 9. PERFORMANCE TEST QUERIES
-- =====================================================

-- Test index usage with EXPLAIN (these won't return data but show query plans)
SELECT 'TESTING INDEX USAGE:' as info;

-- Test user_id index
EXPLAIN (ANALYZE false, BUFFERS false) 
SELECT * FROM public.invoices WHERE user_id = '00000000-0000-0000-0000-000000000000';

-- Test status index
EXPLAIN (ANALYZE false, BUFFERS false) 
SELECT * FROM public.invoices WHERE status = 'pending';

-- Test created_at index
EXPLAIN (ANALYZE false, BUFFERS false) 
SELECT * FROM public.invoices ORDER BY created_at DESC LIMIT 10;

-- Test composite index
EXPLAIN (ANALYZE false, BUFFERS false) 
SELECT * FROM public.invoices 
WHERE user_id = '00000000-0000-0000-0000-000000000000' 
AND status = 'pending' 
ORDER BY created_at DESC;

-- =====================================================
-- 10. FINAL VERIFICATION SUMMARY
-- =====================================================

DO $$
DECLARE
    table_exists BOOLEAN;
    rls_enabled BOOLEAN;
    trigger_count INTEGER;
    index_count INTEGER;
    policy_count INTEGER;
BEGIN
    -- Check if table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'invoices'
    ) INTO table_exists;
    
    -- Check if RLS is enabled
    SELECT relrowsecurity INTO rls_enabled
    FROM pg_class 
    WHERE relname = 'invoices' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
    
    -- Count triggers
    SELECT COUNT(*) INTO trigger_count
    FROM information_schema.triggers 
    WHERE event_object_table = 'invoices' AND event_object_schema = 'public';
    
    -- Count indexes
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE tablename = 'invoices' AND schemaname = 'public';
    
    -- Count RLS policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename = 'invoices' AND schemaname = 'public';
    
    -- Display summary
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'INVOICE SYSTEM VERIFICATION SUMMARY';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Table exists: %', CASE WHEN table_exists THEN '✅ YES' ELSE '❌ NO' END;
    RAISE NOTICE 'RLS enabled: %', CASE WHEN rls_enabled THEN '✅ YES' ELSE '❌ NO' END;
    RAISE NOTICE 'Triggers created: % ✅', trigger_count;
    RAISE NOTICE 'Indexes created: % ✅', index_count;
    RAISE NOTICE 'RLS policies: % ✅', policy_count;
    RAISE NOTICE '==========================================';
    
    IF table_exists AND rls_enabled AND trigger_count >= 2 AND index_count >= 8 AND policy_count >= 5 THEN
        RAISE NOTICE '🎉 INVOICE SYSTEM SETUP SUCCESSFUL!';
        RAISE NOTICE '✅ Ready for production use';
    ELSE
        RAISE NOTICE '⚠️  SETUP INCOMPLETE - Please review the results above';
    END IF;
    
    RAISE NOTICE '==========================================';
END $$;
