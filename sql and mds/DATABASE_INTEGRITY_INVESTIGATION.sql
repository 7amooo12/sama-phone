-- ============================================================================
-- DATABASE INTEGRITY INVESTIGATION FOR VOUCHER SYSTEM
-- ============================================================================
-- This script investigates the current state of voucher system integrity
-- and identifies orphaned client_vouchers records

-- ============================================================================
-- STEP 1: Check Current State of Vouchers and Client Vouchers
-- ============================================================================

-- Check total counts
SELECT 
    'vouchers' as table_name,
    COUNT(*) as total_records
FROM public.vouchers
UNION ALL
SELECT 
    'client_vouchers' as table_name,
    COUNT(*) as total_records
FROM public.client_vouchers;

-- ============================================================================
-- STEP 2: Identify Orphaned Client Voucher Records
-- ============================================================================

-- Find client_vouchers that reference non-existent vouchers
SELECT 
    cv.id as client_voucher_id,
    cv.voucher_id as missing_voucher_id,
    cv.client_id,
    cv.status,
    cv.assigned_at,
    cv.created_at,
    up.name as client_name,
    up.email as client_email
FROM public.client_vouchers cv
LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
LEFT JOIN public.user_profiles up ON cv.client_id = up.id
WHERE v.id IS NULL
ORDER BY cv.created_at DESC;

-- ============================================================================
-- STEP 3: Check Specific Voucher IDs from the Problem Report
-- ============================================================================

-- Check if the specific voucher IDs exist
SELECT 
    'Voucher Check' as check_type,
    voucher_id,
    CASE 
        WHEN EXISTS (SELECT 1 FROM public.vouchers WHERE id = voucher_id) 
        THEN 'EXISTS' 
        ELSE 'MISSING' 
    END as status
FROM (
    VALUES 
        ('6676eb53-c570-4ff4-be51-1082925f7c2c'::UUID),
        ('8e38613f-19c0-4c9a-9290-30cdcd220c60'::UUID)
) AS check_vouchers(voucher_id);

-- Check client_vouchers for specific client
SELECT 
    cv.id as client_voucher_id,
    cv.voucher_id,
    cv.client_id,
    cv.status,
    cv.assigned_at,
    v.id as voucher_exists,
    v.name as voucher_name,
    v.code as voucher_code,
    v.is_active as voucher_active
FROM public.client_vouchers cv
LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
WHERE cv.client_id = 'aaaaf98e-f3aa-489d-9586-573332ff6301'::UUID
ORDER BY cv.created_at DESC;

-- ============================================================================
-- STEP 4: Check for Recently Deleted Vouchers (if audit trail exists)
-- ============================================================================

-- Check if there are any patterns in voucher creation/deletion
SELECT 
    DATE(created_at) as creation_date,
    COUNT(*) as vouchers_created
FROM public.vouchers
GROUP BY DATE(created_at)
ORDER BY creation_date DESC
LIMIT 10;

-- ============================================================================
-- STEP 5: Analyze Impact of Orphaned Records
-- ============================================================================

-- Count orphaned records by status
SELECT 
    cv.status,
    COUNT(*) as orphaned_count
FROM public.client_vouchers cv
LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
WHERE v.id IS NULL
GROUP BY cv.status;

-- Count affected clients
SELECT 
    COUNT(DISTINCT cv.client_id) as affected_clients,
    COUNT(*) as total_orphaned_records
FROM public.client_vouchers cv
LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
WHERE v.id IS NULL;

-- ============================================================================
-- STEP 6: Check Foreign Key Constraints
-- ============================================================================

-- Verify foreign key constraints are in place
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
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
    AND tc.table_schema = 'public';

-- ============================================================================
-- STEP 7: Generate Summary Report
-- ============================================================================

-- Summary of database integrity issues
WITH orphaned_stats AS (
    SELECT
        COUNT(*) as total_orphaned,
        COUNT(DISTINCT cv.client_id) as affected_clients,
        MIN(cv.created_at) as oldest_orphaned,
        MAX(cv.created_at) as newest_orphaned
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
    'DATABASE INTEGRITY SUMMARY' as report_section,
    ts.total_client_vouchers,
    ts.total_clients_with_vouchers,
    COALESCE(os.total_orphaned, 0) as orphaned_records,
    COALESCE(os.affected_clients, 0) as affected_clients,
    CASE 
        WHEN COALESCE(os.total_orphaned, 0) = 0 THEN 'HEALTHY'
        WHEN COALESCE(os.total_orphaned, 0) < 10 THEN 'MINOR_ISSUES'
        ELSE 'CRITICAL_ISSUES'
    END as integrity_status,
    os.oldest_orphaned,
    os.newest_orphaned
FROM total_stats ts
CROSS JOIN orphaned_stats os;

-- ============================================================================
-- INVESTIGATION COMPLETE
-- ============================================================================

-- Instructions:
-- 1. Run this script in Supabase SQL Editor
-- 2. Review the results to understand the scope of the integrity issues
-- 3. Use the findings to determine the best cleanup strategy
-- 4. Proceed with the cleanup script if orphaned records are found
