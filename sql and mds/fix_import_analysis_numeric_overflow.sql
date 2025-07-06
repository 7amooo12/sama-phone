-- =====================================================
-- SmartBizTracker Import Analysis Numeric Field Overflow Fix
-- =====================================================
-- This migration fixes PostgreSQL numeric field overflow errors by increasing
-- the precision of DECIMAL fields that were causing overflow issues.
-- 
-- Error: numeric field overflow, code: 22003
-- Details: A field with precision 10, scale 6 must round to an absolute value less than 10⁴
-- 
-- Root Cause: DECIMAL(10,6) fields can only store values up to 9999.999999
-- Solution: Increase precision to DECIMAL(15,6) to accommodate larger values
-- =====================================================

-- Check if tables exist before attempting migration
DO $$
BEGIN
    -- Check if packing_list_items table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'packing_list_items') THEN
        RAISE NOTICE 'Found packing_list_items table, proceeding with migration...';
        
        -- Fix total_cubic_meters field precision
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'packing_list_items' 
            AND column_name = 'total_cubic_meters'
            AND numeric_precision = 10
            AND numeric_scale = 6
        ) THEN
            RAISE NOTICE 'Updating total_cubic_meters precision from DECIMAL(10,6) to DECIMAL(15,6)...';
            ALTER TABLE packing_list_items 
            ALTER COLUMN total_cubic_meters TYPE DECIMAL(15,6);
            RAISE NOTICE '✅ total_cubic_meters precision updated successfully';
        ELSE
            RAISE NOTICE 'total_cubic_meters already has correct precision or does not exist';
        END IF;
        
        -- Fix conversion_rate field precision
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'packing_list_items' 
            AND column_name = 'conversion_rate'
            AND numeric_precision = 10
            AND numeric_scale = 6
        ) THEN
            RAISE NOTICE 'Updating conversion_rate precision from DECIMAL(10,6) to DECIMAL(15,6)...';
            ALTER TABLE packing_list_items 
            ALTER COLUMN conversion_rate TYPE DECIMAL(15,6);
            RAISE NOTICE '✅ conversion_rate precision updated successfully';
        ELSE
            RAISE NOTICE 'conversion_rate already has correct precision or does not exist';
        END IF;
        
    ELSE
        RAISE NOTICE 'packing_list_items table not found, skipping...';
    END IF;
    
    -- Check if currency_rates table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'currency_rates') THEN
        RAISE NOTICE 'Found currency_rates table, proceeding with migration...';
        
        -- Fix rate field precision
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'currency_rates' 
            AND column_name = 'rate'
            AND numeric_precision = 10
            AND numeric_scale = 6
        ) THEN
            RAISE NOTICE 'Updating currency_rates.rate precision from DECIMAL(10,6) to DECIMAL(15,6)...';
            ALTER TABLE currency_rates 
            ALTER COLUMN rate TYPE DECIMAL(15,6);
            RAISE NOTICE '✅ currency_rates.rate precision updated successfully';
        ELSE
            RAISE NOTICE 'currency_rates.rate already has correct precision or does not exist';
        END IF;
        
    ELSE
        RAISE NOTICE 'currency_rates table not found, skipping...';
    END IF;
    
END $$;

-- =====================================================
-- Verification Queries
-- =====================================================

-- Verify the changes were applied correctly
SELECT 
    'packing_list_items' as table_name,
    'total_cubic_meters' as column_name,
    numeric_precision,
    numeric_scale,
    CASE 
        WHEN numeric_precision = 15 AND numeric_scale = 6 THEN '✅ FIXED'
        WHEN numeric_precision = 10 AND numeric_scale = 6 THEN '❌ NEEDS FIX'
        ELSE '⚠️ UNKNOWN'
    END as status
FROM information_schema.columns 
WHERE table_name = 'packing_list_items' 
AND column_name = 'total_cubic_meters'

UNION ALL

SELECT 
    'packing_list_items' as table_name,
    'conversion_rate' as column_name,
    numeric_precision,
    numeric_scale,
    CASE 
        WHEN numeric_precision = 15 AND numeric_scale = 6 THEN '✅ FIXED'
        WHEN numeric_precision = 10 AND numeric_scale = 6 THEN '❌ NEEDS FIX'
        ELSE '⚠️ UNKNOWN'
    END as status
FROM information_schema.columns 
WHERE table_name = 'packing_list_items' 
AND column_name = 'conversion_rate'

UNION ALL

SELECT 
    'currency_rates' as table_name,
    'rate' as column_name,
    numeric_precision,
    numeric_scale,
    CASE 
        WHEN numeric_precision = 15 AND numeric_scale = 6 THEN '✅ FIXED'
        WHEN numeric_precision = 10 AND numeric_scale = 6 THEN '❌ NEEDS FIX'
        ELSE '⚠️ UNKNOWN'
    END as status
FROM information_schema.columns 
WHERE table_name = 'currency_rates' 
AND column_name = 'rate';

-- =====================================================
-- Test Data Validation
-- =====================================================

-- Test that large values can now be stored without overflow
DO $$
DECLARE
    test_batch_id UUID;
    test_item_id UUID;
BEGIN
    -- Only run tests if tables exist
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'import_batches') 
       AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'packing_list_items') THEN
        
        RAISE NOTICE 'Running validation tests...';
        
        -- Create a test batch
        INSERT INTO import_batches (filename, original_filename, file_size, file_type)
        VALUES ('test_overflow_fix.xlsx', 'test_overflow_fix.xlsx', 1024, 'xlsx')
        RETURNING id INTO test_batch_id;
        
        -- Test large total_cubic_meters value (previously would overflow at 9999.999999)
        INSERT INTO packing_list_items (
            import_batch_id, 
            item_number, 
            total_quantity, 
            total_cubic_meters,
            conversion_rate
        ) VALUES (
            test_batch_id,
            'TEST_OVERFLOW_FIX',
            1,
            15000.123456,  -- This would have caused overflow with DECIMAL(10,6)
            12345.678901   -- This would have caused overflow with DECIMAL(10,6)
        ) RETURNING id INTO test_item_id;
        
        RAISE NOTICE '✅ Successfully inserted test data with large values:';
        RAISE NOTICE '   - total_cubic_meters: 15000.123456';
        RAISE NOTICE '   - conversion_rate: 12345.678901';
        
        -- Clean up test data
        DELETE FROM packing_list_items WHERE id = test_item_id;
        DELETE FROM import_batches WHERE id = test_batch_id;
        
        RAISE NOTICE '✅ Test data cleaned up successfully';
        RAISE NOTICE '🎉 Numeric overflow fix validation completed successfully!';
        
    ELSE
        RAISE NOTICE 'Required tables not found, skipping validation tests';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Validation test failed: %', SQLERRM;
        -- Clean up on error
        IF test_item_id IS NOT NULL THEN
            DELETE FROM packing_list_items WHERE id = test_item_id;
        END IF;
        IF test_batch_id IS NOT NULL THEN
            DELETE FROM import_batches WHERE id = test_batch_id;
        END IF;
END $$;

-- =====================================================
-- Summary
-- =====================================================
SELECT 
    '🎯 Import Analysis Numeric Overflow Fix Summary' as summary,
    'Fixed DECIMAL(10,6) → DECIMAL(15,6) for fields that can exceed 9999.999999' as description,
    'total_cubic_meters, conversion_rate, currency_rates.rate' as affected_fields,
    'Maximum value increased from 9999.999999 to 999999999.999999' as improvement;
