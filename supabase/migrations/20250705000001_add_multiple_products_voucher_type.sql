-- ============================================================================
-- ADD MULTIPLE PRODUCTS VOUCHER TYPE SUPPORT
-- Migration: 20250705000001_add_multiple_products_voucher_type.sql
-- Description: Update vouchers table constraint to support 'multiple_products' type
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Drop existing type constraint
-- ============================================================================

-- Drop the existing constraint that only allows 'category' and 'product'
ALTER TABLE public.vouchers DROP CONSTRAINT IF EXISTS vouchers_type_check;

-- ============================================================================
-- STEP 2: Add updated constraint with multiple_products support
-- ============================================================================

-- Add new constraint that includes 'multiple_products' as a valid type
ALTER TABLE public.vouchers ADD CONSTRAINT vouchers_type_check 
CHECK (type IN ('category', 'product', 'multiple_products'));

-- ============================================================================
-- STEP 3: Update any existing functions that might reference voucher types
-- ============================================================================

-- Update the voucher assignment function to handle multiple_products type
-- (This ensures compatibility with existing database functions)
CREATE OR REPLACE FUNCTION public.get_applicable_vouchers_for_cart(
    p_client_id UUID,
    p_cart_items JSONB
) RETURNS TABLE (
    voucher_id UUID,
    voucher_code TEXT,
    voucher_name TEXT,
    voucher_type TEXT,
    target_id TEXT,
    target_name TEXT,
    discount_percentage INTEGER,
    discount_type TEXT,
    discount_amount DECIMAL(10,2),
    expiration_date TIMESTAMP WITH TIME ZONE,
    metadata JSONB
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.id,
        v.code,
        v.name,
        v.type,
        v.target_id,
        v.target_name,
        v.discount_percentage,
        v.discount_type,
        v.discount_amount,
        v.expiration_date,
        v.metadata
    FROM public.vouchers v
    INNER JOIN public.client_vouchers cv ON v.id = cv.voucher_id
    WHERE cv.client_id = p_client_id
      AND cv.status = 'active'
      AND v.is_active = true
      AND v.expiration_date > NOW()
      AND (
          -- Category voucher: check if any cart item matches the category
          (v.type = 'category' AND EXISTS (
              SELECT 1 FROM jsonb_array_elements(p_cart_items) AS item
              WHERE item->>'category' = v.target_id OR item->>'category' = v.target_name
          ))
          OR
          -- Product voucher: check if specific product is in cart
          (v.type = 'product' AND EXISTS (
              SELECT 1 FROM jsonb_array_elements(p_cart_items) AS item
              WHERE item->>'productId' = v.target_id
          ))
          OR
          -- Multiple products voucher: check if any selected product is in cart
          (v.type = 'multiple_products' AND EXISTS (
              SELECT 1 FROM jsonb_array_elements(p_cart_items) AS cart_item
              WHERE EXISTS (
                  SELECT 1 FROM jsonb_array_elements(v.metadata->'selectedProducts') AS selected_product
                  WHERE selected_product->>'id' = cart_item->>'productId'
              )
          ))
      );
END;
$$;

-- ============================================================================
-- STEP 4: Add indexes for better performance with multiple_products type
-- ============================================================================

-- Add index for voucher type queries (if not exists)
CREATE INDEX IF NOT EXISTS idx_vouchers_type_active ON public.vouchers(type, is_active) 
WHERE is_active = true;

-- Add index for metadata queries on multiple_products vouchers
CREATE INDEX IF NOT EXISTS idx_vouchers_metadata_selected_products ON public.vouchers 
USING GIN ((metadata->'selectedProducts'))
WHERE type = 'multiple_products';

-- ============================================================================
-- STEP 5: Log completion
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎉 VOUCHER TYPE CONSTRAINT UPDATE COMPLETED!';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Updated vouchers_type_check constraint to include multiple_products';
    RAISE NOTICE '✅ Updated get_applicable_vouchers_for_cart function for multiple_products support';
    RAISE NOTICE '✅ Added performance indexes for multiple_products vouchers';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Supported voucher types: category, product, multiple_products';
    RAISE NOTICE '';
END;
$$;

COMMIT;
