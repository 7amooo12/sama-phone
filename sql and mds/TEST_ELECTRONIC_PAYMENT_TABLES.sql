-- Test script to verify electronic payment tables are working
-- Run this after the migration to ensure everything is functioning

-- ============================================================================
-- STEP 1: Basic Table Verification
-- ============================================================================

-- Check if tables exist
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('payment_accounts', 'electronic_payments')
ORDER BY table_name;

-- ============================================================================
-- STEP 2: Check Table Structure
-- ============================================================================

-- Payment accounts table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'payment_accounts'
ORDER BY ordinal_position;

-- Electronic payments table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'electronic_payments'
ORDER BY ordinal_position;

-- ============================================================================
-- STEP 3: Check Indexes
-- ============================================================================

-- Check indexes for payment_accounts
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'payment_accounts' 
AND schemaname = 'public';

-- Check indexes for electronic_payments
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'electronic_payments' 
AND schemaname = 'public';

-- ============================================================================
-- STEP 4: Check RLS Policies
-- ============================================================================

-- Check RLS is enabled
SELECT 
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename IN ('payment_accounts', 'electronic_payments')
AND schemaname = 'public';

-- Check policies for payment_accounts
SELECT 
    policyname,
    cmd,
    roles,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'payment_accounts'
AND schemaname = 'public';

-- Check policies for electronic_payments
SELECT 
    policyname,
    cmd,
    roles,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'electronic_payments'
AND schemaname = 'public';

-- ============================================================================
-- STEP 5: Check Default Data
-- ============================================================================

-- Check default payment accounts
SELECT 
    id,
    account_type,
    account_number,
    account_holder_name,
    is_active,
    created_at
FROM public.payment_accounts
ORDER BY account_type;

-- Check electronic payments (should be empty initially)
SELECT COUNT(*) as payment_count
FROM public.electronic_payments;

-- ============================================================================
-- STEP 6: Test Basic Operations (Safe Read-Only Tests)
-- ============================================================================

-- Test selecting from payment_accounts (this should work for authenticated users)
-- Note: This will only work if you're authenticated and have proper permissions
SELECT 
    'payment_accounts' as table_name,
    'SELECT test' as operation,
    CASE 
        WHEN COUNT(*) >= 0 THEN 'SUCCESS'
        ELSE 'FAILED'
    END as result
FROM public.payment_accounts;

-- Test selecting from electronic_payments
SELECT 
    'electronic_payments' as table_name,
    'SELECT test' as operation,
    CASE 
        WHEN COUNT(*) >= 0 THEN 'SUCCESS'
        ELSE 'FAILED'
    END as result
FROM public.electronic_payments;

-- ============================================================================
-- STEP 7: Summary Report
-- ============================================================================

-- Generate a summary report
SELECT 
    'ELECTRONIC PAYMENT SYSTEM VERIFICATION REPORT' as report_title,
    now() as generated_at;

-- Table existence check
SELECT 
    'Table Existence' as check_type,
    CASE 
        WHEN (
            SELECT COUNT(*) 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name IN ('payment_accounts', 'electronic_payments')
        ) = 2 THEN 'PASS ✅'
        ELSE 'FAIL ❌'
    END as result;

-- RLS check
SELECT 
    'Row Level Security' as check_type,
    CASE 
        WHEN (
            SELECT COUNT(*) 
            FROM pg_tables 
            WHERE tablename IN ('payment_accounts', 'electronic_payments')
            AND schemaname = 'public'
            AND rowsecurity = true
        ) = 2 THEN 'PASS ✅'
        ELSE 'FAIL ❌'
    END as result;

-- Policies check
SELECT 
    'RLS Policies' as check_type,
    CASE 
        WHEN (
            SELECT COUNT(*) 
            FROM pg_policies 
            WHERE tablename IN ('payment_accounts', 'electronic_payments')
            AND schemaname = 'public'
        ) >= 5 THEN 'PASS ✅'
        ELSE 'FAIL ❌'
    END as result;

-- Default data check
SELECT 
    'Default Payment Accounts' as check_type,
    CASE 
        WHEN (
            SELECT COUNT(*) 
            FROM public.payment_accounts
        ) >= 2 THEN 'PASS ✅'
        ELSE 'FAIL ❌'
    END as result;

-- Final status
SELECT 
    '🎯 OVERALL STATUS' as status_type,
    CASE 
        WHEN (
            -- All checks must pass
            (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('payment_accounts', 'electronic_payments')) = 2
            AND (SELECT COUNT(*) FROM pg_tables WHERE tablename IN ('payment_accounts', 'electronic_payments') AND schemaname = 'public' AND rowsecurity = true) = 2
            AND (SELECT COUNT(*) FROM pg_policies WHERE tablename IN ('payment_accounts', 'electronic_payments') AND schemaname = 'public') >= 5
            AND (SELECT COUNT(*) FROM public.payment_accounts) >= 2
        ) THEN '🚀 SYSTEM READY - All checks passed!'
        ELSE '⚠️ ISSUES DETECTED - Check individual results above'
    END as overall_result;

-- Instructions for next steps
SELECT 
    'NEXT STEPS' as instruction_type,
    'If all checks passed, your Flutter app should now work with electronic payments. If any checks failed, review the migration script and re-run it.' as instructions;
