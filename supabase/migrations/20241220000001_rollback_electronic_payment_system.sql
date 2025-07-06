-- Rollback script for electronic payment system migration
-- Migration: 20241220000001_rollback_electronic_payment_system.sql
-- Use this script ONLY if you need to completely remove the electronic payment system

-- WARNING: This will remove all electronic payment data and restore original reference_type constraint
-- Make sure you have backups before running this script

-- Begin rollback transaction
BEGIN;

DO $$
BEGIN
    RAISE NOTICE '⚠️  STARTING ELECTRONIC PAYMENT SYSTEM ROLLBACK';
    RAISE NOTICE '   This will remove all electronic payment data and restore the original system';
    RAISE NOTICE '';
END $$;

-- ============================================================================
-- STEP 1: Remove Electronic Payment Triggers and Functions
-- ============================================================================

-- Drop the electronic payment trigger
DROP TRIGGER IF EXISTS trigger_electronic_payment_approval ON public.electronic_payments;

DO $$
BEGIN
    RAISE NOTICE '🗑️  Dropped electronic payment trigger';
END $$;

-- Drop the electronic payment function
DROP FUNCTION IF EXISTS public.handle_electronic_payment_approval();

DO $$
BEGIN
    RAISE NOTICE '🗑️  Dropped electronic payment function';
END $$;

-- ============================================================================
-- STEP 2: Remove Electronic Payment Tables and Data
-- ============================================================================

-- Drop electronic payments table (this will remove all payment data)
DROP TABLE IF EXISTS public.electronic_payments CASCADE;

DO $$
BEGIN
    RAISE NOTICE '🗑️  Dropped electronic_payments table';
END $$;

-- Drop payment accounts table
DROP TABLE IF EXISTS public.payment_accounts CASCADE;

DO $$
BEGIN
    RAISE NOTICE '🗑️  Dropped payment_accounts table';
END $$;

-- ============================================================================
-- STEP 3: Restore Original Reference Type Constraint and Data
-- ============================================================================

DO $$
DECLARE
    backup_exists BOOLEAN := FALSE;
    restored_count INTEGER := 0;
    constraint_exists BOOLEAN := FALSE;
    original_types TEXT[];
    combined_types TEXT[];
BEGIN
    -- Check if backup table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'wallet_transactions_reference_type_backup'
        AND table_schema = 'public'
    ) INTO backup_exists;

    -- Check if constraint exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'wallet_transactions_reference_type_valid'
        AND table_name = 'wallet_transactions'
        AND table_schema = 'public'
    ) INTO constraint_exists;

    IF backup_exists THEN
        RAISE NOTICE '💾 Found backup table, preparing to restore original reference_type values...';

        -- Get all original reference types from backup
        SELECT ARRAY_AGG(DISTINCT original_reference_type) INTO original_types
        FROM public.wallet_transactions_reference_type_backup
        WHERE original_reference_type IS NOT NULL;

        RAISE NOTICE '📋 Original reference types found in backup: %', array_to_string(original_types, ', ');

        -- First, update the constraint to allow original values
        IF constraint_exists THEN
            -- Drop current constraint
            ALTER TABLE public.wallet_transactions
            DROP CONSTRAINT wallet_transactions_reference_type_valid;
            RAISE NOTICE '🗑️  Dropped current reference_type constraint';
        END IF;

        -- Combine standard types with original types
        SELECT ARRAY(
            SELECT DISTINCT unnest(
                ARRAY['order', 'task', 'reward', 'salary', 'manual', 'transfer'] ||
                COALESCE(original_types, ARRAY[]::TEXT[])
            )
        ) INTO combined_types;

        -- Create temporary constraint that allows both standard and original types
        EXECUTE format(
            'ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_reference_type_valid CHECK (reference_type IS NULL OR reference_type = ANY(%L))',
            combined_types
        );
        RAISE NOTICE '✅ Created temporary constraint allowing original types: %', array_to_string(combined_types, ', ');

        -- Now restore original reference_type values from backup
        UPDATE public.wallet_transactions
        SET reference_type = backup.original_reference_type
        FROM public.wallet_transactions_reference_type_backup backup
        WHERE public.wallet_transactions.id = backup.id;

        GET DIAGNOSTICS restored_count = ROW_COUNT;
        RAISE NOTICE '✅ Restored % rows to their original reference_type values', restored_count;

        -- Drop the backup table
        DROP TABLE public.wallet_transactions_reference_type_backup;
        RAISE NOTICE '🗑️  Dropped backup table';

    ELSE
        RAISE NOTICE '⚠️  No backup table found - reference_type values will remain as they were modified';

        -- Still need to update constraint to remove electronic_payment
        IF constraint_exists THEN
            ALTER TABLE public.wallet_transactions
            DROP CONSTRAINT wallet_transactions_reference_type_valid;

            ALTER TABLE public.wallet_transactions
            ADD CONSTRAINT wallet_transactions_reference_type_valid CHECK (
                reference_type IS NULL OR reference_type IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer')
            );
            RAISE NOTICE '✅ Updated constraint to remove electronic_payment (no backup to restore)';
        END IF;
    END IF;
END $$;

-- Constraint handling is now complete from the previous step

-- ============================================================================
-- STEP 4: Clean Up Electronic Payment Related Data
-- ============================================================================

-- Remove any wallet transactions that were created by electronic payments
DELETE FROM public.wallet_transactions
WHERE reference_type = 'electronic_payment';

DO $$
BEGIN
    RAISE NOTICE '🗑️  Removed electronic payment wallet transactions';
END $$;

-- ============================================================================
-- STEP 5: Verification
-- ============================================================================

DO $$
DECLARE
    ep_tables_count INTEGER;
    ep_functions_count INTEGER;
    ep_triggers_count INTEGER;
    ep_transactions_count INTEGER;
BEGIN
    -- Check that electronic payment tables are gone
    SELECT COUNT(*) INTO ep_tables_count
    FROM information_schema.tables 
    WHERE table_name IN ('electronic_payments', 'payment_accounts') 
    AND table_schema = 'public';
    
    -- Check that electronic payment functions are gone
    SELECT COUNT(*) INTO ep_functions_count
    FROM information_schema.routines 
    WHERE routine_name = 'handle_electronic_payment_approval' 
    AND routine_schema = 'public';
    
    -- Check that electronic payment triggers are gone
    SELECT COUNT(*) INTO ep_triggers_count
    FROM information_schema.triggers 
    WHERE trigger_name = 'trigger_electronic_payment_approval';
    
    -- Check that electronic payment transactions are gone
    SELECT COUNT(*) INTO ep_transactions_count
    FROM public.wallet_transactions 
    WHERE reference_type = 'electronic_payment';
    
    IF ep_tables_count = 0 AND ep_functions_count = 0 AND ep_triggers_count = 0 AND ep_transactions_count = 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '✅ ROLLBACK COMPLETED SUCCESSFULLY';
        RAISE NOTICE '   - Electronic payment tables removed';
        RAISE NOTICE '   - Electronic payment functions removed';
        RAISE NOTICE '   - Electronic payment triggers removed';
        RAISE NOTICE '   - Electronic payment transactions removed';
        RAISE NOTICE '   - Original reference_type constraint restored';
        RAISE NOTICE '';
        RAISE NOTICE '🔄 System restored to pre-electronic-payment state';
    ELSE
        RAISE EXCEPTION 'ROLLBACK INCOMPLETE: Some electronic payment components still exist (tables: %, functions: %, triggers: %, transactions: %)', 
                       ep_tables_count, ep_functions_count, ep_triggers_count, ep_transactions_count;
    END IF;
END $$;

-- Commit rollback transaction
COMMIT;
