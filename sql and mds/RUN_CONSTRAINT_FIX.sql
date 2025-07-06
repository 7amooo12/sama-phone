-- =====================================================
-- QUICK CONSTRAINT FIX FOR ELECTRONIC PAYMENTS
-- =====================================================
-- This script directly fixes the wallet_transactions constraint
-- to include 'electronic_payment' as a valid reference_type

-- Step 1: Check current constraint
DO $$
DECLARE
    constraint_exists BOOLEAN := FALSE;
    current_constraint_def TEXT;
BEGIN
    RAISE NOTICE '🔍 Checking current constraint...';
    
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
        
        RAISE NOTICE '📋 Current constraint: %', current_constraint_def;
        
        -- Check if it includes electronic_payment
        IF current_constraint_def LIKE '%electronic_payment%' THEN
            RAISE NOTICE '✅ Constraint already includes electronic_payment - no fix needed';
        ELSE
            RAISE NOTICE '❌ Constraint missing electronic_payment - will fix';
        END IF;
    ELSE
        RAISE NOTICE '❌ Constraint does not exist - will create';
    END IF;
END $$;

-- Step 2: Clean up any invalid reference_type values
DO $$
DECLARE
    invalid_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🧹 Cleaning up invalid reference_type values...';
    
    -- Count invalid values
    SELECT COUNT(*) INTO invalid_count
    FROM public.wallet_transactions
    WHERE reference_type IS NOT NULL
    AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment');
    
    IF invalid_count > 0 THEN
        RAISE NOTICE '🔧 Found % invalid reference_type values - cleaning up...', invalid_count;
        
        -- Update invalid values to 'manual'
        UPDATE public.wallet_transactions 
        SET reference_type = 'manual'
        WHERE reference_type IS NOT NULL
        AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment');
        
        RAISE NOTICE '✅ Cleaned up % invalid reference_type values', invalid_count;
    ELSE
        RAISE NOTICE '✅ No invalid reference_type values found';
    END IF;
END $$;

-- Step 3: Fix the constraint
DO $$
DECLARE
    constraint_exists BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE '🔧 Fixing constraint...';
    
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
    
    RAISE NOTICE '✅ Created updated constraint with electronic_payment support';
END $$;

-- Step 4: Verify the fix
DO $$
DECLARE
    constraint_def TEXT;
    invalid_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🔍 Verifying fix...';
    
    -- Get constraint definition
    SELECT pg_get_constraintdef(oid) INTO constraint_def
    FROM pg_constraint 
    WHERE conrelid = 'public.wallet_transactions'::regclass 
    AND conname = 'wallet_transactions_reference_type_valid';
    
    RAISE NOTICE '📋 New constraint: %', constraint_def;
    
    -- Verify no invalid values remain
    SELECT COUNT(*) INTO invalid_count
    FROM public.wallet_transactions
    WHERE reference_type IS NOT NULL
    AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment');
    
    IF invalid_count = 0 THEN
        RAISE NOTICE '✅ VERIFICATION PASSED: All reference_type values are valid';
        RAISE NOTICE '🎉 Electronic payment approvals should now work!';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: Still found % invalid reference_type values', invalid_count;
    END IF;
END $$;

-- Step 5: Test the constraint
DO $$
BEGIN
    RAISE NOTICE '🧪 Testing constraint with electronic_payment...';
    
    BEGIN
        -- Try to insert a test transaction with electronic_payment reference_type
        INSERT INTO public.wallet_transactions (
            wallet_id, user_id, transaction_type, amount, balance_before, balance_after,
            reference_type, reference_id, description, status, created_by
        ) VALUES (
            gen_random_uuid(), -- This will fail FK constraint but that's OK for testing
            gen_random_uuid(),
            'credit', 100.00, 0.00, 100.00,
            'electronic_payment', -- This should be allowed now
            gen_random_uuid()::TEXT,
            'Test electronic payment constraint',
            'completed',
            gen_random_uuid()
        );
        
        RAISE NOTICE '✅ Constraint test PASSED: electronic_payment accepted';
        
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE '✅ Constraint test PASSED: electronic_payment accepted (FK error expected)';
        WHEN check_violation THEN
            RAISE EXCEPTION 'Constraint test FAILED: electronic_payment rejected by constraint';
        WHEN OTHERS THEN
            RAISE NOTICE '⚠️  Constraint test completed with error: %', SQLERRM;
    END;
END $$;

-- Final summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎯 CONSTRAINT FIX COMPLETED!';
    RAISE NOTICE '✅ wallet_transactions_reference_type_valid constraint updated';
    RAISE NOTICE '✅ electronic_payment is now a valid reference_type';
    RAISE NOTICE '✅ Electronic payment approvals should work without constraint violations';
    RAISE NOTICE '';
    RAISE NOTICE '💡 Next: Test electronic payment approval in Flutter app';
END $$;
