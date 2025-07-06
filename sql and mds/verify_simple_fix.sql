-- Quick verification script for the simple RLS fix
-- Run this after executing fix_rls_simple.sql

-- Check RLS status and policies for priority tables
SELECT 
    t.tablename,
    CASE WHEN c.relrowsecurity THEN 'Enabled' ELSE 'Disabled' END as rls_status,
    COUNT(p.policyname) as policy_count
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
LEFT JOIN pg_policies p ON p.tablename = t.tablename AND p.schemaname = t.schemaname
WHERE t.schemaname = 'public'
    AND t.tablename IN ('tasks', 'task_feedback', 'task_submissions', 'user_profiles', 'products', 'notifications', 'favorites')
GROUP BY t.tablename, c.relrowsecurity
ORDER BY t.tablename;

-- List all policies for these tables
SELECT 
    tablename,
    policyname,
    cmd as operation,
    roles
FROM pg_policies 
WHERE schemaname = 'public'
    AND tablename IN ('tasks', 'task_feedback', 'task_submissions', 'user_profiles', 'products', 'notifications', 'favorites')
ORDER BY tablename, policyname;

-- Test if we can query the tables (should not give permission errors)
DO $$
DECLARE
    test_result TEXT;
BEGIN
    RAISE NOTICE '=== TESTING TABLE ACCESS ===';
    
    -- Test tasks table
    BEGIN
        PERFORM COUNT(*) FROM public.tasks LIMIT 1;
        RAISE NOTICE '✅ tasks table - Accessible';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ tasks table - Error: %', SQLERRM;
    END;
    
    -- Test task_feedback table
    BEGIN
        PERFORM COUNT(*) FROM public.task_feedback LIMIT 1;
        RAISE NOTICE '✅ task_feedback table - Accessible';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ task_feedback table - Error: %', SQLERRM;
    END;
    
    -- Test task_submissions table
    BEGIN
        PERFORM COUNT(*) FROM public.task_submissions LIMIT 1;
        RAISE NOTICE '✅ task_submissions table - Accessible';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ task_submissions table - Error: %', SQLERRM;
    END;
    
    -- Test user_profiles table
    BEGIN
        PERFORM COUNT(*) FROM public.user_profiles LIMIT 1;
        RAISE NOTICE '✅ user_profiles table - Accessible';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ user_profiles table - Error: %', SQLERRM;
    END;
    
    -- Test products table
    BEGIN
        PERFORM COUNT(*) FROM public.products LIMIT 1;
        RAISE NOTICE '✅ products table - Accessible';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ products table - Error: %', SQLERRM;
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE 'If all tables show as accessible, your RLS fix was successful!';
    RAISE NOTICE 'You can now test task creation in your Flutter app.';
END $$;
