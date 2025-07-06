-- 🚨 IMMEDIATE WAREHOUSE ACCESS FIX
-- Quick resolution for warehouse data access issues across all authorized roles

-- ==================== STEP 1: CURRENT STATUS CHECK ====================

-- Show current RLS status
SELECT 
  '🔒 CURRENT RLS STATUS' as info,
  tablename,
  rowsecurity as rls_enabled,
  CASE WHEN rowsecurity THEN 'ENABLED' ELSE 'DISABLED' END as status
FROM pg_tables 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests')
  AND schemaname = 'public';

-- Show current policies
SELECT 
  '📜 CURRENT POLICIES' as info,
  tablename,
  policyname,
  cmd as operation,
  roles
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests')
ORDER BY tablename, cmd;

-- Show user profiles for context
SELECT 
  '👥 USER PROFILES' as info,
  id,
  email,
  role,
  status,
  CASE 
    WHEN role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND status = 'approved' 
    THEN 'SHOULD_HAVE_ACCESS'
    ELSE 'NO_ACCESS'
  END as expected_access
FROM user_profiles 
ORDER BY role;

-- ==================== STEP 2: EMERGENCY ACCESS RESTORATION ====================

-- Temporarily disable RLS to restore immediate access
ALTER TABLE warehouses DISABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_requests DISABLE ROW LEVEL SECURITY;

-- Check if warehouse_request_items exists and disable RLS
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_request_items') THEN
        ALTER TABLE warehouse_request_items DISABLE ROW LEVEL SECURITY;
        RAISE NOTICE '✅ RLS disabled on warehouse_request_items';
    END IF;
END $$;

-- ==================== STEP 3: VERIFY IMMEDIATE ACCESS ====================

-- Test basic access to all warehouse tables
SELECT 
  '✅ WAREHOUSES ACCESS TEST' as test,
  COUNT(*) as record_count,
  'RLS DISABLED - FULL ACCESS' as status
FROM warehouses;

SELECT 
  '✅ INVENTORY ACCESS TEST' as test,
  COUNT(*) as record_count,
  'RLS DISABLED - FULL ACCESS' as status
FROM warehouse_inventory;

SELECT 
  '✅ TRANSACTIONS ACCESS TEST' as test,
  COUNT(*) as record_count,
  'RLS DISABLED - FULL ACCESS' as status
FROM warehouse_transactions;

SELECT 
  '✅ REQUESTS ACCESS TEST' as test,
  COUNT(*) as record_count,
  'RLS DISABLED - FULL ACCESS' as status
FROM warehouse_requests;

-- ==================== STEP 4: CREATE PROPER SECURITY DEFINER FUNCTION ====================

-- First, drop the function if it exists to avoid conflicts
DROP FUNCTION IF EXISTS public.has_warehouse_access(UUID);
DROP FUNCTION IF EXISTS public.has_warehouse_access();

-- Create function to check warehouse access without RLS recursion
CREATE OR REPLACE FUNCTION public.has_warehouse_access(user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
    user_status TEXT;
BEGIN
    -- Handle null user_id
    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Get user role and status directly (bypasses RLS)
    SELECT role, status INTO user_role, user_status
    FROM user_profiles
    WHERE id = user_id;

    -- Return true if user has warehouse access
    RETURN (
        user_role IS NOT NULL AND
        user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND
        user_status = 'approved'
    );
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and deny access
        RAISE WARNING 'Error in has_warehouse_access for user %: %', user_id, SQLERRM;
        RETURN FALSE;
END;
$$;

-- Verify function was created
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'has_warehouse_access') THEN
        RAISE NOTICE '✅ Function has_warehouse_access created successfully';
    ELSE
        RAISE EXCEPTION '❌ Failed to create has_warehouse_access function';
    END IF;
END $$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.has_warehouse_access(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_warehouse_access() TO authenticated;

-- Test the function
SELECT
  '🧪 FUNCTION TEST' as test,
  public.has_warehouse_access() as current_user_access,
  'Function is working if this query succeeds' as status;

-- ==================== STEP 5: RE-ENABLE RLS WITH PROPER POLICIES ====================

-- Re-enable RLS
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_requests ENABLE ROW LEVEL SECURITY;

-- Re-enable RLS on warehouse_request_items if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_request_items') THEN
        ALTER TABLE warehouse_request_items ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE '✅ RLS re-enabled on warehouse_request_items';
    END IF;
END $$;

-- ==================== STEP 6: CREATE COMPREHENSIVE POLICIES ====================

-- WAREHOUSES TABLE POLICIES
CREATE POLICY "warehouses_access_policy" ON warehouses
    FOR ALL
    USING (public.has_warehouse_access())
    WITH CHECK (public.has_warehouse_access());

-- WAREHOUSE INVENTORY POLICIES
CREATE POLICY "inventory_access_policy" ON warehouse_inventory
    FOR ALL
    USING (public.has_warehouse_access())
    WITH CHECK (public.has_warehouse_access());

-- WAREHOUSE TRANSACTIONS POLICIES
-- SELECT, INSERT, UPDATE for all authorized roles
CREATE POLICY "transactions_read_write_policy" ON warehouse_transactions
    FOR SELECT
    USING (public.has_warehouse_access());

CREATE POLICY "transactions_insert_policy" ON warehouse_transactions
    FOR INSERT
    WITH CHECK (public.has_warehouse_access());

CREATE POLICY "transactions_update_policy" ON warehouse_transactions
    FOR UPDATE
    USING (public.has_warehouse_access());

-- DELETE only for admin (audit integrity)
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

-- WAREHOUSE REQUESTS POLICIES
CREATE POLICY "requests_access_policy" ON warehouse_requests
    FOR ALL
    USING (public.has_warehouse_access())
    WITH CHECK (public.has_warehouse_access());

-- WAREHOUSE REQUEST ITEMS POLICIES (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_request_items') THEN
        EXECUTE 'CREATE POLICY "request_items_access_policy" ON warehouse_request_items
            FOR ALL
            USING (public.has_warehouse_access())
            WITH CHECK (public.has_warehouse_access())';
        RAISE NOTICE '✅ Policies created for warehouse_request_items';
    END IF;
END $$;

-- ==================== STEP 7: FINAL VERIFICATION ====================

-- Test access with new policies
SELECT 
  '🎉 FINAL ACCESS VERIFICATION' as test,
  'warehouses' as table_name,
  COUNT(*) as accessible_records
FROM warehouses
UNION ALL
SELECT 
  '🎉 FINAL ACCESS VERIFICATION' as test,
  'warehouse_inventory' as table_name,
  COUNT(*) as accessible_records
FROM warehouse_inventory
UNION ALL
SELECT 
  '🎉 FINAL ACCESS VERIFICATION' as test,
  'warehouse_transactions' as table_name,
  COUNT(*) as accessible_records
FROM warehouse_transactions
UNION ALL
SELECT 
  '🎉 FINAL ACCESS VERIFICATION' as test,
  'warehouse_requests' as table_name,
  COUNT(*) as accessible_records
FROM warehouse_requests;

-- Show final policy status
SELECT 
  '✅ FINAL POLICY STATUS' as info,
  tablename,
  policyname,
  cmd as operation
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests', 'warehouse_request_items')
ORDER BY tablename, cmd;

-- Success message
SELECT 
  '🎉 SUCCESS' as status,
  'Warehouse access control has been fixed' as message,
  'All authorized roles (admin, owner, accountant, warehouseManager) should now have proper access' as details;
