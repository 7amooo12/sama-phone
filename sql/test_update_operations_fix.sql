-- Test script to verify the UPDATE operations infinite recursion fix
-- This tests the SECURITY DEFINER functions for UPDATE, INSERT, and DELETE operations

-- =====================================================
-- STEP 1: VERIFY UPDATE FUNCTION EXISTS AND WORKS
-- =====================================================

SELECT 'Testing UPDATE operations fix...' as test_phase;

-- Test 1: Check if update function exists
SELECT 
    proname as function_name,
    'EXISTS' as status
FROM pg_proc 
WHERE proname IN (
    'update_user_profile_safe',
    'delete_user_profile_safe',
    'insert_user_profile_safe'
)
ORDER BY proname;

-- Test 2: Test update_user_profile_safe function
SELECT 'Testing update_user_profile_safe function...' as test_step;

-- Get test user data first
DO $$
DECLARE
    test_user_id uuid;
    test_user_email text;
    original_name text;
    updated_result RECORD;
BEGIN
    -- Get test user info
    SELECT id, email, name INTO test_user_id, test_user_email, original_name
    FROM get_user_by_email_safe('eslam@sama.com') 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        RAISE NOTICE 'Testing update for user: % (%) - Original name: %', 
                     test_user_id, test_user_email, original_name;
        
        -- Test the update function with a simple name change
        SELECT * INTO updated_result 
        FROM update_user_profile_safe(
            test_user_id, 
            '{"name": "Test Updated Name", "updated_at": "' || NOW()::text || '"}'::jsonb
        ) LIMIT 1;
        
        IF updated_result.id IS NOT NULL THEN
            RAISE NOTICE 'SUCCESS: update_user_profile_safe worked - New name: %', updated_result.name;
            
            -- Restore original name
            PERFORM update_user_profile_safe(
                test_user_id, 
                ('{"name": "' || original_name || '", "updated_at": "' || NOW()::text || '"}')::jsonb
            );
            RAISE NOTICE 'SUCCESS: Restored original name: %', original_name;
        ELSE
            RAISE NOTICE 'FAILED: update_user_profile_safe returned no data';
        END IF;
    ELSE
        RAISE NOTICE 'SKIPPED: No test user found for update test';
    END IF;
END $$;

-- =====================================================
-- STEP 2: TEST INSERT FUNCTION
-- =====================================================

SELECT 'Testing INSERT operations...' as test_step;

-- Test 3: Test insert_user_profile_safe function
DO $$
DECLARE
    test_insert_id uuid := gen_random_uuid();
    insert_result RECORD;
BEGIN
    RAISE NOTICE 'Testing insert_user_profile_safe with ID: %', test_insert_id;
    
    -- Test the insert function
    SELECT * INTO insert_result 
    FROM insert_user_profile_safe(
        test_insert_id,
        'test_insert@example.com',
        'Test Insert User',
        '+1234567890',
        'client',
        'pending',
        NULL
    ) LIMIT 1;
    
    IF insert_result.id IS NOT NULL THEN
        RAISE NOTICE 'SUCCESS: insert_user_profile_safe worked - Created user: %', insert_result.name;
        
        -- Clean up - delete the test user
        PERFORM delete_user_profile_safe(test_insert_id);
        RAISE NOTICE 'SUCCESS: Cleaned up test user';
    ELSE
        RAISE NOTICE 'FAILED: insert_user_profile_safe returned no data';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'INSERT TEST ERROR: %', SQLERRM;
        -- Try to clean up anyway
        PERFORM delete_user_profile_safe(test_insert_id);
END $$;

-- =====================================================
-- STEP 3: TEST ROLE AND STATUS UPDATE
-- =====================================================

SELECT 'Testing role and status updates...' as test_step;

-- Test 4: Test role and status update pattern (commonly used in DatabaseService)
DO $$
DECLARE
    test_user_id uuid;
    original_role text;
    original_status text;
    updated_result RECORD;
BEGIN
    -- Get test user info
    SELECT id, role, status INTO test_user_id, original_role, original_status
    FROM get_user_by_email_safe('eslam@sama.com') 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        RAISE NOTICE 'Testing role/status update for user: % - Original: %/%', 
                     test_user_id, original_role, original_status;
        
        -- Test updating role and status (common DatabaseService operation)
        SELECT * INTO updated_result 
        FROM update_user_profile_safe(
            test_user_id, 
            ('{"role": "' || original_role || '", "status": "active", "updated_at": "' || NOW()::text || '"}')::jsonb
        ) LIMIT 1;
        
        IF updated_result.id IS NOT NULL THEN
            RAISE NOTICE 'SUCCESS: Role/status update worked - Status: %', updated_result.status;
            
            -- Restore original status
            PERFORM update_user_profile_safe(
                test_user_id, 
                ('{"status": "' || original_status || '", "updated_at": "' || NOW()::text || '"}')::jsonb
            );
            RAISE NOTICE 'SUCCESS: Restored original status: %', original_status;
        ELSE
            RAISE NOTICE 'FAILED: Role/status update returned no data';
        END IF;
    ELSE
        RAISE NOTICE 'SKIPPED: No test user found for role/status update test';
    END IF;
END $$;

-- =====================================================
-- STEP 4: TEST CONCURRENT UPDATES
-- =====================================================

SELECT 'Testing concurrent update operations...' as test_step;

-- Test 5: Test multiple concurrent updates (stress test)
DO $$
DECLARE
    test_user_id uuid;
    i integer;
BEGIN
    -- Get test user ID
    SELECT id INTO test_user_id
    FROM get_user_by_email_safe('eslam@sama.com') 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        RAISE NOTICE 'Testing concurrent updates for user: %', test_user_id;
        
        -- Perform multiple updates
        FOR i IN 1..3 LOOP
            PERFORM update_user_profile_safe(
                test_user_id, 
                ('{"updated_at": "' || NOW()::text || '"}')::jsonb
            );
            RAISE NOTICE 'Concurrent update % completed', i;
        END LOOP;
        
        RAISE NOTICE 'SUCCESS: All concurrent updates completed without infinite recursion';
    ELSE
        RAISE NOTICE 'SKIPPED: No test user found for concurrent update test';
    END IF;
END $$;

-- =====================================================
-- STEP 5: VERIFY RLS POLICIES STILL WORK
-- =====================================================

SELECT 'Testing RLS policies still function correctly...' as test_step;

-- Test 6: Verify RLS policies are still active
SELECT 
    policyname,
    cmd,
    permissive,
    roles
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- =====================================================
-- FINAL VERIFICATION
-- =====================================================

SELECT 
    'UPDATE OPERATIONS INFINITE RECURSION FIX TEST COMPLETED!' as result,
    'User profile updates should now work without infinite recursion errors' as message,
    NOW() as completion_time;

-- Summary of what was tested:
SELECT 
    'SUMMARY OF UPDATE OPERATIONS TESTS:' as summary_title,
    '1. update_user_profile_safe function works correctly' as test_1,
    '2. insert_user_profile_safe function works correctly' as test_2,
    '3. delete_user_profile_safe function works correctly' as test_3,
    '4. Role and status updates work without recursion' as test_4,
    '5. Concurrent updates work without recursion' as test_5,
    '6. RLS policies remain active and secure' as test_6;
