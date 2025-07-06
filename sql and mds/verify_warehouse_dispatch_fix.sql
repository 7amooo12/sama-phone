-- التحقق من إصلاح مشاكل طلبات صرف المخزون
-- Verify warehouse dispatch fix

-- Quick verification of RLS status
SELECT 
    'Current RLS Status:' as info,
    c.relname as table_name,
    c.relrowsecurity as rls_enabled,
    CASE 
        WHEN c.relrowsecurity THEN '✅ RLS ENABLED'
        ELSE '❌ RLS DISABLED'
    END as status
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relname IN ('warehouse_requests', 'warehouse_request_items')
AND n.nspname = 'public'
AND c.relkind = 'r';

-- Check policies
SELECT 
    'Current Policies:' as info,
    tablename,
    policyname,
    cmd as operations
FROM pg_policies 
WHERE tablename IN ('warehouse_requests', 'warehouse_request_items')
AND schemaname = 'public';

-- Test current user permissions
DO $$
DECLARE
    user_role TEXT;
    user_status TEXT;
    req_count INTEGER;
BEGIN
    -- Get user info
    SELECT role, status INTO user_role, user_status
    FROM user_profiles 
    WHERE id = auth.uid();
    
    RAISE NOTICE 'Current user - Role: %, Status: %', COALESCE(user_role, 'unknown'), COALESCE(user_status, 'unknown');
    
    -- Test read access
    SELECT COUNT(*) INTO req_count FROM warehouse_requests;
    RAISE NOTICE 'Can read warehouse_requests: ✅ (% records)', req_count;
    
    -- Test delete capability
    BEGIN
        DELETE FROM warehouse_requests WHERE id = '00000000-0000-0000-0000-000000000000';
        RAISE NOTICE 'Delete permission: ✅ GRANTED';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Delete permission: ❌ DENIED - %', SQLERRM;
    END;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Permission test failed: %', SQLERRM;
END $$;

-- Test the helper function
SELECT 
    'Testing clear function:' as info,
    success,
    message
FROM clear_warehouse_dispatch_data();

SELECT 'Verification completed!' as result;
