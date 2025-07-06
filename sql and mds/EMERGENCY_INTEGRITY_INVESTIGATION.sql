-- ============================================================================
-- EMERGENCY DATABASE INTEGRITY INVESTIGATION - VOUCHER SYSTEM REGRESSION
-- ============================================================================
-- This script investigates the resurfaced orphaned records issue
-- Run this immediately to understand the current state

-- ============================================================================
-- STEP 1: Current State Analysis - Specific Client Focus
-- ============================================================================

-- Check the specific client mentioned in the logs
SELECT 
    '=== SPECIFIC CLIENT ANALYSIS ===' as section,
    cv.id as client_voucher_id,
    cv.voucher_id as missing_voucher_id,
    cv.client_id,
    cv.status,
    cv.assigned_at,
    cv.created_at,
    cv.updated_at,
    up.name as client_name,
    up.email as client_email,
    CASE WHEN v.id IS NULL THEN 'ORPHANED' ELSE 'VALID' END as record_status
FROM public.client_vouchers cv
LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
LEFT JOIN public.user_profiles up ON cv.client_id = up.id
WHERE cv.client_id = 'aaaaf98e-f3aa-489d-9586-573332ff6301'::UUID
ORDER BY cv.created_at DESC;

-- ============================================================================
-- STEP 2: Verify Specific Orphaned Records from Logs
-- ============================================================================

-- Check the exact client voucher IDs mentioned in the logs
SELECT 
    '=== SPECIFIC ORPHANED RECORDS ===' as section,
    cv.id as client_voucher_id,
    cv.voucher_id as missing_voucher_id,
    cv.status,
    cv.assigned_at,
    cv.created_at,
    CASE WHEN v.id IS NULL THEN 'CONFIRMED ORPHANED' ELSE 'UNEXPECTEDLY VALID' END as verification_status
FROM public.client_vouchers cv
LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
WHERE cv.id IN (
    'e17e8ca9-22b9-4237-9d2e-c037fa10ffbf'::UUID,
    '17a11c80-cd38-4191-8d4b-c5d8b998b540'::UUID,
    '7aaf2811-9c7b-4955-8cda-c596db407955'::UUID
);

-- Check if the missing voucher IDs exist anywhere
SELECT 
    '=== MISSING VOUCHER VERIFICATION ===' as section,
    check_voucher_id,
    CASE 
        WHEN EXISTS (SELECT 1 FROM public.vouchers WHERE id = check_voucher_id) 
        THEN 'EXISTS IN VOUCHERS TABLE' 
        ELSE 'CONFIRMED MISSING' 
    END as voucher_status,
    CASE 
        WHEN EXISTS (SELECT 1 FROM public.orphaned_client_vouchers_backup WHERE voucher_id = check_voucher_id)
        THEN 'FOUND IN BACKUP'
        ELSE 'NOT IN BACKUP'
    END as backup_status
FROM (
    VALUES 
        ('cab36f65-f1c6-4aa0-bfd1-7f51eef742c7'::UUID),
        ('6676eb53-c570-4ff4-be51-1082925f7c2c'::UUID),
        ('8e38613f-19c0-4c9a-9290-30cdcd220c60'::UUID)
) AS check_vouchers(check_voucher_id);

-- ============================================================================
-- STEP 3: Complete System-Wide Orphaned Records Check
-- ============================================================================

-- Get ALL orphaned records in the system
SELECT 
    '=== ALL ORPHANED RECORDS ===' as section,
    cv.id as client_voucher_id,
    cv.voucher_id as missing_voucher_id,
    cv.client_id,
    cv.status,
    cv.assigned_at,
    cv.created_at,
    up.name as client_name,
    up.email as client_email,
    EXTRACT(DAYS FROM NOW() - cv.created_at) as days_since_creation
FROM public.client_vouchers cv
LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
LEFT JOIN public.user_profiles up ON cv.client_id = up.id
WHERE v.id IS NULL
ORDER BY cv.created_at DESC;

-- Count by status
SELECT 
    '=== ORPHANED RECORDS BY STATUS ===' as section,
    cv.status,
    COUNT(*) as count
FROM public.client_vouchers cv
LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
WHERE v.id IS NULL
GROUP BY cv.status;

-- ============================================================================
-- STEP 4: Timeline Analysis - When Did This Happen?
-- ============================================================================

-- Check recent voucher deletions (if cleanup log exists)
SELECT 
    '=== RECENT CLEANUP ACTIVITY ===' as section,
    cleanup_type,
    table_name,
    records_affected,
    cleanup_timestamp,
    details
FROM public.database_cleanup_log
WHERE cleanup_timestamp >= NOW() - INTERVAL '7 days'
ORDER BY cleanup_timestamp DESC;

-- Check voucher creation patterns
SELECT 
    '=== RECENT VOUCHER ACTIVITY ===' as section,
    DATE(created_at) as creation_date,
    COUNT(*) as vouchers_created,
    COUNT(CASE WHEN is_active THEN 1 END) as active_vouchers,
    COUNT(CASE WHEN NOT is_active THEN 1 END) as inactive_vouchers
FROM public.vouchers
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY creation_date DESC;

-- ============================================================================
-- STEP 5: Foreign Key Constraint Verification
-- ============================================================================

-- Check if CASCADE constraint is properly configured
SELECT 
    '=== FOREIGN KEY CONSTRAINT STATUS ===' as section,
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule,
    rc.update_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'client_vouchers'
    AND kcu.column_name = 'voucher_id'
    AND tc.table_schema = 'public';

-- ============================================================================
-- STEP 6: Recovery Voucher Check
-- ============================================================================

-- Check if any recovery vouchers exist for these missing IDs
SELECT 
    '=== RECOVERY VOUCHER STATUS ===' as section,
    v.id,
    v.code,
    v.name,
    v.is_active,
    v.metadata->>'recovery' as is_recovery,
    v.metadata->>'original_voucher_id' as original_voucher_id,
    v.created_at
FROM public.vouchers v
WHERE v.metadata->>'recovery' = 'true'
   OR v.id IN (
       'cab36f65-f1c6-4aa0-bfd1-7f51eef742c7'::UUID,
       '6676eb53-c570-4ff4-be51-1082925f7c2c'::UUID,
       '8e38613f-19c0-4c9a-9290-30cdcd220c60'::UUID
   );

-- ============================================================================
-- STEP 7: Updated Summary Report
-- ============================================================================

-- Generate current integrity summary
WITH current_orphaned_stats AS (
    SELECT 
        COUNT(*) as total_orphaned,
        COUNT(DISTINCT cv.client_id) as affected_clients,
        MIN(cv.created_at) as oldest_orphaned,
        MAX(cv.created_at) as newest_orphaned,
        COUNT(CASE WHEN cv.status = 'active' THEN 1 END) as active_orphaned,
        COUNT(CASE WHEN cv.status = 'used' THEN 1 END) as used_orphaned,
        COUNT(CASE WHEN cv.status = 'expired' THEN 1 END) as expired_orphaned
    FROM public.client_vouchers cv
    LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
    WHERE v.id IS NULL
),
total_stats AS (
    SELECT 
        COUNT(*) as total_client_vouchers,
        COUNT(DISTINCT client_id) as total_clients_with_vouchers
    FROM public.client_vouchers
)
SELECT 
    '=== EMERGENCY INTEGRITY SUMMARY ===' as section,
    ts.total_client_vouchers,
    ts.total_clients_with_vouchers,
    COALESCE(os.total_orphaned, 0) as orphaned_records,
    COALESCE(os.affected_clients, 0) as affected_clients,
    COALESCE(os.active_orphaned, 0) as active_orphaned,
    COALESCE(os.used_orphaned, 0) as used_orphaned,
    COALESCE(os.expired_orphaned, 0) as expired_orphaned,
    CASE 
        WHEN COALESCE(os.total_orphaned, 0) = 0 THEN 'HEALTHY'
        WHEN COALESCE(os.total_orphaned, 0) < 5 THEN 'MINOR_ISSUES'
        WHEN COALESCE(os.total_orphaned, 0) < 10 THEN 'MODERATE_ISSUES'
        ELSE 'CRITICAL_ISSUES'
    END as integrity_status,
    os.oldest_orphaned,
    os.newest_orphaned
FROM total_stats ts
CROSS JOIN current_orphaned_stats os;

-- ============================================================================
-- STEP 8: Immediate Action Recommendations
-- ============================================================================

SELECT 
    '=== IMMEDIATE ACTION REQUIRED ===' as section,
    'Run EMERGENCY_RECOVERY_SCRIPT.sql immediately' as action_1,
    'Check application logs for voucher deletion events' as action_2,
    'Verify CASCADE constraint is functioning' as action_3,
    'Implement additional deletion safeguards' as action_4;

-- ============================================================================
-- INVESTIGATION COMPLETE - PROCEED TO EMERGENCY RECOVERY
-- ============================================================================
