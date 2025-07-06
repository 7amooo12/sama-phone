-- Diagnostic script to identify problematic wallet_transactions data
-- Run this BEFORE the electronic payment migration to see what needs to be fixed

-- Check current constraint status
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'public.wallet_transactions'::regclass 
AND conname = 'wallet_transactions_reference_type_valid';

-- Find all distinct reference_type values in the table
SELECT 
    reference_type,
    COUNT(*) as count,
    CASE 
        WHEN reference_type IS NULL THEN '✅ Valid (NULL)'
        WHEN reference_type IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment') THEN '✅ Valid'
        ELSE '❌ INVALID - Will cause constraint violation'
    END as status
FROM public.wallet_transactions 
GROUP BY reference_type 
ORDER BY 
    CASE 
        WHEN reference_type IS NULL THEN 1
        WHEN reference_type IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment') THEN 2
        ELSE 3
    END,
    reference_type;

-- Show sample rows with invalid reference_type values
SELECT 
    id,
    user_id,
    transaction_type,
    amount,
    reference_type,
    reference_id,
    description,
    created_at
FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL 
AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment')
ORDER BY created_at DESC
LIMIT 10;

-- Count of rows that would be affected by the cleanup
SELECT 
    COUNT(*) as total_invalid_rows,
    COUNT(DISTINCT reference_type) as distinct_invalid_types
FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL 
AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment');

-- Show the breakdown by invalid reference_type
SELECT 
    reference_type,
    COUNT(*) as count,
    MIN(created_at) as earliest_occurrence,
    MAX(created_at) as latest_occurrence
FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL 
AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment')
GROUP BY reference_type
ORDER BY count DESC;
