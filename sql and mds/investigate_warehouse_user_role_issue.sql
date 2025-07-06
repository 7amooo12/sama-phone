-- 🔍 CRITICAL INVESTIGATION: warehouse@samastore.com Role Assignment Issue
-- Investigating why warehouse manager is getting admin role instead of warehouseManager

-- ==================== 1. DATABASE ROLE VERIFICATION ====================

-- Check the actual role stored for warehouse@samastore.com
SELECT 
  '🔍 WAREHOUSE USER ROLE CHECK' as investigation_type,
  id,
  email,
  name,
  role,
  status,
  created_at,
  updated_at
FROM user_profiles 
WHERE email = 'warehouse@samastore.com';

-- Check if there are multiple entries for this email
SELECT 
  '📊 DUPLICATE EMAIL CHECK' as check_type,
  COUNT(*) as total_entries,
  STRING_AGG(DISTINCT role, ', ') as all_roles,
  STRING_AGG(DISTINCT status, ', ') as all_statuses
FROM user_profiles 
WHERE email = 'warehouse@samastore.com';

-- ==================== 2. ROLE HISTORY ANALYSIS ====================

-- Check if there's any audit trail or history of role changes
-- (This assumes there might be an audit table or updated_at tracking)
SELECT 
  '📋 ROLE CHANGE HISTORY' as history_type,
  email,
  role,
  status,
  updated_at,
  created_at,
  CASE 
    WHEN updated_at > created_at THEN 'ROLE MODIFIED'
    ELSE 'ORIGINAL ROLE'
  END as change_status
FROM user_profiles 
WHERE email = 'warehouse@samastore.com'
ORDER BY updated_at DESC;

-- ==================== 3. ADMIN ROLE ANALYSIS ====================

-- Check all users with admin role to see if warehouse user was incorrectly promoted
SELECT 
  '👑 ALL ADMIN USERS' as admin_check,
  email,
  name,
  role,
  status,
  created_at,
  CASE 
    WHEN email LIKE '%warehouse%' THEN '🚨 SUSPICIOUS'
    WHEN email LIKE '%admin%' THEN '✅ EXPECTED'
    WHEN email LIKE '%owner%' THEN '✅ EXPECTED'
    ELSE '❓ REVIEW NEEDED'
  END as legitimacy_check
FROM user_profiles 
WHERE role = 'admin'
ORDER BY created_at;

-- ==================== 4. WAREHOUSE MANAGER ROLE CHECK ====================

-- Check all users with warehouseManager role
SELECT 
  '🏭 ALL WAREHOUSE MANAGERS' as warehouse_check,
  email,
  name,
  role,
  status,
  created_at
FROM user_profiles 
WHERE role = 'warehouseManager'
ORDER BY created_at;

-- ==================== 5. AUTHENTICATION TABLE CHECK ====================

-- Check Supabase auth.users table for this user
SELECT 
  '🔐 AUTH TABLE CHECK' as auth_check,
  id,
  email,
  email_confirmed_at,
  created_at,
  updated_at,
  last_sign_in_at
FROM auth.users 
WHERE email = 'warehouse@samastore.com';

-- ==================== 6. TRIGGER AND FUNCTION ANALYSIS ====================

-- Check for any triggers that might be auto-promoting users to admin
SELECT 
  '🔧 TRIGGER ANALYSIS' as trigger_check,
  trigger_name,
  event_manipulation,
  action_statement,
  action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'user_profiles'
ORDER BY trigger_name;

-- Check for any functions that might modify user roles
SELECT 
  '⚙️ FUNCTION ANALYSIS' as function_check,
  routine_name,
  routine_type,
  routine_definition
FROM information_schema.routines 
WHERE routine_definition ILIKE '%admin%' 
   OR routine_definition ILIKE '%role%'
   OR routine_definition ILIKE '%user_profiles%'
ORDER BY routine_name;

-- ==================== 7. RECENT ROLE CHANGES ====================

-- Check for any recent role changes (last 7 days)
SELECT 
  '📅 RECENT ROLE CHANGES' as recent_changes,
  email,
  role,
  status,
  updated_at,
  created_at,
  EXTRACT(EPOCH FROM (updated_at - created_at)) / 3600 as hours_between_create_update
FROM user_profiles 
WHERE updated_at > NOW() - INTERVAL '7 days'
   OR created_at > NOW() - INTERVAL '7 days'
ORDER BY updated_at DESC;

-- ==================== 8. SECURITY POLICY CHECK ====================

-- Check if our recent RLS policies might be affecting role assignment
SELECT 
  '🛡️ RLS POLICY CHECK' as policy_check,
  schemaname,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN with_check LIKE '%admin%' THEN '⚠️ ADMIN RELATED'
    WHEN with_check LIKE '%role%' THEN '📋 ROLE RELATED'
    ELSE '✅ NORMAL'
  END as policy_type
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- ==================== 9. EMERGENCY ROLE CORRECTION ====================

-- Prepare corrective action (DO NOT EXECUTE YET - FOR REVIEW ONLY)
-- This will be used if we confirm the role should be warehouseManager

/*
-- EMERGENCY FIX (Uncomment only after confirming the issue)
UPDATE user_profiles 
SET 
  role = 'warehouseManager',
  updated_at = NOW()
WHERE email = 'warehouse@samastore.com' 
  AND role = 'admin';

-- Log the correction
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
  'system_correction',
  'Fixed incorrect admin role assignment for warehouse manager',
  NOW()
FROM user_profiles 
WHERE email = 'warehouse@samastore.com';
*/

-- ==================== 10. VERIFICATION QUERIES ====================

-- After any fix, use these to verify the correction
SELECT 
  '✅ POST-FIX VERIFICATION' as verification_type,
  email,
  role,
  status,
  updated_at
FROM user_profiles 
WHERE email = 'warehouse@samastore.com';

-- Check role distribution to ensure it's correct
SELECT 
  '📊 ROLE DISTRIBUTION' as distribution_check,
  role,
  COUNT(*) as user_count,
  STRING_AGG(email, ', ') as users
FROM user_profiles 
GROUP BY role
ORDER BY role;

-- ==================== INVESTIGATION SUMMARY ====================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🔍 INVESTIGATION SUMMARY FOR warehouse@samastore.com:';
  RAISE NOTICE '1. Check actual role in database';
  RAISE NOTICE '2. Verify if role was changed recently';
  RAISE NOTICE '3. Look for triggers/functions that might auto-promote to admin';
  RAISE NOTICE '4. Check if this is related to our recent security fixes';
  RAISE NOTICE '5. Prepare corrective action if needed';
  RAISE NOTICE '';
  RAISE NOTICE '🚨 SECURITY IMPLICATIONS:';
  RAISE NOTICE '- If warehouse manager has admin role, they have excessive privileges';
  RAISE NOTICE '- This could bypass our RLS policies';
  RAISE NOTICE '- May indicate privilege escalation vulnerability';
  RAISE NOTICE '';
  RAISE NOTICE '📋 NEXT STEPS:';
  RAISE NOTICE '1. Review query results above';
  RAISE NOTICE '2. Determine root cause (data vs code issue)';
  RAISE NOTICE '3. Apply corrective action if needed';
  RAISE NOTICE '4. Update authentication code if logic error found';
  RAISE NOTICE '';
END $$;
