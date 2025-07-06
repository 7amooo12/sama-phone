-- =====================================================
-- DEBUG WORKER VISIBILITY IN ATTENDANCE REPORTS
-- =====================================================
-- 
-- This script investigates why new workers are not appearing
-- in attendance reports despite being registered in the system
--

-- =====================================================
-- STEP 1: CHECK ALL WORKERS IN SYSTEM
-- =====================================================

SELECT 
    '=== ALL WORKERS IN SYSTEM ===' as section;

SELECT 
    id,
    name,
    email,
    role,
    status,
    created_at,
    updated_at
FROM user_profiles
WHERE role IN ('worker', 'عامل')
ORDER BY created_at DESC;

-- =====================================================
-- STEP 2: CHECK WORKERS BY ROLE AND STATUS
-- =====================================================

SELECT 
    '=== WORKERS BY ROLE AND STATUS ===' as section;

-- Count by role
SELECT 
    'Workers by role' as category,
    role,
    status,
    COUNT(*) as count
FROM user_profiles
WHERE role IN ('worker', 'عامل')
GROUP BY role, status
ORDER BY role, status;

-- =====================================================
-- STEP 3: TEST DATABASE FUNCTION QUERY
-- =====================================================

SELECT 
    '=== TESTING DATABASE FUNCTION QUERY ===' as section;

-- Test the exact query used in get_worker_attendance_report_data
SELECT 
    up.id, 
    up.name, 
    up.profile_image,
    up.role,
    up.status,
    up.created_at
FROM user_profiles up
WHERE (up.role = 'عامل' OR up.role = 'worker') AND up.status = 'approved'
ORDER BY up.created_at DESC;

-- =====================================================
-- STEP 4: CHECK RECENT WORKER REGISTRATIONS
-- =====================================================

SELECT 
    '=== RECENT WORKER REGISTRATIONS ===' as section;

-- Check workers created in the last 24 hours
SELECT 
    id,
    name,
    email,
    role,
    status,
    created_at,
    EXTRACT(EPOCH FROM (NOW() - created_at)) / 3600 as hours_since_creation
FROM user_profiles
WHERE role IN ('worker', 'عامل')
  AND created_at >= NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- =====================================================
-- STEP 5: CHECK WORKER ATTENDANCE PROFILES
-- =====================================================

SELECT 
    '=== WORKER ATTENDANCE PROFILES ===' as section;

-- Check if new workers have attendance profiles
SELECT 
    up.id as user_id,
    up.name,
    up.role,
    up.status,
    wap.id as profile_id,
    wap.device_hash,
    wap.is_active,
    wap.created_at as profile_created_at
FROM user_profiles up
LEFT JOIN worker_attendance_profiles wap ON up.id = wap.worker_id
WHERE up.role IN ('worker', 'عامل')
ORDER BY up.created_at DESC;

-- =====================================================
-- STEP 6: TEST ATTENDANCE REPORT FUNCTION
-- =====================================================

SELECT 
    '=== TESTING ATTENDANCE REPORT FUNCTION ===' as section;

-- Test the function with current date range
SELECT 
    worker_id,
    worker_name,
    profile_image_url,
    check_in_status,
    check_out_status,
    attendance_days,
    absence_days
FROM get_worker_attendance_report_data(
    CURRENT_DATE::TIMESTAMP,
    (CURRENT_DATE + INTERVAL '1 day')::TIMESTAMP,
    9, 0, 17, 0, 15, 10
)
ORDER BY worker_name;

-- =====================================================
-- STEP 7: IDENTIFY MISSING WORKERS
-- =====================================================

SELECT 
    '=== WORKERS NOT IN ATTENDANCE REPORTS ===' as section;

-- Find workers that should be in reports but aren't
WITH report_workers AS (
    SELECT worker_id
    FROM get_worker_attendance_report_data(
        CURRENT_DATE::TIMESTAMP,
        (CURRENT_DATE + INTERVAL '1 day')::TIMESTAMP,
        9, 0, 17, 0, 15, 10
    )
),
all_eligible_workers AS (
    SELECT id, name, role, status
    FROM user_profiles
    WHERE (role = 'عامل' OR role = 'worker') AND status = 'approved'
)
SELECT 
    aew.id,
    aew.name,
    aew.role,
    aew.status,
    CASE WHEN rw.worker_id IS NULL THEN 'MISSING FROM REPORTS' ELSE 'IN REPORTS' END as report_status
FROM all_eligible_workers aew
LEFT JOIN report_workers rw ON aew.id = rw.worker_id
ORDER BY report_status DESC, aew.name;

-- =====================================================
-- STEP 8: SUMMARY AND RECOMMENDATIONS
-- =====================================================

SELECT 
    '=== SUMMARY ===' as section;

SELECT 
    'Total workers in system' as metric,
    COUNT(*) as value
FROM user_profiles
WHERE role IN ('worker', 'عامل')
UNION ALL
SELECT 
    'Approved workers' as metric,
    COUNT(*) as value
FROM user_profiles
WHERE (role = 'عامل' OR role = 'worker') AND status = 'approved'
UNION ALL
SELECT 
    'Workers in attendance reports' as metric,
    COUNT(*) as value
FROM get_worker_attendance_report_data(
    CURRENT_DATE::TIMESTAMP,
    (CURRENT_DATE + INTERVAL '1 day')::TIMESTAMP,
    9, 0, 17, 0, 15, 10
);

-- Final diagnostic message
SELECT 
    '🔍 WORKER VISIBILITY DIAGNOSTIC COMPLETE' as status,
    'Check the results above to identify why workers are missing from reports' as next_step;
