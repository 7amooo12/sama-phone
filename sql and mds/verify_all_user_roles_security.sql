-- 🔍 COMPREHENSIVE USER ROLE SECURITY VERIFICATION
-- Check for any other users with potentially incorrect role assignments

-- ==================== SUSPICIOUS ROLE PATTERNS ====================

-- Check for users with warehouse-related emails but admin roles
SELECT 
  '🚨 WAREHOUSE EMAILS WITH ADMIN ROLE' as alert_type,
  email,
  name,
  role,
  status,
  created_at
FROM user_profiles 
WHERE (
  email LIKE '%warehouse%' OR 
  email LIKE '%مخزن%' OR 
  name LIKE '%warehouse%' OR 
  name LIKE '%مخزن%' OR
  name LIKE '%Warehouse%'
) AND role = 'admin'
ORDER BY created_at;

-- Check for users with admin-related emails but non-admin roles
SELECT 
  '🔍 ADMIN EMAILS WITH NON-ADMIN ROLE' as check_type,
  email,
  name,
  role,
  status,
  created_at
FROM user_profiles 
WHERE (
  email LIKE '%admin%' OR 
  email LIKE '%مدير%' OR 
  name LIKE '%admin%' OR 
  name LIKE '%مدير%' OR
  name LIKE '%Admin%'
) AND role != 'admin'
ORDER BY created_at;

-- Check for users with accountant-related emails but wrong roles
SELECT 
  '📊 ACCOUNTANT EMAILS WITH WRONG ROLE' as check_type,
  email,
  name,
  role,
  status,
  created_at
FROM user_profiles 
WHERE (
  email LIKE '%accountant%' OR 
  email LIKE '%محاسب%' OR 
  name LIKE '%accountant%' OR 
  name LIKE '%محاسب%' OR
  name LIKE '%Accountant%'
) AND role NOT IN ('accountant', 'admin')
ORDER BY created_at;

-- ==================== ROLE DISTRIBUTION ANALYSIS ====================

-- Overall role distribution
SELECT 
  '📊 CURRENT ROLE DISTRIBUTION' as analysis_type,
  role,
  COUNT(*) as user_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM user_profiles 
GROUP BY role
ORDER BY user_count DESC;

-- Users by status and role
SELECT 
  '📋 ROLE-STATUS MATRIX' as matrix_type,
  role,
  status,
  COUNT(*) as user_count
FROM user_profiles 
GROUP BY role, status
ORDER BY role, status;

-- ==================== ADMIN USERS VERIFICATION ====================

-- All admin users - verify they should have admin access
SELECT 
  '👑 ALL ADMIN USERS VERIFICATION' as admin_check,
  email,
  name,
  role,
  status,
  created_at,
  CASE 
    WHEN email LIKE '%admin%' OR email LIKE '%owner%' OR email LIKE '%sama%' THEN '✅ LEGITIMATE'
    WHEN email LIKE '%warehouse%' OR email LIKE '%worker%' OR email LIKE '%client%' THEN '🚨 SUSPICIOUS'
    ELSE '❓ REVIEW NEEDED'
  END as legitimacy_assessment
FROM user_profiles 
WHERE role = 'admin'
ORDER BY created_at;

-- ==================== WAREHOUSE MANAGER VERIFICATION ====================

-- All warehouse managers - verify they have correct role
SELECT 
  '🏭 ALL WAREHOUSE MANAGERS' as warehouse_check,
  email,
  name,
  role,
  status,
  created_at,
  CASE 
    WHEN email LIKE '%warehouse%' OR name LIKE '%warehouse%' OR name LIKE '%مخزن%' THEN '✅ APPROPRIATE'
    ELSE '❓ REVIEW NEEDED'
  END as appropriateness_check
FROM user_profiles 
WHERE role = 'warehouseManager'
ORDER BY created_at;

-- ==================== RECENT ROLE CHANGES ====================

-- Users created or updated in the last 30 days
SELECT 
  '📅 RECENT USER ACTIVITY' as activity_check,
  email,
  name,
  role,
  status,
  created_at,
  updated_at,
  CASE 
    WHEN updated_at > created_at + INTERVAL '1 hour' THEN '🔄 ROLE MODIFIED'
    ELSE '📝 ORIGINAL ROLE'
  END as change_indicator,
  EXTRACT(EPOCH FROM (COALESCE(updated_at, created_at) - created_at)) / 3600 as hours_since_creation
FROM user_profiles 
WHERE created_at > NOW() - INTERVAL '30 days' 
   OR updated_at > NOW() - INTERVAL '30 days'
ORDER BY COALESCE(updated_at, created_at) DESC;

-- ==================== SECURITY RISK ASSESSMENT ====================

-- High-risk role assignments
WITH risk_assessment AS (
  SELECT 
    email,
    name,
    role,
    status,
    CASE 
      -- High risk: Non-admin emails with admin role
      WHEN role = 'admin' AND NOT (
        email LIKE '%admin%' OR 
        email LIKE '%owner%' OR 
        email LIKE '%sama%' OR
        name LIKE '%admin%' OR 
        name LIKE '%owner%'
      ) THEN 'HIGH'
      
      -- Medium risk: Warehouse emails with non-warehouse roles
      WHEN (email LIKE '%warehouse%' OR name LIKE '%warehouse%') 
           AND role NOT IN ('warehouseManager', 'admin') THEN 'MEDIUM'
      
      -- Low risk: Everything else
      ELSE 'LOW'
    END as risk_level
  FROM user_profiles
)
SELECT 
  '🚨 SECURITY RISK ASSESSMENT' as risk_check,
  risk_level,
  COUNT(*) as user_count,
  STRING_AGG(email, ', ') as affected_users
FROM risk_assessment
WHERE risk_level != 'LOW'
GROUP BY risk_level
ORDER BY 
  CASE risk_level 
    WHEN 'HIGH' THEN 1 
    WHEN 'MEDIUM' THEN 2 
    ELSE 3 
  END;

-- ==================== PRIVILEGE ESCALATION CHECK ====================

-- Check for any signs of privilege escalation
SELECT 
  '🔒 PRIVILEGE ESCALATION CHECK' as escalation_check,
  email,
  name,
  role,
  status,
  created_at,
  updated_at,
  CASE 
    WHEN role = 'admin' AND updated_at > created_at + INTERVAL '1 minute' THEN '🚨 POTENTIAL ESCALATION'
    WHEN role = 'admin' AND created_at > NOW() - INTERVAL '7 days' THEN '⚠️ RECENT ADMIN'
    ELSE '✅ NORMAL'
  END as escalation_risk
FROM user_profiles 
WHERE role = 'admin'
ORDER BY created_at DESC;

-- ==================== RECOMMENDATIONS ====================

DO $$
DECLARE
  admin_count INTEGER;
  warehouse_admin_count INTEGER;
  suspicious_count INTEGER;
BEGIN
  -- Count various user categories
  SELECT COUNT(*) INTO admin_count FROM user_profiles WHERE role = 'admin';
  
  SELECT COUNT(*) INTO warehouse_admin_count 
  FROM user_profiles 
  WHERE role = 'admin' AND (email LIKE '%warehouse%' OR name LIKE '%warehouse%');
  
  SELECT COUNT(*) INTO suspicious_count
  FROM user_profiles 
  WHERE role = 'admin' AND NOT (
    email LIKE '%admin%' OR 
    email LIKE '%owner%' OR 
    email LIKE '%sama%' OR
    name LIKE '%admin%' OR 
    name LIKE '%owner%'
  );
  
  RAISE NOTICE '';
  RAISE NOTICE '📊 SECURITY ANALYSIS SUMMARY:';
  RAISE NOTICE '   Total admin users: %', admin_count;
  RAISE NOTICE '   Warehouse users with admin role: %', warehouse_admin_count;
  RAISE NOTICE '   Suspicious admin assignments: %', suspicious_count;
  RAISE NOTICE '';
  
  IF warehouse_admin_count > 0 THEN
    RAISE NOTICE '🚨 ACTION REQUIRED: % warehouse users have admin role', warehouse_admin_count;
    RAISE NOTICE '   These should likely be warehouseManager role instead';
  END IF;
  
  IF suspicious_count > 0 THEN
    RAISE NOTICE '⚠️ REVIEW NEEDED: % users have suspicious admin role assignments', suspicious_count;
    RAISE NOTICE '   Manual review recommended for these accounts';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '🔒 SECURITY RECOMMENDATIONS:';
  RAISE NOTICE '1. Review all admin users for legitimacy';
  RAISE NOTICE '2. Ensure warehouse users have warehouseManager role';
  RAISE NOTICE '3. Monitor for unauthorized role escalations';
  RAISE NOTICE '4. Implement role change audit logging';
  RAISE NOTICE '5. Regular security audits of user roles';
  RAISE NOTICE '';
END $$;
