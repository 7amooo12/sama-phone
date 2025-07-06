-- ============================================================================
-- FIX OWNER ACCESS TO WORKER DATA
-- This script fixes the RLS policies to allow owners to view worker profiles
-- and related data for the Worker Tracking feature in the owner dashboard
-- ============================================================================

-- ============================================================================
-- STEP 1: Fix user_profiles RLS policies for owner role
-- ============================================================================

-- Drop existing conflicting policies for user_profiles
DROP POLICY IF EXISTS "Owner can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Owners can view worker profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Owner can view worker profiles" ON public.user_profiles;

-- Create policy allowing owners to view all user profiles (needed for worker data)
CREATE POLICY "Owner can view all profiles" ON public.user_profiles
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'owner'
            AND status IN ('approved', 'active')
        )
    );

-- ============================================================================
-- STEP 2: Verify and create owner access policies for related tables
-- ============================================================================

-- Check if owner access policy exists for worker_tasks, if not create it
DO $$
BEGIN
    -- Check if the policy exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'worker_tasks' 
        AND policyname = 'Owner view worker_tasks'
    ) THEN
        -- Create the policy if it doesn't exist
        CREATE POLICY "Owner view worker_tasks" ON public.worker_tasks
            FOR SELECT
            TO authenticated
            USING (
                EXISTS (
                    SELECT 1 FROM public.user_profiles
                    WHERE id = auth.uid()
                    AND role = 'owner'
                    AND status IN ('approved', 'active')
                )
            );
    END IF;
END $$;

-- Check if owner access policy exists for worker_rewards, if not create it
DO $$
BEGIN
    -- Check if the policy exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'worker_rewards' 
        AND policyname = 'Owner view worker_rewards'
    ) THEN
        -- Create the policy if it doesn't exist
        CREATE POLICY "Owner view worker_rewards" ON public.worker_rewards
            FOR SELECT
            TO authenticated
            USING (
                EXISTS (
                    SELECT 1 FROM public.user_profiles
                    WHERE id = auth.uid()
                    AND role = 'owner'
                    AND status IN ('approved', 'active')
                )
            );
    END IF;
END $$;

-- ============================================================================
-- STEP 3: Create debugging function to test owner access
-- ============================================================================

-- Create a function to test owner access to worker data
CREATE OR REPLACE FUNCTION test_owner_worker_access()
RETURNS TABLE (
    test_name TEXT,
    result TEXT,
    details TEXT
) AS $$
BEGIN
    -- Test 1: Check if current user is owner
    RETURN QUERY
    SELECT 
        'Current User Role'::TEXT,
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM public.user_profiles 
                WHERE id = auth.uid() AND role = 'owner'
            ) THEN 'PASS - User is owner'
            ELSE 'FAIL - User is not owner or not found'
        END::TEXT,
        COALESCE(
            (SELECT 'Role: ' || role || ', Status: ' || status 
             FROM public.user_profiles 
             WHERE id = auth.uid()), 
            'No profile found'
        )::TEXT;

    -- Test 2: Check worker profiles access
    RETURN QUERY
    SELECT 
        'Worker Profiles Access'::TEXT,
        CASE 
            WHEN (SELECT COUNT(*) FROM public.user_profiles WHERE role = 'worker') > 0 
            THEN 'PASS - Can access worker profiles'
            ELSE 'FAIL - Cannot access worker profiles'
        END::TEXT,
        ('Found ' || (SELECT COUNT(*) FROM public.user_profiles WHERE role = 'worker')::TEXT || ' worker profiles')::TEXT;

    -- Test 3: Check worker_tasks access
    RETURN QUERY
    SELECT 
        'Worker Tasks Access'::TEXT,
        CASE 
            WHEN (SELECT COUNT(*) FROM public.worker_tasks) > 0 
            THEN 'PASS - Can access worker tasks'
            ELSE 'INFO - No worker tasks found or no access'
        END::TEXT,
        ('Found ' || (SELECT COUNT(*) FROM public.worker_tasks)::TEXT || ' worker tasks')::TEXT;

    -- Test 4: Check worker_rewards access
    RETURN QUERY
    SELECT 
        'Worker Rewards Access'::TEXT,
        CASE 
            WHEN (SELECT COUNT(*) FROM public.worker_rewards) > 0 
            THEN 'PASS - Can access worker rewards'
            ELSE 'INFO - No worker rewards found or no access'
        END::TEXT,
        ('Found ' || (SELECT COUNT(*) FROM public.worker_rewards)::TEXT || ' worker rewards')::TEXT;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 4: Grant necessary permissions
-- ============================================================================

-- Grant execute permission on the test function to authenticated users
GRANT EXECUTE ON FUNCTION test_owner_worker_access() TO authenticated;

-- ============================================================================
-- STEP 5: Verification queries
-- ============================================================================

-- Show current RLS policies for user_profiles
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'user_profiles'
AND policyname LIKE '%owner%' OR policyname LIKE '%Owner%'
ORDER BY policyname;

-- Show current RLS policies for worker_tasks
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'worker_tasks'
ORDER BY policyname;

-- Show current RLS policies for worker_rewards
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'worker_rewards'
ORDER BY policyname;

-- ============================================================================
-- INSTRUCTIONS FOR TESTING
-- ============================================================================

/*
After running this script:

1. Test the fix by running this query as an owner user:
   SELECT * FROM test_owner_worker_access();

2. Test worker data access:
   SELECT id, name, email, role, status FROM user_profiles WHERE role = 'worker';

3. Test worker tasks access:
   SELECT id, title, assigned_to, status FROM worker_tasks LIMIT 5;

4. Test worker rewards access:
   SELECT id, worker_id, amount, awarded_at FROM worker_rewards LIMIT 5;

5. If tests pass, the Worker Tracking feature should work in the Flutter app.

6. Check the Flutter app console for debug messages when loading worker data.
*/
