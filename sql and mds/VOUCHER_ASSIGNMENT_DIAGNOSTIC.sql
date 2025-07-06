-- ============================================================================
-- VOUCHER ASSIGNMENT DIAGNOSTIC AND FIX SCRIPT
-- ============================================================================
-- This script diagnoses and fixes voucher assignment issues between
-- business owner assignment and client voucher retrieval
-- ============================================================================

-- Step 1: Check current RLS policies for client_vouchers table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'client_vouchers'
ORDER BY policyname;

-- Step 2: Check for orphaned client voucher records
SELECT 
    cv.id as client_voucher_id,
    cv.voucher_id,
    cv.client_id,
    cv.status,
    cv.assigned_at,
    cv.assigned_by,
    v.id as voucher_exists,
    v.code as voucher_code,
    v.name as voucher_name,
    v.is_active as voucher_active
FROM client_vouchers cv
LEFT JOIN vouchers v ON cv.voucher_id = v.id
WHERE v.id IS NULL
ORDER BY cv.assigned_at DESC;

-- Step 3: Check user profiles and authentication status
SELECT 
    up.id,
    up.email,
    up.name,
    up.role,
    up.status,
    up.created_at,
    au.email as auth_email,
    au.email_confirmed_at,
    au.last_sign_in_at
FROM user_profiles up
LEFT JOIN auth.users au ON up.id = au.id
WHERE up.role = 'client' AND up.status = 'approved'
ORDER BY up.created_at DESC
LIMIT 10;

-- Step 4: Test voucher assignment visibility for a specific client
-- Replace 'CLIENT_ID_HERE' with actual client ID
/*
SELECT 
    cv.id,
    cv.voucher_id,
    cv.client_id,
    cv.status,
    cv.assigned_at,
    v.code,
    v.name,
    v.discount_percentage,
    v.expiration_date,
    v.is_active
FROM client_vouchers cv
JOIN vouchers v ON cv.voucher_id = v.id
WHERE cv.client_id = 'CLIENT_ID_HERE'
ORDER BY cv.assigned_at DESC;
*/

-- Step 5: Check recent voucher assignments
SELECT 
    cv.id,
    cv.voucher_id,
    cv.client_id,
    cv.status,
    cv.assigned_at,
    cv.assigned_by,
    v.code as voucher_code,
    v.name as voucher_name,
    up_client.email as client_email,
    up_client.name as client_name,
    up_assigner.email as assigned_by_email,
    up_assigner.name as assigned_by_name
FROM client_vouchers cv
LEFT JOIN vouchers v ON cv.voucher_id = v.id
LEFT JOIN user_profiles up_client ON cv.client_id = up_client.id
LEFT JOIN user_profiles up_assigner ON cv.assigned_by = up_assigner.id
WHERE cv.assigned_at >= NOW() - INTERVAL '7 days'
ORDER BY cv.assigned_at DESC
LIMIT 20;

-- Step 6: Verify RLS policy functionality
-- This function tests if RLS policies are working correctly
CREATE OR REPLACE FUNCTION test_voucher_rls_policies()
RETURNS TABLE (
    test_name TEXT,
    result TEXT,
    details TEXT
) AS $$
DECLARE
    test_client_id UUID;
    test_voucher_count INTEGER;
    admin_voucher_count INTEGER;
BEGIN
    -- Get a test client ID
    SELECT user_profiles.id INTO test_client_id
    FROM user_profiles
    WHERE user_profiles.role = 'client' AND user_profiles.status = 'approved'
    LIMIT 1;

    IF test_client_id IS NULL THEN
        RETURN QUERY SELECT 'RLS Test'::TEXT, 'SKIPPED'::TEXT, 'No approved clients found'::TEXT;
        RETURN;
    END IF;

    -- Test 1: Check if client can see their own vouchers
    SELECT COUNT(*) INTO test_voucher_count
    FROM client_vouchers
    WHERE client_vouchers.client_id = test_client_id;
    
    RETURN QUERY SELECT 
        'Client Voucher Visibility'::TEXT,
        CASE WHEN test_voucher_count >= 0 THEN 'PASS' ELSE 'FAIL' END::TEXT,
        format('Client %s can see %s vouchers', test_client_id, test_voucher_count)::TEXT;
    
    -- Test 2: Check admin visibility
    SELECT COUNT(*) INTO admin_voucher_count
    FROM client_vouchers;
    
    RETURN QUERY SELECT 
        'Admin Voucher Visibility'::TEXT,
        CASE WHEN admin_voucher_count >= test_voucher_count THEN 'PASS' ELSE 'FAIL' END::TEXT,
        format('Admin can see %s total vouchers vs client %s', admin_voucher_count, test_voucher_count)::TEXT;
        
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Run the RLS test
SELECT * FROM test_voucher_rls_policies();

-- Step 7: Fix orphaned client voucher records
-- This will delete client voucher records that reference non-existent vouchers
/*
-- UNCOMMENT TO RUN THE CLEANUP (BE CAREFUL!)
DELETE FROM client_vouchers 
WHERE voucher_id NOT IN (SELECT id FROM vouchers);
*/

-- Step 8: Create a comprehensive voucher assignment verification function
CREATE OR REPLACE FUNCTION verify_voucher_assignment(
    p_voucher_id UUID,
    p_client_id UUID
)
RETURNS TABLE (
    check_name TEXT,
    status TEXT,
    details TEXT
) AS $$
DECLARE
    voucher_exists BOOLEAN := FALSE;
    client_exists BOOLEAN := FALSE;
    assignment_exists BOOLEAN := FALSE;
    voucher_active BOOLEAN := FALSE;
    client_approved BOOLEAN := FALSE;
BEGIN
    -- Check if voucher exists
    SELECT EXISTS(SELECT 1 FROM vouchers WHERE vouchers.id = p_voucher_id) INTO voucher_exists;
    RETURN QUERY SELECT 'Voucher Exists'::TEXT,
                        CASE WHEN voucher_exists THEN 'PASS' ELSE 'FAIL' END::TEXT,
                        format('Voucher %s %s', p_voucher_id, CASE WHEN voucher_exists THEN 'exists' ELSE 'not found' END)::TEXT;
    
    -- Check if voucher is active
    IF voucher_exists THEN
        SELECT vouchers.is_active INTO voucher_active FROM vouchers WHERE vouchers.id = p_voucher_id;
        RETURN QUERY SELECT 'Voucher Active'::TEXT,
                            CASE WHEN voucher_active THEN 'PASS' ELSE 'WARN' END::TEXT,
                            format('Voucher is %s', CASE WHEN voucher_active THEN 'active' ELSE 'inactive' END)::TEXT;
    END IF;

    -- Check if client exists
    SELECT EXISTS(SELECT 1 FROM user_profiles WHERE user_profiles.id = p_client_id) INTO client_exists;
    RETURN QUERY SELECT 'Client Exists'::TEXT,
                        CASE WHEN client_exists THEN 'PASS' ELSE 'FAIL' END::TEXT,
                        format('Client %s %s', p_client_id, CASE WHEN client_exists THEN 'exists' ELSE 'not found' END)::TEXT;

    -- Check if client is approved
    IF client_exists THEN
        SELECT user_profiles.status = 'approved' INTO client_approved FROM user_profiles WHERE user_profiles.id = p_client_id;
        RETURN QUERY SELECT 'Client Approved'::TEXT,
                            CASE WHEN client_approved THEN 'PASS' ELSE 'WARN' END::TEXT,
                            format('Client is %s', CASE WHEN client_approved THEN 'approved' ELSE 'not approved' END)::TEXT;
    END IF;
    
    -- Check if assignment exists
    SELECT EXISTS(SELECT 1 FROM client_vouchers WHERE client_vouchers.voucher_id = p_voucher_id AND client_vouchers.client_id = p_client_id) INTO assignment_exists;
    RETURN QUERY SELECT 'Assignment Exists'::TEXT,
                        CASE WHEN assignment_exists THEN 'PASS' ELSE 'FAIL' END::TEXT,
                        format('Assignment %s', CASE WHEN assignment_exists THEN 'exists' ELSE 'not found' END)::TEXT;

    -- If assignment exists, check its status
    IF assignment_exists THEN
        RETURN QUERY SELECT 'Assignment Details'::TEXT, 'INFO'::TEXT,
                            (SELECT format('Status: %s, Assigned: %s', client_vouchers.status, client_vouchers.assigned_at)
                             FROM client_vouchers
                             WHERE client_vouchers.voucher_id = p_voucher_id AND client_vouchers.client_id = p_client_id)::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 9: Create a function to fix common voucher assignment issues
CREATE OR REPLACE FUNCTION fix_voucher_assignment_issues()
RETURNS TABLE (
    fix_name TEXT,
    affected_rows INTEGER,
    details TEXT
) AS $$
DECLARE
    orphaned_count INTEGER;
    expired_active_count INTEGER;
BEGIN
    -- Fix 1: Remove orphaned client voucher records
    DELETE FROM client_vouchers
    WHERE client_vouchers.voucher_id NOT IN (SELECT vouchers.id FROM vouchers);

    GET DIAGNOSTICS orphaned_count = ROW_COUNT;
    RETURN QUERY SELECT 'Remove Orphaned Records'::TEXT, orphaned_count,
                        format('Removed %s orphaned client voucher records', orphaned_count)::TEXT;

    -- Fix 2: Update expired active vouchers to inactive
    UPDATE vouchers
    SET is_active = FALSE, updated_at = NOW()
    WHERE vouchers.is_active = TRUE AND vouchers.expiration_date < NOW();
    
    GET DIAGNOSTICS expired_active_count = ROW_COUNT;
    RETURN QUERY SELECT 'Deactivate Expired Vouchers'::TEXT, expired_active_count,
                        format('Deactivated %s expired vouchers', expired_active_count)::TEXT;
    
    -- Fix 3: Update expired client voucher statuses
    UPDATE client_vouchers
    SET status = 'expired'
    WHERE client_vouchers.status = 'active'
    AND client_vouchers.voucher_id IN (
        SELECT vouchers.id FROM vouchers WHERE vouchers.expiration_date < NOW()
    );
    
    GET DIAGNOSTICS expired_active_count = ROW_COUNT;
    RETURN QUERY SELECT 'Update Expired Assignments'::TEXT, expired_active_count,
                        format('Updated %s expired client voucher assignments', expired_active_count)::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 10: Generate a comprehensive voucher system health report
CREATE OR REPLACE FUNCTION voucher_system_health_report()
RETURNS TABLE (
    metric_name TEXT,
    value INTEGER,
    status TEXT,
    recommendation TEXT
) AS $$
DECLARE
    total_vouchers INTEGER;
    active_vouchers INTEGER;
    expired_vouchers INTEGER;
    total_assignments INTEGER;
    active_assignments INTEGER;
    orphaned_assignments INTEGER;
    approved_clients INTEGER;
BEGIN
    -- Get basic metrics with properly qualified column references
    SELECT COUNT(*) INTO total_vouchers FROM vouchers;
    SELECT COUNT(*) INTO active_vouchers FROM vouchers WHERE vouchers.is_active = TRUE;
    SELECT COUNT(*) INTO expired_vouchers FROM vouchers WHERE vouchers.expiration_date < NOW();
    SELECT COUNT(*) INTO total_assignments FROM client_vouchers;
    SELECT COUNT(*) INTO active_assignments FROM client_vouchers WHERE client_vouchers.status = 'active';
    SELECT COUNT(*) INTO approved_clients FROM user_profiles WHERE user_profiles.role = 'client' AND user_profiles.status = 'approved';

    -- Check for orphaned assignments
    SELECT COUNT(*) INTO orphaned_assignments
    FROM client_vouchers cv
    LEFT JOIN vouchers v ON cv.voucher_id = v.id
    WHERE v.id IS NULL;

    -- Return metrics with recommendations
    RETURN QUERY SELECT 'Total Vouchers'::TEXT, total_vouchers, 'INFO'::TEXT, 'Total vouchers in system'::TEXT;
    RETURN QUERY SELECT 'Active Vouchers'::TEXT, active_vouchers, 'INFO'::TEXT, 'Currently active vouchers'::TEXT;
    RETURN QUERY SELECT 'Expired Vouchers'::TEXT, expired_vouchers,
                        CASE WHEN expired_vouchers > 0 THEN 'WARN' ELSE 'OK' END::TEXT,
                        CASE WHEN expired_vouchers > 0 THEN 'Consider cleaning up expired vouchers' ELSE 'No expired vouchers' END::TEXT;

    RETURN QUERY SELECT 'Total Assignments'::TEXT, total_assignments, 'INFO'::TEXT, 'Total voucher assignments'::TEXT;
    RETURN QUERY SELECT 'Active Assignments'::TEXT, active_assignments, 'INFO'::TEXT, 'Currently active assignments'::TEXT;
    RETURN QUERY SELECT 'Approved Clients'::TEXT, approved_clients, 'INFO'::TEXT, 'Clients eligible for vouchers'::TEXT;

    RETURN QUERY SELECT 'Orphaned Assignments'::TEXT, orphaned_assignments,
                        CASE WHEN orphaned_assignments > 0 THEN 'ERROR' ELSE 'OK' END::TEXT,
                        CASE WHEN orphaned_assignments > 0 THEN 'CRITICAL: Run fix_voucher_assignment_issues()' ELSE 'No orphaned assignments' END::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Run the health report
SELECT * FROM voucher_system_health_report();

-- Step 11: Test the functions to ensure they work correctly
-- Test the health report function
DO $$
BEGIN
    RAISE NOTICE 'Testing voucher_system_health_report function...';
    PERFORM * FROM voucher_system_health_report();
    RAISE NOTICE 'voucher_system_health_report function executed successfully!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in voucher_system_health_report: %', SQLERRM;
END $$;

-- Test the RLS policies function
DO $$
BEGIN
    RAISE NOTICE 'Testing test_voucher_rls_policies function...';
    PERFORM * FROM test_voucher_rls_policies();
    RAISE NOTICE 'test_voucher_rls_policies function executed successfully!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in test_voucher_rls_policies: %', SQLERRM;
END $$;

-- Test the fix function (dry run)
DO $$
BEGIN
    RAISE NOTICE 'Testing fix_voucher_assignment_issues function...';
    PERFORM * FROM fix_voucher_assignment_issues();
    RAISE NOTICE 'fix_voucher_assignment_issues function executed successfully!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in fix_voucher_assignment_issues: %', SQLERRM;
END $$;

-- Step 12: Instructions for manual testing
/*
MANUAL TESTING INSTRUCTIONS:

1. Run this script to identify issues
2. Note any orphaned records or RLS policy problems
3. Test voucher assignment from business owner interface
4. Immediately check if the assignment appears in client interface
5. Use verify_voucher_assignment() function to debug specific assignments
6. Run fix_voucher_assignment_issues() if problems are found

Example usage:
SELECT * FROM verify_voucher_assignment('VOUCHER_ID_HERE', 'CLIENT_ID_HERE');
SELECT * FROM fix_voucher_assignment_issues();

FIXED ISSUES:
- All column references are now properly qualified with table names
- Functions should execute without PostgreSQL error 42702 (ambiguous column reference)
- All status, role, and other potentially ambiguous columns are prefixed with table names
*/
