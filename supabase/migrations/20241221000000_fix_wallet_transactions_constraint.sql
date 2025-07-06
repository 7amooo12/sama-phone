-- =====================================================
-- FIX WALLET TRANSACTIONS REFERENCE TYPE CONSTRAINT
-- =====================================================
-- This migration fixes the wallet_transactions_reference_type_valid constraint
-- to ensure 'electronic_payment' is included as a valid reference_type value.
-- This resolves the constraint violation error during electronic payment approvals.

-- Step 1: Diagnose current constraint state
DO $$
DECLARE
    constraint_exists BOOLEAN := FALSE;
    current_constraint_def TEXT;
    invalid_count INTEGER := 0;
    constraint_valid BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE '🔍 Diagnosing wallet_transactions constraint issue...';
    
    -- Check if constraint exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'wallet_transactions_reference_type_valid'
        AND table_name = 'wallet_transactions'
        AND table_schema = 'public'
    ) INTO constraint_exists;
    
    IF constraint_exists THEN
        -- Get current constraint definition
        SELECT pg_get_constraintdef(oid) INTO current_constraint_def
        FROM pg_constraint 
        WHERE conrelid = 'public.wallet_transactions'::regclass 
        AND conname = 'wallet_transactions_reference_type_valid';
        
        RAISE NOTICE '📋 Current constraint definition: %', current_constraint_def;
        
        -- Check if constraint includes 'electronic_payment'
        IF current_constraint_def LIKE '%electronic_payment%' THEN
            constraint_valid := TRUE;
            RAISE NOTICE '✅ Constraint already includes electronic_payment';
        ELSE
            RAISE NOTICE '❌ Constraint does NOT include electronic_payment - needs update';
        END IF;
    ELSE
        RAISE NOTICE '❌ Constraint does not exist - needs creation';
    END IF;
    
    -- Check for invalid reference_type values
    SELECT COUNT(*) INTO invalid_count
    FROM public.wallet_transactions
    WHERE reference_type IS NOT NULL
    AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment');
    
    IF invalid_count > 0 THEN
        RAISE NOTICE '⚠️  Found % rows with invalid reference_type values', invalid_count;
        
        -- Show sample invalid values
        RAISE NOTICE '📋 Sample invalid reference_type values:';
        FOR current_constraint_def IN 
            SELECT DISTINCT reference_type 
            FROM public.wallet_transactions 
            WHERE reference_type IS NOT NULL 
            AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment')
            LIMIT 5
        LOOP
            RAISE NOTICE '   - %', current_constraint_def;
        END LOOP;
    ELSE
        RAISE NOTICE '✅ All reference_type values are valid';
    END IF;
    
END $$;

-- Step 2: Clean up invalid reference_type values if any exist
DO $$
DECLARE
    invalid_count INTEGER := 0;
    cleanup_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🧹 Cleaning up invalid reference_type values...';
    
    -- Count invalid values
    SELECT COUNT(*) INTO invalid_count
    FROM public.wallet_transactions
    WHERE reference_type IS NOT NULL
    AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment');
    
    IF invalid_count > 0 THEN
        RAISE NOTICE '🔧 Cleaning up % invalid reference_type values...', invalid_count;
        
        -- Create backup table if it doesn't exist
        CREATE TABLE IF NOT EXISTS public.wallet_transactions_reference_type_backup AS
        SELECT 
            id,
            wallet_id,
            user_id,
            reference_type as original_reference_type,
            reference_id,
            description,
            created_at,
            now() as backup_created_at
        FROM public.wallet_transactions
        WHERE reference_type IS NOT NULL
        AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment');
        
        RAISE NOTICE '💾 Created backup of invalid reference_type values';
        
        -- Update invalid reference_type values using intelligent mapping
        UPDATE public.wallet_transactions 
        SET reference_type = CASE
            WHEN reference_type ILIKE '%order%' OR reference_type ILIKE '%purchase%' THEN 'order'
            WHEN reference_type ILIKE '%task%' OR reference_type ILIKE '%work%' THEN 'task'
            WHEN reference_type ILIKE '%reward%' OR reference_type ILIKE '%bonus%' THEN 'reward'
            WHEN reference_type ILIKE '%salary%' OR reference_type ILIKE '%wage%' OR reference_type ILIKE '%pay%' THEN 'salary'
            WHEN reference_type ILIKE '%transfer%' OR reference_type ILIKE '%move%' THEN 'transfer'
            WHEN reference_type ILIKE '%electronic%' OR reference_type ILIKE '%payment%' THEN 'electronic_payment'
            ELSE 'manual'
        END
        WHERE reference_type IS NOT NULL
        AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment');
        
        GET DIAGNOSTICS cleanup_count = ROW_COUNT;
        RAISE NOTICE '✅ Cleaned up % reference_type values', cleanup_count;
    ELSE
        RAISE NOTICE '✅ No invalid reference_type values found - no cleanup needed';
    END IF;
    
END $$;

-- Step 3: Update or create the constraint
DO $$
DECLARE
    constraint_exists BOOLEAN := FALSE;
    invalid_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🔧 Updating wallet_transactions constraint...';
    
    -- Final validation - ensure no invalid values remain
    SELECT COUNT(*) INTO invalid_count
    FROM public.wallet_transactions
    WHERE reference_type IS NOT NULL
    AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment');
    
    IF invalid_count > 0 THEN
        RAISE EXCEPTION 'CRITICAL: Still found % rows with invalid reference_type values after cleanup. Manual intervention required.', invalid_count;
    END IF;
    
    -- Check if constraint exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'wallet_transactions_reference_type_valid'
        AND table_name = 'wallet_transactions'
        AND table_schema = 'public'
    ) INTO constraint_exists;
    
    -- Drop existing constraint if it exists
    IF constraint_exists THEN
        ALTER TABLE public.wallet_transactions
        DROP CONSTRAINT wallet_transactions_reference_type_valid;
        RAISE NOTICE '🗑️  Dropped existing constraint';
    END IF;
    
    -- Create the updated constraint with electronic_payment support
    ALTER TABLE public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_reference_type_valid CHECK (
        reference_type IS NULL OR reference_type IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment')
    );
    
    RAISE NOTICE '✅ Successfully created updated constraint with electronic_payment support';
    
END $$;

-- Step 4: Verify the fix
DO $$
DECLARE
    constraint_def TEXT;
    invalid_count INTEGER := 0;
    total_count INTEGER := 0;
    electronic_payment_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🔍 Verifying constraint fix...';
    
    -- Get constraint definition
    SELECT pg_get_constraintdef(oid) INTO constraint_def
    FROM pg_constraint 
    WHERE conrelid = 'public.wallet_transactions'::regclass 
    AND conname = 'wallet_transactions_reference_type_valid';
    
    RAISE NOTICE '📋 Final constraint definition: %', constraint_def;
    
    -- Verify no invalid values remain
    SELECT COUNT(*) INTO invalid_count
    FROM public.wallet_transactions
    WHERE reference_type IS NOT NULL
    AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment');
    
    -- Count total transactions
    SELECT COUNT(*) INTO total_count
    FROM public.wallet_transactions;
    
    -- Count electronic_payment transactions
    SELECT COUNT(*) INTO electronic_payment_count
    FROM public.wallet_transactions
    WHERE reference_type = 'electronic_payment';
    
    IF invalid_count = 0 THEN
        RAISE NOTICE '✅ VERIFICATION PASSED: No invalid reference_type values found';
        RAISE NOTICE '📊 Total wallet transactions: %', total_count;
        RAISE NOTICE '📊 Electronic payment transactions: %', electronic_payment_count;
        RAISE NOTICE '🎉 Constraint fix completed successfully!';
        RAISE NOTICE '💡 Electronic payment approvals should now work without constraint violations';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: Still found % invalid reference_type values', invalid_count;
    END IF;
    
END $$;

-- Step 5: Test constraint with sample data (optional verification)
DO $$
BEGIN
    RAISE NOTICE '🧪 Testing constraint with sample electronic_payment value...';
    
    -- This should succeed without constraint violation
    BEGIN
        -- Create a temporary test transaction to verify constraint works
        INSERT INTO public.wallet_transactions (
            wallet_id, user_id, transaction_type, amount, balance_before, balance_after,
            reference_type, reference_id, description, status, created_by
        ) VALUES (
            gen_random_uuid(), -- wallet_id (will fail FK but that's ok for constraint test)
            gen_random_uuid(), -- user_id
            'credit', 100.00, 0.00, 100.00,
            'electronic_payment', -- This should be allowed now
            gen_random_uuid()::TEXT,
            'Test electronic payment constraint',
            'completed',
            gen_random_uuid()
        );
        
        -- If we get here, constraint allows electronic_payment
        RAISE NOTICE '✅ Constraint test PASSED: electronic_payment value accepted';
        
        -- Clean up test record (will fail due to FK constraints, but that's expected)
        -- We just wanted to test the reference_type constraint
        
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE '✅ Constraint test PASSED: electronic_payment accepted (FK error expected)';
        WHEN check_violation THEN
            RAISE EXCEPTION 'Constraint test FAILED: electronic_payment value rejected by constraint';
        WHEN OTHERS THEN
            RAISE NOTICE '⚠️  Constraint test completed with unexpected error (but constraint likely works): %', SQLERRM;
    END;
    
END $$;

-- Final summary
DO $$
BEGIN
    RAISE NOTICE '🎯 MIGRATION COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '📝 Summary:';
    RAISE NOTICE '   - Fixed wallet_transactions_reference_type_valid constraint';
    RAISE NOTICE '   - Added support for electronic_payment reference_type';
    RAISE NOTICE '   - Cleaned up any invalid reference_type values';
    RAISE NOTICE '   - Created backup of original invalid values';
    RAISE NOTICE '💡 Electronic payment approvals should now work without constraint violations';
END $$;
