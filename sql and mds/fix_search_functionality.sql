-- ============================================================================
-- FIX SEARCH FUNCTIONALITY FOR ACCOUNTANT
-- ============================================================================
-- هذا السكريبت يصلح وظائف البحث للمحاسب
-- This script fixes search functionality for accountant users
-- ============================================================================

-- ==================== STEP 1: CHECK SEARCH FUNCTIONS ====================

-- التحقق من وجود دوال البحث
SELECT 
  '🔍 CHECKING SEARCH FUNCTIONS' as check_type,
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name IN ('search_warehouse_products', 'search_warehouse_categories')
ORDER BY routine_name;

-- ==================== STEP 2: GRANT FUNCTION PERMISSIONS ====================

-- منح صلاحيات تنفيذ دوال البحث
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- صلاحيات محددة لدوال البحث إذا كانت موجودة
DO $$
BEGIN
  -- search_warehouse_products function
  IF EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_schema = 'public' 
    AND routine_name = 'search_warehouse_products'
  ) THEN
    GRANT EXECUTE ON FUNCTION search_warehouse_products TO authenticated;
    GRANT EXECUTE ON FUNCTION search_warehouse_products TO service_role;
    RAISE NOTICE '✅ Granted permissions for search_warehouse_products';
  ELSE
    RAISE NOTICE '⚠️ search_warehouse_products function not found';
  END IF;
  
  -- search_warehouse_categories function
  IF EXISTS (
    SELECT 1 FROM information_schema.routines 
    WHERE routine_schema = 'public' 
    AND routine_name = 'search_warehouse_categories'
  ) THEN
    GRANT EXECUTE ON FUNCTION search_warehouse_categories TO authenticated;
    GRANT EXECUTE ON FUNCTION search_warehouse_categories TO service_role;
    RAISE NOTICE '✅ Granted permissions for search_warehouse_categories';
  ELSE
    RAISE NOTICE '⚠️ search_warehouse_categories function not found';
  END IF;
END $$;

-- ==================== STEP 3: CREATE BASIC SEARCH FUNCTIONS IF MISSING ====================

-- إنشاء دالة بحث بسيطة للمنتجات إذا لم تكن موجودة
CREATE OR REPLACE FUNCTION simple_product_search(search_term TEXT)
RETURNS TABLE (
  id UUID,
  name TEXT,
  category TEXT,
  price NUMERIC,
  quantity INTEGER,
  sku TEXT
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT
    p.id::UUID,
    p.name::TEXT,
    COALESCE(p.category, '')::TEXT,
    COALESCE(p.price, 0)::NUMERIC,
    COALESCE(p.quantity, 0)::INTEGER,
    COALESCE(p.sku, '')::TEXT
  FROM products p
  WHERE
    (p.name ILIKE '%' || search_term || '%' OR
     COALESCE(p.category, '') ILIKE '%' || search_term || '%' OR
     COALESCE(p.sku, '') ILIKE '%' || search_term || '%')
    AND search_term IS NOT NULL
    AND LENGTH(TRIM(search_term)) > 0
  ORDER BY p.name
  LIMIT 50;
$$;

-- منح صلاحيات للدالة الجديدة
GRANT EXECUTE ON FUNCTION simple_product_search TO authenticated;
GRANT EXECUTE ON FUNCTION simple_product_search TO service_role;

-- ==================== STEP 4: CREATE WAREHOUSE INVENTORY SEARCH ====================

-- دالة بحث في مخزون المخازن
CREATE OR REPLACE FUNCTION simple_inventory_search(search_term TEXT)
RETURNS TABLE (
  product_id UUID,
  product_name TEXT,
  warehouse_id UUID,
  warehouse_name TEXT,
  quantity INTEGER,
  category TEXT
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT
    p.id::UUID as product_id,
    p.name::TEXT as product_name,
    w.id::UUID as warehouse_id,
    w.name::TEXT as warehouse_name,
    COALESCE(wi.quantity, 0)::INTEGER,
    COALESCE(p.category, '')::TEXT
  FROM warehouse_inventory wi
  JOIN products p ON wi.product_id = p.id
  JOIN warehouses w ON wi.warehouse_id = w.id
  WHERE
    (p.name ILIKE '%' || search_term || '%' OR
     COALESCE(p.category, '') ILIKE '%' || search_term || '%' OR
     w.name ILIKE '%' || search_term || '%')
    AND search_term IS NOT NULL
    AND LENGTH(TRIM(search_term)) > 0
  ORDER BY p.name, w.name
  LIMIT 50;
$$;

-- منح صلاحيات للدالة
GRANT EXECUTE ON FUNCTION simple_inventory_search TO authenticated;
GRANT EXECUTE ON FUNCTION simple_inventory_search TO service_role;

-- ==================== STEP 5: CREATE USER SEARCH FUNCTION ====================

-- دالة بحث في المستخدمين (للعملاء)
CREATE OR REPLACE FUNCTION simple_user_search(search_term TEXT)
RETURNS TABLE (
  id UUID,
  name TEXT,
  email TEXT,
  phone_number TEXT,
  role TEXT,
  status TEXT
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT
    up.id::UUID,
    up.name::TEXT,
    up.email::TEXT,
    COALESCE(up.phone_number, '')::TEXT,
    up.role::TEXT,
    up.status::TEXT
  FROM user_profiles up
  WHERE
    (up.name ILIKE '%' || search_term || '%' OR
     up.email ILIKE '%' || search_term || '%' OR
     COALESCE(up.phone_number, '') ILIKE '%' || search_term || '%')
    AND search_term IS NOT NULL
    AND LENGTH(TRIM(search_term)) > 0
  ORDER BY up.name
  LIMIT 50;
$$;

-- منح صلاحيات للدالة
GRANT EXECUTE ON FUNCTION simple_user_search TO authenticated;
GRANT EXECUTE ON FUNCTION simple_user_search TO service_role;

-- ==================== STEP 6: ENSURE TABLE INDEXES FOR SEARCH ====================

-- إنشاء فهارس للبحث السريع
CREATE INDEX IF NOT EXISTS idx_products_name_search ON products USING gin(to_tsvector('arabic', name));
CREATE INDEX IF NOT EXISTS idx_products_category_search ON products USING gin(to_tsvector('arabic', category));
CREATE INDEX IF NOT EXISTS idx_products_sku_search ON products (sku);
CREATE INDEX IF NOT EXISTS idx_warehouses_name_search ON warehouses USING gin(to_tsvector('arabic', name));
CREATE INDEX IF NOT EXISTS idx_user_profiles_name_search ON user_profiles USING gin(to_tsvector('arabic', name));
CREATE INDEX IF NOT EXISTS idx_user_profiles_email_search ON user_profiles (email);

-- ==================== STEP 7: TEST SEARCH FUNCTIONS ====================

-- اختبار دوال البحث
SELECT 
  '🧪 TESTING SEARCH FUNCTIONS' as test_type,
  'Testing simple_product_search' as function_name;

-- اختبار بحث المنتجات
SELECT COUNT(*) as product_search_results 
FROM simple_product_search('test');

-- اختبار بحث المخزون
SELECT COUNT(*) as inventory_search_results 
FROM simple_inventory_search('test');

-- اختبار بحث المستخدمين
SELECT COUNT(*) as user_search_results 
FROM simple_user_search('test');

-- ==================== STEP 8: VERIFY PERMISSIONS ====================

-- التحقق من صلاحيات دوال البحث
SELECT 
  '🔑 FUNCTION PERMISSIONS CHECK' as check_type,
  routine_name,
  CASE 
    WHEN has_function_privilege('authenticated', routine_name || '(text)', 'execute') 
    THEN '✅ AUTHENTICATED CAN EXECUTE'
    ELSE '❌ NO EXECUTE PERMISSION'
  END as permission_status
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%search%'
ORDER BY routine_name;

-- ==================== STEP 9: ADDITIONAL SEARCH SUPPORT ====================

-- دالة بحث شاملة تجمع النتائج من جميع الجداول
CREATE OR REPLACE FUNCTION comprehensive_search(search_term TEXT)
RETURNS TABLE (
  result_type TEXT,
  id UUID,
  name TEXT,
  description TEXT,
  additional_info JSONB
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  -- البحث في المنتجات
  SELECT
    'product'::TEXT as result_type,
    p.id::UUID,
    p.name::TEXT,
    COALESCE(p.category, '')::TEXT as description,
    jsonb_build_object(
      'price', COALESCE(p.price, 0),
      'quantity', COALESCE(p.quantity, 0),
      'sku', COALESCE(p.sku, '')
    ) as additional_info
  FROM products p
  WHERE
    (p.name ILIKE '%' || search_term || '%' OR
     COALESCE(p.category, '') ILIKE '%' || search_term || '%' OR
     COALESCE(p.sku, '') ILIKE '%' || search_term || '%')
    AND search_term IS NOT NULL
    AND LENGTH(TRIM(search_term)) > 0

  UNION ALL

  -- البحث في المخازن
  SELECT
    'warehouse'::TEXT as result_type,
    w.id::UUID,
    w.name::TEXT,
    COALESCE(w.location, '')::TEXT as description,
    jsonb_build_object(
      'location', COALESCE(w.location, ''),
      'status', COALESCE(w.status, '')
    ) as additional_info
  FROM warehouses w
  WHERE
    (w.name ILIKE '%' || search_term || '%' OR
     COALESCE(w.location, '') ILIKE '%' || search_term || '%')
    AND search_term IS NOT NULL
    AND LENGTH(TRIM(search_term)) > 0

  UNION ALL

  -- البحث في المستخدمين
  SELECT
    'user'::TEXT as result_type,
    up.id::UUID,
    up.name::TEXT,
    up.role::TEXT as description,
    jsonb_build_object(
      'email', up.email,
      'role', up.role,
      'status', up.status
    ) as additional_info
  FROM user_profiles up
  WHERE
    (up.name ILIKE '%' || search_term || '%' OR
     up.email ILIKE '%' || search_term || '%')
    AND search_term IS NOT NULL
    AND LENGTH(TRIM(search_term)) > 0

  ORDER BY result_type, name
  LIMIT 100;
$$;

-- منح صلاحيات للدالة الشاملة
GRANT EXECUTE ON FUNCTION comprehensive_search TO authenticated;
GRANT EXECUTE ON FUNCTION comprehensive_search TO service_role;

-- ==================== COMPLETION ====================

SELECT 
  '✅ SEARCH FUNCTIONALITY RESTORED' as status,
  'Search functions have been created and permissions granted' as message,
  'Test search in the accountant dashboard now' as instruction;

-- عرض جميع دوال البحث المتاحة
SELECT 
  '📋 AVAILABLE SEARCH FUNCTIONS' as info,
  routine_name as function_name,
  'SELECT * FROM ' || routine_name || '(''search_term'');' as usage_example
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%search%'
ORDER BY routine_name;
