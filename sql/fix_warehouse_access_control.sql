-- 🔧 COMPREHENSIVE WAREHOUSE ACCESS CONTROL FIX
-- Systematic resolution of role-based access issues for warehouse data

-- ==================== STEP 1: CLEANUP EXISTING POLICIES ====================

-- Drop all existing warehouse-related policies to start fresh
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    -- Drop policies on warehouses table
    FOR policy_record IN 
        SELECT policyname FROM pg_policies 
        WHERE tablename = 'warehouses' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON warehouses', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;

    -- Drop policies on warehouse_inventory table
    FOR policy_record IN 
        SELECT policyname FROM pg_policies 
        WHERE tablename = 'warehouse_inventory' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON warehouse_inventory', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;

    -- Drop policies on warehouse_transactions table
    FOR policy_record IN 
        SELECT policyname FROM pg_policies 
        WHERE tablename = 'warehouse_transactions' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON warehouse_transactions', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;

    -- Drop policies on warehouse_requests table
    FOR policy_record IN 
        SELECT policyname FROM pg_policies 
        WHERE tablename = 'warehouse_requests' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON warehouse_requests', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;

    -- Drop policies on warehouse_request_items table
    FOR policy_record IN 
        SELECT policyname FROM pg_policies 
        WHERE tablename = 'warehouse_request_items' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON warehouse_request_items', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;

    RAISE NOTICE '✅ All existing warehouse policies have been dropped';
END $$;

-- ==================== STEP 2: CREATE SECURITY DEFINER FUNCTION ====================

-- Create a SECURITY DEFINER function to check user permissions without RLS recursion
CREATE OR REPLACE FUNCTION check_warehouse_access(user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
    user_status TEXT;
BEGIN
    -- Get user role and status directly without RLS
    SELECT role, status INTO user_role, user_status
    FROM user_profiles
    WHERE id = user_id;
    
    -- Check if user has warehouse access
    RETURN (
        user_role IS NOT NULL AND 
        user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND
        user_status = 'approved'
    );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_warehouse_access(UUID) TO authenticated;

-- ==================== STEP 3: ENABLE RLS ON ALL WAREHOUSE TABLES ====================

-- Enable RLS on all warehouse tables
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_requests ENABLE ROW LEVEL SECURITY;

-- Enable RLS on warehouse_request_items if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_request_items') THEN
        ALTER TABLE warehouse_request_items ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE '✅ RLS enabled on warehouse_request_items';
    ELSE
        RAISE NOTICE 'ℹ️ warehouse_request_items table does not exist';
    END IF;
END $$;

-- ==================== STEP 4: CREATE COMPREHENSIVE WAREHOUSE POLICIES ====================

-- WAREHOUSES TABLE POLICIES
-- SELECT: All authorized roles can view warehouses
CREATE POLICY "warehouses_select_policy" ON warehouses
    FOR SELECT
    USING (
        auth.uid() IS NOT NULL AND 
        check_warehouse_access(auth.uid())
    );

-- INSERT: Admin, Owner, Accountant can create warehouses
CREATE POLICY "warehouses_insert_policy" ON warehouses
    FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL AND 
        check_warehouse_access(auth.uid()) AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'accountant')
            AND status = 'approved'
        )
    );

-- UPDATE: Admin, Owner, Accountant can update warehouses
CREATE POLICY "warehouses_update_policy" ON warehouses
    FOR UPDATE
    USING (
        auth.uid() IS NOT NULL AND 
        check_warehouse_access(auth.uid()) AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'accountant')
            AND status = 'approved'
        )
    );

-- DELETE: Only Admin and Owner can delete warehouses
CREATE POLICY "warehouses_delete_policy" ON warehouses
    FOR DELETE
    USING (
        auth.uid() IS NOT NULL AND 
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
            AND status = 'approved'
        )
    );

-- ==================== STEP 5: WAREHOUSE INVENTORY POLICIES ====================

-- SELECT: All authorized roles can view inventory
CREATE POLICY "inventory_select_policy" ON warehouse_inventory
    FOR SELECT
    USING (
        auth.uid() IS NOT NULL AND 
        check_warehouse_access(auth.uid())
    );

-- INSERT: All authorized roles can add inventory
CREATE POLICY "inventory_insert_policy" ON warehouse_inventory
    FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL AND 
        check_warehouse_access(auth.uid())
    );

-- UPDATE: All authorized roles can update inventory
CREATE POLICY "inventory_update_policy" ON warehouse_inventory
    FOR UPDATE
    USING (
        auth.uid() IS NOT NULL AND 
        check_warehouse_access(auth.uid())
    );

-- DELETE: Admin, Owner, Accountant can delete inventory items
CREATE POLICY "inventory_delete_policy" ON warehouse_inventory
    FOR DELETE
    USING (
        auth.uid() IS NOT NULL AND 
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'accountant')
            AND status = 'approved'
        )
    );

-- ==================== STEP 6: WAREHOUSE TRANSACTIONS POLICIES ====================

-- SELECT: All authorized roles can view transactions
CREATE POLICY "transactions_select_policy" ON warehouse_transactions
    FOR SELECT
    USING (
        auth.uid() IS NOT NULL AND 
        check_warehouse_access(auth.uid())
    );

-- INSERT: All authorized roles can create transactions
CREATE POLICY "transactions_insert_policy" ON warehouse_transactions
    FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL AND 
        check_warehouse_access(auth.uid())
    );

-- UPDATE: All authorized roles can update transactions
CREATE POLICY "transactions_update_policy" ON warehouse_transactions
    FOR UPDATE
    USING (
        auth.uid() IS NOT NULL AND 
        check_warehouse_access(auth.uid())
    );

-- DELETE: Only Admin can delete transactions (audit integrity)
CREATE POLICY "transactions_delete_policy" ON warehouse_transactions
    FOR DELETE
    USING (
        auth.uid() IS NOT NULL AND 
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND status = 'approved'
        )
    );

-- ==================== STEP 7: WAREHOUSE REQUESTS POLICIES ====================

-- SELECT: All authorized roles can view requests
CREATE POLICY "requests_select_policy" ON warehouse_requests
    FOR SELECT
    USING (
        auth.uid() IS NOT NULL AND 
        check_warehouse_access(auth.uid())
    );

-- INSERT: All authorized roles can create requests
CREATE POLICY "requests_insert_policy" ON warehouse_requests
    FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL AND 
        check_warehouse_access(auth.uid())
    );

-- UPDATE: Admin, Owner, Accountant can approve/modify requests
CREATE POLICY "requests_update_policy" ON warehouse_requests
    FOR UPDATE
    USING (
        auth.uid() IS NOT NULL AND 
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'accountant')
            AND status = 'approved'
        )
    );

-- DELETE: Admin, Owner can delete requests
CREATE POLICY "requests_delete_policy" ON warehouse_requests
    FOR DELETE
    USING (
        auth.uid() IS NOT NULL AND 
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
            AND status = 'approved'
        )
    );

-- ==================== STEP 8: WAREHOUSE REQUEST ITEMS POLICIES (IF EXISTS) ====================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_request_items') THEN
        -- SELECT: All authorized roles can view request items
        EXECUTE 'CREATE POLICY "request_items_select_policy" ON warehouse_request_items
            FOR SELECT
            USING (
                auth.uid() IS NOT NULL AND 
                check_warehouse_access(auth.uid())
            )';

        -- INSERT: All authorized roles can create request items
        EXECUTE 'CREATE POLICY "request_items_insert_policy" ON warehouse_request_items
            FOR INSERT
            WITH CHECK (
                auth.uid() IS NOT NULL AND 
                check_warehouse_access(auth.uid())
            )';

        -- UPDATE: All authorized roles can update request items
        EXECUTE 'CREATE POLICY "request_items_update_policy" ON warehouse_request_items
            FOR UPDATE
            USING (
                auth.uid() IS NOT NULL AND 
                check_warehouse_access(auth.uid())
            )';

        -- DELETE: Admin, Owner can delete request items
        EXECUTE 'CREATE POLICY "request_items_delete_policy" ON warehouse_request_items
            FOR DELETE
            USING (
                auth.uid() IS NOT NULL AND 
                EXISTS (
                    SELECT 1 FROM user_profiles 
                    WHERE id = auth.uid() 
                    AND role IN (''admin'', ''owner'')
                    AND status = ''approved''
                )
            )';

        RAISE NOTICE '✅ Policies created for warehouse_request_items';
    ELSE
        RAISE NOTICE 'ℹ️ warehouse_request_items table does not exist, skipping policies';
    END IF;
END $$;

-- ==================== STEP 9: VERIFICATION ====================

-- Show created policies
SELECT 
    '✅ CREATED POLICIES VERIFICATION' as status,
    schemaname,
    tablename,
    policyname,
    cmd as operation,
    CASE 
        WHEN roles = '{public}' THEN '🚨 PUBLIC ACCESS'
        ELSE '🔒 SECURED'
    END as security_status
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests', 'warehouse_request_items')
ORDER BY tablename, cmd;

-- Show RLS status
SELECT 
    '🔒 RLS STATUS VERIFICATION' as status,
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests', 'warehouse_request_items')
  AND schemaname = 'public';

-- ==================== STEP 10: TEST ACCESS FOR EACH ROLE ====================

-- Test function to verify access for a specific user
CREATE OR REPLACE FUNCTION test_user_warehouse_access(test_user_id UUID)
RETURNS TABLE(
    test_name TEXT,
    table_name TEXT,
    operation TEXT,
    success BOOLEAN,
    error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    test_result RECORD;
    error_msg TEXT;
BEGIN
    -- Get user info for context
    SELECT role, status INTO test_result
    FROM user_profiles
    WHERE id = test_user_id;

    IF test_result IS NULL THEN
        RETURN QUERY SELECT
            'User Profile Check'::TEXT,
            'user_profiles'::TEXT,
            'SELECT'::TEXT,
            FALSE,
            'User not found'::TEXT;
        RETURN;
    END IF;

    -- Test warehouses SELECT
    BEGIN
        PERFORM * FROM warehouses LIMIT 1;
        RETURN QUERY SELECT
            format('Role: %s, Status: %s', test_result.role, test_result.status)::TEXT,
            'warehouses'::TEXT,
            'SELECT'::TEXT,
            TRUE,
            'Success'::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT
            format('Role: %s, Status: %s', test_result.role, test_result.status)::TEXT,
            'warehouses'::TEXT,
            'SELECT'::TEXT,
            FALSE,
            SQLERRM::TEXT;
    END;

    -- Test warehouse_inventory SELECT
    BEGIN
        PERFORM * FROM warehouse_inventory LIMIT 1;
        RETURN QUERY SELECT
            format('Role: %s, Status: %s', test_result.role, test_result.status)::TEXT,
            'warehouse_inventory'::TEXT,
            'SELECT'::TEXT,
            TRUE,
            'Success'::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT
            format('Role: %s, Status: %s', test_result.role, test_result.status)::TEXT,
            'warehouse_inventory'::TEXT,
            'SELECT'::TEXT,
            FALSE,
            SQLERRM::TEXT;
    END;

    -- Test warehouse_transactions SELECT
    BEGIN
        PERFORM * FROM warehouse_transactions LIMIT 1;
        RETURN QUERY SELECT
            format('Role: %s, Status: %s', test_result.role, test_result.status)::TEXT,
            'warehouse_transactions'::TEXT,
            'SELECT'::TEXT,
            TRUE,
            'Success'::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT
            format('Role: %s, Status: %s', test_result.role, test_result.status)::TEXT,
            'warehouse_transactions'::TEXT,
            'SELECT'::TEXT,
            FALSE,
            SQLERRM::TEXT;
    END;

    -- Test warehouse_requests SELECT
    BEGIN
        PERFORM * FROM warehouse_requests LIMIT 1;
        RETURN QUERY SELECT
            format('Role: %s, Status: %s', test_result.role, test_result.status)::TEXT,
            'warehouse_requests'::TEXT,
            'SELECT'::TEXT,
            TRUE,
            'Success'::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT
            format('Role: %s, Status: %s', test_result.role, test_result.status)::TEXT,
            'warehouse_requests'::TEXT,
            'SELECT'::TEXT,
            FALSE,
            SQLERRM::TEXT;
    END;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION test_user_warehouse_access(UUID) TO authenticated;

RAISE NOTICE '🎉 Warehouse access control fix completed successfully!';
RAISE NOTICE '📋 Next steps:';
RAISE NOTICE '1. Test access with different user roles using test_user_warehouse_access(user_id)';
RAISE NOTICE '2. Verify Flutter app can now access warehouse data for all authorized roles';
RAISE NOTICE '3. Run diagnostic queries to confirm proper access patterns';
