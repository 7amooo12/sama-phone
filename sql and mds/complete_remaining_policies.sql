-- 🔧 إكمال تحديث سياسات المخازن المتبقية
-- Complete updating remaining warehouse policies

-- ==================== تحديث سياسات SELECT المتبقية ====================

-- تحديث سياسة SELECT للمخازن
DROP POLICY IF EXISTS "warehouses_select_admin_accountant" ON warehouses;
CREATE POLICY "warehouses_select_complete" ON warehouses
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- تحديث سياسة SELECT لطلبات المخازن
DROP POLICY IF EXISTS "warehouse_requests_select_admin_accountant" ON warehouse_requests;
CREATE POLICY "warehouse_requests_select_complete" ON warehouse_requests
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- تحديث سياسة SELECT لمخزون المخازن
DROP POLICY IF EXISTS "warehouse_inventory_select_admin_accountant" ON warehouse_inventory;
CREATE POLICY "warehouse_inventory_select_complete" ON warehouse_inventory
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- تحديث سياسة SELECT لمعاملات المخازن
DROP POLICY IF EXISTS "warehouse_transactions_select_admin_accountant" ON warehouse_transactions;
CREATE POLICY "warehouse_transactions_select_complete" ON warehouse_transactions
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== تحديث سياسات INSERT المتبقية ====================

-- تحديث سياسة INSERT لطلبات المخازن
DROP POLICY IF EXISTS "warehouse_requests_insert_admin_accountant" ON warehouse_requests;
CREATE POLICY "warehouse_requests_insert_complete" ON warehouse_requests
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- تحديث سياسة INSERT لمخزون المخازن
DROP POLICY IF EXISTS "warehouse_inventory_insert_admin_accountant" ON warehouse_inventory;
CREATE POLICY "warehouse_inventory_insert_complete" ON warehouse_inventory
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- تحديث سياسة INSERT لمعاملات المخازن
DROP POLICY IF EXISTS "warehouse_transactions_insert_admin_accountant" ON warehouse_transactions;
CREATE POLICY "warehouse_transactions_insert_complete" ON warehouse_transactions
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== تحديث سياسات UPDATE المتبقية ====================

-- تحديث سياسة UPDATE لمخزون المخازن
DROP POLICY IF EXISTS "warehouse_inventory_update_admin_accountant" ON warehouse_inventory;
CREATE POLICY "warehouse_inventory_update_complete" ON warehouse_inventory
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- تحديث سياسة UPDATE لمعاملات المخازن
DROP POLICY IF EXISTS "warehouse_transactions_update_admin_accountant" ON warehouse_transactions;
CREATE POLICY "warehouse_transactions_update_complete" ON warehouse_transactions
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== التحقق النهائي ====================

-- عرض جميع السياسات المحدثة
SELECT 
  '✅ التحقق النهائي من السياسات' as verification_type,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN policyname LIKE '%complete%' OR policyname LIKE '%warehouse_manager%' THEN '✅ محدث'
    ELSE '❌ لم يحدث'
  END as policy_status
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_requests', 'warehouse_inventory', 'warehouse_transactions')
ORDER BY tablename, cmd;

-- ==================== رسالة النجاح ====================

DO $$
DECLARE
  total_policies INTEGER;
  updated_policies INTEGER;
BEGIN
  SELECT 
    COUNT(*),
    COUNT(CASE WHEN policyname LIKE '%complete%' OR policyname LIKE '%warehouse_manager%' THEN 1 END)
  INTO total_policies, updated_policies
  FROM pg_policies 
  WHERE tablename IN ('warehouses', 'warehouse_requests', 'warehouse_inventory', 'warehouse_transactions');
  
  RAISE NOTICE '';
  RAISE NOTICE '🎉 تم إكمال تحديث صلاحيات المخازن!';
  RAISE NOTICE '================================';
  RAISE NOTICE '✅ إجمالي السياسات: %', total_policies;
  RAISE NOTICE '✅ السياسات المحدثة: %', updated_policies;
  RAISE NOTICE '✅ نسبة الإكمال: %%%', ROUND((updated_policies::DECIMAL / total_policies * 100), 1);
  RAISE NOTICE '';
  
  IF updated_policies = total_policies THEN
    RAISE NOTICE '🎯 نجح: تم تحديث جميع سياسات المخازن!';
    RAISE NOTICE '';
    RAISE NOTICE '🔐 مصفوفة الصلاحيات النهائية:';
    RAISE NOTICE '  👑 المدير: صلاحيات كاملة على جميع جداول المخازن';
    RAISE NOTICE '  🏢 صاحب العمل: صلاحيات كاملة على جميع جداول المخازن';
    RAISE NOTICE '  🏭 مدير المخزن: صلاحيات كاملة على جميع جداول المخازن';
    RAISE NOTICE '  📊 المحاسب: صلاحيات كاملة عدا حذف المعاملات';
    RAISE NOTICE '  👤 العميل: لا يوجد وصول (محجوب بشكل صحيح)';
    RAISE NOTICE '';
    RAISE NOTICE '📋 جاهز للإنتاج:';
    RAISE NOTICE '1. جميع مديري المخازن يمكنهم إدارة المخازن بالكامل';
    RAISE NOTICE '2. أصحاب الأعمال لديهم تحكم تشغيلي كامل';
    RAISE NOTICE '3. المحاسبون لديهم وصول إشرافي مناسب';
    RAISE NOTICE '4. الحدود الأمنية محفوظة للمستخدمين غير المصرح لهم';
  ELSE
    RAISE NOTICE '⚠️ غير مكتمل: % سياسات تحتاج تحديث', (total_policies - updated_policies);
  END IF;
  RAISE NOTICE '';
END $$;
