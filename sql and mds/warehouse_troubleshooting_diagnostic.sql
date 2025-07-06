-- 🔍 COMPREHENSIVE WAREHOUSE TROUBLESHOOTING DIAGNOSTIC
-- This script will help identify exactly where the warehouse data access is failing

-- =====================================================
-- STEP 1: VERIFY SQL SCRIPT RESULTS
-- =====================================================

SELECT '🔍 === VERIFYING SQL SCRIPT RESULTS ===' as diagnostic_step;

-- Check if our new policies were created
SELECT 
  '📋 NEW POLICIES STATUS' as check_type,
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN policyname LIKE '%2025%' THEN '✅ NEW POLICY CREATED'
    ELSE '⚠️ OLD/UNKNOWN POLICY'
  END as policy_status
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory')
ORDER BY tablename, cmd;

-- Verify warehouse data is accessible
SELECT 
  '🏢 WAREHOUSE DATA VERIFICATION' as check_type,
  COUNT(*) as total_warehouses,
  COUNT(*) FILTER (WHERE is_active = true) as active_warehouses,
  STRING_AGG(name, ', ' ORDER BY name) as warehouse_names
FROM warehouses;

-- Verify inventory data is accessible
SELECT 
  '📦 INVENTORY DATA VERIFICATION' as check_type,
  COUNT(*) as total_inventory_items,
  COUNT(DISTINCT warehouse_id) as warehouses_with_inventory,
  SUM(quantity) as total_quantity,
  STRING_AGG(DISTINCT w.name, ', ' ORDER BY w.name) as warehouses_with_stock
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id;

-- Check user profiles status
SELECT 
  '👥 USER PROFILES STATUS' as check_type,
  role,
  status,
  COUNT(*) as user_count,
  STRING_AGG(email, ', ') as sample_emails
FROM user_profiles 
WHERE role IN ('admin', 'owner', 'accountant', 'warehouseManager')
GROUP BY role, status
ORDER BY role, status;

-- =====================================================
-- STEP 2: TEST SPECIFIC USER ACCESS
-- =====================================================

SELECT '🧪 === TESTING SPECIFIC USER ACCESS ===' as test_step;

-- Test access for each role type
DO $$
DECLARE
    test_user RECORD;
    warehouse_count INTEGER;
    inventory_count INTEGER;
BEGIN
    -- Test each user role
    FOR test_user IN 
        SELECT DISTINCT role 
        FROM user_profiles 
        WHERE role IN ('admin', 'owner', 'accountant', 'warehouseManager')
          AND status = 'approved'
    LOOP
        -- Get a sample user of this role
        DECLARE
            sample_user_id UUID;
        BEGIN
            SELECT id INTO sample_user_id 
            FROM user_profiles 
            WHERE role = test_user.role 
              AND status = 'approved' 
            LIMIT 1;
            
            -- Test warehouse access for this user
            EXECUTE format('SET LOCAL "request.jwt.claims" = ''{"sub": "%s"}''', sample_user_id);
            
            SELECT COUNT(*) INTO warehouse_count FROM warehouses;
            SELECT COUNT(*) INTO inventory_count FROM warehouse_inventory;
            
            RAISE NOTICE '🔍 Role: % | User ID: % | Warehouses: % | Inventory: %', 
                test_user.role, sample_user_id, warehouse_count, inventory_count;
                
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ Error testing role %: %', test_user.role, SQLERRM;
        END;
    END LOOP;
END $$;

-- =====================================================
-- STEP 3: CREATE FLUTTER DEBUGGING FUNCTION
-- =====================================================

-- Create a function to simulate Flutter app calls
CREATE OR REPLACE FUNCTION test_flutter_warehouse_access(
    user_email TEXT,
    test_type TEXT DEFAULT 'warehouses'
)
RETURNS TABLE (
    success BOOLEAN,
    data_count INTEGER,
    error_message TEXT,
    user_info JSONB,
    sample_data JSONB
) AS $$
DECLARE
    target_user_id UUID;
    user_role TEXT;
    user_status TEXT;
    result_count INTEGER := 0;
    sample_record JSONB;
BEGIN
    -- Get user info
    SELECT up.id, up.role, up.status 
    INTO target_user_id, user_role, user_status
    FROM user_profiles up
    WHERE up.email = user_email;
    
    -- Check if user exists
    IF target_user_id IS NULL THEN
        RETURN QUERY SELECT 
            false, 
            0, 
            'User not found: ' || user_email,
            NULL::JSONB,
            NULL::JSONB;
        RETURN;
    END IF;
    
    -- Set user context (simulate Flutter authentication)
    PERFORM set_config('request.jwt.claims', 
        json_build_object('sub', target_user_id)::text, true);
    
    -- Test based on type
    IF test_type = 'warehouses' THEN
        -- Test warehouse access
        BEGIN
            SELECT COUNT(*) INTO result_count FROM warehouses;
            
            -- Get sample warehouse data
            SELECT to_jsonb(w.*) INTO sample_record 
            FROM warehouses w 
            LIMIT 1;
            
            RETURN QUERY SELECT 
                true,
                result_count,
                'Success'::TEXT,
                jsonb_build_object(
                    'user_id', target_user_id,
                    'email', user_email,
                    'role', user_role,
                    'status', user_status
                ),
                sample_record;
                
        EXCEPTION WHEN OTHERS THEN
            RETURN QUERY SELECT 
                false,
                0,
                'Error accessing warehouses: ' || SQLERRM,
                jsonb_build_object(
                    'user_id', target_user_id,
                    'email', user_email,
                    'role', user_role,
                    'status', user_status
                ),
                NULL::JSONB;
        END;
        
    ELSIF test_type = 'inventory' THEN
        -- Test inventory access
        BEGIN
            SELECT COUNT(*) INTO result_count FROM warehouse_inventory;
            
            -- Get sample inventory data
            SELECT to_jsonb(wi.*) INTO sample_record 
            FROM warehouse_inventory wi 
            LIMIT 1;
            
            RETURN QUERY SELECT 
                true,
                result_count,
                'Success'::TEXT,
                jsonb_build_object(
                    'user_id', target_user_id,
                    'email', user_email,
                    'role', user_role,
                    'status', user_status
                ),
                sample_record;
                
        EXCEPTION WHEN OTHERS THEN
            RETURN QUERY SELECT 
                false,
                0,
                'Error accessing inventory: ' || SQLERRM,
                jsonb_build_object(
                    'user_id', target_user_id,
                    'email', user_email,
                    'role', user_role,
                    'status', user_status
                ),
                NULL::JSONB;
        END;
    END IF;
    
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant access to the function
GRANT EXECUTE ON FUNCTION test_flutter_warehouse_access(TEXT, TEXT) TO authenticated;

-- =====================================================
-- STEP 4: TEST SAMPLE USERS
-- =====================================================

SELECT '🧪 === TESTING SAMPLE USERS ===' as user_test_step;

-- Test warehouse access for sample users of each role
SELECT 
    '🏢 WAREHOUSE ACCESS BY ROLE' as test_type,
    email,
    role,
    (test_flutter_warehouse_access(email, 'warehouses')).*
FROM user_profiles 
WHERE role IN ('admin', 'owner', 'accountant', 'warehouseManager')
  AND status = 'approved'
ORDER BY role
LIMIT 4; -- One user per role

-- Test inventory access for sample users
SELECT 
    '📦 INVENTORY ACCESS BY ROLE' as test_type,
    email,
    role,
    (test_flutter_warehouse_access(email, 'inventory')).*
FROM user_profiles 
WHERE role IN ('admin', 'owner', 'accountant', 'warehouseManager')
  AND status = 'approved'
ORDER BY role
LIMIT 4; -- One user per role

SELECT '✅ DIAGNOSTIC COMPLETED - CHECK RESULTS ABOVE' as completion_message;
