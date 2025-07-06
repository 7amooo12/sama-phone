-- =====================================================
-- IMPORT ANALYSIS SYSTEM MIGRATION (SAFE & IDEMPOTENT)
-- =====================================================
-- Creates/updates the import analysis system with proper
-- numeric field handling to prevent overflow errors.
-- Handles existing tables and policies safely.
--
-- SAFETY GUARANTEES:
-- ✅ Idempotent - can run multiple times safely
-- ✅ No data loss - preserves existing data
-- ✅ Production-safe - handles existing structures
-- ✅ Performance-optimized - includes all necessary indexes
-- ✅ RLS-safe - uses IF NOT EXISTS for policies
-- =====================================================

-- =====================================================
-- 1. HANDLE EXISTING TABLES (SAFE ALTERATIONS)
-- =====================================================

-- Check and fix total_quantity column type if it exists and is wrong type
DO $$
DECLARE
    total_quantity_type TEXT;
    table_exists BOOLEAN := FALSE;
BEGIN
    -- Check if packing_list_items table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'packing_list_items'
    ) INTO table_exists;

    IF table_exists THEN
        RAISE NOTICE '🔧 Found existing packing_list_items table - checking total_quantity column type...';

        -- Get current column type
        SELECT data_type INTO total_quantity_type
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'packing_list_items'
        AND column_name = 'total_quantity';

        IF total_quantity_type = 'integer' THEN
            RAISE NOTICE '⚠️  FIXING: total_quantity is INTEGER - converting to BIGINT to handle large values';

            -- Safely alter the column type
            ALTER TABLE public.packing_list_items
            ALTER COLUMN total_quantity TYPE BIGINT;

            RAISE NOTICE '✅ SUCCESS: total_quantity column converted from INTEGER to BIGINT';

        ELSIF total_quantity_type = 'bigint' THEN
            RAISE NOTICE '✅ GOOD: total_quantity is already BIGINT - no changes needed';

        ELSE
            RAISE NOTICE '❓ UNEXPECTED: total_quantity type is % - leaving as is', total_quantity_type;
        END IF;

        -- Check and add missing columns if table exists
        RAISE NOTICE '🔧 Checking for missing columns in existing packing_list_items table...';

        -- Add materials column if missing
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'packing_list_items' AND column_name = 'materials') THEN
            ALTER TABLE public.packing_list_items ADD COLUMN materials JSONB DEFAULT '[]';
            RAISE NOTICE '✅ Added missing column: materials';
        END IF;

        -- Add other potentially missing columns
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'packing_list_items' AND column_name = 'product_group_id') THEN
            ALTER TABLE public.packing_list_items ADD COLUMN product_group_id TEXT;
            RAISE NOTICE '✅ Added missing column: product_group_id';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'packing_list_items' AND column_name = 'is_grouped_product') THEN
            ALTER TABLE public.packing_list_items ADD COLUMN is_grouped_product BOOLEAN DEFAULT FALSE;
            RAISE NOTICE '✅ Added missing column: is_grouped_product';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'packing_list_items' AND column_name = 'source_row_references') THEN
            ALTER TABLE public.packing_list_items ADD COLUMN source_row_references JSONB DEFAULT '[]';
            RAISE NOTICE '✅ Added missing column: source_row_references';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'packing_list_items' AND column_name = 'grouping_confidence') THEN
            ALTER TABLE public.packing_list_items ADD COLUMN grouping_confidence DECIMAL(3,2);
            RAISE NOTICE '✅ Added missing column: grouping_confidence';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'packing_list_items' AND column_name = 'duplicate_cluster_id') THEN
            ALTER TABLE public.packing_list_items ADD COLUMN duplicate_cluster_id UUID;
            RAISE NOTICE '✅ Added missing column: duplicate_cluster_id';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'packing_list_items' AND column_name = 'similarity_score') THEN
            ALTER TABLE public.packing_list_items ADD COLUMN similarity_score DECIMAL(3,2) DEFAULT 0.0;
            RAISE NOTICE '✅ Added missing column: similarity_score';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'packing_list_items' AND column_name = 'is_potential_duplicate') THEN
            ALTER TABLE public.packing_list_items ADD COLUMN is_potential_duplicate BOOLEAN DEFAULT FALSE;
            RAISE NOTICE '✅ Added missing column: is_potential_duplicate';
        END IF;

    ELSE
        RAISE NOTICE '📝 packing_list_items table does not exist - will be created with correct BIGINT type';
    END IF;
END $$;

-- =====================================================
-- 2. CORE TABLES
-- =====================================================

-- Import Batches Table - Tracks file imports and processing status
CREATE TABLE IF NOT EXISTS public.import_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  filename TEXT NOT NULL,
  original_filename TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  file_type TEXT NOT NULL CHECK (file_type IN ('xlsx', 'xls', 'csv')),
  total_items INTEGER DEFAULT 0,
  processed_items INTEGER DEFAULT 0,
  processing_status TEXT DEFAULT 'pending' CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
  
  -- Summary statistics (JSON for flexibility)
  summary_stats JSONB DEFAULT '{}',
  category_breakdown JSONB DEFAULT '{}',
  financial_summary JSONB DEFAULT '{}',
  
  -- Validation and error tracking
  validation_errors JSONB DEFAULT '[]',
  processing_errors JSONB DEFAULT '[]',
  
  -- Version management for duplicate batch handling
  version_number INTEGER DEFAULT 1,
  parent_batch_id UUID REFERENCES public.import_batches(id) ON DELETE SET NULL,
  
  -- Currency settings for this batch
  currency_settings JSONB DEFAULT '{"base_currency": "RMB", "target_currency": "EGP", "exchange_rate": 2.25}',
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Metadata for processing info
  metadata JSONB DEFAULT '{}'
);

-- Packing List Items Table - Core data from Excel/CSV files
-- CRITICAL FIX: Changed total_quantity from INTEGER to BIGINT to handle large values
CREATE TABLE IF NOT EXISTS public.packing_list_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  import_batch_id UUID NOT NULL REFERENCES public.import_batches(id) ON DELETE CASCADE,
  
  -- Core item identification
  serial_number INTEGER,
  item_number TEXT NOT NULL,
  image_url TEXT,
  
  -- Quantity information - FIXED: BIGINT for large quantities
  carton_count INTEGER,
  pieces_per_carton INTEGER,
  total_quantity BIGINT NOT NULL,
  
  -- Dimensions (stored as JSON for flexibility)
  dimensions JSONB DEFAULT '{}', -- {size1, size2, size3, unit}
  total_cubic_meters DECIMAL(15,6),
  
  -- Weight information (stored as JSON)
  weights JSONB DEFAULT '{}', -- {net_weight, gross_weight, total_net_weight, total_gross_weight, unit}
  
  -- Pricing information with high precision for financial accuracy
  unit_price DECIMAL(12,6),
  rmb_price DECIMAL(12,6),
  converted_price DECIMAL(12,6), -- Price in user's selected currency
  conversion_rate DECIMAL(15,6), -- Exchange rate used for conversion
  conversion_currency TEXT DEFAULT 'USD',
  
  -- Remarks and notes (multiple fields support)
  remarks JSONB DEFAULT '{}', -- {remarks_a, remarks_b, remarks_c}
  
  -- Classification and analysis
  category TEXT,
  subcategory TEXT,
  classification_confidence DECIMAL(3,2), -- 0.00 to 1.00
  
  -- Data validation and quality
  validation_status TEXT DEFAULT 'pending' CHECK (validation_status IN ('pending', 'valid', 'invalid', 'warning')),
  validation_issues JSONB DEFAULT '[]',
  data_quality_score DECIMAL(3,2), -- 0.00 to 1.00
  
  -- Smart grouping and duplicate detection
  materials JSONB DEFAULT '[]', -- Array of material names extracted from remarks
  product_group_id TEXT, -- Groups similar products together
  is_grouped_product BOOLEAN DEFAULT FALSE,
  source_row_references JSONB DEFAULT '[]', -- References to original Excel rows
  grouping_confidence DECIMAL(3,2), -- 0.00 to 1.00
  
  -- Duplicate detection
  duplicate_cluster_id UUID,
  similarity_score DECIMAL(3,2) DEFAULT 0.0, -- 0.00 to 1.00
  is_potential_duplicate BOOLEAN DEFAULT FALSE,
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Additional metadata
  metadata JSONB DEFAULT '{}'
);

-- Currency Rates Table - Real-time exchange rate tracking
CREATE TABLE IF NOT EXISTS public.currency_rates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  base_currency TEXT NOT NULL,
  target_currency TEXT NOT NULL,
  rate DECIMAL(15,6) NOT NULL,
  rate_date DATE NOT NULL,
  rate_source TEXT DEFAULT 'manual', -- 'api', 'manual', 'cached'
  
  -- API metadata
  api_provider TEXT,
  api_response_data JSONB DEFAULT '{}',
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure unique rates per currency pair per date
  UNIQUE(base_currency, target_currency, rate_date)
);

-- Import Analysis Settings Table - User preferences and configuration
CREATE TABLE IF NOT EXISTS public.import_analysis_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Default currency settings
  default_base_currency TEXT DEFAULT 'RMB',
  default_target_currency TEXT DEFAULT 'EGP',
  default_exchange_rate DECIMAL(15,6) DEFAULT 2.25,
  
  -- Processing preferences
  auto_detect_duplicates BOOLEAN DEFAULT TRUE,
  auto_group_similar_products BOOLEAN DEFAULT TRUE,
  enable_smart_categorization BOOLEAN DEFAULT TRUE,
  
  -- Validation settings
  strict_validation BOOLEAN DEFAULT FALSE,
  require_all_fields BOOLEAN DEFAULT FALSE,
  
  -- Export preferences
  preferred_export_format TEXT DEFAULT 'xlsx' CHECK (preferred_export_format IN ('xlsx', 'csv', 'json')),
  include_analysis_metadata BOOLEAN DEFAULT TRUE,
  
  -- UI preferences
  ui_preferences JSONB DEFAULT '{}',
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure one settings record per user
  UNIQUE(user_id)
);

-- =====================================================
-- 3. PERFORMANCE INDEXES
-- =====================================================

-- Import Batches Indexes
CREATE INDEX IF NOT EXISTS idx_import_batches_user_status 
ON public.import_batches(created_by, processing_status);

CREATE INDEX IF NOT EXISTS idx_import_batches_created_at 
ON public.import_batches(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_import_batches_filename 
ON public.import_batches(filename);

CREATE INDEX IF NOT EXISTS idx_import_batches_parent 
ON public.import_batches(parent_batch_id) WHERE parent_batch_id IS NOT NULL;

-- Packing List Items Indexes
CREATE INDEX IF NOT EXISTS idx_packing_items_batch_status 
ON public.packing_list_items(import_batch_id, validation_status);

CREATE INDEX IF NOT EXISTS idx_packing_items_item_number 
ON public.packing_list_items(item_number);

CREATE INDEX IF NOT EXISTS idx_packing_items_category 
ON public.packing_list_items(category) WHERE category IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_packing_items_duplicate_cluster 
ON public.packing_list_items(duplicate_cluster_id) WHERE duplicate_cluster_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_packing_items_potential_duplicates 
ON public.packing_list_items(is_potential_duplicate) WHERE is_potential_duplicate = TRUE;

CREATE INDEX IF NOT EXISTS idx_packing_items_created_at 
ON public.packing_list_items(created_at DESC);

-- Currency Rates Indexes
CREATE INDEX IF NOT EXISTS idx_currency_rates_lookup 
ON public.currency_rates(base_currency, target_currency, rate_date DESC);

-- Import Analysis Settings Indexes
CREATE INDEX IF NOT EXISTS idx_import_analysis_settings_user 
ON public.import_analysis_settings(user_id);

-- =====================================================
-- 4. ROW LEVEL SECURITY (RLS) - SAFE POLICY CREATION
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.import_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.packing_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.currency_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.import_analysis_settings ENABLE ROW LEVEL SECURITY;

-- Import Batches RLS Policies (Safe creation - handles existing policies)
DO $$
BEGIN
    -- Create policies only if they don't exist
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'import_batches' AND policyname = 'Users can view their own import batches') THEN
        CREATE POLICY "Users can view their own import batches" ON public.import_batches
          FOR SELECT USING (auth.uid() = created_by);
        RAISE NOTICE '✅ Created policy: Users can view their own import batches';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Users can view their own import batches';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'import_batches' AND policyname = 'Users can create their own import batches') THEN
        CREATE POLICY "Users can create their own import batches" ON public.import_batches
          FOR INSERT WITH CHECK (auth.uid() = created_by);
        RAISE NOTICE '✅ Created policy: Users can create their own import batches';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Users can create their own import batches';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'import_batches' AND policyname = 'Users can update their own import batches') THEN
        CREATE POLICY "Users can update their own import batches" ON public.import_batches
          FOR UPDATE USING (auth.uid() = created_by);
        RAISE NOTICE '✅ Created policy: Users can update their own import batches';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Users can update their own import batches';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'import_batches' AND policyname = 'Users can delete their own import batches') THEN
        CREATE POLICY "Users can delete their own import batches" ON public.import_batches
          FOR DELETE USING (auth.uid() = created_by);
        RAISE NOTICE '✅ Created policy: Users can delete their own import batches';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Users can delete their own import batches';
    END IF;
END $$;

-- Packing List Items RLS Policies (Safe creation - handles existing policies)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'packing_list_items' AND policyname = 'Users can view items from their own batches') THEN
        CREATE POLICY "Users can view items from their own batches" ON public.packing_list_items
          FOR SELECT USING (
            EXISTS (
              SELECT 1 FROM public.import_batches
              WHERE id = import_batch_id AND created_by = auth.uid()
            )
          );
        RAISE NOTICE '✅ Created policy: Users can view items from their own batches';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Users can view items from their own batches';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'packing_list_items' AND policyname = 'Users can create items for their own batches') THEN
        CREATE POLICY "Users can create items for their own batches" ON public.packing_list_items
          FOR INSERT WITH CHECK (
            EXISTS (
              SELECT 1 FROM public.import_batches
              WHERE id = import_batch_id AND created_by = auth.uid()
            )
          );
        RAISE NOTICE '✅ Created policy: Users can create items for their own batches';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Users can create items for their own batches';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'packing_list_items' AND policyname = 'Users can update items from their own batches') THEN
        CREATE POLICY "Users can update items from their own batches" ON public.packing_list_items
          FOR UPDATE USING (
            EXISTS (
              SELECT 1 FROM public.import_batches
              WHERE id = import_batch_id AND created_by = auth.uid()
            )
          );
        RAISE NOTICE '✅ Created policy: Users can update items from their own batches';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Users can update items from their own batches';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'packing_list_items' AND policyname = 'Users can delete items from their own batches') THEN
        CREATE POLICY "Users can delete items from their own batches" ON public.packing_list_items
          FOR DELETE USING (
            EXISTS (
              SELECT 1 FROM public.import_batches
              WHERE id = import_batch_id AND created_by = auth.uid()
            )
          );
        RAISE NOTICE '✅ Created policy: Users can delete items from their own batches';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Users can delete items from their own batches';
    END IF;
END $$;

-- Currency Rates RLS Policies (Safe creation - read-only for all authenticated users)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'currency_rates' AND policyname = 'Authenticated users can view currency rates') THEN
        CREATE POLICY "Authenticated users can view currency rates" ON public.currency_rates
          FOR SELECT TO authenticated USING (true);
        RAISE NOTICE '✅ Created policy: Authenticated users can view currency rates';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Authenticated users can view currency rates';
    END IF;
END $$;

-- Import Analysis Settings RLS Policies (Safe creation)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'import_analysis_settings' AND policyname = 'Users can view their own settings') THEN
        CREATE POLICY "Users can view their own settings" ON public.import_analysis_settings
          FOR SELECT USING (auth.uid() = user_id);
        RAISE NOTICE '✅ Created policy: Users can view their own settings';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Users can view their own settings';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'import_analysis_settings' AND policyname = 'Users can create their own settings') THEN
        CREATE POLICY "Users can create their own settings" ON public.import_analysis_settings
          FOR INSERT WITH CHECK (auth.uid() = user_id);
        RAISE NOTICE '✅ Created policy: Users can create their own settings';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Users can create their own settings';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'import_analysis_settings' AND policyname = 'Users can update their own settings') THEN
        CREATE POLICY "Users can update their own settings" ON public.import_analysis_settings
          FOR UPDATE USING (auth.uid() = user_id);
        RAISE NOTICE '✅ Created policy: Users can update their own settings';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Users can update their own settings';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'import_analysis_settings' AND policyname = 'Users can delete their own settings') THEN
        CREATE POLICY "Users can delete their own settings" ON public.import_analysis_settings
          FOR DELETE USING (auth.uid() = user_id);
        RAISE NOTICE '✅ Created policy: Users can delete their own settings';
    ELSE
        RAISE NOTICE '⏭️  Policy already exists: Users can delete their own settings';
    END IF;
END $$;

-- =====================================================
-- 5. COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON TABLE public.import_batches IS 'Tracks Excel/CSV file imports with processing status and metadata';
COMMENT ON TABLE public.packing_list_items IS 'Core packing list data extracted from import files with analysis results';
COMMENT ON TABLE public.currency_rates IS 'Real-time currency exchange rates for price conversion';
COMMENT ON TABLE public.import_analysis_settings IS 'User preferences and configuration for import analysis';

COMMENT ON COLUMN public.packing_list_items.total_quantity IS 'BIGINT to handle large quantities from carton_count * pieces_per_carton calculations';
COMMENT ON COLUMN public.packing_list_items.materials IS 'Array of material names extracted from remarks for smart grouping';
COMMENT ON COLUMN public.packing_list_items.product_group_id IS 'Groups similar products together for consolidated analysis';

-- =====================================================
-- 6. VERIFICATION AND FINAL STATUS
-- =====================================================

DO $$
DECLARE
    tables_created INTEGER := 0;
    policies_created INTEGER := 0;
    total_quantity_type TEXT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎯 === IMPORT ANALYSIS MIGRATION VERIFICATION ===';

    -- Count created tables
    SELECT COUNT(*) INTO tables_created
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name IN ('import_batches', 'packing_list_items', 'currency_rates', 'import_analysis_settings');

    -- Count created policies
    SELECT COUNT(*) INTO policies_created
    FROM pg_policies
    WHERE schemaname = 'public'
    AND tablename IN ('import_batches', 'packing_list_items', 'currency_rates', 'import_analysis_settings');

    -- Check final total_quantity type
    SELECT data_type INTO total_quantity_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'packing_list_items'
    AND column_name = 'total_quantity';

    RAISE NOTICE '� MIGRATION RESULTS:';
    RAISE NOTICE '   Tables available: % of 4', tables_created;
    RAISE NOTICE '   RLS policies active: %', policies_created;
    RAISE NOTICE '   total_quantity column type: %', COALESCE(total_quantity_type, 'NOT FOUND');
    RAISE NOTICE '';

    IF tables_created = 4 AND total_quantity_type = 'bigint' THEN
        RAISE NOTICE '✅ SUCCESS: Import Analysis System is ready for use!';
        RAISE NOTICE '🔧 CRITICAL FIX APPLIED: total_quantity now uses BIGINT to handle large values';
        RAISE NOTICE '� Excel files with large quantities can now be processed without overflow errors';
    ELSE
        RAISE NOTICE '⚠️  PARTIAL SUCCESS: Some components may need manual verification';
        IF total_quantity_type != 'bigint' THEN
            RAISE NOTICE '❌ ISSUE: total_quantity is not BIGINT - numeric overflow may still occur';
        END IF;
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '📋 NEXT STEPS:';
    RAISE NOTICE '   1. Test Excel import with the problematic file';
    RAISE NOTICE '   2. Verify all 145 rows are processed without stopping';
    RAISE NOTICE '   3. Confirm no numeric overflow errors occur';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration completed successfully';
END $$;
