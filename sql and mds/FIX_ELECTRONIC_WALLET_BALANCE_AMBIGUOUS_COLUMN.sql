-- ============================================================================
-- FIX ELECTRONIC WALLET BALANCE AMBIGUOUS COLUMN REFERENCE
-- ============================================================================
-- 
-- Purpose: Fix PostgrestException error caused by ambiguous column reference
--          "current_balance" in the update_wallet_balance stored function
-- 
-- Error Details:
-- - PostgrestException(message: column reference "current_balance" is ambiguous, 
--   code: 42702, details: It could refer to either a PL/pgSQL variable or a 
--   table column., hint: null)
-- 
-- Root Cause: Both the PL/pgSQL DECLARE variable and the electronic_wallets 
--             table column were named "current_balance"
-- 
-- Solution: Rename PL/pgSQL variable to "wallet_current_balance" and update
--           all variable references throughout the function
-- 
-- Date: 2025-06-18
-- ============================================================================

-- Drop the existing function first to ensure clean replacement
DROP FUNCTION IF EXISTS public.update_wallet_balance(UUID, DECIMAL, TEXT, TEXT, TEXT, UUID, UUID);

-- Create the corrected function with fixed variable naming
CREATE OR REPLACE FUNCTION public.update_wallet_balance(
    wallet_uuid UUID,
    transaction_amount DECIMAL(12,2),
    transaction_type_param TEXT,
    description_param TEXT DEFAULT NULL,
    reference_id_param TEXT DEFAULT NULL,
    payment_id_param UUID DEFAULT NULL,
    processed_by_param UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    wallet_current_balance DECIMAL(12,2);  -- Renamed from current_balance to avoid ambiguity
    new_balance DECIMAL(12,2);
    transaction_id UUID;
BEGIN
    -- Get current balance with table alias to avoid ambiguity
    SELECT ew.current_balance INTO wallet_current_balance
    FROM public.electronic_wallets ew
    WHERE ew.id = wallet_uuid AND ew.status = 'active';
    
    -- Check if wallet was found and is active
    IF wallet_current_balance IS NULL THEN
        RAISE EXCEPTION 'Wallet not found or inactive';
    END IF;
    
    -- Calculate new balance based on transaction type
    IF transaction_type_param IN ('deposit', 'refund') THEN
        new_balance := wallet_current_balance + transaction_amount;
    ELSIF transaction_type_param IN ('withdrawal', 'payment') THEN
        -- Check for sufficient balance before withdrawal/payment
        IF wallet_current_balance < transaction_amount THEN
            RAISE EXCEPTION 'Insufficient balance';
        END IF;
        new_balance := wallet_current_balance - transaction_amount;
    ELSE
        RAISE EXCEPTION 'Invalid transaction type';
    END IF;
    
    -- Create transaction record
    INSERT INTO public.electronic_wallet_transactions (
        wallet_id, transaction_type, amount, balance_before, balance_after,
        status, description, reference_id, payment_id, processed_by
    ) VALUES (
        wallet_uuid, transaction_type_param, transaction_amount, 
        wallet_current_balance, new_balance,  -- Use renamed variable
        'completed', description_param, reference_id_param, 
        payment_id_param, processed_by_param
    ) RETURNING id INTO transaction_id;
    
    -- Update wallet balance in electronic_wallets table
    UPDATE public.electronic_wallets
    SET current_balance = new_balance, updated_at = now()
    WHERE id = wallet_uuid;
    
    RETURN transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.update_wallet_balance(UUID, DECIMAL, TEXT, TEXT, TEXT, UUID, UUID) TO authenticated;

-- Grant execute permissions to service_role
GRANT EXECUTE ON FUNCTION public.update_wallet_balance(UUID, DECIMAL, TEXT, TEXT, TEXT, UUID, UUID) TO service_role;

-- ============================================================================
-- VERIFICATION TESTS
-- ============================================================================

-- Test 1: Verify function exists and has correct signature
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'update_wallet_balance';

-- Test 2: Verify function can be called without syntax errors
-- Note: This will fail if no test wallet exists, but should not have syntax errors
DO $$
DECLARE
    test_result UUID;
BEGIN
    -- This is just a syntax test - will likely fail due to no test data
    -- but should not have ambiguous column reference errors
    BEGIN
        SELECT public.update_wallet_balance(
            '00000000-0000-0000-0000-000000000000'::UUID,
            100.00,
            'deposit',
            'Test transaction',
            'TEST_REF',
            NULL,
            NULL
        ) INTO test_result;
    EXCEPTION
        WHEN OTHERS THEN
            -- Expected to fail due to no test wallet, but should not be ambiguous column error
            IF SQLSTATE = '42702' THEN
                RAISE EXCEPTION 'FAILED: Ambiguous column reference still exists';
            ELSE
                RAISE NOTICE 'SUCCESS: Function syntax is correct (expected error: %)', SQLERRM;
            END IF;
    END;
END;
$$;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

SELECT 'Electronic wallet balance function successfully fixed - ambiguous column reference resolved' as status;
