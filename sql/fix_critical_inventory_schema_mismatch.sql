-- 🚨 CRITICAL FIX: Inventory Schema Data Type Mismatch
-- Fix the critical issue where warehouse_inventory.product_id (INTEGER) 
-- doesn't match products.id (TEXT), causing global inventory search to return 0 results
-- 
-- Issue: Product ID "131" exists but JOIN fails due to type mismatch
-- Solution: Standardize both tables to use TEXT for product_id

-- =====================================================
-- STEP 1: ANALYZE CURRENT SCHEMA STATE
-- =====================================================

-- Check current data types
SELECT 
    'warehouse_inventory.product_id' as table_column,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'warehouse_inventory' 
    AND column_name = 'product_id'
    AND table_schema = 'public';

SELECT 
    'products.id' as table_column,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'products' 
    AND column_name = 'id'
    AND table_schema = 'public';

-- Check if we have any data that would be affected
SELECT 
    'Current warehouse_inventory records' as info,
    COUNT(*) as total_records,
    COUNT(DISTINCT product_id) as unique_products
FROM warehouse_inventory;

SELECT 
    'Current products records' as info,
    COUNT(*) as total_records
FROM products;

-- =====================================================
-- STEP 2: BACKUP EXISTING DATA
-- =====================================================

-- Create backup table for warehouse_inventory
CREATE TABLE IF NOT EXISTS warehouse_inventory_backup_20250629 AS 
SELECT * FROM warehouse_inventory;

-- Create backup table for products
CREATE TABLE IF NOT EXISTS products_backup_20250629 AS 
SELECT * FROM products;

-- =====================================================
-- STEP 3: FIX WAREHOUSE_INVENTORY TABLE
-- =====================================================

-- First, let's see what product_id values we have
SELECT 
    'Sample warehouse_inventory product_ids' as info,
    product_id,
    COUNT(*) as count
FROM warehouse_inventory 
GROUP BY product_id 
ORDER BY count DESC 
LIMIT 10;

-- Convert warehouse_inventory.product_id from INTEGER to TEXT
-- This is the safest approach since products.id is already TEXT

-- Step 3a: Add new column with TEXT type
ALTER TABLE warehouse_inventory 
ADD COLUMN IF NOT EXISTS product_id_text TEXT;

-- Step 3b: Copy data with conversion
UPDATE warehouse_inventory 
SET product_id_text = product_id::TEXT 
WHERE product_id_text IS NULL;

-- Step 3c: Drop the old INTEGER column
ALTER TABLE warehouse_inventory 
DROP COLUMN IF EXISTS product_id;

-- Step 3d: Rename the new column
ALTER TABLE warehouse_inventory 
RENAME COLUMN product_id_text TO product_id;

-- Step 3e: Add NOT NULL constraint
ALTER TABLE warehouse_inventory 
ALTER COLUMN product_id SET NOT NULL;

-- =====================================================
-- STEP 4: UPDATE INDEXES AND CONSTRAINTS
-- =====================================================

-- Create index on the new TEXT product_id column
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_product_id_text 
ON warehouse_inventory(product_id);

-- Create composite index for better query performance
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_product_warehouse 
ON warehouse_inventory(product_id, warehouse_id);

-- Create index for quantity searches
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_quantity_gt_zero 
ON warehouse_inventory(product_id, quantity) 
WHERE quantity > 0;

-- =====================================================
-- STEP 5: UPDATE DATABASE FUNCTIONS
-- =====================================================

-- Update the search_product_globally function to handle TEXT product_id
DROP FUNCTION IF EXISTS search_product_globally(TEXT, INTEGER, TEXT[]);

CREATE OR REPLACE FUNCTION search_product_globally(
    p_product_id TEXT,
    p_requested_quantity INTEGER DEFAULT 1,
    p_exclude_warehouses TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS TABLE (
    warehouse_id UUID,
    warehouse_name TEXT,
    warehouse_priority INTEGER,
    available_quantity INTEGER,
    minimum_stock INTEGER,
    maximum_stock INTEGER,
    can_allocate INTEGER,
    last_updated TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Log the search attempt
    RAISE NOTICE 'Searching for product_id: %, requested_quantity: %', p_product_id, p_requested_quantity;
    
    RETURN QUERY
    SELECT 
        wi.warehouse_id,
        w.name as warehouse_name,
        0 as warehouse_priority, -- Default priority since column may not exist
        wi.quantity as available_quantity,
        COALESCE(wi.minimum_stock, 0) as minimum_stock,
        COALESCE(wi.maximum_stock, 0) as maximum_stock,
        GREATEST(0, wi.quantity - COALESCE(wi.minimum_stock, 0)) as can_allocate,
        wi.last_updated
    FROM warehouse_inventory wi
    JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE wi.product_id = p_product_id
        AND w.is_active = true
        AND wi.quantity > 0
        AND NOT (wi.warehouse_id::TEXT = ANY(p_exclude_warehouses))
    ORDER BY 
        wi.quantity DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION search_product_globally(TEXT, INTEGER, TEXT[]) TO authenticated;

-- =====================================================
-- STEP 6: VERIFICATION QUERIES
-- =====================================================

-- Test the fix with the problematic product ID "131"
SELECT 'Testing product ID 131 search...' as test_status;

-- Direct query test
SELECT 
    'Direct warehouse_inventory query for product 131' as test_type,
    wi.id,
    wi.warehouse_id,
    wi.product_id,
    wi.quantity,
    w.name as warehouse_name,
    w.is_active
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '131'
    AND w.is_active = true
    AND wi.quantity > 0;

-- Test the function
SELECT 
    'Function test for product 131' as test_type,
    *
FROM search_product_globally('131', 4);

-- Test JOIN with products table
SELECT 
    'JOIN test with products table' as test_type,
    wi.product_id,
    wi.quantity,
    w.name as warehouse_name,
    p.name as product_name,
    p.id as product_table_id
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
LEFT JOIN products p ON wi.product_id = p.id
WHERE wi.product_id = '131'
    AND w.is_active = true
    AND wi.quantity > 0;

-- =====================================================
-- STEP 7: CLEANUP
-- =====================================================

-- Drop old indexes if they exist
DROP INDEX IF EXISTS idx_warehouse_inventory_product_id;

-- Update table comments
COMMENT ON COLUMN warehouse_inventory.product_id IS 'Product ID as TEXT to match products.id type';

-- Final verification
SELECT 
    'Schema fix verification' as status,
    'warehouse_inventory.product_id is now TEXT' as result,
    data_type
FROM information_schema.columns 
WHERE table_name = 'warehouse_inventory' 
    AND column_name = 'product_id'
    AND table_schema = 'public';

-- Success message
SELECT '✅ Critical inventory schema mismatch has been fixed!' as final_status;
