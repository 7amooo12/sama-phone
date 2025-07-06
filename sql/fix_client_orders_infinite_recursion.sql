-- FIX: client_orders table infinite recursion in RLS policies
-- This addresses PostgreSQL error in client_orders table RLS policies

-- =====================================================
-- STEP 1: DROP EXISTING PROBLEMATIC POLICIES
-- =====================================================

SELECT 'Fixing client_orders infinite recursion...' as status;

-- Drop all existing client_orders policies that cause recursion
DROP POLICY IF EXISTS "Admin full access to client orders" ON public.client_orders;
DROP POLICY IF EXISTS "Owner full access to client orders" ON public.client_orders;
DROP POLICY IF EXISTS "Accountant read access to client orders" ON public.client_orders;
DROP POLICY IF EXISTS "Worker read access to orders" ON public.client_orders;
DROP POLICY IF EXISTS "Approved users fallback access" ON public.client_orders;
DROP POLICY IF EXISTS "Client access to own orders" ON public.client_orders;
DROP POLICY IF EXISTS "client_own_orders" ON public.client_orders;
DROP POLICY IF EXISTS "worker_assigned_orders" ON public.client_orders;
DROP POLICY IF EXISTS "Admin and Owner full access" ON public.client_orders;

-- Drop any other potential policies
DROP POLICY IF EXISTS "client_orders_admin_access" ON public.client_orders;
DROP POLICY IF EXISTS "client_orders_owner_access" ON public.client_orders;
DROP POLICY IF EXISTS "client_orders_worker_access" ON public.client_orders;
DROP POLICY IF EXISTS "client_orders_client_access" ON public.client_orders;

SELECT 'Dropped existing problematic client_orders RLS policies' as step_completed;

-- =====================================================
-- STEP 2: CREATE NEW SAFE RLS POLICIES
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE public.client_orders ENABLE ROW LEVEL SECURITY;

-- Policy 1: Admin - Full access to all orders
CREATE POLICY "client_orders_admin_safe" ON public.client_orders
    FOR ALL USING (
        public.user_is_admin_safe()
    ) WITH CHECK (
        public.user_is_admin_safe()
    );

-- Policy 2: Owner - Full access to all orders
CREATE POLICY "client_orders_owner_safe" ON public.client_orders
    FOR ALL USING (
        public.user_is_owner_safe()
    ) WITH CHECK (
        public.user_is_owner_safe()
    );

-- Policy 3: Accountant - Read access to all orders
CREATE POLICY "client_orders_accountant_safe" ON public.client_orders
    FOR SELECT USING (
        public.user_is_accountant_safe()
    );

-- Policy 4: Worker - Read access to assigned orders
CREATE POLICY "client_orders_worker_safe" ON public.client_orders
    FOR SELECT USING (
        public.user_is_worker_safe() AND 
        (assigned_to = auth.uid() OR assigned_to IS NULL)
    );

-- Policy 5: Client - Access to own orders only
CREATE POLICY "client_orders_client_safe" ON public.client_orders
    FOR ALL USING (
        public.user_is_client_safe() AND 
        (client_id = auth.uid() OR user_id = auth.uid())
    ) WITH CHECK (
        public.user_is_client_safe() AND 
        (client_id = auth.uid() OR user_id = auth.uid())
    );

-- Policy 6: Service role - Full access (for system operations)
CREATE POLICY "client_orders_service_role" ON public.client_orders
    FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);

SELECT 'Created new safe RLS policies for client_orders using SECURITY DEFINER functions' as step_completed;

-- =====================================================
-- STEP 3: VERIFICATION
-- =====================================================

-- Check that new policies exist
SELECT 
    'client_orders RLS policies:' as info,
    policyname,
    cmd,
    roles
FROM pg_policies 
WHERE tablename = 'client_orders'
ORDER BY policyname;

-- Test basic query (should not cause infinite recursion)
DO $$
DECLARE
    order_count integer;
BEGIN
    SELECT COUNT(*) INTO order_count FROM client_orders;
    RAISE NOTICE 'SUCCESS: client_orders query returned % orders without infinite recursion', order_count;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR in client_orders query: %', SQLERRM;
END $$;

SELECT 'client_orders infinite recursion fix completed!' as final_status;
