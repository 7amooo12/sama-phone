-- 🚨 CRITICAL WALLET ERROR FIX
-- Fixes: "Bad state: No element" and "type 'Null' is not a subtype of type 'String'"
-- Date: $(date)

-- =====================================================
-- STEP 1: ANALYZE CURRENT DATA ISSUES
-- =====================================================

SELECT '=== ANALYZING WALLET DATA ISSUES ===' as section;

-- Check for wallets with null essential fields
SELECT 
    'Wallets with NULL essential fields' as issue_type,
    COUNT(*) as count,
    array_agg(id) as wallet_ids
FROM public.wallets 
WHERE id IS NULL OR user_id IS NULL OR role IS NULL OR role = '';

-- Check for invalid wallet statuses
SELECT 
    'Invalid wallet statuses' as issue_type,
    status,
    COUNT(*) as count
FROM public.wallets 
WHERE status NOT IN ('active', 'suspended', 'closed') OR status IS NULL
GROUP BY status;

-- Check for invalid wallet roles
SELECT 
    'Invalid wallet roles' as issue_type,
    role,
    COUNT(*) as count
FROM public.wallets 
WHERE role NOT IN ('admin', 'accountant', 'owner', 'client', 'worker') OR role IS NULL OR role = ''
GROUP BY role;

-- Check for transactions with null essential fields
SELECT 
    'Transactions with NULL essential fields' as issue_type,
    COUNT(*) as count
FROM public.wallet_transactions 
WHERE id IS NULL OR wallet_id IS NULL OR user_id IS NULL OR created_by IS NULL;

-- Check for invalid transaction types
SELECT 
    'Invalid transaction types' as issue_type,
    transaction_type,
    COUNT(*) as count
FROM public.wallet_transactions 
WHERE transaction_type NOT IN ('credit', 'debit', 'reward', 'salary', 'payment', 'refund', 'bonus', 'penalty', 'transfer') 
   OR transaction_type IS NULL OR transaction_type = ''
GROUP BY transaction_type;

-- Check for invalid transaction statuses
SELECT 
    'Invalid transaction statuses' as issue_type,
    status,
    COUNT(*) as count
FROM public.wallet_transactions 
WHERE status NOT IN ('pending', 'completed', 'failed', 'cancelled') OR status IS NULL OR status = ''
GROUP BY status;

-- Check for invalid reference types
SELECT 
    'Invalid reference types' as issue_type,
    reference_type,
    COUNT(*) as count
FROM public.wallet_transactions 
WHERE reference_type IS NOT NULL 
  AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment')
  AND reference_type != ''
GROUP BY reference_type;

-- =====================================================
-- STEP 2: FIX WALLET DATA ISSUES
-- =====================================================

SELECT '=== FIXING WALLET DATA ISSUES ===' as section;

-- Fix wallets with null or invalid statuses
UPDATE public.wallets 
SET status = 'active' 
WHERE status IS NULL OR status = '' OR status NOT IN ('active', 'suspended', 'closed');

-- Fix wallets with null or invalid currencies
UPDATE public.wallets 
SET currency = 'EGP' 
WHERE currency IS NULL OR currency = '';

-- Fix wallets with null balances
UPDATE public.wallets 
SET balance = 0.00 
WHERE balance IS NULL;

-- Fix wallets with null timestamps
UPDATE public.wallets 
SET created_at = NOW() 
WHERE created_at IS NULL;

UPDATE public.wallets 
SET updated_at = NOW() 
WHERE updated_at IS NULL;

-- Delete wallets with null essential fields that can't be fixed
DELETE FROM public.wallets 
WHERE id IS NULL OR user_id IS NULL OR role IS NULL OR role = '';

-- =====================================================
-- STEP 3: FIX TRANSACTION DATA ISSUES
-- =====================================================

SELECT '=== FIXING TRANSACTION DATA ISSUES ===' as section;

-- Fix transactions with null or invalid statuses
UPDATE public.wallet_transactions 
SET status = 'completed' 
WHERE status IS NULL OR status = '' OR status NOT IN ('pending', 'completed', 'failed', 'cancelled');

-- Fix transactions with null or invalid transaction types
UPDATE public.wallet_transactions 
SET transaction_type = 'credit' 
WHERE transaction_type IS NULL OR transaction_type = '' 
   OR transaction_type NOT IN ('credit', 'debit', 'reward', 'salary', 'payment', 'refund', 'bonus', 'penalty', 'transfer');

-- Fix transactions with null amounts
UPDATE public.wallet_transactions 
SET amount = 0.00 
WHERE amount IS NULL;

-- Fix transactions with null balance fields
UPDATE public.wallet_transactions 
SET balance_before = 0.00 
WHERE balance_before IS NULL;

UPDATE public.wallet_transactions 
SET balance_after = 0.00 
WHERE balance_after IS NULL;

-- Fix transactions with null descriptions
UPDATE public.wallet_transactions 
SET description = 'معاملة غير محددة' 
WHERE description IS NULL OR description = '';

-- Fix transactions with null timestamps
UPDATE public.wallet_transactions 
SET created_at = NOW() 
WHERE created_at IS NULL;

-- Fix invalid reference types (set to null instead of invalid values)
UPDATE public.wallet_transactions 
SET reference_type = NULL 
WHERE reference_type IS NOT NULL 
  AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment')
  AND reference_type != '';

-- Delete transactions with null essential fields that can't be fixed
DELETE FROM public.wallet_transactions 
WHERE id IS NULL OR wallet_id IS NULL OR user_id IS NULL OR created_by IS NULL;

-- =====================================================
-- STEP 4: ADD MISSING CONSTRAINTS AND DEFAULTS
-- =====================================================

SELECT '=== ADDING MISSING CONSTRAINTS ===' as section;

-- Add NOT NULL constraints where missing (with defaults)
DO $$
BEGIN
    -- Ensure wallets table has proper constraints
    BEGIN
        ALTER TABLE public.wallets ALTER COLUMN status SET DEFAULT 'active';
        ALTER TABLE public.wallets ALTER COLUMN currency SET DEFAULT 'EGP';
        ALTER TABLE public.wallets ALTER COLUMN balance SET DEFAULT 0.00;
        ALTER TABLE public.wallets ALTER COLUMN created_at SET DEFAULT NOW();
        ALTER TABLE public.wallets ALTER COLUMN updated_at SET DEFAULT NOW();
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Some wallet constraints already exist or failed to add: %', SQLERRM;
    END;

    -- Ensure wallet_transactions table has proper constraints
    BEGIN
        ALTER TABLE public.wallet_transactions ALTER COLUMN status SET DEFAULT 'completed';
        ALTER TABLE public.wallet_transactions ALTER COLUMN balance_before SET DEFAULT 0.00;
        ALTER TABLE public.wallet_transactions ALTER COLUMN balance_after SET DEFAULT 0.00;
        ALTER TABLE public.wallet_transactions ALTER COLUMN created_at SET DEFAULT NOW();
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Some transaction constraints already exist or failed to add: %', SQLERRM;
    END;
END $$;

-- =====================================================
-- STEP 5: VERIFY FIXES
-- =====================================================

SELECT '=== VERIFICATION AFTER FIXES ===' as section;

-- Verify wallet data integrity
SELECT 
    'Wallets after fix' as table_name,
    COUNT(*) as total_count,
    COUNT(CASE WHEN status = 'active' THEN 1 END) as active_count,
    COUNT(CASE WHEN role = 'client' THEN 1 END) as client_count,
    COUNT(CASE WHEN role = 'worker' THEN 1 END) as worker_count,
    COUNT(CASE WHEN balance > 0 THEN 1 END) as positive_balance_count
FROM public.wallets;

-- Verify transaction data integrity
SELECT 
    'Transactions after fix' as table_name,
    COUNT(*) as total_count,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_count,
    COUNT(CASE WHEN transaction_type = 'credit' THEN 1 END) as credit_count,
    COUNT(CASE WHEN transaction_type = 'debit' THEN 1 END) as debit_count,
    COUNT(CASE WHEN reference_type = 'electronic_payment' THEN 1 END) as electronic_payment_count
FROM public.wallet_transactions;

-- Check for any remaining null essential fields
SELECT 
    'Remaining NULL issues' as check_type,
    'wallets' as table_name,
    COUNT(*) as null_count
FROM public.wallets 
WHERE id IS NULL OR user_id IS NULL OR role IS NULL OR role = ''

UNION ALL

SELECT 
    'Remaining NULL issues' as check_type,
    'transactions' as table_name,
    COUNT(*) as null_count
FROM public.wallet_transactions 
WHERE id IS NULL OR wallet_id IS NULL OR user_id IS NULL OR created_by IS NULL;

SELECT '=== CRITICAL WALLET ERROR FIX COMPLETED ===' as completion_status;
