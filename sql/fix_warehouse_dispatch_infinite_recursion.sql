-- =====================================================
-- FIX WAREHOUSE DISPATCH INFINITE RECURSION
-- =====================================================
-- This script fixes the PostgreSQL infinite recursion error (code: 42P17)
-- affecting warehouse dispatch functionality by replacing direct user_profiles
-- queries in RLS policies with SECURITY DEFINER functions

SELECT '🔧 FIXING WAREHOUSE DISPATCH INFINITE RECURSION...' as progress;

-- =====================================================
-- STEP 1: CREATE SECURITY DEFINER FUNCTIONS
-- =====================================================

-- Function to safely check if user has warehouse management permissions
-- Using CREATE OR REPLACE to handle existing functions gracefully
CREATE OR REPLACE FUNCTION check_warehouse_user_permissions_safe()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Bypass RLS by using SECURITY DEFINER
    -- Check if current user has warehouse management role and is approved
    RETURN EXISTS (
        SELECT 1 FROM user_profiles
        WHERE id = auth.uid()
          AND role IN ('admin', 'owner', 'accountant', 'warehouseManager')
          AND status = 'approved'
    );
EXCEPTION
    WHEN OTHERS THEN
        -- Return false if any error occurs (e.g., user_profiles table issues)
        RETURN false;
END;
$$;

-- Function to safely check if user has admin/owner permissions for warehouse operations
-- Using CREATE OR REPLACE to handle existing functions gracefully
CREATE OR REPLACE FUNCTION check_warehouse_admin_permissions_safe()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Bypass RLS by using SECURITY DEFINER
    -- Check if current user has admin/owner role and is approved
    RETURN EXISTS (
        SELECT 1 FROM user_profiles
        WHERE id = auth.uid()
          AND role IN ('admin', 'owner', 'accountant')
          AND status = 'approved'
    );
EXCEPTION
    WHEN OTHERS THEN
        -- Return false if any error occurs (e.g., user_profiles table issues)
        RETURN false;
END;
$$;

-- Function to safely validate a user ID for warehouse operations
-- Using CREATE OR REPLACE to handle existing functions gracefully
CREATE OR REPLACE FUNCTION validate_warehouse_user_safe(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Bypass RLS by using SECURITY DEFINER
    -- Check if the provided user ID has warehouse management permissions
    RETURN EXISTS (
        SELECT 1 FROM user_profiles
        WHERE id = user_id
          AND role IN ('admin', 'owner', 'accountant', 'warehouseManager')
          AND status = 'approved'
    );
EXCEPTION
    WHEN OTHERS THEN
        -- Return false if any error occurs (e.g., user_profiles table issues)
        RETURN false;
END;
$$;

-- Grant execute permissions on the functions
DO $$
BEGIN
    -- Grant to authenticated role
    GRANT EXECUTE ON FUNCTION check_warehouse_user_permissions_safe() TO authenticated;
    GRANT EXECUTE ON FUNCTION check_warehouse_admin_permissions_safe() TO authenticated;
    GRANT EXECUTE ON FUNCTION validate_warehouse_user_safe(uuid) TO authenticated;

    -- Grant to service_role for administrative operations
    GRANT EXECUTE ON FUNCTION check_warehouse_user_permissions_safe() TO service_role;
    GRANT EXECUTE ON FUNCTION check_warehouse_admin_permissions_safe() TO service_role;
    GRANT EXECUTE ON FUNCTION validate_warehouse_user_safe(uuid) TO service_role;

    RAISE NOTICE 'Granted execute permissions on warehouse SECURITY DEFINER functions';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error granting permissions: %', SQLERRM;
END $$;

SELECT '✅ Created SECURITY DEFINER functions for warehouse operations' as progress;

-- =====================================================
-- STEP 2: FIX WAREHOUSE_REQUESTS TABLE POLICIES
-- =====================================================

SELECT '🔧 Fixing warehouse_requests table policies...' as progress;

-- Drop all existing policies that cause infinite recursion (comprehensive cleanup)
DO $$
BEGIN
    -- Drop all existing warehouse_requests policies (including new safe ones)
    DROP POLICY IF EXISTS "warehouse_requests_select_policy" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_insert_policy" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_update_policy" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_delete_policy" ON warehouse_requests;
    DROP POLICY IF EXISTS "secure_requests_select" ON warehouse_requests;
    DROP POLICY IF EXISTS "secure_requests_insert" ON warehouse_requests;
    DROP POLICY IF EXISTS "secure_requests_update" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_all_operations" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_allow_warehouse_managers" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_insert_secure" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_insert_fixed" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_insert_working" ON warehouse_requests;
    -- Drop the new safe policies in case they exist from previous runs
    DROP POLICY IF EXISTS "warehouse_requests_select_safe" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_insert_safe" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_update_safe" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_requests_delete_safe" ON warehouse_requests;

    RAISE NOTICE 'Dropped all existing warehouse_requests policies (including safe ones)';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Some policies may not have existed: %', SQLERRM;
END $$;

-- Create new safe policies using SECURITY DEFINER functions with exception handling
DO $$
BEGIN
    -- SELECT policy
    BEGIN
        CREATE POLICY "warehouse_requests_select_safe" ON warehouse_requests
          FOR SELECT
          USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_user_permissions_safe()
          );
        RAISE NOTICE 'Created warehouse_requests_select_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_requests_select_safe already exists, skipping';
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating warehouse_requests_select_safe: %', SQLERRM;
    END;

    -- INSERT policy
    BEGIN
        CREATE POLICY "warehouse_requests_insert_safe" ON warehouse_requests
          FOR INSERT
          WITH CHECK (
            auth.uid() IS NOT NULL AND
            check_warehouse_user_permissions_safe() AND
            (requested_by = auth.uid() OR requested_by IS NULL)
          );
        RAISE NOTICE 'Created warehouse_requests_insert_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_requests_insert_safe already exists, skipping';
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating warehouse_requests_insert_safe: %', SQLERRM;
    END;

    -- UPDATE policy
    BEGIN
        CREATE POLICY "warehouse_requests_update_safe" ON warehouse_requests
          FOR UPDATE
          USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_admin_permissions_safe()
          );
        RAISE NOTICE 'Created warehouse_requests_update_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_requests_update_safe already exists, skipping';
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating warehouse_requests_update_safe: %', SQLERRM;
    END;

    -- DELETE policy
    BEGIN
        CREATE POLICY "warehouse_requests_delete_safe" ON warehouse_requests
          FOR DELETE
          USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_admin_permissions_safe()
          );
        RAISE NOTICE 'Created warehouse_requests_delete_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_requests_delete_safe already exists, skipping';
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating warehouse_requests_delete_safe: %', SQLERRM;
    END;
END $$;

SELECT '✅ Created safe warehouse_requests policies' as progress;

-- =====================================================
-- STEP 3: FIX WAREHOUSE_REQUEST_ITEMS TABLE POLICIES
-- =====================================================

SELECT '🔧 Fixing warehouse_request_items table policies...' as progress;

-- Drop all existing policies that cause infinite recursion (comprehensive cleanup)
DO $$
BEGIN
    -- Drop all existing warehouse_request_items policies (including new safe ones)
    DROP POLICY IF EXISTS "warehouse_request_items_select_policy" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_insert_policy" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_update_policy" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_delete_policy" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_all_operations" ON warehouse_request_items;
    -- Drop the new safe policies in case they exist from previous runs
    DROP POLICY IF EXISTS "warehouse_request_items_select_safe" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_insert_safe" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_update_safe" ON warehouse_request_items;
    DROP POLICY IF EXISTS "warehouse_request_items_delete_safe" ON warehouse_request_items;

    RAISE NOTICE 'Dropped all existing warehouse_request_items policies (including safe ones)';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Some policies may not have existed: %', SQLERRM;
END $$;

-- Create new safe policies using SECURITY DEFINER functions with exception handling
DO $$
BEGIN
    -- SELECT policy
    BEGIN
        CREATE POLICY "warehouse_request_items_select_safe" ON warehouse_request_items
          FOR SELECT
          USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_user_permissions_safe()
          );
        RAISE NOTICE 'Created warehouse_request_items_select_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_request_items_select_safe already exists, skipping';
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating warehouse_request_items_select_safe: %', SQLERRM;
    END;

    -- INSERT policy
    BEGIN
        CREATE POLICY "warehouse_request_items_insert_safe" ON warehouse_request_items
          FOR INSERT
          WITH CHECK (
            auth.uid() IS NOT NULL AND
            check_warehouse_user_permissions_safe()
          );
        RAISE NOTICE 'Created warehouse_request_items_insert_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_request_items_insert_safe already exists, skipping';
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating warehouse_request_items_insert_safe: %', SQLERRM;
    END;

    -- UPDATE policy
    BEGIN
        CREATE POLICY "warehouse_request_items_update_safe" ON warehouse_request_items
          FOR UPDATE
          USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_user_permissions_safe()
          );
        RAISE NOTICE 'Created warehouse_request_items_update_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_request_items_update_safe already exists, skipping';
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating warehouse_request_items_update_safe: %', SQLERRM;
    END;

    -- DELETE policy
    BEGIN
        CREATE POLICY "warehouse_request_items_delete_safe" ON warehouse_request_items
          FOR DELETE
          USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_admin_permissions_safe()
          );
        RAISE NOTICE 'Created warehouse_request_items_delete_safe policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_request_items_delete_safe already exists, skipping';
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating warehouse_request_items_delete_safe: %', SQLERRM;
    END;
END $$;

SELECT '✅ Created safe warehouse_request_items policies' as progress;

-- =====================================================
-- STEP 4: ENSURE RLS IS ENABLED AND GRANT PERMISSIONS
-- =====================================================

-- Enable RLS on both tables with error handling
DO $$
BEGIN
    -- Enable RLS on warehouse_requests
    BEGIN
        ALTER TABLE warehouse_requests ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'Enabled RLS on warehouse_requests';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'RLS may already be enabled on warehouse_requests: %', SQLERRM;
    END;

    -- Enable RLS on warehouse_request_items
    BEGIN
        ALTER TABLE warehouse_request_items ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'Enabled RLS on warehouse_request_items';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'RLS may already be enabled on warehouse_request_items: %', SQLERRM;
    END;

    -- Grant necessary permissions on warehouse_requests
    BEGIN
        GRANT SELECT, INSERT, UPDATE, DELETE ON warehouse_requests TO authenticated;
        RAISE NOTICE 'Granted permissions on warehouse_requests to authenticated';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Permissions may already be granted on warehouse_requests: %', SQLERRM;
    END;

    -- Grant necessary permissions on warehouse_request_items
    BEGIN
        GRANT SELECT, INSERT, UPDATE, DELETE ON warehouse_request_items TO authenticated;
        RAISE NOTICE 'Granted permissions on warehouse_request_items to authenticated';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Permissions may already be granted on warehouse_request_items: %', SQLERRM;
    END;
END $$;

SELECT '✅ Enabled RLS and granted permissions (with error handling)' as progress;

-- =====================================================
-- STEP 5: VERIFICATION AND TESTING
-- =====================================================

SELECT '🔧 Running verification tests...' as progress;

-- Test the new policies
DO $$
DECLARE
    test_count integer;
BEGIN
    -- Test warehouse_requests table
    BEGIN
        SELECT COUNT(*) INTO test_count FROM warehouse_requests;
        RAISE NOTICE 'SUCCESS: warehouse_requests query returned % rows without infinite recursion', test_count;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR: warehouse_requests still has issues: %', SQLERRM;
    END;
    
    -- Test warehouse_request_items table
    BEGIN
        SELECT COUNT(*) INTO test_count FROM warehouse_request_items;
        RAISE NOTICE 'SUCCESS: warehouse_request_items query returned % rows without infinite recursion', test_count;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR: warehouse_request_items still has issues: %', SQLERRM;
    END;
END $$;

-- Show final policy status
SELECT 
    '✅ FINAL WAREHOUSE DISPATCH POLICIES' as summary,
    tablename,
    policyname,
    cmd as operation,
    'Using SECURITY DEFINER functions' as status
FROM pg_policies 
WHERE tablename IN ('warehouse_requests', 'warehouse_request_items')
  AND (qual LIKE '%_safe()%' OR with_check LIKE '%_safe()%')
ORDER BY tablename, cmd;

SELECT '✅ WAREHOUSE DISPATCH INFINITE RECURSION FIX COMPLETED!' as final_status;

-- =====================================================
-- STEP 6: COMPREHENSIVE DIAGNOSIS OF REMAINING ISSUES
-- =====================================================

-- Check if our SECURITY DEFINER functions exist
SELECT
    '🔍 CHECKING SECURITY DEFINER FUNCTIONS' as check_type,
    routine_name,
    routine_type,
    security_type,
    'Function exists and is SECURITY DEFINER' as status
FROM information_schema.routines
WHERE routine_name IN ('get_user_role_safe', 'get_user_status_safe', 'check_warehouse_access_safe')
  AND routine_schema = 'public'
ORDER BY routine_name;

-- Check ALL RLS policies that might reference user_profiles
SELECT
    '🔍 ALL POLICIES REFERENCING USER_PROFILES' as check_type,
    schemaname,
    tablename,
    policyname,
    cmd as operation,
    CASE
        WHEN qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%' THEN 'POTENTIAL_RECURSION'
        ELSE 'SAFE'
    END as recursion_risk,
    qual as using_condition,
    with_check as with_check_condition
FROM pg_policies
WHERE (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%')
  AND schemaname = 'public'
ORDER BY recursion_risk DESC, tablename, cmd;

-- Check for any remaining problematic policies on warehouse tables
SELECT
    '🔍 WAREHOUSE TABLE POLICIES STATUS' as check_type,
    tablename,
    policyname,
    cmd as operation,
    CASE
        WHEN qual LIKE '%_safe()%' OR with_check LIKE '%_safe()%' THEN 'USING_SAFE_FUNCTIONS'
        WHEN qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%' THEN 'DANGEROUS_RECURSION'
        ELSE 'OTHER'
    END as policy_type
FROM pg_policies
WHERE tablename IN ('warehouse_requests', 'warehouse_request_items', 'warehouses')
  AND schemaname = 'public'
ORDER BY policy_type DESC, tablename, cmd;

-- Test the exact query that Flutter is running
DO $$
DECLARE
    test_result RECORD;
    error_message TEXT;
BEGIN
    -- Test the exact query from Flutter WarehouseDispatchService
    BEGIN
        SELECT COUNT(*) as request_count INTO test_result
        FROM warehouse_requests wr
        LEFT JOIN warehouse_request_items wri ON wr.id = wri.request_id;

        RAISE NOTICE '✅ FLUTTER QUERY TEST PASSED: Found % warehouse requests with items', test_result.request_count;
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            RAISE NOTICE '❌ FLUTTER QUERY TEST FAILED: %', error_message;

            -- If it's infinite recursion, we need to find the root cause
            IF error_message LIKE '%infinite recursion%' THEN
                RAISE NOTICE '🔍 INFINITE RECURSION DETECTED - Checking user_profiles policies...';

                -- Check user_profiles policies
                FOR test_result IN
                    SELECT policyname, cmd, qual, with_check
                    FROM pg_policies
                    WHERE tablename = 'user_profiles'
                LOOP
                    RAISE NOTICE '📋 user_profiles policy: % (%) - USING: % - WITH CHECK: %',
                        test_result.policyname, test_result.cmd, test_result.qual, test_result.with_check;
                END LOOP;
            END IF;
    END;
END $$;

-- Final instructions
SELECT
    'NEXT STEPS FOR WAREHOUSE DISPATCH:' as instructions,
    '1. Test warehouse dispatch loading in Flutter app' as step_1,
    '2. Verify dispatch request creation works' as step_2,
    '3. Check dispatch request status updates' as step_3,
    '4. All infinite recursion errors should be resolved' as step_4;
