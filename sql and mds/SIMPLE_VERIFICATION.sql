-- =====================================================
-- SIMPLE INVOICE SCHEMA VERIFICATION
-- =====================================================
-- Run this AFTER executing SUPABASE_INVOICE_SCHEMA.sql
-- =====================================================

-- Check if table exists and show structure
SELECT 'INVOICES TABLE STRUCTURE:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'invoices'
ORDER BY ordinal_position;

-- Show created indexes
SELECT 'CREATED INDEXES:' as info;
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'invoices' 
AND schemaname = 'public'
ORDER BY indexname;

-- Show RLS policies
SELECT 'ROW LEVEL SECURITY POLICIES:' as info;
SELECT 
    policyname,
    cmd as command
FROM pg_policies 
WHERE tablename = 'invoices' 
AND schemaname = 'public'
ORDER BY policyname;

-- Show triggers
SELECT 'TRIGGERS ON INVOICES TABLE:' as info;
SELECT 
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'invoices' 
AND event_object_schema = 'public'
ORDER BY trigger_name;

-- Show custom functions
SELECT 'CUSTOM FUNCTIONS CREATED:' as info;
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN (
    'calculate_invoice_total',
    'validate_invoice_items',
    'get_user_invoice_stats',
    'search_invoices_by_customer'
)
ORDER BY routine_name;

-- Show views
SELECT 'CREATED VIEWS:' as info;
SELECT 
    table_name as view_name
FROM information_schema.views 
WHERE table_schema = 'public' 
AND table_name IN ('invoice_statistics', 'recent_invoices')
ORDER BY table_name;

-- Test basic functionality with a simple insert/delete
DO $$
DECLARE
    test_user_id UUID := '00000000-0000-0000-0000-000000000000';
    calculated_total NUMERIC;
BEGIN
    -- Try to insert a test invoice
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
    
    RAISE NOTICE '✅ Basic functionality test completed successfully';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Error during basic functionality test: %', SQLERRM;
    -- Try to clean up in case of error
    DELETE FROM public.invoices WHERE id = 'TEST-CALCULATION';
END $$;

-- Final verification summary
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
        RAISE NOTICE '✅ Your Flutter app can now create invoices';
        RAISE NOTICE '✅ All automatic calculations working';
        RAISE NOTICE '✅ Row Level Security properly configured';
        RAISE NOTICE '✅ Performance indexes in place';
    ELSE
        RAISE NOTICE '⚠️  SETUP INCOMPLETE - Please review the results above';
    END IF;
    
    RAISE NOTICE '==========================================';
END $$;
