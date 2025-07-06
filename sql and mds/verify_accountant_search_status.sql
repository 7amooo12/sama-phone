-- ============================================================================
-- VERIFY ACCOUNTANT SEARCH STATUS
-- ============================================================================
-- التحقق من حالة البحث للمحاسب في نظام المخازن والمخزون
-- ============================================================================

-- 1. Test basic table access for search operations
SELECT 'BASIC TABLE ACCESS TEST' as test_category;

SELECT 'Products Access' as test_name, COUNT(*) as accessible_records FROM products;
SELECT 'Warehouses Access' as test_name, COUNT(*) as accessible_records FROM warehouses;
SELECT 'Warehouse Inventory Access' as test_name, COUNT(*) as accessible_records FROM warehouse_inventory;
SELECT 'Categories Access' as test_name, COUNT(*) as accessible_records FROM categories;
SELECT 'User Profiles Access' as test_name, COUNT(*) as accessible_records FROM user_profiles;

-- 2. Test search-related joins (common in warehouse inventory searches)
SELECT 'SEARCH JOINS TEST' as test_category;

SELECT 
  'Product-Inventory Join' as test_name,
  COUNT(*) as accessible_records
FROM products p
JOIN warehouse_inventory wi ON p.id = wi.product_id
LIMIT 1;

SELECT 
  'Product-Warehouse-Inventory Join' as test_name,
  COUNT(*) as accessible_records
FROM products p
JOIN warehouse_inventory wi ON p.id = wi.product_id
JOIN warehouses w ON wi.warehouse_id = w.id
LIMIT 1;

-- 3. Test basic search queries (like what the app would perform)
SELECT 'BASIC SEARCH QUERIES TEST' as test_category;

-- Product name search
SELECT 
  'Product Name Search' as test_name,
  COUNT(*) as matching_records
FROM products 
WHERE name ILIKE '%test%' OR name ILIKE '%منتج%'
LIMIT 1;

-- Warehouse search
SELECT 
  'Warehouse Search' as test_name,
  COUNT(*) as matching_records
FROM warehouses 
WHERE name ILIKE '%test%' OR name ILIKE '%مخزن%'
LIMIT 1;

-- Category search
SELECT 
  'Category Search' as test_name,
  COUNT(*) as matching_records
FROM products 
WHERE category ILIKE '%test%' OR category ILIKE '%فئة%'
LIMIT 1;

-- 4. Check if our custom search functions exist and are accessible
SELECT 'CUSTOM SEARCH FUNCTIONS TEST' as test_category;

SELECT 
  'Available Search Functions' as info,
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%search%'
ORDER BY routine_name;

-- Test safe_product_search function if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_schema = 'public' 
    AND routine_name = 'safe_product_search'
  ) THEN
    PERFORM * FROM safe_product_search('test') LIMIT 1;
    RAISE NOTICE 'safe_product_search function is accessible and working';
  ELSE
    RAISE NOTICE 'safe_product_search function does not exist';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error testing safe_product_search: %', SQLERRM;
END $$;

-- Test safe_warehouse_search function if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_schema = 'public' 
    AND routine_name = 'safe_warehouse_search'
  ) THEN
    PERFORM * FROM safe_warehouse_search('test') LIMIT 1;
    RAISE NOTICE 'safe_warehouse_search function is accessible and working';
  ELSE
    RAISE NOTICE 'safe_warehouse_search function does not exist';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error testing safe_warehouse_search: %', SQLERRM;
END $$;

-- Test safe_inventory_search function if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_schema = 'public' 
    AND routine_name = 'safe_inventory_search'
  ) THEN
    PERFORM * FROM safe_inventory_search('test') LIMIT 1;
    RAISE NOTICE 'safe_inventory_search function is accessible and working';
  ELSE
    RAISE NOTICE 'safe_inventory_search function does not exist';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error testing safe_inventory_search: %', SQLERRM;
END $$;

-- 5. Check function permissions
SELECT 'FUNCTION PERMISSIONS TEST' as test_category;

SELECT 
  'Function Permissions' as info,
  routine_name,
  privilege_type,
  grantee
FROM information_schema.routine_privileges 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%search%'
  AND grantee IN ('authenticated', 'public')
ORDER BY routine_name, grantee;

-- 6. Test complex search scenarios (like the app would use)
SELECT 'COMPLEX SEARCH SCENARIOS TEST' as test_category;

-- Search products with inventory information
SELECT 
  'Product Search with Inventory' as test_name,
  COUNT(*) as results
FROM (
  SELECT 
    p.id,
    p.name,
    p.category,
    w.name as warehouse_name,
    wi.quantity
  FROM products p
  LEFT JOIN warehouse_inventory wi ON p.id = wi.product_id
  LEFT JOIN warehouses w ON wi.warehouse_id = w.id
  WHERE p.name ILIKE '%test%'
  LIMIT 10
) search_results;

-- Search by category with warehouse breakdown
SELECT 
  'Category Search with Warehouse Breakdown' as test_name,
  COUNT(*) as results
FROM (
  SELECT 
    p.category,
    w.name as warehouse_name,
    SUM(wi.quantity) as total_quantity
  FROM products p
  JOIN warehouse_inventory wi ON p.id = wi.product_id
  JOIN warehouses w ON wi.warehouse_id = w.id
  WHERE p.category ILIKE '%test%'
  GROUP BY p.category, w.name
  LIMIT 10
) category_search_results;

-- 7. Check for any remaining RLS restrictions
SELECT 'RLS POLICIES CHECK' as test_category;

SELECT 
  'Current RLS Policies' as info,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN qual LIKE '%true%' THEN 'OPEN ACCESS'
    WHEN qual LIKE '%authenticated%' THEN 'AUTHENTICATED ACCESS'
    WHEN qual LIKE '%accountant%' THEN 'INCLUDES ACCOUNTANT'
    ELSE 'RESTRICTED ACCESS'
  END as access_level
FROM pg_policies 
WHERE schemaname = 'public'
  AND tablename IN ('products', 'warehouses', 'warehouse_inventory', 'categories', 'user_profiles')
ORDER BY tablename, cmd;

-- 8. Final summary and recommendations
SELECT 'SEARCH STATUS SUMMARY' as summary_type;

SELECT 
  'Search Functionality Status' as status_check,
  CASE 
    WHEN EXISTS (SELECT 1 FROM products LIMIT 1) 
     AND EXISTS (SELECT 1 FROM warehouses LIMIT 1)
     AND EXISTS (SELECT 1 FROM warehouse_inventory LIMIT 1)
    THEN 'BASIC ACCESS: WORKING'
    ELSE 'BASIC ACCESS: FAILED'
  END as basic_access_status,
  
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_schema = 'public' 
      AND routine_name LIKE '%search%'
    )
    THEN 'SEARCH FUNCTIONS: AVAILABLE'
    ELSE 'SEARCH FUNCTIONS: MISSING'
  END as search_functions_status,
  
  'Check results above for detailed analysis' as next_steps;
