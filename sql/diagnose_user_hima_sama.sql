-- 🔍 COMPREHENSIVE DIAGNOSIS FOR USER hima@sama.com
-- Diagnose and fix database access issues after table recreation incident

-- ==================== STEP 1: VERIFY USER EXISTS IN AUTH ====================

-- Check if user exists in auth.users
SELECT 
  '🔍 AUTH USER CHECK' as check_type,
  id,
  email,
  email_confirmed,
  created_at,
  updated_at,
  last_sign_in_at,
  raw_user_meta_data
FROM auth.users 
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15'
   OR email = 'hima@sama.com';

-- ==================== STEP 2: CHECK USER PROFILE ====================

-- Check if user profile exists and is properly configured
SELECT 
  '👤 USER PROFILE CHECK' as check_type,
  id,
  email,
  name,
  phone_number,
  role,
  status,
  created_at,
  updated_at,
  profile_image
FROM user_profiles 
WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15'
   OR email = 'hima@sama.com';

-- ==================== STEP 3: CHECK TABLE ACCESS PERMISSIONS ====================

-- Test access to critical tables
DO $$
DECLARE
    test_result TEXT;
    error_msg TEXT;
BEGIN
    -- Test warehouses table access
    BEGIN
        PERFORM COUNT(*) FROM warehouses;
        RAISE NOTICE '✅ warehouses table: ACCESSIBLE';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ warehouses table: ERROR - %', SQLERRM;
    END;
    
    -- Test warehouse_inventory table access
    BEGIN
        PERFORM COUNT(*) FROM warehouse_inventory;
        RAISE NOTICE '✅ warehouse_inventory table: ACCESSIBLE';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ warehouse_inventory table: ERROR - %', SQLERRM;
    END;
    
    -- Test warehouse_requests table access
    BEGIN
        PERFORM COUNT(*) FROM warehouse_requests;
        RAISE NOTICE '✅ warehouse_requests table: ACCESSIBLE';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ warehouse_requests table: ERROR - %', SQLERRM;
    END;
    
    -- Test warehouse_transactions table access
    BEGIN
        PERFORM COUNT(*) FROM warehouse_transactions;
        RAISE NOTICE '✅ warehouse_transactions table: ACCESSIBLE';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ warehouse_transactions table: ERROR - %', SQLERRM;
    END;
    
    -- Test products table access
    BEGIN
        PERFORM COUNT(*) FROM products;
        RAISE NOTICE '✅ products table: ACCESSIBLE';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ products table: ERROR - %', SQLERRM;
    END;
END $$;

-- ==================== STEP 4: CHECK RLS POLICIES ====================

-- Check RLS policies on user_profiles
SELECT 
  '🔒 USER_PROFILES RLS POLICIES' as check_type,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- Check RLS policies on warehouses
SELECT 
  '🏢 WAREHOUSES RLS POLICIES' as check_type,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'warehouses'
ORDER BY policyname;

-- Check RLS policies on warehouse_inventory
SELECT 
  '📦 WAREHOUSE_INVENTORY RLS POLICIES' as check_type,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'warehouse_inventory'
ORDER BY policyname;

-- ==================== STEP 5: CHECK DATABASE FUNCTIONS ====================

-- List all custom functions that might be missing
SELECT 
  '⚙️ CUSTOM FUNCTIONS CHECK' as check_type,
  routine_name,
  routine_type,
  security_type,
  is_deterministic
FROM information_schema.routines 
WHERE routine_schema = 'public'
  AND routine_name LIKE '%warehouse%'
  OR routine_name LIKE '%user%'
ORDER BY routine_name;

-- ==================== STEP 6: VERIFY TABLE EXISTENCE ====================

-- Check if all required tables exist
SELECT 
  '📋 TABLE EXISTENCE CHECK' as check_type,
  table_name,
  table_type
FROM information_schema.tables 
WHERE table_schema = 'public'
  AND (
    table_name LIKE '%warehouse%' 
    OR table_name LIKE '%user%'
    OR table_name LIKE '%product%'
    OR table_name LIKE '%invoice%'
  )
ORDER BY table_name;

-- ==================== STEP 7: CHECK FOREIGN KEY CONSTRAINTS ====================

-- Check foreign key constraints that might be broken
SELECT 
  '🔗 FOREIGN KEY CONSTRAINTS' as check_type,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_schema = 'public'
  AND (
    tc.table_name LIKE '%warehouse%' 
    OR tc.table_name LIKE '%user%'
  )
ORDER BY tc.table_name;

-- ==================== STEP 8: SUMMARY REPORT ====================

-- Generate summary report
SELECT 
  '📊 DIAGNOSIS SUMMARY' as report_type,
  'User ID: 4ac083bc-3e05-4456-8579-0877d2627b15' as user_info,
  'Email: hima@sama.com' as email_info,
  'Incident Date: 16 Jun, 2025 18:56' as incident_date,
  'Diagnosis Date: ' || NOW()::TEXT as diagnosis_date;
