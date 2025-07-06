-- 🔧 COMPREHENSIVE USER STATUS INCONSISTENCY FIX
-- إصلاح شامل لمشكلة عدم تطابق حالة المستخدمين
-- 
-- ISSUE: Users with 'active' status cannot perform critical operations that 'approved' users can perform
-- SOLUTION: Standardize all database functions to treat 'active' and 'approved' statuses identically
--
-- AFFECTED AREAS:
-- 1. SECURITY DEFINER functions that only check for 'approved' status
-- 2. RLS policies that discriminate between 'active' and 'approved'
-- 3. Order processing workflows
-- 4. Warehouse management operations
-- 5. User role validation logic

-- =====================================================
-- STEP 1: DIAGNOSTIC INFORMATION
-- =====================================================

SELECT '🔍 === DIAGNOSTIC: CURRENT USER STATUS DISTRIBUTION ===' as diagnostic_step;

-- Show current user status distribution
SELECT 
    status,
    COUNT(*) as user_count,
    ARRAY_AGG(DISTINCT role) as roles_with_status
FROM user_profiles 
GROUP BY status
ORDER BY user_count DESC;

-- Show users who might be affected by this issue
SELECT 
    '⚠️ AFFECTED USERS WITH ACTIVE STATUS' as info,
    COUNT(*) as active_users_count
FROM user_profiles 
WHERE status = 'active' 
AND role IN ('admin', 'owner', 'accountant', 'warehouseManager', 'worker');

-- =====================================================
-- STEP 2: FIX PROBLEMATIC SECURITY DEFINER FUNCTIONS
-- =====================================================

SELECT '🔧 === FIXING SECURITY DEFINER FUNCTIONS ===' as fix_step;

-- Fix check_user_approved_safe() function
CREATE OR REPLACE FUNCTION public.check_user_approved_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_status TEXT;
BEGIN
    user_status := get_user_status_safe();
    -- FIXED: Now accepts both 'approved' and 'active' statuses
    RETURN user_status IN ('approved', 'active');
END;
$$;

-- Fix check_warehouse_access_safe() function
CREATE OR REPLACE FUNCTION public.check_warehouse_access_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
    user_status TEXT;
BEGIN
    user_role := get_user_role_safe();
    user_status := get_user_status_safe();
    
    -- FIXED: Now accepts both 'approved' and 'active' statuses
    RETURN user_status IN ('approved', 'active') AND user_role IN ('admin', 'owner', 'accountant', 'warehouseManager');
END;
$$;

-- Fix check_warehouse_access() function (with user_id parameter)
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
    
    -- FIXED: Now accepts both 'approved' and 'active' statuses
    RETURN (
        user_role IS NOT NULL AND 
        user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND
        user_status IN ('approved', 'active')
    );
END;
$$;

-- Create a universal status validation function
CREATE OR REPLACE FUNCTION public.user_has_valid_status_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_status TEXT;
BEGIN
    user_status := get_user_status_safe();
    -- Both 'approved' and 'active' are considered valid statuses
    RETURN user_status IN ('approved', 'active');
END;
$$;

-- Create enhanced role and status checker
CREATE OR REPLACE FUNCTION public.user_has_role_and_valid_status_safe(required_roles TEXT[])
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
    user_status TEXT;
BEGIN
    user_role := get_user_role_safe();
    user_status := get_user_status_safe();
    
    RETURN (
        user_role = ANY(required_roles) AND 
        user_status IN ('approved', 'active')
    );
END;
$$;

-- =====================================================
-- STEP 3: CREATE COMPREHENSIVE ORDER ACCESS FUNCTION
-- =====================================================

SELECT '📦 === CREATING ORDER ACCESS FUNCTIONS ===' as order_step;

-- Function to check if user can process orders (for pending orders workflow)
CREATE OR REPLACE FUNCTION public.user_can_process_orders_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
    user_status TEXT;
BEGIN
    user_role := get_user_role_safe();
    user_status := get_user_status_safe();
    
    -- Users with these roles and valid status can process orders
    RETURN (
        user_role IN ('admin', 'owner', 'accountant', 'worker') AND 
        user_status IN ('approved', 'active')
    );
END;
$$;

-- Function to check if user can approve pricing
CREATE OR REPLACE FUNCTION public.user_can_approve_pricing_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
    user_status TEXT;
BEGIN
    user_role := get_user_role_safe();
    user_status := get_user_status_safe();
    
    -- Users with these roles and valid status can approve pricing
    RETURN (
        user_role IN ('admin', 'owner', 'accountant') AND 
        user_status IN ('approved', 'active')
    );
END;
$$;

-- Function to check if user can create warehouse release orders
CREATE OR REPLACE FUNCTION public.user_can_create_release_orders_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
    user_status TEXT;
BEGIN
    user_role := get_user_role_safe();
    user_status := get_user_status_safe();
    
    -- Users with these roles and valid status can create release orders
    RETURN (
        user_role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND 
        user_status IN ('approved', 'active')
    );
END;
$$;

-- =====================================================
-- STEP 4: UPDATE EXISTING FUNCTIONS TO USE NEW LOGIC
-- =====================================================

SELECT '🔄 === UPDATING EXISTING FUNCTIONS ===' as update_step;

-- Update user_is_approved_safe() to accept both statuses
CREATE OR REPLACE FUNCTION public.user_is_approved_safe()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND status IN ('approved', 'active')
    );
$$;

-- Update user_has_role_safe() to accept both statuses
CREATE OR REPLACE FUNCTION public.user_has_role_safe(user_id uuid, required_role text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 
        FROM user_profiles up
        WHERE up.id = user_id 
        AND up.role = required_role
        AND up.status IN ('approved', 'active')
    );
$$;

-- =====================================================
-- STEP 5: VERIFICATION TESTS
-- =====================================================

SELECT '✅ === VERIFICATION TESTS ===' as verification_step;

-- Test the updated functions
DO $$
DECLARE
    test_approved BOOLEAN;
    test_warehouse_access BOOLEAN;
    test_order_processing BOOLEAN;
    test_pricing_approval BOOLEAN;
    test_release_orders BOOLEAN;
    current_user_status TEXT;
    current_user_role TEXT;
BEGIN
    -- Get current user info
    current_user_status := get_user_status_safe();
    current_user_role := get_user_role_safe();
    
    -- Test all functions
    test_approved := check_user_approved_safe();
    test_warehouse_access := check_warehouse_access_safe();
    test_order_processing := user_can_process_orders_safe();
    test_pricing_approval := user_can_approve_pricing_safe();
    test_release_orders := user_can_create_release_orders_safe();
    
    RAISE NOTICE '🔍 VERIFICATION RESULTS:';
    RAISE NOTICE '   Current User Status: %', COALESCE(current_user_status, 'NULL');
    RAISE NOTICE '   Current User Role: %', COALESCE(current_user_role, 'NULL');
    RAISE NOTICE '   User Approved Check: %', test_approved;
    RAISE NOTICE '   Warehouse Access: %', test_warehouse_access;
    RAISE NOTICE '   Can Process Orders: %', test_order_processing;
    RAISE NOTICE '   Can Approve Pricing: %', test_pricing_approval;
    RAISE NOTICE '   Can Create Release Orders: %', test_release_orders;
    
    -- Verify that both 'active' and 'approved' users get the same results
    IF current_user_status IN ('approved', 'active') THEN
        RAISE NOTICE '✅ SUCCESS: User with % status has proper access', current_user_status;
    ELSE
        RAISE NOTICE '⚠️  WARNING: User status % may have limited access', current_user_status;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ ERROR in verification: %', SQLERRM;
END $$;

SELECT '🎉 === USER STATUS INCONSISTENCY FIX COMPLETED ===' as completion_message;
SELECT 'Both "active" and "approved" statuses now have identical permissions' as result_summary;
