-- Migration: Add Bank Account Support to Treasury Management
-- Date: 2024-12-25
-- Description: Extends treasury_vaults table to support bank account information

-- Add new columns to treasury_vaults table for bank account support
ALTER TABLE treasury_vaults 
ADD COLUMN IF NOT EXISTS treasury_type VARCHAR(10) DEFAULT 'cash' CHECK (treasury_type IN ('cash', 'bank')),
ADD COLUMN IF NOT EXISTS bank_name VARCHAR(100),
ADD COLUMN IF NOT EXISTS account_number VARCHAR(50),
ADD COLUMN IF NOT EXISTS account_holder_name VARCHAR(100);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_treasury_vaults_treasury_type ON treasury_vaults(treasury_type);
CREATE INDEX IF NOT EXISTS idx_treasury_vaults_bank_name ON treasury_vaults(bank_name) WHERE bank_name IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_treasury_vaults_account_number ON treasury_vaults(account_number) WHERE account_number IS NOT NULL;

-- Add comments for documentation
COMMENT ON COLUMN treasury_vaults.treasury_type IS 'Type of treasury: cash (currency-based) or bank (bank account-based)';
COMMENT ON COLUMN treasury_vaults.bank_name IS 'Name of the bank for bank-type treasuries';
COMMENT ON COLUMN treasury_vaults.account_number IS 'Bank account number for bank-type treasuries';
COMMENT ON COLUMN treasury_vaults.account_holder_name IS 'Optional account holder name for bank-type treasuries';

-- Update the treasury_exchange_rate_summary view to include bank information
DROP VIEW IF EXISTS public.treasury_exchange_rate_summary;

CREATE OR REPLACE VIEW public.treasury_exchange_rate_summary AS
SELECT 
    tv.id,
    tv.name,
    tv.currency,
    tv.exchange_rate_to_egp,
    tv.balance,
    tv.balance * tv.exchange_rate_to_egp as balance_in_egp,
    tv.is_main_treasury,
    tv.treasury_type,
    tv.bank_name,
    tv.account_number,
    tv.account_holder_name,
    tv.updated_at as last_rate_update,
    CASE 
        WHEN tv.treasury_type = 'bank' AND tv.bank_name IS NOT NULL THEN
            CASE 
                WHEN LOWER(tv.bank_name) LIKE '%cib%' OR LOWER(tv.bank_name) LIKE '%commercial international%' THEN '🏦'
                WHEN LOWER(tv.bank_name) LIKE '%مصر%' OR LOWER(tv.bank_name) LIKE '%egypt%' THEN '🇪🇬'
                WHEN LOWER(tv.bank_name) LIKE '%قاهرة%' OR LOWER(tv.bank_name) LIKE '%cairo%' THEN '🏛️'
                WHEN LOWER(tv.bank_name) LIKE '%أهلي%' OR LOWER(tv.bank_name) LIKE '%ahli%' THEN '🏪'
                WHEN LOWER(tv.bank_name) LIKE '%مشرق%' OR LOWER(tv.bank_name) LIKE '%mashreq%' THEN '🌅'
                ELSE '🏦'
            END
        WHEN tv.currency = 'EGP' THEN '🇪🇬'
        WHEN tv.currency = 'USD' THEN '🇺🇸'
        WHEN tv.currency = 'SAR' THEN '🇸🇦'
        WHEN tv.currency = 'EUR' THEN '🇪🇺'
        ELSE '💰'
    END as display_icon,
    CASE 
        WHEN tv.currency = 'EGP' THEN 'ج.م'
        WHEN tv.currency = 'USD' THEN '$'
        WHEN tv.currency = 'SAR' THEN 'ر.س'
        WHEN tv.currency = 'EUR' THEN '€'
        ELSE tv.currency
    END as currency_symbol,
    -- Masked account number for display
    CASE 
        WHEN tv.treasury_type = 'bank' AND tv.account_number IS NOT NULL AND LENGTH(tv.account_number) > 4 THEN
            CONCAT(
                SUBSTRING(tv.account_number, 1, 2),
                REPEAT('*', LEAST(LENGTH(tv.account_number) - 6, 8)),
                SUBSTRING(tv.account_number, LENGTH(tv.account_number) - 3)
            )
        WHEN tv.treasury_type = 'bank' AND tv.account_number IS NOT NULL THEN tv.account_number
        ELSE NULL
    END as masked_account_number
FROM treasury_vaults tv
ORDER BY tv.is_main_treasury DESC, tv.treasury_type ASC, tv.name ASC;

-- Create a function to validate bank treasury data
CREATE OR REPLACE FUNCTION validate_bank_treasury_data()
RETURNS TRIGGER AS $$
BEGIN
    -- Validate bank treasury requirements
    IF NEW.treasury_type = 'bank' THEN
        -- Bank name is required for bank treasuries
        IF NEW.bank_name IS NULL OR TRIM(NEW.bank_name) = '' THEN
            RAISE EXCEPTION 'Bank name is required for bank-type treasuries';
        END IF;
        
        -- Account number is required for bank treasuries
        IF NEW.account_number IS NULL OR TRIM(NEW.account_number) = '' THEN
            RAISE EXCEPTION 'Account number is required for bank-type treasuries';
        END IF;
        
        -- Validate account number format (digits only, 8-20 characters)
        IF NOT (NEW.account_number ~ '^[0-9]{8,20}$') THEN
            RAISE EXCEPTION 'Account number must be 8-20 digits only';
        END IF;
        
        -- Bank treasuries should typically use EGP currency
        IF NEW.currency != 'EGP' THEN
            RAISE WARNING 'Bank treasuries typically use EGP currency';
        END IF;
    ELSE
        -- Clear bank-specific fields for cash treasuries
        NEW.bank_name := NULL;
        NEW.account_number := NULL;
        NEW.account_holder_name := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for bank treasury validation
DROP TRIGGER IF EXISTS trigger_validate_bank_treasury ON treasury_vaults;
CREATE TRIGGER trigger_validate_bank_treasury
    BEFORE INSERT OR UPDATE ON treasury_vaults
    FOR EACH ROW
    EXECUTE FUNCTION validate_bank_treasury_data();

-- Update existing cash treasuries to have the correct treasury_type
UPDATE treasury_vaults 
SET treasury_type = 'cash' 
WHERE treasury_type IS NULL OR treasury_type = '';

-- Create a function to get treasury display information
CREATE OR REPLACE FUNCTION get_treasury_display_info(treasury_id UUID)
RETURNS TABLE (
    id UUID,
    name VARCHAR,
    display_name VARCHAR,
    treasury_type VARCHAR,
    currency VARCHAR,
    balance DECIMAL,
    display_icon TEXT,
    bank_name VARCHAR,
    masked_account_number TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tv.id,
        tv.name,
        CASE 
            WHEN tv.treasury_type = 'bank' AND tv.bank_name IS NOT NULL THEN
                CONCAT(tv.name, ' - ', tv.bank_name)
            ELSE tv.name
        END as display_name,
        tv.treasury_type,
        tv.currency,
        tv.balance,
        CASE 
            WHEN tv.treasury_type = 'bank' AND tv.bank_name IS NOT NULL THEN
                CASE 
                    WHEN LOWER(tv.bank_name) LIKE '%cib%' OR LOWER(tv.bank_name) LIKE '%commercial international%' THEN '🏦'
                    WHEN LOWER(tv.bank_name) LIKE '%مصر%' OR LOWER(tv.bank_name) LIKE '%egypt%' THEN '🇪🇬'
                    WHEN LOWER(tv.bank_name) LIKE '%قاهرة%' OR LOWER(tv.bank_name) LIKE '%cairo%' THEN '🏛️'
                    WHEN LOWER(tv.bank_name) LIKE '%أهلي%' OR LOWER(tv.bank_name) LIKE '%ahli%' THEN '🏪'
                    WHEN LOWER(tv.bank_name) LIKE '%مشرق%' OR LOWER(tv.bank_name) LIKE '%mashreq%' THEN '🌅'
                    ELSE '🏦'
                END
            WHEN tv.currency = 'EGP' THEN '🇪🇬'
            WHEN tv.currency = 'USD' THEN '🇺🇸'
            WHEN tv.currency = 'SAR' THEN '🇸🇦'
            WHEN tv.currency = 'EUR' THEN '🇪🇺'
            ELSE '💰'
        END as display_icon,
        tv.bank_name,
        CASE 
            WHEN tv.treasury_type = 'bank' AND tv.account_number IS NOT NULL AND LENGTH(tv.account_number) > 4 THEN
                CONCAT(
                    SUBSTRING(tv.account_number, 1, 2),
                    REPEAT('*', LEAST(LENGTH(tv.account_number) - 6, 8)),
                    SUBSTRING(tv.account_number, LENGTH(tv.account_number) - 3)
                )
            WHEN tv.treasury_type = 'bank' AND tv.account_number IS NOT NULL THEN tv.account_number
            ELSE NULL
        END as masked_account_number
    FROM treasury_vaults tv
    WHERE tv.id = treasury_id;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT SELECT ON treasury_exchange_rate_summary TO authenticated;
GRANT EXECUTE ON FUNCTION get_treasury_display_info(UUID) TO authenticated;

-- Add helpful comments
COMMENT ON VIEW treasury_exchange_rate_summary IS 'Enhanced view providing treasury information including bank account details and display formatting';
COMMENT ON FUNCTION get_treasury_display_info(UUID) IS 'Function to get formatted display information for a specific treasury including bank details';
COMMENT ON FUNCTION validate_bank_treasury_data() IS 'Validation function to ensure bank treasury data integrity';
