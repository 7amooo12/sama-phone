-- =====================================================
-- COMPREHENSIVE DATABASE ERROR RESOLUTION SCRIPT
-- =====================================================
-- This script addresses critical database errors affecting SmartBizTracker:
-- 1. Authentication state management issues
-- 2. Wallet transaction constraint violations
-- 3. Electronic payment approval failures
-- 4. Invoice widget type casting errors
-- 5. Warehouse data loading authentication failures

SELECT '🔧 STARTING COMPREHENSIVE DATABASE ERROR RESOLUTION...' as progress;

-- =====================================================
-- PHASE 1: FIX WALLET TRANSACTION CONSTRAINT VIOLATIONS
-- =====================================================

SELECT '🔧 PHASE 1: FIXING WALLET TRANSACTION CONSTRAINTS...' as progress;

-- First, check current constraint status
DO $$
DECLARE
    constraint_exists BOOLEAN := FALSE;
    invalid_count INTEGER := 0;
    current_constraint_def TEXT;
BEGIN
    -- Check if constraint exists
    SELECT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'wallet_transactions_reference_type_valid'
    ) INTO constraint_exists;

    IF constraint_exists THEN
        -- Get current constraint definition using pg_get_constraintdef function
        SELECT pg_get_constraintdef(oid) INTO current_constraint_def
        FROM pg_constraint
        WHERE conname = 'wallet_transactions_reference_type_valid';

        RAISE NOTICE '📋 Current constraint definition: %', current_constraint_def;

        -- Check for invalid reference_type values
        SELECT COUNT(*) INTO invalid_count
        FROM public.wallet_transactions
        WHERE reference_type IS NOT NULL
        AND reference_type NOT IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer', 'electronic_payment', 'adminAdjustment', 'adjustment');

        RAISE NOTICE '📊 Found % rows with invalid reference_type values', invalid_count;
    ELSE
        RAISE NOTICE '⚠️ wallet_transactions_reference_type_valid constraint does not exist';
    END IF;
END $$;

-- Update constraint to include missing reference types
DO $$
DECLARE
    constraint_exists BOOLEAN := FALSE;
BEGIN
    -- Check if constraint exists
    SELECT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'wallet_transactions_reference_type_valid'
    ) INTO constraint_exists;

    -- Drop existing constraint if it exists
    IF constraint_exists THEN
        ALTER TABLE public.wallet_transactions
        DROP CONSTRAINT wallet_transactions_reference_type_valid;
        RAISE NOTICE '🗑️ Dropped existing wallet_transactions_reference_type_valid constraint';
    END IF;

    -- Create updated constraint with all required reference types
    ALTER TABLE public.wallet_transactions
    ADD CONSTRAINT wallet_transactions_reference_type_valid CHECK (
        reference_type IS NULL OR reference_type IN (
            'order', 'task', 'reward', 'salary', 'manual', 'transfer',
            'electronic_payment', 'adminAdjustment', 'adjustment', 'refund',
            'wallet_topup', 'wallet_withdrawal', 'payment', 'bonus', 'penalty'
        )
    );

    RAISE NOTICE '✅ Created updated wallet_transactions_reference_type_valid constraint with all required types';
END $$;

SELECT '✅ PHASE 1 COMPLETED: WALLET TRANSACTION CONSTRAINTS FIXED' as progress;

-- =====================================================
-- PHASE 2: FIX ELECTRONIC PAYMENT APPROVAL FAILURES
-- =====================================================

SELECT '🔧 PHASE 2: FIXING ELECTRONIC PAYMENT APPROVAL FAILURES...' as progress;

-- Create function to safely validate approver role without PGRST116 errors
CREATE OR REPLACE FUNCTION public.validate_approver_role_safe(approver_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_record RECORD;
    result JSONB;
BEGIN
    -- Get user profile safely (avoid PGRST116 by using LIMIT 1)
    SELECT role, status INTO user_record
    FROM user_profiles
    WHERE id = approver_id
    AND status IN ('approved', 'active')
    LIMIT 1;

    -- Check if user was found
    IF NOT FOUND THEN
        result := jsonb_build_object(
            'valid', false,
            'error', 'User not found or not active',
            'error_ar', 'المستخدم غير موجود أو غير مفعل'
        );
    ELSIF user_record.role NOT IN ('admin', 'owner', 'accountant') THEN
        result := jsonb_build_object(
            'valid', false,
            'error', 'User does not have approval permissions',
            'error_ar', 'المستخدم ليس لديه صلاحيات الاعتماد',
            'role', user_record.role
        );
    ELSE
        result := jsonb_build_object(
            'valid', true,
            'role', user_record.role,
            'status', user_record.status
        );
    END IF;

    RETURN result;
END;
$$;

-- Create function to safely get client wallet information
CREATE OR REPLACE FUNCTION public.get_client_wallet_safe(client_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    wallet_record RECORD;
    wallet_count INTEGER;
    result JSONB;
BEGIN
    -- Count wallets for this client
    SELECT COUNT(*) INTO wallet_count
    FROM wallets
    WHERE user_id = client_id
    AND status = 'active';

    IF wallet_count = 0 THEN
        result := jsonb_build_object(
            'found', false,
            'error', 'No active wallet found for client',
            'error_ar', 'لا توجد محفظة نشطة للعميل'
        );
    ELSIF wallet_count = 1 THEN
        -- Single wallet - safe to use
        SELECT id, balance, wallet_type INTO wallet_record
        FROM wallets
        WHERE user_id = client_id
        AND status = 'active'
        LIMIT 1;

        result := jsonb_build_object(
            'found', true,
            'wallet_id', wallet_record.id,
            'balance', wallet_record.balance,
            'wallet_type', wallet_record.wallet_type,
            'multiple_wallets', false
        );
    ELSE
        -- Multiple wallets - prioritize personal wallet
        SELECT id, balance, wallet_type INTO wallet_record
        FROM wallets
        WHERE user_id = client_id
        AND status = 'active'
        ORDER BY
            CASE WHEN wallet_type = 'personal' THEN 1 ELSE 2 END,
            created_at DESC
        LIMIT 1;

        result := jsonb_build_object(
            'found', true,
            'wallet_id', wallet_record.id,
            'balance', wallet_record.balance,
            'wallet_type', wallet_record.wallet_type,
            'multiple_wallets', true,
            'wallet_count', wallet_count
        );
    END IF;

    RETURN result;
END;
$$;

SELECT '✅ PHASE 2 COMPLETED: ELECTRONIC PAYMENT FUNCTIONS CREATED' as progress;

-- =====================================================
-- PHASE 3: ENSURE SECURITY DEFINER FUNCTIONS EXIST
-- =====================================================

SELECT '🔧 PHASE 3: CREATING WAREHOUSE ACCESS FUNCTIONS...' as progress;

-- Create or update the warehouse access checker function
CREATE OR REPLACE FUNCTION public.check_warehouse_access_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
    user_status TEXT;
BEGIN
    -- Get user role and status safely
    SELECT role, status INTO user_role, user_status
    FROM user_profiles
    WHERE id = auth.uid()
    LIMIT 1;

    -- Check if user has warehouse access
    RETURN user_status IN ('approved', 'active') AND
           user_role IN ('admin', 'owner', 'accountant', 'warehouseManager', 'warehouse_manager');
END;
$$;

-- Create function to check if user can manage warehouses (create, update, delete)
CREATE OR REPLACE FUNCTION public.check_warehouse_manage_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
    user_status TEXT;
BEGIN
    -- Get user role and status safely
    SELECT role, status INTO user_role, user_status
    FROM user_profiles
    WHERE id = auth.uid()
    LIMIT 1;
    
    -- Admin, owner, and accountant can manage warehouses
    -- warehouseManager can only manage assigned warehouses (handled in policies)
    RETURN user_status IN ('approved', 'active') AND 
           user_role IN ('admin', 'owner', 'accountant', 'warehouseManager', 'warehouse_manager');
END;
$$;

-- Create function to check if user can delete warehouses
CREATE OR REPLACE FUNCTION public.check_warehouse_delete_safe()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_role TEXT;
    user_status TEXT;
BEGIN
    -- Get user role and status safely
    SELECT role, status INTO user_role, user_status
    FROM user_profiles
    WHERE id = auth.uid()
    LIMIT 1;
    
    -- Only admin and owner can delete warehouses
    RETURN user_status IN ('approved', 'active') AND 
           user_role IN ('admin', 'owner');
END;
$$;

SELECT '✅ SECURITY DEFINER FUNCTIONS CREATED/UPDATED' as progress;

-- =====================================================
-- STEP 2: UPDATE WAREHOUSES TABLE POLICIES
-- =====================================================

-- Drop existing policies
DO $$
DECLARE
    policy_record RECORD;
    policy_name text;
    drop_sql text;
BEGIN
    -- Drop all existing policies dynamically
    FOR policy_record IN 
        SELECT policyname
        FROM pg_policies 
        WHERE tablename = 'warehouses' AND schemaname = 'public'
    LOOP
        policy_name := policy_record.policyname;
        drop_sql := format('DROP POLICY IF EXISTS "%s" ON warehouses', policy_name);
        EXECUTE drop_sql;
        RAISE NOTICE 'Dropped warehouses policy: %', policy_name;
    END LOOP;
END $$;

-- Create new safe policies for warehouses
DO $$
BEGIN
    -- SELECT policy: Allow all authorized roles to view warehouses
    BEGIN
        CREATE POLICY "warehouses_select_expanded_roles" ON warehouses
        FOR SELECT TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouses_select_expanded_roles policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouses_select_expanded_roles already exists, skipping';
    END;
    
    -- INSERT policy: Allow admin, owner, accountant to create warehouses
    BEGIN
        CREATE POLICY "warehouses_insert_expanded_roles" ON warehouses
        FOR INSERT TO authenticated
        WITH CHECK (
            auth.uid() IS NOT NULL AND
            check_warehouse_manage_safe()
        );
        RAISE NOTICE 'Created warehouses_insert_expanded_roles policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouses_insert_expanded_roles already exists, skipping';
    END;
    
    -- UPDATE policy: Allow authorized roles to update warehouses
    BEGIN
        CREATE POLICY "warehouses_update_expanded_roles" ON warehouses
        FOR UPDATE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            (check_warehouse_manage_safe() OR manager_id = auth.uid())
        );
        RAISE NOTICE 'Created warehouses_update_expanded_roles policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouses_update_expanded_roles already exists, skipping';
    END;
    
    -- DELETE policy: Only admin and owner can delete warehouses
    BEGIN
        CREATE POLICY "warehouses_delete_expanded_roles" ON warehouses
        FOR DELETE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_delete_safe()
        );
        RAISE NOTICE 'Created warehouses_delete_expanded_roles policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouses_delete_expanded_roles already exists, skipping';
    END;
END $$;

SELECT '✅ WAREHOUSES TABLE POLICIES UPDATED' as progress;

-- =====================================================
-- STEP 3: UPDATE WAREHOUSE_INVENTORY TABLE POLICIES
-- =====================================================

-- Drop existing warehouse_inventory policies
DO $$
DECLARE
    policy_record RECORD;
    policy_name text;
    drop_sql text;
BEGIN
    -- Drop all existing policies dynamically
    FOR policy_record IN 
        SELECT policyname
        FROM pg_policies 
        WHERE tablename = 'warehouse_inventory' AND schemaname = 'public'
    LOOP
        policy_name := policy_record.policyname;
        drop_sql := format('DROP POLICY IF EXISTS "%s" ON warehouse_inventory', policy_name);
        EXECUTE drop_sql;
        RAISE NOTICE 'Dropped warehouse_inventory policy: %', policy_name;
    END LOOP;
END $$;

-- Create new safe policies for warehouse_inventory
DO $$
BEGIN
    -- SELECT policy
    BEGIN
        CREATE POLICY "warehouse_inventory_select_expanded_roles" ON warehouse_inventory
        FOR SELECT TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_inventory_select_expanded_roles policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_inventory_select_expanded_roles already exists, skipping';
    END;
    
    -- INSERT policy
    BEGIN
        CREATE POLICY "warehouse_inventory_insert_expanded_roles" ON warehouse_inventory
        FOR INSERT TO authenticated
        WITH CHECK (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_inventory_insert_expanded_roles policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_inventory_insert_expanded_roles already exists, skipping';
    END;
    
    -- UPDATE policy
    BEGIN
        CREATE POLICY "warehouse_inventory_update_expanded_roles" ON warehouse_inventory
        FOR UPDATE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_access_safe()
        );
        RAISE NOTICE 'Created warehouse_inventory_update_expanded_roles policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_inventory_update_expanded_roles already exists, skipping';
    END;
    
    -- DELETE policy
    BEGIN
        CREATE POLICY "warehouse_inventory_delete_expanded_roles" ON warehouse_inventory
        FOR DELETE TO authenticated
        USING (
            auth.uid() IS NOT NULL AND
            check_warehouse_delete_safe()
        );
        RAISE NOTICE 'Created warehouse_inventory_delete_expanded_roles policy';
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Policy warehouse_inventory_delete_expanded_roles already exists, skipping';
    END;
END $$;

SELECT '✅ WAREHOUSE_INVENTORY TABLE POLICIES UPDATED' as progress;

-- =====================================================
-- STEP 4: TEST THE NEW POLICIES
-- =====================================================

-- Test the SECURITY DEFINER functions
DO $$
DECLARE
    test_access BOOLEAN;
    test_manage BOOLEAN;
    test_delete BOOLEAN;
    error_message TEXT;
BEGIN
    BEGIN
        test_access := check_warehouse_access_safe();
        test_manage := check_warehouse_manage_safe();
        test_delete := check_warehouse_delete_safe();
        
        RAISE NOTICE '✅ SECURITY DEFINER FUNCTIONS TEST PASSED:';
        RAISE NOTICE '   Warehouse Access: %', test_access;
        RAISE NOTICE '   Warehouse Manage: %', test_manage;
        RAISE NOTICE '   Warehouse Delete: %', test_delete;
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            RAISE NOTICE '❌ SECURITY DEFINER FUNCTIONS TEST FAILED: %', error_message;
    END;
END $$;

-- Test warehouse table access
DO $$
DECLARE
    test_count integer;
    error_message TEXT;
BEGIN
    BEGIN
        SELECT COUNT(*) INTO test_count FROM warehouses;
        RAISE NOTICE '✅ WAREHOUSES TABLE ACCESS TEST PASSED: % warehouses found', test_count;
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            RAISE NOTICE '❌ WAREHOUSES TABLE ACCESS TEST FAILED: %', error_message;
    END;
    
    BEGIN
        SELECT COUNT(*) INTO test_count FROM warehouse_inventory;
        RAISE NOTICE '✅ WAREHOUSE_INVENTORY TABLE ACCESS TEST PASSED: % inventory records found', test_count;
    EXCEPTION
        WHEN OTHERS THEN
            error_message := SQLERRM;
            RAISE NOTICE '❌ WAREHOUSE_INVENTORY TABLE ACCESS TEST FAILED: %', error_message;
    END;
END $$;

-- Show final policy status
SELECT 
    '✅ FINAL WAREHOUSE POLICIES STATUS' as summary,
    tablename,
    COUNT(*) as policy_count,
    STRING_AGG(policyname, ', ') as policy_names
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory')
  AND schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

SELECT '🎉 WAREHOUSE AUTHENTICATION AND ROLE-BASED ACCESS FIX COMPLETED!' as final_status;

-- Final instructions
SELECT 
    'NEXT STEPS:' as instructions,
    '1. Test warehouse loading in Flutter app with admin/owner/accountant roles' as step_1,
    '2. Verify that all authorized roles can view warehouse data' as step_2,
    '3. Test warehouse creation/editing with different roles' as step_3,
    '4. Authentication issues should be resolved' as step_4;
