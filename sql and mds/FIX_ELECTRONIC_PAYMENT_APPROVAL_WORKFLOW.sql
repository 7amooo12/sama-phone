-- ============================================================================
-- FIX ELECTRONIC PAYMENT APPROVAL WORKFLOW
-- ============================================================================
-- This script fixes the electronic payment approval workflow to properly
-- update electronic wallet balances instead of user wallets when payments
-- are approved.

BEGIN;

-- Step 1: Create function to update electronic wallet balance
CREATE OR REPLACE FUNCTION public.update_electronic_wallet_balance(
    wallet_uuid UUID,
    transaction_amount DECIMAL(10,2),
    transaction_type_param TEXT,
    description_param TEXT DEFAULT NULL,
    reference_id_param TEXT DEFAULT NULL,
    payment_id_param TEXT DEFAULT NULL,
    processed_by_param UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    wallet_record RECORD;
    new_balance DECIMAL(10,2);
    transaction_id UUID;
BEGIN
    -- Get current wallet information
    SELECT * INTO wallet_record
    FROM public.electronic_wallets
    WHERE id = wallet_uuid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Electronic wallet not found: %', wallet_uuid;
    END IF;

    -- Calculate new balance
    IF transaction_type_param = 'deposit' THEN
        new_balance := wallet_record.current_balance + transaction_amount;
    ELSIF transaction_type_param = 'withdrawal' THEN
        new_balance := wallet_record.current_balance - transaction_amount;
        IF new_balance < 0 THEN
            RAISE EXCEPTION 'Insufficient balance. Current: %, Requested: %',
                           wallet_record.current_balance, transaction_amount;
        END IF;
    ELSE
        RAISE EXCEPTION 'Invalid transaction type: %', transaction_type_param;
    END IF;

    -- Update wallet balance
    UPDATE public.electronic_wallets
    SET
        current_balance = new_balance,
        updated_at = now()
    WHERE id = wallet_uuid;

    -- Create transaction record
    INSERT INTO public.electronic_wallet_transactions (
        wallet_id,
        transaction_type,
        amount,
        balance_before,
        balance_after,
        status,
        description,
        reference_id,
        payment_id,
        processed_by,
        created_at,
        updated_at
    ) VALUES (
        wallet_uuid,
        transaction_type_param,
        transaction_amount,
        wallet_record.current_balance,
        new_balance,
        'completed',
        description_param,
        reference_id_param,
        payment_id_param,
        processed_by_param,
        now(),
        now()
    ) RETURNING id INTO transaction_id;

    RAISE NOTICE 'Updated electronic wallet % balance from % to % (transaction: %)',
                 wallet_uuid, wallet_record.current_balance, new_balance, transaction_id;

    RETURN transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 1.5: Create function to update client wallet balance
CREATE OR REPLACE FUNCTION public.update_client_wallet_balance(
    client_user_id UUID,
    transaction_amount DECIMAL(10,2),
    transaction_type_param TEXT,
    description_param TEXT DEFAULT NULL,
    reference_id_param TEXT DEFAULT NULL,
    payment_id_param TEXT DEFAULT NULL,
    processed_by_param UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    wallet_record RECORD;
    new_balance DECIMAL(10,2);
    transaction_id UUID;
BEGIN
    -- Get current client wallet information
    SELECT * INTO wallet_record
    FROM public.wallets
    WHERE user_id = client_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Client wallet not found for user: %', client_user_id;
    END IF;

    -- Calculate new balance
    IF transaction_type_param = 'debit' OR transaction_type_param = 'payment' THEN
        new_balance := wallet_record.balance - transaction_amount;
        IF new_balance < 0 THEN
            RAISE EXCEPTION 'رصيد العميل غير كافي لإتمام العملية. الرصيد الحالي: % ج.م، المطلوب: % ج.م',
                           wallet_record.balance, transaction_amount;
        END IF;
    ELSIF transaction_type_param = 'credit' OR transaction_type_param = 'deposit' THEN
        new_balance := wallet_record.balance + transaction_amount;
    ELSE
        RAISE EXCEPTION 'Invalid transaction type: %', transaction_type_param;
    END IF;

    -- Update client wallet balance
    UPDATE public.wallets
    SET
        balance = new_balance,
        updated_at = now()
    WHERE user_id = client_user_id;

    -- Create transaction record in wallet_transactions
    INSERT INTO public.wallet_transactions (
        wallet_id,
        transaction_type,
        amount,
        balance_before,
        balance_after,
        description,
        reference_id,
        reference_type,
        status,
        created_by,
        created_at,
        updated_at
    ) VALUES (
        wallet_record.id,
        transaction_type_param,
        transaction_amount,
        wallet_record.balance,
        new_balance,
        description_param,
        payment_id_param,
        'electronic_payment',
        'completed',
        processed_by_param,
        now(),
        now()
    ) RETURNING id INTO transaction_id;

    RAISE NOTICE 'Updated client wallet % balance from % to % (transaction: %)',
                 wallet_record.id, wallet_record.balance, new_balance, transaction_id;

    RETURN transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 1.6: Create dual wallet transaction function (atomic operation)
CREATE OR REPLACE FUNCTION public.process_dual_wallet_transaction(
    client_user_id UUID,
    electronic_wallet_id UUID,
    transaction_amount DECIMAL(10,2),
    payment_id_param TEXT,
    description_param TEXT DEFAULT NULL,
    processed_by_param UUID DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
    client_wallet_record RECORD;
    electronic_wallet_record RECORD;
    client_transaction_id UUID;
    electronic_transaction_id UUID;
    result JSON;
BEGIN
    -- Start transaction block for atomicity
    -- Validate client wallet exists and has sufficient balance
    SELECT * INTO client_wallet_record
    FROM public.wallets
    WHERE user_id = client_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'محفظة العميل غير موجودة للمستخدم: %', client_user_id;
    END IF;

    IF client_wallet_record.balance < transaction_amount THEN
        RAISE EXCEPTION 'رصيد العميل غير كافي لإتمام العملية. الرصيد الحالي: % ج.م، المطلوب: % ج.م',
                       client_wallet_record.balance, transaction_amount;
    END IF;

    -- Validate electronic wallet exists and is active
    SELECT * INTO electronic_wallet_record
    FROM public.electronic_wallets
    WHERE id = electronic_wallet_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'المحفظة الإلكترونية غير موجودة: %', electronic_wallet_id;
    END IF;

    IF electronic_wallet_record.status != 'active' THEN
        RAISE EXCEPTION 'المحفظة الإلكترونية غير نشطة: %', electronic_wallet_id;
    END IF;

    -- Perform client wallet debit (atomic)
    SELECT public.update_client_wallet_balance(
        client_user_id,
        transaction_amount,
        'payment',
        description_param || ' - خصم من محفظة العميل',
        payment_id_param,
        payment_id_param,
        processed_by_param
    ) INTO client_transaction_id;

    -- Perform electronic wallet credit (atomic)
    SELECT public.update_electronic_wallet_balance(
        electronic_wallet_id,
        transaction_amount,
        'deposit',
        description_param || ' - إيداع في المحفظة الإلكترونية',
        payment_id_param,
        payment_id_param,
        processed_by_param
    ) INTO electronic_transaction_id;

    -- Create result JSON
    result := json_build_object(
        'success', true,
        'client_transaction_id', client_transaction_id,
        'electronic_transaction_id', electronic_transaction_id,
        'client_balance_before', client_wallet_record.balance,
        'client_balance_after', client_wallet_record.balance - transaction_amount,
        'electronic_balance_before', electronic_wallet_record.current_balance,
        'electronic_balance_after', electronic_wallet_record.current_balance + transaction_amount,
        'amount', transaction_amount
    );

    RAISE NOTICE 'Dual wallet transaction completed: Client % debited % EGP, Electronic wallet % credited % EGP',
                 client_user_id, transaction_amount, electronic_wallet_id, transaction_amount;

    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        -- Rollback is automatic in PostgreSQL for failed transactions
        RAISE EXCEPTION 'فشل في معالجة المعاملة المزدوجة: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Create new function to handle electronic payment approval with dual wallet system
CREATE OR REPLACE FUNCTION public.handle_electronic_payment_approval_v3()
RETURNS TRIGGER AS $$
DECLARE
    client_wallet_record RECORD;
    electronic_wallet_record RECORD;
    account_record RECORD;
    transaction_result JSON;
BEGIN
    -- Only process if status changed to 'approved'
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN

        -- Validate payment account exists
        SELECT * INTO account_record
        FROM public.payment_accounts
        WHERE id = NEW.recipient_account_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'حساب الدفع غير موجود: %', NEW.recipient_account_id;
        END IF;

        -- Validate electronic wallet exists
        SELECT * INTO electronic_wallet_record
        FROM public.electronic_wallets
        WHERE id = NEW.recipient_account_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'المحفظة الإلكترونية غير موجودة: %', NEW.recipient_account_id;
        END IF;

        -- Validate client wallet exists
        SELECT * INTO client_wallet_record
        FROM public.wallets
        WHERE user_id = NEW.client_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'محفظة العميل غير موجودة للمستخدم: %', NEW.client_id;
        END IF;

        -- Check client wallet balance before processing
        IF client_wallet_record.balance < NEW.amount THEN
            RAISE EXCEPTION 'رصيد العميل غير كافي لإتمام العملية. الرصيد الحالي: % ج.م، المطلوب: % ج.م',
                           client_wallet_record.balance, NEW.amount;
        END IF;

        -- Process dual wallet transaction atomically
        SELECT public.process_dual_wallet_transaction(
            NEW.client_id,
            NEW.recipient_account_id,
            NEW.amount,
            NEW.id,
            'دفعة إلكترونية - ' ||
            CASE
                WHEN NEW.payment_method = 'vodafone_cash' THEN 'فودافون كاش'
                WHEN NEW.payment_method = 'instapay' THEN 'إنستاباي'
                ELSE 'دفع إلكتروني'
            END,
            NEW.approved_by
        ) INTO transaction_result;

        RAISE NOTICE 'Electronic payment approved with dual wallet transaction: Payment %, Amount % EGP, Result: %',
                     NEW.id, NEW.amount, transaction_result;
    END IF;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error with Arabic message for better debugging
        RAISE EXCEPTION 'خطأ في معالجة اعتماد الدفعة الإلكترونية: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Replace the old trigger with the new one
DROP TRIGGER IF EXISTS trigger_electronic_payment_approval ON public.electronic_payments;
DROP TRIGGER IF EXISTS trigger_electronic_payment_approval_v2 ON public.electronic_payments;
CREATE TRIGGER trigger_electronic_payment_approval_v3
    AFTER UPDATE ON public.electronic_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_electronic_payment_approval_v3();

-- Step 4: Create function to sync existing electronic wallets with payment accounts
CREATE OR REPLACE FUNCTION public.sync_all_electronic_wallets_with_payment_accounts()
RETURNS INTEGER AS $$
DECLARE
    synced_count INTEGER := 0;
    wallet_record RECORD;
BEGIN
    -- Insert payment accounts for all electronic wallets that don't have them
    FOR wallet_record IN 
        SELECT ew.* 
        FROM public.electronic_wallets ew
        LEFT JOIN public.payment_accounts pa ON ew.id = pa.id
        WHERE pa.id IS NULL
    LOOP
        INSERT INTO public.payment_accounts (
            id,
            account_type,
            account_number,
            account_holder_name,
            is_active,
            created_at,
            updated_at
        ) VALUES (
            wallet_record.id,
            wallet_record.wallet_type,
            wallet_record.phone_number,
            wallet_record.wallet_name,
            CASE WHEN wallet_record.status = 'active' THEN true ELSE false END,
            wallet_record.created_at,
            wallet_record.updated_at
        );
        
        synced_count := synced_count + 1;
        RAISE NOTICE 'Created payment account for wallet: % (%)', 
                     wallet_record.wallet_name, wallet_record.id;
    END LOOP;
    
    -- Update existing payment accounts to match wallet data
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
    
    RAISE NOTICE 'Synchronized % electronic wallets with payment accounts', synced_count;
    RETURN synced_count;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Run the synchronization
SELECT public.sync_all_electronic_wallets_with_payment_accounts();

-- Step 6: Create trigger to automatically sync when wallets are created/updated
CREATE OR REPLACE FUNCTION public.auto_sync_payment_account_with_wallet()
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

DROP TRIGGER IF EXISTS auto_sync_payment_account_trigger ON public.electronic_wallets;
CREATE TRIGGER auto_sync_payment_account_trigger
    AFTER INSERT OR UPDATE ON public.electronic_wallets
    FOR EACH ROW
    EXECUTE FUNCTION public.auto_sync_payment_account_with_wallet();

-- Step 7: Verification
DO $$
DECLARE
    wallet_count INTEGER;
    account_count INTEGER;
    synced_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO wallet_count FROM public.electronic_wallets;
    SELECT COUNT(*) INTO account_count FROM public.payment_accounts 
    WHERE account_type IN ('vodafone_cash', 'instapay');
    
    SELECT COUNT(*) INTO synced_count 
    FROM public.electronic_wallets ew
    INNER JOIN public.payment_accounts pa ON ew.id = pa.id;
    
    RAISE NOTICE '=== VERIFICATION REPORT ===';
    RAISE NOTICE 'Electronic wallets: %', wallet_count;
    RAISE NOTICE 'Payment accounts (wallet types): %', account_count;
    RAISE NOTICE 'Synced wallets: %', synced_count;
    
    IF synced_count = wallet_count THEN
        RAISE NOTICE '✅ All electronic wallets are properly synced with payment accounts';
        RAISE NOTICE '✅ Electronic payment approval workflow updated successfully';
    ELSE
        RAISE NOTICE '⚠️ Some wallets may not be properly synced';
    END IF;
END;
$$;

COMMIT;

-- ============================================================================
-- USAGE NOTES
-- ============================================================================
-- 
-- This migration:
-- 1. Creates a new function to update electronic wallet balances
-- 2. Updates the payment approval workflow to deposit to electronic wallets
-- 3. Automatically syncs all existing electronic wallets with payment accounts
-- 4. Creates triggers to maintain synchronization going forward
-- 5. Ensures clients can see newly created wallets as payment options
-- 
-- After running this migration:
-- - Newly created electronic wallets will automatically appear as payment options
-- - When payments are approved, the electronic wallet balance will be updated
-- - The synchronization between wallets and payment accounts is maintained
-- ============================================================================
