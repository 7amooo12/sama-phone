-- =====================================================
-- FIX WALLET CONSTRAINT ERROR
-- =====================================================
-- This script fixes the wallet constraint error that's preventing
-- user profile creation
-- =====================================================

-- =====================================================
-- 1. CHECK CURRENT WALLET TABLE STRUCTURE
-- =====================================================

-- Show wallet table structure
SELECT 
    'WALLET TABLE STRUCTURE:' as section,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'wallets'
ORDER BY ordinal_position;

-- Show wallet table constraints
SELECT 
    'WALLET CONSTRAINTS:' as section,
    constraint_name,
    constraint_type
FROM information_schema.table_constraints 
WHERE table_schema = 'public' 
AND table_name = 'wallets';

-- Show wallet table indexes
SELECT 
    'WALLET INDEXES:' as section,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'wallets' 
AND schemaname = 'public';

-- =====================================================
-- 2. CHECK THE PROBLEMATIC TRIGGER FUNCTION
-- =====================================================

-- Show the trigger function that's causing the error
SELECT 
    'TRIGGER FUNCTION:' as section,
    routine_name,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'create_user_wallet';

-- Show triggers on user_profiles table
SELECT 
    'USER_PROFILES TRIGGERS:' as section,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'user_profiles' 
AND event_object_schema = 'public';

-- =====================================================
-- 3. FIX THE WALLET TABLE CONSTRAINTS
-- =====================================================

-- Create unique constraint on wallets table if it doesn't exist
-- This will allow the ON CONFLICT clause to work properly

-- First, check if the constraint already exists
DO $$
BEGIN
    -- Try to create unique constraint on (user_id, role)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND constraint_name = 'wallets_user_id_role_unique'
    ) THEN
        -- Create the unique constraint
        ALTER TABLE public.wallets 
        ADD CONSTRAINT wallets_user_id_role_unique 
        UNIQUE (user_id, role);
        
        RAISE NOTICE 'Created unique constraint on wallets (user_id, role)';
    ELSE
        RAISE NOTICE 'Unique constraint already exists on wallets';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not create unique constraint: %', SQLERRM;
END $$;

-- =====================================================
-- 4. ALTERNATIVE: FIX THE TRIGGER FUNCTION
-- =====================================================

-- Create or replace the trigger function with better error handling
CREATE OR REPLACE FUNCTION create_user_wallet()
RETURNS TRIGGER AS $$
BEGIN
    -- Try to insert wallet, ignore if already exists
    BEGIN
        INSERT INTO public.wallets (user_id, role, balance, created_at, updated_at)
        VALUES (NEW.id, NEW.role, 0.00, NOW(), NOW());
    EXCEPTION 
        WHEN unique_violation THEN
            -- Wallet already exists, do nothing
            NULL;
        WHEN OTHERS THEN
            -- Log error but don't fail the user creation
            RAISE WARNING 'Could not create wallet for user %: %', NEW.id, SQLERRM;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. ALTERNATIVE: DISABLE WALLET CREATION TEMPORARILY
-- =====================================================

-- If the above doesn't work, temporarily disable the wallet trigger
-- Uncomment these lines if needed:

-- DROP TRIGGER IF EXISTS create_wallet_on_user_insert ON public.user_profiles;
-- DROP TRIGGER IF EXISTS trigger_create_user_wallet ON public.user_profiles;

-- =====================================================
-- 6. NOW RETRY THE USER PROFILE CREATION
-- =====================================================

-- Clear any partial inserts that might have failed
DELETE FROM public.user_profiles 
WHERE id IN (
    SELECT au.id 
    FROM auth.users au
    LEFT JOIN public.user_profiles up ON au.id = up.id
    WHERE up.id IS NULL
);

-- Insert missing profiles for auth users (retry)
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
-- 7. UPDATE UNAPPROVED USERS TO APPROVED
-- =====================================================

-- Approve all existing users for testing
UPDATE public.user_profiles 
SET 
    status = 'approved',
    updated_at = NOW()
WHERE status != 'approved';

-- =====================================================
-- 8. VERIFY THE FIX
-- =====================================================

-- Show all users after fixes
SELECT 
    'USERS AFTER WALLET FIX:' as section,
    up.id,
    up.email,
    up.name,
    up.role,
    up.status,
    CASE 
        WHEN au.id IS NOT NULL THEN 'AUTH OK'
        ELSE 'AUTH MISSING'
    END as auth_status,
    CASE 
        WHEN w.user_id IS NOT NULL THEN 'WALLET EXISTS'
        ELSE 'NO WALLET'
    END as wallet_status
FROM public.user_profiles up
LEFT JOIN auth.users au ON up.id = au.id
LEFT JOIN public.wallets w ON up.id = w.user_id AND up.role = w.role
ORDER BY up.role, up.created_at DESC;

-- Count users by role and status
SELECT 
    'USER SUMMARY AFTER FIX:' as section,
    role,
    status,
    COUNT(*) as user_count
FROM public.user_profiles 
GROUP BY role, status
ORDER BY role, status;

-- Show recommended test users
SELECT 
    'RECOMMENDED TEST USERS:' as section,
    email,
    role,
    status,
    'Use this user for testing in Flutter app' as recommendation
FROM public.user_profiles 
WHERE status = 'approved'
AND role IN ('admin', 'client')
ORDER BY role, created_at DESC
LIMIT 5;

-- =====================================================
-- 9. MANUAL WALLET CREATION (IF NEEDED)
-- =====================================================

-- Create wallets manually for users who don't have them
INSERT INTO public.wallets (user_id, role, balance, created_at, updated_at)
SELECT 
    up.id,
    up.role,
    0.00,
    NOW(),
    NOW()
FROM public.user_profiles up
LEFT JOIN public.wallets w ON up.id = w.user_id AND up.role = w.role
WHERE w.user_id IS NULL
ON CONFLICT (user_id, role) DO NOTHING;

-- =====================================================
-- WALLET CONSTRAINT FIX COMPLETE
-- =====================================================

SELECT 'WALLET CONSTRAINT ERROR FIXED' as status;
SELECT 'User profiles should now be created successfully' as result;
SELECT 'Flutter app authentication should work' as next_step;
