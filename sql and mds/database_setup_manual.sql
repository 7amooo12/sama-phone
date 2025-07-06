-- =====================================================
-- SmartBizTracker Warehouse Release Orders Database Setup
-- Manual SQL Script for Supabase
-- =====================================================

-- Drop existing tables if they exist (optional - only if you need to recreate)
-- DROP TABLE IF EXISTS warehouse_release_order_history CASCADE;
-- DROP TABLE IF EXISTS warehouse_release_order_items CASCADE;
-- DROP TABLE IF EXISTS warehouse_release_orders CASCADE;

-- =====================================================
-- 1. Create warehouse_release_orders table
-- =====================================================
CREATE TABLE IF NOT EXISTS warehouse_release_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_order_number VARCHAR(50) UNIQUE NOT NULL,
    original_order_id VARCHAR(255) NOT NULL,
    client_name VARCHAR(255) NOT NULL,
    client_email VARCHAR(255),
    client_phone VARCHAR(50),
    assigned_to VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending_warehouse_approval',
    total_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(10) NOT NULL DEFAULT 'EGP',
    notes TEXT,
    warehouse_manager_id VARCHAR(255),
    warehouse_manager_name VARCHAR(255),
    approved_at TIMESTAMPTZ,
    rejected_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_status CHECK (status IN (
        'pending_warehouse_approval',
        'approved',
        'rejected',
        'completed'
    )),
    CONSTRAINT valid_currency CHECK (currency IN ('EGP', 'USD', 'EUR')),
    CONSTRAINT positive_amount CHECK (total_amount >= 0)
);

-- =====================================================
-- 2. Create warehouse_release_order_items table
-- =====================================================
CREATE TABLE IF NOT EXISTS warehouse_release_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_order_id UUID NOT NULL REFERENCES warehouse_release_orders(id) ON DELETE CASCADE,
    product_name VARCHAR(255) NOT NULL,
    product_code VARCHAR(100),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(12,2) NOT NULL,
    unit VARCHAR(50) DEFAULT 'قطعة',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT positive_quantity CHECK (quantity > 0),
    CONSTRAINT positive_unit_price CHECK (unit_price >= 0),
    CONSTRAINT positive_total_price CHECK (total_price >= 0)
);

-- =====================================================
-- 3. Create warehouse_release_order_history table
-- =====================================================
CREATE TABLE IF NOT EXISTS warehouse_release_order_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    release_order_id UUID NOT NULL REFERENCES warehouse_release_orders(id) ON DELETE CASCADE,
    action VARCHAR(100) NOT NULL,
    old_status VARCHAR(50),
    new_status VARCHAR(50),
    performed_by VARCHAR(255) NOT NULL,
    performed_by_name VARCHAR(255),
    notes TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- 4. Create indexes for performance
-- =====================================================

-- Primary indexes for warehouse_release_orders
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_status 
    ON warehouse_release_orders(status);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_assigned_to 
    ON warehouse_release_orders(assigned_to);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_created_at 
    ON warehouse_release_orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_original_order 
    ON warehouse_release_orders(original_order_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_orders_number 
    ON warehouse_release_orders(release_order_number);

-- Indexes for warehouse_release_order_items
CREATE INDEX IF NOT EXISTS idx_warehouse_release_order_items_release_order 
    ON warehouse_release_order_items(release_order_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_order_items_product 
    ON warehouse_release_order_items(product_name);

-- Indexes for warehouse_release_order_history
CREATE INDEX IF NOT EXISTS idx_warehouse_release_order_history_release_order 
    ON warehouse_release_order_history(release_order_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_release_order_history_created_at 
    ON warehouse_release_order_history(created_at DESC);

-- =====================================================
-- 5. Create triggers for automatic updates
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for warehouse_release_orders
DROP TRIGGER IF EXISTS update_warehouse_release_orders_updated_at ON warehouse_release_orders;
CREATE TRIGGER update_warehouse_release_orders_updated_at
    BEFORE UPDATE ON warehouse_release_orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to log history changes
CREATE OR REPLACE FUNCTION log_warehouse_release_order_changes()
RETURNS TRIGGER AS $$
BEGIN
    -- Log status changes
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO warehouse_release_order_history (
            release_order_id,
            action,
            old_status,
            new_status,
            performed_by,
            performed_by_name,
            notes
        ) VALUES (
            NEW.id,
            'status_change',
            OLD.status,
            NEW.status,
            COALESCE(NEW.warehouse_manager_id, NEW.assigned_to),
            COALESCE(NEW.warehouse_manager_name, 'System'),
            CASE 
                WHEN NEW.status = 'rejected' THEN NEW.rejection_reason
                ELSE 'Status updated'
            END
        );
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for history logging
DROP TRIGGER IF EXISTS log_warehouse_release_order_changes_trigger ON warehouse_release_orders;
CREATE TRIGGER log_warehouse_release_order_changes_trigger
    AFTER UPDATE ON warehouse_release_orders
    FOR EACH ROW
    EXECUTE FUNCTION log_warehouse_release_order_changes();

-- =====================================================
-- 6. Row Level Security (RLS) Policies
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE warehouse_release_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_release_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_release_order_history ENABLE ROW LEVEL SECURITY;

-- Policies for warehouse_release_orders
DROP POLICY IF EXISTS "warehouse_release_orders_select_policy" ON warehouse_release_orders;
CREATE POLICY "warehouse_release_orders_select_policy" ON warehouse_release_orders
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "warehouse_release_orders_insert_policy" ON warehouse_release_orders;
CREATE POLICY "warehouse_release_orders_insert_policy" ON warehouse_release_orders
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "warehouse_release_orders_update_policy" ON warehouse_release_orders;
CREATE POLICY "warehouse_release_orders_update_policy" ON warehouse_release_orders
    FOR UPDATE USING (true);

DROP POLICY IF EXISTS "warehouse_release_orders_delete_policy" ON warehouse_release_orders;
CREATE POLICY "warehouse_release_orders_delete_policy" ON warehouse_release_orders
    FOR DELETE USING (true);

-- Policies for warehouse_release_order_items
DROP POLICY IF EXISTS "warehouse_release_order_items_select_policy" ON warehouse_release_order_items;
CREATE POLICY "warehouse_release_order_items_select_policy" ON warehouse_release_order_items
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "warehouse_release_order_items_insert_policy" ON warehouse_release_order_items;
CREATE POLICY "warehouse_release_order_items_insert_policy" ON warehouse_release_order_items
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "warehouse_release_order_items_update_policy" ON warehouse_release_order_items;
CREATE POLICY "warehouse_release_order_items_update_policy" ON warehouse_release_order_items
    FOR UPDATE USING (true);

DROP POLICY IF EXISTS "warehouse_release_order_items_delete_policy" ON warehouse_release_order_items;
CREATE POLICY "warehouse_release_order_items_delete_policy" ON warehouse_release_order_items
    FOR DELETE USING (true);

-- Policies for warehouse_release_order_history
DROP POLICY IF EXISTS "warehouse_release_order_history_select_policy" ON warehouse_release_order_history;
CREATE POLICY "warehouse_release_order_history_select_policy" ON warehouse_release_order_history
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "warehouse_release_order_history_insert_policy" ON warehouse_release_order_history;
CREATE POLICY "warehouse_release_order_history_insert_policy" ON warehouse_release_order_history
    FOR INSERT WITH CHECK (true);

-- =====================================================
-- 7. Grant permissions
-- =====================================================

-- Grant permissions to authenticated users
GRANT ALL ON warehouse_release_orders TO authenticated;
GRANT ALL ON warehouse_release_order_items TO authenticated;
GRANT ALL ON warehouse_release_order_history TO authenticated;

-- Grant permissions to service role
GRANT ALL ON warehouse_release_orders TO service_role;
GRANT ALL ON warehouse_release_order_items TO service_role;
GRANT ALL ON warehouse_release_order_history TO service_role;

-- =====================================================
-- 8. Insert sample data (optional for testing)
-- =====================================================

-- Uncomment the following to insert sample data for testing
/*
INSERT INTO warehouse_release_orders (
    release_order_number,
    original_order_id,
    client_name,
    client_email,
    assigned_to,
    status,
    total_amount,
    notes
) VALUES (
    'WRO-2024-001',
    'test-order-123',
    'عميل تجريبي',
    'test@example.com',
    'test-accountant',
    'pending_warehouse_approval',
    1500.00,
    'أذن صرف تجريبي للاختبار'
);
*/

-- =====================================================
-- 9. Verification queries
-- =====================================================

-- Check if tables were created successfully
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
    AND table_name LIKE 'warehouse_release%'
ORDER BY table_name;

-- Check foreign key relationships
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name LIKE 'warehouse_release%';

-- =====================================================
-- Setup Complete!
-- =====================================================

-- If you see the tables listed in the verification queries above,
-- the setup was successful and you can now use the warehouse release orders system.

COMMIT;
