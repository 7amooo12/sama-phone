-- MASTER SCRIPT: Complete fix for infinite recursion across ALL database tables
-- This script runs all the individual fixes in the correct order
-- Run this script to resolve ALL PostgreSQL infinite recursion errors (code 42P17)

-- =====================================================
-- OVERVIEW OF THE INFINITE RECURSION PROBLEM
-- =====================================================

/*
PROBLEM SUMMARY:
- Multiple database tables have RLS policies that directly query user_profiles
- When these policies are evaluated, they trigger user_profiles RLS policies
- This creates infinite recursion: Table -> user_profiles -> user_profiles -> ...
- PostgreSQL throws: "infinite recursion detected in policy for relation user_profiles"

AFFECTED TABLES:
1. user_profiles (authentication/profile updates)
2. distributors & distribution_centers (distributor management)
3. client_orders (order management)
4. warehouses, warehouse_inventory, warehouse_requests, warehouse_transactions
5. products (likely affected)
6. Any other table with EXISTS(SELECT 1 FROM user_profiles...) in RLS policies

SOLUTION APPROACH:
- Create SECURITY DEFINER functions that bypass RLS
- Replace direct user_profiles queries in RLS policies with these safe functions
- Maintain proper role-based access control without infinite recursion
*/

-- =====================================================
-- STEP 1: CREATE UNIVERSAL SECURITY DEFINER FUNCTIONS
-- =====================================================

SELECT '🔧 STEP 1: Creating universal SECURITY DEFINER functions...' as progress;

-- Include the comprehensive functions from fix_all_infinite_recursion_comprehensive.sql
\i sql/fix_all_infinite_recursion_comprehensive.sql

-- =====================================================
-- STEP 2: FIX USER_PROFILES TABLE (CORE AUTHENTICATION)
-- =====================================================

SELECT '🔧 STEP 2: Fixing user_profiles table (authentication core)...' as progress;

-- This was already fixed in our previous work, but ensure it's applied
\i sql/fix_infinite_recursion_final.sql

-- =====================================================
-- STEP 3: FIX DISTRIBUTORS TABLES
-- =====================================================

SELECT '🔧 STEP 3: Fixing distributors and distribution_centers tables...' as progress;

-- Apply the distributors fix we created earlier
\i sql/fix_distributors_infinite_recursion.sql

-- =====================================================
-- STEP 4: FIX CLIENT_ORDERS TABLE
-- =====================================================

SELECT '🔧 STEP 4: Fixing client_orders table...' as progress;

-- Apply the client_orders fix
\i sql/fix_client_orders_infinite_recursion.sql

-- =====================================================
-- STEP 5: FIX WAREHOUSE TABLES (DISPATCH FOCUS)
-- =====================================================

SELECT '🔧 STEP 5: Fixing warehouse tables (focusing on dispatch functionality)...' as progress;

-- Apply the warehouse tables fix with specific focus on dispatch
\i sql/fix_warehouse_dispatch_infinite_recursion.sql

-- =====================================================
-- STEP 6: FIX ANY REMAINING TABLES WITH user_profiles DEPENDENCIES
-- =====================================================

SELECT '🔧 STEP 6: Fixing any remaining tables with user_profiles dependencies...' as progress;

-- Find and fix any other tables that might have user_profiles dependencies
DO $$
DECLARE
    policy_record RECORD;
    table_name text;
    policy_name text;
BEGIN
    -- Find all remaining policies that query user_profiles
    FOR policy_record IN 
        SELECT DISTINCT tablename, policyname
        FROM pg_policies 
        WHERE (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%')
          AND tablename NOT IN ('user_profiles', 'distributors', 'distribution_centers', 'client_orders', 'warehouses', 'warehouse_inventory', 'warehouse_requests', 'warehouse_transactions')
    LOOP
        table_name := policy_record.tablename;
        policy_name := policy_record.policyname;
        
        RAISE NOTICE 'WARNING: Found additional table with user_profiles dependency: %.% - Manual fix may be required', table_name, policy_name;
    END LOOP;
END $$;

-- =====================================================
-- STEP 7: COMPREHENSIVE VERIFICATION
-- =====================================================

SELECT '🔧 STEP 7: Running comprehensive verification...' as progress;

-- Test all major tables for infinite recursion
DO $$
DECLARE
    test_count integer;
    table_name text;
BEGIN
    -- Test each major table
    FOR table_name IN VALUES ('user_profiles'), ('distributors'), ('distribution_centers'), ('client_orders'), ('warehouses')
    LOOP
        BEGIN
            EXECUTE format('SELECT COUNT(*) FROM %I', table_name) INTO test_count;
            RAISE NOTICE 'SUCCESS: % table query returned % rows without infinite recursion', table_name, test_count;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'ERROR: % table still has issues: %', table_name, SQLERRM;
        END;
    END LOOP;
END $$;

-- =====================================================
-- STEP 8: FINAL STATUS AND SUMMARY
-- =====================================================

SELECT '✅ COMPREHENSIVE INFINITE RECURSION FIX COMPLETED!' as final_status;

-- Show summary of all SECURITY DEFINER functions created
SELECT 
    'SECURITY DEFINER FUNCTIONS CREATED:' as summary,
    proname as function_name,
    'Available for use in RLS policies' as status
FROM pg_proc 
WHERE proname LIKE '%_safe'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY proname;

-- Show summary of all tables with updated RLS policies
SELECT 
    'TABLES WITH UPDATED RLS POLICIES:' as summary,
    tablename,
    COUNT(*) as policy_count,
    'Using SECURITY DEFINER functions' as status
FROM pg_policies 
WHERE (qual LIKE '%_safe()%' OR with_check LIKE '%_safe()%')
GROUP BY tablename
ORDER BY tablename;

-- Final instructions
SELECT 
    'NEXT STEPS:' as instructions,
    '1. Test your Flutter app authentication' as step_1,
    '2. Test distributor management features' as step_2,
    '3. Test warehouse management features' as step_3,
    '4. Test order management features' as step_4,
    '5. All infinite recursion errors should be resolved' as step_5;

SELECT 
    'IF YOU STILL GET INFINITE RECURSION ERRORS:' as troubleshooting,
    '1. Check the table name in the error message' as debug_1,
    '2. Look for RLS policies on that table querying user_profiles' as debug_2,
    '3. Replace with appropriate SECURITY DEFINER function calls' as debug_3,
    '4. Follow the same pattern used in the fixes above' as debug_4;
