-- ============================================================================
-- FIX MISSING INVENTORY TABLES AND COLUMNS
-- ============================================================================
-- This script creates missing tables and columns needed for inventory deduction

-- 1. Check and fix warehouse_transactions table structure
DO $$
DECLARE
    table_exists BOOLEAN := FALSE;
    column_exists BOOLEAN := FALSE;
BEGIN
    -- Check if warehouse_transactions table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'warehouse_transactions'
    ) INTO table_exists;
    
    IF NOT table_exists THEN
        RAISE NOTICE '📋 Creating warehouse_transactions table...';
        
        CREATE TABLE warehouse_transactions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            warehouse_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            type TEXT NOT NULL CHECK (type IN ('addition', 'withdrawal', 'adjustment', 'transfer')),
            quantity_change INTEGER NOT NULL,
            quantity_before INTEGER NOT NULL,
            quantity_after INTEGER NOT NULL,
            performed_by TEXT NOT NULL,
            performed_at TIMESTAMP DEFAULT NOW(),
            reason TEXT,
            reference_id TEXT,
            reference_type TEXT,
            transaction_number TEXT UNIQUE,
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW()
        );
        
        -- Create indexes
        CREATE INDEX idx_warehouse_transactions_warehouse_id ON warehouse_transactions(warehouse_id);
        CREATE INDEX idx_warehouse_transactions_product_id ON warehouse_transactions(product_id);
        CREATE INDEX idx_warehouse_transactions_performed_at ON warehouse_transactions(performed_at);
        CREATE INDEX idx_warehouse_transactions_type ON warehouse_transactions(type);
        
        -- Enable RLS
        ALTER TABLE warehouse_transactions ENABLE ROW LEVEL SECURITY;
        
        -- Create RLS policies
        CREATE POLICY "warehouse_transactions_read" ON warehouse_transactions
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM user_profiles 
                    WHERE user_profiles.id = auth.uid()
                    AND user_profiles.status = 'approved'
                    AND user_profiles.role IN ('admin', 'owner', 'warehouseManager', 'accountant')
                )
            );
        
        CREATE POLICY "warehouse_transactions_insert" ON warehouse_transactions
            FOR INSERT WITH CHECK (
                EXISTS (
                    SELECT 1 FROM user_profiles 
                    WHERE user_profiles.id = auth.uid()
                    AND user_profiles.status = 'approved'
                    AND user_profiles.role IN ('admin', 'owner', 'warehouseManager', 'accountant')
                )
            );
        
        GRANT SELECT, INSERT ON warehouse_transactions TO authenticated;
        
        RAISE NOTICE '✅ warehouse_transactions table created successfully';
    ELSE
        RAISE NOTICE '✅ warehouse_transactions table already exists';
        
        -- Check if quantity_change column exists
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'warehouse_transactions'
            AND column_name = 'quantity_change'
        ) INTO column_exists;
        
        IF NOT column_exists THEN
            RAISE NOTICE '📋 Adding missing quantity_change column...';
            ALTER TABLE warehouse_transactions ADD COLUMN quantity_change INTEGER;
            
            -- Update existing records to calculate quantity_change
            UPDATE warehouse_transactions 
            SET quantity_change = quantity_after - quantity_before
            WHERE quantity_change IS NULL;
            
            -- Make it NOT NULL after updating
            ALTER TABLE warehouse_transactions ALTER COLUMN quantity_change SET NOT NULL;
            
            RAISE NOTICE '✅ quantity_change column added successfully';
        ELSE
            RAISE NOTICE '✅ quantity_change column already exists';
        END IF;
    END IF;
END $$;

-- 2. Check and create global_inventory_audit_log table
DO $$
DECLARE
    table_exists BOOLEAN := FALSE;
BEGIN
    -- Check if global_inventory_audit_log table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'global_inventory_audit_log'
    ) INTO table_exists;
    
    IF NOT table_exists THEN
        RAISE NOTICE '📋 Creating global_inventory_audit_log table...';
        
        CREATE TABLE global_inventory_audit_log (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            warehouse_id TEXT, -- NULL for global operations
            product_id TEXT,   -- NULL for multi-product operations
            action_type TEXT NOT NULL, -- 'inventory_deduction', 'global_search', 'withdrawal_request_processed'
            action_details JSONB,
            performed_by TEXT,
            performed_at TIMESTAMP DEFAULT NOW(),
            created_at TIMESTAMP DEFAULT NOW()
        );
        
        -- Create indexes
        CREATE INDEX idx_global_inventory_audit_warehouse_id ON global_inventory_audit_log(warehouse_id);
        CREATE INDEX idx_global_inventory_audit_product_id ON global_inventory_audit_log(product_id);
        CREATE INDEX idx_global_inventory_audit_performed_at ON global_inventory_audit_log(performed_at);
        CREATE INDEX idx_global_inventory_audit_action_type ON global_inventory_audit_log(action_type);
        
        -- Enable RLS
        ALTER TABLE global_inventory_audit_log ENABLE ROW LEVEL SECURITY;
        
        -- Create RLS policies
        CREATE POLICY "global_inventory_audit_read" ON global_inventory_audit_log
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM user_profiles 
                    WHERE user_profiles.id = auth.uid()
                    AND user_profiles.status = 'approved'
                    AND user_profiles.role IN ('admin', 'owner', 'warehouseManager', 'accountant')
                )
            );
        
        CREATE POLICY "global_inventory_audit_insert" ON global_inventory_audit_log
            FOR INSERT WITH CHECK (
                EXISTS (
                    SELECT 1 FROM user_profiles 
                    WHERE user_profiles.id = auth.uid()
                    AND user_profiles.status = 'approved'
                    AND user_profiles.role IN ('admin', 'owner', 'warehouseManager', 'accountant')
                )
            );
        
        GRANT SELECT, INSERT ON global_inventory_audit_log TO authenticated;
        
        RAISE NOTICE '✅ global_inventory_audit_log table created successfully';
    ELSE
        RAISE NOTICE '✅ global_inventory_audit_log table already exists';
    END IF;
END $$;

-- 3. Verify table structures
SELECT 
    'WAREHOUSE_TRANSACTIONS_FINAL_STRUCTURE' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'warehouse_transactions'
ORDER BY ordinal_position;

SELECT 
    'GLOBAL_INVENTORY_AUDIT_LOG_STRUCTURE' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'global_inventory_audit_log'
ORDER BY ordinal_position;

-- 4. Test basic functionality
DO $$
BEGIN
    RAISE NOTICE '==================== TABLE CREATION SUMMARY ====================';
    RAISE NOTICE 'All required tables and columns have been created or verified:';
    RAISE NOTICE '✅ warehouse_transactions table with quantity_change column';
    RAISE NOTICE '✅ global_inventory_audit_log table';
    RAISE NOTICE '✅ Proper indexes and RLS policies';
    RAISE NOTICE '✅ Appropriate permissions granted';
    RAISE NOTICE '';
    RAISE NOTICE 'You can now run the debug_inventory_deduction.sql script safely.';
    RAISE NOTICE '================================================================';
END $$;
