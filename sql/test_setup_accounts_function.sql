-- Test script for the fixed setup_test_accounts() function
-- Run this to verify the function works correctly

-- 1. Test the function execution
SELECT 'TESTING SETUP_TEST_ACCOUNTS FUNCTION' as test_step;

-- 2. Run the function
SELECT setup_test_accounts() as function_result;

-- 3. Verify all test accounts were created/updated
SELECT 
    'VERIFICATION OF TEST ACCOUNTS' as verification_step,
    email,
    name,
    role,
    status,
    email_confirmed,
    CASE 
        WHEN status = 'active' AND email_confirmed = true THEN 'READY'
        ELSE 'NOT_READY'
    END as login_ready
FROM user_profiles 
WHERE email IN (
    'eslam@sama.com',
    'admin@sama.com', 
    'hima@sama.com',
    'worker@sama.com',
    'test@sama.com'
)
ORDER BY role, email;

-- 4. Count test accounts by role
SELECT 
    'ACCOUNT COUNT BY ROLE' as count_step,
    role,
    COUNT(*) as account_count
FROM user_profiles 
WHERE email LIKE '%@sama.com'
GROUP BY role
ORDER BY role;

-- 5. Check for any accounts that might need attention
SELECT 
    'ACCOUNTS NEEDING ATTENTION' as attention_step,
    email,
    name,
    role,
    status,
    email_confirmed,
    CASE 
        WHEN status != 'active' THEN 'Status not active'
        WHEN email_confirmed != true THEN 'Email not confirmed'
        ELSE 'Unknown issue'
    END as issue
FROM user_profiles 
WHERE email LIKE '%@sama.com'
AND (status != 'active' OR email_confirmed != true);

-- 6. Test specific eslam@sama.com account
SELECT 
    'ESLAM ACCOUNT VERIFICATION' as eslam_check,
    id,
    name,
    email,
    role,
    status,
    email_confirmed,
    email_confirmed_at,
    created_at,
    updated_at
FROM user_profiles 
WHERE email = 'eslam@sama.com';

-- 7. Show success message
SELECT 
    'FUNCTION TEST COMPLETED' as completion_status,
    'If no errors appeared above, the function is working correctly' as result,
    'All @sama.com test accounts should now be ready for authentication' as note;
