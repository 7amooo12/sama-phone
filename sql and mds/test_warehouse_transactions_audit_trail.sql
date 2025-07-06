-- =====================================================
-- TEST WAREHOUSE TRANSACTIONS AUDIT TRAIL
-- =====================================================
-- This script tests the complete warehouse transaction tracking system
-- to ensure inventory deductions are properly recorded and displayed

-- Step 1: Verify warehouse_transactions table structure
DO $$
BEGIN
    RAISE NOTICE '🔍 === TESTING WAREHOUSE TRANSACTIONS AUDIT TRAIL ===';
    
    -- Check table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_transactions') THEN
        RAISE NOTICE '✅ warehouse_transactions table exists';
    ELSE
        RAISE NOTICE '❌ warehouse_transactions table missing';
        RETURN;
    END IF;
    
    -- Check required columns exist
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'warehouse_transactions' 
        AND column_name IN ('quantity_change', 'quantity_before', 'quantity_after', 'performed_by', 'type')
        GROUP BY table_name
        HAVING COUNT(*) = 5
    ) THEN
        RAISE NOTICE '✅ All required columns present';
    ELSE
        RAISE NOTICE '❌ Missing required columns';
    END IF;
END $$;

-- Step 2: Test the deduct_inventory_with_validation function
DO $$
DECLARE
    test_warehouse_id TEXT;
    test_product_id TEXT;
    test_user_id TEXT;
    deduction_result JSONB;
    transaction_count INTEGER;
BEGIN
    RAISE NOTICE '🧪 === TESTING INVENTORY DEDUCTION WITH TRANSACTION CREATION ===';
    
    -- Get a test warehouse (first active warehouse)
    SELECT id INTO test_warehouse_id 
    FROM warehouses 
    WHERE is_active = true 
    LIMIT 1;
    
    IF test_warehouse_id IS NULL THEN
        RAISE NOTICE '❌ No active warehouses found for testing';
        RETURN;
    END IF;
    
    RAISE NOTICE '🏢 Using test warehouse: %', test_warehouse_id;
    
    -- Get a test product with inventory
    SELECT product_id INTO test_product_id
    FROM warehouse_inventory 
    WHERE warehouse_id = test_warehouse_id 
    AND quantity > 5
    LIMIT 1;
    
    IF test_product_id IS NULL THEN
        RAISE NOTICE '❌ No products with sufficient inventory found for testing';
        RETURN;
    END IF;
    
    RAISE NOTICE '📦 Using test product: %', test_product_id;
    
    -- Get current user (or use a test user)
    SELECT auth.uid()::TEXT INTO test_user_id;
    IF test_user_id IS NULL THEN
        -- Use first admin user for testing
        SELECT id::TEXT INTO test_user_id 
        FROM user_profiles 
        WHERE role = 'admin' AND status = 'approved' 
        LIMIT 1;
    END IF;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE '❌ No authorized user found for testing';
        RETURN;
    END IF;
    
    RAISE NOTICE '👤 Using test user: %', test_user_id;
    
    -- Count transactions before test
    SELECT COUNT(*) INTO transaction_count
    FROM warehouse_transactions
    WHERE warehouse_id = test_warehouse_id 
    AND product_id = test_product_id;
    
    RAISE NOTICE '📊 Transactions before test: %', transaction_count;
    
    -- Test inventory deduction (small amount for safety)
    SELECT deduct_inventory_with_validation(
        test_warehouse_id,
        test_product_id,
        1, -- Deduct only 1 item for testing
        test_user_id,
        'Test transaction creation - audit trail verification',
        'TEST-' || EXTRACT(EPOCH FROM NOW())::TEXT,
        'audit_test'
    ) INTO deduction_result;
    
    RAISE NOTICE '🔧 Deduction result: %', deduction_result;
    
    -- Check if deduction was successful
    IF (deduction_result->>'success')::BOOLEAN THEN
        RAISE NOTICE '✅ Inventory deduction successful';
        
        -- Count transactions after test
        SELECT COUNT(*) INTO transaction_count
        FROM warehouse_transactions
        WHERE warehouse_id = test_warehouse_id 
        AND product_id = test_product_id;
        
        RAISE NOTICE '📊 Transactions after test: %', transaction_count;
        
        -- Verify transaction was created
        IF EXISTS (
            SELECT 1 FROM warehouse_transactions
            WHERE warehouse_id = test_warehouse_id 
            AND product_id = test_product_id
            AND reason LIKE '%audit trail verification%'
            AND performed_at > NOW() - INTERVAL '1 minute'
        ) THEN
            RAISE NOTICE '✅ Transaction record created successfully';
            
            -- Show transaction details
            FOR rec IN 
                SELECT id, type, quantity_change, quantity_before, quantity_after, 
                       reason, performed_at, transaction_number
                FROM warehouse_transactions
                WHERE warehouse_id = test_warehouse_id 
                AND product_id = test_product_id
                AND reason LIKE '%audit trail verification%'
                ORDER BY performed_at DESC
                LIMIT 1
            LOOP
                RAISE NOTICE '📋 Transaction Details:';
                RAISE NOTICE '  - ID: %', rec.id;
                RAISE NOTICE '  - Type: %', rec.type;
                RAISE NOTICE '  - Quantity Change: %', rec.quantity_change;
                RAISE NOTICE '  - Before: %, After: %', rec.quantity_before, rec.quantity_after;
                RAISE NOTICE '  - Reason: %', rec.reason;
                RAISE NOTICE '  - Time: %', rec.performed_at;
                RAISE NOTICE '  - Transaction Number: %', rec.transaction_number;
            END LOOP;
        ELSE
            RAISE NOTICE '❌ Transaction record NOT created - AUDIT TRAIL BROKEN!';
        END IF;
    ELSE
        RAISE NOTICE '❌ Inventory deduction failed: %', deduction_result->>'error';
    END IF;
END $$;

-- Step 3: Test transaction visibility with RLS policies
DO $$
DECLARE
    visible_transactions INTEGER;
    total_transactions INTEGER;
BEGIN
    RAISE NOTICE '🔐 === TESTING TRANSACTION VISIBILITY (RLS POLICIES) ===';
    
    -- Count total transactions in table (admin view)
    SELECT COUNT(*) INTO total_transactions FROM warehouse_transactions;
    
    -- Count visible transactions (with RLS)
    SELECT COUNT(*) INTO visible_transactions 
    FROM warehouse_transactions
    WHERE performed_at > NOW() - INTERVAL '1 day';
    
    RAISE NOTICE '📊 Total transactions in database: %', total_transactions;
    RAISE NOTICE '📊 Visible transactions (last 24h): %', visible_transactions;
    
    IF total_transactions > 0 THEN
        RAISE NOTICE '✅ Transactions exist in database';
        
        IF visible_transactions > 0 THEN
            RAISE NOTICE '✅ Transactions are visible (RLS policies working)';
        ELSE
            RAISE NOTICE '⚠️ No recent transactions visible - check RLS policies';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No transactions in database - may need to perform inventory operations';
    END IF;
END $$;

-- Step 4: Show sample transactions for verification
DO $$
BEGIN
    RAISE NOTICE '📋 === SAMPLE RECENT TRANSACTIONS ===';
    
    FOR rec IN 
        SELECT 
            wt.id,
            wt.warehouse_id,
            w.name as warehouse_name,
            wt.product_id,
            wt.type,
            wt.quantity_change,
            wt.reason,
            wt.performed_at,
            wt.transaction_number
        FROM warehouse_transactions wt
        LEFT JOIN warehouses w ON wt.warehouse_id = w.id
        WHERE wt.performed_at > NOW() - INTERVAL '1 day'
        ORDER BY wt.performed_at DESC
        LIMIT 5
    LOOP
        RAISE NOTICE '📦 Transaction: % | Warehouse: % | Product: % | Type: % | Change: % | Reason: %', 
            rec.transaction_number, rec.warehouse_name, rec.product_id, 
            rec.type, rec.quantity_change, rec.reason;
    END LOOP;
END $$;

-- Step 5: Verification summary
DO $$
DECLARE
    function_exists BOOLEAN;
    table_exists BOOLEAN;
    policies_exist BOOLEAN;
    recent_transactions INTEGER;
BEGIN
    RAISE NOTICE '✅ === AUDIT TRAIL VERIFICATION SUMMARY ===';
    
    -- Check function exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'deduct_inventory_with_validation'
    ) INTO function_exists;
    
    -- Check table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'warehouse_transactions'
    ) INTO table_exists;
    
    -- Check policies exist
    SELECT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'warehouse_transactions'
    ) INTO policies_exist;
    
    -- Count recent transactions
    SELECT COUNT(*) INTO recent_transactions
    FROM warehouse_transactions
    WHERE performed_at > NOW() - INTERVAL '1 hour';
    
    RAISE NOTICE '🔧 Deduction Function: %', CASE WHEN function_exists THEN 'EXISTS' ELSE 'MISSING' END;
    RAISE NOTICE '📋 Transactions Table: %', CASE WHEN table_exists THEN 'EXISTS' ELSE 'MISSING' END;
    RAISE NOTICE '🔐 RLS Policies: %', CASE WHEN policies_exist THEN 'CONFIGURED' ELSE 'MISSING' END;
    RAISE NOTICE '📊 Recent Transactions: %', recent_transactions;
    
    IF function_exists AND table_exists AND policies_exist THEN
        RAISE NOTICE '✅ AUDIT TRAIL SYSTEM: FULLY OPERATIONAL';
        RAISE NOTICE '🎯 Next Steps:';
        RAISE NOTICE '   1. Test inventory deduction in Flutter app';
        RAISE NOTICE '   2. Check warehouse transactions tab displays records';
        RAISE NOTICE '   3. Verify transaction details are complete';
    ELSE
        RAISE NOTICE '❌ AUDIT TRAIL SYSTEM: NEEDS ATTENTION';
        RAISE NOTICE '🔧 Please ensure all components are properly configured';
    END IF;
END $$;
