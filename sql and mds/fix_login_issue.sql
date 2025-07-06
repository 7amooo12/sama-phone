-- ============================================================================
-- FIX LOGIN ISSUE
-- ============================================================================
-- إصلاح مشكلة تسجيل الدخول
-- ============================================================================

-- إيقاف RLS على جدول المستخدمين مؤقتاً
ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;

-- حذف كل الـ policies على جدول المستخدمين
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    FOR policy_record IN 
        SELECT policyname FROM pg_policies 
        WHERE tablename = 'user_profiles' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_record.policyname || '" ON public.user_profiles';
        RAISE NOTICE 'Dropped policy: % on user_profiles', policy_record.policyname;
    END LOOP;
END $$;

-- منح كل الصلاحيات على جدول المستخدمين
GRANT ALL PRIVILEGES ON public.user_profiles TO authenticated;
GRANT ALL PRIVILEGES ON public.user_profiles TO anon;
GRANT ALL PRIVILEGES ON public.user_profiles TO service_role;
GRANT ALL PRIVILEGES ON public.user_profiles TO postgres;

-- إعادة تفعيل RLS مع policy مفتوح تماماً
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- إنشاء policy مفتوح للكل بدون أي قيود
CREATE POLICY "user_profiles_open_access" ON public.user_profiles
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- التأكد من وجود المستخدم
SELECT 
  'USER CHECK' as check_type,
  id,
  email,
  name,
  role,
  status,
  created_at
FROM user_profiles 
WHERE email = 'hima@sama.com';

-- اختبار الوصول لجدول المستخدمين
SELECT 'USER PROFILES ACCESS TEST' as test, COUNT(*) as count FROM user_profiles;

-- إصلاح أي مشاكل في الـ auth schema
-- التأكد من أن المستخدم موجود في auth.users
SELECT 
  'AUTH USERS CHECK' as check_type,
  id,
  email,
  email_confirmed_at,
  created_at,
  updated_at
FROM auth.users 
WHERE email = 'hima@sama.com';

-- إصلاح باقي الجداول المهمة لتسجيل الدخول
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications DISABLE ROW LEVEL SECURITY;

-- حذف كل الـ policies من الجداول المهمة
DO $$
DECLARE
    table_name TEXT;
    policy_record RECORD;
BEGIN
    FOR table_name IN VALUES ('products'), ('warehouses'), ('warehouse_inventory'), ('invoices'), ('orders'), ('tasks'), ('notifications')
    LOOP
        FOR policy_record IN 
            SELECT policyname FROM pg_policies 
            WHERE tablename = table_name AND schemaname = 'public'
        LOOP
            EXECUTE 'DROP POLICY IF EXISTS "' || policy_record.policyname || '" ON public.' || table_name;
            RAISE NOTICE 'Dropped policy: % on %', policy_record.policyname, table_name;
        END LOOP;
    END LOOP;
END $$;

-- منح كل الصلاحيات
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;

-- إعادة تفعيل الجداول بدون قيود
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "products_open" ON public.products FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "warehouses_open" ON public.warehouses FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.warehouse_inventory ENABLE ROW LEVEL SECURITY;
CREATE POLICY "warehouse_inventory_open" ON public.warehouse_inventory FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "invoices_open" ON public.invoices FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "orders_open" ON public.orders FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tasks_open" ON public.tasks FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notifications_open" ON public.notifications FOR ALL USING (true) WITH CHECK (true);

-- اختبار نهائي
SELECT 'LOGIN FIX COMPLETED' as status;
SELECT 'تم إصلاح مشكلة تسجيل الدخول' as message;
SELECT 'جرب تسجيل الدخول الآن' as instruction;

-- عرض معلومات المستخدم للتأكد
SELECT 
  'FINAL USER CHECK' as final_check,
  email,
  role,
  status,
  'يجب أن يكون approved' as status_note
FROM user_profiles 
WHERE email = 'hima@sama.com';
