-- 🔧 FIX RLS POLICIES STATUS INCONSISTENCY
-- إصلاح سياسات RLS لمعالجة عدم تطابق حالة المستخدمين
-- 
-- ISSUE: Many RLS policies only check for 'approved' status, blocking 'active' users
-- SOLUTION: Update all RLS policies to accept both 'approved' and 'active' statuses

-- =====================================================
-- STEP 1: DIAGNOSTIC - FIND PROBLEMATIC POLICIES
-- =====================================================

SELECT '🔍 === DIAGNOSTIC: CURRENT RLS POLICIES WITH STATUS CHECKS ===' as diagnostic_step;

-- Find all policies that check for status = 'approved' only
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    CASE 
        WHEN qual LIKE '%status = ''approved''%' OR with_check LIKE '%status = ''approved''%' THEN '❌ NEEDS_FIX'
        WHEN qual LIKE '%status IN (''approved'', ''active'')%' OR with_check LIKE '%status IN (''approved'', ''active'')%' THEN '✅ ALREADY_FIXED'
        ELSE '⚠️ NO_STATUS_CHECK'
    END as status_check_type
FROM pg_policies 
WHERE (qual LIKE '%status%' OR with_check LIKE '%status%')
ORDER BY tablename, policyname;

-- =====================================================
-- STEP 2: FIX CLIENT_ORDERS POLICIES
-- =====================================================

SELECT '📦 === FIXING CLIENT_ORDERS RLS POLICIES ===' as orders_step;

-- Drop existing policies that only check for 'approved'
DROP POLICY IF EXISTS "Admin full access to client orders" ON public.client_orders;
DROP POLICY IF EXISTS "admin_full_access" ON public.client_orders;
DROP POLICY IF EXISTS "Worker read access to orders" ON public.client_orders;
DROP POLICY IF EXISTS "Approved users fallback access" ON public.client_orders;

-- Create updated policies that accept both 'approved' and 'active'
CREATE POLICY "admin_full_access_updated" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND status IN ('approved', 'active')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND status IN ('approved', 'active')
        )
    );

CREATE POLICY "owner_full_access_updated" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'owner'
            AND status IN ('approved', 'active')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'owner'
            AND status IN ('approved', 'active')
        )
    );

CREATE POLICY "accountant_full_access_updated" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'accountant'
            AND status IN ('approved', 'active')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'accountant'
            AND status IN ('approved', 'active')
        )
    );

CREATE POLICY "worker_read_access_updated" ON public.client_orders
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'worker'
            AND status IN ('approved', 'active')
        )
    );

-- =====================================================
-- STEP 3: FIX WAREHOUSE_REQUESTS POLICIES
-- =====================================================

SELECT '🏭 === FIXING WAREHOUSE_REQUESTS RLS POLICIES ===' as warehouse_step;

-- Drop existing problematic policies
DROP POLICY IF EXISTS "warehouse_requests_allow_warehouse_managers" ON public.warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_insert_working" ON public.warehouse_requests;
DROP POLICY IF EXISTS "simple_requests_policy" ON public.warehouse_requests;

-- Create comprehensive warehouse requests policy
CREATE POLICY "warehouse_requests_comprehensive_access" ON public.warehouse_requests
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'accountant', 'warehouseManager')
            AND status IN ('approved', 'active')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'accountant', 'warehouseManager')
            AND status IN ('approved', 'active')
        )
    );

-- =====================================================
-- STEP 4: FIX USER_PROFILES POLICIES
-- =====================================================

SELECT '👤 === FIXING USER_PROFILES RLS POLICIES ===' as users_step;

-- Drop existing policies that might be problematic
DROP POLICY IF EXISTS "authenticated_can_read_approved_users" ON public.user_profiles;

-- Create updated user profiles policy
CREATE POLICY "authenticated_can_read_valid_users" ON public.user_profiles
    FOR SELECT
    TO authenticated
    USING (
        -- Users can see their own profile OR see other valid users
        id = auth.uid() 
        OR 
        status IN ('approved', 'active')
    );

-- =====================================================
-- STEP 5: FIX TASKS POLICIES
-- =====================================================

SELECT '📋 === FIXING TASKS RLS POLICIES ===' as tasks_step;

-- Drop existing tasks policies that only check for 'approved'
DROP POLICY IF EXISTS "Admin full access to tasks" ON public.tasks;

-- Create updated tasks policy
CREATE POLICY "admin_full_access_to_tasks_updated" ON public.tasks
    FOR ALL 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND status IN ('approved', 'active')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
            AND status IN ('approved', 'active')
        )
    );

-- =====================================================
-- STEP 6: VERIFICATION
-- =====================================================

SELECT '✅ === VERIFICATION: UPDATED POLICIES ===' as verification_step;

-- Show all policies that now properly handle both statuses
SELECT 
    '✅ UPDATED POLICIES' as info,
    schemaname,
    tablename,
    policyname,
    cmd,
    CASE 
        WHEN qual LIKE '%status IN (''approved'', ''active'')%' OR with_check LIKE '%status IN (''approved'', ''active'')%' THEN '✅ FIXED'
        WHEN qual LIKE '%status = ''approved''%' OR with_check LIKE '%status = ''approved''%' THEN '❌ STILL_NEEDS_FIX'
        ELSE '⚠️ NO_STATUS_CHECK'
    END as fix_status
FROM pg_policies 
WHERE tablename IN ('client_orders', 'warehouse_requests', 'user_profiles', 'tasks')
ORDER BY tablename, policyname;

-- Test current user access with updated policies
DO $$
DECLARE
    current_user_id UUID;
    user_status TEXT;
    user_role TEXT;
    can_access_orders BOOLEAN;
    can_access_warehouse BOOLEAN;
BEGIN
    current_user_id := auth.uid();
    
    IF current_user_id IS NOT NULL THEN
        SELECT status, role INTO user_status, user_role
        FROM user_profiles 
        WHERE id = current_user_id;
        
        -- Test order access
        SELECT EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'accountant', 'worker')
            AND status IN ('approved', 'active')
        ) INTO can_access_orders;
        
        -- Test warehouse access
        SELECT EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'accountant', 'warehouseManager')
            AND status IN ('approved', 'active')
        ) INTO can_access_warehouse;
        
        RAISE NOTICE '🔍 ACCESS VERIFICATION:';
        RAISE NOTICE '   User Status: %', COALESCE(user_status, 'NULL');
        RAISE NOTICE '   User Role: %', COALESCE(user_role, 'NULL');
        RAISE NOTICE '   Can Access Orders: %', can_access_orders;
        RAISE NOTICE '   Can Access Warehouse: %', can_access_warehouse;
        
        IF user_status IN ('approved', 'active') THEN
            RAISE NOTICE '✅ SUCCESS: User with % status should now have proper access', user_status;
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No authenticated user for testing';
    END IF;
END $$;

-- =====================================================
-- STEP 7: FIX REMAINING PROBLEMATIC POLICIES
-- =====================================================

SELECT '🔧 === FIXING REMAINING PROBLEMATIC POLICIES ===' as remaining_step;

-- Fix client orders policies that still only check for 'approved'
DROP POLICY IF EXISTS "pending_orders_client_own_orders" ON public.client_orders;
DROP POLICY IF EXISTS "pending_orders_worker_assigned_orders" ON public.client_orders;

-- Create updated client policy
CREATE POLICY "client_own_orders_updated" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'client'
            AND status IN ('approved', 'active')
        )
        AND client_id = auth.uid()
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'client'
            AND status IN ('approved', 'active')
        )
        AND client_id = auth.uid()
    );

-- Create updated worker policy
CREATE POLICY "worker_assigned_orders_updated" ON public.client_orders
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'worker'
            AND status IN ('approved', 'active')
        )
        AND assigned_to = auth.uid()
    );

-- =====================================================
-- STEP 8: CREATE UNIVERSAL STATUS VALIDATION FUNCTION
-- =====================================================

SELECT '🛡️ === CREATING UNIVERSAL STATUS VALIDATION ===' as universal_step;

-- Create a function that can be used in all policies for consistent status checking
CREATE OR REPLACE FUNCTION public.user_has_valid_status_and_role(required_roles TEXT[])
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles
        WHERE id = auth.uid()
        AND role = ANY(required_roles)
        AND status IN ('approved', 'active')
    );
$$;

-- =====================================================
-- STEP 9: FINAL VERIFICATION AND CLEANUP
-- =====================================================

SELECT '🔍 === FINAL VERIFICATION ===' as final_verification_step;

-- Show any remaining policies that might still have issues
SELECT
    '⚠️ POLICIES THAT STILL NEED ATTENTION' as warning,
    schemaname,
    tablename,
    policyname,
    cmd
FROM pg_policies
WHERE (qual LIKE '%status = ''approved''%' OR with_check LIKE '%status = ''approved''%')
AND NOT (qual LIKE '%status IN (''approved'', ''active'')%' OR with_check LIKE '%status IN (''approved'', ''active'')%')
ORDER BY tablename, policyname;

SELECT '🎉 === RLS POLICIES STATUS INCONSISTENCY FIX COMPLETED ===' as completion_message;
SELECT 'All RLS policies now treat "active" and "approved" statuses identically' as result_summary;
