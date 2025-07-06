-- تشخيص مشكلة مزامنة بيانات صرف المخازن
-- Diagnose warehouse dispatch data synchronization issue

-- ==================== STEP 1: IDENTIFY THE PROBLEM ====================

-- Check if RLS is enabled on both tables
SELECT 
    'RLS Status Check:' as info,
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename IN ('warehouse_requests', 'warehouse_request_items')
ORDER BY tablename;

-- Check current policies on both tables
SELECT 
    '📋 Current Policies:' as section,
    schemaname,
    tablename,
    policyname,
    cmd,
    permissive,
    SUBSTRING(qual, 1, 100) as policy_condition_preview
FROM pg_policies 
WHERE tablename IN ('warehouse_requests', 'warehouse_request_items')
ORDER BY tablename, cmd, policyname;

-- ==================== STEP 2: CHECK USER ROLES AND AUTHENTICATION ====================

-- Check current user and their role
DO $$
DECLARE
    current_user_id UUID;
    user_role TEXT;
    user_status TEXT;
    user_email TEXT;
BEGIN
    SELECT auth.uid() INTO current_user_id;
    
    IF current_user_id IS NOT NULL THEN
        SELECT role, status, email INTO user_role, user_status, user_email
        FROM user_profiles 
        WHERE id = current_user_id;
        
        RAISE NOTICE '👤 Current User: %', current_user_id;
        RAISE NOTICE '📧 Email: %', user_email;
        RAISE NOTICE '🎭 Role: %', user_role;
        RAISE NOTICE '✅ Status: %', user_status;
        
        -- Check if user meets policy requirements
        IF user_role IN ('admin', 'accountant', 'warehouseManager', 'warehouse_manager', 'owner') AND user_status = 'approved' THEN
            RAISE NOTICE '✅ User should have access to warehouse dispatch data';
        ELSE
            RAISE NOTICE '❌ User does NOT meet policy requirements';
        END IF;
    ELSE
        RAISE NOTICE '❌ No authenticated user found';
    END IF;
END $$;

-- ==================== STEP 3: TEST DIRECT TABLE ACCESS ====================

-- Test direct access to warehouse_requests
DO $$
DECLARE
    request_count INTEGER;
    sample_request RECORD;
BEGIN
    BEGIN
        SELECT COUNT(*) INTO request_count FROM warehouse_requests;
        RAISE NOTICE '📋 Can access warehouse_requests: % records found', request_count;
        
        -- Get a sample request
        SELECT id, request_number, status, reason INTO sample_request
        FROM warehouse_requests 
        ORDER BY requested_at DESC 
        LIMIT 1;
        
        IF sample_request.id IS NOT NULL THEN
            RAISE NOTICE '📋 Sample request: % (status: %)', sample_request.request_number, sample_request.status;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Cannot access warehouse_requests: %', SQLERRM;
    END;
END $$;

-- Test direct access to warehouse_request_items
DO $$
DECLARE
    items_count INTEGER;
    sample_item RECORD;
BEGIN
    BEGIN
        SELECT COUNT(*) INTO items_count FROM warehouse_request_items;
        RAISE NOTICE '📦 Can access warehouse_request_items: % records found', items_count;
        
        -- Get a sample item
        SELECT id, request_id, product_id, quantity INTO sample_item
        FROM warehouse_request_items 
        LIMIT 1;
        
        IF sample_item.id IS NOT NULL THEN
            RAISE NOTICE '📦 Sample item: Product % (quantity: %)', sample_item.product_id, sample_item.quantity;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Cannot access warehouse_request_items: %', SQLERRM;
    END;
END $$;

-- ==================== STEP 4: TEST JOIN QUERIES ====================

-- Test the JOIN query that the application uses
DO $$
DECLARE
    join_result RECORD;
    join_count INTEGER := 0;
BEGIN
    BEGIN
        RAISE NOTICE '🔗 Testing JOIN query (application pattern)...';
        
        FOR join_result IN 
            SELECT 
                wr.id,
                wr.request_number,
                wr.status,
                COUNT(wri.id) as items_count
            FROM warehouse_requests wr
            LEFT JOIN warehouse_request_items wri ON wr.id = wri.request_id
            GROUP BY wr.id, wr.request_number, wr.status
            ORDER BY wr.requested_at DESC
            LIMIT 5
        LOOP
            join_count := join_count + 1;
            RAISE NOTICE '🔗 JOIN Result %: Request % has % items', 
                join_count, 
                join_result.request_number, 
                join_result.items_count;
        END LOOP;
        
        IF join_count = 0 THEN
            RAISE NOTICE '⚠️ JOIN query returned no results';
        ELSE
            RAISE NOTICE '✅ JOIN query successful: % results', join_count;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ JOIN query failed: %', SQLERRM;
    END;
END $$;

-- ==================== STEP 5: TEST NESTED SELECT QUERIES ====================

-- Test the nested SELECT pattern used in the service
DO $$
DECLARE
    nested_result RECORD;
    nested_count INTEGER := 0;
BEGIN
    BEGIN
        RAISE NOTICE '🎯 Testing nested SELECT query (service pattern)...';
        
        FOR nested_result IN 
            SELECT 
                wr.id,
                wr.request_number,
                wr.status,
                (
                    SELECT COUNT(*) 
                    FROM warehouse_request_items wri 
                    WHERE wri.request_id = wr.id
                ) as items_count_nested
            FROM warehouse_requests wr
            ORDER BY wr.requested_at DESC
            LIMIT 5
        LOOP
            nested_count := nested_count + 1;
            RAISE NOTICE '🎯 Nested Result %: Request % has % items (nested count)', 
                nested_count, 
                nested_result.request_number, 
                nested_result.items_count_nested;
        END LOOP;
        
        IF nested_count = 0 THEN
            RAISE NOTICE '⚠️ Nested SELECT query returned no results';
        ELSE
            RAISE NOTICE '✅ Nested SELECT query successful: % results', nested_count;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Nested SELECT query failed: %', SQLERRM;
    END;
END $$;

-- ==================== STEP 6: SIMULATE ROLE-SPECIFIC ACCESS ====================

-- Create a function to test access as different roles
CREATE OR REPLACE FUNCTION simulate_role_access(target_role TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    test_user_id UUID;
    request_count INTEGER;
    items_count INTEGER;
    result_text TEXT;
BEGIN
    -- Find a user with the target role
    SELECT id INTO test_user_id
    FROM user_profiles 
    WHERE role = target_role AND status = 'approved'
    LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RETURN 'No approved user found with role: ' || target_role;
    END IF;
    
    -- Test if this user would pass the RLS policies
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE user_profiles.id = test_user_id
          AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'warehouse_manager', 'owner')
          AND user_profiles.status = 'approved'
    ) INTO result_text;
    
    IF result_text::BOOLEAN THEN
        result_text := 'PASS - Role ' || target_role || ' should have access';
    ELSE
        result_text := 'FAIL - Role ' || target_role || ' should NOT have access';
    END IF;
    
    RETURN result_text;
END;
$$;

-- Test different roles
SELECT '🎭 Role Access Simulation:' as test_type;
SELECT simulate_role_access('admin') as admin_access;
SELECT simulate_role_access('accountant') as accountant_access;
SELECT simulate_role_access('warehouseManager') as warehouse_manager_camel_access;
SELECT simulate_role_access('warehouse_manager') as warehouse_manager_snake_access;
SELECT simulate_role_access('owner') as owner_access;
SELECT simulate_role_access('client') as client_access;

-- ==================== STEP 7: CHECK FOR POLICY CONFLICTS ====================

-- Look for conflicting or overlapping policies
SELECT 
    '⚠️ Potential Policy Conflicts:' as warning,
    tablename,
    COUNT(*) as policy_count,
    string_agg(policyname, ', ') as policy_names
FROM pg_policies 
WHERE tablename IN ('warehouse_requests', 'warehouse_request_items')
GROUP BY tablename
HAVING COUNT(*) > 4; -- More than expected number of policies

-- ==================== STEP 8: SUMMARY AND RECOMMENDATIONS ====================

DO $$
BEGIN
    RAISE NOTICE '==================== DIAGNOSIS SUMMARY ====================';
    RAISE NOTICE 'Check the output above for:';
    RAISE NOTICE '1. ✅ RLS is enabled on both tables';
    RAISE NOTICE '2. ✅ Current user has proper role and status';
    RAISE NOTICE '3. ✅ Direct table access works';
    RAISE NOTICE '4. ✅ JOIN queries work';
    RAISE NOTICE '5. ✅ Nested SELECT queries work';
    RAISE NOTICE '6. ✅ Role simulation shows expected access';
    RAISE NOTICE '7. ⚠️ No policy conflicts detected';
    RAISE NOTICE '';
    RAISE NOTICE 'If any of the above show ❌ or unexpected results,';
    RAISE NOTICE 'that indicates the source of the data sync issue.';
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Run fix_warehouse_dispatch_data_sync_issue.sql';
END $$;

-- Cleanup
DROP FUNCTION IF EXISTS simulate_role_access(TEXT);
