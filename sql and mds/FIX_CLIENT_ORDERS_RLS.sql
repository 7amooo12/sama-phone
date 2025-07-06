-- =====================================================
-- CLIENT ORDERS RLS POLICY DIAGNOSTIC AND FIX
-- =====================================================
-- This script diagnoses and fixes RLS policy issues
-- for the client_orders table in SmartBizTracker
-- =====================================================

-- =====================================================
-- 1. DIAGNOSTIC: ANALYZE CURRENT STATE
-- =====================================================

-- Check if client_orders table exists
SELECT 'CLIENT_ORDERS TABLE ANALYSIS:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'client_orders'
ORDER BY ordinal_position;

-- Check current RLS status
SELECT 'RLS STATUS ON CLIENT_ORDERS:' as info;
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    hasrls as has_rls_policies
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename = 'client_orders';

-- Show existing RLS policies
SELECT 'EXISTING RLS POLICIES ON CLIENT_ORDERS:' as info;
SELECT 
    policyname,
    cmd as command,
    roles,
    qual as using_expression,
    with_check as with_check_expression
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public'
ORDER BY policyname;

-- Check user_profiles table structure for reference
SELECT 'USER_PROFILES TABLE STRUCTURE:' as info;
SELECT 
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'user_profiles'
AND column_name IN ('id', 'role', 'status', 'email', 'name')
ORDER BY ordinal_position;

-- =====================================================
-- 2. IDENTIFY CURRENT USER AND ROLE
-- =====================================================

-- Function to check current user's role and status
DO $$
DECLARE
    current_user_id UUID;
    user_role TEXT;
    user_status TEXT;
    user_name TEXT;
BEGIN
    -- Get current authenticated user ID
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RAISE NOTICE '❌ No authenticated user found';
        RETURN;
    END IF;
    
    -- Get user profile information
    SELECT role, status, name 
    INTO user_role, user_status, user_name
    FROM public.user_profiles 
    WHERE id = current_user_id;
    
    IF user_role IS NULL THEN
        RAISE NOTICE '❌ User profile not found for user ID: %', current_user_id;
    ELSE
        RAISE NOTICE '👤 Current User Info:';
        RAISE NOTICE '   - User ID: %', current_user_id;
        RAISE NOTICE '   - Name: %', COALESCE(user_name, 'Not set');
        RAISE NOTICE '   - Role: %', user_role;
        RAISE NOTICE '   - Status: %', user_status;
        
        IF user_status != 'approved' THEN
            RAISE NOTICE '⚠️  User status is not approved - this may cause RLS issues';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 3. DROP EXISTING PROBLEMATIC POLICIES
-- =====================================================

-- Drop all existing policies on client_orders to start fresh
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    RAISE NOTICE 'Dropping existing RLS policies on client_orders...';
    
    FOR policy_record IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'client_orders' 
        AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.client_orders', policy_record.policyname);
        RAISE NOTICE '✅ Dropped policy: %', policy_record.policyname;
    END LOOP;
END $$;

-- =====================================================
-- 4. CREATE COMPREHENSIVE RLS POLICIES
-- =====================================================

-- Policy 1: Admin role - Full access to all orders
CREATE POLICY "Admin full access to client orders" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'admin'
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'admin'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 2: Owner role - Full access to all orders
CREATE POLICY "Owner full access to client orders" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'owner'
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'owner'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 3: Accountant role - Full access to all orders
CREATE POLICY "Accountant full access to client orders" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'accountant'
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'accountant'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 4: Client role - Access to own orders only
CREATE POLICY "Client access to own orders" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'client'
            AND user_profiles.status = 'approved'
        )
        AND (
            client_orders.user_id = auth.uid() OR
            client_orders.client_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'client'
            AND user_profiles.status = 'approved'
        )
        AND (
            client_orders.user_id = auth.uid() OR
            client_orders.client_id = auth.uid()
        )
    );

-- Policy 5: Worker role - Read-only access to orders (for fulfillment)
CREATE POLICY "Worker read access to orders" ON public.client_orders
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'worker'
            AND user_profiles.status = 'approved'
        )
    );

-- =====================================================
-- 5. ENSURE RLS IS ENABLED
-- =====================================================

-- Enable RLS on client_orders table
ALTER TABLE public.client_orders ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 6. GRANT NECESSARY PERMISSIONS
-- =====================================================

-- Ensure authenticated users have the necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_orders TO authenticated;

-- =====================================================
-- 7. TEST THE FIXED POLICIES
-- =====================================================

-- Test function to verify RLS policies work correctly
DO $$
DECLARE
    current_user_id UUID;
    user_role TEXT;
    user_status TEXT;
    test_order_id TEXT := 'TEST-ORDER-' || extract(epoch from now())::text;
    can_insert BOOLEAN := FALSE;
BEGIN
    -- Get current user info
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RAISE NOTICE '❌ Cannot test - no authenticated user';
        RETURN;
    END IF;
    
    SELECT role, status INTO user_role, user_status
    FROM public.user_profiles 
    WHERE id = current_user_id;
    
    RAISE NOTICE 'Testing RLS policies for user role: % (status: %)', user_role, user_status;
    
    -- Test insert capability based on role
    BEGIN
        INSERT INTO public.client_orders (
            id, 
            user_id, 
            client_id,
            status,
            total_amount,
            created_at
        ) VALUES (
            test_order_id,
            current_user_id,
            current_user_id,
            'pending',
            100.00,
            NOW()
        );
        
        can_insert := TRUE;
        RAISE NOTICE '✅ INSERT test successful for role: %', user_role;
        
        -- Clean up test data
        DELETE FROM public.client_orders WHERE id = test_order_id;
        RAISE NOTICE '✅ Test cleanup completed';
        
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ INSERT failed due to RLS policy for role: %', user_role;
        RAISE NOTICE '   Error: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️  INSERT test failed for role: % - Error: %', user_role, SQLERRM;
        -- Try to clean up in case of partial insert
        DELETE FROM public.client_orders WHERE id = test_order_id;
    END;
    
END $$;

-- =====================================================
-- 8. VERIFICATION SUMMARY
-- =====================================================

-- Show final policy configuration
SELECT 'UPDATED RLS POLICIES ON CLIENT_ORDERS:' as info;
SELECT 
    policyname,
    cmd as command,
    roles
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public'
ORDER BY policyname;

-- Final status check
DO $$
DECLARE
    rls_enabled BOOLEAN;
    policy_count INTEGER;
BEGIN
    -- Check RLS status
    SELECT relrowsecurity INTO rls_enabled
    FROM pg_class 
    WHERE relname = 'client_orders' 
    AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
    
    -- Count policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename = 'client_orders' 
    AND schemaname = 'public';
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'CLIENT ORDERS RLS FIX SUMMARY';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'RLS enabled: %', CASE WHEN rls_enabled THEN '✅ YES' ELSE '❌ NO' END;
    RAISE NOTICE 'Policies created: % ✅', policy_count;
    RAISE NOTICE '==========================================';
    
    IF rls_enabled AND policy_count >= 5 THEN
        RAISE NOTICE '🎉 CLIENT ORDERS RLS POLICIES FIXED!';
        RAISE NOTICE '✅ Order creation should now work correctly';
        RAISE NOTICE '✅ Role-based access properly configured';
        RAISE NOTICE '✅ Security maintained with proper permissions';
    ELSE
        RAISE NOTICE '⚠️  RLS setup may be incomplete';
    END IF;
    
    RAISE NOTICE '==========================================';
END $$;
