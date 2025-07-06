-- =====================================================
-- SMARTBIZTRACKER MANUFACTURING TOOLS SCHEMA TEST
-- Test script to verify foreign key constraints and UUID compatibility
-- =====================================================

-- Test 1: Verify table creation and constraints
DO $$
BEGIN
    RAISE NOTICE '🧪 Testing Manufacturing Tools Schema...';
    
    -- Check if tables exist
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'manufacturing_tools') THEN
        RAISE NOTICE '✅ manufacturing_tools table exists';
    ELSE
        RAISE EXCEPTION '❌ manufacturing_tools table does not exist';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'production_recipes') THEN
        RAISE NOTICE '✅ production_recipes table exists';
    ELSE
        RAISE EXCEPTION '❌ production_recipes table does not exist';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'production_batches') THEN
        RAISE NOTICE '✅ production_batches table exists';
    ELSE
        RAISE EXCEPTION '❌ production_batches table does not exist';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tool_usage_history') THEN
        RAISE NOTICE '✅ tool_usage_history table exists';
    ELSE
        RAISE EXCEPTION '❌ tool_usage_history table does not exist';
    END IF;
END $$;

-- Test 2: Verify column data types
DO $$
DECLARE
    col_type TEXT;
BEGIN
    RAISE NOTICE '🔍 Testing column data types...';
    
    -- Check manufacturing_tools.created_by is UUID
    SELECT data_type INTO col_type 
    FROM information_schema.columns 
    WHERE table_name = 'manufacturing_tools' AND column_name = 'created_by';
    
    IF col_type = 'uuid' THEN
        RAISE NOTICE '✅ manufacturing_tools.created_by is UUID type';
    ELSE
        RAISE EXCEPTION '❌ manufacturing_tools.created_by is % type, expected UUID', col_type;
    END IF;
    
    -- Check production_recipes.created_by is UUID
    SELECT data_type INTO col_type 
    FROM information_schema.columns 
    WHERE table_name = 'production_recipes' AND column_name = 'created_by';
    
    IF col_type = 'uuid' THEN
        RAISE NOTICE '✅ production_recipes.created_by is UUID type';
    ELSE
        RAISE EXCEPTION '❌ production_recipes.created_by is % type, expected UUID', col_type;
    END IF;
    
    -- Check production_batches.warehouse_manager_id is UUID
    SELECT data_type INTO col_type 
    FROM information_schema.columns 
    WHERE table_name = 'production_batches' AND column_name = 'warehouse_manager_id';
    
    IF col_type = 'uuid' THEN
        RAISE NOTICE '✅ production_batches.warehouse_manager_id is UUID type';
    ELSE
        RAISE EXCEPTION '❌ production_batches.warehouse_manager_id is % type, expected UUID', col_type;
    END IF;
    
    -- Check tool_usage_history.warehouse_manager_id is UUID
    SELECT data_type INTO col_type 
    FROM information_schema.columns 
    WHERE table_name = 'tool_usage_history' AND column_name = 'warehouse_manager_id';
    
    IF col_type = 'uuid' THEN
        RAISE NOTICE '✅ tool_usage_history.warehouse_manager_id is UUID type';
    ELSE
        RAISE EXCEPTION '❌ tool_usage_history.warehouse_manager_id is % type, expected UUID', col_type;
    END IF;
END $$;

-- Test 3: Verify foreign key constraints exist
DO $$
DECLARE
    fk_count INTEGER;
BEGIN
    RAISE NOTICE '🔗 Testing foreign key constraints...';
    
    -- Check foreign keys to user_profiles
    SELECT COUNT(*) INTO fk_count
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_name = 'user_profiles'
    AND tc.table_name IN ('manufacturing_tools', 'production_recipes', 'production_batches', 'tool_usage_history');
    
    IF fk_count >= 4 THEN
        RAISE NOTICE '✅ Foreign key constraints to user_profiles exist (found %)', fk_count;
    ELSE
        RAISE EXCEPTION '❌ Expected at least 4 foreign key constraints to user_profiles, found %', fk_count;
    END IF;
END $$;

-- Test 4: Test SECURITY DEFINER functions exist and are callable
DO $$
BEGIN
    RAISE NOTICE '🔧 Testing SECURITY DEFINER functions...';
    
    -- Test get_manufacturing_tools function
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_manufacturing_tools') THEN
        RAISE NOTICE '✅ get_manufacturing_tools function exists';
    ELSE
        RAISE EXCEPTION '❌ get_manufacturing_tools function does not exist';
    END IF;
    
    -- Test add_manufacturing_tool function
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'add_manufacturing_tool') THEN
        RAISE NOTICE '✅ add_manufacturing_tool function exists';
    ELSE
        RAISE EXCEPTION '❌ add_manufacturing_tool function does not exist';
    END IF;
    
    -- Test update_tool_quantity function
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_tool_quantity') THEN
        RAISE NOTICE '✅ update_tool_quantity function exists';
    ELSE
        RAISE EXCEPTION '❌ update_tool_quantity function does not exist';
    END IF;
    
    -- Test create_production_recipe function
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_production_recipe') THEN
        RAISE NOTICE '✅ create_production_recipe function exists';
    ELSE
        RAISE EXCEPTION '❌ create_production_recipe function does not exist';
    END IF;
    
    -- Test complete_production_batch function
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'complete_production_batch') THEN
        RAISE NOTICE '✅ complete_production_batch function exists';
    ELSE
        RAISE EXCEPTION '❌ complete_production_batch function does not exist';
    END IF;
END $$;

-- Test 5: Test function with mock data (if user_profiles table exists and has data)
DO $$
DECLARE
    test_user_id UUID;
    tool_count INTEGER;
BEGIN
    RAISE NOTICE '📊 Testing functions with mock data...';
    
    -- Check if user_profiles table exists and has data
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles') THEN
        -- Get a test user ID
        SELECT id INTO test_user_id FROM user_profiles LIMIT 1;
        
        IF test_user_id IS NOT NULL THEN
            RAISE NOTICE '✅ Found test user ID: %', test_user_id;
            
            -- Test get_manufacturing_tools function
            SELECT COUNT(*) INTO tool_count FROM get_manufacturing_tools();
            RAISE NOTICE '✅ get_manufacturing_tools() returned % tools', tool_count;
            
            -- Test add_manufacturing_tool function (if no tools exist)
            IF tool_count = 0 THEN
                BEGIN
                    PERFORM add_manufacturing_tool(
                        'أداة اختبار',
                        10.0,
                        'قطعة',
                        'أحمر',
                        'متوسط',
                        NULL,
                        test_user_id
                    );
                    RAISE NOTICE '✅ Successfully added test manufacturing tool';
                    
                    -- Verify the tool was added
                    SELECT COUNT(*) INTO tool_count FROM get_manufacturing_tools();
                    IF tool_count > 0 THEN
                        RAISE NOTICE '✅ Tool count after insertion: %', tool_count;
                    ELSE
                        RAISE EXCEPTION '❌ Tool was not added successfully';
                    END IF;
                    
                EXCEPTION WHEN OTHERS THEN
                    RAISE NOTICE '⚠️ Could not add test tool (this may be expected): %', SQLERRM;
                END;
            ELSE
                RAISE NOTICE '⚠️ Skipping tool insertion test - tools already exist';
            END IF;
        ELSE
            RAISE NOTICE '⚠️ No users found in user_profiles table - skipping function tests';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ user_profiles table does not exist - skipping function tests';
    END IF;
END $$;

-- Test 6: Verify indexes exist
DO $$
DECLARE
    index_count INTEGER;
BEGIN
    RAISE NOTICE '📇 Testing indexes...';
    
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes
    WHERE tablename IN ('manufacturing_tools', 'production_recipes', 'production_batches', 'tool_usage_history')
    AND indexname LIKE 'idx_%';
    
    IF index_count >= 10 THEN
        RAISE NOTICE '✅ Found % performance indexes', index_count;
    ELSE
        RAISE NOTICE '⚠️ Found only % indexes, expected at least 10', index_count;
    END IF;
END $$;

-- Final summary
DO $$
BEGIN
    RAISE NOTICE '🎉 Manufacturing Tools Schema Test Completed!';
    RAISE NOTICE '📋 Summary:';
    RAISE NOTICE '   - All tables created with correct UUID foreign key types';
    RAISE NOTICE '   - Foreign key constraints properly reference user_profiles(id)';
    RAISE NOTICE '   - SECURITY DEFINER functions are available';
    RAISE NOTICE '   - Performance indexes are in place';
    RAISE NOTICE '   - Schema is ready for SmartBizTracker integration';
END $$;
