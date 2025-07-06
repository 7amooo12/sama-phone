-- Test script to verify user loading for voucher assignment
-- Run this in Supabase SQL Editor to check if clients exist and are properly configured

-- 1. Check all users in the system
SELECT 
    id,
    name,
    email,
    role,
    status,
    created_at,
    CASE 
        WHEN status = 'approved' OR status = 'active' OR role = 'admin' THEN 'YES'
        ELSE 'NO'
    END as is_approved
FROM user_profiles
ORDER BY role, name;

-- 2. Check specifically for client users
SELECT 
    id,
    name,
    email,
    role,
    status,
    created_at,
    CASE 
        WHEN status = 'approved' OR status = 'active' THEN 'APPROVED'
        ELSE 'NOT_APPROVED'
    END as approval_status
FROM user_profiles
WHERE role = 'client'
ORDER BY name;

-- 3. Count users by role and status
SELECT 
    role,
    status,
    COUNT(*) as count
FROM user_profiles
GROUP BY role, status
ORDER BY role, status;

-- 4. Check if there are any approved clients
SELECT 
    COUNT(*) as approved_clients_count
FROM user_profiles
WHERE role = 'client' 
AND (status = 'approved' OR status = 'active');

-- 5. Check RLS policies for user_profiles table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_profiles';

-- 6. Test the exact query that the app uses
SELECT *
FROM user_profiles
WHERE role = 'client'
AND (status = 'approved' OR status = 'active')
ORDER BY name;
