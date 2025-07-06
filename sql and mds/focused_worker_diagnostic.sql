-- =====================================================
-- FOCUSED WORKER VISIBILITY DIAGNOSTIC
-- =====================================================
-- 
-- This script provides a focused investigation into why workers
-- are missing from attendance reports
--

-- Step 1: Count all workers by role and status
SELECT 
    'STEP 1: Worker Count by Role and Status' as diagnostic_step,
    role,
    status,
    COUNT(*) as worker_count
FROM user_profiles
WHERE role IN ('worker', 'عامل')
GROUP BY role, status
ORDER BY role, status;

-- Step 2: List all workers with details
SELECT 
    'STEP 2: All Workers Details' as diagnostic_step,
    id,
    name,
    email,
    role,
    status,
    created_at
FROM user_profiles
WHERE role IN ('worker', 'عامل')
ORDER BY created_at DESC;

-- Step 3: Test the exact database function query
SELECT 
    'STEP 3: Database Function Query Test' as diagnostic_step,
    COUNT(*) as eligible_workers_count
FROM user_profiles up
WHERE (up.role = 'عامل' OR up.role = 'worker') AND up.status = 'approved';

-- Step 4: Show eligible workers details
SELECT 
    'STEP 4: Eligible Workers for Reports' as diagnostic_step,
    up.id, 
    up.name, 
    up.role,
    up.status,
    up.created_at
FROM user_profiles up
WHERE (up.role = 'عامل' OR up.role = 'worker') AND up.status = 'approved'
ORDER BY up.created_at DESC;

-- Step 5: Check if get_worker_attendance_report_data function exists
SELECT 
    'STEP 5: Function Existence Check' as diagnostic_step,
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name = 'get_worker_attendance_report_data';

-- Step 6: Test the attendance report function (if it exists)
DO $$
DECLARE
    function_exists BOOLEAN := FALSE;
    report_count INTEGER := 0;
BEGIN
    -- Check if function exists
    SELECT EXISTS(
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'get_worker_attendance_report_data'
    ) INTO function_exists;
    
    IF function_exists THEN
        -- Test the function
        SELECT COUNT(*) INTO report_count
        FROM get_worker_attendance_report_data(
            CURRENT_DATE::TIMESTAMP,
            (CURRENT_DATE + INTERVAL '1 day')::TIMESTAMP,
            9, 0, 17, 0, 15, 10
        );
        
        RAISE NOTICE 'STEP 6: Function Test - Workers in reports: %', report_count;
    ELSE
        RAISE NOTICE 'STEP 6: Function Test - get_worker_attendance_report_data function does not exist';
    END IF;
END $$;

-- Step 7: Check worker attendance profiles
SELECT 
    'STEP 7: Worker Attendance Profiles' as diagnostic_step,
    up.id as user_id,
    up.name,
    up.role,
    up.status,
    CASE WHEN wap.id IS NOT NULL THEN 'HAS_PROFILE' ELSE 'NO_PROFILE' END as profile_status
FROM user_profiles up
LEFT JOIN worker_attendance_profiles wap ON up.id = wap.worker_id
WHERE up.role IN ('worker', 'عامل')
ORDER BY up.created_at DESC;

-- Step 8: Summary comparison
SELECT 
    'STEP 8: Summary Comparison' as diagnostic_step,
    'Total workers in system' as metric,
    COUNT(*) as count
FROM user_profiles
WHERE role IN ('worker', 'عامل')
UNION ALL
SELECT 
    'STEP 8: Summary Comparison' as diagnostic_step,
    'Approved workers (eligible for reports)' as metric,
    COUNT(*) as count
FROM user_profiles
WHERE (role = 'عامل' OR role = 'worker') AND status = 'approved';

-- Final diagnostic message
SELECT 
    'DIAGNOSTIC COMPLETE' as status,
    'Review the results above to identify the issue' as instruction;
