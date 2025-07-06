-- 🔍 PROPER RLS SECURITY VERIFICATION
-- Correct analysis of RLS policy security by examining actual policy conditions

-- ==================== DETAILED POLICY ANALYSIS ====================

-- Check the actual policy definitions and their security conditions
SELECT 
  '🔍 DETAILED POLICY ANALYSIS' as analysis_type,
  schemaname,
  tablename,
  policyname,
  cmd,
  roles,
  -- Check if policy has authentication requirement
  CASE 
    WHEN qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%' THEN '✅ REQUIRES AUTH'
    ELSE '❌ NO AUTH CHECK'
  END as auth_status,
  -- Check if policy has role restrictions
  CASE 
    WHEN qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%' THEN '✅ ROLE RESTRICTED'
    ELSE '❌ NO ROLE CHECK'
  END as role_status,
  -- Show actual policy condition (truncated for readability)
  LEFT(COALESCE(qual, with_check, 'NO CONDITION'), 100) as policy_condition
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_requests', 'warehouse_transactions')
ORDER BY tablename, cmd, policyname;

-- ==================== SECURITY COMPLIANCE CHECK ====================

-- Verify each table has proper security
WITH security_analysis AS (
  SELECT 
    tablename,
    cmd,
    COUNT(*) as policy_count,
    COUNT(CASE WHEN qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%' THEN 1 END) as auth_policies,
    COUNT(CASE WHEN qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%' THEN 1 END) as role_policies
  FROM pg_policies 
  WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_requests', 'warehouse_transactions')
  GROUP BY tablename, cmd
)
SELECT 
  '🛡️ SECURITY COMPLIANCE' as check_type,
  tablename,
  cmd,
  policy_count,
  CASE 
    WHEN auth_policies > 0 AND role_policies > 0 THEN '✅ SECURE'
    WHEN auth_policies > 0 THEN '⚠️ AUTH ONLY'
    ELSE '🚨 VULNERABLE'
  END as security_status,
  CASE 
    WHEN auth_policies = 0 THEN 'Missing authentication check'
    WHEN role_policies = 0 THEN 'Missing role restrictions'
    ELSE 'Properly secured'
  END as issue_description
FROM security_analysis
ORDER BY tablename, cmd;

-- ==================== RLS ENABLEMENT CHECK ====================

-- Verify RLS is enabled on all warehouse tables
SELECT 
  '🔒 RLS ENABLEMENT CHECK' as check_type,
  schemaname,
  tablename,
  CASE 
    WHEN rowsecurity THEN '✅ RLS ENABLED'
    ELSE '🚨 RLS DISABLED'
  END as rls_status
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_requests', 'warehouse_transactions')
ORDER BY tablename;

-- ==================== AUTHENTICATION FUNCTION TEST ====================

-- Test if auth.uid() function is available and working
SELECT 
  '🔑 AUTH FUNCTION TEST' as test_type,
  CASE 
    WHEN auth.uid() IS NOT NULL THEN '✅ AUTHENTICATED USER'
    ELSE '❌ NO AUTHENTICATION'
  END as auth_status,
  auth.uid() as current_user_id;

-- ==================== USER PROFILES TABLE CHECK ====================

-- Verify user_profiles table exists and has proper structure
SELECT 
  '👤 USER PROFILES CHECK' as check_type,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'user_profiles'
  AND column_name IN ('id', 'role', 'status')
ORDER BY column_name;

-- ==================== SAMPLE POLICY CONDITION ANALYSIS ====================

-- Show full policy conditions for warehouses table as example
SELECT 
  '📋 SAMPLE POLICY CONDITIONS' as analysis_type,
  policyname,
  cmd,
  qual as using_condition,
  with_check as with_check_condition
FROM pg_policies 
WHERE tablename = 'warehouses'
ORDER BY cmd, policyname;

-- ==================== EMERGENCY SECURITY TEST ====================

-- Test actual access control (this will show if policies are working)
DO $$
DECLARE
  test_result TEXT;
  warehouse_count INTEGER;
BEGIN
  -- Try to access warehouses table
  BEGIN
    SELECT COUNT(*) INTO warehouse_count FROM warehouses;
    test_result := '✅ ACCESS GRANTED (policies allow current user) - Found ' || warehouse_count || ' warehouses';
  EXCEPTION
    WHEN insufficient_privilege THEN
      test_result := '🔒 ACCESS DENIED (policies working correctly)';
    WHEN OTHERS THEN
      test_result := '❓ OTHER ERROR: ' || SQLERRM;
  END;

  RAISE NOTICE '🧪 WAREHOUSE ACCESS TEST: %', test_result;
END $$;

-- ==================== POLICY RECOMMENDATIONS ====================

-- Provide recommendations based on current state
SELECT 
  '💡 SECURITY RECOMMENDATIONS' as recommendation_type,
  'If policies show auth.uid() and user_profiles checks, they are secure' as note1,
  'The {public} role assignment is normal in Supabase RLS' as note2,
  'Security is enforced by USING and WITH CHECK clauses, not role assignment' as note3,
  'Test actual table access to verify policy effectiveness' as note4;

-- ==================== FINAL VERIFICATION SUMMARY ====================

WITH policy_summary AS (
  SELECT 
    tablename,
    COUNT(*) as total_policies,
    COUNT(CASE WHEN qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%' THEN 1 END) as auth_protected,
    COUNT(CASE WHEN qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%' THEN 1 END) as role_protected
  FROM pg_policies 
  WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_requests', 'warehouse_transactions')
  GROUP BY tablename
)
SELECT 
  '📊 FINAL SECURITY SUMMARY' as summary_type,
  tablename,
  total_policies,
  auth_protected,
  role_protected,
  CASE 
    WHEN auth_protected > 0 AND role_protected > 0 THEN '✅ FULLY SECURED'
    WHEN auth_protected > 0 THEN '⚠️ PARTIALLY SECURED'
    ELSE '🚨 NOT SECURED'
  END as overall_security_status
FROM policy_summary
ORDER BY tablename;
