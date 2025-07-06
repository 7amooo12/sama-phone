-- ============================================================================
-- DATABASE INTEGRITY MONITORING FOR VOUCHER SYSTEM
-- ============================================================================
-- This script provides ongoing monitoring and maintenance functions
-- for the voucher system database integrity

-- ============================================================================
-- STEP 1: Create Monitoring Views for Easy Access
-- ============================================================================

-- View for orphaned client vouchers
CREATE OR REPLACE VIEW public.v_orphaned_client_vouchers AS
SELECT 
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

-- View for voucher system health summary
CREATE OR REPLACE VIEW public.v_voucher_system_health AS
SELECT 
    'Total Vouchers' as metric,
    COUNT(*)::TEXT as value,
    'Active: ' || SUM(CASE WHEN is_active THEN 1 ELSE 0 END)::TEXT ||
    ', Expired: ' || SUM(CASE WHEN expiration_date < NOW() THEN 1 ELSE 0 END)::TEXT as details
FROM public.vouchers
UNION ALL
SELECT 
    'Total Client Vouchers' as metric,
    COUNT(*)::TEXT as value,
    'Active: ' || SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END)::TEXT ||
    ', Used: ' || SUM(CASE WHEN status = 'used' THEN 1 ELSE 0 END)::TEXT ||
    ', Expired: ' || SUM(CASE WHEN status = 'expired' THEN 1 ELSE 0 END)::TEXT as details
FROM public.client_vouchers
UNION ALL
SELECT 
    'Orphaned Client Vouchers' as metric,
    COUNT(*)::TEXT as value,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ No issues found'
        WHEN COUNT(*) < 5 THEN '⚠️ Minor issues'
        ELSE '🚨 Critical issues'
    END as details
FROM public.v_orphaned_client_vouchers
UNION ALL
SELECT 
    'Recovery Vouchers' as metric,
    COUNT(*)::TEXT as value,
    'Vouchers created for recovery purposes' as details
FROM public.vouchers
WHERE metadata->>'recovery' = 'true';

-- ============================================================================
-- STEP 2: Enhanced Monitoring Functions
-- ============================================================================

-- Function to get detailed integrity report
CREATE OR REPLACE FUNCTION get_voucher_integrity_report()
RETURNS TABLE (
    section TEXT,
    metric TEXT,
    value TEXT,
    status TEXT,
    recommendation TEXT
) AS $$
BEGIN
    -- Orphaned vouchers check
    RETURN QUERY
    SELECT 
        'Database Integrity'::TEXT as section,
        'Orphaned Client Vouchers'::TEXT as metric,
        COUNT(*)::TEXT as value,
        CASE 
            WHEN COUNT(*) = 0 THEN 'HEALTHY'
            WHEN COUNT(*) < 5 THEN 'WARNING'
            ELSE 'CRITICAL'
        END::TEXT as status,
        CASE 
            WHEN COUNT(*) = 0 THEN 'No action needed'
            ELSE 'Run DATABASE_INTEGRITY_CLEANUP.sql immediately'
        END::TEXT as recommendation
    FROM public.v_orphaned_client_vouchers;
    
    -- Expired active vouchers check
    RETURN QUERY
    SELECT 
        'Voucher Status'::TEXT as section,
        'Expired Active Vouchers'::TEXT as metric,
        COUNT(*)::TEXT as value,
        CASE 
            WHEN COUNT(*) = 0 THEN 'HEALTHY'
            WHEN COUNT(*) < 10 THEN 'WARNING'
            ELSE 'CRITICAL'
        END::TEXT as status,
        CASE 
            WHEN COUNT(*) = 0 THEN 'No action needed'
            ELSE 'Run cleanup_expired_vouchers() function'
        END::TEXT as recommendation
    FROM public.vouchers
    WHERE is_active = true AND expiration_date < NOW();
    
    -- Client vouchers with invalid status
    RETURN QUERY
    SELECT 
        'Data Consistency'::TEXT as section,
        'Invalid Client Voucher Status'::TEXT as metric,
        COUNT(*)::TEXT as value,
        CASE 
            WHEN COUNT(*) = 0 THEN 'HEALTHY'
            ELSE 'WARNING'
        END::TEXT as status,
        CASE 
            WHEN COUNT(*) = 0 THEN 'No action needed'
            ELSE 'Update client voucher statuses to match voucher expiration'
        END::TEXT as recommendation
    FROM public.client_vouchers cv
    JOIN public.vouchers v ON cv.voucher_id = v.id
    WHERE cv.status = 'active' AND (v.is_active = false OR v.expiration_date < NOW());
    
    -- Recovery vouchers status
    RETURN QUERY
    SELECT 
        'Recovery Status'::TEXT as section,
        'Recovery Vouchers Created'::TEXT as metric,
        COUNT(*)::TEXT as value,
        CASE 
            WHEN COUNT(*) = 0 THEN 'HEALTHY'
            ELSE 'INFO'
        END::TEXT as status,
        CASE 
            WHEN COUNT(*) = 0 THEN 'No recovery vouchers found'
            ELSE 'Review and activate recovery vouchers if needed'
        END::TEXT as recommendation
    FROM public.vouchers
    WHERE metadata->>'recovery' = 'true';
END;
$$ LANGUAGE plpgsql;

-- Function to automatically fix common integrity issues
CREATE OR REPLACE FUNCTION auto_fix_voucher_integrity()
RETURNS TABLE (
    action TEXT,
    records_affected INTEGER,
    status TEXT,
    details TEXT
) AS $$
DECLARE
    expired_vouchers_count INTEGER;
    invalid_status_count INTEGER;
BEGIN
    -- Fix expired active vouchers
    UPDATE public.vouchers 
    SET is_active = false, updated_at = NOW()
    WHERE is_active = true AND expiration_date < NOW();
    
    GET DIAGNOSTICS expired_vouchers_count = ROW_COUNT;
    
    RETURN QUERY
    SELECT 
        'Deactivate Expired Vouchers'::TEXT,
        expired_vouchers_count,
        CASE WHEN expired_vouchers_count > 0 THEN 'FIXED' ELSE 'NO_ACTION_NEEDED' END::TEXT,
        'Set is_active=false for expired vouchers'::TEXT;
    
    -- Fix client voucher statuses for expired vouchers
    UPDATE public.client_vouchers 
    SET status = 'expired', updated_at = NOW()
    WHERE status = 'active' 
    AND voucher_id IN (
        SELECT id FROM public.vouchers 
        WHERE expiration_date < NOW()
    );
    
    GET DIAGNOSTICS invalid_status_count = ROW_COUNT;
    
    RETURN QUERY
    SELECT 
        'Update Client Voucher Status'::TEXT,
        invalid_status_count,
        CASE WHEN invalid_status_count > 0 THEN 'FIXED' ELSE 'NO_ACTION_NEEDED' END::TEXT,
        'Updated client voucher status to expired for expired vouchers'::TEXT;
    
    -- Log the auto-fix actions
    INSERT INTO public.database_cleanup_log (
        cleanup_type,
        table_name,
        records_affected,
        details
    ) VALUES 
    (
        'auto_fix_integrity',
        'vouchers',
        expired_vouchers_count,
        jsonb_build_object(
            'action', 'deactivate_expired_vouchers',
            'timestamp', NOW()
        )
    ),
    (
        'auto_fix_integrity',
        'client_vouchers',
        invalid_status_count,
        jsonb_build_object(
            'action', 'update_expired_status',
            'timestamp', NOW()
        )
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 3: Automated Monitoring Triggers
-- ============================================================================

-- Function to log voucher deletions for audit trail
CREATE OR REPLACE FUNCTION log_voucher_deletion()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.database_cleanup_log (
        cleanup_type,
        table_name,
        records_affected,
        details
    ) VALUES (
        'voucher_deletion',
        'vouchers',
        1,
        jsonb_build_object(
            'deleted_voucher_id', OLD.id,
            'voucher_code', OLD.code,
            'voucher_name', OLD.name,
            'deletion_timestamp', NOW(),
            'deleted_by', auth.uid()
        )
    );
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for voucher deletions
DROP TRIGGER IF EXISTS trigger_log_voucher_deletion ON public.vouchers;
CREATE TRIGGER trigger_log_voucher_deletion
    BEFORE DELETE ON public.vouchers
    FOR EACH ROW
    EXECUTE FUNCTION log_voucher_deletion();

-- ============================================================================
-- STEP 4: Scheduled Maintenance Functions
-- ============================================================================

-- Function for daily maintenance
CREATE OR REPLACE FUNCTION daily_voucher_maintenance()
RETURNS TEXT AS $$
DECLARE
    maintenance_summary TEXT;
    orphaned_count INTEGER;
    expired_fixed INTEGER;
BEGIN
    -- Check for orphaned records
    SELECT COUNT(*) INTO orphaned_count FROM public.v_orphaned_client_vouchers;
    
    -- Auto-fix common issues
    SELECT SUM(records_affected) INTO expired_fixed 
    FROM auto_fix_voucher_integrity() 
    WHERE action = 'Deactivate Expired Vouchers';
    
    -- Generate summary
    maintenance_summary := format(
        'Daily Maintenance Summary (%s): Orphaned Records: %s, Expired Vouchers Fixed: %s',
        NOW()::DATE,
        COALESCE(orphaned_count, 0),
        COALESCE(expired_fixed, 0)
    );
    
    -- Log maintenance activity
    INSERT INTO public.database_cleanup_log (
        cleanup_type,
        table_name,
        records_affected,
        details
    ) VALUES (
        'daily_maintenance',
        'voucher_system',
        COALESCE(expired_fixed, 0),
        jsonb_build_object(
            'orphaned_count', COALESCE(orphaned_count, 0),
            'expired_fixed', COALESCE(expired_fixed, 0),
            'maintenance_date', NOW()::DATE,
            'summary', maintenance_summary
        )
    );
    
    RETURN maintenance_summary;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 5: Quick Health Check Queries
-- ============================================================================

-- Quick health check (run this regularly)
-- SELECT * FROM public.v_voucher_system_health;

-- Detailed integrity report
-- SELECT * FROM get_voucher_integrity_report();

-- Auto-fix common issues
-- SELECT * FROM auto_fix_voucher_integrity();

-- Daily maintenance
-- SELECT daily_voucher_maintenance();

-- View orphaned records
-- SELECT * FROM public.v_orphaned_client_vouchers;

-- ============================================================================
-- MONITORING SETUP COMPLETE
-- ============================================================================

-- Grant necessary permissions
GRANT SELECT ON public.v_orphaned_client_vouchers TO authenticated;
GRANT SELECT ON public.v_voucher_system_health TO authenticated;
GRANT EXECUTE ON FUNCTION get_voucher_integrity_report() TO authenticated;
GRANT EXECUTE ON FUNCTION auto_fix_voucher_integrity() TO service_role;
GRANT EXECUTE ON FUNCTION daily_voucher_maintenance() TO service_role;

-- Instructions:
-- 1. Run this script to set up monitoring infrastructure
-- 2. Schedule daily_voucher_maintenance() to run daily
-- 3. Monitor v_voucher_system_health regularly
-- 4. Run get_voucher_integrity_report() for detailed analysis
-- 5. Use auto_fix_voucher_integrity() to fix common issues automatically
