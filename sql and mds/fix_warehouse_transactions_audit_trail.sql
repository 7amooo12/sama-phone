-- =====================================================
-- COMPREHENSIVE WAREHOUSE TRANSACTIONS AUDIT TRAIL FIX
-- =====================================================
-- This script fixes the critical issue where inventory deductions are not 
-- being recorded in warehouse transactions, causing missing audit trail

-- Step 1: Diagnostic - Check current state
DO $$
DECLARE
    rec RECORD;
    table_exists BOOLEAN := FALSE;
    has_correct_schema BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE '🔍 === WAREHOUSE TRANSACTIONS AUDIT TRAIL DIAGNOSTIC ===';
    
    -- Check if table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'warehouse_transactions'
    ) INTO table_exists;
    
    IF table_exists THEN
        RAISE NOTICE '✅ warehouse_transactions table exists';
        
        -- Check for required columns
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'warehouse_transactions' 
            AND column_name IN ('quantity_change', 'quantity_before', 'quantity_after', 'performed_by', 'type')
            GROUP BY table_name
            HAVING COUNT(*) = 5
        ) INTO has_correct_schema;
        
        RAISE NOTICE '📋 Schema check: %', CASE WHEN has_correct_schema THEN 'CORRECT' ELSE 'NEEDS FIX' END;
        
        -- List current columns
        RAISE NOTICE '📋 Current columns:';
        FOR rec IN 
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns 
            WHERE table_name = 'warehouse_transactions'
            ORDER BY ordinal_position
        LOOP
            RAISE NOTICE '  - %: % (%)', rec.column_name, rec.data_type, 
                CASE WHEN rec.is_nullable = 'YES' THEN 'nullable' ELSE 'not null' END;
        END LOOP;
    ELSE
        RAISE NOTICE '❌ warehouse_transactions table does not exist';
    END IF;
    
    -- Check if deduction function exists
    IF EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'deduct_inventory_with_validation'
    ) THEN
        RAISE NOTICE '✅ deduct_inventory_with_validation function exists';
    ELSE
        RAISE NOTICE '❌ deduct_inventory_with_validation function missing';
    END IF;
END $$;

-- Step 2: Create/Fix warehouse_transactions table with correct schema
DO $$
BEGIN
    -- Drop existing table if schema is wrong
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_transactions') THEN
        -- Check if we need to recreate
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'warehouse_transactions' 
            AND column_name = 'quantity_change'
        ) THEN
            RAISE NOTICE '🔧 Dropping incorrect warehouse_transactions table...';
            DROP TABLE warehouse_transactions CASCADE;
        END IF;
    END IF;
    
    -- Create table with correct schema for audit trail
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_transactions') THEN
        RAISE NOTICE '🏗️ Creating warehouse_transactions table with audit trail schema...';
        
        CREATE TABLE warehouse_transactions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            warehouse_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            type TEXT NOT NULL CHECK (type IN ('addition', 'withdrawal', 'adjustment', 'transfer', 'stock_in', 'stock_out')),
            quantity_change INTEGER NOT NULL,
            quantity_before INTEGER NOT NULL,
            quantity_after INTEGER NOT NULL,
            performed_by TEXT NOT NULL,
            performed_at TIMESTAMP DEFAULT NOW(),
            reason TEXT,
            reference_id TEXT,
            reference_type TEXT,
            transaction_number TEXT UNIQUE,
            metadata JSONB DEFAULT '{}'::jsonb,
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW()
        );
        
        RAISE NOTICE '✅ warehouse_transactions table created successfully';
    END IF;
END $$;

-- Step 3: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_warehouse_id ON warehouse_transactions(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_product_id ON warehouse_transactions(product_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_performed_at ON warehouse_transactions(performed_at);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_type ON warehouse_transactions(type);
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_reference_id ON warehouse_transactions(reference_id);

-- Step 4: Enable RLS and create policies
ALTER TABLE warehouse_transactions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "warehouse_transactions_select_policy" ON warehouse_transactions;
DROP POLICY IF EXISTS "warehouse_transactions_insert_policy" ON warehouse_transactions;
DROP POLICY IF EXISTS "warehouse_transactions_update_policy" ON warehouse_transactions;
DROP POLICY IF EXISTS "warehouse_transactions_delete_policy" ON warehouse_transactions;

-- Create RLS policies for audit trail access
CREATE POLICY "warehouse_transactions_select_policy" ON warehouse_transactions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

CREATE POLICY "warehouse_transactions_insert_policy" ON warehouse_transactions
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner', 'accountant', 'warehouseManager')
        AND user_profiles.status = 'approved'
    )
  );

CREATE POLICY "warehouse_transactions_update_policy" ON warehouse_transactions
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role IN ('admin', 'owner')
        AND user_profiles.status = 'approved'
    )
  );

CREATE POLICY "warehouse_transactions_delete_policy" ON warehouse_transactions
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.id = auth.uid() 
        AND user_profiles.role = 'admin'
        AND user_profiles.status = 'approved'
    )
  );

-- Step 5: Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON warehouse_transactions TO authenticated;

-- Step 6: Create/Update the deduct_inventory_with_validation function
DROP FUNCTION IF EXISTS deduct_inventory_with_validation(TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION deduct_inventory_with_validation(
    p_warehouse_id TEXT,
    p_product_id TEXT,
    p_quantity INTEGER,
    p_performed_by TEXT,
    p_reason TEXT,
    p_reference_id TEXT DEFAULT NULL,
    p_reference_type TEXT DEFAULT 'manual'
)
RETURNS JSONB AS $$
DECLARE
    v_current_quantity INTEGER := 0;
    v_minimum_stock INTEGER := 0;
    v_new_quantity INTEGER := 0;
    v_transaction_id TEXT;
    v_transaction_number TEXT;
    v_user_role TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles 
    WHERE id = auth.uid() AND status = 'approved';
    
    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager', 'accountant') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'غير مصرح لك بخصم المخزون'
        );
    END IF;

    -- Get current inventory
    SELECT quantity, COALESCE(minimum_stock, 0)
    INTO v_current_quantity, v_minimum_stock
    FROM warehouse_inventory
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المنتج غير موجود في هذا المخزن'
        );
    END IF;
    
    -- Validate quantity
    IF p_quantity <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'الكمية يجب أن تكون أكبر من صفر'
        );
    END IF;
    
    IF v_current_quantity < p_quantity THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'الكمية المطلوبة (' || p_quantity || ') أكبر من المتاح (' || v_current_quantity || ')'
        );
    END IF;
    
    -- Calculate new quantity
    v_new_quantity := v_current_quantity - p_quantity;
    
    -- Update inventory
    UPDATE warehouse_inventory
    SET 
        quantity = v_new_quantity,
        last_updated = NOW(),
        updated_at = NOW()
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    
    -- Generate transaction ID and number
    v_transaction_id := gen_random_uuid()::TEXT;
    v_transaction_number := 'TXN-' || EXTRACT(EPOCH FROM NOW())::BIGINT || '-' || SUBSTRING(v_transaction_id, 1, 8);
    
    -- CRITICAL: Create transaction record for audit trail
    INSERT INTO warehouse_transactions (
        id,
        warehouse_id,
        product_id,
        type,
        quantity_change,
        quantity_before,
        quantity_after,
        performed_by,
        performed_at,
        reason,
        reference_id,
        reference_type,
        transaction_number,
        metadata,
        created_at,
        updated_at
    ) VALUES (
        v_transaction_id,
        p_warehouse_id,
        p_product_id,
        'withdrawal',
        -p_quantity,
        v_current_quantity,
        v_new_quantity,
        p_performed_by,
        NOW(),
        p_reason,
        p_reference_id,
        p_reference_type,
        v_transaction_number,
        jsonb_build_object(
            'deduction_method', 'automated',
            'minimum_stock_warning', v_new_quantity <= v_minimum_stock
        ),
        NOW(),
        NOW()
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_transaction_id,
        'transaction_number', v_transaction_number,
        'quantity_before', v_current_quantity,
        'quantity_after', v_new_quantity,
        'remaining_quantity', v_new_quantity,
        'minimum_stock_warning', v_new_quantity <= v_minimum_stock,
        'deducted_quantity', p_quantity
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'خطأ في خصم المخزون: ' || SQLERRM,
            'error_detail', SQLSTATE
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION deduct_inventory_with_validation(TEXT, TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- Step 7: Verification and completion message
DO $$
BEGIN
    RAISE NOTICE '✅ === WAREHOUSE TRANSACTIONS AUDIT TRAIL FIX COMPLETE ===';
    RAISE NOTICE '📋 Table created/updated with correct schema';
    RAISE NOTICE '🔐 RLS policies applied for security';
    RAISE NOTICE '⚡ Performance indexes created';
    RAISE NOTICE '🔧 Function updated to create transaction records';
    RAISE NOTICE '📊 Audit trail should now work correctly';
    RAISE NOTICE '🎯 Test by running inventory deduction operations';
END $$;
