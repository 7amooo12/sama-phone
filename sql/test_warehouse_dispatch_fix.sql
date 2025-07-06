-- Test script to verify warehouse dispatch infinite recursion fix
-- This script tests the exact queries that Flutter is running

SELECT '🧪 TESTING WAREHOUSE DISPATCH INFINITE RECURSION FIX...' as test_status;

-- Test 1: Check if SECURITY DEFINER functions exist
SELECT 
    '🔍 SECURITY DEFINER FUNCTIONS CHECK' as test_name,
    routine_name,
    security_type,
    'Function exists' as status
FROM information_schema.routines 
WHERE routine_name IN ('get_user_role_safe', 'get_user_status_safe', 'check_warehouse_access_safe', 'is_admin_safe', 'is_owner_safe', 'is_warehouse_manager_safe')
  AND routine_schema = 'public'
ORDER BY routine_name;

-- Test 2: Check current RLS policies on warehouse tables
SELECT 
    '🔍 CURRENT RLS POLICIES' as test_name,
    tablename,
    policyname,
    cmd as operation,
    CASE 
        WHEN qual LIKE '%_safe()%' OR with_check LIKE '%_safe()%' THEN 'USING_SAFE_FUNCTIONS'
        WHEN qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%' THEN 'POTENTIAL_RECURSION'
        ELSE 'OTHER'
    END as policy_type
FROM pg_policies 
WHERE tablename IN ('warehouse_requests', 'warehouse_request_items', 'warehouses', 'user_profiles')
  AND schemaname = 'public'
ORDER BY policy_type DESC, tablename, cmd;

-- Test 3: Test basic warehouse_requests query (without JOIN)
DO $$
DECLARE
    test_count integer;
    error_message TEXT;
BEGIN
    BEGIN
        SELECT COUNT(*) INTO test_count FROM warehouse_requests;
        RAISE NOTICE '✅ TEST 3 PASSED: warehouse_requests basic query returned % rows', test_count;
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            RAISE NOTICE '❌ TEST 3 FAILED: warehouse_requests basic query error: %', error_message;
    END;
END $$;

-- Test 4: Test basic warehouse_request_items query (without JOIN)
DO $$
DECLARE
    test_count integer;
    error_message TEXT;
BEGIN
    BEGIN
        SELECT COUNT(*) INTO test_count FROM warehouse_request_items;
        RAISE NOTICE '✅ TEST 4 PASSED: warehouse_request_items basic query returned % rows', test_count;
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            RAISE NOTICE '❌ TEST 4 FAILED: warehouse_request_items basic query error: %', error_message;
    END;
END $$;

-- Test 5: Test the exact Flutter query with JOIN (this was failing before)
DO $$
DECLARE
    test_count integer;
    error_message TEXT;
BEGIN
    BEGIN
        SELECT COUNT(*) INTO test_count 
        FROM warehouse_requests wr
        LEFT JOIN warehouse_request_items wri ON wr.id = wri.request_id;
        RAISE NOTICE '✅ TEST 5 PASSED: Flutter JOIN query returned % rows without infinite recursion', test_count;
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            RAISE NOTICE '❌ TEST 5 FAILED: Flutter JOIN query error: %', error_message;
            
            -- Additional debugging if it's still infinite recursion
            IF error_message LIKE '%infinite recursion%' THEN
                RAISE NOTICE '🔍 INFINITE RECURSION STILL DETECTED - Need further investigation';
            END IF;
    END;
END $$;

-- Test 6: Test the exact Flutter SELECT query with nested items
DO $$
DECLARE
    test_result RECORD;
    error_message TEXT;
    test_count integer := 0;
BEGIN
    BEGIN
        -- This is the exact query from WarehouseDispatchService.getDispatchRequests()
        FOR test_result IN 
            SELECT wr.*, 
                   (SELECT json_agg(wri.*) FROM warehouse_request_items wri WHERE wri.request_id = wr.id) as warehouse_request_items
            FROM warehouse_requests wr
            ORDER BY wr.requested_at DESC
            LIMIT 5
        LOOP
            test_count := test_count + 1;
        END LOOP;
        
        RAISE NOTICE '✅ TEST 6 PASSED: Flutter nested SELECT query returned % rows without infinite recursion', test_count;
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            RAISE NOTICE '❌ TEST 6 FAILED: Flutter nested SELECT query error: %', error_message;
    END;
END $$;

-- Test 7: Test SECURITY DEFINER functions directly
DO $$
DECLARE
    test_role TEXT;
    test_status TEXT;
    test_approved BOOLEAN;
    test_access BOOLEAN;
    error_message TEXT;
BEGIN
    BEGIN
        test_role := get_user_role_safe();
        test_status := get_user_status_safe();
        test_approved := check_user_approved_safe();
        test_access := check_warehouse_access_safe();
        
        RAISE NOTICE '✅ TEST 7 PASSED: SECURITY DEFINER functions work correctly';
        RAISE NOTICE '   User Role: %', COALESCE(test_role, 'NULL');
        RAISE NOTICE '   User Status: %', COALESCE(test_status, 'NULL');
        RAISE NOTICE '   User Approved: %', test_approved;
        RAISE NOTICE '   Warehouse Access: %', test_access;
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            RAISE NOTICE '❌ TEST 7 FAILED: SECURITY DEFINER functions error: %', error_message;
    END;
END $$;

SELECT '🎯 WAREHOUSE DISPATCH INFINITE RECURSION FIX TESTING COMPLETED!' as final_test_status;
