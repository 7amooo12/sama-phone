-- RLS Configuration Verification Script
-- Run this after implementing all RLS policies to verify everything is working correctly

-- 1. Check RLS Status for All Tables
SELECT 
    schemaname,
    tablename,
    CASE 
        WHEN c.relrowsecurity THEN 'Enabled' 
        ELSE 'Disabled' 
    END as rls_status
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE schemaname = 'public'
    AND tablename IN (
        'client_order_items', 'client_orders', 'favorites', 'notifications',
        'order_history', 'order_items', 'order_notifications', 'order_tracking_links',
        'orders', 'products', 'task_feedback', 'task_submissions', 'tasks',
        'todos', 'user_profiles', 'worker_reward_balances', 'worker_rewards', 'worker_tasks'
    )
ORDER BY tablename;

-- 2. Count Policies Per Table
SELECT 
    tablename,
    COUNT(*) as policy_count,
    STRING_AGG(policyname, ', ' ORDER BY policyname) as policy_names
FROM pg_policies 
WHERE schemaname = 'public'
    AND tablename IN (
        'client_order_items', 'client_orders', 'favorites', 'notifications',
        'order_history', 'order_items', 'order_notifications', 'order_tracking_links',
        'orders', 'products', 'task_feedback', 'task_submissions', 'tasks',
        'todos', 'user_profiles', 'worker_reward_balances', 'worker_rewards', 'worker_tasks'
    )
GROUP BY tablename
ORDER BY tablename;

-- 3. Verify Helper Functions Exist
SELECT 
    proname as function_name,
    CASE 
        WHEN proname IS NOT NULL THEN 'Exists' 
        ELSE 'Missing' 
    END as status
FROM pg_proc 
WHERE proname IN ('is_admin', 'is_worker', 'is_client')
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth');

-- 4. Check for Tables with RLS Enabled but No Policies (Should be empty)
SELECT 
    t.tablename,
    'RLS Enabled but No Policies' as issue
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
LEFT JOIN pg_policies p ON p.tablename = t.tablename AND p.schemaname = t.schemaname
WHERE t.schemaname = 'public'
    AND c.relrowsecurity = true
    AND p.policyname IS NULL
    AND t.tablename IN (
        'client_order_items', 'client_orders', 'favorites', 'notifications',
        'order_history', 'order_items', 'order_notifications', 'order_tracking_links',
        'orders', 'products', 'task_feedback', 'task_submissions', 'tasks',
        'todos', 'user_profiles', 'worker_reward_balances', 'worker_rewards', 'worker_tasks'
    );

-- 5. Detailed Policy Information
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as operation,
    CASE 
        WHEN qual IS NOT NULL THEN 'Has USING clause'
        ELSE 'No USING clause'
    END as using_clause,
    CASE 
        WHEN with_check IS NOT NULL THEN 'Has WITH CHECK clause'
        ELSE 'No WITH CHECK clause'
    END as with_check_clause
FROM pg_policies 
WHERE schemaname = 'public'
    AND tablename IN (
        'client_order_items', 'client_orders', 'favorites', 'notifications',
        'order_history', 'order_items', 'order_notifications', 'order_tracking_links',
        'orders', 'products', 'task_feedback', 'task_submissions', 'tasks',
        'todos', 'user_profiles', 'worker_reward_balances', 'worker_rewards', 'worker_tasks'
    )
ORDER BY tablename, policyname;

-- 6. Expected Policy Count Verification
WITH expected_counts AS (
    SELECT 'client_order_items' as table_name, 5 as expected_policies
    UNION ALL SELECT 'client_orders', 6
    UNION ALL SELECT 'favorites', 1
    UNION ALL SELECT 'notifications', 2
    UNION ALL SELECT 'order_history', 4
    UNION ALL SELECT 'order_items', 2
    UNION ALL SELECT 'order_notifications', 4
    UNION ALL SELECT 'order_tracking_links', 5
    UNION ALL SELECT 'orders', 4
    UNION ALL SELECT 'products', 2
    UNION ALL SELECT 'task_feedback', 4
    UNION ALL SELECT 'task_submissions', 4
    UNION ALL SELECT 'tasks', 9
    UNION ALL SELECT 'todos', 4
    UNION ALL SELECT 'user_profiles', 9
    UNION ALL SELECT 'worker_reward_balances', 3
    UNION ALL SELECT 'worker_rewards', 5
    UNION ALL SELECT 'worker_tasks', 5
),
actual_counts AS (
    SELECT 
        tablename,
        COUNT(*) as actual_policies
    FROM pg_policies 
    WHERE schemaname = 'public'
    GROUP BY tablename
)
SELECT 
    e.table_name,
    e.expected_policies,
    COALESCE(a.actual_policies, 0) as actual_policies,
    CASE 
        WHEN e.expected_policies = COALESCE(a.actual_policies, 0) THEN '✅ Correct'
        WHEN COALESCE(a.actual_policies, 0) = 0 THEN '❌ No policies found'
        ELSE '⚠️ Count mismatch'
    END as status
FROM expected_counts e
LEFT JOIN actual_counts a ON e.table_name = a.tablename
ORDER BY e.table_name;

-- 7. Test Helper Functions (if you have test data)
-- Uncomment and modify these if you want to test with actual user data
/*
-- Test admin function
SELECT 
    id,
    email,
    role,
    auth.is_admin() as is_admin_result
FROM public.user_profiles 
WHERE role = 'admin'
LIMIT 1;

-- Test worker function  
SELECT 
    id,
    email,
    role,
    auth.is_worker() as is_worker_result
FROM public.user_profiles 
WHERE role = 'worker'
LIMIT 1;

-- Test client function
SELECT 
    id,
    email,
    role,
    auth.is_client() as is_client_result
FROM public.user_profiles 
WHERE role = 'client'
LIMIT 1;
*/

-- 8. Summary Report
DO $$
DECLARE
    total_tables INTEGER;
    tables_with_rls INTEGER;
    tables_with_policies INTEGER;
    total_policies INTEGER;
BEGIN
    -- Count totals
    SELECT COUNT(*) INTO total_tables
    FROM pg_tables 
    WHERE schemaname = 'public'
        AND tablename IN (
            'client_order_items', 'client_orders', 'favorites', 'notifications',
            'order_history', 'order_items', 'order_notifications', 'order_tracking_links',
            'orders', 'products', 'task_feedback', 'task_submissions', 'tasks',
            'todos', 'user_profiles', 'worker_reward_balances', 'worker_rewards', 'worker_tasks'
        );
    
    SELECT COUNT(*) INTO tables_with_rls
    FROM pg_tables t
    JOIN pg_class c ON c.relname = t.tablename
    WHERE t.schemaname = 'public'
        AND c.relrowsecurity = true
        AND t.tablename IN (
            'client_order_items', 'client_orders', 'favorites', 'notifications',
            'order_history', 'order_items', 'order_notifications', 'order_tracking_links',
            'orders', 'products', 'task_feedback', 'task_submissions', 'tasks',
            'todos', 'user_profiles', 'worker_reward_balances', 'worker_rewards', 'worker_tasks'
        );
    
    SELECT COUNT(DISTINCT tablename) INTO tables_with_policies
    FROM pg_policies 
    WHERE schemaname = 'public'
        AND tablename IN (
            'client_order_items', 'client_orders', 'favorites', 'notifications',
            'order_history', 'order_items', 'order_notifications', 'order_tracking_links',
            'orders', 'products', 'task_feedback', 'task_submissions', 'tasks',
            'todos', 'user_profiles', 'worker_reward_balances', 'worker_rewards', 'worker_tasks'
        );
    
    SELECT COUNT(*) INTO total_policies
    FROM pg_policies 
    WHERE schemaname = 'public'
        AND tablename IN (
            'client_order_items', 'client_orders', 'favorites', 'notifications',
            'order_history', 'order_items', 'order_notifications', 'order_tracking_links',
            'orders', 'products', 'task_feedback', 'task_submissions', 'tasks',
            'todos', 'user_profiles', 'worker_reward_balances', 'worker_rewards', 'worker_tasks'
        );
    
    RAISE NOTICE '=== RLS CONFIGURATION VERIFICATION SUMMARY ===';
    RAISE NOTICE 'Total Tables Configured: %', total_tables;
    RAISE NOTICE 'Tables with RLS Enabled: %', tables_with_rls;
    RAISE NOTICE 'Tables with Policies: %', tables_with_policies;
    RAISE NOTICE 'Total Policies Created: %', total_policies;
    RAISE NOTICE 'Expected Total Policies: 82';
    
    IF total_policies = 82 AND tables_with_rls = 18 AND tables_with_policies = 18 THEN
        RAISE NOTICE '✅ SUCCESS: All RLS policies configured correctly!';
    ELSE
        RAISE NOTICE '⚠️ WARNING: Configuration may be incomplete. Please review the results above.';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '1. Test your Flutter application';
    RAISE NOTICE '2. Monitor for permission errors';
    RAISE NOTICE '3. Verify user roles in user_profiles table';
    RAISE NOTICE '4. Test with different user types (admin, worker, client)';
END $$;
