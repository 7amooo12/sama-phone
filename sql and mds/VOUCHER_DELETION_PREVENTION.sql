-- ============================================================================
-- VOUCHER DELETION PREVENTION SYSTEM
-- ============================================================================
-- This script implements safeguards to prevent vouchers from being deleted
-- while active client assignments exist

-- ============================================================================
-- STEP 1: Create Enhanced Deletion Prevention Function
-- ============================================================================

-- Function to check if voucher can be safely deleted
CREATE OR REPLACE FUNCTION can_delete_voucher(voucher_id_param UUID)
RETURNS TABLE (
    can_delete BOOLEAN,
    reason TEXT,
    active_assignments INTEGER,
    used_assignments INTEGER,
    total_assignments INTEGER
) AS $$
DECLARE
    active_count INTEGER;
    used_count INTEGER;
    total_count INTEGER;
BEGIN
    -- Count assignments by status
    SELECT 
        COUNT(CASE WHEN status = 'active' THEN 1 END),
        COUNT(CASE WHEN status = 'used' THEN 1 END),
        COUNT(*)
    INTO active_count, used_count, total_count
    FROM public.client_vouchers
    WHERE voucher_id = voucher_id_param;
    
    -- Determine if deletion is safe
    IF total_count = 0 THEN
        RETURN QUERY SELECT 
            true,
            'No client assignments exist - safe to delete',
            active_count,
            used_count,
            total_count;
    ELSIF active_count > 0 THEN
        RETURN QUERY SELECT 
            false,
            format('Cannot delete: %s active assignments exist', active_count),
            active_count,
            used_count,
            total_count;
    ELSIF used_count > 0 THEN
        RETURN QUERY SELECT 
            false,
            format('Cannot delete: %s used assignments exist (historical data)', used_count),
            active_count,
            used_count,
            total_count;
    ELSE
        RETURN QUERY SELECT 
            true,
            'Only expired assignments exist - safe to delete',
            active_count,
            used_count,
            total_count;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 2: Create Deletion Prevention Trigger
-- ============================================================================

-- Function to prevent unsafe voucher deletions
CREATE OR REPLACE FUNCTION prevent_unsafe_voucher_deletion()
RETURNS TRIGGER AS $$
DECLARE
    deletion_check RECORD;
    admin_override BOOLEAN DEFAULT false;
BEGIN
    -- Check if this is an admin override (set in session)
    BEGIN
        admin_override := current_setting('voucher.allow_unsafe_deletion', true)::BOOLEAN;
    EXCEPTION WHEN OTHERS THEN
        admin_override := false;
    END;
    
    -- If admin override is enabled, allow deletion but log it
    IF admin_override THEN
        INSERT INTO public.database_cleanup_log (
            cleanup_type,
            table_name,
            records_affected,
            details
        ) VALUES (
            'admin_override_deletion',
            'vouchers',
            1,
            jsonb_build_object(
                'deleted_voucher_id', OLD.id,
                'voucher_code', OLD.code,
                'voucher_name', OLD.name,
                'override_timestamp', NOW(),
                'deleted_by', auth.uid(),
                'warning', 'Admin override used - deletion allowed despite active assignments'
            )
        );
        RETURN OLD;
    END IF;
    
    -- Check if deletion is safe
    SELECT * INTO deletion_check FROM can_delete_voucher(OLD.id);
    
    IF NOT deletion_check.can_delete THEN
        -- Log the prevented deletion attempt
        INSERT INTO public.database_cleanup_log (
            cleanup_type,
            table_name,
            records_affected,
            details
        ) VALUES (
            'prevented_deletion',
            'vouchers',
            0,
            jsonb_build_object(
                'voucher_id', OLD.id,
                'voucher_code', OLD.code,
                'voucher_name', OLD.name,
                'prevention_reason', deletion_check.reason,
                'active_assignments', deletion_check.active_assignments,
                'used_assignments', deletion_check.used_assignments,
                'total_assignments', deletion_check.total_assignments,
                'attempted_by', auth.uid(),
                'prevention_timestamp', NOW()
            )
        );
        
        -- Raise exception to prevent deletion
        RAISE EXCEPTION 'Voucher deletion prevented: %. Active assignments: %, Used assignments: %, Total: %', 
            deletion_check.reason,
            deletion_check.active_assignments,
            deletion_check.used_assignments,
            deletion_check.total_assignments
            USING ERRCODE = 'P0001';
    END IF;
    
    -- If we reach here, deletion is safe - log it
    INSERT INTO public.database_cleanup_log (
        cleanup_type,
        table_name,
        records_affected,
        details
    ) VALUES (
        'safe_voucher_deletion',
        'vouchers',
        1,
        jsonb_build_object(
            'deleted_voucher_id', OLD.id,
            'voucher_code', OLD.code,
            'voucher_name', OLD.name,
            'deletion_reason', deletion_check.reason,
            'deleted_by', auth.uid(),
            'deletion_timestamp', NOW()
        )
    );
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS trigger_prevent_unsafe_voucher_deletion ON public.vouchers;
CREATE TRIGGER trigger_prevent_unsafe_voucher_deletion
    BEFORE DELETE ON public.vouchers
    FOR EACH ROW
    EXECUTE FUNCTION prevent_unsafe_voucher_deletion();

-- ============================================================================
-- STEP 3: Create Safe Voucher Deletion Function
-- ============================================================================

-- Function for safe voucher deletion with checks
CREATE OR REPLACE FUNCTION safe_delete_voucher(
    voucher_id_param UUID,
    force_delete BOOLEAN DEFAULT false
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    assignments_affected INTEGER
) AS $$
DECLARE
    deletion_check RECORD;
    affected_assignments INTEGER;
BEGIN
    -- Check if deletion is safe
    SELECT * INTO deletion_check FROM can_delete_voucher(voucher_id_param);
    
    IF NOT deletion_check.can_delete AND NOT force_delete THEN
        RETURN QUERY SELECT 
            false,
            deletion_check.reason,
            deletion_check.total_assignments;
        RETURN;
    END IF;
    
    -- If force delete is enabled, set session variable for admin override
    IF force_delete THEN
        PERFORM set_config('voucher.allow_unsafe_deletion', 'true', true);
    END IF;
    
    -- Count assignments that will be affected
    SELECT COUNT(*) INTO affected_assignments
    FROM public.client_vouchers
    WHERE voucher_id = voucher_id_param;
    
    -- Perform the deletion
    DELETE FROM public.vouchers WHERE id = voucher_id_param;
    
    -- Reset the override setting
    IF force_delete THEN
        PERFORM set_config('voucher.allow_unsafe_deletion', 'false', true);
    END IF;
    
    RETURN QUERY SELECT 
        true,
        CASE 
            WHEN force_delete THEN 'Voucher force deleted successfully'
            ELSE 'Voucher safely deleted'
        END,
        affected_assignments;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 4: Create Voucher Deactivation Alternative
-- ============================================================================

-- Function to safely deactivate vouchers instead of deleting
CREATE OR REPLACE FUNCTION safe_deactivate_voucher(voucher_id_param UUID)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    active_assignments_updated INTEGER
) AS $$
DECLARE
    voucher_exists BOOLEAN;
    assignments_updated INTEGER;
BEGIN
    -- Check if voucher exists
    SELECT EXISTS(SELECT 1 FROM public.vouchers WHERE id = voucher_id_param)
    INTO voucher_exists;
    
    IF NOT voucher_exists THEN
        RETURN QUERY SELECT 
            false,
            'Voucher not found',
            0;
        RETURN;
    END IF;
    
    -- Deactivate the voucher
    UPDATE public.vouchers 
    SET is_active = false, updated_at = NOW()
    WHERE id = voucher_id_param;
    
    -- Update active client voucher assignments to expired
    UPDATE public.client_vouchers 
    SET status = 'expired', updated_at = NOW()
    WHERE voucher_id = voucher_id_param 
    AND status = 'active';
    
    GET DIAGNOSTICS assignments_updated = ROW_COUNT;
    
    -- Log the deactivation
    INSERT INTO public.database_cleanup_log (
        cleanup_type,
        table_name,
        records_affected,
        details
    ) VALUES (
        'safe_voucher_deactivation',
        'vouchers',
        1,
        jsonb_build_object(
            'voucher_id', voucher_id_param,
            'assignments_expired', assignments_updated,
            'deactivated_by', auth.uid(),
            'deactivation_timestamp', NOW(),
            'reason', 'Safe alternative to deletion'
        )
    );
    
    RETURN QUERY SELECT 
        true,
        format('Voucher deactivated successfully. %s active assignments expired.', assignments_updated),
        assignments_updated;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 5: Create Monitoring Views
-- ============================================================================

-- View for vouchers with active assignments (cannot be safely deleted)
CREATE OR REPLACE VIEW public.v_vouchers_with_active_assignments AS
SELECT 
    v.id,
    v.code,
    v.name,
    v.is_active,
    v.expiration_date,
    COUNT(cv.id) as total_assignments,
    COUNT(CASE WHEN cv.status = 'active' THEN 1 END) as active_assignments,
    COUNT(CASE WHEN cv.status = 'used' THEN 1 END) as used_assignments,
    COUNT(CASE WHEN cv.status = 'expired' THEN 1 END) as expired_assignments,
    CASE 
        WHEN COUNT(CASE WHEN cv.status = 'active' THEN 1 END) > 0 THEN 'CANNOT_DELETE'
        WHEN COUNT(CASE WHEN cv.status = 'used' THEN 1 END) > 0 THEN 'HISTORICAL_DATA'
        WHEN COUNT(cv.id) = 0 THEN 'SAFE_TO_DELETE'
        ELSE 'SAFE_TO_DELETE'
    END as deletion_safety
FROM public.vouchers v
LEFT JOIN public.client_vouchers cv ON v.id = cv.voucher_id
GROUP BY v.id, v.code, v.name, v.is_active, v.expiration_date
ORDER BY active_assignments DESC, total_assignments DESC;

-- ============================================================================
-- STEP 6: Grant Permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION can_delete_voucher(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION safe_delete_voucher(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION safe_deactivate_voucher(UUID) TO authenticated;
GRANT SELECT ON public.v_vouchers_with_active_assignments TO authenticated;

-- ============================================================================
-- PREVENTION SYSTEM COMPLETE
-- ============================================================================

-- Usage Examples:
-- 1. Check if voucher can be deleted: SELECT * FROM can_delete_voucher('voucher-id-here');
-- 2. Safe delete: SELECT * FROM safe_delete_voucher('voucher-id-here', false);
-- 3. Force delete: SELECT * FROM safe_delete_voucher('voucher-id-here', true);
-- 4. Safe deactivate: SELECT * FROM safe_deactivate_voucher('voucher-id-here');
-- 5. View protected vouchers: SELECT * FROM v_vouchers_with_active_assignments;
