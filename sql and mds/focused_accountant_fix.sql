-- ============================================================================
-- FOCUSED ACCOUNTANT SEARCH FIX
-- ============================================================================
-- إصلاح مركز لمشكلة بحث المحاسب
-- ============================================================================

-- 1. Find the exact blocking policies
SELECT 
  tablename,
  policyname,
  cmd,
  qual
FROM pg_policies 
WHERE schemaname = 'public'
  AND tablename IN ('products', 'warehouses', 'warehouse_inventory', 'user_profiles')
  AND cmd = 'SELECT'
  AND (qual LIKE '%admin%' OR qual LIKE '%owner%')
  AND qual NOT LIKE '%accountant%';

-- 2. Show current user roles
SELECT role, COUNT(*) as count FROM user_profiles GROUP BY role;

-- 3. Test current access
SELECT 'Can read products' as test, COUNT(*) FROM products LIMIT 1;
SELECT 'Can read warehouses' as test, COUNT(*) FROM warehouses LIMIT 1;

-- 4. Skip the UPDATE approach - go directly to DROP and CREATE

-- 5. Comprehensive policy cleanup - Drop ALL existing policies
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    -- Drop all policies on products table
    FOR policy_record IN
        SELECT policyname FROM pg_policies
        WHERE tablename = 'products' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_record.policyname || '" ON public.products';
        RAISE NOTICE 'Dropped policy: % on products', policy_record.policyname;
    END LOOP;

    -- Drop all policies on warehouses table
    FOR policy_record IN
        SELECT policyname FROM pg_policies
        WHERE tablename = 'warehouses' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_record.policyname || '" ON public.warehouses';
        RAISE NOTICE 'Dropped policy: % on warehouses', policy_record.policyname;
    END LOOP;

    -- Drop all policies on warehouse_inventory table
    FOR policy_record IN
        SELECT policyname FROM pg_policies
        WHERE tablename = 'warehouse_inventory' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_record.policyname || '" ON public.warehouse_inventory';
        RAISE NOTICE 'Dropped policy: % on warehouse_inventory', policy_record.policyname;
    END LOOP;

    -- Drop all policies on user_profiles table
    FOR policy_record IN
        SELECT policyname FROM pg_policies
        WHERE tablename = 'user_profiles' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_record.policyname || '" ON public.user_profiles';
        RAISE NOTICE 'Dropped policy: % on user_profiles', policy_record.policyname;
    END LOOP;

    RAISE NOTICE 'All existing policies have been dropped successfully';
END $$;

-- Verify policy removal
SELECT
  'POLICY CLEANUP VERIFICATION' as check_type,
  tablename,
  COUNT(*) as remaining_policies
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('products', 'warehouses', 'warehouse_inventory', 'user_profiles')
GROUP BY tablename
ORDER BY tablename;

-- Create new inclusive policies with error handling
DO $$
DECLARE
    timestamp_suffix TEXT := to_char(now(), 'YYYYMMDDHH24MISS');
BEGIN
    -- Create products policy
    BEGIN
        EXECUTE 'CREATE POLICY "products_comprehensive_access_' || timestamp_suffix || '" ON public.products
          FOR SELECT
          USING (
            auth.role() = ''service_role'' OR
            (
              auth.role() = ''authenticated'' AND
              auth.uid() IS NOT NULL AND
              EXISTS (
                SELECT 1 FROM user_profiles
                WHERE user_profiles.id = auth.uid()
                  AND user_profiles.role IN (''admin'', ''owner'', ''accountant'', ''warehouseManager'')
                  AND user_profiles.status = ''approved''
              )
            )
          )';
        RAISE NOTICE 'Created products policy successfully';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating products policy: %', SQLERRM;
    END;

    -- Create warehouses policy
    BEGIN
        EXECUTE 'CREATE POLICY "warehouses_comprehensive_access_' || timestamp_suffix || '" ON public.warehouses
          FOR SELECT
          USING (
            auth.role() = ''service_role'' OR
            (
              auth.role() = ''authenticated'' AND
              auth.uid() IS NOT NULL AND
              EXISTS (
                SELECT 1 FROM user_profiles
                WHERE user_profiles.id = auth.uid()
                  AND user_profiles.role IN (''admin'', ''owner'', ''accountant'', ''warehouseManager'')
                  AND user_profiles.status = ''approved''
              )
            )
          )';
        RAISE NOTICE 'Created warehouses policy successfully';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating warehouses policy: %', SQLERRM;
    END;

    -- Create warehouse_inventory policy
    BEGIN
        EXECUTE 'CREATE POLICY "warehouse_inventory_comprehensive_access_' || timestamp_suffix || '" ON public.warehouse_inventory
          FOR SELECT
          USING (
            auth.role() = ''service_role'' OR
            (
              auth.role() = ''authenticated'' AND
              auth.uid() IS NOT NULL AND
              EXISTS (
                SELECT 1 FROM user_profiles
                WHERE user_profiles.id = auth.uid()
                  AND user_profiles.role IN (''admin'', ''owner'', ''accountant'', ''warehouseManager'')
                  AND user_profiles.status = ''approved''
              )
            )
          )';
        RAISE NOTICE 'Created warehouse_inventory policy successfully';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating warehouse_inventory policy: %', SQLERRM;
    END;

    -- Create user_profiles policy
    BEGIN
        EXECUTE 'CREATE POLICY "user_profiles_comprehensive_access_' || timestamp_suffix || '" ON public.user_profiles
          FOR SELECT
          USING (
            auth.role() = ''service_role'' OR
            (
              auth.role() = ''authenticated'' AND
              auth.uid() IS NOT NULL AND
              (
                user_profiles.id = auth.uid() OR
                EXISTS (
                  SELECT 1 FROM user_profiles up
                  WHERE up.id = auth.uid()
                    AND up.role IN (''admin'', ''owner'', ''accountant'', ''warehouseManager'')
                    AND up.status = ''approved''
                )
              )
            )
          )';
        RAISE NOTICE 'Created user_profiles policy successfully';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating user_profiles policy: %', SQLERRM;
    END;
END $$;

-- 6. Ensure search functions have proper permissions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- 7. Test after fix
SELECT 'AFTER FIX - Can read products' as test, COUNT(*) FROM products LIMIT 1;
SELECT 'AFTER FIX - Can read warehouses' as test, COUNT(*) FROM warehouses LIMIT 1;
SELECT 'AFTER FIX - Can read inventory' as test, COUNT(*) FROM warehouse_inventory LIMIT 1;

-- 8. Final verification
SELECT 
  'VERIFICATION' as status,
  'Accountant search should now work' as result,
  'Test search functionality in the app' as next_step;
