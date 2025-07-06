-- ============================================================================
-- EMERGENCY RESTORE ACCOUNTANT ACCESS
-- ============================================================================
-- هذا السكريبت يستعيد الوصول للبيانات للمحاسب فوراً
-- This script immediately restores data access for accountant users
-- ============================================================================

-- ==================== STEP 1: DISABLE PROBLEMATIC RLS POLICIES ====================

-- إيقاف RLS مؤقتاً على الجداول الأساسية لاستعادة الوصول
-- Temporarily disable RLS on core tables to restore access

ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;

-- ==================== STEP 2: REMOVE ALL PROBLEMATIC POLICIES ====================

-- حذف جميع الـ policies التي تم إنشاؤها حديثاً
-- Remove all recently created policies that are causing issues

-- Products table policies
DROP POLICY IF EXISTS "products_accountant_select" ON public.products;
DROP POLICY IF EXISTS "products_comprehensive_access" ON public.products;
DROP POLICY IF EXISTS "products_simple_read_access" ON public.products;
DROP POLICY IF EXISTS "Products are viewable by authenticated users" ON public.products;
DROP POLICY IF EXISTS "Products viewable by everyone" ON public.products;
DROP POLICY IF EXISTS "Everyone can view products" ON public.products;

-- Warehouse inventory policies
DROP POLICY IF EXISTS "warehouse_inventory_accountant_select" ON public.warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_simple_read" ON public.warehouse_inventory;

-- Warehouses policies
DROP POLICY IF EXISTS "warehouses_accountant_select" ON public.warehouses;
DROP POLICY IF EXISTS "warehouses_simple_read" ON public.warehouses;

-- User profiles policies
DROP POLICY IF EXISTS "user_profiles_accountant_select" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_simple_read" ON public.user_profiles;

-- Other table policies
DROP POLICY IF EXISTS "categories_accountant_select" ON public.categories;
DROP POLICY IF EXISTS "invoices_accountant_select" ON public.invoices;

-- ==================== STEP 3: CREATE SIMPLE, WORKING POLICIES ====================

-- إعادة تفعيل RLS مع policies بسيطة وآمنة
-- Re-enable RLS with simple, safe policies

-- Products table - السماح لجميع المستخدمين المصرح لهم بقراءة المنتجات
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "products_simple_read_access" ON public.products
  FOR SELECT
  USING (
    auth.role() = 'service_role' OR
    auth.role() = 'authenticated'
  );

-- Warehouse inventory - السماح للأدوار المناسبة بقراءة المخزون
ALTER TABLE public.warehouse_inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "warehouse_inventory_simple_read" ON public.warehouse_inventory
  FOR SELECT
  USING (
    auth.role() = 'service_role' OR
    (
      auth.role() = 'authenticated' AND
      auth.uid() IS NOT NULL
    )
  );

-- Warehouses - السماح بقراءة المخازن
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "warehouses_simple_read" ON public.warehouses
  FOR SELECT
  USING (
    auth.role() = 'service_role' OR
    (
      auth.role() = 'authenticated' AND
      auth.uid() IS NOT NULL
    )
  );

-- User profiles - السماح بقراءة الملفات الشخصية
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_profiles_simple_read" ON public.user_profiles
  FOR SELECT
  USING (
    auth.role() = 'service_role' OR
    (
      auth.role() = 'authenticated' AND
      auth.uid() IS NOT NULL
    )
  );

-- حذف الـ policies الموجودة أولاً ثم إعادة إنشائها
DROP POLICY IF EXISTS "user_profiles_update_own" ON public.user_profiles;
DROP POLICY IF EXISTS "user_profiles_insert_own" ON public.user_profiles;
DROP POLICY IF EXISTS "user_can_update_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "user_can_insert_own_profile" ON public.user_profiles;

CREATE POLICY "user_profiles_update_own" ON public.user_profiles
  FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY "user_profiles_insert_own" ON public.user_profiles
  FOR INSERT
  WITH CHECK (id = auth.uid());

-- ==================== STEP 4: ENSURE FUNCTION ACCESS ====================

-- التأكد من أن دوال البحث متاحة
-- Ensure search functions are accessible

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- ==================== STEP 5: GRANT TABLE PERMISSIONS ====================

-- منح الصلاحيات الأساسية للجداول
-- Grant basic table permissions

GRANT SELECT ON public.products TO authenticated;
GRANT SELECT ON public.warehouse_inventory TO authenticated;
GRANT SELECT ON public.warehouses TO authenticated;
GRANT SELECT ON public.user_profiles TO authenticated;

-- ==================== STEP 6: VERIFICATION ====================

-- التحقق من أن البيانات أصبحت متاحة
-- Verify that data is now accessible

SELECT 
  '✅ EMERGENCY RESTORE COMPLETED' as status,
  'Data access should now be restored for accountant users' as message;

-- اختبار سريع للوصول للبيانات
-- Quick test for data access
SELECT 
  '📊 DATA ACCESS TEST' as test_type,
  (SELECT COUNT(*) FROM products) as products_count,
  (SELECT COUNT(*) FROM warehouses) as warehouses_count,
  (SELECT COUNT(*) FROM warehouse_inventory) as inventory_count,
  (SELECT COUNT(*) FROM user_profiles) as profiles_count;

-- ==================== STEP 7: ADDITIONAL SAFETY MEASURES ====================

-- إضافة policies إضافية للأمان إذا لزم الأمر
-- Add additional safety policies if needed

-- For categories table if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'categories'
  ) THEN
    ALTER TABLE public.categories DISABLE ROW LEVEL SECURITY;
    ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
    
    CREATE POLICY "categories_simple_read" ON public.categories
      FOR SELECT
      USING (
        auth.role() = 'service_role' OR
        auth.role() = 'authenticated'
      );
      
    GRANT SELECT ON public.categories TO authenticated;
  END IF;
END $$;

-- For invoices table if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'invoices'
  ) THEN
    ALTER TABLE public.invoices DISABLE ROW LEVEL SECURITY;
    ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
    
    CREATE POLICY "invoices_simple_read" ON public.invoices
      FOR SELECT
      USING (
        auth.role() = 'service_role' OR
        auth.role() = 'authenticated'
      );
      
    GRANT SELECT ON public.invoices TO authenticated;
  END IF;
END $$;

-- ==================== COMPLETION MESSAGE ====================

SELECT 
  '🎉 EMERGENCY RESTORATION COMPLETE' as final_status,
  'Accountant dashboard should now display data correctly' as result,
  'All users should have proper read access to necessary tables' as confirmation,
  'Search functionality should work normally' as search_status;

-- ==================== INSTRUCTIONS ====================

SELECT 
  '📋 NEXT STEPS' as instructions,
  '1. Test the accountant dashboard to confirm data is visible' as step1,
  '2. Test search functionality in all screens' as step2,
  '3. If issues persist, the problem may be in the application code' as step3,
  '4. Monitor for any security concerns with the simplified policies' as step4;
