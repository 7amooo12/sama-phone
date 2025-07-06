-- Treasury Management System Migration
-- Creates tables and functions for advanced treasury management with visual connections

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create treasury_vaults table
CREATE TABLE IF NOT EXISTS treasury_vaults (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'EGP',
    balance DECIMAL(15,2) DEFAULT 0 CHECK (balance >= 0),
    exchange_rate_to_egp DECIMAL(10,4) DEFAULT 1 CHECK (exchange_rate_to_egp > 0),
    is_main_treasury BOOLEAN DEFAULT FALSE,
    position_x DECIMAL(8,2) DEFAULT 0,
    position_y DECIMAL(8,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT valid_currency CHECK (currency IN ('EGP', 'USD', 'SAR', 'CNY', 'EUR'))
    -- Note: unique_main_treasury constraint removed - using partial unique index instead
);

-- Create treasury_connections table
CREATE TABLE IF NOT EXISTS treasury_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_treasury_id UUID NOT NULL REFERENCES treasury_vaults(id) ON DELETE CASCADE,
    target_treasury_id UUID NOT NULL REFERENCES treasury_vaults(id) ON DELETE CASCADE,
    connection_amount DECIMAL(15,2) NOT NULL CHECK (connection_amount > 0),
    exchange_rate_used DECIMAL(10,4) NOT NULL CHECK (exchange_rate_used > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT no_self_connection CHECK (source_treasury_id != target_treasury_id),
    CONSTRAINT unique_connection UNIQUE (source_treasury_id, target_treasury_id)
);

-- Create treasury_transactions table for audit trail
CREATE TABLE IF NOT EXISTS treasury_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    treasury_id UUID NOT NULL REFERENCES treasury_vaults(id) ON DELETE CASCADE,
    transaction_type VARCHAR(20) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    balance_before DECIMAL(15,2) NOT NULL,
    balance_after DECIMAL(15,2) NOT NULL,
    description TEXT,
    reference_id UUID, -- Can reference connection_id or other transaction
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT valid_transaction_type CHECK (transaction_type IN ('credit', 'debit', 'connection', 'disconnection', 'exchange_rate_update'))
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_treasury_vaults_currency ON treasury_vaults(currency);
CREATE INDEX IF NOT EXISTS idx_treasury_vaults_main ON treasury_vaults(is_main_treasury) WHERE is_main_treasury = true;

-- Create partial unique index to ensure only one main treasury exists
-- This allows unlimited sub-treasuries (is_main_treasury = false) while ensuring only one main treasury
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_main_treasury
ON treasury_vaults (is_main_treasury)
WHERE is_main_treasury = true;
CREATE INDEX IF NOT EXISTS idx_treasury_connections_source ON treasury_connections(source_treasury_id);
CREATE INDEX IF NOT EXISTS idx_treasury_connections_target ON treasury_connections(target_treasury_id);
CREATE INDEX IF NOT EXISTS idx_treasury_transactions_treasury ON treasury_transactions(treasury_id);
CREATE INDEX IF NOT EXISTS idx_treasury_transactions_type ON treasury_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_treasury_transactions_created ON treasury_transactions(created_at DESC);

-- Create function to update treasury balance with transaction logging
CREATE OR REPLACE FUNCTION update_treasury_balance(
    treasury_uuid UUID,
    new_balance DECIMAL(15,2),
    transaction_type_param VARCHAR(20),
    description_param TEXT DEFAULT NULL,
    reference_uuid UUID DEFAULT NULL,
    user_uuid UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    old_balance DECIMAL(15,2);
    transaction_id UUID;
    amount_diff DECIMAL(15,2);
BEGIN
    -- Get current balance
    SELECT balance INTO old_balance 
    FROM treasury_vaults 
    WHERE id = treasury_uuid;
    
    IF old_balance IS NULL THEN
        RAISE EXCEPTION 'Treasury vault not found: %', treasury_uuid;
    END IF;
    
    -- Calculate amount difference
    amount_diff := new_balance - old_balance;
    
    -- Update treasury balance
    UPDATE treasury_vaults 
    SET balance = new_balance, 
        updated_at = NOW()
    WHERE id = treasury_uuid;
    
    -- Log transaction
    INSERT INTO treasury_transactions (
        treasury_id, 
        transaction_type, 
        amount, 
        balance_before, 
        balance_after, 
        description, 
        reference_id, 
        created_by
    ) VALUES (
        treasury_uuid,
        transaction_type_param,
        ABS(amount_diff),
        old_balance,
        new_balance,
        description_param,
        reference_uuid,
        user_uuid
    ) RETURNING id INTO transaction_id;
    
    RETURN transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to establish treasury connection
CREATE OR REPLACE FUNCTION create_treasury_connection(
    source_uuid UUID,
    target_uuid UUID,
    connection_amount_param DECIMAL(15,2),
    user_uuid UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    source_balance DECIMAL(15,2);
    target_balance DECIMAL(15,2);
    source_rate DECIMAL(10,4);
    target_rate DECIMAL(10,4);
    equivalent_amount DECIMAL(15,2);
    connection_id UUID;
BEGIN
    -- Get source treasury info
    SELECT balance, exchange_rate_to_egp INTO source_balance, source_rate
    FROM treasury_vaults WHERE id = source_uuid;

    -- Get target treasury info
    SELECT balance, exchange_rate_to_egp INTO target_balance, target_rate
    FROM treasury_vaults WHERE id = target_uuid;

    IF source_balance IS NULL OR target_balance IS NULL THEN
        RAISE EXCEPTION 'One or both treasury vaults not found';
    END IF;

    -- Calculate equivalent amount in target currency
    equivalent_amount := connection_amount_param * source_rate / target_rate;

    -- Check if source has sufficient balance
    IF source_balance < connection_amount_param THEN
        RAISE EXCEPTION 'Insufficient balance in source treasury';
    END IF;

    -- Create connection record
    INSERT INTO treasury_connections (
        source_treasury_id,
        target_treasury_id,
        connection_amount,
        exchange_rate_used,
        created_by
    ) VALUES (
        source_uuid,
        target_uuid,
        connection_amount_param,
        source_rate / target_rate,
        user_uuid
    ) RETURNING id INTO connection_id;

    -- Update source treasury balance (deduct)
    PERFORM update_treasury_balance(
        source_uuid,
        source_balance - connection_amount_param,
        'connection',
        'Connection established to treasury',
        connection_id,
        user_uuid
    );

    -- Update target treasury balance (add)
    PERFORM update_treasury_balance(
        target_uuid,
        target_balance + equivalent_amount,
        'connection',
        'Connection received from treasury',
        connection_id,
        user_uuid
    );

    RETURN connection_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to remove treasury connection
CREATE OR REPLACE FUNCTION remove_treasury_connection(
    connection_uuid UUID,
    user_uuid UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    source_uuid UUID;
    target_uuid UUID;
    connection_amount_val DECIMAL(15,2);
    exchange_rate_val DECIMAL(10,4);
    source_balance DECIMAL(15,2);
    target_balance DECIMAL(15,2);
    equivalent_amount DECIMAL(15,2);
BEGIN
    -- Get connection details
    SELECT source_treasury_id, target_treasury_id, connection_amount, exchange_rate_used
    INTO source_uuid, target_uuid, connection_amount_val, exchange_rate_val
    FROM treasury_connections WHERE id = connection_uuid;

    IF source_uuid IS NULL THEN
        RAISE EXCEPTION 'Connection not found: %', connection_uuid;
    END IF;

    -- Get current balances
    SELECT balance INTO source_balance FROM treasury_vaults WHERE id = source_uuid;
    SELECT balance INTO target_balance FROM treasury_vaults WHERE id = target_uuid;

    -- Calculate equivalent amount to return
    equivalent_amount := connection_amount_val * exchange_rate_val;

    -- Check if target has sufficient balance to return
    IF target_balance < equivalent_amount THEN
        RAISE EXCEPTION 'Insufficient balance in target treasury to disconnect';
    END IF;

    -- Update target treasury balance (deduct)
    PERFORM update_treasury_balance(
        target_uuid,
        target_balance - equivalent_amount,
        'disconnection',
        'Connection removed to treasury',
        connection_uuid,
        user_uuid
    );

    -- Update source treasury balance (add back)
    PERFORM update_treasury_balance(
        source_uuid,
        source_balance + connection_amount_val,
        'disconnection',
        'Connection returned from treasury',
        connection_uuid,
        user_uuid
    );

    -- Remove connection record
    DELETE FROM treasury_connections WHERE id = connection_uuid;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get treasury statistics
CREATE OR REPLACE FUNCTION get_treasury_statistics()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_vaults', COUNT(*),
        'total_balance_egp', COALESCE(SUM(balance * exchange_rate_to_egp), 0),
        'main_treasury_balance', COALESCE((SELECT balance FROM treasury_vaults WHERE is_main_treasury = true), 0),
        'currencies_count', COUNT(DISTINCT currency),
        'connections_count', (SELECT COUNT(*) FROM treasury_connections),
        'last_updated', MAX(updated_at)
    ) INTO result
    FROM treasury_vaults;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to validate connection (prevent cycles)
CREATE OR REPLACE FUNCTION validate_treasury_connection(
    source_uuid UUID,
    target_uuid UUID
) RETURNS BOOLEAN AS $$
DECLARE
    cycle_exists BOOLEAN := FALSE;
BEGIN
    -- Check for direct reverse connection
    IF EXISTS (
        SELECT 1 FROM treasury_connections
        WHERE source_treasury_id = target_uuid
        AND target_treasury_id = source_uuid
    ) THEN
        RETURN FALSE;
    END IF;

    -- Check for existing connection
    IF EXISTS (
        SELECT 1 FROM treasury_connections
        WHERE source_treasury_id = source_uuid
        AND target_treasury_id = target_uuid
    ) THEN
        RETURN FALSE;
    END IF;

    -- Check connection limits (max 2 connections per treasury)
    IF (
        SELECT COUNT(*) FROM treasury_connections
        WHERE source_treasury_id = source_uuid OR target_treasury_id = source_uuid
    ) >= 2 THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable Row Level Security
ALTER TABLE treasury_vaults ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_transactions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for treasury_vaults (idempotent)
DROP POLICY IF EXISTS "Users can view treasury vaults" ON treasury_vaults;
CREATE POLICY "Users can view treasury vaults" ON treasury_vaults
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Accountants and owners can manage treasury vaults" ON treasury_vaults;
CREATE POLICY "Accountants and owners can manage treasury vaults" ON treasury_vaults
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.role IN ('accountant', 'owner', 'admin')
            AND user_profiles.status IN ('approved', 'active')
        )
    );

-- Create RLS policies for treasury_connections (idempotent)
DROP POLICY IF EXISTS "Users can view treasury connections" ON treasury_connections;
CREATE POLICY "Users can view treasury connections" ON treasury_connections
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Accountants and owners can manage treasury connections" ON treasury_connections;
CREATE POLICY "Accountants and owners can manage treasury connections" ON treasury_connections
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.role IN ('accountant', 'owner', 'admin')
            AND user_profiles.status IN ('approved', 'active')
        )
    );

-- Create RLS policies for treasury_transactions (idempotent)
DROP POLICY IF EXISTS "Users can view treasury transactions" ON treasury_transactions;
CREATE POLICY "Users can view treasury transactions" ON treasury_transactions
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "System can insert treasury transactions" ON treasury_transactions;
CREATE POLICY "System can insert treasury transactions" ON treasury_transactions
    FOR INSERT WITH CHECK (true);

-- Insert default main treasury if not exists
INSERT INTO treasury_vaults (name, currency, balance, is_main_treasury, created_by)
SELECT 'الخزنة الرئيسية', 'EGP', 0, true, auth.uid()
WHERE NOT EXISTS (SELECT 1 FROM treasury_vaults WHERE is_main_treasury = true);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_treasury_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER treasury_vaults_updated_at
    BEFORE UPDATE ON treasury_vaults
    FOR EACH ROW
    EXECUTE FUNCTION update_treasury_updated_at();
