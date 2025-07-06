-- ============================================================================
-- SIMPLE SEARCH FIX FOR ACCOUNTANT
-- ============================================================================
-- سكريبت مبسط لإصلاح البحث للمحاسب
-- Simple script to fix search for accountant users
-- ============================================================================

-- ==================== STEP 1: GRANT BASIC PERMISSIONS ====================

-- منح صلاحيات أساسية للبحث
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;

-- ==================== STEP 2: CHECK TABLE STRUCTURE ====================

-- التحقق من بنية جدول المنتجات
SELECT 
  '📋 PRODUCTS TABLE STRUCTURE' as info,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'products'
ORDER BY ordinal_position;

-- ==================== STEP 3: CREATE SAFE SEARCH FUNCTIONS ====================

-- دالة بحث آمنة للمنتجات
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

-- دالة بحث آمنة للمخازن
CREATE OR REPLACE FUNCTION safe_warehouse_search(search_term TEXT DEFAULT '')
RETURNS TABLE (
  warehouse_id TEXT,
  warehouse_name TEXT,
  warehouse_location TEXT,
  warehouse_status TEXT
) 
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT 
    COALESCE(w.id::TEXT, '') as warehouse_id,
    COALESCE(w.name, '') as warehouse_name,
    COALESCE(w.location, '') as warehouse_location,
    COALESCE(w.status, '') as warehouse_status
  FROM warehouses w
  WHERE 
    CASE 
      WHEN search_term IS NULL OR TRIM(search_term) = '' THEN TRUE
      ELSE (
        w.name ILIKE '%' || search_term || '%' OR
        COALESCE(w.location, '') ILIKE '%' || search_term || '%'
      )
    END
  ORDER BY w.name
  LIMIT 100;
$$;

-- دالة بحث آمنة للمستخدمين
CREATE OR REPLACE FUNCTION safe_user_search(search_term TEXT DEFAULT '')
RETURNS TABLE (
  user_id TEXT,
  user_name TEXT,
  user_email TEXT,
  user_phone TEXT,
  user_role TEXT,
  user_status TEXT
) 
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT 
    COALESCE(up.id::TEXT, '') as user_id,
    COALESCE(up.name, '') as user_name,
    COALESCE(up.email, '') as user_email,
    COALESCE(up.phone_number, '') as user_phone,
    COALESCE(up.role, '') as user_role,
    COALESCE(up.status, '') as user_status
  FROM user_profiles up
  WHERE 
    CASE 
      WHEN search_term IS NULL OR TRIM(search_term) = '' THEN TRUE
      ELSE (
        up.name ILIKE '%' || search_term || '%' OR
        up.email ILIKE '%' || search_term || '%' OR
        COALESCE(up.phone_number, '') ILIKE '%' || search_term || '%'
      )
    END
  ORDER BY up.name
  LIMIT 100;
$$;

-- دالة بحث آمنة للمخزون
CREATE OR REPLACE FUNCTION safe_inventory_search(search_term TEXT DEFAULT '')
RETURNS TABLE (
  product_id TEXT,
  product_name TEXT,
  warehouse_id TEXT,
  warehouse_name TEXT,
  quantity_available TEXT,
  product_category TEXT
) 
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT 
    COALESCE(p.id::TEXT, '') as product_id,
    COALESCE(p.name, '') as product_name,
    COALESCE(w.id::TEXT, '') as warehouse_id,
    COALESCE(w.name, '') as warehouse_name,
    COALESCE(wi.quantity::TEXT, '0') as quantity_available,
    COALESCE(p.category, '') as product_category
  FROM warehouse_inventory wi
  JOIN products p ON wi.product_id = p.id
  JOIN warehouses w ON wi.warehouse_id = w.id
  WHERE 
    CASE 
      WHEN search_term IS NULL OR TRIM(search_term) = '' THEN TRUE
      ELSE (
        p.name ILIKE '%' || search_term || '%' OR
        COALESCE(p.category, '') ILIKE '%' || search_term || '%' OR
        w.name ILIKE '%' || search_term || '%'
      )
    END
  ORDER BY p.name, w.name
  LIMIT 100;
$$;

-- ==================== STEP 4: GRANT PERMISSIONS ====================

-- منح صلاحيات للدوال الجديدة
GRANT EXECUTE ON FUNCTION safe_product_search TO authenticated;
GRANT EXECUTE ON FUNCTION safe_warehouse_search TO authenticated;
GRANT EXECUTE ON FUNCTION safe_user_search TO authenticated;
GRANT EXECUTE ON FUNCTION safe_inventory_search TO authenticated;

GRANT EXECUTE ON FUNCTION safe_product_search TO service_role;
GRANT EXECUTE ON FUNCTION safe_warehouse_search TO service_role;
GRANT EXECUTE ON FUNCTION safe_user_search TO service_role;
GRANT EXECUTE ON FUNCTION safe_inventory_search TO service_role;

-- ==================== STEP 5: TEST FUNCTIONS ====================

-- اختبار الدوال الجديدة
SELECT 
  '🧪 TESTING SAFE SEARCH FUNCTIONS' as test_type,
  'All functions should return results without errors' as description;

-- اختبار بحث المنتجات
SELECT 'Products Search Test' as test_name, COUNT(*) as result_count 
FROM safe_product_search('');

-- اختبار بحث المخازن
SELECT 'Warehouses Search Test' as test_name, COUNT(*) as result_count 
FROM safe_warehouse_search('');

-- اختبار بحث المستخدمين
SELECT 'Users Search Test' as test_name, COUNT(*) as result_count 
FROM safe_user_search('');

-- اختبار بحث المخزون
SELECT 'Inventory Search Test' as test_name, COUNT(*) as result_count 
FROM safe_inventory_search('');

-- ==================== STEP 6: VERIFY PERMISSIONS ====================

-- التحقق من صلاحيات الدوال
SELECT 
  '🔑 FUNCTION PERMISSIONS VERIFICATION' as check_type,
  routine_name,
  CASE 
    WHEN has_function_privilege('authenticated', routine_name || '(text)', 'execute') 
    THEN '✅ AUTHENTICATED CAN EXECUTE'
    ELSE '❌ NO EXECUTE PERMISSION'
  END as permission_status
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE 'safe_%_search'
ORDER BY routine_name;

-- ==================== STEP 7: USAGE EXAMPLES ====================

-- أمثلة على الاستخدام
SELECT 
  '📖 USAGE EXAMPLES' as info,
  'Use these functions in your Flutter app:' as instruction;

SELECT 
  'safe_product_search' as function_name,
  'SELECT * FROM safe_product_search(''منتج'');' as example_usage;

SELECT 
  'safe_warehouse_search' as function_name,
  'SELECT * FROM safe_warehouse_search(''مخزن'');' as example_usage;

SELECT 
  'safe_user_search' as function_name,
  'SELECT * FROM safe_user_search(''أحمد'');' as example_usage;

SELECT 
  'safe_inventory_search' as function_name,
  'SELECT * FROM safe_inventory_search(''منتج'');' as example_usage;

-- ==================== COMPLETION ====================

SELECT 
  '✅ SAFE SEARCH FUNCTIONS CREATED' as status,
  'Search functionality should now work without type errors' as message,
  'Test search in the accountant dashboard' as next_step;

-- عرض جميع الدوال المتاحة
SELECT 
  '📋 AVAILABLE SAFE SEARCH FUNCTIONS' as summary,
  routine_name as function_name,
  routine_type as type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE 'safe_%_search'
ORDER BY routine_name;
