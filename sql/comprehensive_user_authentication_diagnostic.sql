-- Comprehensive User Authentication Diagnostic Query for SmartBizTracker
-- This query analyzes all users and their authentication status to troubleshoot login issues

-- ========================================
-- 1. COMPLETE USER PROFILE ANALYSIS
-- ========================================

SELECT 
    '=== COMPLETE USER PROFILE ANALYSIS ===' as section_header;

SELECT 
    up.id as user_id,
    up.name,
    up.email,
    up.role,
    up.status,
    up.email_confirmed,
    up.email_confirmed_at,
    up.created_at,
    up.updated_at,
    
    -- Authentication status analysis
    CASE 
        WHEN au.id IS NOT NULL THEN 'EXISTS_IN_AUTH'
        ELSE 'MISSING_FROM_AUTH'
    END as auth_table_status,
    
    au.email_confirmed_at as auth_email_confirmed_at,
    au.last_sign_in_at,
    
    -- Login readiness analysis
    CASE 
        WHEN up.status IN ('active', 'approved') AND up.email_confirmed = true THEN 'READY_FOR_LOGIN'
        WHEN up.status NOT IN ('active', 'approved') THEN 'STATUS_NOT_APPROVED'
        WHEN up.email_confirmed != true THEN 'EMAIL_NOT_CONFIRMED'
        ELSE 'NEEDS_ATTENTION'
    END as login_readiness,
    
    -- Special flags for test accounts
    CASE 
        WHEN up.email LIKE '%@sama.com' THEN 'TEST_ACCOUNT'
        ELSE 'REGULAR_ACCOUNT'
    END as account_type,
    
    -- Days since creation
    EXTRACT(DAY FROM (NOW() - up.created_at)) as days_since_creation

FROM user_profiles up
LEFT JOIN auth.users au ON up.id = au.id
ORDER BY up.role, up.email;

-- ========================================
-- 2. FOCUS ON @SAMA.COM TEST ACCOUNTS
-- ========================================

SELECT 
    '=== @SAMA.COM TEST ACCOUNTS ANALYSIS ===' as section_header;

SELECT 
    up.email,
    up.name,
    up.role,
    up.status,
    up.email_confirmed,
    up.email_confirmed_at,
    
    -- Auth table presence
    CASE 
        WHEN au.id IS NOT NULL THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as in_auth_table,
    
    -- Email confirmation in auth
    CASE 
        WHEN au.email_confirmed_at IS NOT NULL THEN '✅ CONFIRMED'
        ELSE '❌ NOT_CONFIRMED'
    END as auth_email_status,
    
    -- Overall login status
    CASE 
        WHEN up.status IN ('active', 'approved') AND up.email_confirmed = true THEN '🟢 READY'
        WHEN up.status NOT IN ('active', 'approved') THEN '🔴 STATUS_ISSUE'
        WHEN up.email_confirmed != true THEN '🟡 EMAIL_ISSUE'
        ELSE '🔴 UNKNOWN_ISSUE'
    END as login_status,
    
    -- Specific issues
    CASE 
        WHEN up.status NOT IN ('active', 'approved') THEN 'Status is: ' || up.status || ' (needs active/approved)'
        WHEN up.email_confirmed != true THEN 'Email not confirmed in user_profiles'
        WHEN au.id IS NULL THEN 'Missing from auth.users table'
        WHEN au.email_confirmed_at IS NULL THEN 'Email not confirmed in auth.users'
        ELSE 'No issues detected'
    END as specific_issue

FROM user_profiles up
LEFT JOIN auth.users au ON up.id = au.id
WHERE up.email LIKE '%@sama.com'
ORDER BY up.role, up.email;

-- ========================================
-- 3. SUMMARY STATISTICS
-- ========================================

SELECT 
    '=== SUMMARY STATISTICS ===' as section_header;

-- Count by role
SELECT
    'USERS BY ROLE' as metric_type,
    up.role,
    COUNT(*) as count,
    COUNT(CASE WHEN up.status IN ('active', 'approved') THEN 1 END) as approved_count,
    COUNT(CASE WHEN up.email_confirmed = true THEN 1 END) as email_confirmed_count
FROM user_profiles up
GROUP BY up.role
ORDER BY up.role;

-- Count by status
SELECT
    'USERS BY STATUS' as metric_type,
    up.status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM user_profiles), 2) as percentage
FROM user_profiles up
GROUP BY up.status
ORDER BY count DESC;

-- Login readiness summary
SELECT
    'LOGIN READINESS SUMMARY' as metric_type,
    COUNT(*) as total_users,
    COUNT(CASE WHEN up.status IN ('active', 'approved') AND up.email_confirmed = true THEN 1 END) as ready_for_login,
    COUNT(CASE WHEN up.status NOT IN ('active', 'approved') THEN 1 END) as status_issues,
    COUNT(CASE WHEN up.email_confirmed != true THEN 1 END) as email_issues,
    COUNT(CASE WHEN up.email LIKE '%@sama.com' THEN 1 END) as test_accounts
FROM user_profiles up;

-- ========================================
-- 4. AUTHENTICATION ISSUES ANALYSIS
-- ========================================

SELECT 
    '=== AUTHENTICATION ISSUES ANALYSIS ===' as section_header;

-- Users with authentication problems
SELECT 
    'USERS WITH AUTH PROBLEMS' as issue_category,
    up.email,
    up.name,
    up.role,
    up.status,
    up.email_confirmed,
    
    -- List all issues
    ARRAY_TO_STRING(ARRAY[
        CASE WHEN up.status NOT IN ('active', 'approved') THEN 'Status: ' || up.status END,
        CASE WHEN up.email_confirmed != true THEN 'Email not confirmed in profiles' END,
        CASE WHEN au.id IS NULL THEN 'Missing from auth.users' END,
        CASE WHEN au.email_confirmed_at IS NULL THEN 'Email not confirmed in auth' END
    ]::TEXT[], ' | ') as issues_found

FROM user_profiles up
LEFT JOIN auth.users au ON up.id = au.id
WHERE 
    up.status NOT IN ('active', 'approved') 
    OR up.email_confirmed != true 
    OR au.id IS NULL 
    OR au.email_confirmed_at IS NULL
ORDER BY up.email LIKE '%@sama.com' DESC, up.role, up.email;

-- ========================================
-- 5. SPECIFIC ESLAM@SAMA.COM ANALYSIS
-- ========================================

SELECT 
    '=== ESLAM@SAMA.COM SPECIFIC ANALYSIS ===' as section_header;

SELECT 
    'ESLAM ACCOUNT DETAILS' as analysis_type,
    up.id,
    up.name,
    up.email,
    up.role,
    up.status,
    up.email_confirmed,
    up.email_confirmed_at,
    up.created_at,
    up.updated_at,
    
    -- Auth table details
    au.id as auth_user_id,
    au.email_confirmed_at as auth_email_confirmed,
    au.last_sign_in_at,
    au.created_at as auth_created_at,
    
    -- Diagnosis
    CASE 
        WHEN up.id IS NULL THEN '❌ USER DOES NOT EXIST'
        WHEN up.status NOT IN ('active', 'approved') THEN '❌ STATUS ISSUE: ' || up.status
        WHEN up.email_confirmed != true THEN '❌ EMAIL NOT CONFIRMED IN PROFILES'
        WHEN au.id IS NULL THEN '❌ MISSING FROM AUTH.USERS'
        WHEN au.email_confirmed_at IS NULL THEN '❌ EMAIL NOT CONFIRMED IN AUTH'
        ELSE '✅ ACCOUNT LOOKS GOOD'
    END as diagnosis

FROM user_profiles up
FULL OUTER JOIN auth.users au ON up.email = au.email
WHERE COALESCE(up.email, au.email) = 'eslam@sama.com';

-- ========================================
-- 6. RECOMMENDED ACTIONS
-- ========================================

SELECT 
    '=== RECOMMENDED ACTIONS ===' as section_header;

SELECT 
    'RECOMMENDED FIXES' as action_type,
    'Run the following commands to fix authentication issues:' as description,
    '1. Execute fix_eslam_user_authentication.sql script' as step_1,
    '2. Run setup_test_accounts() function' as step_2,
    '3. Verify all @sama.com accounts have status=active' as step_3,
    '4. Check Supabase project configuration' as step_4,
    '5. Test authentication with Flutter app' as step_5;

-- Show accounts that need immediate attention
SELECT
    'ACCOUNTS NEEDING IMMEDIATE ATTENTION' as priority_action,
    up.email,
    up.role,
    up.status,
    up.email_confirmed,
    'UPDATE user_profiles SET status=''active'', email_confirmed=true WHERE email=''' || up.email || ''';' as fix_sql
FROM user_profiles up
WHERE up.email LIKE '%@sama.com'
AND (up.status NOT IN ('active', 'approved') OR up.email_confirmed != true)
ORDER BY up.email;
