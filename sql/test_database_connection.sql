-- Test database connection and basic functionality
-- This script verifies that we can connect to the database and run basic queries

SELECT 'Testing database connection...' as status;

-- Test 1: Check current user and authentication
SELECT 
    'Current database user: ' || current_user as user_info,
    'Current timestamp: ' || NOW() as timestamp_info;

-- Test 2: Check if auth schema exists
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'auth') 
        THEN 'auth schema exists' 
        ELSE 'auth schema missing' 
    END as auth_schema_status;

-- Test 3: Check if user_profiles table exists
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles' AND table_schema = 'public') 
        THEN 'user_profiles table exists' 
        ELSE 'user_profiles table missing' 
    END as user_profiles_status;

-- Test 4: Check if warehouse tables exist
SELECT 
    table_name,
    'exists' as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('warehouses', 'warehouse_requests', 'warehouse_request_items', 'warehouse_inventory', 'warehouse_transactions')
ORDER BY table_name;

-- Test 5: Check current RLS policies on problematic tables
SELECT 
    'Current RLS policies:' as info,
    tablename,
    policyname,
    cmd as operation
FROM pg_policies 
WHERE tablename IN ('user_profiles', 'warehouse_requests', 'warehouse_request_items')
  AND schemaname = 'public'
ORDER BY tablename, cmd;

-- Test 6: Check for existing SECURITY DEFINER functions
SELECT 
    'Existing SECURITY DEFINER functions:' as info,
    routine_name,
    security_type
FROM information_schema.routines 
WHERE routine_name LIKE '%_safe'
  AND routine_schema = 'public'
ORDER BY routine_name;

SELECT 'Database connection test completed successfully!' as final_status;
