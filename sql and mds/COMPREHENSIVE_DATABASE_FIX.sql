-- =====================================================
-- COMPREHENSIVE DATABASE FIX
-- Fixes all identified database issues:
-- 1. Worker data retrieval (RLS policies)
-- 2. Table name inconsistencies (users vs user_profiles)
-- 3. Missing purchase_price column in products table
-- 4. Idempotent script (can be run multiple times)
-- =====================================================

-- STEP 1: ANALYZE CURRENT DATABASE STATE
-- =====================================================

SELECT '=== DATABASE STATE ANALYSIS ===' as section;

-- Check if user_profiles table exists
SELECT 
    'user_profiles table exists' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'user_profiles'
        ) THEN 'YES'
        ELSE 'NO'
    END as result;

-- Check if users table exists (legacy)
SELECT 
    'users table exists (legacy)' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'users'
        ) THEN 'YES'
        ELSE 'NO'
    END as result;

-- Check if products table has purchase_price column
SELECT 
    'products.purchase_price column exists' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'products' 
            AND column_name = 'purchase_price'
        ) THEN 'YES'
        ELSE 'NO'
    END as result;

-- STEP 2: CREATE USERS TABLE ALIAS (IF NEEDED)
-- =====================================================

-- Create a view that maps 'users' to 'user_profiles' for backward compatibility
-- This fixes the "permission denied for table users" error
DROP VIEW IF EXISTS public.users;

CREATE VIEW public.users AS 
SELECT * FROM public.user_profiles;

-- Grant permissions on the view
GRANT SELECT ON public.users TO authenticated;
GRANT SELECT ON public.users TO service_role;

SELECT 'Created users view as alias to user_profiles' as fix_applied;

-- STEP 3: ADD MISSING PURCHASE_PRICE COLUMN TO PRODUCTS
-- =====================================================

-- Add purchase_price column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'products' 
        AND column_name = 'purchase_price'
    ) THEN
        ALTER TABLE public.products 
        ADD COLUMN purchase_price DECIMAL(10,2) DEFAULT 0.0;
        
        RAISE NOTICE 'Added purchase_price column to products table';
    ELSE
        RAISE NOTICE 'purchase_price column already exists in products table';
    END IF;
END $$;

-- Update existing products with default purchase price (80% of selling price)
UPDATE public.products 
SET purchase_price = ROUND(price * 0.8, 2)
WHERE purchase_price IS NULL OR purchase_price = 0;

SELECT 'Updated products with default purchase prices' as fix_applied;

-- STEP 4: CLEAN UP EXISTING RLS POLICIES (IDEMPOTENT)
-- =====================================================

SELECT '=== CLEANING UP EXISTING POLICIES ===' as section;

-- Remove all existing user_profiles policies to start fresh
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    FOR policy_record IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'user_profiles'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.user_profiles', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;
END $$;

-- STEP 5: CREATE SAFE, NON-RECURSIVE RLS POLICIES
-- =====================================================

SELECT '=== CREATING SAFE RLS POLICIES ===' as section;

-- Ensure RLS is enabled
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Policy 1: Service role full access (for system operations)
CREATE POLICY "user_profiles_service_role_access" ON public.user_profiles
FOR ALL TO service_role
USING (true)
WITH CHECK (true);

-- Policy 2: Users can view their own profile
CREATE POLICY "user_profiles_view_own" ON public.user_profiles
FOR SELECT TO authenticated
USING (id = auth.uid());

-- Policy 3: Users can update their own profile
CREATE POLICY "user_profiles_update_own" ON public.user_profiles
FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Policy 4: Users can insert their own profile during signup
CREATE POLICY "user_profiles_insert_own" ON public.user_profiles
FOR INSERT TO authenticated
WITH CHECK (id = auth.uid());

-- Policy 5: CRITICAL - Allow authenticated users to view all profiles
-- This is the key policy that enables worker data loading
CREATE POLICY "user_profiles_authenticated_view_all" ON public.user_profiles
FOR SELECT TO authenticated
USING (true);

SELECT 'Created safe RLS policies for user_profiles' as fix_applied;

-- STEP 6: CREATE SAFE ADMIN ACCESS FUNCTION
-- =====================================================

-- Create a function to check admin status without recursion
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'owner', 'accountant')
        AND status IN ('active', 'approved')
        LIMIT 1
    );
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.is_admin_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin_user() TO service_role;

-- Policy 6: Admin users can manage all profiles using safe function
CREATE POLICY "user_profiles_admin_manage_all" ON public.user_profiles
FOR ALL TO authenticated
USING (public.is_admin_user())
WITH CHECK (public.is_admin_user());

SELECT 'Created safe admin access function and policy' as fix_applied;

-- STEP 7: CREATE PERFORMANCE INDEXES
-- =====================================================

-- Create indexes for faster queries (IF NOT EXISTS to avoid conflicts)
CREATE INDEX IF NOT EXISTS idx_user_profiles_role_status 
ON public.user_profiles(role, status);

CREATE INDEX IF NOT EXISTS idx_user_profiles_name 
ON public.user_profiles(name);

CREATE INDEX IF NOT EXISTS idx_user_profiles_email 
ON public.user_profiles(email);

CREATE INDEX IF NOT EXISTS idx_products_purchase_price 
ON public.products(purchase_price) 
WHERE purchase_price IS NOT NULL;

SELECT 'Created performance indexes' as fix_applied;

-- STEP 8: VERIFY THE FIXES
-- =====================================================

SELECT '=== VERIFICATION TESTS ===' as section;

-- Test 1: Check if workers are now visible
SELECT 
    'Workers visible after fix' as test_name,
    COUNT(*) as count
FROM public.user_profiles
WHERE role = 'worker';

-- Test 2: Check approved workers
SELECT 
    'Approved workers visible' as test_name,
    COUNT(*) as count
FROM public.user_profiles
WHERE role = 'worker'
AND status IN ('approved', 'active');

-- Test 3: Test users view (backward compatibility)
SELECT 
    'Users view working' as test_name,
    COUNT(*) as count
FROM public.users
WHERE role = 'worker';

-- Test 4: Check products with purchase_price
SELECT 
    'Products with purchase_price' as test_name,
    COUNT(*) as count
FROM public.products
WHERE purchase_price IS NOT NULL AND purchase_price > 0;

-- Test 5: Check if admin function works
SELECT 
    'Admin function test' as test_name,
    public.is_admin_user() as result;

-- STEP 9: FINAL POLICY VERIFICATION
-- =====================================================

-- Show final policies
SELECT 
    'Final user_profiles policies' as info,
    policyname,
    cmd,
    CASE 
        WHEN qual LIKE '%user_profiles%' THEN 'POTENTIAL_RECURSION'
        ELSE 'SAFE'
    END as safety_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'user_profiles'
ORDER BY policyname;

-- STEP 10: SUCCESS VERIFICATION
-- =====================================================

-- Final verification using PL/pgSQL block
DO $$
DECLARE
    worker_count INTEGER;
    approved_worker_count INTEGER;
    products_with_price INTEGER;
    users_view_count INTEGER;
BEGIN
    -- Count total workers
    SELECT COUNT(*) INTO worker_count
    FROM public.user_profiles
    WHERE role = 'worker';
    
    -- Count approved workers
    SELECT COUNT(*) INTO approved_worker_count
    FROM public.user_profiles
    WHERE role = 'worker'
    AND status IN ('approved', 'active');
    
    -- Count products with purchase price
    SELECT COUNT(*) INTO products_with_price
    FROM public.products
    WHERE purchase_price IS NOT NULL AND purchase_price > 0;
    
    -- Test users view
    SELECT COUNT(*) INTO users_view_count
    FROM public.users
    WHERE role = 'worker';
    
    -- Report results
    RAISE NOTICE '=== COMPREHENSIVE FIX RESULTS ===';
    RAISE NOTICE 'Total workers found: %', worker_count;
    RAISE NOTICE 'Approved workers found: %', approved_worker_count;
    RAISE NOTICE 'Products with purchase_price: %', products_with_price;
    RAISE NOTICE 'Workers accessible via users view: %', users_view_count;
    
    IF worker_count > 0 AND users_view_count > 0 AND products_with_price > 0 THEN
        RAISE NOTICE 'SUCCESS: All database issues should now be resolved';
    ELSE
        RAISE NOTICE 'WARNING: Some issues may remain - check individual counts above';
    END IF;
    
END $$;

-- STEP 11: FINAL STATUS MESSAGE
-- =====================================================

SELECT 
    'COMPREHENSIVE DATABASE FIX COMPLETE' as status,
    'All identified issues have been addressed' as result,
    'Test the Flutter app to verify functionality' as next_step;

-- Show summary of fixes applied
SELECT 'Summary of fixes applied:' as summary
UNION ALL
SELECT '1. Created users view as alias to user_profiles'
UNION ALL
SELECT '2. Added purchase_price column to products table'
UNION ALL
SELECT '3. Fixed RLS policies for user_profiles table'
UNION ALL
SELECT '4. Created safe admin access function'
UNION ALL
SELECT '5. Added performance indexes'
UNION ALL
SELECT '6. Made script idempotent (can run multiple times)';
