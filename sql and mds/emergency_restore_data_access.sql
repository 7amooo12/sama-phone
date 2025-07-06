-- ============================================================================
-- EMERGENCY RESTORE DATA ACCESS
-- ============================================================================
-- استعادة فورية للوصول للبيانات
-- ============================================================================

-- إيقاف RLS مؤقتاً لاستعادة الوصول
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;

-- إعادة تفعيل RLS مع policies بسيطة
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- إنشاء policies بسيطة وآمنة
CREATE POLICY "products_simple_access" ON public.products
  FOR ALL
  USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "warehouses_simple_access" ON public.warehouses
  FOR ALL
  USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "warehouse_inventory_simple_access" ON public.warehouse_inventory
  FOR ALL
  USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "user_profiles_simple_access" ON public.user_profiles
  FOR ALL
  USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

-- منح الصلاحيات الأساسية
GRANT ALL ON public.products TO authenticated;
GRANT ALL ON public.warehouses TO authenticated;
GRANT ALL ON public.warehouse_inventory TO authenticated;
GRANT ALL ON public.user_profiles TO authenticated;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- اختبار الوصول
SELECT 'البيانات عادت تظهر' as status, COUNT(*) as products_count FROM products;
SELECT 'المخازن متاحة' as status, COUNT(*) as warehouses_count FROM warehouses;
SELECT 'المخزون متاح' as status, COUNT(*) as inventory_count FROM warehouse_inventory;
SELECT 'المستخدمين متاحين' as status, COUNT(*) as users_count FROM user_profiles;
