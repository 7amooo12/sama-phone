-- التحقق من إصلاح مزامنة بيانات صرف المخازن
-- Verify warehouse dispatch data synchronization fix

-- ==================== STEP 1: CHECK CURRENT POLICIES ====================

SELECT 
    '🔒 Current RLS Policies for warehouse_request_items:' as section,
    policyname,
    cmd,
    permissive,
    CASE 
        WHEN qual IS NOT NULL THEN 'Has USING clause'
        ELSE 'No USING clause'
    END as using_clause,
    CASE 
        WHEN with_check IS NOT NULL THEN 'Has WITH CHECK clause'
        ELSE 'No WITH CHECK clause'
    END as with_check_clause
FROM pg_policies 
WHERE tablename = 'warehouse_request_items'
ORDER BY cmd, policyname;

-- ==================== STEP 2: CHECK USER ROLES ====================

SELECT 
    '👥 User Roles Distribution:' as section,
    role,
    status,
    COUNT(*) as user_count
FROM user_profiles 
GROUP BY role, status
ORDER BY role, status;

-- ==================== STEP 3: TEST ACCESS FOR DIFFERENT ROLES ====================

-- Test function to simulate different user roles
CREATE OR REPLACE FUNCTION test_role_access(test_role TEXT, test_status TEXT DEFAULT 'approved')
RETURNS TABLE (
    role_tested TEXT,
    status_tested TEXT,
    can_select_requests BOOLEAN,
    can_select_items BOOLEAN,
    requests_count INTEGER,
    items_count INTEGER,
    error_message TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    test_user_id UUID;
    req_count INTEGER := 0;
    itm_count INTEGER := 0;
    can_req BOOLEAN := FALSE;
    can_itm BOOLEAN := FALSE;
    err_msg TEXT := NULL;
BEGIN
    -- Get a user with the specified role
    SELECT id INTO test_user_id
    FROM user_profiles 
    WHERE role = test_role AND status = test_status
    LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RETURN QUERY SELECT test_role, test_status, FALSE, FALSE, 0, 0, 'No user found with this role/status';
        RETURN;
    END IF;
    
    -- Test warehouse_requests access
    BEGIN
        -- Simulate the RLS check
        SELECT EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_profiles.id = test_user_id
              AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'warehouse_manager', 'owner')
              AND user_profiles.status = 'approved'
        ) INTO can_req;
        
        IF can_req THEN
            SELECT COUNT(*) INTO req_count FROM warehouse_requests LIMIT 100;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            err_msg := 'Error accessing requests: ' || SQLERRM;
    END;
    
    -- Test warehouse_request_items access
    BEGIN
        -- Simulate the RLS check
        SELECT EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_profiles.id = test_user_id
              AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'warehouse_manager', 'owner')
              AND user_profiles.status = 'approved'
        ) INTO can_itm;
        
        IF can_itm THEN
            SELECT COUNT(*) INTO itm_count FROM warehouse_request_items LIMIT 100;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            err_msg := COALESCE(err_msg || ' | ', '') || 'Error accessing items: ' || SQLERRM;
    END;
    
    RETURN QUERY SELECT test_role, test_status, can_req, can_itm, req_count, itm_count, err_msg;
END;
$$;

-- Test access for different roles
SELECT '🧪 Testing Role Access:' as test_section;

SELECT * FROM test_role_access('admin');
SELECT * FROM test_role_access('accountant');
SELECT * FROM test_role_access('warehouseManager');
SELECT * FROM test_role_access('warehouse_manager');
SELECT * FROM test_role_access('owner');
SELECT * FROM test_role_access('client'); -- Should fail

-- ==================== STEP 4: TEST ACTUAL DATA RETRIEVAL ====================

-- Test the exact query pattern used by the application
DO $$
DECLARE
    test_record RECORD;
    total_requests INTEGER := 0;
    total_items INTEGER := 0;
    requests_with_items INTEGER := 0;
    requests_without_items INTEGER := 0;
BEGIN
    RAISE NOTICE '📊 Testing actual data retrieval patterns...';
    
    -- Count total requests and items
    SELECT COUNT(*) INTO total_requests FROM warehouse_requests;
    SELECT COUNT(*) INTO total_items FROM warehouse_request_items;
    
    RAISE NOTICE '📋 Total requests in database: %', total_requests;
    RAISE NOTICE '📦 Total items in database: %', total_items;
    
    -- Test the JOIN query that the application uses
    FOR test_record IN 
        SELECT 
            wr.id,
            wr.request_number,
            wr.status,
            wr.reason,
            COUNT(wri.id) as item_count
        FROM warehouse_requests wr
        LEFT JOIN warehouse_request_items wri ON wr.id = wri.request_id
        GROUP BY wr.id, wr.request_number, wr.status, wr.reason
        ORDER BY wr.requested_at DESC
        LIMIT 5
    LOOP
        IF test_record.item_count > 0 THEN
            requests_with_items := requests_with_items + 1;
        ELSE
            requests_without_items := requests_without_items + 1;
        END IF;
        
        RAISE NOTICE '📋 Request %: % items (status: %)', 
            test_record.request_number, 
            test_record.item_count,
            test_record.status;
    END LOOP;
    
    RAISE NOTICE '✅ Requests with items: %', requests_with_items;
    RAISE NOTICE '⚠️ Requests without items: %', requests_without_items;
    
    -- Test the specific query with nested SELECT that might be causing issues
    FOR test_record IN 
        SELECT 
            wr.*,
            (
                SELECT json_agg(
                    json_build_object(
                        'id', wri.id,
                        'product_id', wri.product_id,
                        'quantity', wri.quantity,
                        'notes', wri.notes
                    )
                )
                FROM warehouse_request_items wri 
                WHERE wri.request_id = wr.id
            ) as items_json
        FROM warehouse_requests wr
        ORDER BY wr.requested_at DESC
        LIMIT 3
    LOOP
        RAISE NOTICE '📋 Request % has items: %', 
            test_record.request_number, 
            CASE 
                WHEN test_record.items_json IS NOT NULL THEN 'YES'
                ELSE 'NO'
            END;
    END LOOP;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error during data retrieval test: %', SQLERRM;
END $$;

-- ==================== STEP 5: SIMULATE APPLICATION QUERY ====================

-- This simulates the exact query used by WarehouseDispatchService.getDispatchRequests()
DO $$
DECLARE
    app_query_result RECORD;
    result_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🔍 Testing application-style query...';
    
    FOR app_query_result IN 
        SELECT 
            wr.*,
            COALESCE(
                json_agg(
                    json_build_object(
                        'id', wri.id,
                        'request_id', wri.request_id,
                        'product_id', wri.product_id,
                        'quantity', wri.quantity,
                        'notes', wri.notes
                    ) ORDER BY wri.id
                ) FILTER (WHERE wri.id IS NOT NULL),
                '[]'::json
            ) as warehouse_request_items
        FROM warehouse_requests wr
        LEFT JOIN warehouse_request_items wri ON wr.id = wri.request_id
        GROUP BY wr.id
        ORDER BY wr.requested_at DESC
        LIMIT 5
    LOOP
        result_count := result_count + 1;
        
        RAISE NOTICE '📋 App Query Result %: Request % has % items', 
            result_count,
            app_query_result.request_number,
            json_array_length(app_query_result.warehouse_request_items);
    END LOOP;
    
    RAISE NOTICE '✅ Application query returned % results', result_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error during application query test: %', SQLERRM;
END $$;

-- ==================== STEP 6: CLEANUP AND SUMMARY ====================

-- Drop the test function
DROP FUNCTION IF EXISTS test_role_access(TEXT, TEXT);

-- Final summary
SELECT 
    '✅ Verification Complete' as status,
    'Check the notices above for detailed test results' as instruction,
    'If all tests pass, the data sync issue should be resolved' as conclusion,
    'Test both Accountant and Warehouse Manager dashboards to confirm' as next_step;
