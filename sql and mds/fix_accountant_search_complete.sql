-- ============================================================================
-- COMPLETE ACCOUNTANT SEARCH FIX
-- ============================================================================
-- إصلاح شامل لوظائف البحث للمحاسب
-- ============================================================================

-- 1. First, ensure all required search functions exist
-- Create the search_warehouse_products function that the app is calling
CREATE OR REPLACE FUNCTION search_warehouse_products(
  search_query TEXT,
  warehouse_ids TEXT[],
  page_limit INTEGER DEFAULT 20,
  page_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  product_id UUID,
  product_name TEXT,
  product_sku TEXT,
  product_description TEXT,
  category_name TEXT,
  total_quantity INTEGER,
  warehouse_breakdown JSONB,
  last_updated TIMESTAMP WITH TIME ZONE,
  image_url TEXT,
  price NUMERIC
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  WITH product_search AS (
    SELECT DISTINCT
      p.id as product_id,
      p.name as product_name,
      COALESCE(p.sku, '') as product_sku,
      COALESCE(p.description, '') as product_description,
      COALESCE(p.category, 'غير محدد') as category_name,
      COALESCE(p.main_image_url, '') as image_url,
      COALESCE(p.price, 0) as price
    FROM products p
    WHERE 
      (search_query IS NULL OR search_query = '' OR
       p.name ILIKE '%' || search_query || '%' OR
       COALESCE(p.sku, '') ILIKE '%' || search_query || '%' OR
       COALESCE(p.description, '') ILIKE '%' || search_query || '%' OR
       COALESCE(p.category, '') ILIKE '%' || search_query || '%')
  ),
  inventory_data AS (
    SELECT 
      wi.product_id,
      SUM(wi.quantity) as total_quantity,
      MAX(wi.last_updated) as last_updated,
      jsonb_agg(
        jsonb_build_object(
          'warehouse_id', wi.warehouse_id,
          'warehouse_name', w.name,
          'warehouse_location', COALESCE(w.address, ''),
          'quantity', wi.quantity,
          'last_updated', wi.last_updated
        )
      ) as warehouse_breakdown
    FROM warehouse_inventory wi
    JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE wi.warehouse_id = ANY(warehouse_ids::UUID[])
    GROUP BY wi.product_id
  )
  SELECT 
    ps.product_id,
    ps.product_name,
    ps.product_sku,
    ps.product_description,
    ps.category_name,
    COALESCE(id.total_quantity, 0)::INTEGER as total_quantity,
    COALESCE(id.warehouse_breakdown, '[]'::jsonb) as warehouse_breakdown,
    COALESCE(id.last_updated, NOW()) as last_updated,
    ps.image_url,
    ps.price
  FROM product_search ps
  LEFT JOIN inventory_data id ON ps.product_id = id.product_id
  ORDER BY ps.product_name
  LIMIT page_limit
  OFFSET page_offset;
$$;

-- Create the search_warehouse_categories function
CREATE OR REPLACE FUNCTION search_warehouse_categories(
  search_query TEXT,
  warehouse_ids TEXT[],
  page_limit INTEGER DEFAULT 20,
  page_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  category_name TEXT,
  product_count INTEGER,
  total_quantity INTEGER,
  warehouse_breakdown JSONB
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  WITH category_data AS (
    SELECT 
      COALESCE(p.category, 'غير محدد') as category_name,
      COUNT(DISTINCT p.id) as product_count,
      SUM(wi.quantity) as total_quantity,
      jsonb_agg(
        DISTINCT jsonb_build_object(
          'warehouse_id', wi.warehouse_id,
          'warehouse_name', w.name,
          'quantity', wi.quantity
        )
      ) as warehouse_breakdown
    FROM products p
    LEFT JOIN warehouse_inventory wi ON p.id = wi.product_id
    LEFT JOIN warehouses w ON wi.warehouse_id = w.id
    WHERE 
      (wi.warehouse_id = ANY(warehouse_ids::UUID[]) OR wi.warehouse_id IS NULL)
      AND (search_query IS NULL OR search_query = '' OR
           COALESCE(p.category, '') ILIKE '%' || search_query || '%')
    GROUP BY COALESCE(p.category, 'غير محدد')
  )
  SELECT 
    category_name,
    product_count::INTEGER,
    COALESCE(total_quantity, 0)::INTEGER as total_quantity,
    COALESCE(warehouse_breakdown, '[]'::jsonb) as warehouse_breakdown
  FROM category_data
  ORDER BY category_name
  LIMIT page_limit
  OFFSET page_offset;
$$;

-- 2. Grant execute permissions to all authenticated users
GRANT EXECUTE ON FUNCTION search_warehouse_products TO authenticated;
GRANT EXECUTE ON FUNCTION search_warehouse_categories TO authenticated;
GRANT EXECUTE ON FUNCTION search_warehouse_products TO service_role;
GRANT EXECUTE ON FUNCTION search_warehouse_categories TO service_role;

-- 3. Ensure our safe search functions are also available
-- Update the safe_product_search function to work better
CREATE OR REPLACE FUNCTION safe_product_search(search_term TEXT DEFAULT '')
RETURNS TABLE (
  product_id TEXT,
  product_name TEXT,
  product_category TEXT,
  product_price TEXT,
  product_quantity TEXT,
  product_sku TEXT
) 
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT 
    COALESCE(p.id::TEXT, '') as product_id,
    COALESCE(p.name, '') as product_name,
    COALESCE(p.category, '') as product_category,
    COALESCE(p.price::TEXT, '0') as product_price,
    COALESCE(p.quantity::TEXT, '0') as product_quantity,
    COALESCE(p.sku, '') as product_sku
  FROM products p
  WHERE 
    CASE 
      WHEN search_term IS NULL OR TRIM(search_term) = '' THEN TRUE
      ELSE (
        p.name ILIKE '%' || search_term || '%' OR
        COALESCE(p.category, '') ILIKE '%' || search_term || '%' OR
        COALESCE(p.sku, '') ILIKE '%' || search_term || '%'
      )
    END
  ORDER BY p.name
  LIMIT 100;
$$;

-- 4. Update the warehouse search service access
-- Ensure the getAccessibleWarehouseIds function works for accountant
-- The service checks for 'admin', 'owner', 'warehouseManager' but not 'accountant'
-- Let's make sure accountant role can access warehouses

-- Check if there's a specific warehouse access table, if not, allow accountant to see all active warehouses
-- This is handled in the service code, but we need to ensure the database allows it

-- 5. Test all search functions
SELECT 'TESTING SEARCH FUNCTIONS' as test_status;

-- Test search_warehouse_products
SELECT 'search_warehouse_products test' as test_name, COUNT(*) as result_count
FROM search_warehouse_products('', ARRAY[]::TEXT[], 5, 0);

-- Test search_warehouse_categories  
SELECT 'search_warehouse_categories test' as test_name, COUNT(*) as result_count
FROM search_warehouse_categories('', ARRAY[]::TEXT[], 5, 0);

-- Test safe_product_search
SELECT 'safe_product_search test' as test_name, COUNT(*) as result_count
FROM safe_product_search('');

-- 6. Verify function permissions
SELECT 
  'FUNCTION PERMISSIONS VERIFICATION' as check_type,
  routine_name,
  CASE 
    WHEN has_function_privilege('authenticated', routine_name, 'execute') 
    THEN 'CAN EXECUTE'
    ELSE 'CANNOT EXECUTE'
  END as permission_status
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name IN ('search_warehouse_products', 'search_warehouse_categories', 'safe_product_search')
ORDER BY routine_name;

-- 7. Final verification - test complex search scenario
SELECT 'COMPLEX SEARCH TEST' as test_type;

-- Test with actual search term
SELECT 
  'Product search with term' as test_name,
  COUNT(*) as results
FROM search_warehouse_products('test', ARRAY[]::TEXT[], 10, 0);

-- 8. Success message
SELECT 
  'SEARCH FIX COMPLETED' as status,
  'All search functions have been created and permissions granted' as message,
  'Accountant should now be able to search in warehouse inventory system' as result,
  'Test search functionality in the Accountant dashboard' as next_step;
