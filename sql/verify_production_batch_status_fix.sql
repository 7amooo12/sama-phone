-- =====================================================
-- Verification Script for Production Batch Status Fix
-- SmartBizTracker Manufacturing System
-- =====================================================
-- This script verifies that the production batch status update fix is working
-- Run this AFTER deploying the fix to ensure everything is working correctly
-- =====================================================

-- 1. Verify that the tool_usage_history table has the correct columns
DO $$
DECLARE
    v_has_warehouse_manager_id BOOLEAN := FALSE;
    v_has_created_by BOOLEAN := FALSE;
    v_has_usage_date BOOLEAN := FALSE;
BEGIN
    -- Check for warehouse_manager_id column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tool_usage_history' 
        AND column_name = 'warehouse_manager_id'
        AND table_schema = 'public'
    ) INTO v_has_warehouse_manager_id;
    
    -- Check for created_by column (should not exist)
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tool_usage_history' 
        AND column_name = 'created_by'
        AND table_schema = 'public'
    ) INTO v_has_created_by;
    
    -- Check for usage_date column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tool_usage_history' 
        AND column_name = 'usage_date'
        AND table_schema = 'public'
    ) INTO v_has_usage_date;
    
    RAISE NOTICE '📋 Tool Usage History Table Column Check:';
    RAISE NOTICE '   ✅ warehouse_manager_id column exists: %', v_has_warehouse_manager_id;
    RAISE NOTICE '   ❌ created_by column exists: % (should be FALSE)', v_has_created_by;
    RAISE NOTICE '   ✅ usage_date column exists: %', v_has_usage_date;
    
    IF v_has_warehouse_manager_id AND NOT v_has_created_by AND v_has_usage_date THEN
        RAISE NOTICE '✅ Table schema is correct for the fix';
    ELSE
        RAISE NOTICE '⚠️  Table schema may have issues';
    END IF;
END $$;

-- 2. Verify that the production_batches table has the correct columns
DO $$
DECLARE
    v_has_status BOOLEAN := FALSE;
    v_has_updated_at BOOLEAN := FALSE;
    v_has_completion_date BOOLEAN := FALSE;
BEGIN
    -- Check for status column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'production_batches' 
        AND column_name = 'status'
        AND table_schema = 'public'
    ) INTO v_has_status;
    
    -- Check for updated_at column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'production_batches' 
        AND column_name = 'updated_at'
        AND table_schema = 'public'
    ) INTO v_has_updated_at;
    
    -- Check for completion_date column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'production_batches' 
        AND column_name = 'completion_date'
        AND table_schema = 'public'
    ) INTO v_has_completion_date;
    
    RAISE NOTICE '📋 Production Batches Table Column Check:';
    RAISE NOTICE '   ✅ status column exists: %', v_has_status;
    RAISE NOTICE '   ✅ updated_at column exists: %', v_has_updated_at;
    RAISE NOTICE '   ✅ completion_date column exists: %', v_has_completion_date;
    
    IF v_has_status AND v_has_updated_at AND v_has_completion_date THEN
        RAISE NOTICE '✅ Production batches table schema is correct';
    ELSE
        RAISE NOTICE '⚠️  Production batches table may have missing columns';
    END IF;
END $$;

-- 3. Verify that the fixed function exists and is accessible
DO $$
DECLARE
    v_function_exists BOOLEAN := FALSE;
    v_function_definition TEXT;
BEGIN
    -- Check if the function exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'update_production_batch_status'
        AND routine_schema = 'public'
        AND routine_type = 'FUNCTION'
    ) INTO v_function_exists;
    
    RAISE NOTICE '📋 Function Availability Check:';
    RAISE NOTICE '   ✅ update_production_batch_status function exists: %', v_function_exists;
    
    IF v_function_exists THEN
        -- Get function definition to check if it uses warehouse_manager_id
        SELECT pg_get_functiondef(p.oid) INTO v_function_definition
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'update_production_batch_status';
        
        IF v_function_definition LIKE '%warehouse_manager_id%' THEN
            RAISE NOTICE '   ✅ Function uses warehouse_manager_id (FIXED)';
        ELSE
            RAISE NOTICE '   ❌ Function may still use created_by (NOT FIXED)';
        END IF;
        
        IF v_function_definition LIKE '%created_by%' THEN
            RAISE NOTICE '   ⚠️  Function still contains created_by reference';
        ELSE
            RAISE NOTICE '   ✅ Function does not contain created_by reference';
        END IF;
    ELSE
        RAISE NOTICE '❌ Function is missing - please deploy the fix';
    END IF;
END $$;

-- 4. Check if there are any production batches available for testing
DO $$
DECLARE
    v_total_batches INTEGER := 0;
    v_in_progress_batches INTEGER := 0;
    v_completed_batches INTEGER := 0;
BEGIN
    -- Count total production batches
    SELECT COUNT(*) INTO v_total_batches FROM production_batches;
    
    -- Count in_progress batches
    SELECT COUNT(*) INTO v_in_progress_batches FROM production_batches WHERE status = 'in_progress';
    
    -- Count completed batches
    SELECT COUNT(*) INTO v_completed_batches FROM production_batches WHERE status = 'completed';
    
    RAISE NOTICE '📋 Test Data Availability:';
    RAISE NOTICE '   📊 Total production batches: %', v_total_batches;
    RAISE NOTICE '   🔄 In progress batches: %', v_in_progress_batches;
    RAISE NOTICE '   ✅ Completed batches: %', v_completed_batches;
    
    IF v_total_batches > 0 THEN
        RAISE NOTICE '✅ Test data is available for production batch status testing';
        IF v_in_progress_batches > 0 THEN
            RAISE NOTICE '🎯 You can test status updates with existing in_progress batches';
        END IF;
    ELSE
        RAISE NOTICE '⚠️  No production batches found - create some batches first for testing';
    END IF;
END $$;

-- 5. Check operation types allowed in tool_usage_history
DO $$
DECLARE
    v_constraint_def TEXT;
BEGIN
    -- Get the check constraint definition for operation_type
    SELECT cc.check_clause INTO v_constraint_def
    FROM information_schema.check_constraints cc
    JOIN information_schema.constraint_column_usage ccu ON cc.constraint_name = ccu.constraint_name
    WHERE ccu.table_name = 'tool_usage_history' 
    AND ccu.column_name = 'operation_type'
    AND ccu.table_schema = 'public';
    
    RAISE NOTICE '📋 Operation Type Constraint Check:';
    IF v_constraint_def IS NOT NULL THEN
        RAISE NOTICE '   ✅ Constraint exists: %', v_constraint_def;
        IF v_constraint_def LIKE '%status_update%' THEN
            RAISE NOTICE '   ✅ status_update operation type is allowed';
        ELSE
            RAISE NOTICE '   ⚠️  status_update operation type may not be allowed';
        END IF;
    ELSE
        RAISE NOTICE '   ⚠️  No operation_type constraint found';
    END IF;
END $$;

-- 6. Final verification summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎯 VERIFICATION SUMMARY:';
    RAISE NOTICE '================================';
    RAISE NOTICE '1. Deploy sql/fix_production_batch_status_created_by_error.sql if not done';
    RAISE NOTICE '2. Restart your Flutter application';
    RAISE NOTICE '3. Test production batch status updates in the app';
    RAISE NOTICE '4. Try changing status from "in_progress" to "completed"';
    RAISE NOTICE '5. Check for success message and proper status change';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 If all checks above show ✅, the status update fix should be working!';
    RAISE NOTICE '📝 The fix changes created_by to warehouse_manager_id in tool_usage_history inserts';
END $$;
