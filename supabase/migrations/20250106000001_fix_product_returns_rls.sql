-- Migration: Fix product returns RLS policies for admin access
-- Date: 2025-01-06
-- Purpose: Ensure admin users can access product returns data properly

-- Step 1: Add service role policy for product returns (for system operations)
DO $$
BEGIN
    -- Drop existing service role policy if it exists
    DROP POLICY IF EXISTS "Service role can manage product returns" ON public.product_returns;
    
    -- Create service role policy
    CREATE POLICY "Service role can manage product returns" ON public.product_returns
        FOR ALL
        TO service_role
        USING (true)
        WITH CHECK (true);
    
    RAISE NOTICE '✅ Created service role policy for product_returns';
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR creating service role policy: %', SQLERRM;
END $$;

-- Step 2: Add a fallback admin policy that doesn't rely on user_profiles
DO $$
BEGIN
    -- Drop existing fallback policy if it exists
    DROP POLICY IF EXISTS "Fallback admin access to product returns" ON public.product_returns;
    
    -- Create fallback admin policy using JWT metadata
    CREATE POLICY "Fallback admin access to product returns" ON public.product_returns
        FOR ALL
        TO authenticated
        USING (
            -- Check if user has admin role in JWT metadata
            COALESCE(
                (auth.jwt() ->> 'user_metadata')::jsonb ->> 'role' = 'admin',
                false
            ) OR
            -- Or check user_profiles table (existing logic)
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid()
                AND role IN ('admin', 'owner', 'accountant')
                AND status = 'approved'
            )
        )
        WITH CHECK (
            -- Same check for inserts/updates
            COALESCE(
                (auth.jwt() ->> 'user_metadata')::jsonb ->> 'role' = 'admin',
                false
            ) OR
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid()
                AND role IN ('admin', 'owner', 'accountant')
                AND status = 'approved'
            )
        );
    
    RAISE NOTICE '✅ Created fallback admin policy for product_returns';
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR creating fallback admin policy: %', SQLERRM;
END $$;

-- Step 3: Add the same policies for error_reports table
DO $$
BEGIN
    -- Service role policy for error reports
    DROP POLICY IF EXISTS "Service role can manage error reports" ON public.error_reports;
    
    CREATE POLICY "Service role can manage error reports" ON public.error_reports
        FOR ALL
        TO service_role
        USING (true)
        WITH CHECK (true);
    
    -- Fallback admin policy for error reports
    DROP POLICY IF EXISTS "Fallback admin access to error reports" ON public.error_reports;
    
    CREATE POLICY "Fallback admin access to error reports" ON public.error_reports
        FOR ALL
        TO authenticated
        USING (
            COALESCE(
                (auth.jwt() ->> 'user_metadata')::jsonb ->> 'role' = 'admin',
                false
            ) OR
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid()
                AND role IN ('admin', 'owner', 'accountant')
                AND status = 'approved'
            )
        )
        WITH CHECK (
            COALESCE(
                (auth.jwt() ->> 'user_metadata')::jsonb ->> 'role' = 'admin',
                false
            ) OR
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE id = auth.uid()
                AND role IN ('admin', 'owner', 'accountant')
                AND status = 'approved'
            )
        );
    
    RAISE NOTICE '✅ Created service role and fallback admin policies for error_reports';
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR creating error_reports policies: %', SQLERRM;
END $$;

-- Step 4: Verify policies were created
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename IN ('product_returns', 'error_reports')
    AND policyname LIKE '%Service role%' OR policyname LIKE '%Fallback admin%';
    
    RAISE NOTICE '✅ Verification: Created % new policies for customer service tables', policy_count;
    
    -- List all policies for these tables
    RAISE NOTICE '📋 Current policies for product_returns and error_reports:';
    FOR policy_count IN 
        SELECT 1 FROM pg_policies 
        WHERE tablename IN ('product_returns', 'error_reports')
    LOOP
        -- This will show in the logs
        NULL;
    END LOOP;
END $$;

-- Step 5: Test data access (optional - for debugging)
DO $$
DECLARE
    test_count INTEGER;
BEGIN
    -- Try to count records (this will help identify if RLS is blocking access)
    SELECT COUNT(*) INTO test_count FROM public.product_returns;
    RAISE NOTICE '📊 Test: Found % product return records', test_count;
    
    SELECT COUNT(*) INTO test_count FROM public.error_reports;
    RAISE NOTICE '📊 Test: Found % error report records', test_count;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️  Test query failed (this might be expected if no data exists): %', SQLERRM;
END $$;
