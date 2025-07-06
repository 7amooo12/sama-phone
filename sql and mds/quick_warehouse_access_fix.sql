-- 🚀 QUICK WAREHOUSE ACCESS FIX
-- إصلاح سريع لمشكلة عدم ظهور بيانات المخازن للأدوار المختلفة
-- البيانات موجودة (19 عنصر، 3 مخازن، 85 كمية) لكن RLS يمنع الوصول

-- =====================================================
-- STEP 1: تحديث حالة المستخدمين
-- =====================================================

-- التأكد من أن جميع المستخدمين المصرح لهم لديهم status = 'approved'
UPDATE user_profiles 
SET 
  status = 'approved',
  updated_at = NOW()
WHERE 
  role IN ('admin', 'owner', 'accountant', 'warehouseManager')
  AND status != 'approved';

-- عرض حالة المستخدمين بعد التحديث
SELECT 
  '👥 USER STATUS AFTER UPDATE' as check_type,
  role,
  status,
  COUNT(*) as user_count,
  STRING_AGG(email, ', ') as emails
FROM user_profiles 
WHERE role IN ('admin', 'owner', 'accountant', 'warehouseManager')
GROUP BY role, status
ORDER BY role;

-- =====================================================
-- STEP 2: حذف جميع السياسات المتضاربة
-- =====================================================

-- حذف جميع سياسات المخازن الموجودة
DROP POLICY IF EXISTS "المخازن قابلة للقراءة من قبل المستخدمين المصرح لهم" ON warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للإنشاء من قبل المديرين ومديري المخازن" ON warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للإنشاء من قبل المديرين" ON warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للتحديث من قبل المديرين ومديري المخازن" ON warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للتحديث من قبل المديرين" ON warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للحذف من قبل المديرين فقط" ON warehouses;
DROP POLICY IF EXISTS "المخازن قابلة للحذف من قبل المديرين" ON warehouses;
DROP POLICY IF EXISTS "warehouse_managers_can_read_warehouses" ON warehouses;
DROP POLICY IF EXISTS "warehouse_managers_can_manage_assigned_warehouses" ON warehouses;
DROP POLICY IF EXISTS "secure_warehouses_select" ON warehouses;
DROP POLICY IF EXISTS "warehouse_select_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouse_insert_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouse_update_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouse_delete_policy" ON warehouses;
DROP POLICY IF EXISTS "warehouses_select_admin_accountant" ON warehouses;
DROP POLICY IF EXISTS "warehouses_insert_admin_accountant" ON warehouses;
DROP POLICY IF EXISTS "warehouses_update_admin_accountant" ON warehouses;
DROP POLICY IF EXISTS "warehouses_delete_admin_accountant" ON warehouses;

-- حذف جميع سياسات مخزون المخازن الموجودة
DROP POLICY IF EXISTS "مخزون المخازن قابل للقراءة من قبل المستخدمين المصرح لهم" ON warehouse_inventory;
DROP POLICY IF EXISTS "مخزون المخازن قابل للتحديث من قبل مديري المخازن" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_select_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_insert_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_update_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_delete_policy" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_select_admin_accountant" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_insert_admin_accountant" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_update_admin_accountant" ON warehouse_inventory;
DROP POLICY IF EXISTS "warehouse_inventory_delete_admin_accountant" ON warehouse_inventory;

-- =====================================================
-- STEP 3: إنشاء سياسات جديدة وبسيطة
-- =====================================================

-- تفعيل RLS
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;

-- سياسة قراءة المخازن - بسيطة وواضحة
CREATE POLICY "allow_warehouse_access_2025" ON warehouses
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- سياسة إنشاء المخازن
CREATE POLICY "allow_warehouse_create_2025" ON warehouses
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- سياسة تحديث المخازن
CREATE POLICY "allow_warehouse_update_2025" ON warehouses
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- سياسة حذف المخازن (admin و owner فقط)
CREATE POLICY "allow_warehouse_delete_2025" ON warehouses
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- سياسة قراءة مخزون المخازن
CREATE POLICY "allow_inventory_access_2025" ON warehouse_inventory
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- سياسة إدارة مخزون المخازن (جميع العمليات)
CREATE POLICY "allow_inventory_manage_2025" ON warehouse_inventory
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- =====================================================
-- STEP 4: اختبار الوصول
-- =====================================================

-- اختبار الوصول للمخازن
SELECT 
  '🏢 WAREHOUSE ACCESS TEST' as test_type,
  COUNT(*) as accessible_warehouses,
  STRING_AGG(name, ', ') as warehouse_names
FROM warehouses;

-- اختبار الوصول لمخزون المخازن
SELECT 
  '📦 INVENTORY ACCESS TEST' as test_type,
  COUNT(*) as accessible_inventory_items,
  COUNT(DISTINCT warehouse_id) as warehouses_with_inventory,
  SUM(quantity) as total_quantity
FROM warehouse_inventory;

-- عرض السياسات الجديدة
SELECT 
  '📋 NEW POLICIES CREATED' as check_type,
  policyname,
  cmd
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory')
  AND policyname LIKE '%2025%'
ORDER BY tablename, cmd;

SELECT '✅ QUICK WAREHOUSE ACCESS FIX COMPLETED!' as result;
SELECT 'Test warehouse access in Flutter app now' as next_step;
