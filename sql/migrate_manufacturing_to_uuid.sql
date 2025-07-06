-- =====================================================
-- SMARTBIZTRACKER MANUFACTURING TOOLS UUID MIGRATION
-- Migration script for existing manufacturing tools data
-- =====================================================
--
-- This script migrates existing manufacturing tools data from INTEGER
-- user references to UUID user references.
--
-- IMPORTANT: Run this ONLY if you have existing manufacturing tools data
-- that needs to be migrated. For new installations, use the main schema file.
--
-- Prerequisites:
-- 1. Backup your existing data
-- 2. Ensure user_profiles table exists with UUID id column
-- 3. Have a mapping strategy for integer IDs to UUIDs
-- =====================================================

-- Step 1: Backup existing data
DO $$
BEGIN
    RAISE NOTICE '📦 Starting Manufacturing Tools UUID Migration...';
    
    -- Check if tables exist
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'manufacturing_tools') THEN
        RAISE NOTICE '✅ Found existing manufacturing_tools table';
    ELSE
        RAISE NOTICE '⚠️ No existing manufacturing_tools table found - migration not needed';
        RETURN;
    END IF;
END $$;

-- Step 2: Create backup tables
CREATE TABLE IF NOT EXISTS manufacturing_tools_backup AS 
SELECT * FROM manufacturing_tools;

CREATE TABLE IF NOT EXISTS production_recipes_backup AS 
SELECT * FROM production_recipes;

CREATE TABLE IF NOT EXISTS production_batches_backup AS 
SELECT * FROM production_batches;

CREATE TABLE IF NOT EXISTS tool_usage_history_backup AS 
SELECT * FROM tool_usage_history;

-- Step 3: Add temporary UUID columns
ALTER TABLE manufacturing_tools ADD COLUMN IF NOT EXISTS created_by_uuid UUID;
ALTER TABLE production_recipes ADD COLUMN IF NOT EXISTS created_by_uuid UUID;
ALTER TABLE production_batches ADD COLUMN IF NOT EXISTS warehouse_manager_uuid UUID;
ALTER TABLE tool_usage_history ADD COLUMN IF NOT EXISTS warehouse_manager_uuid UUID;

-- Step 4: Migration logic (customize based on your user ID mapping)
DO $$
DECLARE
    rec RECORD;
    user_uuid UUID;
BEGIN
    RAISE NOTICE '🔄 Migrating user references to UUID...';
    
    -- Option 1: If you have a simple mapping (e.g., user with integer ID 1 maps to a specific UUID)
    -- Customize this section based on your actual user mapping
    
    -- Example: Map integer user IDs to UUIDs
    -- You'll need to replace these with your actual UUID values
    /*
    UPDATE manufacturing_tools 
    SET created_by_uuid = CASE 
        WHEN created_by = 1 THEN 'your-actual-uuid-here'::UUID
        WHEN created_by = 2 THEN 'another-uuid-here'::UUID
        -- Add more mappings as needed
        ELSE NULL
    END
    WHERE created_by IS NOT NULL;
    */
    
    -- Option 2: If you have a mapping table
    /*
    UPDATE manufacturing_tools mt
    SET created_by_uuid = um.new_uuid
    FROM user_mapping um
    WHERE mt.created_by = um.old_integer_id;
    */
    
    -- Option 3: Set all to the first available user (for testing)
    SELECT id INTO user_uuid FROM user_profiles LIMIT 1;
    
    IF user_uuid IS NOT NULL THEN
        UPDATE manufacturing_tools 
        SET created_by_uuid = user_uuid 
        WHERE created_by IS NOT NULL;
        
        UPDATE production_recipes 
        SET created_by_uuid = user_uuid 
        WHERE created_by IS NOT NULL;
        
        UPDATE production_batches 
        SET warehouse_manager_uuid = user_uuid 
        WHERE warehouse_manager_id IS NOT NULL;
        
        UPDATE tool_usage_history 
        SET warehouse_manager_uuid = user_uuid 
        WHERE warehouse_manager_id IS NOT NULL;
        
        RAISE NOTICE '✅ Mapped all user references to UUID: %', user_uuid;
    ELSE
        RAISE EXCEPTION '❌ No users found in user_profiles table';
    END IF;
END $$;

-- Step 5: Drop foreign key constraints
ALTER TABLE manufacturing_tools DROP CONSTRAINT IF EXISTS manufacturing_tools_created_by_fkey;
ALTER TABLE production_recipes DROP CONSTRAINT IF EXISTS production_recipes_created_by_fkey;
ALTER TABLE production_batches DROP CONSTRAINT IF EXISTS production_batches_warehouse_manager_id_fkey;
ALTER TABLE tool_usage_history DROP CONSTRAINT IF EXISTS tool_usage_history_warehouse_manager_id_fkey;

-- Step 6: Drop old integer columns
ALTER TABLE manufacturing_tools DROP COLUMN IF EXISTS created_by;
ALTER TABLE production_recipes DROP COLUMN IF EXISTS created_by;
ALTER TABLE production_batches DROP COLUMN IF EXISTS warehouse_manager_id;
ALTER TABLE tool_usage_history DROP COLUMN IF EXISTS warehouse_manager_id;

-- Step 7: Rename UUID columns to original names
ALTER TABLE manufacturing_tools RENAME COLUMN created_by_uuid TO created_by;
ALTER TABLE production_recipes RENAME COLUMN created_by_uuid TO created_by;
ALTER TABLE production_batches RENAME COLUMN warehouse_manager_uuid TO warehouse_manager_id;
ALTER TABLE tool_usage_history RENAME COLUMN warehouse_manager_uuid TO warehouse_manager_id;

-- Step 8: Add foreign key constraints
ALTER TABLE manufacturing_tools 
ADD CONSTRAINT manufacturing_tools_created_by_fkey 
FOREIGN KEY (created_by) REFERENCES user_profiles(id);

ALTER TABLE production_recipes 
ADD CONSTRAINT production_recipes_created_by_fkey 
FOREIGN KEY (created_by) REFERENCES user_profiles(id);

ALTER TABLE production_batches 
ADD CONSTRAINT production_batches_warehouse_manager_id_fkey 
FOREIGN KEY (warehouse_manager_id) REFERENCES user_profiles(id);

ALTER TABLE tool_usage_history 
ADD CONSTRAINT tool_usage_history_warehouse_manager_id_fkey 
FOREIGN KEY (warehouse_manager_id) REFERENCES user_profiles(id);

-- Step 9: Update functions (drop and recreate with new signatures)
-- Note: This will be done by running the main schema file after migration

-- Step 10: Verification
DO $$
DECLARE
    tool_count INTEGER;
    recipe_count INTEGER;
    batch_count INTEGER;
    history_count INTEGER;
BEGIN
    RAISE NOTICE '🔍 Verifying migration...';
    
    SELECT COUNT(*) INTO tool_count FROM manufacturing_tools;
    SELECT COUNT(*) INTO recipe_count FROM production_recipes;
    SELECT COUNT(*) INTO batch_count FROM production_batches;
    SELECT COUNT(*) INTO history_count FROM tool_usage_history;
    
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📊 Data counts:';
    RAISE NOTICE '   - Manufacturing tools: %', tool_count;
    RAISE NOTICE '   - Production recipes: %', recipe_count;
    RAISE NOTICE '   - Production batches: %', batch_count;
    RAISE NOTICE '   - Usage history: %', history_count;
    
    RAISE NOTICE '📋 Next steps:';
    RAISE NOTICE '   1. Run the updated manufacturing_tools_schema.sql to recreate functions';
    RAISE NOTICE '   2. Run test_manufacturing_schema.sql to verify everything works';
    RAISE NOTICE '   3. Update your Flutter application with the new models';
    RAISE NOTICE '   4. Test the manufacturing tools functionality';
    RAISE NOTICE '   5. Remove backup tables when satisfied with migration';
END $$;

-- Cleanup instructions (run manually after verification)
/*
-- Remove backup tables after successful migration and testing
DROP TABLE IF EXISTS manufacturing_tools_backup;
DROP TABLE IF EXISTS production_recipes_backup;
DROP TABLE IF EXISTS production_batches_backup;
DROP TABLE IF EXISTS tool_usage_history_backup;
*/
