-- =====================================================
-- Verification Script for Production Batch Fix
-- SmartBizTracker Manufacturing System
-- =====================================================
-- This script verifies that the production batch creation fix is working
-- Run this AFTER deploying the fix to ensure everything is working correctly
-- =====================================================

-- 1. Verify that the tool_usage_history table has the correct columns
DO $$
DECLARE
    v_has_usage_date BOOLEAN := FALSE;
    v_has_created_at BOOLEAN := FALSE;
BEGIN
    -- Check for usage_date column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tool_usage_history' 
        AND column_name = 'usage_date'
        AND table_schema = 'public'
    ) INTO v_has_usage_date;
    
    -- Check for created_at column (should not exist)
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tool_usage_history' 
        AND column_name = 'created_at'
        AND table_schema = 'public'
    ) INTO v_has_created_at;
    
    RAISE NOTICE '📋 Tool Usage History Table Column Check:';
    RAISE NOTICE '   ✅ usage_date column exists: %', v_has_usage_date;
    RAISE NOTICE '   ❌ created_at column exists: % (should be FALSE)', v_has_created_at;
    
    IF v_has_usage_date AND NOT v_has_created_at THEN
        RAISE NOTICE '✅ Table schema is correct for the fix';
    ELSE
        RAISE NOTICE '⚠️  Table schema may have issues';
    END IF;
END $$;

-- 2. Verify that the production_batches table has the correct columns
DO $$
DECLARE
    v_has_created_at BOOLEAN := FALSE;
    v_has_updated_at BOOLEAN := FALSE;
BEGIN
    -- Check for created_at column in production_batches
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'production_batches' 
        AND column_name = 'created_at'
        AND table_schema = 'public'
    ) INTO v_has_created_at;
    
    -- Check for updated_at column in production_batches
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'production_batches' 
        AND column_name = 'updated_at'
        AND table_schema = 'public'
    ) INTO v_has_updated_at;
    
    RAISE NOTICE '📋 Production Batches Table Column Check:';
    RAISE NOTICE '   ✅ created_at column exists: %', v_has_created_at;
    RAISE NOTICE '   ✅ updated_at column exists: %', v_has_updated_at;
    
    IF v_has_created_at AND v_has_updated_at THEN
        RAISE NOTICE '✅ Production batches table schema is correct';
    ELSE
        RAISE NOTICE '⚠️  Production batches table may have missing columns';
    END IF;
END $$;

-- 3. Verify that the fixed function exists and is accessible
DO $$
DECLARE
    v_function_exists BOOLEAN := FALSE;
BEGIN
    -- Check if the function exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'create_production_batch_in_progress'
        AND routine_schema = 'public'
        AND routine_type = 'FUNCTION'
    ) INTO v_function_exists;
    
    RAISE NOTICE '📋 Function Availability Check:';
    RAISE NOTICE '   ✅ create_production_batch_in_progress function exists: %', v_function_exists;
    
    IF v_function_exists THEN
        RAISE NOTICE '✅ Fixed function is available';
    ELSE
        RAISE NOTICE '❌ Function is missing - please deploy the fix';
    END IF;
END $$;

-- 4. Check if there are any manufacturing tools and production recipes for testing
DO $$
DECLARE
    v_tools_count INTEGER := 0;
    v_recipes_count INTEGER := 0;
BEGIN
    -- Count manufacturing tools
    SELECT COUNT(*) INTO v_tools_count FROM manufacturing_tools;
    
    -- Count production recipes
    SELECT COUNT(*) INTO v_recipes_count FROM production_recipes;
    
    RAISE NOTICE '📋 Test Data Availability:';
    RAISE NOTICE '   🔧 Manufacturing tools available: %', v_tools_count;
    RAISE NOTICE '   📝 Production recipes available: %', v_recipes_count;
    
    IF v_tools_count > 0 AND v_recipes_count > 0 THEN
        RAISE NOTICE '✅ Test data is available for production batch testing';
    ELSE
        RAISE NOTICE '⚠️  Limited test data - may need to create tools and recipes first';
    END IF;
END $$;

-- 5. Final verification summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎯 VERIFICATION SUMMARY:';
    RAISE NOTICE '================================';
    RAISE NOTICE '1. Deploy sql/fix_production_batch_created_at_error.sql if not done';
    RAISE NOTICE '2. Restart your Flutter application';
    RAISE NOTICE '3. Test production batch creation in the app';
    RAISE NOTICE '4. Check for success message: "تم بدء الإنتاج بنجاح"';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 If all checks above show ✅, the fix should be working!';
END $$;
