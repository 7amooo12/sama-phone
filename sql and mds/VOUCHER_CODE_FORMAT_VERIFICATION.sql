-- ============================================================================
-- VOUCHER CODE FORMAT VERIFICATION
-- ============================================================================
-- This script verifies that the emergency recovery voucher codes comply with
-- the database constraint: vouchers_code_format

-- ============================================================================
-- STEP 1: Check Current Constraint Definition
-- ============================================================================

-- Display the current voucher code format constraint
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conname = 'vouchers_code_format';

-- ============================================================================
-- STEP 2: Test Emergency Recovery Code Format
-- ============================================================================

-- Test the new emergency recovery code format
SELECT 
    'Format Verification' as test_type,
    'VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR001' as sample_code,
    ('VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR001') ~ '^VOUCHER-[0-9]{8}-[A-Z0-9]{6}$' as matches_constraint,
    length('VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR001') as code_length,
    'Expected: VOUCHER-YYYYMMDD-EMR001' as format_explanation;

-- Test all three emergency codes
SELECT 
    'Emergency Code 1' as voucher_name,
    'VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR001' as code,
    ('VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR001') ~ '^VOUCHER-[0-9]{8}-[A-Z0-9]{6}$' as valid
UNION ALL
SELECT 
    'Emergency Code 2' as voucher_name,
    'VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR002' as code,
    ('VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR002') ~ '^VOUCHER-[0-9]{8}-[A-Z0-9]{6}$' as valid
UNION ALL
SELECT 
    'Emergency Code 3' as voucher_name,
    'VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR003' as code,
    ('VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR003') ~ '^VOUCHER-[0-9]{8}-[A-Z0-9]{6}$' as valid;

-- ============================================================================
-- STEP 3: Breakdown of Code Format
-- ============================================================================

-- Analyze the code format components
WITH code_analysis AS (
    SELECT 'VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR001' as sample_code
)
SELECT 
    'Code Format Analysis' as analysis_type,
    sample_code,
    substring(sample_code from 1 for 8) as prefix_part,
    substring(sample_code from 9 for 8) as date_part,
    substring(sample_code from 17 for 1) as separator,
    substring(sample_code from 18 for 6) as suffix_part,
    length(substring(sample_code from 9 for 8)) as date_length,
    length(substring(sample_code from 18 for 6)) as suffix_length,
    substring(sample_code from 9 for 8) ~ '^[0-9]{8}$' as date_is_numeric,
    substring(sample_code from 18 for 6) ~ '^[A-Z0-9]{6}$' as suffix_is_alphanumeric
FROM code_analysis;

-- ============================================================================
-- STEP 4: Constraint Pattern Explanation
-- ============================================================================

-- Explain the constraint pattern
SELECT 
    'Constraint Pattern' as info_type,
    '^VOUCHER-[0-9]{8}-[A-Z0-9]{6}$' as pattern,
    'VOUCHER- (fixed prefix)' as part_1,
    '[0-9]{8} (exactly 8 digits)' as part_2,
    '- (separator)' as part_3,
    '[A-Z0-9]{6} (exactly 6 alphanumeric uppercase)' as part_4,
    'Total length: 8 + 8 + 1 + 6 = 23 characters' as total_length;

-- ============================================================================
-- STEP 5: Verify Against Existing Vouchers
-- ============================================================================

-- Check existing voucher codes to understand the pattern
SELECT 
    'Existing Voucher Codes' as analysis_type,
    code,
    code ~ '^VOUCHER-[0-9]{8}-[A-Z0-9]{6}$' as matches_constraint,
    length(code) as code_length
FROM public.vouchers 
WHERE code IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;

-- ============================================================================
-- STEP 6: Final Validation
-- ============================================================================

-- Final validation that our emergency codes will work
SELECT 
    'FINAL VALIDATION' as test_result,
    CASE 
        WHEN ('VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR001') ~ '^VOUCHER-[0-9]{8}-[A-Z0-9]{6}$' 
        AND ('VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR002') ~ '^VOUCHER-[0-9]{8}-[A-Z0-9]{6}$'
        AND ('VOUCHER-' || to_char(NOW(), 'YYYYMMDD') || '-EMR003') ~ '^VOUCHER-[0-9]{8}-[A-Z0-9]{6}$'
        THEN '✅ ALL EMERGENCY CODES VALID'
        ELSE '❌ CODES DO NOT MATCH CONSTRAINT'
    END as validation_result,
    'Emergency recovery script is ready to run' as status;

-- ============================================================================
-- VERIFICATION COMPLETE
-- ============================================================================
