-- 🔍 EMERGENCY DEPLOYMENT VERIFICATION SCRIPT
-- Run this script in Supabase SQL Editor AFTER executing emergency_auth_context_restoration.sql
-- This confirms the fix was deployed to production database, not just run locally

-- =====================================================
-- STEP 1: VERIFY FUNCTIONS EXIST IN PRODUCTION
-- =====================================================

SELECT 
    '🔍 PRODUCTION FUNCTION CHECK' as check_type,
    CASE 
        WHEN COUNT(*) = 2 THEN '✅ SUCCESS: Both emergency functions deployed to production'
        WHEN COUNT(*) = 1 THEN '⚠️ PARTIAL: Only 1 function found - deployment incomplete'
        ELSE '❌ FAILURE: No emergency functions found - script ran locally only'
    END as deployment_status,
    STRING_AGG(routine_name, ', ') as found_functions
FROM information_schema.routines 
WHERE routine_name IN ('get_product_inventory_bypass_rls', 'search_product_inventory_comprehensive')
    AND routine_schema = 'public';

-- =====================================================
-- STEP 2: VERIFY RLS POLICIES EXIST IN PRODUCTION
-- =====================================================

SELECT 
    '🔍 PRODUCTION RLS POLICY CHECK' as check_type,
    COUNT(*) as emergency_policies_count,
    CASE 
        WHEN COUNT(*) >= 2 THEN '✅ SUCCESS: Emergency RLS policies deployed'
        WHEN COUNT(*) = 1 THEN '⚠️ PARTIAL: Some emergency policies missing'
        ELSE '❌ FAILURE: No emergency policies found'
    END as policy_status,
    STRING_AGG(policyname, ', ') as found_policies
FROM pg_policies 
WHERE policyname LIKE '%emergency%' OR policyname LIKE '%bypass%';

-- =====================================================
-- STEP 3: TEST PRODUCT ID 131 INVENTORY ACCESS
-- =====================================================

-- Test the bypass function with Product ID 131
SELECT 
    '🧪 PRODUCT 131 INVENTORY TEST' as test_type,
    public.get_product_inventory_bypass_rls('131') as inventory_result;

-- Test the comprehensive search function
SELECT 
    '🧪 PRODUCT 131 COMPREHENSIVE SEARCH TEST' as test_type,
    public.search_product_inventory_comprehensive('131', 4) as search_result;

-- =====================================================
-- STEP 4: VERIFY ACTUAL INVENTORY DATA
-- =====================================================

-- Direct inventory check (should work with emergency policies)
SELECT 
    '📊 DIRECT INVENTORY CHECK' as check_type,
    wi.product_id,
    w.name as warehouse_name,
    wi.quantity,
    CASE 
        WHEN wi.quantity >= 4 THEN '✅ Sufficient stock'
        WHEN wi.quantity > 0 THEN '⚠️ Partial stock'
        ELSE '❌ No stock'
    END as stock_status
FROM warehouse_inventory wi
JOIN warehouses w ON wi.warehouse_id = w.id
WHERE wi.product_id = '131'
    AND w.is_active = true
ORDER BY wi.quantity DESC;

-- =====================================================
-- STEP 5: AUTHENTICATION CONTEXT CHECK
-- =====================================================

SELECT 
    '🔐 AUTH CONTEXT CHECK' as check_type,
    auth.uid() as current_user_id,
    CASE 
        WHEN auth.uid() IS NOT NULL THEN '✅ Valid auth context'
        ELSE '⚠️ NULL auth context - emergency functions should handle this'
    END as auth_status;

-- =====================================================
-- STEP 6: FINAL DEPLOYMENT SUCCESS CONFIRMATION
-- =====================================================

SELECT 
    '🎯 FINAL DEPLOYMENT VERIFICATION' as final_check,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'get_product_inventory_bypass_rls'
        ) AND EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'search_product_inventory_comprehensive'
        ) AND EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE policyname LIKE '%emergency%' OR policyname LIKE '%bypass%'
        ) THEN '🎉 SUCCESS: Emergency fix deployed to production database'
        ELSE '❌ FAILURE: Deployment incomplete - some components missing'
    END as overall_status,
    '🚀 Next: Test Product ID 131 in SmartBizTracker app' as next_action;

-- =====================================================
-- STEP 7: SMARTBIZTRACKER APP TESTING INSTRUCTIONS
-- =====================================================

SELECT 
    '📱 APP TESTING INSTRUCTIONS' as instruction_type,
    'Open SmartBizTracker → Inventory → Search Product ID 131' as step_1,
    'Verify: Should show actual quantities (not 0)' as step_2,
    'Test: Try to deduct 4 units from inventory' as step_3,
    'Expected: Operation should succeed without errors' as expected_result;

-- =====================================================
-- TROUBLESHOOTING GUIDE
-- =====================================================

SELECT 
    '🔧 TROUBLESHOOTING GUIDE' as guide_type,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'get_product_inventory_bypass_rls'
        ) THEN '❌ Functions missing: Re-run emergency_auth_context_restoration.sql in Supabase SQL Editor'
        WHEN NOT EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE policyname LIKE '%emergency%'
        ) THEN '❌ Policies missing: Check RLS policy creation in emergency script'
        ELSE '✅ All components deployed successfully'
    END as troubleshooting_advice;
