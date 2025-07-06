-- إصلاح مشكلة مزامنة البيانات في نظام صرف المخازن
-- Fix warehouse dispatch data synchronization issue between Accountant and Warehouse Manager dashboards

-- ==================== STEP 1: DIAGNOSE THE ISSUE ====================

-- Check current RLS policies on warehouse_request_items
SELECT 
    'Current RLS policies on warehouse_request_items:' as info,
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'warehouse_request_items'
ORDER BY policyname;

-- Check user roles format in the database
SELECT 
    'User roles in database:' as info,
    role,
    COUNT(*) as user_count
FROM user_profiles 
GROUP BY role
ORDER BY role;

-- Test current user access
DO $$
DECLARE
    current_user_id UUID;
    user_role TEXT;
    user_status TEXT;
    test_request_count INTEGER;
    test_items_count INTEGER;
BEGIN
    -- Get current user info
    SELECT auth.uid() INTO current_user_id;
    
    IF current_user_id IS NOT NULL THEN
        SELECT role, status INTO user_role, user_status
        FROM user_profiles 
        WHERE id = current_user_id;
        
        RAISE NOTICE '👤 Current user: % (role: %, status: %)', current_user_id, user_role, user_status;
        
        -- Test access to warehouse_requests
        SELECT COUNT(*) INTO test_request_count
        FROM warehouse_requests 
        LIMIT 5;
        
        RAISE NOTICE '📋 Can access % warehouse_requests', test_request_count;
        
        -- Test access to warehouse_request_items
        SELECT COUNT(*) INTO test_items_count
        FROM warehouse_request_items 
        LIMIT 5;
        
        RAISE NOTICE '📦 Can access % warehouse_request_items', test_items_count;
        
    ELSE
        RAISE NOTICE '❌ No authenticated user found';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error testing access: %', SQLERRM;
END $$;

-- ==================== STEP 2: FIX THE RLS POLICIES ====================

-- Drop existing problematic policies
DROP POLICY IF EXISTS "عناصر طلبات السحب تتبع نفس سياسات الطلبات" ON warehouse_request_items;
DROP POLICY IF EXISTS "warehouse_request_items_policy" ON warehouse_request_items;
DROP POLICY IF EXISTS "warehouse_request_items_select_policy" ON warehouse_request_items;
DROP POLICY IF EXISTS "warehouse_request_items_insert_policy" ON warehouse_request_items;
DROP POLICY IF EXISTS "warehouse_request_items_update_policy" ON warehouse_request_items;
DROP POLICY IF EXISTS "warehouse_request_items_delete_policy" ON warehouse_request_items;

-- Create comprehensive and consistent policies for warehouse_request_items
-- These policies should match exactly with warehouse_requests policies

-- SELECT: Allow all authorized roles to view request items
CREATE POLICY "warehouse_request_items_select_comprehensive" ON warehouse_request_items
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'warehouse_manager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- INSERT: Allow authorized roles to create request items
CREATE POLICY "warehouse_request_items_insert_comprehensive" ON warehouse_request_items
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'warehouse_manager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- UPDATE: Allow authorized roles to update request items
CREATE POLICY "warehouse_request_items_update_comprehensive" ON warehouse_request_items
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'warehouse_manager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- DELETE: Allow admin and owner to delete request items
CREATE POLICY "warehouse_request_items_delete_comprehensive" ON warehouse_request_items
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== STEP 3: ENSURE WAREHOUSE_REQUESTS POLICIES ARE CONSISTENT ====================

-- Drop and recreate warehouse_requests policies to ensure consistency
DROP POLICY IF EXISTS "warehouse_requests_select_admin_accountant" ON warehouse_requests;
DROP POLICY IF EXISTS "warehouse_requests_select_policy" ON warehouse_requests;
DROP POLICY IF EXISTS "secure_requests_select" ON warehouse_requests;

CREATE POLICY "warehouse_requests_select_comprehensive" ON warehouse_requests
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL 
    AND EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'accountant', 'warehouseManager', 'warehouse_manager', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

-- ==================== STEP 4: VERIFY THE FIX ====================

-- Test the fix with current user
DO $$
DECLARE
    current_user_id UUID;
    user_role TEXT;
    user_status TEXT;
    test_request_count INTEGER;
    test_items_count INTEGER;
    sample_request_id UUID;
    sample_items_count INTEGER;
BEGIN
    -- Get current user info
    SELECT auth.uid() INTO current_user_id;
    
    IF current_user_id IS NOT NULL THEN
        SELECT role, status INTO user_role, user_status
        FROM user_profiles 
        WHERE id = current_user_id;
        
        RAISE NOTICE '✅ Testing with user: % (role: %, status: %)', current_user_id, user_role, user_status;
        
        -- Test access to warehouse_requests
        SELECT COUNT(*) INTO test_request_count
        FROM warehouse_requests;
        
        RAISE NOTICE '✅ Can access % warehouse_requests', test_request_count;
        
        -- Test access to warehouse_request_items
        SELECT COUNT(*) INTO test_items_count
        FROM warehouse_request_items;
        
        RAISE NOTICE '✅ Can access % warehouse_request_items', test_items_count;
        
        -- Test specific request with items
        SELECT id INTO sample_request_id
        FROM warehouse_requests 
        WHERE id IN (
            SELECT DISTINCT request_id 
            FROM warehouse_request_items 
            LIMIT 1
        )
        LIMIT 1;
        
        IF sample_request_id IS NOT NULL THEN
            SELECT COUNT(*) INTO sample_items_count
            FROM warehouse_request_items 
            WHERE request_id = sample_request_id;
            
            RAISE NOTICE '✅ Sample request % has % items', sample_request_id, sample_items_count;
        ELSE
            RAISE NOTICE '⚠️ No requests with items found for testing';
        END IF;
        
    ELSE
        RAISE NOTICE '❌ No authenticated user found for testing';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error during verification: %', SQLERRM;
END $$;

-- ==================== STEP 5: CREATE A TEST QUERY ====================

-- Test the exact query used by the application
DO $$
DECLARE
    test_result RECORD;
    items_count INTEGER;
BEGIN
    RAISE NOTICE '🧪 Testing application query pattern...';
    
    FOR test_result IN 
        SELECT 
            wr.id,
            wr.request_number,
            wr.status,
            wr.reason,
            (
                SELECT COUNT(*) 
                FROM warehouse_request_items wri 
                WHERE wri.request_id = wr.id
            ) as items_count
        FROM warehouse_requests wr
        ORDER BY wr.requested_at DESC
        LIMIT 3
    LOOP
        RAISE NOTICE '📋 Request %: % (status: %, items: %)', 
            test_result.request_number, 
            test_result.reason, 
            test_result.status,
            test_result.items_count;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error testing application query: %', SQLERRM;
END $$;

-- ==================== STEP 6: SUMMARY ====================

SELECT 
    'Warehouse dispatch data sync fix completed!' as summary,
    'The RLS policies have been updated to ensure consistent access for both Accountant and Warehouse Manager roles.' as description,
    'Both warehouseManager and warehouse_manager role formats are now supported.' as compatibility_note,
    'Test the fix by accessing the dispatch tab from both dashboards.' as next_steps;
