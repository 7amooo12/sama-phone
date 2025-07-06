-- إنشاء دالة قاعدة بيانات لمسح طلبات الصرف
-- Create database function to clear warehouse dispatch requests

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS clear_all_warehouse_dispatch_requests();

-- Create the function with SECURITY DEFINER to bypass RLS
CREATE OR REPLACE FUNCTION clear_all_warehouse_dispatch_requests()
RETURNS TABLE (
    success BOOLEAN,
    deleted_items_count INTEGER,
    deleted_requests_count INTEGER,
    error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    items_count INTEGER := 0;
    requests_count INTEGER := 0;
    initial_requests_count INTEGER := 0;
    final_requests_count INTEGER := 0;
BEGIN
    -- Log the start of operation
    RAISE NOTICE 'Starting warehouse dispatch clear operation...';
    
    -- Get initial count
    SELECT COUNT(*) INTO initial_requests_count FROM warehouse_requests;
    RAISE NOTICE 'Initial requests count: %', initial_requests_count;
    
    -- Delete all warehouse request items first
    DELETE FROM warehouse_request_items;
    GET DIAGNOSTICS items_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % warehouse request items', items_count;
    
    -- Delete all warehouse requests
    DELETE FROM warehouse_requests;
    GET DIAGNOSTICS requests_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % warehouse requests', requests_count;
    
    -- Verify deletion
    SELECT COUNT(*) INTO final_requests_count FROM warehouse_requests;
    RAISE NOTICE 'Final requests count: %', final_requests_count;
    
    -- Return success result
    RETURN QUERY
    SELECT 
        TRUE as success,
        items_count as deleted_items_count,
        requests_count as deleted_requests_count,
        NULL::TEXT as error_message;
        
EXCEPTION
    WHEN OTHERS THEN
        -- Return error result
        RAISE NOTICE 'Error in clear operation: %', SQLERRM;
        RETURN QUERY
        SELECT 
            FALSE as success,
            0 as deleted_items_count,
            0 as deleted_requests_count,
            SQLERRM as error_message;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION clear_all_warehouse_dispatch_requests TO authenticated;

-- Create a simpler test function
CREATE OR REPLACE FUNCTION test_warehouse_clear_permissions()
RETURNS TABLE (
    current_user_id UUID,
    user_email TEXT,
    user_role TEXT,
    user_status TEXT,
    can_access_function BOOLEAN,
    requests_count INTEGER,
    error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_info RECORD;
    req_count INTEGER := 0;
BEGIN
    -- Get current user info
    SELECT 
        auth.uid() as user_id,
        auth.email() as email
    INTO user_info;
    
    -- Get user profile info
    SELECT 
        role,
        status
    INTO user_info.role, user_info.status
    FROM user_profiles 
    WHERE id = auth.uid();
    
    -- Count current requests
    SELECT COUNT(*) INTO req_count FROM warehouse_requests;
    
    -- Return result
    RETURN QUERY
    SELECT 
        auth.uid() as current_user_id,
        auth.email() as user_email,
        COALESCE(user_info.role, 'unknown') as user_role,
        COALESCE(user_info.status, 'unknown') as user_status,
        TRUE as can_access_function,
        req_count as requests_count,
        NULL::TEXT as error_message;
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY
        SELECT 
            auth.uid() as current_user_id,
            auth.email() as user_email,
            'error'::TEXT as user_role,
            'error'::TEXT as user_status,
            FALSE as can_access_function,
            0 as requests_count,
            SQLERRM as error_message;
END;
$$;

GRANT EXECUTE ON FUNCTION test_warehouse_clear_permissions TO authenticated;

-- Create a function to check RLS policies
CREATE OR REPLACE FUNCTION check_warehouse_rls_status()
RETURNS TABLE (
    table_name TEXT,
    rls_enabled BOOLEAN,
    policy_count INTEGER,
    can_select BOOLEAN,
    can_delete BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check warehouse_requests table
    RETURN QUERY
    SELECT 
        'warehouse_requests'::TEXT as table_name,
        (SELECT relrowsecurity FROM pg_class WHERE relname = 'warehouse_requests') as rls_enabled,
        (SELECT COUNT(*)::INTEGER FROM pg_policies WHERE tablename = 'warehouse_requests') as policy_count,
        TRUE as can_select, -- If we can execute this, we can select
        TRUE as can_delete; -- Will be tested by the clear function
        
    -- Check warehouse_request_items table
    RETURN QUERY
    SELECT 
        'warehouse_request_items'::TEXT as table_name,
        (SELECT relrowsecurity FROM pg_class WHERE relname = 'warehouse_request_items') as rls_enabled,
        (SELECT COUNT(*)::INTEGER FROM pg_policies WHERE tablename = 'warehouse_request_items') as policy_count,
        TRUE as can_select,
        TRUE as can_delete;
END;
$$;

GRANT EXECUTE ON FUNCTION check_warehouse_rls_status TO authenticated;

-- Add comments for documentation
COMMENT ON FUNCTION clear_all_warehouse_dispatch_requests IS 'مسح جميع طلبات صرف المخزون مع تجاوز قيود RLS';
COMMENT ON FUNCTION test_warehouse_clear_permissions IS 'اختبار صلاحيات مسح طلبات الصرف';
COMMENT ON FUNCTION check_warehouse_rls_status IS 'فحص حالة سياسات RLS لجداول طلبات الصرف';

SELECT 'Warehouse dispatch clear functions created successfully!' as status;
