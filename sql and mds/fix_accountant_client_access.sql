-- ============================================================================
-- FIX ACCOUNTANT ACCESS TO CLIENT DATA
-- This script fixes the RLS policies to allow accountants to view client profiles
-- and wallet data for the Customer Debts feature in the accountant dashboard
-- ============================================================================

-- ============================================================================
-- STEP 1: Fix user_profiles RLS policies
-- ============================================================================

-- Drop existing conflicting policies for user_profiles
DROP POLICY IF EXISTS "Accountant can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Accountants can view client profiles" ON public.user_profiles;

-- Create policy allowing accountants to view all user profiles (needed for client data)
CREATE POLICY "Accountant can view all profiles" ON public.user_profiles
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'accountant'
            AND status = 'approved'
        )
    );

-- ============================================================================
-- STEP 2: Verify wallets RLS policies (should already exist)
-- ============================================================================

-- Check if accountant wallet access policy exists, if not create it
DO $$
BEGIN
    -- Check if the policy exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'wallets' 
        AND policyname = 'wallets_accountant_full_access'
    ) THEN
        -- Create the policy if it doesn't exist
        CREATE POLICY "wallets_accountant_full_access" ON public.wallets
            FOR ALL
            TO authenticated
            USING (
                EXISTS (
                    SELECT 1 FROM public.user_profiles
                    WHERE id = auth.uid()
                    AND role = 'accountant'
                    AND status = 'approved'
                )
            )
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.user_profiles
                    WHERE id = auth.uid()
                    AND role = 'accountant'
                    AND status = 'approved'
                )
            );
    END IF;
END $$;

-- ============================================================================
-- STEP 3: Create debugging function to test access
-- ============================================================================

-- Create a function to test accountant access to client data
CREATE OR REPLACE FUNCTION test_accountant_client_access()
RETURNS TABLE (
    test_name TEXT,
    result TEXT,
    details TEXT
) AS $$
BEGIN
    -- Test 1: Check if current user is accountant
    RETURN QUERY
    SELECT 
        'Current User Role'::TEXT,
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM public.user_profiles 
                WHERE id = auth.uid() AND role = 'accountant'
            ) THEN 'PASS - User is accountant'
            ELSE 'FAIL - User is not accountant or not found'
        END::TEXT,
        COALESCE(
            (SELECT 'Role: ' || role || ', Status: ' || status 
             FROM public.user_profiles 
             WHERE id = auth.uid()), 
            'No profile found'
        )::TEXT;

    -- Test 2: Check client profiles access
    RETURN QUERY
    SELECT 
        'Client Profiles Access'::TEXT,
        CASE 
            WHEN (SELECT COUNT(*) FROM public.user_profiles WHERE role = 'client') > 0 
            THEN 'PASS - Can access client profiles'
            ELSE 'FAIL - Cannot access client profiles'
        END::TEXT,
        ('Found ' || (SELECT COUNT(*) FROM public.user_profiles WHERE role = 'client')::TEXT || ' client profiles')::TEXT;

    -- Test 3: Check wallets access
    RETURN QUERY
    SELECT 
        'Wallets Access'::TEXT,
        CASE 
            WHEN (SELECT COUNT(*) FROM public.wallets WHERE role = 'client') > 0 
            THEN 'PASS - Can access client wallets'
            ELSE 'FAIL - Cannot access client wallets'
        END::TEXT,
        ('Found ' || (SELECT COUNT(*) FROM public.wallets WHERE role = 'client')::TEXT || ' client wallets')::TEXT;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 4: Grant necessary permissions
-- ============================================================================

-- Grant execute permission on the test function to authenticated users
GRANT EXECUTE ON FUNCTION test_accountant_client_access() TO authenticated;

-- ============================================================================
-- STEP 5: Verification queries
-- ============================================================================

-- Show current RLS policies for user_profiles
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'user_profiles'
ORDER BY policyname;

-- Show current RLS policies for wallets
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'wallets'
ORDER BY policyname;

-- ============================================================================
-- INSTRUCTIONS FOR TESTING
-- ============================================================================

/*
After running this script:

1. Test the fix by running this query as an accountant user:
   SELECT * FROM test_accountant_client_access();

2. Test client data access:
   SELECT id, name, email, phone_number FROM user_profiles WHERE role = 'client' AND status = 'approved';

3. Test wallet data access:
   SELECT user_id, balance, status FROM wallets WHERE role = 'client' AND status = 'active';

4. If tests pass, the Customer Debts feature should work in the Flutter app.

5. Check the Flutter app console for debug messages when loading client debts.
*/
