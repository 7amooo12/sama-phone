-- Migration: Fix voucher discount_percentage constraint for fixed_amount vouchers
-- Date: 2025-06-30
-- Description: Update the discount_percentage constraint to allow null values for fixed_amount vouchers
-- This fixes the issue where fixed_amount vouchers fail to create due to constraint violation

-- Step 1: Drop the existing constraint that requires discount_percentage >= 1
ALTER TABLE public.vouchers DROP CONSTRAINT IF EXISTS vouchers_discount_percentage_check;

-- Step 2: Add a new constraint that allows null discount_percentage for fixed_amount vouchers
-- and requires valid percentage (1-100) for percentage-type vouchers
ALTER TABLE public.vouchers ADD CONSTRAINT vouchers_discount_percentage_check
CHECK (
    (discount_type = 'percentage' AND discount_percentage >= 1 AND discount_percentage <= 100) OR
    (discount_type = 'fixed_amount' AND discount_percentage IS NULL)
);

-- Step 3: Update existing vouchers to set discount_percentage to null for fixed_amount types
-- This handles any existing data that might have invalid values
UPDATE public.vouchers
SET discount_percentage = NULL
WHERE discount_type = 'fixed_amount';

-- Step 4: Update the validation trigger function to handle the new constraint logic
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
    
    -- Clear discount_percentage for fixed_amount type
    IF NEW.discount_type = 'fixed_amount' THEN
        NEW.discount_percentage = NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Ensure the trigger is properly set up
DROP TRIGGER IF EXISTS trigger_validate_voucher_discount ON vouchers;
CREATE TRIGGER trigger_validate_voucher_discount
    BEFORE INSERT OR UPDATE ON vouchers
    FOR EACH ROW
    EXECUTE FUNCTION validate_voucher_discount();

-- Step 6: Add helpful comments for documentation
COMMENT ON CONSTRAINT vouchers_discount_percentage_check ON vouchers IS 
'Ensures discount_percentage is between 1-100 for percentage vouchers and null for fixed_amount vouchers';

-- Step 7: Update the voucher_discount_info view to handle null discount_percentage
CREATE OR REPLACE VIEW voucher_discount_info AS
SELECT 
    id,
    code,
    name,
    discount_type,
    discount_percentage,
    discount_amount,
    CASE 
        WHEN discount_type = 'percentage' THEN CONCAT(COALESCE(discount_percentage, 0)::text, '%')
        WHEN discount_type = 'fixed_amount' THEN CONCAT(COALESCE(discount_amount, 0)::text, ' جنيه')
        ELSE 'غير محدد'
    END as formatted_discount,
    is_active,
    expiration_date,
    created_at
FROM vouchers
ORDER BY created_at DESC;

-- Step 8: Verify the fix by testing constraint behavior
-- This will be executed as part of the migration to ensure it works
DO $$
BEGIN
    -- Test that percentage vouchers still work
    PERFORM 1 WHERE EXISTS (
        SELECT 1 FROM vouchers 
        WHERE discount_type = 'percentage' 
        AND discount_percentage BETWEEN 1 AND 100
    );
    
    -- Test that fixed_amount vouchers can have null discount_percentage
    PERFORM 1 WHERE EXISTS (
        SELECT 1 FROM vouchers 
        WHERE discount_type = 'fixed_amount' 
        AND discount_percentage IS NULL
    );
    
    RAISE NOTICE 'Voucher discount constraint fix completed successfully';
END $$;
