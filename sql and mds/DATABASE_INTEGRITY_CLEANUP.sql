-- ============================================================================
-- DATABASE INTEGRITY CLEANUP FOR VOUCHER SYSTEM
-- ============================================================================
-- This script cleans up orphaned client_vouchers records and restores integrity
-- WARNING: This script will DELETE orphaned records. Review carefully before running.

-- ============================================================================
-- STEP 1: Backup Orphaned Records Before Cleanup
-- ============================================================================

-- Create a backup table for orphaned records (for recovery if needed)
CREATE TABLE IF NOT EXISTS public.orphaned_client_vouchers_backup (
    id UUID,
    voucher_id UUID,
    client_id UUID,
    status TEXT,
    used_at TIMESTAMP WITH TIME ZONE,
    order_id UUID,
    discount_amount DECIMAL(10, 2),
    assigned_by UUID,
    assigned_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB,
    backup_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    backup_reason TEXT DEFAULT 'Orphaned voucher cleanup'
);

-- Insert orphaned records into backup table
INSERT INTO public.orphaned_client_vouchers_backup (
    id, voucher_id, client_id, status, used_at, order_id, 
    discount_amount, assigned_by, assigned_at, created_at, 
    updated_at, metadata
)
SELECT 
    cv.id, cv.voucher_id, cv.client_id, cv.status, cv.used_at, cv.order_id,
    cv.discount_amount, cv.assigned_by, cv.assigned_at, cv.created_at,
    cv.updated_at, cv.metadata
FROM public.client_vouchers cv
LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
WHERE v.id IS NULL;

-- ============================================================================
-- STEP 2: Log Cleanup Activity
-- ============================================================================

-- Create cleanup log table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.database_cleanup_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cleanup_type TEXT NOT NULL,
    table_name TEXT NOT NULL,
    records_affected INTEGER NOT NULL,
    cleanup_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    details JSONB,
    performed_by UUID REFERENCES auth.users(id)
);

-- ============================================================================
-- STEP 3: Attempt to Restore Missing Vouchers (if possible)
-- ============================================================================

-- Check if we can restore vouchers from any backup or audit trail
-- This section would need to be customized based on your backup strategy

-- For now, we'll create placeholder vouchers for critical orphaned records
-- that are still active and might be needed

DO $$
DECLARE
    orphaned_record RECORD;
    new_voucher_id UUID;
    voucher_code TEXT;
BEGIN
    -- Loop through active orphaned client vouchers
    FOR orphaned_record IN 
        SELECT DISTINCT cv.voucher_id, COUNT(*) as assignment_count
        FROM public.client_vouchers cv
        LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
        WHERE v.id IS NULL 
        AND cv.status = 'active'
        GROUP BY cv.voucher_id
        HAVING COUNT(*) > 0
    LOOP
        -- Generate a recovery voucher code
        voucher_code := 'RECOVERY-' || EXTRACT(EPOCH FROM NOW())::BIGINT || '-' || SUBSTRING(orphaned_record.voucher_id::TEXT, 1, 6);
        
        -- Create a recovery voucher with the original ID
        INSERT INTO public.vouchers (
            id,
            code,
            name,
            description,
            type,
            target_id,
            target_name,
            discount_percentage,
            expiration_date,
            is_active,
            created_by,
            created_at,
            updated_at,
            metadata
        ) VALUES (
            orphaned_record.voucher_id,
            voucher_code,
            'قسيمة مستردة - Recovery Voucher',
            'تم إنشاء هذه القسيمة لاستعادة التعيينات المفقودة - This voucher was created to recover lost assignments',
            'product',
            'recovery-product',
            'منتج الاسترداد - Recovery Product',
            10, -- Default 10% discount
            NOW() + INTERVAL '1 year', -- Valid for 1 year
            false, -- Inactive by default
            (SELECT id FROM auth.users LIMIT 1), -- Use first available user as creator
            NOW(),
            NOW(),
            jsonb_build_object(
                'recovery', true,
                'original_voucher_id', orphaned_record.voucher_id,
                'assignment_count', orphaned_record.assignment_count,
                'recovery_timestamp', NOW()
            )
        )
        ON CONFLICT (id) DO NOTHING; -- Skip if voucher already exists
        
        RAISE NOTICE 'Created recovery voucher % for % assignments', voucher_code, orphaned_record.assignment_count;
    END LOOP;
END $$;

-- ============================================================================
-- STEP 4: Clean Up Remaining Orphaned Records
-- ============================================================================

-- Log the cleanup operation
INSERT INTO public.database_cleanup_log (
    cleanup_type,
    table_name,
    records_affected,
    details
) 
SELECT 
    'orphaned_records_cleanup',
    'client_vouchers',
    COUNT(*),
    jsonb_build_object(
        'orphaned_voucher_ids', array_agg(DISTINCT cv.voucher_id),
        'affected_clients', array_agg(DISTINCT cv.client_id),
        'cleanup_reason', 'Foreign key integrity violation - voucher records missing'
    )
FROM public.client_vouchers cv
LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
WHERE v.id IS NULL;

-- Delete orphaned client_vouchers that couldn't be recovered
-- Only delete records where vouchers still don't exist after recovery attempt
DELETE FROM public.client_vouchers 
WHERE id IN (
    SELECT cv.id
    FROM public.client_vouchers cv
    LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
    WHERE v.id IS NULL
);

-- ============================================================================
-- STEP 5: Strengthen Foreign Key Constraints
-- ============================================================================

-- Ensure foreign key constraints are properly enforced
-- The constraint should already exist, but let's verify and recreate if needed

DO $$
BEGIN
    -- Check if the foreign key constraint exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'client_vouchers_voucher_id_fkey' 
        AND table_name = 'client_vouchers'
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        -- Add the foreign key constraint if it doesn't exist
        ALTER TABLE public.client_vouchers 
        ADD CONSTRAINT client_vouchers_voucher_id_fkey 
        FOREIGN KEY (voucher_id) REFERENCES public.vouchers(id) ON DELETE CASCADE;
        
        RAISE NOTICE 'Added missing foreign key constraint for voucher_id';
    ELSE
        RAISE NOTICE 'Foreign key constraint already exists';
    END IF;
END $$;

-- ============================================================================
-- STEP 6: Create Integrity Monitoring Functions
-- ============================================================================

-- Function to check voucher system integrity
CREATE OR REPLACE FUNCTION check_voucher_integrity()
RETURNS TABLE (
    check_name TEXT,
    status TEXT,
    issue_count INTEGER,
    details TEXT
) AS $$
BEGIN
    -- Check for orphaned client vouchers
    RETURN QUERY
    SELECT 
        'orphaned_client_vouchers'::TEXT,
        CASE WHEN COUNT(*) = 0 THEN 'HEALTHY' ELSE 'ISSUES_FOUND' END::TEXT,
        COUNT(*)::INTEGER,
        'Client vouchers referencing non-existent vouchers'::TEXT
    FROM public.client_vouchers cv
    LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
    WHERE v.id IS NULL;
    
    -- Check for expired active vouchers
    RETURN QUERY
    SELECT 
        'expired_active_vouchers'::TEXT,
        CASE WHEN COUNT(*) = 0 THEN 'HEALTHY' ELSE 'ISSUES_FOUND' END::TEXT,
        COUNT(*)::INTEGER,
        'Active vouchers that have passed expiration date'::TEXT
    FROM public.vouchers
    WHERE is_active = true AND expiration_date < NOW();
    
    -- Check for client vouchers with invalid status
    RETURN QUERY
    SELECT 
        'invalid_voucher_status'::TEXT,
        CASE WHEN COUNT(*) = 0 THEN 'HEALTHY' ELSE 'ISSUES_FOUND' END::TEXT,
        COUNT(*)::INTEGER,
        'Client vouchers with inconsistent status'::TEXT
    FROM public.client_vouchers cv
    JOIN public.vouchers v ON cv.voucher_id = v.id
    WHERE cv.status = 'active' AND (v.is_active = false OR v.expiration_date < NOW());
END;
$$ LANGUAGE plpgsql;

-- Function to automatically clean up expired vouchers
CREATE OR REPLACE FUNCTION cleanup_expired_vouchers()
RETURNS INTEGER AS $$
DECLARE
    affected_count INTEGER;
BEGIN
    -- Update client vouchers status for expired vouchers
    UPDATE public.client_vouchers 
    SET status = 'expired', updated_at = NOW()
    WHERE status = 'active' 
    AND voucher_id IN (
        SELECT id FROM public.vouchers 
        WHERE expiration_date < NOW()
    );
    
    GET DIAGNOSTICS affected_count = ROW_COUNT;
    
    -- Log the cleanup
    INSERT INTO public.database_cleanup_log (
        cleanup_type,
        table_name,
        records_affected,
        details
    ) VALUES (
        'expired_vouchers_cleanup',
        'client_vouchers',
        affected_count,
        jsonb_build_object(
            'cleanup_timestamp', NOW(),
            'action', 'Updated expired active vouchers to expired status'
        )
    );
    
    RETURN affected_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 7: Final Verification
-- ============================================================================

-- Run integrity check
SELECT * FROM check_voucher_integrity();

-- Show cleanup summary
SELECT 
    'CLEANUP SUMMARY' as section,
    (SELECT COUNT(*) FROM public.orphaned_client_vouchers_backup) as backed_up_records,
    (SELECT COUNT(*) FROM public.client_vouchers cv LEFT JOIN public.vouchers v ON cv.voucher_id = v.id WHERE v.id IS NULL) as remaining_orphaned,
    (SELECT COUNT(*) FROM public.vouchers WHERE metadata->>'recovery' = 'true') as recovery_vouchers_created;

-- ============================================================================
-- CLEANUP COMPLETE
-- ============================================================================

-- Instructions for next steps:
-- 1. Review the cleanup summary above
-- 2. Test the voucher system functionality
-- 3. Monitor for any new integrity issues
-- 4. Consider setting up automated monitoring using the created functions
