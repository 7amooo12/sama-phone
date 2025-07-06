-- =====================================================
-- FIX ORDER STATISTICS FUNCTION
-- =====================================================
-- This migration fixes the critical PostgreSQL function error
-- preventing the Owner Dashboard Reports tab from loading.
-- 
-- Issue: get_order_statistics function returns TABLE format
-- but the service expects JSON format.
-- 
-- Solution: Create get_order_statistics_json function that
-- returns JSON format compatible with the service.
-- =====================================================

-- Create JSON-returning order statistics function
CREATE OR REPLACE FUNCTION public.get_order_statistics_json(
    start_date DATE DEFAULT NULL,
    end_date DATE DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    -- Build JSON object with order statistics
    SELECT json_build_object(
        'total_orders', COUNT(*),
        'pending_orders', COUNT(*) FILTER (WHERE status = 'pending'),
        'confirmed_orders', COUNT(*) FILTER (WHERE status = 'confirmed'),
        'processing_orders', COUNT(*) FILTER (WHERE status = 'processing'),
        'shipped_orders', COUNT(*) FILTER (WHERE status = 'shipped'),
        'delivered_orders', COUNT(*) FILTER (WHERE status = 'delivered'),
        'cancelled_orders', COUNT(*) FILTER (WHERE status = 'cancelled'),
        'total_revenue', COALESCE(SUM(CASE WHEN status != 'cancelled' THEN total_amount END), 0),
        'average_order_value', COALESCE(AVG(CASE WHEN status != 'cancelled' THEN total_amount END), 0),
        'today_orders', COUNT(*) FILTER (WHERE DATE(created_at) = CURRENT_DATE),
        'this_week_orders', COUNT(*) FILTER (WHERE created_at >= date_trunc('week', CURRENT_DATE)),
        'this_month_orders', COUNT(*) FILTER (WHERE created_at >= date_trunc('month', CURRENT_DATE)),
        'today_revenue', COALESCE(SUM(CASE WHEN DATE(created_at) = CURRENT_DATE AND status != 'cancelled' THEN total_amount END), 0),
        'this_week_revenue', COALESCE(SUM(CASE WHEN created_at >= date_trunc('week', CURRENT_DATE) AND status != 'cancelled' THEN total_amount END), 0),
        'this_month_revenue', COALESCE(SUM(CASE WHEN created_at >= date_trunc('month', CURRENT_DATE) AND status != 'cancelled' THEN total_amount END), 0)
    ) INTO result
    FROM public.client_orders
    WHERE (start_date IS NULL OR DATE(created_at) >= start_date)
      AND (end_date IS NULL OR DATE(created_at) <= end_date);
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_order_statistics_json(DATE, DATE) TO authenticated;

-- Create a simplified version without date parameters for general use
CREATE OR REPLACE FUNCTION public.get_order_statistics_json()
RETURNS JSON AS $$
BEGIN
    RETURN public.get_order_statistics_json(NULL, NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission for the parameterless version
GRANT EXECUTE ON FUNCTION public.get_order_statistics_json() TO authenticated;

-- Add helpful comment
COMMENT ON FUNCTION public.get_order_statistics_json(DATE, DATE) IS 
'Returns order statistics in JSON format for the specified date range. Used by Owner Dashboard Reports tab.';

COMMENT ON FUNCTION public.get_order_statistics_json() IS 
'Returns order statistics in JSON format for all orders. Used by Owner Dashboard Reports tab.';

-- Log successful creation
DO $$
BEGIN
    RAISE NOTICE '✅ Order statistics JSON function created successfully!';
    RAISE NOTICE '📊 Function: get_order_statistics_json(start_date, end_date)';
    RAISE NOTICE '📊 Function: get_order_statistics_json() - parameterless version';
    RAISE NOTICE '🔒 Permissions granted to authenticated users';
    RAISE NOTICE '🎯 This fixes the Owner Dashboard Reports tab loading issue';
END $$;
