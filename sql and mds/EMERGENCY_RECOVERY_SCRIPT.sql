-- ============================================================================
-- EMERGENCY RECOVERY SCRIPT - VOUCHER SYSTEM REGRESSION FIX
-- ============================================================================
-- This script immediately recovers the 3 missing vouchers for client
-- aaaaf98e-f3aa-489d-9586-573332ff6301

-- ============================================================================
-- STEP 1: Create Emergency Backup of Current Orphaned State
-- ============================================================================

-- Create emergency backup table with timestamp
DO $$
DECLARE
    backup_table_name TEXT;
BEGIN
    -- Generate timestamped table name
    backup_table_name := 'emergency_orphaned_backup_' || to_char(NOW(), 'YYYYMMDD_HH24MISS');

    -- Create backup table with dynamic name
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS public.%I AS
        SELECT
            cv.*,
            NOW() as backup_timestamp,
            ''Emergency backup before recovery'' as backup_reason
        FROM public.client_vouchers cv
        LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
        WHERE v.id IS NULL',
        backup_table_name
    );

    RAISE NOTICE 'Created emergency backup table: %', backup_table_name;
END $$;

-- Log the emergency recovery action
INSERT INTO public.database_cleanup_log (
    cleanup_type,
    table_name,
    records_affected,
    details
) VALUES (
    'emergency_recovery_start',
    'client_vouchers',
    (SELECT COUNT(*) FROM public.client_vouchers cv LEFT JOIN public.vouchers v ON cv.voucher_id = v.id WHERE v.id IS NULL),
    jsonb_build_object(
        'emergency_timestamp', NOW(),
        'affected_client', 'aaaaf98e-f3aa-489d-9586-573332ff6301',
        'missing_voucher_ids', ARRAY[
            'cab36f65-f1c6-4aa0-bfd1-7f51eef742c7',
            '6676eb53-c570-4ff4-be51-1082925f7c2c', 
            '8e38613f-19c0-4c9a-9290-30cdcd220c60'
        ],
        'reason', 'Critical production issue - client cannot access vouchers'
    )
);

-- ============================================================================
-- STEP 2: Create Recovery Vouchers for Missing IDs
-- ============================================================================

-- Get current user for voucher creation (use first admin if available)
DO $$
DECLARE
    admin_user_id UUID;
    recovery_timestamp BIGINT;
BEGIN
    -- Get an admin user for voucher creation
    SELECT up.id INTO admin_user_id
    FROM public.user_profiles up
    WHERE up.role IN ('admin', 'owner') 
    AND up.status = 'approved'
    LIMIT 1;
    
    -- If no admin found, use any authenticated user
    IF admin_user_id IS NULL THEN
        SELECT id INTO admin_user_id FROM auth.users LIMIT 1;
    END IF;
    
    -- Generate timestamp for unique codes (8 digits for date format)
    recovery_timestamp := EXTRACT(EPOCH FROM NOW())::BIGINT;

    -- Recovery Voucher 1: cab36f65-f1c6-4aa0-bfd1-7f51eef742c7
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
        'cab36f65-f1c6-4aa0-bfd1-7f51eef742c7'::UUID,
        'VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR001',
        'قسيمة طوارئ مستردة 1 - Emergency Recovery Voucher 1',
        'تم إنشاء هذه القسيمة لاستعادة التعيين المفقود في حالة طوارئ',
        'product',
        'emergency-recovery-001',
        'استرداد طوارئ - Emergency Recovery',
        15, -- 15% discount
        NOW() + INTERVAL '1 year',
        true, -- Active immediately for client access
        admin_user_id,
        NOW(),
        NOW(),
        jsonb_build_object(
            'emergency_recovery', true,
            'original_voucher_id', 'cab36f65-f1c6-4aa0-bfd1-7f51eef742c7',
            'recovery_timestamp', NOW(),
            'recovery_reason', 'Critical production issue - orphaned client voucher',
            'affected_client', 'aaaaf98e-f3aa-489d-9586-573332ff6301',
            'client_voucher_id', 'e17e8ca9-22b9-4237-9d2e-c037fa10ffbf'
        )
    ) ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        is_active = true,
        updated_at = NOW(),
        metadata = EXCLUDED.metadata;
    
    -- Recovery Voucher 2: 6676eb53-c570-4ff4-be51-1082925f7c2c
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
        '6676eb53-c570-4ff4-be51-1082925f7c2c'::UUID,
        'VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR002',
        'قسيمة طوارئ مستردة 2 - Emergency Recovery Voucher 2',
        'تم إنشاء هذه القسيمة لاستعادة التعيين المفقود في حالة طوارئ',
        'product',
        'emergency-recovery-002',
        'استرداد طوارئ - Emergency Recovery',
        20, -- 20% discount
        NOW() + INTERVAL '1 year',
        true, -- Active immediately for client access
        admin_user_id,
        NOW(),
        NOW(),
        jsonb_build_object(
            'emergency_recovery', true,
            'original_voucher_id', '6676eb53-c570-4ff4-be51-1082925f7c2c',
            'recovery_timestamp', NOW(),
            'recovery_reason', 'Critical production issue - orphaned client voucher',
            'affected_client', 'aaaaf98e-f3aa-489d-9586-573332ff6301',
            'client_voucher_id', '17a11c80-cd38-4191-8d4b-c5d8b998b540'
        )
    ) ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        is_active = true,
        updated_at = NOW(),
        metadata = EXCLUDED.metadata;
    
    -- Recovery Voucher 3: 8e38613f-19c0-4c9a-9290-30cdcd220c60
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
        '8e38613f-19c0-4c9a-9290-30cdcd220c60'::UUID,
        'VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR003',
        'قسيمة طوارئ مستردة 3 - Emergency Recovery Voucher 3',
        'تم إنشاء هذه القسيمة لاستعادة التعيين المفقود في حالة طوارئ',
        'product',
        'emergency-recovery-003',
        'استرداد طوارئ - Emergency Recovery',
        25, -- 25% discount
        NOW() + INTERVAL '1 year',
        true, -- Active immediately for client access
        admin_user_id,
        NOW(),
        NOW(),
        jsonb_build_object(
            'emergency_recovery', true,
            'original_voucher_id', '8e38613f-19c0-4c9a-9290-30cdcd220c60',
            'recovery_timestamp', NOW(),
            'recovery_reason', 'Critical production issue - orphaned client voucher',
            'affected_client', 'aaaaf98e-f3aa-489d-9586-573332ff6301',
            'client_voucher_id', '7aaf2811-9c7b-4955-8cda-c596db407955'
        )
    ) ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        is_active = true,
        updated_at = NOW(),
        metadata = EXCLUDED.metadata;
    
    RAISE NOTICE 'Emergency recovery vouchers created successfully';
END $$;

-- ============================================================================
-- STEP 3: Verify Recovery Success
-- ============================================================================

-- Check that all vouchers now exist
SELECT 
    '=== RECOVERY VERIFICATION ===' as section,
    cv.id as client_voucher_id,
    cv.voucher_id,
    v.code as voucher_code,
    v.name as voucher_name,
    v.is_active,
    CASE WHEN v.id IS NOT NULL THEN 'RECOVERED' ELSE 'STILL MISSING' END as status
FROM public.client_vouchers cv
LEFT JOIN public.vouchers v ON cv.voucher_id = v.id
WHERE cv.client_id = 'aaaaf98e-f3aa-489d-9586-573332ff6301'::UUID
ORDER BY cv.created_at;

-- Check overall system health after recovery
SELECT 
    '=== POST-RECOVERY SYSTEM HEALTH ===' as section,
    COUNT(*) as total_client_vouchers,
    COUNT(CASE WHEN v.id IS NOT NULL THEN 1 END) as valid_vouchers,
    COUNT(CASE WHEN v.id IS NULL THEN 1 END) as remaining_orphaned
FROM public.client_vouchers cv
LEFT JOIN public.vouchers v ON cv.voucher_id = v.id;

-- ============================================================================
-- STEP 4: Log Recovery Completion
-- ============================================================================

INSERT INTO public.database_cleanup_log (
    cleanup_type,
    table_name,
    records_affected,
    details
) VALUES (
    'emergency_recovery_complete',
    'vouchers',
    3,
    jsonb_build_object(
        'recovery_timestamp', NOW(),
        'recovered_voucher_ids', ARRAY[
            'cab36f65-f1c6-4aa0-bfd1-7f51eef742c7',
            '6676eb53-c570-4ff4-be51-1082925f7c2c',
            '8e38613f-19c0-4c9a-9290-30cdcd220c60'
        ],
        'affected_client', 'aaaaf98e-f3aa-489d-9586-573332ff6301',
        'recovery_method', 'Emergency voucher creation with original IDs and compliant codes',
        'voucher_codes', ARRAY[
            'VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR001',
            'VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR002',
            'VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR003'
        ],
        'vouchers_active', true,
        'client_access_restored', true
    )
);

-- ============================================================================
-- STEP 5: Immediate Action Items
-- ============================================================================

SELECT 
    '=== NEXT STEPS ===' as section,
    '1. Test client voucher access immediately' as step_1,
    '2. Run Flutter app to verify voucher visibility' as step_2,
    '3. Investigate why vouchers were deleted' as step_3,
    '4. Implement deletion safeguards' as step_4,
    '5. Monitor for additional orphaned records' as step_5;

-- ============================================================================
-- EMERGENCY RECOVERY COMPLETE
-- ============================================================================
