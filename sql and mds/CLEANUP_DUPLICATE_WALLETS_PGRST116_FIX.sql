-- 🔧 إصلاح مشكلة المحافظ المكررة - PGRST116 Error Fix
-- Fix for PostgreSQL duplicate wallet records causing PGRST116 errors
-- This script safely merges duplicate wallet records while preserving data integrity

-- STEP 1: INVESTIGATION AND BACKUP
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '=== بدء إصلاح مشكلة المحافظ المكررة ===';
    RAISE NOTICE 'Starting duplicate wallet cleanup for PGRST116 error fix';
END $$;

-- Create backup table for safety
CREATE TABLE IF NOT EXISTS public.wallets_backup_pgrst116_fix AS 
SELECT * FROM public.wallets;

DO $$
DECLARE
    backup_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO backup_count FROM public.wallets_backup_pgrst116_fix;
    RAISE NOTICE '✅ Created backup table with % wallet records', backup_count;
END $$;

-- STEP 2: ANALYZE DUPLICATE WALLET RECORDS
-- =====================================================

DO $$
DECLARE
    duplicate_count INTEGER;
    total_wallets INTEGER;
    rec RECORD;  -- Added missing RECORD declaration for FOR loop
BEGIN
    -- Count total wallets
    SELECT COUNT(*) INTO total_wallets FROM public.wallets;
    
    -- Count users with multiple wallets
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT user_id, COUNT(*) as wallet_count
        FROM public.wallets
        GROUP BY user_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    RAISE NOTICE '📊 Analysis Results:';
    RAISE NOTICE '   Total wallets: %', total_wallets;
    RAISE NOTICE '   Users with multiple wallets: %', duplicate_count;
    
    -- Show detailed duplicate information
    IF duplicate_count > 0 THEN
        RAISE NOTICE '🔍 Duplicate wallet details:';
        FOR rec IN (
            SELECT 
                user_id,
                COUNT(*) as wallet_count,
                STRING_AGG(id::text, ', ') as wallet_ids,
                STRING_AGG(balance::text, ', ') as balances,
                STRING_AGG(COALESCE(wallet_type, 'NULL'), ', ') as types,
                STRING_AGG(COALESCE(status, 'NULL'), ', ') as statuses
            FROM public.wallets
            GROUP BY user_id
            HAVING COUNT(*) > 1
            ORDER BY COUNT(*) DESC
            LIMIT 10
        ) LOOP
            RAISE NOTICE '   User: % | Wallets: % | IDs: % | Balances: % | Types: % | Status: %', 
                rec.user_id, rec.wallet_count, rec.wallet_ids, rec.balances, rec.types, rec.statuses;
        END LOOP;
    END IF;
END $$;

-- STEP 3: SAFE DUPLICATE WALLET CLEANUP
-- =====================================================

DO $$
DECLARE
    user_record RECORD;
    wallet_record RECORD;
    keep_wallet_id UUID;
    total_balance DECIMAL(15,2);
    merged_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🔄 Starting safe duplicate wallet cleanup...';
    
    -- Process each user with multiple wallets
    FOR user_record IN (
        SELECT user_id, COUNT(*) as wallet_count
        FROM public.wallets
        GROUP BY user_id
        HAVING COUNT(*) > 1
    ) LOOP
        
        RAISE NOTICE '👤 Processing user: % (% wallets)', user_record.user_id, user_record.wallet_count;
        
        -- Calculate total balance across all wallets for this user
        SELECT COALESCE(SUM(balance), 0) INTO total_balance
        FROM public.wallets
        WHERE user_id = user_record.user_id;
        
        -- Select the wallet to keep (prioritize: personal type, then most recent, then highest balance)
        SELECT id INTO keep_wallet_id
        FROM public.wallets
        WHERE user_id = user_record.user_id
        ORDER BY 
            CASE WHEN wallet_type = 'personal' THEN 1 ELSE 2 END,
            created_at DESC,
            balance DESC
        LIMIT 1;
        
        RAISE NOTICE '   💰 Total balance: % EGP | Keeping wallet: %', total_balance, keep_wallet_id;
        
        -- Update the kept wallet with the total balance
        UPDATE public.wallets
        SET 
            balance = total_balance,
            updated_at = NOW(),
            wallet_type = COALESCE(wallet_type, 'personal'),
            is_active = COALESCE(is_active, true),
            status = COALESCE(status, 'active')
        WHERE id = keep_wallet_id;
        
        -- Update wallet_transactions to point to the kept wallet
        UPDATE public.wallet_transactions
        SET wallet_id = keep_wallet_id
        WHERE wallet_id IN (
            SELECT id FROM public.wallets 
            WHERE user_id = user_record.user_id 
            AND id != keep_wallet_id
        );
        
        -- Delete duplicate wallets (keep only the selected one)
        DELETE FROM public.wallets
        WHERE user_id = user_record.user_id
        AND id != keep_wallet_id;
        
        merged_count := merged_count + 1;
        
    END LOOP;
    
    RAISE NOTICE '✅ Merged duplicate wallets for % users', merged_count;
END $$;

-- STEP 4: ADD CONSTRAINTS TO PREVENT FUTURE DUPLICATES
-- =====================================================

DO $$
BEGIN
    -- Add unique constraint on user_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'wallets_user_id_unique' 
        AND table_name = 'wallets'
    ) THEN
        ALTER TABLE public.wallets 
        ADD CONSTRAINT wallets_user_id_unique UNIQUE (user_id);
        RAISE NOTICE '✅ Added unique constraint on user_id';
    ELSE
        RAISE NOTICE 'ℹ️ Unique constraint on user_id already exists';
    END IF;
    
    -- Ensure wallet_type column exists with default value
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'wallets' 
        AND column_name = 'wallet_type'
    ) THEN
        ALTER TABLE public.wallets 
        ADD COLUMN wallet_type TEXT DEFAULT 'personal';
        RAISE NOTICE '✅ Added wallet_type column';
    END IF;
    
    -- Ensure is_active column exists with default value
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'wallets' 
        AND column_name = 'is_active'
    ) THEN
        ALTER TABLE public.wallets 
        ADD COLUMN is_active BOOLEAN DEFAULT true;
        RAISE NOTICE '✅ Added is_active column';
    END IF;
    
END $$;

-- STEP 5: VERIFICATION AND FINAL REPORT
-- =====================================================

DO $$
DECLARE
    final_wallet_count INTEGER;
    remaining_duplicates INTEGER;
    cleanup_success BOOLEAN := true;
    rec RECORD;  -- Added missing RECORD declaration for FOR loop
BEGIN
    -- Count final wallet records
    SELECT COUNT(*) INTO final_wallet_count FROM public.wallets;
    
    -- Check for remaining duplicates
    SELECT COUNT(*) INTO remaining_duplicates
    FROM (
        SELECT user_id, COUNT(*) as wallet_count
        FROM public.wallets
        GROUP BY user_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    RAISE NOTICE '📊 Final Results:';
    RAISE NOTICE '   Total wallets after cleanup: %', final_wallet_count;
    RAISE NOTICE '   Remaining duplicate users: %', remaining_duplicates;
    
    IF remaining_duplicates = 0 THEN
        RAISE NOTICE '✅ SUCCESS: All duplicate wallets have been cleaned up!';
        RAISE NOTICE '✅ PGRST116 error should now be resolved';
    ELSE
        RAISE NOTICE '⚠️ WARNING: % users still have multiple wallets', remaining_duplicates;
        cleanup_success := false;
    END IF;
    
    -- Show sample of cleaned data
    RAISE NOTICE '📋 Sample of cleaned wallet data:';
    FOR rec IN (
        SELECT 
            user_id,
            id as wallet_id,
            balance,
            wallet_type,
            is_active,
            status
        FROM public.wallets
        ORDER BY created_at DESC
        LIMIT 5
    ) LOOP
        RAISE NOTICE '   User: % | Wallet: % | Balance: % | Type: % | Active: % | Status: %',
            rec.user_id, rec.wallet_id, rec.balance, rec.wallet_type, rec.is_active, rec.status;
    END LOOP;
    
END $$;

-- STEP 6: CREATE IMPROVED DATABASE FUNCTIONS
-- =====================================================

-- Enhanced get_or_create_client_wallet function that prevents duplicates
CREATE OR REPLACE FUNCTION public.get_or_create_client_wallet(p_user_id UUID)
RETURNS UUID AS $$
DECLARE
    client_wallet_id UUID;
BEGIN
    -- Try to find existing wallet (with proper uniqueness handling)
    SELECT id INTO client_wallet_id
    FROM public.wallets
    WHERE user_id = p_user_id
    LIMIT 1; -- Ensure only one record is returned
    
    -- If wallet exists, return it
    IF client_wallet_id IS NOT NULL THEN
        RETURN client_wallet_id;
    END IF;
    
    -- Create new wallet with proper conflict handling
    INSERT INTO public.wallets (
        user_id, 
        wallet_type, 
        role, 
        balance, 
        currency, 
        status, 
        is_active,
        created_at, 
        updated_at
    ) VALUES (
        p_user_id, 
        'personal', 
        'client', 
        0.00, 
        'EGP', 
        'active', 
        true,
        NOW(), 
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        updated_at = NOW(),
        is_active = true,
        status = 'active'
    RETURNING id INTO client_wallet_id;
    
    RETURN client_wallet_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
BEGIN
    RAISE NOTICE '=== إصلاح مشكلة المحافظ المكررة مكتمل ===';
    RAISE NOTICE '=== PGRST116 Duplicate Wallet Fix Complete ===';
    RAISE NOTICE 'يرجى اختبار النظام للتأكد من حل مشكلة PGRST116';
    RAISE NOTICE 'Please test the system to verify PGRST116 error is resolved';
END $$;
