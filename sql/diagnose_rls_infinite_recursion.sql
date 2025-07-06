-- Diagnose RLS Infinite Recursion Error on user_profiles table
-- PostgreSQL Error Code: 42P17 - infinite recursion detected in policy

-- ========================================
-- 1. EXAMINE CURRENT RLS POLICIES
-- ========================================

SELECT 
    '=== CURRENT RLS POLICIES ON USER_PROFILES ===' as section_header;

-- List all policies on user_profiles table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual as policy_condition,
    with_check
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY policyname;

-- ========================================
-- 2. CHECK FOR RECURSIVE FUNCTIONS
-- ========================================

SELECT 
    '=== CUSTOM FUNCTIONS THAT MIGHT CAUSE RECURSION ===' as section_header;

-- Check for custom functions that might query user_profiles
SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND pg_get_functiondef(p.oid) ILIKE '%user_profiles%'
ORDER BY p.proname;

-- ========================================
-- 3. TEST DIRECT TABLE ACCESS
-- ========================================

SELECT 
    '=== TESTING DIRECT TABLE ACCESS ===' as section_header;

-- Test if we can query user_profiles directly (this might fail with recursion error)
-- We'll wrap this in a function to catch the error
CREATE OR REPLACE FUNCTION test_user_profiles_access()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result_count INTEGER;
    error_message TEXT;
BEGIN
    BEGIN
        SELECT COUNT(*) INTO result_count FROM user_profiles;
        RETURN 'SUCCESS: Can access user_profiles table. Total rows: ' || result_count;
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS error_message = MESSAGE_TEXT;
            RETURN 'ERROR: ' || error_message;
    END;
END;
$$;

SELECT test_user_profiles_access();

-- ========================================
-- 4. TEST SPECIFIC USER QUERY
-- ========================================

SELECT 
    '=== TESTING SPECIFIC USER QUERY ===' as section_header;

-- Test the specific query that's failing
CREATE OR REPLACE FUNCTION test_eslam_user_query()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_record RECORD;
    error_message TEXT;
BEGIN
    BEGIN
        SELECT * INTO user_record 
        FROM user_profiles 
        WHERE email = 'eslam@sama.com';
        
        IF FOUND THEN
            RETURN 'SUCCESS: Found user eslam@sama.com - ID: ' || user_record.id || ', Role: ' || user_record.role;
        ELSE
            RETURN 'WARNING: User eslam@sama.com not found';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS error_message = MESSAGE_TEXT;
            RETURN 'ERROR: ' || error_message;
    END;
END;
$$;

SELECT test_eslam_user_query();

-- ========================================
-- 5. ANALYZE AUTH CONTEXT
-- ========================================

SELECT 
    '=== CURRENT AUTH CONTEXT ===' as section_header;

-- Check current authentication context
SELECT 
    'Current auth.uid()' as context_type,
    COALESCE(auth.uid()::text, 'NULL') as auth_value;

SELECT 
    'Current auth.role()' as context_type,
    COALESCE(auth.role(), 'NULL') as auth_value;

-- ========================================
-- 6. IDENTIFY PROBLEMATIC POLICIES
-- ========================================

SELECT 
    '=== ANALYZING POLICY CONDITIONS FOR RECURSION PATTERNS ===' as section_header;

-- Look for policies that might cause recursion
SELECT 
    policyname,
    cmd,
    qual as policy_condition,
    CASE 
        WHEN qual ILIKE '%user_profiles%' THEN 'POTENTIAL_RECURSION: References user_profiles table'
        WHEN qual ILIKE '%auth.uid()%' AND qual ILIKE '%SELECT%' THEN 'POTENTIAL_RECURSION: Uses auth.uid() with subquery'
        WHEN qual ILIKE '%function%' THEN 'POTENTIAL_RECURSION: Uses custom function'
        ELSE 'SAFE: Simple condition'
    END as recursion_risk
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY 
    CASE 
        WHEN qual ILIKE '%user_profiles%' THEN 1
        WHEN qual ILIKE '%auth.uid()%' AND qual ILIKE '%SELECT%' THEN 2
        WHEN qual ILIKE '%function%' THEN 3
        ELSE 4
    END;

-- ========================================
-- 7. RECOMMENDED FIX STRATEGY
-- ========================================

SELECT 
    '=== RECOMMENDED FIX STRATEGY ===' as section_header;

SELECT 
    'STEP 1: Drop all existing policies on user_profiles' as fix_step,
    'This will temporarily disable RLS to test basic access' as description;

SELECT 
    'STEP 2: Create simple, non-recursive policies' as fix_step,
    'Use direct auth.uid() = id comparisons only' as description;

SELECT 
    'STEP 3: Test each policy individually' as fix_step,
    'Add policies one by one to identify the problematic one' as description;

SELECT 
    'STEP 4: Avoid subqueries and function calls in policies' as fix_step,
    'Use only direct column comparisons and auth.uid()' as description;

-- ========================================
-- 8. EMERGENCY RLS DISABLE (FOR TESTING ONLY)
-- ========================================

SELECT 
    '=== EMERGENCY RLS DISABLE COMMANDS (USE WITH CAUTION) ===' as section_header;

SELECT 
    'To temporarily disable RLS for testing:' as warning,
    'ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;' as disable_command,
    'To re-enable: ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;' as enable_command;

-- ========================================
-- 9. CLEANUP TEST FUNCTIONS
-- ========================================

-- Clean up test functions
DROP FUNCTION IF EXISTS test_user_profiles_access();
DROP FUNCTION IF EXISTS test_eslam_user_query();
