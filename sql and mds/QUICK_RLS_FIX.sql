-- =====================================================
-- QUICK RLS FIX FOR CLIENT ORDERS - SUPABASE COMPATIBLE
-- =====================================================
-- This script provides immediate fixes for common RLS issues
-- Compatible with Supabase SQL Editor
-- =====================================================

-- =====================================================
-- OPTION 1: TEMPORARY DISABLE RLS (EMERGENCY FIX)
-- =====================================================
-- Uncomment the line below ONLY if you need immediate access
-- and will fix RLS policies properly later
-- ALTER TABLE public.client_orders DISABLE ROW LEVEL SECURITY;

-- =====================================================
-- OPTION 2: CREATE PERMISSIVE POLICIES (RECOMMENDED)
-- =====================================================

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Enable read access for all users" ON public.client_orders;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.client_orders;
DROP POLICY IF EXISTS "Enable update for users based on email" ON public.client_orders;
DROP POLICY IF EXISTS "Enable delete for users based on email" ON public.client_orders;
DROP POLICY IF EXISTS "Users can view their own orders" ON public.client_orders;
DROP POLICY IF EXISTS "Users can create their own orders" ON public.client_orders;
DROP POLICY IF EXISTS "Users can update their own orders" ON public.client_orders;
DROP POLICY IF EXISTS "Users can delete their own orders" ON public.client_orders;

-- Ensure RLS is enabled
ALTER TABLE public.client_orders ENABLE ROW LEVEL SECURITY;

-- Create comprehensive policies that work with SmartBizTracker roles

-- Policy 1: Admin and Owner - Full access
CREATE POLICY "Admin and Owner full access" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'owner')
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'owner')
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 2: Accountant - Full access for order management
CREATE POLICY "Accountant full access" ON public.client_orders
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

-- Policy 3: Client - Access to own orders
CREATE POLICY "Client own orders access" ON public.client_orders
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
            client_orders.client_id = auth.uid() OR
            client_orders.customer_id = auth.uid()
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
            client_orders.client_id = auth.uid() OR
            client_orders.customer_id = auth.uid()
        )
    );

-- Policy 4: Worker - Read access for order fulfillment
CREATE POLICY "Worker read access" ON public.client_orders
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
-- OPTION 3: FALLBACK POLICY FOR APPROVED USERS
-- =====================================================

-- If the above policies are still too restrictive, 
-- create a fallback policy for any approved user
CREATE POLICY "Approved users fallback access" ON public.client_orders
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.status = 'approved'
        )
    );

-- =====================================================
-- ENSURE PROPER PERMISSIONS
-- =====================================================

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.client_orders TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- =====================================================
-- TEST THE FIX
-- =====================================================

DO $$
DECLARE
    current_user_id UUID;
    user_role TEXT;
    user_status TEXT;
    test_order_id TEXT;
    success BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE '=== TESTING QUICK RLS FIX ===';
    
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RAISE NOTICE '❌ No authenticated user - cannot test';
        RETURN;
    END IF;
    
    SELECT role, status INTO user_role, user_status
    FROM public.user_profiles 
    WHERE id = current_user_id;
    
    RAISE NOTICE 'Testing with user: % (role: %, status: %)', current_user_id, user_role, user_status;
    
    test_order_id := 'QUICK-FIX-TEST-' || extract(epoch from now())::text;
    
    BEGIN
        -- Test insert
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
            50.00,
            NOW()
        );
        
        success := TRUE;
        RAISE NOTICE '✅ SUCCESS: Order creation is now working!';
        
        -- Test update
        UPDATE public.client_orders 
        SET status = 'confirmed' 
        WHERE id = test_order_id;
        
        RAISE NOTICE '✅ SUCCESS: Order update is working!';
        
        -- Test select
        PERFORM * FROM public.client_orders WHERE id = test_order_id;
        
        RAISE NOTICE '✅ SUCCESS: Order reading is working!';
        
        -- Clean up
        DELETE FROM public.client_orders WHERE id = test_order_id;
        RAISE NOTICE '✅ Test cleanup completed';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Test failed: %', SQLERRM;
        RAISE NOTICE 'Error code: %', SQLSTATE;
        
        -- Try to clean up
        BEGIN
            DELETE FROM public.client_orders WHERE id = test_order_id;
        EXCEPTION WHEN OTHERS THEN
            -- Ignore cleanup errors
        END;
    END;
    
    IF success THEN
        RAISE NOTICE '🎉 QUICK FIX SUCCESSFUL!';
        RAISE NOTICE 'Your Flutter app should now be able to create orders';
    ELSE
        RAISE NOTICE '⚠️  Quick fix may not be sufficient';
        RAISE NOTICE 'Consider running the full diagnostic script';
    END IF;
END $$;

-- =====================================================
-- SHOW FINAL POLICY STATUS
-- =====================================================

SELECT 'FINAL RLS POLICIES ON CLIENT_ORDERS:' as info;
SELECT 
    policyname,
    cmd as command
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public'
ORDER BY policyname;

-- Show RLS status
SELECT 
    'RLS STATUS:' as info,
    CASE WHEN relrowsecurity THEN 'ENABLED ✅' ELSE 'DISABLED ❌' END as status
FROM pg_class 
WHERE relname = 'client_orders' 
AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

RAISE NOTICE '==========================================';
RAISE NOTICE 'QUICK RLS FIX COMPLETED';
RAISE NOTICE '==========================================';
RAISE NOTICE 'If order creation is still failing:';
RAISE NOTICE '1. Check user status is "approved" in user_profiles';
RAISE NOTICE '2. Verify user role is valid (admin/owner/accountant/client/worker)';
RAISE NOTICE '3. Run DIAGNOSE_RLS_ISSUE.sql for detailed analysis';
RAISE NOTICE '==========================================';
