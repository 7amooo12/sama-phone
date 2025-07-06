-- Test script to verify the comprehensive diagnostic query works
-- Run this first to check for any syntax errors

-- Simple test query to verify table structure
SELECT 
    'TESTING TABLE ACCESS' as test_step,
    COUNT(*) as total_users_in_profiles
FROM user_profiles;

-- Test auth.users table access (may not work in all environments)
SELECT 
    'TESTING AUTH TABLE ACCESS' as test_step,
    COUNT(*) as total_users_in_auth
FROM auth.users;

-- Test the join between tables
SELECT 
    'TESTING TABLE JOIN' as test_step,
    COUNT(up.id) as profiles_count,
    COUNT(au.id) as auth_count,
    COUNT(CASE WHEN up.id IS NOT NULL AND au.id IS NOT NULL THEN 1 END) as matched_count
FROM user_profiles up
FULL OUTER JOIN auth.users au ON up.id = au.id;

-- Test specific eslam@sama.com lookup
SELECT 
    'TESTING ESLAM LOOKUP' as test_step,
    CASE 
        WHEN COUNT(*) > 0 THEN 'FOUND'
        ELSE 'NOT_FOUND'
    END as eslam_status
FROM user_profiles 
WHERE email = 'eslam@sama.com';

-- Test @sama.com accounts lookup
SELECT 
    'TESTING SAMA.COM ACCOUNTS' as test_step,
    COUNT(*) as sama_accounts_count
FROM user_profiles 
WHERE email LIKE '%@sama.com';

SELECT 
    'DIAGNOSTIC QUERY TEST COMPLETED' as result,
    'If no errors appeared above, the main diagnostic query should work' as status;
