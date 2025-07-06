-- =====================================================
-- DIAGNOSE CLIENT ORDERS RLS ISSUE
-- =====================================================
-- Run this first to understand the current problem
-- =====================================================

-- =====================================================
-- 1. CHECK CURRENT USER AUTHENTICATION
-- =====================================================

DO $$
DECLARE
    current_user_id UUID;
    user_exists BOOLEAN;
    user_role TEXT;
    user_status TEXT;
    user_email TEXT;
    user_name TEXT;
BEGIN
    RAISE NOTICE '=== CURRENT USER DIAGNOSIS ===';
    
    -- Check if user is authenticated
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RAISE NOTICE '❌ CRITICAL: No authenticated user (auth.uid() returns NULL)';
        RAISE NOTICE '   This means the user is not logged in or session expired';
        RETURN;
    ELSE
        RAISE NOTICE '✅ Authenticated user ID: %', current_user_id;
    END IF;
    
    -- Check if user exists in auth.users
    SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = current_user_id) INTO user_exists;
    
    IF NOT user_exists THEN
        RAISE NOTICE '❌ CRITICAL: User not found in auth.users table';
        RETURN;
    ELSE
        RAISE NOTICE '✅ User exists in auth.users table';
    END IF;
    
    -- Check user profile
    SELECT role, status, email, name 
    INTO user_role, user_status, user_email, user_name
    FROM public.user_profiles 
    WHERE id = current_user_id;
    
    IF user_role IS NULL THEN
        RAISE NOTICE '❌ CRITICAL: User profile not found in user_profiles table';
        RAISE NOTICE '   User ID % has no profile record', current_user_id;
    ELSE
        RAISE NOTICE '✅ User profile found:';
        RAISE NOTICE '   - Name: %', COALESCE(user_name, 'NULL');
        RAISE NOTICE '   - Email: %', COALESCE(user_email, 'NULL');
        RAISE NOTICE '   - Role: %', COALESCE(user_role, 'NULL');
        RAISE NOTICE '   - Status: %', COALESCE(user_status, 'NULL');
        
        -- Check for common issues
        IF user_status != 'approved' THEN
            RAISE NOTICE '⚠️  WARNING: User status is "%" (not "approved")', user_status;
            RAISE NOTICE '   This will cause RLS policy failures';
        END IF;
        
        IF user_role NOT IN ('admin', 'owner', 'accountant', 'client', 'worker') THEN
            RAISE NOTICE '⚠️  WARNING: Invalid user role "%"', user_role;
        END IF;
    END IF;
END $$;

-- =====================================================
-- 2. ANALYZE CLIENT_ORDERS TABLE STRUCTURE
-- =====================================================

RAISE NOTICE '=== CLIENT_ORDERS TABLE ANALYSIS ===';

-- Check if table exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'client_orders') THEN
        RAISE NOTICE '❌ CRITICAL: client_orders table does not exist!';
        RETURN;
    ELSE
        RAISE NOTICE '✅ client_orders table exists';
    END IF;
END $$;

-- Show table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'client_orders'
ORDER BY ordinal_position;

-- =====================================================
-- 3. CHECK RLS STATUS AND POLICIES
-- =====================================================

-- Check RLS status
SELECT 
    'RLS STATUS:' as info,
    CASE WHEN relrowsecurity THEN 'ENABLED' ELSE 'DISABLED' END as rls_status
FROM pg_class 
WHERE relname = 'client_orders' 
AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Show all current policies
SELECT 
    'CURRENT POLICIES:' as info,
    policyname,
    cmd as command,
    roles,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public'
ORDER BY policyname;

-- =====================================================
-- 4. TEST POLICY EVALUATION
-- =====================================================

-- Test if current user can theoretically insert
DO $$
DECLARE
    current_user_id UUID;
    user_role TEXT;
    user_status TEXT;
    policy_check_admin BOOLEAN := FALSE;
    policy_check_owner BOOLEAN := FALSE;
    policy_check_accountant BOOLEAN := FALSE;
    policy_check_client BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE '=== POLICY EVALUATION TEST ===';
    
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RAISE NOTICE '❌ Cannot test policies - no authenticated user';
        RETURN;
    END IF;
    
    SELECT role, status INTO user_role, user_status
    FROM public.user_profiles 
    WHERE id = current_user_id;
    
    -- Test admin policy condition
    SELECT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role = 'admin'
        AND user_profiles.status = 'approved'
    ) INTO policy_check_admin;
    
    -- Test owner policy condition
    SELECT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role = 'owner'
        AND user_profiles.status = 'approved'
    ) INTO policy_check_owner;
    
    -- Test accountant policy condition
    SELECT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role = 'accountant'
        AND user_profiles.status = 'approved'
    ) INTO policy_check_accountant;
    
    -- Test client policy condition
    SELECT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role = 'client'
        AND user_profiles.status = 'approved'
    ) INTO policy_check_client;
    
    RAISE NOTICE 'Policy evaluation for user role "%" (status "%"):', user_role, user_status;
    RAISE NOTICE '   - Admin policy match: %', policy_check_admin;
    RAISE NOTICE '   - Owner policy match: %', policy_check_owner;
    RAISE NOTICE '   - Accountant policy match: %', policy_check_accountant;
    RAISE NOTICE '   - Client policy match: %', policy_check_client;
    
    IF NOT (policy_check_admin OR policy_check_owner OR policy_check_accountant OR policy_check_client) THEN
        RAISE NOTICE '❌ PROBLEM FOUND: User does not match any RLS policy conditions!';
        RAISE NOTICE '   This explains why order creation is failing';
        
        -- Provide specific guidance
        IF user_status != 'approved' THEN
            RAISE NOTICE '💡 SOLUTION: User status needs to be "approved"';
        ELSIF user_role NOT IN ('admin', 'owner', 'accountant', 'client') THEN
            RAISE NOTICE '💡 SOLUTION: User role needs to be one of: admin, owner, accountant, client';
        ELSE
            RAISE NOTICE '💡 SOLUTION: Check RLS policy definitions - they may be incorrect';
        END IF;
    ELSE
        RAISE NOTICE '✅ User matches at least one RLS policy condition';
    END IF;
END $$;

-- =====================================================
-- 5. CHECK TABLE PERMISSIONS
-- =====================================================

-- Check table permissions for authenticated role
SELECT 
    'TABLE PERMISSIONS:' as info,
    privilege_type,
    is_grantable
FROM information_schema.table_privileges 
WHERE table_schema = 'public' 
AND table_name = 'client_orders'
AND grantee = 'authenticated'
ORDER BY privilege_type;

-- =====================================================
-- 6. SIMULATE THE EXACT INSERT THAT'S FAILING
-- =====================================================

-- Try to identify what specific insert is failing
DO $$
DECLARE
    current_user_id UUID;
    test_order_id TEXT;
BEGIN
    RAISE NOTICE '=== SIMULATING ORDER INSERT ===';
    
    current_user_id := auth.uid();
    test_order_id := 'DIAGNOSTIC-TEST-' || extract(epoch from now())::text;
    
    IF current_user_id IS NULL THEN
        RAISE NOTICE '❌ Cannot simulate - no authenticated user';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Attempting to insert test order with user_id: %', current_user_id;
    
    BEGIN
        -- Try a minimal insert that matches typical order creation
        INSERT INTO public.client_orders (
            id,
            user_id,
            status,
            total_amount,
            created_at
        ) VALUES (
            test_order_id,
            current_user_id,
            'pending',
            100.00,
            NOW()
        );
        
        RAISE NOTICE '✅ SUCCESS: Test order insert worked!';
        RAISE NOTICE '   The RLS policies are working correctly';
        
        -- Clean up
        DELETE FROM public.client_orders WHERE id = test_order_id;
        RAISE NOTICE '✅ Test cleanup completed';
        
    EXCEPTION 
        WHEN insufficient_privilege THEN
            RAISE NOTICE '❌ CONFIRMED: RLS policy violation';
            RAISE NOTICE '   Error: %', SQLERRM;
            RAISE NOTICE '   This confirms the RLS policies need to be fixed';
        WHEN OTHERS THEN
            RAISE NOTICE '⚠️  Other error occurred: %', SQLERRM;
            RAISE NOTICE '   Error code: %', SQLSTATE;
    END;
END $$;

-- =====================================================
-- 7. PROVIDE DIAGNOSIS SUMMARY
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'DIAGNOSIS COMPLETE';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Review the output above to identify the issue';
    RAISE NOTICE '2. If RLS policies are the problem, run FIX_CLIENT_ORDERS_RLS.sql';
    RAISE NOTICE '3. If user status/role is the issue, update user_profiles table';
    RAISE NOTICE '4. If table permissions are missing, grant them to authenticated role';
    RAISE NOTICE '==========================================';
END $$;
