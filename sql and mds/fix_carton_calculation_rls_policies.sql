-- 📦 FIX CARTON CALCULATION RLS POLICIES - IDEMPOTENT VERSION
-- Comprehensive fix for carton/box display issues across Admin, Accountant, and Business Owner roles
-- This script ensures all warehouse-related tables have proper RLS policies for carton calculations
-- Uses timestamped policy names to avoid conflicts and includes comprehensive cleanup

-- =====================================================
-- STEP 1: COMPREHENSIVE POLICY CLEANUP
-- =====================================================

SELECT '🧹 === COMPREHENSIVE POLICY CLEANUP ===' as cleanup_step;

-- Remove ALL existing warehouse-related policies to start fresh
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    -- Get all existing policies for warehouse tables
    FOR policy_record IN
        SELECT tablename, policyname
        FROM pg_policies
        WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests')
        AND schemaname = 'public'
    LOOP
        BEGIN
            EXECUTE format('DROP POLICY IF EXISTS %I ON %I', policy_record.policyname, policy_record.tablename);
            RAISE NOTICE '✅ Dropped policy: % on %', policy_record.policyname, policy_record.tablename;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '⚠️ Could not drop policy % on %: %', policy_record.policyname, policy_record.tablename, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE '🎯 Comprehensive policy cleanup completed';
END $$;

-- =====================================================
-- STEP 2: DIAGNOSTIC ANALYSIS
-- =====================================================

SELECT '🔍 === CARTON CALCULATION RLS DIAGNOSTIC ===' as diagnostic_step;

-- Check current RLS status for warehouse tables
SELECT 
    '📋 TABLE RLS STATUS' as check_type,
    c.relname as table_name,
    c.relrowsecurity as rls_enabled,
    CASE 
        WHEN c.relrowsecurity THEN '✅ RLS ENABLED'
        ELSE '❌ RLS DISABLED'
    END as rls_status
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relname IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests')
AND n.nspname = 'public'
AND c.relkind = 'r'
ORDER BY c.relname;

-- Check existing policies for warehouse_inventory (critical for carton calculations)
SELECT 
    '🛡️ WAREHOUSE_INVENTORY POLICIES' as check_type,
    policyname,
    cmd as operation,
    CASE 
        WHEN qual LIKE '%admin%' AND qual LIKE '%accountant%' AND qual LIKE '%owner%' THEN '✅ ALL ROLES'
        WHEN qual LIKE '%admin%' OR qual LIKE '%accountant%' OR qual LIKE '%owner%' THEN '⚠️ PARTIAL'
        ELSE '❌ MISSING ROLES'
    END as role_coverage
FROM pg_policies 
WHERE tablename = 'warehouse_inventory'
AND schemaname = 'public'
ORDER BY cmd, policyname;

-- Check user_profiles table structure for role verification
SELECT 
    '👤 USER PROFILES STRUCTURE' as check_type,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'user_profiles'
AND column_name IN ('id', 'role', 'status')
ORDER BY column_name;

-- =====================================================
-- STEP 2: CLEAN UP EXISTING POLICIES
-- =====================================================

SELECT '🧹 === CLEANING UP EXISTING POLICIES ===' as cleanup_step;

-- First, let's see what policies currently exist
SELECT
    '🔍 EXISTING POLICIES BEFORE CLEANUP' as check_type,
    tablename,
    policyname,
    cmd as operation
FROM pg_policies
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests')
AND schemaname = 'public'
ORDER BY tablename, policyname;

-- Clean up warehouse_inventory policies
DO $$
BEGIN
    -- Drop existing policies for warehouse_inventory
    DROP POLICY IF EXISTS "secure_inventory_select" ON warehouse_inventory;
    DROP POLICY IF EXISTS "secure_inventory_select_carton_access" ON warehouse_inventory;
    DROP POLICY IF EXISTS "secure_inventory_insert" ON warehouse_inventory;
    DROP POLICY IF EXISTS "secure_inventory_insert_carton_access" ON warehouse_inventory;
    DROP POLICY IF EXISTS "secure_inventory_update" ON warehouse_inventory;
    DROP POLICY IF EXISTS "secure_inventory_update_carton_access" ON warehouse_inventory;
    DROP POLICY IF EXISTS "secure_inventory_delete" ON warehouse_inventory;
    DROP POLICY IF EXISTS "warehouse_inventory_select_admin_accountant" ON warehouse_inventory;
    DROP POLICY IF EXISTS "warehouse_inventory_select_policy" ON warehouse_inventory;
    DROP POLICY IF EXISTS "warehouse_inventory_insert_policy" ON warehouse_inventory;
    DROP POLICY IF EXISTS "warehouse_inventory_update_policy" ON warehouse_inventory;
    
    RAISE NOTICE '✅ Cleaned up warehouse_inventory policies';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ Some policies may not have existed: %', SQLERRM;
END $$;

-- Clean up warehouses policies
DO $$
BEGIN
    -- Drop existing policies for warehouses
    DROP POLICY IF EXISTS "secure_warehouses_select" ON warehouses;
    DROP POLICY IF EXISTS "secure_warehouses_insert" ON warehouses;
    DROP POLICY IF EXISTS "secure_warehouses_update" ON warehouses;
    DROP POLICY IF EXISTS "secure_warehouses_delete" ON warehouses;
    DROP POLICY IF EXISTS "warehouse_managers_can_read_warehouses" ON warehouses;
    DROP POLICY IF EXISTS "warehouse_managers_can_manage_assigned_warehouses" ON warehouses;
    DROP POLICY IF EXISTS "warehouses_carton_select_policy" ON warehouses;
    DROP POLICY IF EXISTS "warehouses_carton_insert_policy" ON warehouses;
    DROP POLICY IF EXISTS "warehouses_carton_update_policy" ON warehouses;
    DROP POLICY IF EXISTS "warehouses_carton_delete_policy" ON warehouses;

    RAISE NOTICE '✅ Cleaned up warehouses policies';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ Some policies may not have existed: %', SQLERRM;
END $$;

-- Clean up warehouse_transactions policies
DO $$
BEGIN
    -- Drop existing policies for warehouse_transactions
    DROP POLICY IF EXISTS "secure_transactions_select" ON warehouse_transactions;
    DROP POLICY IF EXISTS "secure_transactions_insert" ON warehouse_transactions;
    DROP POLICY IF EXISTS "secure_transactions_update" ON warehouse_transactions;
    DROP POLICY IF EXISTS "secure_transactions_delete" ON warehouse_transactions;
    DROP POLICY IF EXISTS "warehouse_managers_can_manage_transactions" ON warehouse_transactions;
    DROP POLICY IF EXISTS "transactions_carton_select_policy" ON warehouse_transactions;
    DROP POLICY IF EXISTS "transactions_carton_insert_policy" ON warehouse_transactions;
    DROP POLICY IF EXISTS "transactions_carton_update_policy" ON warehouse_transactions;
    DROP POLICY IF EXISTS "transactions_carton_delete_policy" ON warehouse_transactions;

    RAISE NOTICE '✅ Cleaned up warehouse_transactions policies';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ Some policies may not have existed: %', SQLERRM;
END $$;

-- Clean up warehouse_requests policies
DO $$
BEGIN
    -- Drop existing policies for warehouse_requests
    DROP POLICY IF EXISTS "secure_requests_select" ON warehouse_requests;
    DROP POLICY IF EXISTS "secure_requests_insert" ON warehouse_requests;
    DROP POLICY IF EXISTS "secure_requests_update" ON warehouse_requests;
    DROP POLICY IF EXISTS "secure_requests_delete" ON warehouse_requests;
    DROP POLICY IF EXISTS "users_can_create_withdrawal_requests" ON warehouse_requests;
    DROP POLICY IF EXISTS "warehouse_managers_can_manage_requests" ON warehouse_requests;
    DROP POLICY IF EXISTS "requests_carton_select_policy" ON warehouse_requests;
    DROP POLICY IF EXISTS "requests_carton_insert_policy" ON warehouse_requests;
    DROP POLICY IF EXISTS "requests_carton_update_policy" ON warehouse_requests;
    DROP POLICY IF EXISTS "requests_carton_delete_policy" ON warehouse_requests;

    RAISE NOTICE '✅ Cleaned up warehouse_requests policies';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ Some policies may not have existed: %', SQLERRM;
END $$;

-- =====================================================
-- STEP 3: ENABLE RLS ON ALL WAREHOUSE TABLES
-- =====================================================

SELECT '🔐 === ENABLING RLS ON WAREHOUSE TABLES ===' as rls_step;

-- Enable RLS on all warehouse tables
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_requests ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- STEP 4: CREATE COMPREHENSIVE RLS POLICIES
-- =====================================================

SELECT '🛡️ === CREATING COMPREHENSIVE RLS POLICIES ===' as policy_step;

-- ==================== WAREHOUSES TABLE POLICIES ====================

-- SELECT: Admin, Owner, Accountant, Warehouse Manager can view warehouses
CREATE POLICY "warehouses_carton_select_policy" ON warehouses
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Admin, Owner, Accountant can create warehouses
CREATE POLICY "warehouses_carton_insert_policy" ON warehouses
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Admin, Owner, Accountant can update warehouses
CREATE POLICY "warehouses_carton_update_policy" ON warehouses
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Admin, Owner can delete warehouses
CREATE POLICY "warehouses_carton_delete_policy" ON warehouses
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== WAREHOUSE_INVENTORY TABLE POLICIES (CRITICAL FOR CARTONS) ====================

-- SELECT: All warehouse roles can view inventory (ESSENTIAL FOR CARTON CALCULATIONS)
CREATE POLICY "inventory_carton_select_policy" ON warehouse_inventory
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: All warehouse roles can add inventory
CREATE POLICY "inventory_carton_insert_policy" ON warehouse_inventory
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: All warehouse roles can update inventory
CREATE POLICY "inventory_carton_update_policy" ON warehouse_inventory
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Admin, Owner can delete inventory
CREATE POLICY "inventory_carton_delete_policy" ON warehouse_inventory
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== WAREHOUSE_TRANSACTIONS TABLE POLICIES ====================

-- SELECT: All warehouse roles can view transactions
CREATE POLICY "transactions_carton_select_policy" ON warehouse_transactions
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: All warehouse roles can create transactions
CREATE POLICY "transactions_carton_insert_policy" ON warehouse_transactions
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Admin, Owner can modify transactions (audit integrity)
CREATE POLICY "transactions_carton_update_policy" ON warehouse_transactions
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Admin can delete transactions (audit integrity)
CREATE POLICY "transactions_carton_delete_policy" ON warehouse_transactions
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role = 'admin'
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== WAREHOUSE_REQUESTS TABLE POLICIES ====================

-- SELECT: All warehouse roles can view requests
CREATE POLICY "requests_carton_select_policy" ON warehouse_requests
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: All warehouse roles can create requests
CREATE POLICY "requests_carton_insert_policy" ON warehouse_requests
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Admin, Owner, Accountant can approve/modify requests
CREATE POLICY "requests_carton_update_policy" ON warehouse_requests
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner', 'accountant')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Admin, Owner can delete requests
CREATE POLICY "requests_carton_delete_policy" ON warehouse_requests
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- =====================================================
-- STEP 5: VERIFICATION
-- =====================================================

SELECT '✅ === VERIFICATION OF NEW POLICIES ===' as verification_step;

-- Verify new policies are in place
SELECT
  '📋 NEW POLICIES CREATED' as verification_type,
  tablename,
  policyname,
  cmd as operation,
  CASE
    WHEN policyname LIKE '%carton%' THEN '✅ NEW CARTON POLICY'
    ELSE '⚠️ OTHER POLICY'
  END as policy_status
FROM pg_policies
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests')
AND schemaname = 'public'
ORDER BY tablename, cmd;

-- Test carton calculation access for different roles
SELECT '🧪 === TESTING CARTON CALCULATION ACCESS ===' as test_step;

-- Check if warehouse_inventory table has quantity_per_carton column
SELECT
    '📦 CARTON COLUMN CHECK' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'warehouse_inventory'
AND column_name IN ('quantity', 'quantity_per_carton')
ORDER BY column_name;

-- Sample carton calculation test (if data exists)
SELECT
    '🧮 CARTON CALCULATION TEST' as test_type,
    COUNT(*) as inventory_records,
    COUNT(CASE WHEN quantity_per_carton > 0 THEN 1 END) as valid_carton_records,
    AVG(CASE WHEN quantity_per_carton > 0 THEN CEIL(quantity::DECIMAL / quantity_per_carton) END) as avg_cartons
FROM warehouse_inventory
WHERE quantity > 0;

SELECT '🎯 === CARTON CALCULATION RLS FIX COMPLETED ===' as completion_message;
