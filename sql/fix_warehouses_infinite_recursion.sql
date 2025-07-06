-- FIX: warehouses and related tables infinite recursion in RLS policies
-- This addresses PostgreSQL error in warehouse tables RLS policies

-- =====================================================
-- STEP 1: DROP EXISTING PROBLEMATIC POLICIES
-- =====================================================

SELECT 'Fixing warehouses infinite recursion...' as status;

-- Drop all existing warehouse policies that cause recursion
DROP POLICY IF EXISTS "warehouse_select_policy" ON public.warehouses;
DROP POLICY IF EXISTS "warehouse_insert_policy" ON public.warehouses;
DROP POLICY IF EXISTS "warehouse_update_policy" ON public.warehouses;
DROP POLICY IF EXISTS "warehouse_delete_policy" ON public.warehouses;
DROP POLICY IF EXISTS "secure_warehouses_select" ON public.warehouses;
DROP POLICY IF EXISTS "warehouse_managers_can_read_warehouses" ON public.warehouses;
DROP POLICY IF EXISTS "warehouse_managers_can_manage_assigned_warehouses" ON public.warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للإنشاء من قبل المديرين" ON public.warehouses;

-- Drop warehouse_inventory policies
DROP POLICY IF EXISTS "warehouse_inventory_select_policy" ON public.warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_insert_policy" ON public.warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_update_policy" ON public.warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_delete_policy" ON public.warehouse_inventory;

-- Drop warehouse_requests policies
DROP POLICY IF EXISTS "warehouse_requests_select_policy" ON public.warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_policy" ON public.warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_update_policy" ON public.warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_delete_policy" ON public.warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_allow_warehouse_managers" ON public.warehouse_requests;

-- Drop warehouse_transactions policies
DROP POLICY IF EXISTS "warehouse_transactions_select_policy" ON public.warehouse_transactions;
DROP POLICY IF EXISTS "warehouse_transactions_insert_policy" ON public.warehouse_transactions;
DROP POLICY IF EXISTS "warehouse_transactions_update_policy" ON public.warehouse_transactions;
DROP POLICY IF EXISTS "warehouse_transactions_delete_policy" ON public.warehouse_transactions;

SELECT 'Dropped existing problematic warehouse RLS policies' as step_completed;

-- =====================================================
-- STEP 2: CREATE NEW SAFE RLS POLICIES FOR WAREHOUSES
-- =====================================================

-- Ensure RLS is enabled on all warehouse tables
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;

-- Warehouses table policies
CREATE POLICY "warehouses_select_safe" ON public.warehouses
    FOR SELECT USING (
        public.user_has_warehouse_access_safe()
    );

CREATE POLICY "warehouses_insert_safe" ON public.warehouses
    FOR INSERT WITH CHECK (
        public.user_is_admin_or_owner_safe() OR public.user_is_accountant_safe()
    );

CREATE POLICY "warehouses_update_safe" ON public.warehouses
    FOR UPDATE USING (
        public.user_has_warehouse_access_safe()
    ) WITH CHECK (
        public.user_has_warehouse_access_safe()
    );

CREATE POLICY "warehouses_delete_safe" ON public.warehouses
    FOR DELETE USING (
        public.user_is_admin_or_owner_safe()
    );

-- Service role access
CREATE POLICY "warehouses_service_role" ON public.warehouses
    FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);

SELECT 'Created safe RLS policies for warehouses table' as step_completed;

-- =====================================================
-- STEP 3: CREATE SAFE POLICIES FOR WAREHOUSE_INVENTORY
-- =====================================================

-- Check if warehouse_inventory table exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_inventory') THEN
        -- Enable RLS
        ALTER TABLE public.warehouse_inventory ENABLE ROW LEVEL SECURITY;
        
        -- Create safe policies
        CREATE POLICY "warehouse_inventory_select_safe" ON public.warehouse_inventory
            FOR SELECT USING (
                public.user_has_warehouse_access_safe()
            );

        CREATE POLICY "warehouse_inventory_insert_safe" ON public.warehouse_inventory
            FOR INSERT WITH CHECK (
                public.user_has_warehouse_access_safe()
            );

        CREATE POLICY "warehouse_inventory_update_safe" ON public.warehouse_inventory
            FOR UPDATE USING (
                public.user_has_warehouse_access_safe()
            ) WITH CHECK (
                public.user_has_warehouse_access_safe()
            );

        CREATE POLICY "warehouse_inventory_delete_safe" ON public.warehouse_inventory
            FOR DELETE USING (
                public.user_is_admin_or_owner_safe()
            );

        CREATE POLICY "warehouse_inventory_service_role" ON public.warehouse_inventory
            FOR ALL TO service_role
            USING (true)
            WITH CHECK (true);
            
        RAISE NOTICE 'Created safe RLS policies for warehouse_inventory table';
    ELSE
        RAISE NOTICE 'warehouse_inventory table does not exist, skipping';
    END IF;
END $$;

-- =====================================================
-- STEP 4: CREATE SAFE POLICIES FOR WAREHOUSE_REQUESTS
-- =====================================================

-- Check if warehouse_requests table exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_requests') THEN
        -- Enable RLS
        ALTER TABLE public.warehouse_requests ENABLE ROW LEVEL SECURITY;
        
        -- Create safe policies
        CREATE POLICY "warehouse_requests_select_safe" ON public.warehouse_requests
            FOR SELECT USING (
                public.user_has_warehouse_access_safe()
            );

        CREATE POLICY "warehouse_requests_insert_safe" ON public.warehouse_requests
            FOR INSERT WITH CHECK (
                public.user_has_warehouse_access_safe()
            );

        CREATE POLICY "warehouse_requests_update_safe" ON public.warehouse_requests
            FOR UPDATE USING (
                public.user_has_warehouse_access_safe()
            ) WITH CHECK (
                public.user_has_warehouse_access_safe()
            );

        CREATE POLICY "warehouse_requests_delete_safe" ON public.warehouse_requests
            FOR DELETE USING (
                public.user_is_admin_or_owner_safe()
            );

        CREATE POLICY "warehouse_requests_service_role" ON public.warehouse_requests
            FOR ALL TO service_role
            USING (true)
            WITH CHECK (true);
            
        RAISE NOTICE 'Created safe RLS policies for warehouse_requests table';
    ELSE
        RAISE NOTICE 'warehouse_requests table does not exist, skipping';
    END IF;
END $$;

-- =====================================================
-- STEP 5: CREATE SAFE POLICIES FOR WAREHOUSE_TRANSACTIONS
-- =====================================================

-- Check if warehouse_transactions table exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_transactions') THEN
        -- Enable RLS
        ALTER TABLE public.warehouse_transactions ENABLE ROW LEVEL SECURITY;
        
        -- Create safe policies
        CREATE POLICY "warehouse_transactions_select_safe" ON public.warehouse_transactions
            FOR SELECT USING (
                public.user_has_warehouse_access_safe()
            );

        CREATE POLICY "warehouse_transactions_insert_safe" ON public.warehouse_transactions
            FOR INSERT WITH CHECK (
                public.user_has_warehouse_access_safe()
            );

        CREATE POLICY "warehouse_transactions_update_safe" ON public.warehouse_transactions
            FOR UPDATE USING (
                public.user_has_warehouse_access_safe()
            ) WITH CHECK (
                public.user_has_warehouse_access_safe()
            );

        -- Note: Accountants should not delete transactions for audit integrity
        CREATE POLICY "warehouse_transactions_delete_safe" ON public.warehouse_transactions
            FOR DELETE USING (
                public.user_is_admin_or_owner_safe()
            );

        CREATE POLICY "warehouse_transactions_service_role" ON public.warehouse_transactions
            FOR ALL TO service_role
            USING (true)
            WITH CHECK (true);
            
        RAISE NOTICE 'Created safe RLS policies for warehouse_transactions table';
    ELSE
        RAISE NOTICE 'warehouse_transactions table does not exist, skipping';
    END IF;
END $$;

-- =====================================================
-- STEP 6: VERIFICATION
-- =====================================================

-- Check that new policies exist
SELECT 
    'Warehouse tables RLS policies:' as info,
    tablename,
    policyname,
    cmd
FROM pg_policies 
WHERE tablename LIKE 'warehouse%'
ORDER BY tablename, policyname;

-- Test basic queries (should not cause infinite recursion)
DO $$
DECLARE
    warehouse_count integer;
BEGIN
    SELECT COUNT(*) INTO warehouse_count FROM warehouses;
    RAISE NOTICE 'SUCCESS: warehouses query returned % warehouses without infinite recursion', warehouse_count;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR in warehouses query: %', SQLERRM;
END $$;

SELECT 'Warehouses infinite recursion fix completed!' as final_status;
