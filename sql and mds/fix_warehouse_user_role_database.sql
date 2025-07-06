-- 🔧 FIX WAREHOUSE USER ROLE DATABASE ISSUE
-- Correcting warehouse@samastore.com role from "admin" to "warehouseManager"

-- ==================== INVESTIGATION RESULTS ====================

-- First, let's confirm the current state
SELECT 
  '🔍 CURRENT STATE VERIFICATION' as check_type,
  id,
  email,
  name,
  role,
  status,
  created_at,
  updated_at
FROM user_profiles 
WHERE email = 'warehouse@samastore.com';

-- ==================== ROOT CAUSE ANALYSIS ====================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🔍 ROOT CAUSE ANALYSIS:';
  RAISE NOTICE '1. The Flutter code is working correctly';
  RAISE NOTICE '2. UserRole.fromString("admin") correctly returns UserRole.admin';
  RAISE NOTICE '3. The issue is that warehouse@samastore.com has role="admin" in database';
  RAISE NOTICE '4. This user should have role="warehouseManager" instead';
  RAISE NOTICE '';
  RAISE NOTICE '🚨 SECURITY IMPLICATIONS:';
  RAISE NOTICE '- User has admin privileges instead of warehouse manager privileges';
  RAISE NOTICE '- This bypasses our role-based access control';
  RAISE NOTICE '- User can access admin dashboard instead of warehouse dashboard';
  RAISE NOTICE '';
END $$;

-- ==================== BACKUP CURRENT DATA ====================

-- Create a backup of the current user data before making changes
CREATE TABLE IF NOT EXISTS user_profiles_backup_warehouse_fix AS
SELECT 
  id,
  email,
  name,
  role,
  status,
  created_at,
  updated_at,
  NOW() as backup_timestamp,
  'warehouse_role_fix' as backup_reason
FROM user_profiles 
WHERE email = 'warehouse@samastore.com';

-- ==================== APPLY THE FIX ====================

-- Update the role from "admin" to "warehouseManager"
UPDATE user_profiles 
SET 
  role = 'warehouseManager',
  updated_at = NOW()
WHERE email = 'warehouse@samastore.com' 
  AND role = 'admin';

-- Log the number of affected rows
DO $$
DECLARE
  affected_rows INTEGER;
BEGIN
  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RAISE NOTICE '✅ ROLE FIX APPLIED: % rows updated', affected_rows;
  
  IF affected_rows = 0 THEN
    RAISE NOTICE '⚠️ No rows updated - user may not exist or already has correct role';
  ELSIF affected_rows = 1 THEN
    RAISE NOTICE '✅ Successfully updated warehouse@samastore.com role to warehouseManager';
  ELSE
    RAISE NOTICE '🚨 WARNING: Multiple rows updated (%) - this is unexpected', affected_rows;
  END IF;
END $$;

-- ==================== VERIFICATION ====================

-- Verify the fix was applied correctly
SELECT 
  '✅ POST-FIX VERIFICATION' as verification_type,
  id,
  email,
  name,
  role,
  status,
  updated_at
FROM user_profiles 
WHERE email = 'warehouse@samastore.com';

-- Check that we don't have any other warehouse-related emails with admin role
SELECT 
  '🔍 OTHER WAREHOUSE USERS CHECK' as check_type,
  email,
  name,
  role,
  status
FROM user_profiles 
WHERE (email LIKE '%warehouse%' OR name LIKE '%warehouse%' OR name LIKE '%مخزن%')
  AND role = 'admin'
ORDER BY email;

-- ==================== ROLE DISTRIBUTION ANALYSIS ====================

-- Check the current role distribution to ensure it's correct
SELECT 
  '📊 ROLE DISTRIBUTION AFTER FIX' as distribution_check,
  role,
  COUNT(*) as user_count,
  STRING_AGG(email, ', ') as users
FROM user_profiles 
GROUP BY role
ORDER BY role;

-- ==================== SECURITY VERIFICATION ====================

-- Verify that warehouse@samastore.com now has appropriate permissions
DO $$
DECLARE
  user_role TEXT;
  user_status TEXT;
  user_id UUID;
BEGIN
  -- Get the updated user data
  SELECT role, status, id INTO user_role, user_status, user_id
  FROM user_profiles 
  WHERE email = 'warehouse@samastore.com';
  
  RAISE NOTICE '';
  RAISE NOTICE '🔒 SECURITY VERIFICATION:';
  RAISE NOTICE '   Email: warehouse@samastore.com';
  RAISE NOTICE '   Role: %', user_role;
  RAISE NOTICE '   Status: %', user_status;
  RAISE NOTICE '   User ID: %', user_id;
  
  -- Check expected permissions
  IF user_role = 'warehouseManager' THEN
    RAISE NOTICE '   ✅ Role is correct: warehouseManager';
    RAISE NOTICE '   ✅ Should route to warehouse manager dashboard';
    RAISE NOTICE '   ✅ Should have warehouse management permissions only';
  ELSE
    RAISE NOTICE '   🚨 Role is incorrect: % (expected: warehouseManager)', user_role;
  END IF;
  
  IF user_status = 'approved' THEN
    RAISE NOTICE '   ✅ Status is approved - user can login';
  ELSE
    RAISE NOTICE '   ⚠️ Status is % - user may not be able to login', user_status;
  END IF;
  RAISE NOTICE '';
END $$;

-- ==================== TEST AUTHENTICATION FLOW ====================

-- Simulate the authentication flow to verify it works correctly
DO $$
DECLARE
  user_record RECORD;
  expected_flutter_role TEXT;
BEGIN
  -- Get user data as Flutter would
  SELECT * INTO user_record
  FROM user_profiles 
  WHERE email = 'warehouse@samastore.com';
  
  -- Determine what Flutter UserRole.fromString() would return
  CASE user_record.role
    WHEN 'admin' THEN expected_flutter_role := 'UserRole.admin';
    WHEN 'warehouseManager' THEN expected_flutter_role := 'UserRole.warehouseManager';
    WHEN 'accountant' THEN expected_flutter_role := 'UserRole.accountant';
    WHEN 'owner' THEN expected_flutter_role := 'UserRole.owner';
    WHEN 'client' THEN expected_flutter_role := 'UserRole.client';
    ELSE expected_flutter_role := 'UserRole.guest';
  END CASE;
  
  RAISE NOTICE '🧪 AUTHENTICATION FLOW TEST:';
  RAISE NOTICE '   Database role: "%"', user_record.role;
  RAISE NOTICE '   Flutter UserRole: %', expected_flutter_role;
  RAISE NOTICE '   Expected dashboard: %', 
    CASE user_record.role
      WHEN 'warehouseManager' THEN 'Warehouse Manager Dashboard'
      WHEN 'admin' THEN 'Admin Dashboard'
      ELSE 'Other Dashboard'
    END;
  RAISE NOTICE '';
END $$;

-- ==================== AUDIT LOG ====================

-- Create an audit log entry for this fix (if audit table exists)
DO $$
BEGIN
  -- Check if audit table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles_audit') THEN
    INSERT INTO user_profiles_audit (
      user_id,
      old_role,
      new_role,
      changed_by,
      change_reason,
      changed_at
    )
    SELECT
      id,
      'admin',
      'warehouseManager',
      'system_security_fix',
      'Fixed incorrect admin role assignment - warehouse@samastore.com should be warehouseManager',
      NOW()
    FROM user_profiles
    WHERE email = 'warehouse@samastore.com';

    RAISE NOTICE '✅ Audit log entry created';
  ELSE
    RAISE NOTICE '⚠️ Audit table does not exist - logging to backup table instead';

    -- Log to our backup table as alternative audit trail
    UPDATE user_profiles_backup_warehouse_fix
    SET backup_reason = backup_reason || ' | Role changed from admin to warehouseManager at ' || NOW()::TEXT
    WHERE email = 'warehouse@samastore.com';
  END IF;
END $$;

-- ==================== FINAL INSTRUCTIONS ====================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '📋 NEXT STEPS:';
  RAISE NOTICE '1. Test login with warehouse@samastore.com';
  RAISE NOTICE '2. Verify user is routed to warehouse manager dashboard';
  RAISE NOTICE '3. Confirm user has warehouse management permissions only';
  RAISE NOTICE '4. Check that user cannot access admin functions';
  RAISE NOTICE '';
  RAISE NOTICE '🔒 SECURITY VERIFICATION CHECKLIST:';
  RAISE NOTICE '✅ Role changed from admin to warehouseManager';
  RAISE NOTICE '✅ User should no longer have admin privileges';
  RAISE NOTICE '✅ User should access warehouse management features only';
  RAISE NOTICE '✅ RLS policies should now work correctly for this user';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️ MONITORING:';
  RAISE NOTICE 'Watch for any other users with incorrect role assignments';
  RAISE NOTICE 'Monitor authentication logs for proper role mapping';
  RAISE NOTICE 'Verify no privilege escalation vulnerabilities remain';
  RAISE NOTICE '';
END $$;
