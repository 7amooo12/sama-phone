-- =====================================================
-- SMARTBIZTRACKER MANUFACTURING TOOLS MANAGEMENT SYSTEM
-- Complete Database Schema with SECURITY DEFINER Functions
-- =====================================================
-- 
-- This schema implements a comprehensive manufacturing tools management system
-- with inventory tracking, production workflows, and automatic deduction logic.
-- All functions use SECURITY DEFINER to bypass RLS while maintaining security.
--
-- Execute this script in your Supabase SQL Editor
-- =====================================================

-- =====================================================
-- STEP 1: CREATE MANUFACTURING TOOLS TABLES
-- =====================================================

-- Manufacturing tools inventory table
CREATE TABLE IF NOT EXISTS manufacturing_tools (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    quantity DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    initial_stock DECIMAL(10,2) DEFAULT 0 CHECK (initial_stock >= 0), -- For percentage calculations
    unit VARCHAR(20) NOT NULL DEFAULT 'قطعة',
    color VARCHAR(50),
    size VARCHAR(50),
    image_url TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by UUID REFERENCES user_profiles(id),

    -- Constraints
    CONSTRAINT manufacturing_tools_name_unique UNIQUE(name),
    CONSTRAINT manufacturing_tools_quantity_positive CHECK (quantity >= 0),
    CONSTRAINT manufacturing_tools_initial_stock_positive CHECK (initial_stock >= 0)
);

-- Production recipes (tool requirements per product)
CREATE TABLE IF NOT EXISTS production_recipes (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    tool_id INTEGER REFERENCES manufacturing_tools(id) ON DELETE CASCADE,
    quantity_required DECIMAL(10,2) NOT NULL CHECK (quantity_required > 0),
    created_at TIMESTAMP DEFAULT NOW(),
    created_by UUID REFERENCES user_profiles(id),

    -- Constraints
    UNIQUE(product_id, tool_id)
);

-- Production batches tracking
CREATE TABLE IF NOT EXISTS production_batches (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    units_produced DECIMAL(10,2) NOT NULL CHECK (units_produced > 0),
    completion_date TIMESTAMP DEFAULT NOW(),
    warehouse_manager_id UUID REFERENCES user_profiles(id),
    status VARCHAR(20) DEFAULT 'completed' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
    notes TEXT,

    -- Audit fields
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Tool usage history with comprehensive audit trail
CREATE TABLE IF NOT EXISTS tool_usage_history (
    id SERIAL PRIMARY KEY,
    tool_id INTEGER REFERENCES manufacturing_tools(id) ON DELETE CASCADE,
    batch_id INTEGER REFERENCES production_batches(id) ON DELETE CASCADE,
    quantity_used DECIMAL(10,2) NOT NULL CHECK (quantity_used > 0),
    remaining_stock DECIMAL(10,2) NOT NULL CHECK (remaining_stock >= 0),
    usage_date TIMESTAMP DEFAULT NOW(),
    warehouse_manager_id UUID REFERENCES user_profiles(id),
    operation_type VARCHAR(20) DEFAULT 'production' CHECK (operation_type IN ('production', 'adjustment', 'import', 'export')),
    notes TEXT
);

-- =====================================================
-- STEP 2: CREATE PERFORMANCE INDEXES
-- =====================================================

-- Manufacturing tools indexes
CREATE INDEX IF NOT EXISTS idx_manufacturing_tools_name ON manufacturing_tools(name);
CREATE INDEX IF NOT EXISTS idx_manufacturing_tools_created_by ON manufacturing_tools(created_by);
CREATE INDEX IF NOT EXISTS idx_manufacturing_tools_updated_at ON manufacturing_tools(updated_at DESC);

-- Production recipes indexes
CREATE INDEX IF NOT EXISTS idx_production_recipes_product ON production_recipes(product_id);
CREATE INDEX IF NOT EXISTS idx_production_recipes_tool ON production_recipes(tool_id);
CREATE INDEX IF NOT EXISTS idx_production_recipes_created_by ON production_recipes(created_by);

-- Production batches indexes
CREATE INDEX IF NOT EXISTS idx_production_batches_product ON production_batches(product_id);
CREATE INDEX IF NOT EXISTS idx_production_batches_manager ON production_batches(warehouse_manager_id);
CREATE INDEX IF NOT EXISTS idx_production_batches_status ON production_batches(status);
CREATE INDEX IF NOT EXISTS idx_production_batches_completion_date ON production_batches(completion_date DESC);

-- Tool usage history indexes
CREATE INDEX IF NOT EXISTS idx_tool_usage_history_tool ON tool_usage_history(tool_id);
CREATE INDEX IF NOT EXISTS idx_tool_usage_history_batch ON tool_usage_history(batch_id);
CREATE INDEX IF NOT EXISTS idx_tool_usage_history_date ON tool_usage_history(usage_date DESC);
CREATE INDEX IF NOT EXISTS idx_tool_usage_history_manager ON tool_usage_history(warehouse_manager_id);
CREATE INDEX IF NOT EXISTS idx_tool_usage_history_operation ON tool_usage_history(operation_type);

-- =====================================================
-- STEP 3: CREATE TRIGGERS FOR AUTOMATIC UPDATES
-- =====================================================

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers to tables
DROP TRIGGER IF EXISTS update_manufacturing_tools_updated_at ON manufacturing_tools;
CREATE TRIGGER update_manufacturing_tools_updated_at
    BEFORE UPDATE ON manufacturing_tools
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_production_batches_updated_at ON production_batches;
CREATE TRIGGER update_production_batches_updated_at
    BEFORE UPDATE ON production_batches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- STEP 4: SECURITY DEFINER FUNCTIONS
-- =====================================================

-- Function to get all manufacturing tools with current stock
CREATE OR REPLACE FUNCTION get_manufacturing_tools()
RETURNS TABLE (
    id INTEGER,
    name VARCHAR(100),
    quantity DECIMAL(10,2),
    initial_stock DECIMAL(10,2),
    unit VARCHAR(20),
    color VARCHAR(50),
    size VARCHAR(50),
    image_url TEXT,
    stock_percentage DECIMAL(5,2),
    stock_status VARCHAR(20),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by UUID
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        mt.id,
        mt.name,
        mt.quantity,
        mt.initial_stock,
        mt.unit,
        mt.color,
        mt.size,
        mt.image_url,
        CASE 
            WHEN mt.initial_stock > 0 THEN ROUND((mt.quantity / mt.initial_stock * 100), 2)
            ELSE 100.00
        END as stock_percentage,
        CASE 
            WHEN mt.initial_stock > 0 THEN
                CASE 
                    WHEN (mt.quantity / mt.initial_stock * 100) >= 70 THEN 'green'
                    WHEN (mt.quantity / mt.initial_stock * 100) >= 30 THEN 'yellow'
                    WHEN (mt.quantity / mt.initial_stock * 100) >= 10 THEN 'orange'
                    ELSE 'red'
                END
            ELSE 'green'
        END as stock_status,
        mt.created_at,
        mt.updated_at,
        mt.created_by
    FROM manufacturing_tools mt
    ORDER BY mt.name;
$$;

-- Function to add new manufacturing tool with validation
CREATE OR REPLACE FUNCTION add_manufacturing_tool(
    p_name VARCHAR(100),
    p_quantity DECIMAL(10,2),
    p_unit VARCHAR(20),
    p_color VARCHAR(50) DEFAULT NULL,
    p_size VARCHAR(50) DEFAULT NULL,
    p_image_url TEXT DEFAULT NULL,
    p_created_by UUID DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tool_id INTEGER;
    v_user_id UUID;
BEGIN
    -- Get current user ID if not provided
    IF p_created_by IS NULL THEN
        v_user_id := auth.uid();
    ELSE
        v_user_id := p_created_by;
    END IF;
    
    -- Validate user has appropriate role
    IF NOT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = v_user_id 
        AND role IN ('owner', 'admin', 'warehouseManager')
        AND status IN ('approved', 'active')
    ) THEN
        RAISE EXCEPTION 'غير مصرح لك بإضافة أدوات التصنيع';
    END IF;
    
    -- Validate input parameters
    IF p_name IS NULL OR LENGTH(TRIM(p_name)) = 0 THEN
        RAISE EXCEPTION 'اسم الأداة مطلوب';
    END IF;
    
    IF p_quantity < 0 THEN
        RAISE EXCEPTION 'الكمية يجب أن تكون أكبر من أو تساوي صفر';
    END IF;
    
    IF p_unit IS NULL OR LENGTH(TRIM(p_unit)) = 0 THEN
        RAISE EXCEPTION 'وحدة القياس مطلوبة';
    END IF;
    
    -- Check for duplicate name
    IF EXISTS (SELECT 1 FROM manufacturing_tools WHERE LOWER(name) = LOWER(TRIM(p_name))) THEN
        RAISE EXCEPTION 'اسم الأداة موجود بالفعل';
    END IF;
    
    -- Insert new tool
    INSERT INTO manufacturing_tools (
        name, quantity, initial_stock, unit, color, size, image_url, created_by
    ) VALUES (
        TRIM(p_name), p_quantity, p_quantity, TRIM(p_unit), p_color, p_size, p_image_url, v_user_id
    ) RETURNING id INTO v_tool_id;
    
    RETURN v_tool_id;
END;
$$;

-- Function to update tool quantity with audit trail
CREATE OR REPLACE FUNCTION update_tool_quantity(
    p_tool_id INTEGER,
    p_new_quantity DECIMAL(10,2),
    p_operation_type VARCHAR(20) DEFAULT 'adjustment',
    p_notes TEXT DEFAULT NULL,
    p_batch_id INTEGER DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_old_quantity DECIMAL(10,2);
    v_user_id UUID;
    v_quantity_used DECIMAL(10,2);
BEGIN
    -- Get current user ID
    v_user_id := auth.uid();
    
    -- Validate user has appropriate role
    IF NOT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = v_user_id 
        AND role IN ('owner', 'admin', 'warehouseManager')
        AND status IN ('approved', 'active')
    ) THEN
        RAISE EXCEPTION 'غير مصرح لك بتعديل كميات الأدوات';
    END IF;
    
    -- Validate input parameters
    IF p_new_quantity < 0 THEN
        RAISE EXCEPTION 'الكمية الجديدة يجب أن تكون أكبر من أو تساوي صفر';
    END IF;
    
    -- Get current quantity
    SELECT quantity INTO v_old_quantity 
    FROM manufacturing_tools 
    WHERE id = p_tool_id;
    
    IF v_old_quantity IS NULL THEN
        RAISE EXCEPTION 'الأداة غير موجودة';
    END IF;
    
    -- Calculate quantity used (for audit trail)
    v_quantity_used := v_old_quantity - p_new_quantity;
    
    -- Update tool quantity
    UPDATE manufacturing_tools 
    SET quantity = p_new_quantity, updated_at = NOW()
    WHERE id = p_tool_id;
    
    -- Insert audit record
    INSERT INTO tool_usage_history (
        tool_id, batch_id, quantity_used, remaining_stock, 
        warehouse_manager_id, operation_type, notes
    ) VALUES (
        p_tool_id, p_batch_id, ABS(v_quantity_used), p_new_quantity,
        v_user_id, p_operation_type, p_notes
    );
    
    RETURN TRUE;
END;
$$;

-- Function to create production recipe
CREATE OR REPLACE FUNCTION create_production_recipe(
    p_product_id INTEGER,
    p_tool_id INTEGER,
    p_quantity_required DECIMAL(10,2)
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_recipe_id INTEGER;
    v_user_id UUID;
BEGIN
    -- Get current user ID
    v_user_id := auth.uid();

    -- Validate user has appropriate role
    IF NOT EXISTS (
        SELECT 1 FROM user_profiles
        WHERE id = v_user_id
        AND role IN ('owner', 'admin', 'warehouseManager')
        AND status IN ('approved', 'active')
    ) THEN
        RAISE EXCEPTION 'غير مصرح لك بإنشاء وصفات الإنتاج';
    END IF;

    -- Validate input parameters
    IF p_quantity_required <= 0 THEN
        RAISE EXCEPTION 'الكمية المطلوبة يجب أن تكون أكبر من صفر';
    END IF;

    -- Validate tool exists
    IF NOT EXISTS (SELECT 1 FROM manufacturing_tools WHERE id = p_tool_id) THEN
        RAISE EXCEPTION 'الأداة غير موجودة';
    END IF;

    -- Insert or update recipe
    INSERT INTO production_recipes (product_id, tool_id, quantity_required, created_by)
    VALUES (p_product_id, p_tool_id, p_quantity_required, v_user_id)
    ON CONFLICT (product_id, tool_id)
    DO UPDATE SET
        quantity_required = p_quantity_required,
        created_by = v_user_id
    RETURNING id INTO v_recipe_id;

    RETURN v_recipe_id;
END;
$$;

-- Function to complete production batch with automatic inventory deduction
CREATE OR REPLACE FUNCTION complete_production_batch(
    p_product_id INTEGER,
    p_units_produced DECIMAL(10,2),
    p_notes TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_batch_id INTEGER;
    v_user_id UUID;
    v_recipe RECORD;
    v_required_quantity DECIMAL(10,2);
    v_current_stock DECIMAL(10,2);
    v_new_stock DECIMAL(10,2);
BEGIN
    -- Get current user ID
    v_user_id := auth.uid();

    -- Validate user has appropriate role
    IF NOT EXISTS (
        SELECT 1 FROM user_profiles
        WHERE id = v_user_id
        AND role IN ('owner', 'admin', 'warehouseManager')
        AND status IN ('approved', 'active')
    ) THEN
        RAISE EXCEPTION 'غير مصرح لك بإكمال دفعات الإنتاج';
    END IF;

    -- Validate input parameters
    IF p_units_produced <= 0 THEN
        RAISE EXCEPTION 'عدد الوحدات المنتجة يجب أن يكون أكبر من صفر';
    END IF;

    -- Check if production recipe exists
    IF NOT EXISTS (SELECT 1 FROM production_recipes WHERE product_id = p_product_id) THEN
        RAISE EXCEPTION 'لا توجد وصفة إنتاج لهذا المنتج';
    END IF;

    -- Validate sufficient stock for all required tools
    FOR v_recipe IN
        SELECT pr.tool_id, pr.quantity_required, mt.name as tool_name, mt.quantity as current_stock, mt.unit
        FROM production_recipes pr
        JOIN manufacturing_tools mt ON pr.tool_id = mt.id
        WHERE pr.product_id = p_product_id
    LOOP
        v_required_quantity := v_recipe.quantity_required * p_units_produced;

        IF v_recipe.current_stock < v_required_quantity THEN
            RAISE EXCEPTION 'مخزون غير كافي من %: متوفر % %، مطلوب % %',
                v_recipe.tool_name,
                v_recipe.current_stock,
                v_recipe.unit,
                v_required_quantity,
                v_recipe.unit;
        END IF;
    END LOOP;

    -- Create production batch record
    INSERT INTO production_batches (
        product_id, units_produced, warehouse_manager_id, status, notes
    ) VALUES (
        p_product_id, p_units_produced, v_user_id, 'completed', p_notes
    ) RETURNING id INTO v_batch_id;

    -- Deduct materials from inventory
    FOR v_recipe IN
        SELECT pr.tool_id, pr.quantity_required, mt.quantity as current_stock
        FROM production_recipes pr
        JOIN manufacturing_tools mt ON pr.tool_id = mt.id
        WHERE pr.product_id = p_product_id
    LOOP
        v_required_quantity := v_recipe.quantity_required * p_units_produced;
        v_new_stock := v_recipe.current_stock - v_required_quantity;

        -- Update tool quantity
        PERFORM update_tool_quantity(
            v_recipe.tool_id,
            v_new_stock,
            'production',
            'إنتاج دفعة رقم ' || v_batch_id::TEXT,
            v_batch_id
        );
    END LOOP;

    RETURN v_batch_id;
END;
$$;

-- Drop existing function first to allow return type changes
DROP FUNCTION IF EXISTS get_tool_usage_history(INTEGER, INTEGER, INTEGER);

-- Function to get tool usage history with product information
CREATE OR REPLACE FUNCTION get_tool_usage_history(
    p_tool_id INTEGER DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id INTEGER,
    tool_id INTEGER,
    tool_name VARCHAR(100),
    batch_id INTEGER,
    product_id INTEGER,
    product_name VARCHAR(255),
    quantity_used DECIMAL(10,2),
    remaining_stock DECIMAL(10,2),
    usage_date TIMESTAMP,
    warehouse_manager_name VARCHAR(255),
    operation_type VARCHAR(20),
    notes TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        tuh.id,
        tuh.tool_id,
        mt.name as tool_name,
        tuh.batch_id,
        pb.product_id,
        p.name as product_name,
        tuh.quantity_used,
        tuh.remaining_stock,
        tuh.usage_date,
        up.name as warehouse_manager_name,
        tuh.operation_type,
        tuh.notes
    FROM tool_usage_history tuh
    JOIN manufacturing_tools mt ON tuh.tool_id = mt.id
    LEFT JOIN user_profiles up ON tuh.warehouse_manager_id = up.id
    LEFT JOIN production_batches pb ON tuh.batch_id = pb.id
    LEFT JOIN products p ON pb.product_id::TEXT = p.id
    WHERE (p_tool_id IS NULL OR tuh.tool_id = p_tool_id)
    ORDER BY tuh.usage_date DESC
    LIMIT p_limit OFFSET p_offset;
$$;

-- Function to get production recipes for a product
CREATE OR REPLACE FUNCTION get_production_recipes(p_product_id INTEGER)
RETURNS TABLE (
    id INTEGER,
    product_id INTEGER,
    tool_id INTEGER,
    tool_name VARCHAR(100),
    quantity_required DECIMAL(10,2),
    unit VARCHAR(20),
    current_stock DECIMAL(10,2),
    stock_status VARCHAR(20),
    created_at TIMESTAMP
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        pr.id,
        pr.product_id,
        pr.tool_id,
        mt.name as tool_name,
        pr.quantity_required,
        mt.unit,
        mt.quantity as current_stock,
        CASE
            WHEN mt.initial_stock > 0 THEN
                CASE
                    WHEN (mt.quantity / mt.initial_stock * 100) >= 70 THEN 'green'
                    WHEN (mt.quantity / mt.initial_stock * 100) >= 30 THEN 'yellow'
                    WHEN (mt.quantity / mt.initial_stock * 100) >= 10 THEN 'orange'
                    ELSE 'red'
                END
            ELSE 'green'
        END as stock_status,
        pr.created_at
    FROM production_recipes pr
    JOIN manufacturing_tools mt ON pr.tool_id = mt.id
    WHERE pr.product_id = p_product_id
    ORDER BY mt.name;
$$;

-- =====================================================
-- FORCE DELETION FUNCTIONS FOR MANUFACTURING TOOLS
-- =====================================================

-- Function to check manufacturing tool deletion constraints
CREATE OR REPLACE FUNCTION check_manufacturing_tool_deletion_constraints(p_tool_id INTEGER)
RETURNS TABLE (
    can_delete BOOLEAN,
    production_recipes INTEGER,
    usage_history INTEGER,
    active_batches INTEGER,
    blocking_reason TEXT
) AS $$
DECLARE
    v_production_recipes INTEGER := 0;
    v_usage_history INTEGER := 0;
    v_active_batches INTEGER := 0;
    v_can_delete BOOLEAN := TRUE;
    v_blocking_reasons TEXT[] := ARRAY[]::TEXT[];
    v_user_role TEXT;
BEGIN
    -- Check user authorization
    SELECT role INTO v_user_role
    FROM user_profiles
    WHERE id = auth.uid() AND status IN ('approved', 'active');

    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager') THEN
        RAISE EXCEPTION 'غير مصرح لك بالوصول لهذه الوظيفة';
    END IF;

    -- Check production recipes
    SELECT COUNT(*)
    INTO v_production_recipes
    FROM production_recipes
    WHERE tool_id = p_tool_id;

    -- Check usage history
    SELECT COUNT(*)
    INTO v_usage_history
    FROM tool_usage_history
    WHERE tool_id = p_tool_id;

    -- Check active production batches using this tool
    SELECT COUNT(*)
    INTO v_active_batches
    FROM production_batches pb
    JOIN production_recipes pr ON pb.product_id = pr.product_id
    WHERE pr.tool_id = p_tool_id
    AND pb.status IN ('قيد التنفيذ', 'in_progress');

    -- Build blocking reasons
    IF v_active_batches > 0 THEN
        v_blocking_reasons := array_append(v_blocking_reasons,
            'الأداة مستخدمة في ' || v_active_batches || ' دفعة إنتاج نشطة');
        v_can_delete := FALSE;
    END IF;

    RETURN QUERY SELECT
        v_can_delete,
        v_production_recipes,
        v_usage_history,
        v_active_batches,
        CASE
            WHEN array_length(v_blocking_reasons, 1) > 0 THEN array_to_string(v_blocking_reasons, '، ')
            ELSE ''
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Function to force delete manufacturing tool with automatic cleanup
CREATE OR REPLACE FUNCTION force_delete_manufacturing_tool(
    p_tool_id INTEGER,
    p_performed_by TEXT DEFAULT NULL,
    p_force_options JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB AS $$
DECLARE
    v_user_role TEXT;
    v_performed_by TEXT;
    v_tool_name TEXT;
    v_deletion_successful BOOLEAN := FALSE;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_start_time TIMESTAMP := NOW();
    v_operation_id TEXT;
    v_recipes_deleted INTEGER := 0;
    v_history_deleted INTEGER := 0;
    v_batches_updated INTEGER := 0;
BEGIN
    -- Check user authorization (only admin, owner, and warehouseManager can force delete)
    SELECT role INTO v_user_role
    FROM user_profiles
    WHERE id = auth.uid() AND status IN ('approved', 'active');

    IF v_user_role NOT IN ('admin', 'owner', 'warehouseManager') THEN
        RAISE EXCEPTION 'غير مصرح لك بالحذف القسري لأدوات التصنيع';
    END IF;

    -- Use current user if no performed_by provided
    v_performed_by := COALESCE(p_performed_by, auth.uid()::TEXT);

    -- Generate operation ID for tracking
    v_operation_id := 'force_delete_tool_' || p_tool_id || '_' || extract(epoch from NOW())::TEXT;

    -- Get tool information
    BEGIN
        SELECT name INTO v_tool_name
        FROM manufacturing_tools
        WHERE id = p_tool_id;

        IF v_tool_name IS NULL THEN
            RAISE EXCEPTION 'أداة التصنيع غير موجودة';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_errors := array_append(v_errors, 'فشل في العثور على أداة التصنيع: ' || SQLERRM);
    END;

    -- Step 1: Update any active production batches to remove tool dependency
    BEGIN
        UPDATE production_batches
        SET status = 'cancelled',
            notes = COALESCE(notes, '') || ' - تم إلغاؤها بسبب حذف الأداة: ' || v_tool_name
        WHERE id IN (
            SELECT DISTINCT pb.id
            FROM production_batches pb
            JOIN production_recipes pr ON pb.product_id = pr.product_id
            WHERE pr.tool_id = p_tool_id
            AND pb.status IN ('قيد التنفيذ', 'in_progress')
        );

        GET DIAGNOSTICS v_batches_updated = ROW_COUNT;

    EXCEPTION WHEN OTHERS THEN
        v_errors := array_append(v_errors, 'خطأ في تحديث دفعات الإنتاج: ' || SQLERRM);
    END;

    -- Step 2: Delete production recipes (CASCADE will handle this, but we track count)
    BEGIN
        SELECT COUNT(*) INTO v_recipes_deleted
        FROM production_recipes
        WHERE tool_id = p_tool_id;

    EXCEPTION WHEN OTHERS THEN
        v_errors := array_append(v_errors, 'خطأ في عد وصفات الإنتاج: ' || SQLERRM);
    END;

    -- Step 3: Count usage history (CASCADE will handle this, but we track count)
    BEGIN
        SELECT COUNT(*) INTO v_history_deleted
        FROM tool_usage_history
        WHERE tool_id = p_tool_id;

    EXCEPTION WHEN OTHERS THEN
        v_errors := array_append(v_errors, 'خطأ في عد تاريخ الاستخدام: ' || SQLERRM);
    END;

    -- Step 4: Delete the manufacturing tool itself (CASCADE will clean up related data)
    BEGIN
        DELETE FROM manufacturing_tools WHERE id = p_tool_id;
        v_deletion_successful := TRUE;

    EXCEPTION WHEN OTHERS THEN
        v_errors := array_append(v_errors, 'فشل في حذف أداة التصنيع: ' || SQLERRM);
        v_deletion_successful := FALSE;
    END;

    -- Return comprehensive result
    RETURN jsonb_build_object(
        'success', v_deletion_successful,
        'operation_id', v_operation_id,
        'tool_id', p_tool_id,
        'tool_name', v_tool_name,
        'performed_by', v_performed_by,
        'execution_time_seconds', EXTRACT(EPOCH FROM (NOW() - v_start_time)),
        'cleanup_summary', jsonb_build_object(
            'production_recipes_deleted', v_recipes_deleted,
            'usage_history_deleted', v_history_deleted,
            'production_batches_updated', v_batches_updated
        ),
        'errors', CASE WHEN array_length(v_errors, 1) > 0 THEN v_errors ELSE NULL END,
        'message', CASE
            WHEN v_deletion_successful THEN 'تم حذف أداة التصنيع بنجاح مع تنظيف جميع البيانات المرتبطة'
            ELSE 'فشل في حذف أداة التصنيع: ' || array_to_string(v_errors, '، ')
        END
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Function to get production batches with details
CREATE OR REPLACE FUNCTION get_production_batches(
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id INTEGER,
    product_id INTEGER,
    units_produced DECIMAL(10,2),
    completion_date TIMESTAMP,
    warehouse_manager_name VARCHAR(255),
    status VARCHAR(20),
    notes TEXT,
    created_at TIMESTAMP
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        pb.id,
        pb.product_id,
        pb.units_produced,
        pb.completion_date,
        up.name as warehouse_manager_name,
        pb.status,
        pb.notes,
        pb.created_at
    FROM production_batches pb
    LEFT JOIN user_profiles up ON pb.warehouse_manager_id = up.id
    ORDER BY pb.completion_date DESC
    LIMIT p_limit OFFSET p_offset;
$$;

-- =====================================================
-- STEP 5: GRANT PERMISSIONS
-- =====================================================

-- Grant execute permissions on functions to authenticated users
GRANT EXECUTE ON FUNCTION get_manufacturing_tools() TO authenticated;
GRANT EXECUTE ON FUNCTION add_manufacturing_tool(VARCHAR(100), DECIMAL(10,2), VARCHAR(20), VARCHAR(50), VARCHAR(50), TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_tool_quantity(INTEGER, DECIMAL(10,2), VARCHAR(20), TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION create_production_recipe(INTEGER, INTEGER, DECIMAL(10,2)) TO authenticated;
GRANT EXECUTE ON FUNCTION complete_production_batch(INTEGER, DECIMAL(10,2), TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_tool_usage_history(INTEGER, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_production_recipes(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_production_batches(INTEGER, INTEGER) TO authenticated;

-- =====================================================
-- STEP 6: INSERT SAMPLE DATA FOR TESTING
-- =====================================================

-- Sample manufacturing tools (only if tables are empty)
-- Note: Sample data insertion requires valid user UUIDs from user_profiles table
-- To insert sample data, replace 'YOUR_USER_UUID_HERE' with actual user UUIDs
/*
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM manufacturing_tools LIMIT 1) THEN
        -- Insert sample tools (uncomment and replace UUIDs when ready)
        INSERT INTO manufacturing_tools (name, quantity, initial_stock, unit, color, created_by) VALUES
        ('مفك براغي كبير', 25.0, 30.0, 'قطعة', 'أحمر', 'YOUR_USER_UUID_HERE'::UUID),
        ('مطرقة متوسطة', 15.0, 20.0, 'قطعة', 'أسود', 'YOUR_USER_UUID_HERE'::UUID),
        ('مثقاب كهربائي', 8.0, 10.0, 'قطعة', 'أزرق', 'YOUR_USER_UUID_HERE'::UUID),
        ('زيت تشحيم', 45.5, 50.0, 'لتر', 'أصفر', 'YOUR_USER_UUID_HERE'::UUID),
        ('أسلاك نحاسية', 120.0, 150.0, 'متر', 'برتقالي', 'YOUR_USER_UUID_HERE'::UUID),
        ('براغي صغيرة', 500.0, 1000.0, 'قطعة', 'فضي', 'YOUR_USER_UUID_HERE'::UUID),
        ('صمغ صناعي', 12.5, 15.0, 'كيلو', 'شفاف', 'YOUR_USER_UUID_HERE'::UUID),
        ('شريط لاصق', 35.0, 40.0, 'متر', 'أبيض', 'YOUR_USER_UUID_HERE'::UUID);

        RAISE NOTICE '✅ Sample manufacturing tools inserted successfully';
    ELSE
        RAISE NOTICE '⚠️ Manufacturing tools table already contains data, skipping sample insertion';
    END IF;
END $$;
*/

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Test the functions
DO $$
BEGIN
    RAISE NOTICE '🔧 Testing Manufacturing Tools Management System...';

    -- Test get_manufacturing_tools function
    IF EXISTS (SELECT 1 FROM get_manufacturing_tools() LIMIT 1) THEN
        RAISE NOTICE '✅ get_manufacturing_tools() function working correctly';
    ELSE
        RAISE NOTICE '❌ get_manufacturing_tools() function returned no results';
    END IF;

    RAISE NOTICE '🎉 Manufacturing Tools Management System setup completed successfully!';
END $$;
