-- Check backup data before running rollback
-- Migration: 20241220000005_check_backup_data.sql
-- This script helps you understand what data will be restored during rollback

DO $$
BEGIN
    RAISE NOTICE '🔍 Checking backup table and current constraint status...';
    RAISE NOTICE '';
END $$;

-- Check if backup table exists and show its contents
DO $$
DECLARE
    backup_exists BOOLEAN := FALSE;
    backup_count INTEGER := 0;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'wallet_transactions_reference_type_backup' 
        AND table_schema = 'public'
    ) INTO backup_exists;
    
    IF backup_exists THEN
        SELECT COUNT(*) INTO backup_count
        FROM public.wallet_transactions_reference_type_backup;
        
        RAISE NOTICE '✅ Backup table exists with % rows', backup_count;
        RAISE NOTICE '';
    ELSE
        RAISE NOTICE '⚠️  No backup table found - rollback will not restore original values';
        RAISE NOTICE '';
    END IF;
END $$;

-- Show current constraint definition
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'public.wallet_transactions'::regclass 
AND conname = 'wallet_transactions_reference_type_valid';

-- Show distinct reference_type values in backup table (if it exists)
DO $$
DECLARE
    backup_exists BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'wallet_transactions_reference_type_backup' 
        AND table_schema = 'public'
    ) INTO backup_exists;
    
    IF backup_exists THEN
        RAISE NOTICE '📋 Original reference_type values in backup table:';
        
        -- This will be shown in the query results below
    ELSE
        RAISE NOTICE '⚠️  No backup table to show';
    END IF;
END $$;

-- Show backup table contents (only if table exists)
SELECT 
    original_reference_type,
    COUNT(*) as count,
    MIN(created_at) as earliest,
    MAX(created_at) as latest
FROM public.wallet_transactions_reference_type_backup
WHERE original_reference_type IS NOT NULL
GROUP BY original_reference_type
ORDER BY count DESC;

-- Show current reference_type values in wallet_transactions
SELECT 
    reference_type,
    COUNT(*) as count,
    CASE 
        WHEN reference_type IS NULL THEN '✅ Valid (NULL)'
        WHEN reference_type IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer') THEN '✅ Valid (Standard)'
        WHEN reference_type = 'electronic_payment' THEN '🔄 Electronic Payment (will be removed)'
        ELSE '❌ Non-standard (from backup restore)'
    END as status
FROM public.wallet_transactions 
GROUP BY reference_type 
ORDER BY 
    CASE 
        WHEN reference_type IS NULL THEN 1
        WHEN reference_type IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer') THEN 2
        WHEN reference_type = 'electronic_payment' THEN 3
        ELSE 4
    END,
    reference_type;

-- Show sample rows that would be affected by rollback
DO $$
DECLARE
    backup_exists BOOLEAN := FALSE;
    affected_count INTEGER := 0;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'wallet_transactions_reference_type_backup' 
        AND table_schema = 'public'
    ) INTO backup_exists;
    
    IF backup_exists THEN
        SELECT COUNT(*) INTO affected_count
        FROM public.wallet_transactions wt
        JOIN public.wallet_transactions_reference_type_backup backup ON wt.id = backup.id
        WHERE wt.reference_type != backup.original_reference_type;
        
        RAISE NOTICE '';
        RAISE NOTICE '📊 Rollback Impact Summary:';
        RAISE NOTICE '   - % rows will have their reference_type restored to original values', affected_count;
        
        IF affected_count > 0 THEN
            RAISE NOTICE '   - See query results below for details of affected rows';
        END IF;
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '📊 Rollback Impact Summary:';
        RAISE NOTICE '   - No backup table found, no reference_type values will be restored';
        RAISE NOTICE '   - Only electronic_payment references will be removed';
    END IF;
END $$;

-- Show rows that would be changed during rollback (only if backup exists)
SELECT 
    wt.id,
    wt.reference_type as current_reference_type,
    backup.original_reference_type,
    wt.description,
    wt.amount,
    wt.created_at
FROM public.wallet_transactions wt
JOIN public.wallet_transactions_reference_type_backup backup ON wt.id = backup.id
WHERE wt.reference_type != backup.original_reference_type
ORDER BY wt.created_at DESC
LIMIT 10;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Next Steps:';
    RAISE NOTICE '   1. Review the backup data above';
    RAISE NOTICE '   2. If you proceed with rollback, original reference_type values will be restored';
    RAISE NOTICE '   3. The constraint will be updated to allow those original values';
    RAISE NOTICE '   4. All electronic payment data will be permanently deleted';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  WARNING: Rollback will permanently delete all electronic payment data!';
    RAISE NOTICE '   Make sure you have backups before proceeding.';
END $$;
