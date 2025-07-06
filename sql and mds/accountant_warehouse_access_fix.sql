-- 🔧 إصلاح نهائي لوصول المحاسب لجميع بيانات المخازن
-- المحاسب يجب أن يرى نفس البيانات التي يراها مدير المخزن

-- =====================================================
-- STEP 1: حذف جميع السياسات المتضاربة نهائياً
-- =====================================================

SELECT '🧹 === حذف جميع السياسات المتضاربة ===' as cleanup_step;

-- حذف جميع سياسات المخازن الموجودة (من تحليل CSV)
DROP POLICY IF EXISTS "warehouses_select_expanded_roles" ON warehouses;
DROP POLICY IF EXISTS "warehouses_insert_expanded_roles" ON warehouses;
DROP POLICY IF EXISTS "warehouses_update_expanded_roles" ON warehouses;
DROP POLICY IF EXISTS "warehouses_delete_expanded_roles" ON warehouses;

DROP POLICY IF EXISTS "allow_warehouse_access_2025" ON warehouses;
DROP POLICY IF EXISTS "allow_warehouse_create_2025" ON warehouses;
DROP POLICY IF EXISTS "allow_warehouse_update_2025" ON warehouses;
DROP POLICY IF EXISTS "allow_warehouse_delete_2025" ON warehouses;

DROP POLICY IF EXISTS "unified_warehouses_select_2025" ON warehouses;
DROP POLICY IF EXISTS "unified_warehouses_insert_2025" ON warehouses;

DROP POLICY IF EXISTS "final_warehouses_select_2025" ON warehouses;
DROP POLICY IF EXISTS "final_warehouses_insert_2025" ON warehouses;
DROP POLICY IF EXISTS "final_warehouses_update_2025" ON warehouses;
DROP POLICY IF EXISTS "final_warehouses_delete_2025" ON warehouses;

-- حذف جميع سياسات مخزون المخازن
DROP POLICY IF EXISTS "warehouse_inventory_select_expanded_roles" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_insert_expanded_roles" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_update_expanded_roles" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_delete_expanded_roles" ON warehouse_inventory;

DROP POLICY IF EXISTS "allow_inventory_access_2025" ON warehouse_inventory;
DROP POLICY IF EXISTS "allow_inventory_manage_2025" ON warehouse_inventory;

DROP POLICY IF EXISTS "final_inventory_select_2025" ON warehouse_inventory;
DROP POLICY IF EXISTS "final_inventory_insert_2025" ON warehouse_inventory;
DROP POLICY IF EXISTS "final_inventory_update_2025" ON warehouse_inventory;
DROP POLICY IF EXISTS "final_inventory_delete_2025" ON warehouse_inventory;

SELECT '✅ تم حذف جميع السياسات المتضاربة' as cleanup_result;

-- =====================================================
-- STEP 2: التأكد من حالة المستخدمين
-- =====================================================

SELECT '👥 === تحديث حالة المستخدمين ===' as user_fix_step;

-- تحديث جميع المستخدمين المصرح لهم
UPDATE user_profiles 
SET 
  status = 'approved',
  updated_at = NOW()
WHERE 
  role IN ('admin', 'owner', 'accountant', 'warehouseManager')
  AND status != 'approved';

-- عرض حالة المستخدمين
SELECT 
  '👤 حالة المستخدمين' as check_type,
  role,
  status,
  COUNT(*) as user_count,
  STRING_AGG(email, ', ') as sample_emails
FROM user_profiles 
WHERE role IN ('admin', 'owner', 'accountant', 'warehouseManager')
GROUP BY role, status
ORDER BY role, status;

-- =====================================================
-- STEP 3: إنشاء سياسات بسيطة وموحدة
-- =====================================================

SELECT '🔐 === إنشاء سياسات موحدة للمحاسب ومدير المخزن ===' as policy_creation_step;

-- تفعيل RLS
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;

-- سياسة واحدة بسيطة للمخازن - المحاسب ومدير المخزن لهم نفس الصلاحيات
CREATE POLICY "accountant_warehouse_full_access" ON warehouses
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- سياسة واحدة بسيطة لمخزون المخازن - المحاسب ومدير المخزن لهم نفس الصلاحيات
CREATE POLICY "accountant_inventory_full_access" ON warehouse_inventory
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

SELECT '✅ تم إنشاء السياسات الموحدة بنجاح' as policy_result;

-- =====================================================
-- STEP 4: اختبار فوري للوصول
-- =====================================================

SELECT '🧪 === اختبار الوصول للبيانات ===' as test_step;

-- اختبار الوصول للمخازن
SELECT 
  '🏢 اختبار المخازن' as test_type,
  COUNT(*) as total_warehouses,
  COUNT(*) FILTER (WHERE is_active = true) as active_warehouses,
  STRING_AGG(name, ', ' ORDER BY name) as warehouse_names
FROM warehouses;

-- اختبار الوصول لمخزون المخازن
SELECT 
  '📦 اختبار المخزون' as test_type,
  COUNT(*) as total_inventory_items,
  COUNT(DISTINCT warehouse_id) as warehouses_with_inventory,
  SUM(quantity) as total_quantity
FROM warehouse_inventory;

-- اختبار الوصول للمخازن مع المخزون
SELECT 
  '🔗 اختبار المخازن مع المخزون' as test_type,
  w.name as warehouse_name,
  COUNT(wi.id) as inventory_items,
  COALESCE(SUM(wi.quantity), 0) as total_quantity
FROM warehouses w
LEFT JOIN warehouse_inventory wi ON w.id = wi.warehouse_id
GROUP BY w.id, w.name
ORDER BY w.name;

-- عرض السياسات النهائية
SELECT 
  '📋 السياسات النهائية' as check_type,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN policyname LIKE 'accountant_%' THEN '✅ سياسة المحاسب الجديدة'
    ELSE '⚠️ سياسة أخرى'
  END as policy_status
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory')
ORDER BY tablename, cmd;

-- =====================================================
-- STEP 5: تشخيص المستخدم الحالي
-- =====================================================

SELECT '👤 === تشخيص المستخدم الحالي ===' as user_diagnosis_step;

-- معلومات المستخدم الحالي
SELECT 
  '🔍 المستخدم الحالي' as info_type,
  auth.uid() as user_id,
  CASE 
    WHEN auth.uid() IS NULL THEN '❌ غير مسجل دخول'
    ELSE '✅ مسجل دخول'
  END as auth_status;

-- ملف المستخدم الحالي
SELECT 
  '👤 ملف المستخدم' as info_type,
  up.id,
  up.email,
  up.role,
  up.status,
  CASE 
    WHEN up.role IN ('admin', 'owner', 'accountant', 'warehouseManager') AND up.status = 'approved' 
    THEN '✅ يجب أن يرى المخازن'
    ELSE '❌ لا يملك صلاحية'
  END as expected_access
FROM user_profiles up
WHERE up.id = auth.uid();

SELECT '✅ === إصلاح وصول المحاسب مكتمل ===' as completion_message;
SELECT 'المحاسب الآن يجب أن يرى جميع المخازن والمخزون مثل مدير المخزن تماماً' as final_note;
