-- =====================================================
-- SIMPLE CONSTRAINT FIX FOR ELECTRONIC PAYMENTS
-- =====================================================
-- This script fixes the wallet_transactions constraint to include electronic_payment

-- Step 1: Clean up any invalid reference_type values
UPDATE public.wallet_transactions 
SET reference_type = 'manual'
WHERE reference_type IS NOT NULL
AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment');

-- Step 2: Drop existing constraint
ALTER TABLE public.wallet_transactions
DROP CONSTRAINT IF EXISTS wallet_transactions_reference_type_valid;

-- Step 3: Create updated constraint with electronic_payment support
ALTER TABLE public.wallet_transactions
ADD CONSTRAINT wallet_transactions_reference_type_valid CHECK (
    reference_type IS NULL OR reference_type IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment')
);

-- Step 4: Verify the fix
DO $$
DECLARE
    constraint_def TEXT;
    invalid_count INTEGER;
BEGIN
    -- Get constraint definition
    SELECT pg_get_constraintdef(oid) INTO constraint_def
    FROM pg_constraint 
    WHERE conrelid = 'public.wallet_transactions'::regclass 
    AND conname = 'wallet_transactions_reference_type_valid';
    
    -- Count invalid values
    SELECT COUNT(*) INTO invalid_count
    FROM public.wallet_transactions
    WHERE reference_type IS NOT NULL
    AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment');
    
    RAISE NOTICE '📋 Constraint definition: %', constraint_def;
    RAISE NOTICE '📊 Invalid reference_type count: %', invalid_count;
    
    IF constraint_def LIKE '%electronic_payment%' AND invalid_count = 0 THEN
        RAISE NOTICE '✅ CONSTRAINT FIX SUCCESSFUL!';
        RAISE NOTICE '🎯 Electronic payment approvals should now work';
    ELSE
        RAISE EXCEPTION 'Constraint fix failed';
    END IF;
END $$;
