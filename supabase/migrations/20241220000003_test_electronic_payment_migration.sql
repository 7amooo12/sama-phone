-- Test script for electronic payment system migration
-- Migration: 20241220000003_test_electronic_payment_migration.sql
-- This script tests the electronic payment system to ensure it works correctly

-- Begin test transaction
BEGIN;

DO $$
DECLARE
    test_user_id UUID := '00000000-0000-0000-0000-000000000001';
    test_admin_id UUID := '00000000-0000-0000-0000-000000000002';
    test_wallet_id UUID;
    test_account_id UUID;
    test_payment_id UUID;
    initial_balance DECIMAL(15,2);
    final_balance DECIMAL(15,2);
    transaction_count INTEGER;
BEGIN
    RAISE NOTICE '🧪 Starting Electronic Payment System Test...';
    RAISE NOTICE '';
    
    -- Create test users
    INSERT INTO auth.users (id, email, confirmed_at) VALUES 
    (test_user_id, 'test-client@electronic-payment.com', now()),
    (test_admin_id, 'test-admin@electronic-payment.com', now())
    ON CONFLICT (id) DO NOTHING;
    
    INSERT INTO public.user_profiles (id, name, email, role, status) VALUES 
    (test_user_id, 'Test Client', 'test-client@electronic-payment.com', 'client', 'active'),
    (test_admin_id, 'Test Admin', 'test-admin@electronic-payment.com', 'admin', 'active')
    ON CONFLICT (id) DO NOTHING;
    
    -- Create test wallet
    INSERT INTO public.wallets (user_id, balance, role) VALUES 
    (test_user_id, 100.00, 'client')
    ON CONFLICT (user_id) DO UPDATE SET balance = 100.00;
    
    SELECT id, balance INTO test_wallet_id, initial_balance 
    FROM public.wallets WHERE user_id = test_user_id;
    
    RAISE NOTICE '   ✅ Test wallet created with balance: % EGP', initial_balance;
    
    -- Create test payment account
    INSERT INTO public.payment_accounts (account_type, account_number, account_holder_name, is_active)
    VALUES ('vodafone_cash', '01999999999', 'Test Integration Account', true)
    ON CONFLICT (account_type, account_number) DO UPDATE SET account_holder_name = 'Test Integration Account'
    RETURNING id INTO test_account_id;
    
    RAISE NOTICE '   ✅ Test payment account created';
    
    -- Create test electronic payment
    INSERT INTO public.electronic_payments (
        client_id, payment_method, amount, recipient_account_id, status
    ) VALUES (
        test_user_id, 'vodafone_cash', 50.00, test_account_id, 'pending'
    ) RETURNING id INTO test_payment_id;
    
    RAISE NOTICE '   ✅ Test payment created: 50.00 EGP (pending)';
    
    -- Count initial wallet transactions
    SELECT COUNT(*) INTO transaction_count
    FROM public.wallet_transactions 
    WHERE user_id = test_user_id;
    
    RAISE NOTICE '   📊 Initial transaction count: %', transaction_count;
    
    -- Simulate payment approval (this should trigger wallet balance update)
    UPDATE public.electronic_payments 
    SET status = 'approved', approved_by = test_admin_id, approved_at = now()
    WHERE id = test_payment_id;
    
    RAISE NOTICE '   ✅ Payment approved by admin';
    
    -- Check if wallet balance was updated correctly
    SELECT balance INTO final_balance 
    FROM public.wallets WHERE user_id = test_user_id;
    
    RAISE NOTICE '   📊 Final wallet balance: % EGP', final_balance;
    
    -- Verify balance calculation
    IF final_balance != initial_balance + 50.00 THEN
        RAISE EXCEPTION '❌ TEST FAILED: Expected balance %, got %', 
                       initial_balance + 50.00, final_balance;
    END IF;
    
    -- Verify wallet transaction was created
    IF NOT EXISTS (
        SELECT 1 FROM public.wallet_transactions 
        WHERE user_id = test_user_id 
        AND reference_type = 'electronic_payment'
        AND reference_id = test_payment_id
        AND amount = 50.00
    ) THEN
        RAISE EXCEPTION '❌ TEST FAILED: Wallet transaction not created correctly';
    END IF;
    
    -- Count final wallet transactions
    SELECT COUNT(*) INTO transaction_count
    FROM public.wallet_transactions 
    WHERE user_id = test_user_id;
    
    RAISE NOTICE '   📊 Final transaction count: %', transaction_count;
    
    -- Verify transaction details
    IF NOT EXISTS (
        SELECT 1 FROM public.wallet_transactions 
        WHERE user_id = test_user_id 
        AND reference_type = 'electronic_payment'
        AND transaction_type = 'credit'
        AND status = 'completed'
        AND description LIKE '%Electronic payment via vodafone_cash%'
    ) THEN
        RAISE EXCEPTION '❌ TEST FAILED: Transaction details incorrect';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎉 ALL TESTS PASSED!';
    RAISE NOTICE '   ✅ Electronic payment approval correctly updated wallet balance from % to %', 
                 initial_balance, final_balance;
    RAISE NOTICE '   ✅ Wallet transaction created with correct details';
    RAISE NOTICE '   ✅ Integration with existing wallet system working perfectly';
    
    -- Clean up test data
    DELETE FROM public.wallet_transactions WHERE user_id IN (test_user_id, test_admin_id);
    DELETE FROM public.electronic_payments WHERE id = test_payment_id;
    DELETE FROM public.payment_accounts WHERE id = test_account_id;
    DELETE FROM public.wallets WHERE user_id IN (test_user_id, test_admin_id);
    DELETE FROM public.user_profiles WHERE id IN (test_user_id, test_admin_id);
    DELETE FROM auth.users WHERE id IN (test_user_id, test_admin_id);
    
    RAISE NOTICE '   🧹 Test data cleaned up successfully';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Electronic Payment System is ready for production use!';
    
EXCEPTION
    WHEN OTHERS THEN
        -- Clean up test data even if test fails
        DELETE FROM public.wallet_transactions WHERE user_id IN (test_user_id, test_admin_id);
        DELETE FROM public.electronic_payments WHERE client_id IN (test_user_id, test_admin_id);
        DELETE FROM public.payment_accounts WHERE account_number = '01999999999';
        DELETE FROM public.wallets WHERE user_id IN (test_user_id, test_admin_id);
        DELETE FROM public.user_profiles WHERE id IN (test_user_id, test_admin_id);
        DELETE FROM auth.users WHERE id IN (test_user_id, test_admin_id);
        
        RAISE EXCEPTION 'Test failed: %', SQLERRM;
END $$;

-- Commit test transaction
COMMIT;
