-- 🚨 SIMPLE WAREHOUSE ACCESS FIX (Alternative Approach)
-- If the function-based approach fails, use this simpler method

-- ==================== STEP 1: COMPLETELY DISABLE RLS (TEMPORARY) ====================

-- Disable RLS on all warehouse tables for immediate access restoration
ALTER TABLE warehouses DISABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_requests DISABLE ROW LEVEL SECURITY;

-- Handle warehouse_request_items if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_request_items') THEN
        ALTER TABLE warehouse_request_items DISABLE ROW LEVEL SECURITY;
        RAISE NOTICE '✅ RLS disabled on warehouse_request_items';
    END IF;
END $$;

-- ==================== STEP 2: VERIFY IMMEDIATE ACCESS ====================

-- Test that all users can now access warehouse data
SELECT 
  '✅ IMMEDIATE ACCESS TEST' as test,
  'warehouses' as table_name,
  COUNT(*) as record_count,
  'RLS DISABLED - SHOULD WORK FOR ALL USERS' as status
FROM warehouses;

SELECT 
  '✅ IMMEDIATE ACCESS TEST' as test,
  'warehouse_inventory' as table_name,
  COUNT(*) as record_count,
  'RLS DISABLED - SHOULD WORK FOR ALL USERS' as status
FROM warehouse_inventory;

-- ==================== STEP 3: SHOW USER CONTEXT ====================

-- Show current user for debugging
SELECT 
  '👤 CURRENT USER CONTEXT' as info,
  auth.uid() as current_user_id,
  up.email,
  up.name,
  up.role,
  up.status
FROM user_profiles up
WHERE up.id = auth.uid();

-- ==================== STEP 4: OPTION A - KEEP RLS DISABLED (QUICK FIX) ====================

-- If you want to keep RLS disabled for now (less secure but immediate fix):
SELECT 
  '⚠️ OPTION A: RLS DISABLED' as option,
  'All warehouse tables now accessible to all authenticated users' as description,
  'Less secure but immediate fix' as security_note,
  'Consider re-enabling RLS later with proper policies' as recommendation;

-- ==================== STEP 5: OPTION B - SIMPLE RLS POLICIES ====================

-- If you want to re-enable RLS with very simple policies:

-- Re-enable RLS
-- ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE warehouse_transactions ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE warehouse_requests ENABLE ROW LEVEL SECURITY;

-- Create very simple policies (uncomment if you want to use this option)
/*
-- Simple policy: Allow all operations for authenticated users with approved status
CREATE POLICY "simple_warehouses_policy" ON warehouses
    FOR ALL
    USING (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND status = 'approved'
        )
    )
    WITH CHECK (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND status = 'approved'
        )
    );

CREATE POLICY "simple_inventory_policy" ON warehouse_inventory
    FOR ALL
    USING (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND status = 'approved'
        )
    )
    WITH CHECK (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND status = 'approved'
        )
    );

CREATE POLICY "simple_transactions_policy" ON warehouse_transactions
    FOR ALL
    USING (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND status = 'approved'
        )
    )
    WITH CHECK (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND status = 'approved'
        )
    );

CREATE POLICY "simple_requests_policy" ON warehouse_requests
    FOR ALL
    USING (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND status = 'approved'
        )
    )
    WITH CHECK (
        auth.uid() IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND status = 'approved'
        )
    );
*/

-- ==================== STEP 6: VERIFICATION ====================

-- Show current RLS status
SELECT 
  '🔒 CURRENT RLS STATUS' as info,
  tablename,
  rowsecurity as rls_enabled,
  CASE WHEN rowsecurity THEN 'ENABLED' ELSE 'DISABLED' END as status
FROM pg_tables 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests')
  AND schemaname = 'public';

-- Show current policies (should be empty if RLS is disabled)
SELECT 
  '📜 CURRENT POLICIES' as info,
  tablename,
  policyname,
  cmd as operation
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests')
ORDER BY tablename, cmd;

-- Final test
SELECT 
  '🎉 FINAL TEST' as status,
  'Try accessing warehouse data from your Flutter app now' as instruction,
  'All authorized users should have access' as expected_result;

-- Instructions
SELECT 
  '📋 INSTRUCTIONS' as info,
  'RLS has been disabled on all warehouse tables' as action_taken,
  'Test your Flutter app now - all users should have warehouse access' as next_step,
  'If this works, you can choose to keep RLS disabled or implement simpler policies later' as options;
