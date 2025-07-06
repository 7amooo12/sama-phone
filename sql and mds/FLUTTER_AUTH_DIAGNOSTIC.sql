-- =====================================================
-- FLUTTER APP AUTHENTICATION DIAGNOSTIC
-- =====================================================
-- This script helps diagnose why Flutter app fails with RLS
-- while SQL Editor tests succeed
-- =====================================================

-- =====================================================
-- 1. CHECK ALL REGISTERED USERS
-- =====================================================

-- Show all users in auth.users table
SELECT 
    'ALL AUTH USERS:' as section,
    id,
    email,
    email_confirmed_at,
    created_at,
    updated_at,
    last_sign_in_at
FROM auth.users 
ORDER BY created_at DESC;

-- Show all user profiles
SELECT 
    'ALL USER PROFILES:' as section,
    up.id,
    up.email,
    up.name,
    up.role,
    up.status,
    up.created_at,
    CASE 
        WHEN au.id IS NOT NULL THEN 'EXISTS'
        ELSE 'MISSING'
    END as auth_user_exists
FROM public.user_profiles up
LEFT JOIN auth.users au ON up.id = au.id
ORDER BY up.created_at DESC;

-- =====================================================
-- 2. IDENTIFY AUTHENTICATION ISSUES
-- =====================================================

-- Find users with missing profiles
SELECT 
    'USERS WITHOUT PROFILES:' as section,
    au.id,
    au.email,
    au.created_at,
    'Missing user profile - this will cause RLS failures' as issue
FROM auth.users au
LEFT JOIN public.user_profiles up ON au.id = up.id
WHERE up.id IS NULL;

-- Find profiles without auth users
SELECT 
    'PROFILES WITHOUT AUTH USERS:' as section,
    up.id,
    up.email,
    up.name,
    'Orphaned profile - user cannot authenticate' as issue
FROM public.user_profiles up
LEFT JOIN auth.users au ON up.id = au.id
WHERE au.id IS NULL;

-- Find users with unapproved status
SELECT 
    'UNAPPROVED USERS:' as section,
    up.id,
    up.email,
    up.name,
    up.role,
    up.status,
    'Status not approved - will fail RLS policies' as issue
FROM public.user_profiles up
WHERE up.status != 'approved';

-- =====================================================
-- 3. CHECK SPECIFIC KNOWN USERS
-- =====================================================

-- Check the known registered accounts from memory
SELECT 
    'KNOWN ACCOUNT CHECK:' as section,
    email,
    CASE 
        WHEN EXISTS (SELECT 1 FROM auth.users WHERE auth.users.email = known_emails.email) THEN 'EXISTS IN AUTH'
        ELSE 'MISSING FROM AUTH'
    END as auth_status,
    CASE 
        WHEN EXISTS (SELECT 1 FROM public.user_profiles WHERE user_profiles.email = known_emails.email) THEN 'HAS PROFILE'
        ELSE 'NO PROFILE'
    END as profile_status
FROM (VALUES 
    ('admin@sama.com'),
    ('admin@samastore.com'),
    ('accountant@sama.com'),
    ('owner@sama.com'),
    ('client@sama.com'),
    ('worker@sama.com'),
    ('hima@sama.com'),
    ('testw@sama.com'),
    ('eslam@sama.com'),
    ('test@sama.com'),
    ('cust@sama.com')
) AS known_emails(email);

-- =====================================================
-- 4. CREATE MISSING PROFILES FOR AUTH USERS
-- =====================================================

-- Insert missing profiles for auth users
INSERT INTO public.user_profiles (
    id,
    email,
    name,
    role,
    status,
    created_at,
    updated_at
)
SELECT 
    au.id,
    au.email,
    COALESCE(au.raw_user_meta_data->>'name', SPLIT_PART(au.email, '@', 1)),
    CASE 
        WHEN au.email LIKE '%admin%' THEN 'admin'
        WHEN au.email LIKE '%owner%' THEN 'owner'
        WHEN au.email LIKE '%accountant%' THEN 'accountant'
        WHEN au.email LIKE '%worker%' THEN 'worker'
        ELSE 'client'
    END,
    'approved',
    NOW(),
    NOW()
FROM auth.users au
LEFT JOIN public.user_profiles up ON au.id = up.id
WHERE up.id IS NULL;

-- =====================================================
-- 5. UPDATE UNAPPROVED USERS TO APPROVED
-- =====================================================

-- Approve all existing users for testing
UPDATE public.user_profiles 
SET 
    status = 'approved',
    updated_at = NOW()
WHERE status != 'approved';

-- =====================================================
-- 6. VERIFY FIXES
-- =====================================================

-- Show all users after fixes
SELECT 
    'USERS AFTER FIXES:' as section,
    up.id,
    up.email,
    up.name,
    up.role,
    up.status,
    CASE 
        WHEN au.id IS NOT NULL THEN 'AUTH OK'
        ELSE 'AUTH MISSING'
    END as auth_status
FROM public.user_profiles up
LEFT JOIN auth.users au ON up.id = au.id
ORDER BY up.role, up.created_at DESC;

-- Count users by role and status
SELECT 
    'USER SUMMARY:' as section,
    role,
    status,
    COUNT(*) as user_count
FROM public.user_profiles 
GROUP BY role, status
ORDER BY role, status;

-- =====================================================
-- 7. TEST RLS POLICIES WITH SAMPLE USER
-- =====================================================

-- Test RLS policy conditions for each user type
SELECT 
    'RLS POLICY TEST:' as section,
    up.id,
    up.email,
    up.role,
    up.status,
    CASE 
        WHEN up.role = 'admin' AND up.status = 'approved' THEN 'SHOULD PASS ADMIN POLICY'
        WHEN up.role = 'owner' AND up.status = 'approved' THEN 'SHOULD PASS OWNER POLICY'
        WHEN up.role = 'accountant' AND up.status = 'approved' THEN 'SHOULD PASS ACCOUNTANT POLICY'
        WHEN up.role = 'client' AND up.status = 'approved' THEN 'SHOULD PASS CLIENT POLICY'
        WHEN up.role = 'worker' AND up.status = 'approved' THEN 'SHOULD PASS WORKER POLICY'
        ELSE 'MAY FAIL RLS POLICIES'
    END as rls_prediction
FROM public.user_profiles up
ORDER BY up.role, up.email;

-- =====================================================
-- 8. SHOW CURRENT RLS POLICIES
-- =====================================================

-- Display current RLS policies for reference
SELECT 
    'CURRENT RLS POLICIES:' as section,
    policyname,
    cmd as command,
    roles,
    CASE 
        WHEN qual LIKE '%admin%' THEN 'ADMIN POLICY'
        WHEN qual LIKE '%owner%' THEN 'OWNER POLICY'
        WHEN qual LIKE '%accountant%' THEN 'ACCOUNTANT POLICY'
        WHEN qual LIKE '%client%' THEN 'CLIENT POLICY'
        WHEN qual LIKE '%worker%' THEN 'WORKER POLICY'
        ELSE 'OTHER POLICY'
    END as policy_type
FROM pg_policies 
WHERE tablename = 'client_orders' 
AND schemaname = 'public'
ORDER BY policyname;

-- =====================================================
-- 9. FLUTTER APP TESTING GUIDANCE
-- =====================================================

SELECT 
    'FLUTTER APP TESTING STEPS:' as section,
    '1. Login with any of the approved users shown above' as step_1,
    '2. Verify user authentication in Flutter app' as step_2,
    '3. Check that auth.uid() returns the user ID' as step_3,
    '4. Test order creation - should now work' as step_4;

-- Show recommended test users
SELECT 
    'RECOMMENDED TEST USERS:' as section,
    email,
    role,
    'Use this user for testing in Flutter app' as recommendation
FROM public.user_profiles 
WHERE status = 'approved'
AND role IN ('admin', 'client')
ORDER BY role, created_at DESC
LIMIT 5;

-- =====================================================
-- 10. TROUBLESHOOTING CHECKLIST
-- =====================================================

SELECT 
    'TROUBLESHOOTING CHECKLIST:' as section,
    'If Flutter app still fails after this fix:' as issue,
    '1. Check user is actually logged in (not just registered)' as check_1,
    '2. Verify Supabase client initialization in Flutter' as check_2,
    '3. Check JWT token validity in Flutter app' as check_3,
    '4. Ensure user session is not expired' as check_4,
    '5. Test with different user accounts' as check_5;

-- =====================================================
-- DIAGNOSTIC COMPLETE
-- =====================================================

SELECT 'FLUTTER AUTHENTICATION DIAGNOSTIC COMPLETED' as status;
SELECT 'All users should now have proper profiles and approved status' as result;
SELECT 'Flutter app order creation should work after user login' as next_step;
