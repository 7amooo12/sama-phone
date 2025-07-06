-- Fix Treasury Transaction Constraints and Functions
-- This migration fixes the constraint violation issue in treasury_transactions table
-- and ensures all functions use proper transaction types and balance calculations

-- Step 1: Update the transaction type constraint to include all valid types
ALTER TABLE treasury_transactions 
DROP CONSTRAINT IF EXISTS valid_transaction_type;

ALTER TABLE treasury_transactions 
ADD CONSTRAINT valid_transaction_type 
CHECK (transaction_type IN (
    'credit', 
    'debit', 
    'connection', 
    'disconnection', 
    'exchange_rate_update',
    'transfer_in',
    'transfer_out',
    'balance_adjustment'
));

-- Step 2: Drop and recreate exchange rate functions to ensure proper transaction logging
DROP FUNCTION IF EXISTS public.update_treasury_exchange_rate(UUID, DECIMAL, UUID);

-- Fix the update_treasury_exchange_rate function to use proper transaction logging
CREATE OR REPLACE FUNCTION public.update_treasury_exchange_rate(
    treasury_uuid UUID,
    new_rate DECIMAL(10,4),
    user_uuid UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    old_rate DECIMAL(10,4);
    current_balance DECIMAL(15,2);
BEGIN
    -- Validate exchange rate
    IF new_rate <= 0 THEN
        RAISE EXCEPTION 'Exchange rate must be greater than 0';
    END IF;
    
    -- Get current rate and balance
    SELECT exchange_rate_to_egp, balance INTO old_rate, current_balance
    FROM treasury_vaults WHERE id = treasury_uuid;
    
    -- Check if treasury exists
    IF old_rate IS NULL THEN
        RAISE EXCEPTION 'Treasury vault not found: %', treasury_uuid;
    END IF;
    
    -- Update the exchange rate
    UPDATE treasury_vaults 
    SET 
        exchange_rate_to_egp = new_rate,
        updated_at = NOW()
    WHERE id = treasury_uuid;
    
    -- Log the update using proper transaction logging
    PERFORM update_treasury_balance(
        treasury_uuid,
        current_balance, -- Keep same balance, just log the rate change
        'exchange_rate_update',
        'Exchange rate updated from ' || old_rate::TEXT || ' to ' || new_rate::TEXT,
        NULL, -- No reference_id for rate updates
        user_uuid
    );
    
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Drop and recreate bulk exchange rate function
DROP FUNCTION IF EXISTS public.update_treasury_exchange_rates_bulk(JSONB, UUID);

-- Fix the bulk exchange rate update function
CREATE OR REPLACE FUNCTION public.update_treasury_exchange_rates_bulk(
    rate_updates JSONB,
    user_uuid UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    treasury_id UUID;
    new_rate DECIMAL(10,4);
    update_record RECORD;
    old_rate DECIMAL(10,4);
    current_balance DECIMAL(15,2);
BEGIN
    -- Iterate through the rate updates
    FOR update_record IN 
        SELECT key::UUID as treasury_id, value::DECIMAL(10,4) as new_rate
        FROM jsonb_each_text(rate_updates)
    LOOP
        treasury_id := update_record.treasury_id;
        new_rate := update_record.new_rate;
        
        -- Validate exchange rate
        IF new_rate <= 0 THEN
            RAISE EXCEPTION 'Exchange rate must be greater than 0 for treasury %', treasury_id;
        END IF;
        
        -- Get current rate and balance
        SELECT exchange_rate_to_egp, balance INTO old_rate, current_balance
        FROM treasury_vaults WHERE id = treasury_id;
        
        -- Check if treasury exists
        IF old_rate IS NULL THEN
            RAISE EXCEPTION 'Treasury vault % not found', treasury_id;
        END IF;
        
        -- Update the exchange rate
        UPDATE treasury_vaults 
        SET 
            exchange_rate_to_egp = new_rate,
            updated_at = NOW()
        WHERE id = treasury_id;
        
        -- Log the update using proper transaction logging
        PERFORM update_treasury_balance(
            treasury_id,
            current_balance, -- Keep same balance, just log the rate change
            'exchange_rate_update',
            'Exchange rate updated from ' || old_rate::TEXT || ' to ' || new_rate::TEXT || ' (bulk update)',
            NULL, -- No reference_id for rate updates
            user_uuid
        );
    END LOOP;
    
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Drop and recreate the remove_treasury_connection function to fix return type conflict
DROP FUNCTION IF EXISTS remove_treasury_connection(UUID, UUID);

-- Create a function to remove treasury connections properly
CREATE OR REPLACE FUNCTION remove_treasury_connection(
    connection_uuid UUID,
    user_uuid UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_source_treasury_id UUID;
    v_target_treasury_id UUID;
    v_connection_amount DECIMAL(15,2);
    v_exchange_rate_used DECIMAL(10,4);
    v_source_balance DECIMAL(15,2);
    v_target_balance DECIMAL(15,2);
    v_equivalent_amount DECIMAL(15,2);
BEGIN
    -- Get connection details
    SELECT
        tc.source_treasury_id,
        tc.target_treasury_id,
        tc.connection_amount,
        tc.exchange_rate_used
    INTO
        v_source_treasury_id,
        v_target_treasury_id,
        v_connection_amount,
        v_exchange_rate_used
    FROM treasury_connections tc
    WHERE tc.id = connection_uuid;

    IF v_source_treasury_id IS NULL THEN
        RAISE EXCEPTION 'Treasury connection not found: %', connection_uuid;
    END IF;
    
    -- Get current balances
    SELECT balance INTO v_source_balance FROM treasury_vaults WHERE id = v_source_treasury_id;
    SELECT balance INTO v_target_balance FROM treasury_vaults WHERE id = v_target_treasury_id;

    -- Calculate equivalent amount to reverse
    v_equivalent_amount := v_connection_amount * v_exchange_rate_used;

    -- Validate that target treasury has sufficient balance to reverse
    IF v_target_balance < v_equivalent_amount THEN
        RAISE EXCEPTION 'Insufficient balance in target treasury to reverse connection';
    END IF;
    
    -- Update source treasury balance (add back)
    PERFORM update_treasury_balance(
        v_source_treasury_id,
        v_source_balance + v_connection_amount,
        'disconnection',
        'Connection removed - amount returned from ' || (SELECT name FROM treasury_vaults WHERE id = v_target_treasury_id),
        connection_uuid,
        user_uuid
    );

    -- Update target treasury balance (deduct)
    PERFORM update_treasury_balance(
        v_target_treasury_id,
        v_target_balance - v_equivalent_amount,
        'disconnection',
        'Connection removed - amount returned to ' || (SELECT name FROM treasury_vaults WHERE id = v_source_treasury_id),
        connection_uuid,
        user_uuid
    );

    -- Delete the connection record
    DELETE FROM treasury_connections WHERE id = connection_uuid;
    
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Grant necessary permissions
GRANT EXECUTE ON FUNCTION update_treasury_exchange_rate(UUID, DECIMAL, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_treasury_exchange_rates_bulk(JSONB, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_treasury_connection(UUID, UUID) TO authenticated;

-- Step 6: Add helpful indexes for performance
CREATE INDEX IF NOT EXISTS idx_treasury_transactions_reference_id ON treasury_transactions(reference_id);
CREATE INDEX IF NOT EXISTS idx_treasury_transactions_created_by ON treasury_transactions(created_by);

-- Step 7: Add a comment explaining the transaction types
COMMENT ON CONSTRAINT valid_transaction_type ON treasury_transactions IS 
'Valid transaction types: credit (manual credit), debit (manual debit), connection (treasury connection created), disconnection (treasury connection removed), exchange_rate_update (rate change), transfer_in (incoming transfer), transfer_out (outgoing transfer), balance_adjustment (manual adjustment)';
