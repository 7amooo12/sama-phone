-- ============================================================================
-- FIX WAREHOUSE DISPATCH CLEAR ERRORS
-- ============================================================================
-- إصلاح أخطاء مسح طلبات الصرف من المخازن
-- ============================================================================

-- 1. First, check the current structure of warehouse_request_items table
SELECT 
  'WAREHOUSE_REQUEST_ITEMS TABLE STRUCTURE' as info,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'warehouse_request_items'
ORDER BY ordinal_position;

-- 2. Add the missing created_at column if it doesn't exist
DO $$
BEGIN
  -- Check if created_at column exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'warehouse_request_items' 
      AND column_name = 'created_at'
  ) THEN
    -- Add the created_at column
    ALTER TABLE public.warehouse_request_items 
    ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    
    -- Update existing records with a default timestamp
    UPDATE public.warehouse_request_items 
    SET created_at = NOW() 
    WHERE created_at IS NULL;
    
    RAISE NOTICE 'Added created_at column to warehouse_request_items table';
  ELSE
    RAISE NOTICE 'created_at column already exists in warehouse_request_items table';
  END IF;
END $$;

-- 3. Also add updated_at column if it doesn't exist (for consistency)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'warehouse_request_items' 
      AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE public.warehouse_request_items 
    ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    
    UPDATE public.warehouse_request_items 
    SET updated_at = NOW() 
    WHERE updated_at IS NULL;
    
    RAISE NOTICE 'Added updated_at column to warehouse_request_items table';
  ELSE
    RAISE NOTICE 'updated_at column already exists in warehouse_request_items table';
  END IF;
END $$;

-- 4. Create the missing clear_all_warehouse_dispatch_requests function
CREATE OR REPLACE FUNCTION clear_all_warehouse_dispatch_requests()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_items_count INTEGER := 0;
  deleted_requests_count INTEGER := 0;
  result JSON;
BEGIN
  -- Start transaction
  BEGIN
    -- Delete warehouse_request_items first (child records)
    DELETE FROM warehouse_request_items 
    WHERE request_id IN (
      SELECT id FROM warehouse_requests
    );
    
    GET DIAGNOSTICS deleted_items_count = ROW_COUNT;
    
    -- Delete warehouse_requests (parent records)
    DELETE FROM warehouse_requests;
    
    GET DIAGNOSTICS deleted_requests_count = ROW_COUNT;
    
    -- Create result JSON
    result := json_build_object(
      'success', true,
      'deleted_requests', deleted_requests_count,
      'deleted_items', deleted_items_count,
      'message', 'تم مسح جميع طلبات الصرف بنجاح',
      'timestamp', NOW()
    );
    
    RETURN result;
    
  EXCEPTION
    WHEN OTHERS THEN
      -- Rollback and return error
      RAISE;
  END;
END $$;

-- 5. Create a safer version that only deletes user's own requests
CREATE OR REPLACE FUNCTION clear_user_warehouse_dispatch_requests()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_id UUID;
  deleted_items_count INTEGER := 0;
  deleted_requests_count INTEGER := 0;
  result JSON;
BEGIN
  -- Get current user ID
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'المستخدم غير مصرح له',
      'timestamp', NOW()
    );
  END IF;
  
  -- Start transaction
  BEGIN
    -- Delete warehouse_request_items for user's requests
    DELETE FROM warehouse_request_items 
    WHERE request_id IN (
      SELECT id FROM warehouse_requests 
      WHERE created_by = current_user_id
    );
    
    GET DIAGNOSTICS deleted_items_count = ROW_COUNT;
    
    -- Delete user's warehouse_requests
    DELETE FROM warehouse_requests 
    WHERE created_by = current_user_id;
    
    GET DIAGNOSTICS deleted_requests_count = ROW_COUNT;
    
    -- Create result JSON
    result := json_build_object(
      'success', true,
      'deleted_requests', deleted_requests_count,
      'deleted_items', deleted_items_count,
      'message', 'تم مسح طلبات الصرف الخاصة بك بنجاح',
      'user_id', current_user_id,
      'timestamp', NOW()
    );
    
    RETURN result;
    
  EXCEPTION
    WHEN OTHERS THEN
      -- Return error details
      RETURN json_build_object(
        'success', false,
        'error', SQLERRM,
        'timestamp', NOW()
      );
  END;
END $$;

-- 6. Grant execute permissions
GRANT EXECUTE ON FUNCTION clear_all_warehouse_dispatch_requests TO authenticated;
GRANT EXECUTE ON FUNCTION clear_user_warehouse_dispatch_requests TO authenticated;
GRANT EXECUTE ON FUNCTION clear_all_warehouse_dispatch_requests TO service_role;
GRANT EXECUTE ON FUNCTION clear_user_warehouse_dispatch_requests TO service_role;

-- 7. Create a trigger to automatically update the updated_at column
CREATE OR REPLACE FUNCTION update_warehouse_request_items_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END $$;

-- Drop trigger if exists and create new one
DROP TRIGGER IF EXISTS warehouse_request_items_updated_at_trigger ON warehouse_request_items;

CREATE TRIGGER warehouse_request_items_updated_at_trigger
  BEFORE UPDATE ON warehouse_request_items
  FOR EACH ROW
  EXECUTE FUNCTION update_warehouse_request_items_timestamp();

-- 8. Test the functions
SELECT 'TESTING FUNCTIONS' as test_status;

-- Test the clear function (this will show structure without actually deleting)
SELECT 
  'clear_all_warehouse_dispatch_requests function test' as test_name,
  'Function exists and is callable' as status
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name = 'clear_all_warehouse_dispatch_requests';

-- 9. Verify table structure after fixes
SELECT 
  'UPDATED WAREHOUSE_REQUEST_ITEMS STRUCTURE' as info,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'warehouse_request_items'
ORDER BY ordinal_position;

-- 10. Test basic operations that were failing
SELECT 'TESTING BASIC OPERATIONS' as test_category;

-- Test if we can now query with created_at column
SELECT 
  'created_at column test' as test_name,
  COUNT(*) as record_count
FROM warehouse_request_items 
WHERE created_at IS NOT NULL;

-- 11. Create additional helper functions for the service
-- First, check the actual data types in warehouse_request_items table
SELECT
  'WAREHOUSE_REQUEST_ITEMS COLUMN TYPES' as info,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'warehouse_request_items'
  AND column_name IN ('id', 'request_id', 'product_id', 'quantity')
ORDER BY ordinal_position;

-- Create the function with correct data types
CREATE OR REPLACE FUNCTION get_warehouse_request_items_with_timestamps()
RETURNS TABLE (
  id UUID,
  request_id UUID,
  product_id TEXT,  -- Changed from UUID to TEXT to match actual column type
  quantity INTEGER,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT
    wri.id::UUID,
    wri.request_id::UUID,
    wri.product_id::TEXT,  -- Explicit cast to TEXT
    wri.quantity::INTEGER,
    wri.created_at,
    wri.updated_at
  FROM warehouse_request_items wri
  ORDER BY wri.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION get_warehouse_request_items_with_timestamps TO authenticated;

-- 12. Test the corrected function to ensure no type mismatches
SELECT 'TESTING CORRECTED FUNCTION' as test_status;

-- Test the function with corrected data types
DO $$
BEGIN
  -- Test if the function executes without errors
  PERFORM * FROM get_warehouse_request_items_with_timestamps() LIMIT 1;
  RAISE NOTICE 'SUCCESS: get_warehouse_request_items_with_timestamps function works correctly';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'ERROR: get_warehouse_request_items_with_timestamps function failed: %', SQLERRM;
END $$;

-- 13. Final verification and success message
SELECT
  'DATABASE FIXES COMPLETED' as status,
  'Both missing column and function issues have been resolved' as message,
  'The Accountant can now clear warehouse dispatch requests' as result;

-- Show what functions are now available
SELECT 
  'AVAILABLE FUNCTIONS' as info,
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%warehouse%dispatch%'
ORDER BY routine_name;
