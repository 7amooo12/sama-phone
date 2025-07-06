-- تطبيق تصحيح دوال البحث في المخازن
-- Apply warehouse search functions migration fix

-- Drop existing functions if they exist (to handle re-running)
DROP FUNCTION IF EXISTS search_warehouse_products(TEXT, UUID[], INTEGER, INTEGER);
DROP FUNCTION IF EXISTS search_warehouse_categories(TEXT, UUID[], INTEGER, INTEGER);
DROP FUNCTION IF EXISTS get_accessible_warehouse_ids(UUID);
DROP VIEW IF EXISTS warehouse_product_search_view;

-- Note: Please manually execute the corrected migration file:
-- supabase/migrations/20250615000004_create_warehouse_search_functions.sql

-- After running the migration file, verify the functions were created successfully
SELECT
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('search_warehouse_products', 'search_warehouse_categories', 'get_accessible_warehouse_ids');

SELECT 'Please run the migration file manually, then execute this verification query.' as status;
