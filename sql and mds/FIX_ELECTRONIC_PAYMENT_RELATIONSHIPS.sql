-- Fix Electronic Payment Foreign Key Relationships
-- This script adds proper foreign key constraints to enable Supabase joins
-- Run this ONLY if you want to enable foreign key relationships for better queries

-- ============================================================================
-- STEP 1: Check Current State
-- ============================================================================

-- Check if electronic payment tables exist
SELECT 
    'Table Check' as check_type,
    table_name,
    CASE 
        WHEN table_name IS NOT NULL THEN 'EXISTS ✅'
        ELSE 'MISSING ❌'
    END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('electronic_payments', 'payment_accounts', 'user_profiles')
ORDER BY table_name;

-- Check current foreign key constraints
SELECT 
    'Current Foreign Keys' as info_type,
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_name IN ('electronic_payments', 'payment_accounts')
AND tc.table_schema = 'public';

-- ============================================================================
-- STEP 2: Check user_profiles Table Structure
-- ============================================================================

-- Check if user_profiles exists and its structure
DO $$
DECLARE
    user_profiles_exists BOOLEAN;
    has_user_id_column BOOLEAN;
    has_id_column BOOLEAN;
BEGIN
    -- Check if user_profiles table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles'
    ) INTO user_profiles_exists;
    
    IF user_profiles_exists THEN
        RAISE NOTICE '✅ user_profiles table exists';
        
        -- Check which column exists for user identification
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'user_profiles'
            AND column_name = 'user_id'
        ) INTO has_user_id_column;
        
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'user_profiles'
            AND column_name = 'id'
        ) INTO has_id_column;
        
        RAISE NOTICE 'user_profiles columns: user_id=%, id=%', has_user_id_column, has_id_column;
        
        -- Show user_profiles structure
        RAISE NOTICE 'user_profiles table structure:';
    ELSE
        RAISE NOTICE '❌ user_profiles table does not exist';
        RAISE NOTICE 'Foreign key relationships to user_profiles cannot be created';
    END IF;
END $$;

-- Show user_profiles structure if it exists
SELECT 
    'user_profiles structure' as info_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'user_profiles'
ORDER BY ordinal_position;

-- ============================================================================
-- STEP 3: Add Foreign Key Constraints (Optional)
-- ============================================================================

-- WARNING: Only run this section if you want to add foreign key constraints
-- This will enable Supabase foreign key hint syntax but requires proper data

-- Uncomment the following sections if you want to add foreign key constraints:

/*
-- Add foreign key from electronic_payments.recipient_account_id to payment_accounts.id
-- This should already exist from the migration script
DO $$
BEGIN
    -- Check if constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'public' 
        AND table_name = 'electronic_payments'
        AND constraint_name = 'electronic_payments_recipient_account_id_fkey'
    ) THEN
        ALTER TABLE public.electronic_payments 
        ADD CONSTRAINT electronic_payments_recipient_account_id_fkey 
        FOREIGN KEY (recipient_account_id) 
        REFERENCES public.payment_accounts(id);
        
        RAISE NOTICE '✅ Added foreign key: electronic_payments -> payment_accounts';
    ELSE
        RAISE NOTICE 'ℹ️ Foreign key electronic_payments -> payment_accounts already exists';
    END IF;
END $$;
*/

/*
-- Add foreign key from electronic_payments.client_id to user_profiles
-- This requires determining the correct column in user_profiles
DO $$
DECLARE
    user_profiles_exists BOOLEAN;
    has_user_id_column BOOLEAN;
    has_id_column BOOLEAN;
BEGIN
    -- Check if user_profiles table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles'
    ) INTO user_profiles_exists;
    
    IF user_profiles_exists THEN
        -- Check which column to use
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'user_profiles'
            AND column_name = 'user_id'
        ) INTO has_user_id_column;
        
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'user_profiles'
            AND column_name = 'id'
        ) INTO has_id_column;
        
        -- Add foreign key based on available column
        IF has_user_id_column THEN
            -- Use user_id column
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.table_constraints 
                WHERE table_schema = 'public' 
                AND table_name = 'electronic_payments'
                AND constraint_name = 'electronic_payments_client_id_user_profiles_fkey'
            ) THEN
                ALTER TABLE public.electronic_payments 
                ADD CONSTRAINT electronic_payments_client_id_user_profiles_fkey 
                FOREIGN KEY (client_id) 
                REFERENCES public.user_profiles(user_id);
                
                RAISE NOTICE '✅ Added foreign key: electronic_payments.client_id -> user_profiles.user_id';
            END IF;
        ELSIF has_id_column THEN
            -- Use id column
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.table_constraints 
                WHERE table_schema = 'public' 
                AND table_name = 'electronic_payments'
                AND constraint_name = 'electronic_payments_client_id_user_profiles_fkey'
            ) THEN
                ALTER TABLE public.electronic_payments 
                ADD CONSTRAINT electronic_payments_client_id_user_profiles_fkey 
                FOREIGN KEY (client_id) 
                REFERENCES public.user_profiles(id);
                
                RAISE NOTICE '✅ Added foreign key: electronic_payments.client_id -> user_profiles.id';
            END IF;
        ELSE
            RAISE NOTICE '❌ No suitable column found in user_profiles for foreign key';
        END IF;
    ELSE
        RAISE NOTICE '❌ Cannot add foreign key: user_profiles table does not exist';
    END IF;
END $$;
*/

-- ============================================================================
-- STEP 4: Test Supabase Foreign Key Hints
-- ============================================================================

-- Test if foreign key hints work after adding constraints
-- Uncomment to test:

/*
-- Test payment_accounts relationship
SELECT 
    'Testing payment_accounts relationship' as test_type,
    COUNT(*) as payment_count
FROM public.electronic_payments ep
LEFT JOIN public.payment_accounts pa ON ep.recipient_account_id = pa.id;

-- Test user_profiles relationship (if table exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles'
    ) THEN
        -- Test the relationship
        PERFORM COUNT(*) 
        FROM public.electronic_payments ep
        LEFT JOIN public.user_profiles up ON ep.client_id = up.user_id OR ep.client_id = up.id;
        
        RAISE NOTICE '✅ user_profiles relationship test passed';
    ELSE
        RAISE NOTICE 'ℹ️ Skipping user_profiles relationship test - table does not exist';
    END IF;
END $$;
*/

-- ============================================================================
-- STEP 5: Summary and Recommendations
-- ============================================================================

SELECT 
    'SUMMARY' as section,
    'Foreign Key Relationship Analysis Complete' as message,
    now() as analyzed_at;

-- Provide recommendations
DO $$
DECLARE
    electronic_payments_exists BOOLEAN;
    payment_accounts_exists BOOLEAN;
    user_profiles_exists BOOLEAN;
BEGIN
    -- Check table existence
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'electronic_payments'
    ) INTO electronic_payments_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'payment_accounts'
    ) INTO payment_accounts_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'user_profiles'
    ) INTO user_profiles_exists;
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 RECOMMENDATIONS:';
    RAISE NOTICE '==================';
    
    IF electronic_payments_exists AND payment_accounts_exists THEN
        RAISE NOTICE '✅ Core electronic payment tables exist';
        RAISE NOTICE '1. Your Flutter app should work with the basic query approach';
        RAISE NOTICE '2. Foreign key relationships are optional for basic functionality';
    ELSE
        RAISE NOTICE '❌ Missing core tables - run the migration script first';
    END IF;
    
    IF user_profiles_exists THEN
        RAISE NOTICE '3. user_profiles table exists - you can add foreign keys for better queries';
        RAISE NOTICE '4. Uncomment the foreign key sections above if you want to enable joins';
    ELSE
        RAISE NOTICE '3. user_profiles table missing - foreign key relationships not possible';
        RAISE NOTICE '4. Consider creating user_profiles table or use basic queries only';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🚀 NEXT STEPS:';
    RAISE NOTICE '1. Test your Flutter app with the updated service code';
    RAISE NOTICE '2. The PGRST200 error should be resolved with basic queries';
    RAISE NOTICE '3. Add foreign keys later if you need advanced query features';
    RAISE NOTICE '';
END $$;
