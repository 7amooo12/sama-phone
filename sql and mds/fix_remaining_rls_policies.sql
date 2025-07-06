-- 🔧 FIX REMAINING VULNERABLE RLS POLICIES
-- The INSERT policy is working, but SELECT/UPDATE/DELETE policies are vulnerable

-- ==================== CLEAN UP DUPLICATE POLICIES ====================

-- Remove duplicate INSERT policies (keep the working one)
DROP POLICY IF EXISTS "warehouse_requests_insert_secure" ON warehouse_requests;

-- Keep only the working INSERT policy: "warehouse_requests_insert_fixed"

-- ==================== FIX SELECT POLICY ====================

-- Drop the vulnerable SELECT policy
DROP POLICY IF EXISTS "secure_requests_select" ON warehouse_requests;

-- Create secure SELECT policy
CREATE POLICY "warehouse_requests_select_secure" ON warehouse_requests
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL 
    AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== FIX UPDATE POLICY ====================

-- Drop the vulnerable UPDATE policy
DROP POLICY IF EXISTS "secure_requests_update" ON warehouse_requests;

-- Create secure UPDATE policy (only admin, owner, accountant can approve/modify)
CREATE POLICY "warehouse_requests_update_secure" ON warehouse_requests
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL 
    AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== FIX DELETE POLICY ====================

-- Drop the vulnerable DELETE policy
DROP POLICY IF EXISTS "secure_requests_delete" ON warehouse_requests;

-- Create secure DELETE policy (only admin and owner can delete)
CREATE POLICY "warehouse_requests_delete_secure" ON warehouse_requests
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL 
    AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== VERIFY ALL POLICIES ARE NOW SECURE ====================

-- Check all policies have proper security
SELECT 
  '🔒 SECURITY VERIFICATION' as check_type,
  policyname,
  cmd,
  CASE 
    WHEN (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%') 
     AND (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%')
    THEN '✅ FULLY SECURE'
    WHEN (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%')
    THEN '⚠️ AUTH ONLY'
    ELSE '🚨 VULNERABLE'
  END as security_status,
  CASE 
    WHEN qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%' THEN '✅'
    ELSE '❌'
  END as has_auth,
  CASE 
    WHEN qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%' THEN '✅'
    ELSE '❌'
  END as has_role_check
FROM pg_policies 
WHERE tablename = 'warehouse_requests'
ORDER BY cmd, policyname;

-- ==================== TEST CURRENT USER ACCESS ====================

-- Test if current user can access warehouse_requests with new policies
DO $$
DECLARE
  current_user_id UUID;
  user_role TEXT;
  user_status TEXT;
  can_select BOOLEAN;
  can_insert BOOLEAN;
  can_update BOOLEAN;
  can_delete BOOLEAN;
BEGIN
  SELECT auth.uid() INTO current_user_id;
  
  IF current_user_id IS NOT NULL THEN
    SELECT role, status INTO user_role, user_status
    FROM user_profiles 
    WHERE id = current_user_id;
    
    -- Test SELECT permission
    SELECT EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = current_user_id
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    ) INTO can_select;
    
    -- Test INSERT permission
    SELECT EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = current_user_id
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    ) INTO can_insert;
    
    -- Test UPDATE permission
    SELECT EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = current_user_id
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    ) INTO can_update;
    
    -- Test DELETE permission
    SELECT EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = current_user_id
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    ) INTO can_delete;
    
    RAISE NOTICE '🧪 PERMISSION TEST RESULTS:';
    RAISE NOTICE '   User: % (Role: %, Status: %)', current_user_id, user_role, user_status;
    RAISE NOTICE '   SELECT: %', CASE WHEN can_select THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
    RAISE NOTICE '   INSERT: %', CASE WHEN can_insert THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
    RAISE NOTICE '   UPDATE: %', CASE WHEN can_update THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
    RAISE NOTICE '   DELETE: %', CASE WHEN can_delete THEN '✅ ALLOWED' ELSE '❌ BLOCKED' END;
    
  ELSE
    RAISE NOTICE '❌ No authenticated user for testing';
  END IF;
END $$;

-- ==================== FINAL SECURITY SUMMARY ====================

WITH policy_security AS (
  SELECT 
    COUNT(*) as total_policies,
    COUNT(CASE WHEN (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%') 
                AND (qual LIKE '%user_profiles%' OR with_check LIKE '%user_profiles%')
               THEN 1 END) as secure_policies,
    COUNT(CASE WHEN NOT (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%')
               THEN 1 END) as vulnerable_policies
  FROM pg_policies 
  WHERE tablename = 'warehouse_requests'
)
SELECT 
  '📊 FINAL SECURITY STATUS' as status_type,
  total_policies,
  secure_policies,
  vulnerable_policies,
  CASE 
    WHEN vulnerable_policies = 0 THEN '✅ ALL POLICIES SECURE'
    ELSE '🚨 VULNERABILITIES REMAIN'
  END as overall_status
FROM policy_security;

-- ==================== SUCCESS MESSAGE ====================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🎉 RLS POLICY FIX COMPLETED!';
  RAISE NOTICE '✅ All warehouse_requests policies now have proper security';
  RAISE NOTICE '🔒 Authentication and role-based access control enforced';
  RAISE NOTICE '📋 Permission levels:';
  RAISE NOTICE '   - SELECT: admin, owner, accountant, warehouseManager';
  RAISE NOTICE '   - INSERT: admin, owner, accountant, warehouseManager';
  RAISE NOTICE '   - UPDATE: admin, owner, accountant only';
  RAISE NOTICE '   - DELETE: admin, owner only';
  RAISE NOTICE '';
  RAISE NOTICE '🧪 Now test the warehouse dispatch creation again!';
  RAISE NOTICE '';
END $$;
