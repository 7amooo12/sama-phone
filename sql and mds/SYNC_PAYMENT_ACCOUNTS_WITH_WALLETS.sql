-- ============================================================================
-- SYNC PAYMENT ACCOUNTS WITH ELECTRONIC WALLETS
-- ============================================================================
-- This script ensures that all electronic wallets have corresponding payment accounts
-- to prevent foreign key constraint violations when creating electronic payments.

BEGIN;

-- Step 1: Insert payment accounts for existing electronic wallets that don't have them
INSERT INTO public.payment_accounts (
    id,
    account_type,
    account_number,
    account_holder_name,
    is_active,
    created_at,
    updated_at
)
SELECT 
    ew.id,
    ew.wallet_type,
    ew.phone_number,
    ew.wallet_name,
    CASE WHEN ew.status = 'active' THEN true ELSE false END,
    ew.created_at,
    ew.updated_at
FROM public.electronic_wallets ew
LEFT JOIN public.payment_accounts pa ON ew.id = pa.id
WHERE pa.id IS NULL;

-- Step 2: Update existing payment accounts to match wallet data
UPDATE public.payment_accounts 
SET 
    account_type = ew.wallet_type,
    account_number = ew.phone_number,
    account_holder_name = ew.wallet_name,
    is_active = CASE WHEN ew.status = 'active' THEN true ELSE false END,
    updated_at = now()
FROM public.electronic_wallets ew
WHERE payment_accounts.id = ew.id
AND (
    payment_accounts.account_type != ew.wallet_type OR
    payment_accounts.account_number != ew.phone_number OR
    payment_accounts.account_holder_name != ew.wallet_name OR
    payment_accounts.is_active != CASE WHEN ew.status = 'active' THEN true ELSE false END
);

-- Step 3: Create a function to automatically sync payment accounts when wallets are modified
CREATE OR REPLACE FUNCTION sync_payment_account_with_wallet()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert or update payment account to match wallet
    INSERT INTO public.payment_accounts (
        id,
        account_type,
        account_number,
        account_holder_name,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        NEW.id,
        NEW.wallet_type,
        NEW.phone_number,
        NEW.wallet_name,
        CASE WHEN NEW.status = 'active' THEN true ELSE false END,
        NEW.created_at,
        NEW.updated_at
    )
    ON CONFLICT (id) DO UPDATE SET
        account_type = NEW.wallet_type,
        account_number = NEW.phone_number,
        account_holder_name = NEW.wallet_name,
        is_active = CASE WHEN NEW.status = 'active' THEN true ELSE false END,
        updated_at = NEW.updated_at;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create trigger to automatically sync on wallet changes
DROP TRIGGER IF EXISTS sync_payment_account_trigger ON public.electronic_wallets;
CREATE TRIGGER sync_payment_account_trigger
    AFTER INSERT OR UPDATE ON public.electronic_wallets
    FOR EACH ROW
    EXECUTE FUNCTION sync_payment_account_with_wallet();

-- Step 5: Create a function to clean up orphaned payment accounts
CREATE OR REPLACE FUNCTION cleanup_orphaned_payment_accounts()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete payment accounts that don't have corresponding wallets
    DELETE FROM public.payment_accounts
    WHERE id NOT IN (
        SELECT id FROM public.electronic_wallets
    )
    AND account_type IN ('vodafone_cash', 'instapay');
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RAISE NOTICE 'Cleaned up % orphaned payment accounts', deleted_count;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Verify the synchronization
DO $$
DECLARE
    wallet_count INTEGER;
    account_count INTEGER;
    synced_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO wallet_count FROM public.electronic_wallets;
    SELECT COUNT(*) INTO account_count FROM public.payment_accounts WHERE account_type IN ('vodafone_cash', 'instapay');
    
    SELECT COUNT(*) INTO synced_count 
    FROM public.electronic_wallets ew
    INNER JOIN public.payment_accounts pa ON ew.id = pa.id
    WHERE pa.account_type = ew.wallet_type
    AND pa.account_number = ew.phone_number
    AND pa.account_holder_name = ew.wallet_name;
    
    RAISE NOTICE '=== SYNCHRONIZATION REPORT ===';
    RAISE NOTICE 'Electronic wallets: %', wallet_count;
    RAISE NOTICE 'Payment accounts (wallet types): %', account_count;
    RAISE NOTICE 'Properly synced accounts: %', synced_count;
    
    IF synced_count = wallet_count THEN
        RAISE NOTICE '✅ All wallets are properly synced with payment accounts';
    ELSE
        RAISE NOTICE '⚠️ Some wallets may not be properly synced';
    END IF;
END;
$$;

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check for wallets without payment accounts
SELECT 
    ew.id,
    ew.wallet_name,
    ew.wallet_type,
    ew.phone_number,
    ew.status
FROM public.electronic_wallets ew
LEFT JOIN public.payment_accounts pa ON ew.id = pa.id
WHERE pa.id IS NULL;

-- Check for mismatched data between wallets and payment accounts
SELECT 
    ew.id,
    ew.wallet_name AS wallet_name,
    pa.account_holder_name AS account_name,
    ew.wallet_type AS wallet_type,
    pa.account_type AS account_type,
    ew.phone_number AS wallet_phone,
    pa.account_number AS account_number,
    ew.status AS wallet_status,
    pa.is_active AS account_active
FROM public.electronic_wallets ew
INNER JOIN public.payment_accounts pa ON ew.id = pa.id
WHERE 
    ew.wallet_type != pa.account_type OR
    ew.phone_number != pa.account_number OR
    ew.wallet_name != pa.account_holder_name OR
    (ew.status = 'active') != pa.is_active;

-- Check for orphaned payment accounts
SELECT 
    pa.id,
    pa.account_holder_name,
    pa.account_type,
    pa.account_number
FROM public.payment_accounts pa
LEFT JOIN public.electronic_wallets ew ON pa.id = ew.id
WHERE ew.id IS NULL
AND pa.account_type IN ('vodafone_cash', 'instapay');
