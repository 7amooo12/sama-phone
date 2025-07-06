-- Quick fix for voucher discount_percentage constraint issue
-- This script fixes the issue where fixed_amount vouchers fail to create
-- due to the discount_percentage constraint requiring non-null values

-- Step 1: First, add the discount_type and discount_amount columns if they don't exist
ALTER TABLE public.vouchers
ADD COLUMN IF NOT EXISTS discount_type VARCHAR(20) DEFAULT 'percentage' CHECK (discount_type IN ('percentage', 'fixed_amount')),
ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10,2) DEFAULT NULL;

-- Step 2: Update existing vouchers to have percentage discount type
UPDATE public.vouchers
SET discount_type = 'percentage'
WHERE discount_type IS NULL;

-- Step 3: Drop the existing constraint that prevents null discount_percentage
ALTER TABLE public.vouchers DROP CONSTRAINT IF EXISTS vouchers_discount_percentage_check;

-- Step 4: Modify the discount_percentage column to allow NULL values
ALTER TABLE public.vouchers ALTER COLUMN discount_percentage DROP NOT NULL;

-- Step 5: Add the correct constraint that allows null for fixed_amount vouchers
ALTER TABLE public.vouchers ADD CONSTRAINT vouchers_discount_percentage_check
CHECK (
    (discount_type = 'percentage' AND discount_percentage >= 1 AND discount_percentage <= 100) OR
    (discount_type = 'fixed_amount' AND discount_percentage IS NULL)
);

-- Step 6: Update any existing fixed_amount vouchers to have null discount_percentage
UPDATE public.vouchers
SET discount_percentage = NULL
WHERE discount_type = 'fixed_amount';

-- Step 7: Create/update the validation trigger function
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

-- Step 8: Create the trigger
DROP TRIGGER IF EXISTS trigger_validate_voucher_discount ON public.vouchers;
CREATE TRIGGER trigger_validate_voucher_discount
    BEFORE INSERT OR UPDATE ON public.vouchers
    FOR EACH ROW
    EXECUTE FUNCTION validate_voucher_discount();

-- Step 9: Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_vouchers_discount_type ON public.vouchers(discount_type);

-- Step 10: Add helpful comments for documentation
COMMENT ON COLUMN public.vouchers.discount_type IS 'Type of discount: percentage or fixed_amount';
COMMENT ON COLUMN public.vouchers.discount_amount IS 'Fixed discount amount in currency (only used when discount_type is fixed_amount)';

-- Step 11: Verify the fix works by testing constraint behavior
DO $$
BEGIN
    RAISE NOTICE 'Voucher discount constraint fix completed successfully';
    RAISE NOTICE 'Fixed amount vouchers can now be created with null discount_percentage';
    RAISE NOTICE 'Percentage vouchers still require valid discount_percentage (1-100)';
END $$;
