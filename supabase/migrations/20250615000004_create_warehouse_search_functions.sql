-- إنشاء دوال البحث في المخازن
-- Create warehouse search functions

-- Step 1: Create function to search warehouse products
CREATE OR REPLACE FUNCTION search_warehouse_products(
    search_query TEXT,
    warehouse_ids UUID[],
    page_limit INTEGER DEFAULT 20,
    page_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    product_id TEXT,
    product_name TEXT,
    product_sku TEXT,
    product_description TEXT,
    category_name TEXT,
    total_quantity INTEGER,
    warehouse_breakdown JSONB,
    last_updated TIMESTAMP WITH TIME ZONE,
    image_url TEXT,
    price NUMERIC
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH product_inventory AS (
        SELECT 
            wi.product_id,
            SUM(wi.quantity) as total_qty,
            MAX(wi.last_updated) as latest_update,
            JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'warehouse_id', wi.warehouse_id,
                    'warehouse_name', w.name,
                    'warehouse_location', w.address,
                    'quantity', wi.quantity,
                    'stock_status', 
                        CASE 
                            WHEN wi.quantity = 0 THEN 'out_of_stock'
                            WHEN wi.quantity <= COALESCE(wi.minimum_stock, 10) THEN 'low_stock'
                            ELSE 'in_stock'
                        END,
                    'last_updated', wi.last_updated,
                    'minimum_stock', wi.minimum_stock,
                    'maximum_stock', wi.maximum_stock
                )
            ) as breakdown
        FROM warehouse_inventory wi
        INNER JOIN warehouses w ON wi.warehouse_id = w.id
        WHERE wi.warehouse_id = ANY(warehouse_ids)
        AND w.is_active = true
        GROUP BY wi.product_id
    ),
    filtered_products AS (
        SELECT 
            pi.product_id,
            pi.total_qty,
            pi.latest_update,
            pi.breakdown,
            -- Try to get product info from external API or use fallback
            COALESCE(
                (SELECT name FROM products WHERE id = pi.product_id LIMIT 1),
                'منتج ' || pi.product_id
            ) as prod_name,
            COALESCE(
                (SELECT sku FROM products WHERE id = pi.product_id LIMIT 1),
                pi.product_id
            ) as prod_sku,
            COALESCE(
                (SELECT description FROM products WHERE id = pi.product_id LIMIT 1),
                ''
            ) as prod_description,
            COALESCE(
                (SELECT category FROM products WHERE id = pi.product_id LIMIT 1),
                'غير محدد'
            ) as prod_category,
            COALESCE(
                (SELECT main_image_url FROM products WHERE id = pi.product_id LIMIT 1),
                NULL
            ) as prod_image,
            COALESCE(
                (SELECT price FROM products WHERE id = pi.product_id LIMIT 1),
                0
            ) as prod_price
        FROM product_inventory pi
        WHERE pi.total_qty > 0
    )
    SELECT
        fp.product_id,
        fp.prod_name,
        fp.prod_sku,
        fp.prod_description,
        fp.prod_category,
        fp.total_qty::INTEGER,
        fp.breakdown,
        fp.latest_update,
        fp.prod_image,
        fp.prod_price
    FROM filtered_products fp
    WHERE (
        -- Only filter if search_query is provided and not empty
        search_query IS NULL
        OR search_query = ''
        OR (
            search_query IS NOT NULL
            AND search_query != ''
            AND (
                LOWER(fp.prod_name) LIKE '%' || LOWER(search_query) || '%'
                OR LOWER(fp.prod_sku) LIKE '%' || LOWER(search_query) || '%'
                OR LOWER(fp.prod_description) LIKE '%' || LOWER(search_query) || '%'
                OR LOWER(fp.prod_category) LIKE '%' || LOWER(search_query) || '%'
                OR fp.product_id LIKE '%' || search_query || '%'
            )
        )
    )
    ORDER BY
        -- Prioritize exact matches, then partial matches, then by quantity
        CASE
            WHEN search_query IS NOT NULL AND search_query != '' THEN
                CASE
                    WHEN fp.product_id = search_query THEN 1
                    WHEN LOWER(fp.prod_name) = LOWER(search_query) THEN 2
                    WHEN LOWER(fp.prod_sku) = LOWER(search_query) THEN 3
                    WHEN fp.product_id LIKE '%' || search_query || '%' THEN 4
                    WHEN LOWER(fp.prod_name) LIKE '%' || LOWER(search_query) || '%' THEN 5
                    ELSE 6
                END
            ELSE 7
        END,
        fp.total_qty DESC,
        fp.latest_update DESC
    LIMIT page_limit
    OFFSET page_offset;
END;
$$;

-- Step 2: Create function to search categories
CREATE OR REPLACE FUNCTION search_warehouse_categories(
    search_query TEXT,
    warehouse_ids UUID[],
    page_limit INTEGER DEFAULT 20,
    page_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    category_id TEXT,
    category_name TEXT,
    product_count INTEGER,
    total_value NUMERIC,
    total_quantity INTEGER,
    products JSONB,
    last_updated TIMESTAMP WITH TIME ZONE
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH category_inventory AS (
        SELECT
            COALESCE(
                (SELECT category FROM products WHERE id = wi.product_id LIMIT 1),
                'غير محدد'
            ) as cat_name,
            COUNT(DISTINCT wi.product_id) as prod_count,
            SUM(wi.quantity) as total_qty,
            SUM(
                wi.quantity * COALESCE(
                    (SELECT price FROM products WHERE id = wi.product_id LIMIT 1),
                    0
                )
            ) as total_val,
            MAX(wi.last_updated) as latest_update,
            JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'product_id', wi.product_id,
                    'product_name', COALESCE(
                        (SELECT name FROM products WHERE id = wi.product_id LIMIT 1),
                        'منتج ' || wi.product_id
                    ),
                    'quantity', wi.quantity,
                    'price', COALESCE(
                        (SELECT price FROM products WHERE id = wi.product_id LIMIT 1),
                        0
                    )
                )
            ) as products_data
        FROM warehouse_inventory wi
        INNER JOIN warehouses w ON wi.warehouse_id = w.id
        WHERE wi.warehouse_id = ANY(warehouse_ids)
        AND w.is_active = true
        AND wi.quantity > 0
        GROUP BY cat_name
    )
    SELECT
        LOWER(REPLACE(ci.cat_name, ' ', '_')) as category_id,
        ci.cat_name,
        ci.prod_count::INTEGER,
        ci.total_val,
        ci.total_qty::INTEGER,
        ci.products_data,
        ci.latest_update
    FROM category_inventory ci
    WHERE (
        -- Only filter if search_query is provided and not empty
        search_query IS NULL
        OR search_query = ''
        OR (
            search_query IS NOT NULL
            AND search_query != ''
            AND LOWER(ci.cat_name) LIKE '%' || LOWER(search_query) || '%'
        )
    )
    AND ci.cat_name != 'غير محدد'
    ORDER BY
        -- Prioritize exact matches first
        CASE
            WHEN search_query IS NOT NULL AND search_query != '' THEN
                CASE
                    WHEN LOWER(ci.cat_name) = LOWER(search_query) THEN 1
                    WHEN LOWER(ci.cat_name) LIKE '%' || LOWER(search_query) || '%' THEN 2
                    ELSE 3
                END
            ELSE 4
        END,
        ci.total_qty DESC,
        ci.prod_count DESC
    LIMIT page_limit
    OFFSET page_offset;
END;
$$;

-- Step 3: Grant permissions to authenticated users
GRANT EXECUTE ON FUNCTION search_warehouse_products TO authenticated;
GRANT EXECUTE ON FUNCTION search_warehouse_categories TO authenticated;

-- Step 4: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_product_search 
ON warehouse_inventory (product_id, warehouse_id, quantity) 
WHERE quantity > 0;

CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_last_updated 
ON warehouse_inventory (last_updated DESC);

CREATE INDEX IF NOT EXISTS idx_warehouses_active 
ON warehouses (is_active) 
WHERE is_active = true;

-- Step 5: Create function to get accessible warehouse IDs for a user
CREATE OR REPLACE FUNCTION get_accessible_warehouse_ids(user_id UUID)
RETURNS UUID[]
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_role TEXT;
    warehouse_ids UUID[];
BEGIN
    -- Get user role
    SELECT role INTO user_role
    FROM user_profiles
    WHERE id = user_id
    AND status = 'approved';

    IF user_role IS NULL THEN
        RETURN ARRAY[]::UUID[];
    END IF;

    -- Admin and owner can access all warehouses
    IF user_role IN ('admin', 'owner') THEN
        SELECT ARRAY_AGG(id) INTO warehouse_ids
        FROM warehouses
        WHERE is_active = true;
        
        RETURN COALESCE(warehouse_ids, ARRAY[]::UUID[]);
    END IF;

    -- Warehouse manager can access assigned warehouses
    -- For now, return all warehouses (can be refined later with warehouse_managers table)
    IF user_role = 'warehouseManager' THEN
        SELECT ARRAY_AGG(id) INTO warehouse_ids
        FROM warehouses
        WHERE is_active = true;
        
        RETURN COALESCE(warehouse_ids, ARRAY[]::UUID[]);
    END IF;

    -- Accountant can access all warehouses for reporting
    IF user_role = 'accountant' THEN
        SELECT ARRAY_AGG(id) INTO warehouse_ids
        FROM warehouses
        WHERE is_active = true;
        
        RETURN COALESCE(warehouse_ids, ARRAY[]::UUID[]);
    END IF;

    -- Default: no access
    RETURN ARRAY[]::UUID[];
END;
$$;

GRANT EXECUTE ON FUNCTION get_accessible_warehouse_ids TO authenticated;

-- Step 6: Create a view for quick product search (optional optimization)
CREATE OR REPLACE VIEW warehouse_product_search_view AS
SELECT 
    wi.product_id,
    wi.warehouse_id,
    w.name as warehouse_name,
    w.address as warehouse_location,
    wi.quantity,
    wi.minimum_stock,
    wi.maximum_stock,
    wi.last_updated,
    CASE 
        WHEN wi.quantity = 0 THEN 'out_of_stock'
        WHEN wi.quantity <= COALESCE(wi.minimum_stock, 10) THEN 'low_stock'
        ELSE 'in_stock'
    END as stock_status,
    -- Try to get product info
    COALESCE(
        (SELECT name FROM products WHERE id = wi.product_id LIMIT 1),
        'منتج ' || wi.product_id
    ) as product_name,
    COALESCE(
        (SELECT sku FROM products WHERE id = wi.product_id LIMIT 1),
        wi.product_id
    ) as product_sku,
    COALESCE(
        (SELECT category FROM products WHERE id = wi.product_id LIMIT 1),
        'غير محدد'
    ) as category_name,
    COALESCE(
        (SELECT main_image_url FROM products WHERE id = wi.product_id LIMIT 1),
        NULL
    ) as image_url,
    COALESCE(
        (SELECT price FROM products WHERE id = wi.product_id LIMIT 1),
        0
    ) as price
FROM warehouse_inventory wi
INNER JOIN warehouses w ON wi.warehouse_id = w.id
WHERE w.is_active = true;

-- Grant access to the view
GRANT SELECT ON warehouse_product_search_view TO authenticated;

-- Step 7: Add comments for documentation
COMMENT ON FUNCTION search_warehouse_products IS 'البحث في منتجات المخازن مع تجميع البيانات من مخازن متعددة';
COMMENT ON FUNCTION search_warehouse_categories IS 'البحث في فئات المنتجات مع إحصائيات شاملة';
COMMENT ON FUNCTION get_accessible_warehouse_ids IS 'الحصول على معرفات المخازن المتاحة للمستخدم حسب دوره';
COMMENT ON VIEW warehouse_product_search_view IS 'عرض محسن للبحث السريع في منتجات المخازن';
