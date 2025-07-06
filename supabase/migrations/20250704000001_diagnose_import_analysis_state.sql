-- =====================================================
-- IMPORT ANALYSIS SYSTEM DIAGNOSTIC
-- =====================================================
-- This script checks the current state of import analysis tables
-- and identifies any existing structures, policies, or conflicts
-- before applying the main migration.
-- =====================================================

-- =====================================================
-- 1. CHECK TABLE EXISTENCE
-- =====================================================

DO $$
DECLARE
    import_batches_exists BOOLEAN := FALSE;
    packing_list_items_exists BOOLEAN := FALSE;
    currency_rates_exists BOOLEAN := FALSE;
    import_analysis_settings_exists BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE '🔍 === IMPORT ANALYSIS SYSTEM DIAGNOSTIC ===';
    RAISE NOTICE '';
    
    -- Check if tables exist
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'import_batches'
    ) INTO import_batches_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'packing_list_items'
    ) INTO packing_list_items_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'currency_rates'
    ) INTO currency_rates_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'import_analysis_settings'
    ) INTO import_analysis_settings_exists;
    
    RAISE NOTICE '📊 TABLE EXISTENCE CHECK:';
    RAISE NOTICE '   import_batches: %', CASE WHEN import_batches_exists THEN '✅ EXISTS' ELSE '❌ NOT FOUND' END;
    RAISE NOTICE '   packing_list_items: %', CASE WHEN packing_list_items_exists THEN '✅ EXISTS' ELSE '❌ NOT FOUND' END;
    RAISE NOTICE '   currency_rates: %', CASE WHEN currency_rates_exists THEN '✅ EXISTS' ELSE '❌ NOT FOUND' END;
    RAISE NOTICE '   import_analysis_settings: %', CASE WHEN import_analysis_settings_exists THEN '✅ EXISTS' ELSE '❌ NOT FOUND' END;
    RAISE NOTICE '';
END $$;

-- =====================================================
-- 2. CHECK COLUMN DEFINITIONS (ESPECIALLY total_quantity)
-- =====================================================

DO $$
DECLARE
    total_quantity_type TEXT;
    total_quantity_exists BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE '🔧 COLUMN DEFINITION CHECK:';
    
    -- Check if packing_list_items table exists first
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'packing_list_items') THEN
        -- Check total_quantity column type
        SELECT data_type INTO total_quantity_type
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'packing_list_items' 
        AND column_name = 'total_quantity';
        
        IF total_quantity_type IS NOT NULL THEN
            total_quantity_exists := TRUE;
            RAISE NOTICE '   total_quantity column: ✅ EXISTS (Type: %)', total_quantity_type;
            
            IF total_quantity_type = 'integer' THEN
                RAISE NOTICE '   ⚠️  ISSUE FOUND: total_quantity is INTEGER - needs to be BIGINT for large values';
            ELSIF total_quantity_type = 'bigint' THEN
                RAISE NOTICE '   ✅ GOOD: total_quantity is already BIGINT';
            ELSE
                RAISE NOTICE '   ❓ UNEXPECTED: total_quantity type is % (expected INTEGER or BIGINT)', total_quantity_type;
            END IF;
        ELSE
            RAISE NOTICE '   total_quantity column: ❌ NOT FOUND';
        END IF;
    ELSE
        RAISE NOTICE '   packing_list_items table does not exist - column check skipped';
    END IF;
    RAISE NOTICE '';
END $$;

-- =====================================================
-- 3. CHECK EXISTING RLS POLICIES
-- =====================================================

DO $$
DECLARE
    policy_count INTEGER;
    policy_record RECORD;
BEGIN
    RAISE NOTICE '🔒 RLS POLICIES CHECK:';
    
    -- Check import_batches policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'import_batches';
    
    RAISE NOTICE '   import_batches policies: % found', policy_count;
    
    IF policy_count > 0 THEN
        FOR policy_record IN 
            SELECT policyname, cmd, roles 
            FROM pg_policies 
            WHERE schemaname = 'public' AND tablename = 'import_batches'
        LOOP
            RAISE NOTICE '     - % (%) for %', policy_record.policyname, policy_record.cmd, policy_record.roles;
        END LOOP;
    END IF;
    
    -- Check packing_list_items policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'packing_list_items';
    
    RAISE NOTICE '   packing_list_items policies: % found', policy_count;
    
    IF policy_count > 0 THEN
        FOR policy_record IN 
            SELECT policyname, cmd, roles 
            FROM pg_policies 
            WHERE schemaname = 'public' AND tablename = 'packing_list_items'
        LOOP
            RAISE NOTICE '     - % (%) for %', policy_record.policyname, policy_record.cmd, policy_record.roles;
        END LOOP;
    END IF;
    
    RAISE NOTICE '';
END $$;

-- =====================================================
-- 4. CHECK DATA EXISTENCE
-- =====================================================

DO $$
DECLARE
    batch_count INTEGER := 0;
    item_count INTEGER := 0;
BEGIN
    RAISE NOTICE '📈 DATA EXISTENCE CHECK:';
    
    -- Check if there's any data in the tables
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'import_batches') THEN
        SELECT COUNT(*) INTO batch_count FROM public.import_batches;
        RAISE NOTICE '   import_batches records: %', batch_count;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'packing_list_items') THEN
        SELECT COUNT(*) INTO item_count FROM public.packing_list_items;
        RAISE NOTICE '   packing_list_items records: %', item_count;
    END IF;
    
    IF batch_count > 0 OR item_count > 0 THEN
        RAISE NOTICE '   ⚠️  EXISTING DATA FOUND - migration must preserve data';
    ELSE
        RAISE NOTICE '   ✅ No existing data - safe to recreate tables if needed';
    END IF;
    
    RAISE NOTICE '';
END $$;

-- =====================================================
-- 5. CHECK INDEXES
-- =====================================================

DO $$
DECLARE
    index_record RECORD;
    index_count INTEGER := 0;
BEGIN
    RAISE NOTICE '⚡ INDEX CHECK:';
    
    -- Check indexes on import analysis tables
    FOR index_record IN 
        SELECT 
            schemaname,
            tablename,
            indexname,
            indexdef
        FROM pg_indexes 
        WHERE schemaname = 'public' 
        AND tablename IN ('import_batches', 'packing_list_items', 'currency_rates', 'import_analysis_settings')
        ORDER BY tablename, indexname
    LOOP
        index_count := index_count + 1;
        RAISE NOTICE '   %.%: %', index_record.tablename, index_record.indexname, 
                     CASE WHEN index_record.indexname LIKE '%pkey' THEN 'PRIMARY KEY' ELSE 'INDEX' END;
    END LOOP;
    
    RAISE NOTICE '   Total indexes found: %', index_count;
    RAISE NOTICE '';
END $$;

-- =====================================================
-- 6. SUMMARY AND RECOMMENDATIONS
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '📋 DIAGNOSTIC SUMMARY:';
    RAISE NOTICE '   This diagnostic helps determine the safest migration approach.';
    RAISE NOTICE '   Key findings will guide the creation of an idempotent migration.';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 NEXT STEPS:';
    RAISE NOTICE '   1. Review the diagnostic output above';
    RAISE NOTICE '   2. Create a safe, idempotent migration based on findings';
    RAISE NOTICE '   3. Handle existing policies with IF NOT EXISTS clauses';
    RAISE NOTICE '   4. Safely alter total_quantity column type if needed';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Diagnostic completed successfully';
END $$;
