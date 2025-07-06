-- Comprehensive verification script for electronic payment system integration
-- Migration: 20241220000002_verify_electronic_payment_integration.sql

-- This script thoroughly tests the electronic payment system integration
-- with the existing wallet system to ensure everything works correctly

-- Begin verification transaction
BEGIN;

-- ============================================================================
-- STEP 1: Verify Database Structure
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '🔍 Starting Electronic Payment System Verification...';
    RAISE NOTICE '';
END $$;

-- 1.1 Verify that the wallet_transactions table exists and has the correct structure
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'wallet_transactions' AND table_schema = 'public') THEN
        RAISE EXCEPTION 'CRITICAL: wallet_transactions table does not exist. Please run wallet system migration first.';
    END IF;

    -- Check if reference_type column exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'wallet_transactions' AND column_name = 'reference_type' AND table_schema = 'public') THEN
        RAISE EXCEPTION 'CRITICAL: wallet_transactions table missing reference_type column.';
    END IF;

    RAISE NOTICE '✅ wallet_transactions table structure verified.';
END $$;

-- 1.2 Verify that the wallets table exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'wallets' AND table_schema = 'public') THEN
        RAISE EXCEPTION 'CRITICAL: wallets table does not exist. Please run wallet system migration first.';
    END IF;

    RAISE NOTICE '✅ wallets table verified.';
END $$;

-- 1.3 Verify that the electronic payment tables were created successfully
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payment_accounts' AND table_schema = 'public') THEN
        RAISE EXCEPTION 'CRITICAL: payment_accounts table was not created.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'electronic_payments' AND table_schema = 'public') THEN
        RAISE EXCEPTION 'CRITICAL: electronic_payments table was not created.';
    END IF;

    RAISE NOTICE '✅ Electronic payment tables created successfully.';
END $$;

-- ============================================================================
-- STEP 2: Verify Functions and Triggers
-- ============================================================================

-- 4. Verify that the electronic payment approval function exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.routines 
                   WHERE routine_name = 'handle_electronic_payment_approval') THEN
        RAISE EXCEPTION 'handle_electronic_payment_approval function was not created.';
    END IF;
    
    RAISE NOTICE 'Electronic payment approval function verified.';
END $$;

-- 5. Verify that the electronic payment trigger exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.triggers 
                   WHERE trigger_name = 'trigger_electronic_payment_approval') THEN
        RAISE EXCEPTION 'trigger_electronic_payment_approval was not created.';
    END IF;
    
    RAISE NOTICE 'Electronic payment trigger verified.';
END $$;

-- 6. Verify that the existing wallet triggers still exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.triggers 
                   WHERE trigger_name = 'trigger_update_wallet_balance') THEN
        RAISE EXCEPTION 'Existing wallet trigger trigger_update_wallet_balance is missing.';
    END IF;
    
    RAISE NOTICE 'Existing wallet triggers verified.';
END $$;

-- 7. Verify that the reference_type constraint includes 'electronic_payment'
DO $$
BEGIN
    -- Test the constraint by attempting to insert a valid electronic_payment reference_type
    -- This will fail if the constraint doesn't include 'electronic_payment'
    
    -- First, ensure we have a test user and wallet (we'll clean up after)
    INSERT INTO auth.users (id, email) VALUES ('00000000-0000-0000-0000-000000000001', 'test@electronic-payment.com')
    ON CONFLICT (id) DO NOTHING;
    
    INSERT INTO public.user_profiles (id, name, email, role, status) VALUES 
    ('00000000-0000-0000-0000-000000000001', 'Test User', 'test@electronic-payment.com', 'client', 'active')
    ON CONFLICT (id) DO NOTHING;
    
    INSERT INTO public.wallets (user_id, balance, role) VALUES 
    ('00000000-0000-0000-0000-000000000001', 0.00, 'client')
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Test inserting a wallet transaction with electronic_payment reference_type
    INSERT INTO public.wallet_transactions (
        wallet_id,
        user_id,
        transaction_type,
        amount,
        description,
        reference_type,
        status
    )
    SELECT 
        w.id,
        '00000000-0000-0000-0000-000000000001',
        'credit',
        100.00,
        'Test electronic payment transaction',
        'electronic_payment',
        'completed'
    FROM public.wallets w 
    WHERE w.user_id = '00000000-0000-0000-0000-000000000001';
    
    -- Clean up test data
    DELETE FROM public.wallet_transactions 
    WHERE user_id = '00000000-0000-0000-0000-000000000001' 
    AND description = 'Test electronic payment transaction';
    
    DELETE FROM public.wallets WHERE user_id = '00000000-0000-0000-0000-000000000001';
    DELETE FROM public.user_profiles WHERE id = '00000000-0000-0000-0000-000000000001';
    DELETE FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000001';
    
    RAISE NOTICE 'Reference type constraint verified - electronic_payment is allowed.';
END $$;

-- 8. Test the complete integration flow (simulation)
DO $$
DECLARE
    test_user_id UUID := '00000000-0000-0000-0000-000000000002';
    test_wallet_id UUID;
    test_account_id UUID;
    test_payment_id UUID;
    initial_balance DECIMAL(15,2);
    final_balance DECIMAL(15,2);
BEGIN
    -- Create test data
    INSERT INTO auth.users (id, email) VALUES (test_user_id, 'integration-test@electronic-payment.com')
    ON CONFLICT (id) DO NOTHING;
    
    INSERT INTO public.user_profiles (id, name, email, role, status) VALUES 
    (test_user_id, 'Integration Test User', 'integration-test@electronic-payment.com', 'client', 'active')
    ON CONFLICT (id) DO NOTHING;
    
    INSERT INTO public.wallets (user_id, balance, role) VALUES 
    (test_user_id, 50.00, 'client')
    ON CONFLICT (user_id) DO UPDATE SET balance = 50.00;
    
    SELECT id, balance INTO test_wallet_id, initial_balance 
    FROM public.wallets WHERE user_id = test_user_id;
    
    -- Create test payment account
    INSERT INTO public.payment_accounts (account_type, account_number, account_holder_name, is_active)
    VALUES ('vodafone_cash', '01999999999', 'Test Account', true)
    RETURNING id INTO test_account_id;
    
    -- Create test electronic payment
    INSERT INTO public.electronic_payments (
        client_id, payment_method, amount, recipient_account_id, status
    ) VALUES (
        test_user_id, 'vodafone_cash', 25.00, test_account_id, 'pending'
    ) RETURNING id INTO test_payment_id;
    
    -- Simulate payment approval (this should trigger wallet balance update)
    UPDATE public.electronic_payments 
    SET status = 'approved', approved_by = test_user_id, approved_at = now()
    WHERE id = test_payment_id;
    
    -- Check if wallet balance was updated correctly
    SELECT balance INTO final_balance 
    FROM public.wallets WHERE user_id = test_user_id;
    
    IF final_balance != initial_balance + 25.00 THEN
        RAISE EXCEPTION 'Integration test failed: Expected balance %, got %', 
                       initial_balance + 25.00, final_balance;
    END IF;
    
    -- Verify wallet transaction was created
    IF NOT EXISTS (
        SELECT 1 FROM public.wallet_transactions 
        WHERE user_id = test_user_id 
        AND reference_type = 'electronic_payment'
        AND reference_id = test_payment_id
    ) THEN
        RAISE EXCEPTION 'Integration test failed: Wallet transaction not created';
    END IF;
    
    -- Clean up test data
    DELETE FROM public.wallet_transactions WHERE user_id = test_user_id;
    DELETE FROM public.electronic_payments WHERE id = test_payment_id;
    DELETE FROM public.payment_accounts WHERE id = test_account_id;
    DELETE FROM public.wallets WHERE user_id = test_user_id;
    DELETE FROM public.user_profiles WHERE id = test_user_id;
    DELETE FROM auth.users WHERE id = test_user_id;
    
    RAISE NOTICE 'Integration test passed: Electronic payment approval correctly updated wallet balance from % to %', 
                 initial_balance, final_balance;
END $$;

-- 9. Final verification message
DO $$
BEGIN
    RAISE NOTICE '✅ Electronic Payment System Integration Verification Complete!';
    RAISE NOTICE '   - All required tables exist';
    RAISE NOTICE '   - All triggers and functions are properly configured';
    RAISE NOTICE '   - Wallet integration works correctly';
    RAISE NOTICE '   - No conflicts with existing wallet system';
    RAISE NOTICE '   - Electronic payment approval automatically updates wallet balances';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 The electronic payment system is ready for use!';
END $$;
