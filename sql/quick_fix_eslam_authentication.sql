-- Quick Fix for eslam@sama.com Authentication Issue
-- Run this script to immediately resolve the "Invalid login credentials" error

-- ========================================
-- 1. IMMEDIATE FIX FOR ESLAM@SAMA.COM
-- ========================================

-- Check current status
SELECT 
    'BEFORE FIX - Current Status' as step,
    email,
    name,
    role,
    status,
    email_confirmed,
    email_confirmed_at
FROM user_profiles 
WHERE email = 'eslam@sama.com';

-- Create or update eslam@sama.com user
INSERT INTO user_profiles (
    id,
    name,
    email,
    phone_number,
    role,
    status,
    email_confirmed,
    email_confirmed_at,
    created_at,
    updated_at
)
VALUES (
    gen_random_uuid(),
    'إسلام',
    'eslam@sama.com',
    '+201234567890',
    'owner',
    'active',
    true,
    NOW(),
    NOW(),
    NOW()
)
ON CONFLICT (email) 
DO UPDATE SET
    name = 'إسلام',
    role = 'owner',
    status = 'active',
    email_confirmed = true,
    email_confirmed_at = COALESCE(user_profiles.email_confirmed_at, NOW()),
    updated_at = NOW();

-- Verify the fix
SELECT 
    'AFTER FIX - Updated Status' as step,
    email,
    name,
    role,
    status,
    email_confirmed,
    email_confirmed_at,
    CASE 
        WHEN status = 'active' AND email_confirmed = true THEN '✅ READY FOR LOGIN'
        ELSE '❌ STILL HAS ISSUES'
    END as login_status
FROM user_profiles 
WHERE email = 'eslam@sama.com';

-- ========================================
-- 2. FIX ALL @SAMA.COM TEST ACCOUNTS
-- ========================================

-- Update all existing @sama.com accounts to be active and email confirmed
UPDATE user_profiles 
SET 
    status = 'active',
    email_confirmed = true,
    email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
    updated_at = NOW()
WHERE email LIKE '%@sama.com';

-- Insert missing test accounts if they don't exist
INSERT INTO user_profiles (id, name, email, role, status, email_confirmed, email_confirmed_at, created_at, updated_at)
VALUES 
    (gen_random_uuid(), 'أدمن', 'admin@sama.com', 'admin', 'active', true, NOW(), NOW(), NOW()),
    (gen_random_uuid(), 'هيما', 'hima@sama.com', 'accountant', 'active', true, NOW(), NOW(), NOW()),
    (gen_random_uuid(), 'عامل', 'worker@sama.com', 'worker', 'active', true, NOW(), NOW(), NOW()),
    (gen_random_uuid(), 'عميل تجريبي', 'test@sama.com', 'client', 'active', true, NOW(), NOW(), NOW()),
    (gen_random_uuid(), 'عامل تجريبي', 'testw@sama.com', 'worker', 'active', true, NOW(), NOW(), NOW()),
    (gen_random_uuid(), 'عميل', 'cust@sama.com', 'client', 'active', true, NOW(), NOW(), NOW())
ON CONFLICT (email) DO NOTHING;

-- ========================================
-- 3. VERIFICATION
-- ========================================

-- Show all @sama.com accounts after fix
SELECT 
    'ALL @SAMA.COM ACCOUNTS AFTER FIX' as verification_step,
    email,
    name,
    role,
    status,
    email_confirmed,
    CASE 
        WHEN status = 'active' AND email_confirmed = true THEN '✅ READY'
        ELSE '❌ NEEDS ATTENTION'
    END as login_ready
FROM user_profiles 
WHERE email LIKE '%@sama.com'
ORDER BY role, email;

-- Count summary
SELECT 
    'SUMMARY AFTER FIX' as summary,
    COUNT(*) as total_sama_accounts,
    COUNT(CASE WHEN status = 'active' AND email_confirmed = true THEN 1 END) as ready_accounts,
    COUNT(CASE WHEN status != 'active' OR email_confirmed != true THEN 1 END) as problem_accounts
FROM user_profiles 
WHERE email LIKE '%@sama.com';

-- ========================================
-- 4. SUCCESS MESSAGE
-- ========================================

SELECT 
    'FIX COMPLETED' as status,
    'eslam@sama.com and all @sama.com test accounts have been fixed' as message,
    'All accounts should now be ready for authentication' as result,
    'Try logging in with eslam@sama.com again' as next_step;
