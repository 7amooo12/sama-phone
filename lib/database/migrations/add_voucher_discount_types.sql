-- Migration: Add discount type and amount fields to vouchers table
-- Date: 2025-06-18
-- Description: Extend vouchers table to support both percentage and fixed amount discounts

-- Add new columns to vouchers table
ALTER TABLE vouchers 
ADD COLUMN IF NOT EXISTS discount_type VARCHAR(20) DEFAULT 'percentage' CHECK (discount_type IN ('percentage', 'fixed_amount')),
ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10,2) DEFAULT NULL;

-- Update existing vouchers to have percentage discount type
UPDATE vouchers 
SET discount_type = 'percentage' 
WHERE discount_type IS NULL;

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_vouchers_discount_type ON vouchers(discount_type);

-- Add comments for documentation
COMMENT ON COLUMN vouchers.discount_type IS 'Type of discount: percentage or fixed_amount';
COMMENT ON COLUMN vouchers.discount_amount IS 'Fixed discount amount in currency (only used when discount_type is fixed_amount)';

-- Create a function to validate discount data consistency
CREATE OR REPLACE FUNCTION validate_voucher_discount()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure discount_amount is provided for fixed_amount type
    IF NEW.discount_type = 'fixed_amount' AND (NEW.discount_amount IS NULL OR NEW.discount_amount <= 0) THEN
        RAISE EXCEPTION 'discount_amount must be provided and greater than 0 for fixed_amount discount type';
    END IF;
    
    -- Ensure discount_percentage is valid for percentage type
    IF NEW.discount_type = 'percentage' AND (NEW.discount_percentage IS NULL OR NEW.discount_percentage <= 0 OR NEW.discount_percentage > 100) THEN
        RAISE EXCEPTION 'discount_percentage must be between 1 and 100 for percentage discount type';
    END IF;
    
    -- Clear discount_amount for percentage type
    IF NEW.discount_type = 'percentage' THEN
        NEW.discount_amount = NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to validate discount data
DROP TRIGGER IF EXISTS trigger_validate_voucher_discount ON vouchers;
CREATE TRIGGER trigger_validate_voucher_discount
    BEFORE INSERT OR UPDATE ON vouchers
    FOR EACH ROW
    EXECUTE FUNCTION validate_voucher_discount();

-- Update RLS policies if needed (assuming RLS is enabled)
-- This ensures the new columns are included in existing policies

-- Example: Update existing select policy to include new columns
-- ALTER POLICY "vouchers_select_policy" ON vouchers
-- USING (true); -- Adjust based on your actual RLS setup

-- Add helpful view for voucher discount information
CREATE OR REPLACE VIEW voucher_discount_info AS
SELECT 
    id,
    code,
    name,
    discount_type,
    discount_percentage,
    discount_amount,
    CASE 
        WHEN discount_type = 'percentage' THEN CONCAT(discount_percentage::text, '%')
        WHEN discount_type = 'fixed_amount' THEN CONCAT(discount_amount::text, ' جنيه')
        ELSE 'غير محدد'
    END as formatted_discount,
    is_active,
    expiration_date,
    created_at
FROM vouchers
ORDER BY created_at DESC;

-- Grant necessary permissions (adjust based on your user roles)
-- GRANT SELECT ON voucher_discount_info TO authenticated;
-- GRANT ALL ON vouchers TO service_role;
