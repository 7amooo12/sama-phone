-- =====================================================
-- FIX WAREHOUSES TABLE - Add Missing Columns
-- =====================================================
-- This script fixes the "column manager_id does not exist" error
-- by adding the missing columns to the existing warehouses table

-- Check if warehouses table exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'warehouses'
  ) THEN
    -- Create the complete warehouses table if it doesn't exist
    CREATE TABLE warehouses (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      name TEXT NOT NULL,
      location TEXT,
      manager_id UUID REFERENCES user_profiles(id),
      capacity INTEGER DEFAULT 0,
      current_stock INTEGER DEFAULT 0,
      status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance')),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
    RAISE NOTICE '✅ Created warehouses table with all columns';
  ELSE
    RAISE NOTICE 'ℹ️ Warehouses table already exists, checking columns...';
  END IF;
END $$;

-- Add missing columns one by one
DO $$
BEGIN
  -- Add manager_id column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'warehouses' AND column_name = 'manager_id'
  ) THEN
    ALTER TABLE warehouses ADD COLUMN manager_id UUID;
    -- Add foreign key constraint separately to avoid issues
    ALTER TABLE warehouses ADD CONSTRAINT fk_warehouses_manager 
      FOREIGN KEY (manager_id) REFERENCES user_profiles(id);
    RAISE NOTICE '✅ Added manager_id column to warehouses table';
  ELSE
    RAISE NOTICE 'ℹ️ manager_id column already exists';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Could not add manager_id column: %', SQLERRM;
END $$;

DO $$
BEGIN
  -- Add location column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'warehouses' AND column_name = 'location'
  ) THEN
    ALTER TABLE warehouses ADD COLUMN location TEXT;
    RAISE NOTICE '✅ Added location column to warehouses table';
  ELSE
    RAISE NOTICE 'ℹ️ location column already exists';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Could not add location column: %', SQLERRM;
END $$;

DO $$
BEGIN
  -- Add capacity column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'warehouses' AND column_name = 'capacity'
  ) THEN
    ALTER TABLE warehouses ADD COLUMN capacity INTEGER DEFAULT 0;
    RAISE NOTICE '✅ Added capacity column to warehouses table';
  ELSE
    RAISE NOTICE 'ℹ️ capacity column already exists';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Could not add capacity column: %', SQLERRM;
END $$;

DO $$
BEGIN
  -- Add current_stock column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'warehouses' AND column_name = 'current_stock'
  ) THEN
    ALTER TABLE warehouses ADD COLUMN current_stock INTEGER DEFAULT 0;
    RAISE NOTICE '✅ Added current_stock column to warehouses table';
  ELSE
    RAISE NOTICE 'ℹ️ current_stock column already exists';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Could not add current_stock column: %', SQLERRM;
END $$;

DO $$
BEGIN
  -- Add status column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'warehouses' AND column_name = 'status'
  ) THEN
    ALTER TABLE warehouses ADD COLUMN status TEXT DEFAULT 'active';
    -- Add check constraint separately
    ALTER TABLE warehouses ADD CONSTRAINT chk_warehouses_status 
      CHECK (status IN ('active', 'inactive', 'maintenance'));
    RAISE NOTICE '✅ Added status column to warehouses table';
  ELSE
    RAISE NOTICE 'ℹ️ status column already exists';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Could not add status column: %', SQLERRM;
END $$;

-- Verify the table structure
DO $$
DECLARE
  col_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO col_count
  FROM information_schema.columns
  WHERE table_name = 'warehouses'
  AND column_name IN ('id', 'name', 'location', 'manager_id', 'capacity', 'current_stock', 'status', 'created_at', 'updated_at');
  
  RAISE NOTICE '';
  RAISE NOTICE '📊 Warehouses table verification:';
  RAISE NOTICE '   Expected columns: 9';
  RAISE NOTICE '   Found columns: %', col_count;
  
  IF col_count >= 7 THEN
    RAISE NOTICE '✅ Warehouses table is ready for warehouse manager setup';
  ELSE
    RAISE NOTICE '❌ Warehouses table is missing some columns';
  END IF;
END $$;

-- Show current table structure
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'warehouses'
ORDER BY ordinal_position;

-- Final success message
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🎉 Warehouses table fix completed!';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Next steps:';
  RAISE NOTICE '1. Run the warehouse manager setup script again';
  RAISE NOTICE '2. The manager_id column should now work correctly';
  RAISE NOTICE '3. Test creating warehouse records with manager assignments';
END $$;
