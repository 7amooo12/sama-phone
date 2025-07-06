-- Treasury Exchange Rate Management Functions
-- This migration adds functions for updating exchange rates in treasury management system

-- Function to update exchange rate for a single treasury
CREATE OR REPLACE FUNCTION public.update_treasury_exchange_rate(
    treasury_uuid UUID,
    new_rate DECIMAL(10,4),
    user_uuid UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    treasury_exists BOOLEAN;
BEGIN
    -- Check if treasury exists
    SELECT EXISTS(
        SELECT 1 FROM treasury_vaults 
        WHERE id = treasury_uuid
    ) INTO treasury_exists;
    
    IF NOT treasury_exists THEN
        RAISE EXCEPTION 'Treasury vault not found';
    END IF;
    
    -- Validate exchange rate
    IF new_rate <= 0 THEN
        RAISE EXCEPTION 'Exchange rate must be greater than 0';
    END IF;
    
    -- Update the exchange rate
    UPDATE treasury_vaults 
    SET 
        exchange_rate_to_egp = new_rate,
        updated_at = NOW()
    WHERE id = treasury_uuid;
    
    -- Log the update (optional - for audit trail)
    INSERT INTO treasury_transactions (
        treasury_id,
        transaction_type,
        amount,
        description,
        created_by,
        created_at
    ) VALUES (
        treasury_uuid,
        'EXCHANGE_RATE_UPDATE',
        new_rate,
        'Exchange rate updated to ' || new_rate::TEXT,
        user_uuid,
        NOW()
    );
    
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update exchange rates for multiple treasuries (bulk update)
CREATE OR REPLACE FUNCTION public.update_treasury_exchange_rates_bulk(
    rate_updates JSONB,
    user_uuid UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    treasury_id UUID;
    new_rate DECIMAL(10,4);
    update_record RECORD;
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
        
        -- Check if treasury exists
        IF NOT EXISTS(SELECT 1 FROM treasury_vaults WHERE id = treasury_id) THEN
            RAISE EXCEPTION 'Treasury vault % not found', treasury_id;
        END IF;
        
        -- Update the exchange rate
        UPDATE treasury_vaults 
        SET 
            exchange_rate_to_egp = new_rate,
            updated_at = NOW()
        WHERE id = treasury_id;
        
        -- Log the update (optional - for audit trail)
        INSERT INTO treasury_transactions (
            treasury_id,
            transaction_type,
            amount,
            description,
            created_by,
            created_at
        ) VALUES (
            treasury_id,
            'EXCHANGE_RATE_UPDATE',
            new_rate,
            'Exchange rate updated to ' || new_rate::TEXT || ' (bulk update)',
            user_uuid,
            NOW()
        );
    END LOOP;
    
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all treasury exchange rates with last update info
CREATE OR REPLACE FUNCTION public.get_treasury_exchange_rates()
RETURNS TABLE (
    treasury_id UUID,
    treasury_name VARCHAR(100),
    currency VARCHAR(3),
    exchange_rate_to_egp DECIMAL(10,4),
    last_updated TIMESTAMP WITH TIME ZONE,
    updated_by UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tv.id,
        tv.name,
        tv.currency,
        tv.exchange_rate_to_egp,
        tv.updated_at,
        tv.created_by
    FROM treasury_vaults tv
    ORDER BY tv.is_main_treasury DESC, tv.name ASC;
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.update_treasury_exchange_rate(UUID, DECIMAL, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_treasury_exchange_rates_bulk(JSONB, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_treasury_exchange_rates() TO authenticated;

-- Add RLS policies for the new functions (they use SECURITY DEFINER so they run with elevated privileges)
-- The functions themselves will check user permissions through existing RLS policies on the tables

-- Add indexes for better performance on exchange rate queries
CREATE INDEX IF NOT EXISTS idx_treasury_vaults_exchange_rate ON treasury_vaults(exchange_rate_to_egp);
CREATE INDEX IF NOT EXISTS idx_treasury_vaults_currency ON treasury_vaults(currency);
CREATE INDEX IF NOT EXISTS idx_treasury_vaults_updated_at ON treasury_vaults(updated_at);

-- Add a check constraint to ensure exchange rates are reasonable (between 0.0001 and 10000)
ALTER TABLE treasury_vaults 
DROP CONSTRAINT IF EXISTS check_exchange_rate_range;

ALTER TABLE treasury_vaults 
ADD CONSTRAINT check_exchange_rate_range 
CHECK (exchange_rate_to_egp >= 0.0001 AND exchange_rate_to_egp <= 10000);

-- Create a view for easy access to treasury exchange rate information
CREATE OR REPLACE VIEW public.treasury_exchange_rate_summary AS
SELECT 
    tv.id,
    tv.name,
    tv.currency,
    tv.exchange_rate_to_egp,
    tv.balance,
    tv.balance * tv.exchange_rate_to_egp as balance_in_egp,
    tv.is_main_treasury,
    tv.updated_at as last_rate_update,
    CASE 
        WHEN tv.currency = 'EGP' THEN '🇪🇬'
        WHEN tv.currency = 'USD' THEN '🇺🇸'
        WHEN tv.currency = 'SAR' THEN '🇸🇦'
        WHEN tv.currency = 'EUR' THEN '🇪🇺'
        ELSE '💰'
    END as currency_flag,
    CASE 
        WHEN tv.currency = 'EGP' THEN 'ج.م'
        WHEN tv.currency = 'USD' THEN '$'
        WHEN tv.currency = 'SAR' THEN 'ر.س'
        WHEN tv.currency = 'EUR' THEN '€'
        ELSE tv.currency
    END as currency_symbol
FROM treasury_vaults tv
ORDER BY tv.is_main_treasury DESC, tv.name ASC;

-- Grant access to the view
GRANT SELECT ON public.treasury_exchange_rate_summary TO authenticated;

-- Add connection point fields to treasury_connections table
ALTER TABLE treasury_connections
ADD COLUMN IF NOT EXISTS source_connection_point VARCHAR(10) DEFAULT 'center',
ADD COLUMN IF NOT EXISTS target_connection_point VARCHAR(10) DEFAULT 'center';

-- Add check constraints for connection points
ALTER TABLE treasury_connections
DROP CONSTRAINT IF EXISTS check_source_connection_point;

ALTER TABLE treasury_connections
ADD CONSTRAINT check_source_connection_point
CHECK (source_connection_point IN ('top', 'bottom', 'left', 'right', 'center'));

ALTER TABLE treasury_connections
DROP CONSTRAINT IF EXISTS check_target_connection_point;

ALTER TABLE treasury_connections
ADD CONSTRAINT check_target_connection_point
CHECK (target_connection_point IN ('top', 'bottom', 'left', 'right', 'center'));

-- Create indexes for connection point queries
CREATE INDEX IF NOT EXISTS idx_treasury_connections_source_point ON treasury_connections(source_connection_point);
CREATE INDEX IF NOT EXISTS idx_treasury_connections_target_point ON treasury_connections(target_connection_point);

-- Update the create_treasury_connection function to support connection points
CREATE OR REPLACE FUNCTION create_treasury_connection(
    source_uuid UUID,
    target_uuid UUID,
    connection_amount_param DECIMAL(15,2),
    user_uuid UUID DEFAULT NULL,
    source_point VARCHAR(10) DEFAULT 'center',
    target_point VARCHAR(10) DEFAULT 'center'
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

    -- Validate treasuries exist
    IF source_balance IS NULL OR target_balance IS NULL THEN
        RAISE EXCEPTION 'One or both treasury vaults not found';
    END IF;

    -- Validate sufficient balance
    IF source_balance < connection_amount_param THEN
        RAISE EXCEPTION 'Insufficient balance in source treasury';
    END IF;

    -- Calculate equivalent amount in target currency
    equivalent_amount := (connection_amount_param * source_rate) / target_rate;

    -- Create the connection record
    INSERT INTO treasury_connections (
        source_treasury_id,
        target_treasury_id,
        connection_amount,
        exchange_rate_used,
        source_connection_point,
        target_connection_point,
        created_by,
        created_at
    ) VALUES (
        source_uuid,
        target_uuid,
        connection_amount_param,
        source_rate / target_rate,
        source_point,
        target_point,
        user_uuid,
        NOW()
    ) RETURNING id INTO connection_id;

    -- Update source treasury balance using the proper function (deduct)
    PERFORM update_treasury_balance(
        source_uuid,
        source_balance - connection_amount_param,
        'connection',
        'Connection established to ' || (SELECT name FROM treasury_vaults WHERE id = target_uuid),
        connection_id,
        user_uuid
    );

    -- Update target treasury balance using the proper function (add)
    PERFORM update_treasury_balance(
        target_uuid,
        target_balance + equivalent_amount,
        'connection',
        'Connection received from ' || (SELECT name FROM treasury_vaults WHERE id = source_uuid),
        connection_id,
        user_uuid
    );

    RETURN connection_id;
END $$ LANGUAGE plpgsql SECURITY DEFINER;
