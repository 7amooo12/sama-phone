-- اختبار تشخيص سياسات RLS المصححة
-- Test corrected RLS diagnostics

-- Test 1: Check if tables exist
SELECT 'Checking if warehouse dispatch tables exist...' as test_status;

SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_name IN ('warehouse_requests', 'warehouse_request_items')
AND table_schema = 'public';

-- Test 2: Check RLS status using corrected query
SELECT 'Checking RLS status with corrected query...' as test_status;

SELECT 
    n.nspname as schemaname,
    c.relname as tablename,
    c.relrowsecurity as rls_enabled,
    c.relforcerowsecurity as rls_forced,
    CASE 
        WHEN c.relrowsecurity THEN 'RLS Enabled'
        ELSE 'RLS Disabled'
    END as rls_status
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relname IN ('warehouse_requests', 'warehouse_request_items')
AND n.nspname = 'public'
AND c.relkind = 'r';

-- Test 3: Check existing policies
SELECT 'Checking existing RLS policies...' as test_status;

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as operation,
    CASE 
        WHEN cmd = 'ALL' THEN 'All Operations'
        WHEN cmd = 'SELECT' THEN 'Read'
        WHEN cmd = 'INSERT' THEN 'Create'
        WHEN cmd = 'UPDATE' THEN 'Update'
        WHEN cmd = 'DELETE' THEN 'Delete'
        ELSE cmd
    END as operation_type
FROM pg_policies 
WHERE tablename IN ('warehouse_requests', 'warehouse_request_items')
AND schemaname = 'public'
ORDER BY tablename, cmd;

-- Test 4: Check table permissions
SELECT 'Checking table permissions...' as test_status;

SELECT 
    grantee,
    table_name,
    privilege_type,
    is_grantable
FROM information_schema.table_privileges 
WHERE table_name IN ('warehouse_requests', 'warehouse_request_items')
AND table_schema = 'public'
ORDER BY table_name, privilege_type;

-- Test 5: Check current user context
SELECT 'Checking current user context...' as test_status;

SELECT 
    'Current User Info' as info_type,
    current_user as current_user,
    session_user as session_user,
    current_setting('role') as current_role;

-- Test 6: Check if auth functions are available
SELECT 'Checking auth functions availability...' as test_status;

SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_schema = 'auth'
AND routine_name IN ('uid', 'email')
ORDER BY routine_name;

-- Test 7: Test auth.uid() function if available
DO $$
BEGIN
    BEGIN
        RAISE NOTICE 'Testing auth.uid(): %', auth.uid();
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'auth.uid() not available or error: %', SQLERRM;
    END;
END $$;

-- Test 8: Check user_profiles table structure
SELECT 'Checking user_profiles table structure...' as test_status;

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_profiles'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Test 9: Sample user_profiles data (if accessible)
SELECT 'Checking sample user_profiles data...' as test_status;

DO $$
BEGIN
    BEGIN
        PERFORM COUNT(*) FROM user_profiles LIMIT 1;
        RAISE NOTICE 'user_profiles table is accessible';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Cannot access user_profiles table: %', SQLERRM;
    END;
END $$;

-- Test 10: Check foreign key constraints
SELECT 'Checking foreign key constraints...' as test_status;

SELECT 
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_name IN ('warehouse_requests', 'warehouse_request_items')
AND tc.table_schema = 'public';

SELECT 'RLS diagnostics test completed successfully!' as final_status;
