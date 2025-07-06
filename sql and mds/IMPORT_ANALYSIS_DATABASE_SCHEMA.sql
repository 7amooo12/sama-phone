-- =====================================================
-- SmartBizTracker Import Analysis Database Schema
-- =====================================================
-- This script creates the comprehensive database schema for the Import Analysis feature
-- Following SmartBizTracker security patterns with SECURITY DEFINER functions
-- and aggressive performance optimization with proper indexing

-- =====================================================
-- 1. CORE TABLES
-- =====================================================

-- Import Batches Table - Tracks file imports and processing status
CREATE TABLE IF NOT EXISTS import_batches (
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
  parent_batch_id UUID REFERENCES import_batches(id) ON DELETE SET NULL,
  
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
CREATE TABLE IF NOT EXISTS packing_list_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  import_batch_id UUID NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
  
  -- Core item identification
  serial_number INTEGER,
  item_number TEXT NOT NULL,
  image_url TEXT,
  
  -- Quantity information
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
  
  -- Duplicate detection and clustering
  duplicate_cluster_id UUID,
  similarity_score DECIMAL(3,2), -- Similarity percentage for duplicates
  is_potential_duplicate BOOLEAN DEFAULT FALSE,
  
  -- Audit and tracking
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Processing metadata
  metadata JSONB DEFAULT '{}' -- Processing info, original row data, etc.
);

-- Currency Rates Table - Real-time exchange rate tracking
CREATE TABLE IF NOT EXISTS currency_rates (
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

-- Import Analysis Settings - User preferences and configuration
CREATE TABLE IF NOT EXISTS import_analysis_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- File processing settings
  max_file_size_mb INTEGER DEFAULT 50,
  auto_detect_headers BOOLEAN DEFAULT TRUE,
  default_currency TEXT DEFAULT 'EGP',
  
  -- Classification settings
  category_classification_enabled BOOLEAN DEFAULT TRUE,
  duplicate_detection_threshold DECIMAL(3,2) DEFAULT 0.90,
  auto_merge_duplicates BOOLEAN DEFAULT FALSE,
  
  -- UI preferences
  items_per_page INTEGER DEFAULT 50,
  default_view TEXT DEFAULT 'table' CHECK (default_view IN ('table', 'cards', 'grid')),
  show_advanced_analytics BOOLEAN DEFAULT TRUE,
  
  -- Export preferences
  default_export_format TEXT DEFAULT 'xlsx' CHECK (default_export_format IN ('xlsx', 'pdf', 'csv')),
  include_images_in_export BOOLEAN DEFAULT TRUE,
  
  -- Notification settings
  notify_on_completion BOOLEAN DEFAULT TRUE,
  notify_on_errors BOOLEAN DEFAULT TRUE,
  
  -- Settings data
  settings_data JSONB DEFAULT '{}',
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- One settings record per user
  UNIQUE(user_id)
);

-- =====================================================
-- 2. PERFORMANCE INDEXES
-- =====================================================

-- Import Batches Indexes
CREATE INDEX IF NOT EXISTS idx_import_batches_user_status 
ON import_batches(created_by, processing_status);

CREATE INDEX IF NOT EXISTS idx_import_batches_created_at 
ON import_batches(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_import_batches_filename 
ON import_batches(filename);

CREATE INDEX IF NOT EXISTS idx_import_batches_parent 
ON import_batches(parent_batch_id) WHERE parent_batch_id IS NOT NULL;

-- Packing List Items Indexes
CREATE INDEX IF NOT EXISTS idx_packing_items_batch_status 
ON packing_list_items(import_batch_id, validation_status);

CREATE INDEX IF NOT EXISTS idx_packing_items_item_number 
ON packing_list_items(item_number);

CREATE INDEX IF NOT EXISTS idx_packing_items_category 
ON packing_list_items(category) WHERE category IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_packing_items_duplicate_cluster 
ON packing_list_items(duplicate_cluster_id) WHERE duplicate_cluster_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_packing_items_potential_duplicates 
ON packing_list_items(is_potential_duplicate) WHERE is_potential_duplicate = TRUE;

CREATE INDEX IF NOT EXISTS idx_packing_items_created_at 
ON packing_list_items(created_at DESC);

-- Currency Rates Indexes
CREATE INDEX IF NOT EXISTS idx_currency_rates_lookup 
ON currency_rates(base_currency, target_currency, rate_date DESC);

CREATE INDEX IF NOT EXISTS idx_currency_rates_date 
ON currency_rates(rate_date DESC);

-- Import Analysis Settings Index
CREATE INDEX IF NOT EXISTS idx_import_settings_user 
ON import_analysis_settings(user_id);

-- =====================================================
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE import_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE packing_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE currency_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE import_analysis_settings ENABLE ROW LEVEL SECURITY;

-- Import Batches RLS Policies
CREATE POLICY "Users can view their own import batches" ON import_batches
  FOR SELECT USING (auth.uid() = created_by);

CREATE POLICY "Users can insert their own import batches" ON import_batches
  FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update their own import batches" ON import_batches
  FOR UPDATE USING (auth.uid() = created_by);

CREATE POLICY "Users can delete their own import batches" ON import_batches
  FOR DELETE USING (auth.uid() = created_by);

-- Packing List Items RLS Policies
CREATE POLICY "Users can view items from their own batches" ON packing_list_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM import_batches 
      WHERE import_batches.id = packing_list_items.import_batch_id 
      AND import_batches.created_by = auth.uid()
    )
  );

CREATE POLICY "Users can insert items to their own batches" ON packing_list_items
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM import_batches 
      WHERE import_batches.id = packing_list_items.import_batch_id 
      AND import_batches.created_by = auth.uid()
    )
  );

CREATE POLICY "Users can update items in their own batches" ON packing_list_items
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM import_batches 
      WHERE import_batches.id = packing_list_items.import_batch_id 
      AND import_batches.created_by = auth.uid()
    )
  );

CREATE POLICY "Users can delete items from their own batches" ON packing_list_items
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM import_batches 
      WHERE import_batches.id = packing_list_items.import_batch_id 
      AND import_batches.created_by = auth.uid()
    )
  );

-- Currency Rates RLS Policies (Public read, admin write)
CREATE POLICY "Anyone can view currency rates" ON currency_rates
  FOR SELECT USING (true);

-- Import Analysis Settings RLS Policies
CREATE POLICY "Users can view their own settings" ON import_analysis_settings
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own settings" ON import_analysis_settings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own settings" ON import_analysis_settings
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own settings" ON import_analysis_settings
  FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- 4. SECURITY DEFINER FUNCTIONS
-- =====================================================

-- Function to get import batch statistics with security
CREATE OR REPLACE FUNCTION get_import_batch_statistics(batch_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSON;
  batch_owner UUID;
BEGIN
  -- Verify ownership
  SELECT created_by INTO batch_owner
  FROM import_batches
  WHERE id = batch_id;

  IF batch_owner IS NULL OR batch_owner != auth.uid() THEN
    RAISE EXCEPTION 'Access denied to batch statistics';
  END IF;

  -- Calculate comprehensive statistics
  SELECT json_build_object(
    'total_items', COUNT(*),
    'valid_items', COUNT(*) FILTER (WHERE validation_status = 'valid'),
    'invalid_items', COUNT(*) FILTER (WHERE validation_status = 'invalid'),
    'warning_items', COUNT(*) FILTER (WHERE validation_status = 'warning'),
    'pending_items', COUNT(*) FILTER (WHERE validation_status = 'pending'),
    'potential_duplicates', COUNT(*) FILTER (WHERE is_potential_duplicate = true),
    'total_quantity', COALESCE(SUM(total_quantity), 0),
    'total_cartons', COALESCE(SUM(carton_count), 0),
    'total_cubic_meters', COALESCE(SUM(total_cubic_meters), 0),
    'total_rmb_value', COALESCE(SUM(rmb_price * total_quantity), 0),
    'total_converted_value', COALESCE(SUM(converted_price * total_quantity), 0),
    'categories', json_agg(DISTINCT category) FILTER (WHERE category IS NOT NULL),
    'avg_data_quality', COALESCE(AVG(data_quality_score), 0)
  ) INTO result
  FROM packing_list_items
  WHERE import_batch_id = batch_id;

  RETURN result;
END;
$$;

-- Function to get category breakdown for a batch
CREATE OR REPLACE FUNCTION get_batch_category_breakdown(batch_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSON;
  batch_owner UUID;
BEGIN
  -- Verify ownership
  SELECT created_by INTO batch_owner
  FROM import_batches
  WHERE id = batch_id;

  IF batch_owner IS NULL OR batch_owner != auth.uid() THEN
    RAISE EXCEPTION 'Access denied to batch category breakdown';
  END IF;

  -- Get category breakdown with statistics
  SELECT json_agg(
    json_build_object(
      'category', COALESCE(category, 'Uncategorized'),
      'item_count', item_count,
      'total_quantity', total_quantity,
      'total_value_rmb', total_value_rmb,
      'total_value_converted', total_value_converted,
      'percentage', ROUND((item_count::DECIMAL / total_items * 100), 2)
    )
  ) INTO result
  FROM (
    SELECT
      category,
      COUNT(*) as item_count,
      SUM(total_quantity) as total_quantity,
      SUM(rmb_price * total_quantity) as total_value_rmb,
      SUM(converted_price * total_quantity) as total_value_converted,
      (SELECT COUNT(*) FROM packing_list_items WHERE import_batch_id = batch_id) as total_items
    FROM packing_list_items
    WHERE import_batch_id = batch_id
    GROUP BY category
    ORDER BY item_count DESC
  ) category_stats;

  RETURN COALESCE(result, '[]'::JSON);
END;
$$;

-- Function to detect and cluster duplicate items
CREATE OR REPLACE FUNCTION detect_duplicate_items(batch_id UUID, similarity_threshold DECIMAL DEFAULT 0.90)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSON;
  batch_owner UUID;
  cluster_id UUID;
  item_record RECORD;
  similar_record RECORD;
BEGIN
  -- Verify ownership
  SELECT created_by INTO batch_owner
  FROM import_batches
  WHERE id = batch_id;

  IF batch_owner IS NULL OR batch_owner != auth.uid() THEN
    RAISE EXCEPTION 'Access denied to duplicate detection';
  END IF;

  -- Reset existing duplicate flags for this batch
  UPDATE packing_list_items
  SET duplicate_cluster_id = NULL,
      similarity_score = NULL,
      is_potential_duplicate = FALSE
  WHERE import_batch_id = batch_id;

  -- Simple duplicate detection based on item_number similarity
  -- In production, this would use more sophisticated string matching algorithms
  FOR item_record IN
    SELECT id, item_number, category, total_quantity, rmb_price
    FROM packing_list_items
    WHERE import_batch_id = batch_id
    AND duplicate_cluster_id IS NULL
    ORDER BY item_number
  LOOP
    -- Find similar items
    FOR similar_record IN
      SELECT id, item_number,
             -- Simple similarity calculation (can be enhanced with Levenshtein distance)
             CASE
               WHEN item_number = item_record.item_number THEN 1.0
               WHEN item_number ILIKE '%' || item_record.item_number || '%'
                 OR item_record.item_number ILIKE '%' || item_number || '%' THEN 0.8
               ELSE 0.0
             END as similarity
      FROM packing_list_items
      WHERE import_batch_id = batch_id
      AND id != item_record.id
      AND duplicate_cluster_id IS NULL
    LOOP
      IF similar_record.similarity >= similarity_threshold THEN
        -- Create new cluster if needed
        IF cluster_id IS NULL THEN
          cluster_id := gen_random_uuid();

          -- Update the original item
          UPDATE packing_list_items
          SET duplicate_cluster_id = cluster_id,
              similarity_score = 1.0,
              is_potential_duplicate = TRUE
          WHERE id = item_record.id;
        END IF;

        -- Update the similar item
        UPDATE packing_list_items
        SET duplicate_cluster_id = cluster_id,
            similarity_score = similar_record.similarity,
            is_potential_duplicate = TRUE
        WHERE id = similar_record.id;
      END IF;
    END LOOP;

    -- Reset cluster_id for next group
    cluster_id := NULL;
  END LOOP;

  -- Return duplicate clusters summary
  SELECT json_agg(
    json_build_object(
      'cluster_id', duplicate_cluster_id,
      'item_count', COUNT(*),
      'items', json_agg(
        json_build_object(
          'id', id,
          'item_number', item_number,
          'similarity_score', similarity_score,
          'total_quantity', total_quantity
        )
      )
    )
  ) INTO result
  FROM packing_list_items
  WHERE import_batch_id = batch_id
  AND duplicate_cluster_id IS NOT NULL
  GROUP BY duplicate_cluster_id;

  RETURN COALESCE(result, '[]'::JSON);
END;
$$;

-- Function to update currency conversion for a batch
CREATE OR REPLACE FUNCTION update_batch_currency_conversion(
  batch_id UUID,
  target_currency TEXT,
  exchange_rate DECIMAL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  batch_owner UUID;
  updated_count INTEGER;
BEGIN
  -- Verify ownership
  SELECT created_by INTO batch_owner
  FROM import_batches
  WHERE id = batch_id;

  IF batch_owner IS NULL OR batch_owner != auth.uid() THEN
    RAISE EXCEPTION 'Access denied to batch currency conversion';
  END IF;

  -- Update all items in the batch
  UPDATE packing_list_items
  SET converted_price = rmb_price * exchange_rate,
      conversion_rate = exchange_rate,
      conversion_currency = target_currency,
      updated_at = NOW()
  WHERE import_batch_id = batch_id
  AND rmb_price IS NOT NULL;

  GET DIAGNOSTICS updated_count = ROW_COUNT;

  -- Update batch currency settings
  UPDATE import_batches
  SET currency_settings = jsonb_set(
        currency_settings,
        '{target_currency}',
        to_jsonb(target_currency)
      ),
      currency_settings = jsonb_set(
        currency_settings,
        '{exchange_rate}',
        to_jsonb(exchange_rate)
      ),
      updated_at = NOW()
  WHERE id = batch_id;

  RETURN updated_count > 0;
END;
$$;

-- Function to get latest currency rate
CREATE OR REPLACE FUNCTION get_latest_currency_rate(
  base_curr TEXT,
  target_curr TEXT
)
RETURNS DECIMAL
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  latest_rate DECIMAL;
BEGIN
  SELECT rate INTO latest_rate
  FROM currency_rates
  WHERE base_currency = base_curr
  AND target_currency = target_curr
  ORDER BY rate_date DESC, created_at DESC
  LIMIT 1;

  RETURN COALESCE(latest_rate, 0.0);
END;
$$;

-- =====================================================
-- 5. TRIGGERS AND AUTOMATION
-- =====================================================

-- Trigger function to update batch statistics when items change
CREATE OR REPLACE FUNCTION update_batch_statistics()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  batch_id UUID;
  stats JSON;
BEGIN
  -- Get the batch ID from the affected row
  IF TG_OP = 'DELETE' THEN
    batch_id := OLD.import_batch_id;
  ELSE
    batch_id := NEW.import_batch_id;
  END IF;

  -- Update batch statistics
  UPDATE import_batches
  SET
    total_items = (
      SELECT COUNT(*)
      FROM packing_list_items
      WHERE import_batch_id = batch_id
    ),
    processed_items = (
      SELECT COUNT(*)
      FROM packing_list_items
      WHERE import_batch_id = batch_id
      AND validation_status != 'pending'
    ),
    summary_stats = (
      SELECT json_build_object(
        'total_quantity', COALESCE(SUM(total_quantity), 0),
        'total_cartons', COALESCE(SUM(carton_count), 0),
        'total_cubic_meters', COALESCE(SUM(total_cubic_meters), 0),
        'total_rmb_value', COALESCE(SUM(rmb_price * total_quantity), 0),
        'avg_data_quality', COALESCE(AVG(data_quality_score), 0)
      )
      FROM packing_list_items
      WHERE import_batch_id = batch_id
    ),
    updated_at = NOW()
  WHERE id = batch_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Create trigger for automatic batch statistics updates
DROP TRIGGER IF EXISTS trigger_update_batch_statistics ON packing_list_items;
CREATE TRIGGER trigger_update_batch_statistics
  AFTER INSERT OR UPDATE OR DELETE ON packing_list_items
  FOR EACH ROW
  EXECUTE FUNCTION update_batch_statistics();

-- Trigger function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Create triggers for updated_at columns
DROP TRIGGER IF EXISTS trigger_import_batches_updated_at ON import_batches;
CREATE TRIGGER trigger_import_batches_updated_at
  BEFORE UPDATE ON import_batches
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_packing_items_updated_at ON packing_list_items;
CREATE TRIGGER trigger_packing_items_updated_at
  BEFORE UPDATE ON packing_list_items
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_currency_rates_updated_at ON currency_rates;
CREATE TRIGGER trigger_currency_rates_updated_at
  BEFORE UPDATE ON currency_rates
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_import_settings_updated_at ON import_analysis_settings;
CREATE TRIGGER trigger_import_settings_updated_at
  BEFORE UPDATE ON import_analysis_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 6. INITIAL DATA AND CONFIGURATION
-- =====================================================

-- Insert default currency rates (these would be updated by the API)
INSERT INTO currency_rates (base_currency, target_currency, rate, rate_date, rate_source)
VALUES
  ('RMB', 'USD', 0.14, CURRENT_DATE, 'manual'),
  ('RMB', 'SAR', 0.53, CURRENT_DATE, 'manual'),
  ('RMB', 'EGP', 6.85, CURRENT_DATE, 'manual'),
  ('USD', 'SAR', 3.75, CURRENT_DATE, 'manual'),
  ('USD', 'EGP', 48.50, CURRENT_DATE, 'manual'),
  ('SAR', 'EGP', 12.93, CURRENT_DATE, 'manual')
ON CONFLICT (base_currency, target_currency, rate_date) DO NOTHING;

-- =====================================================
-- 7. GRANTS AND PERMISSIONS
-- =====================================================

-- Grant necessary permissions to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON import_batches TO authenticated;
GRANT ALL ON packing_list_items TO authenticated;
GRANT SELECT ON currency_rates TO authenticated;
GRANT ALL ON import_analysis_settings TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION get_import_batch_statistics(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_batch_category_breakdown(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION detect_duplicate_items(UUID, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION update_batch_currency_conversion(UUID, TEXT, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION get_latest_currency_rate(TEXT, TEXT) TO authenticated;

-- =====================================================
-- 8. COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON TABLE import_batches IS 'Tracks Excel/CSV file imports with processing status and metadata';
COMMENT ON TABLE packing_list_items IS 'Core packing list data extracted from import files with analysis results';
COMMENT ON TABLE currency_rates IS 'Real-time currency exchange rates for price conversion';
COMMENT ON TABLE import_analysis_settings IS 'User preferences and configuration for import analysis';

COMMENT ON FUNCTION get_import_batch_statistics(UUID) IS 'Returns comprehensive statistics for an import batch';
COMMENT ON FUNCTION get_batch_category_breakdown(UUID) IS 'Returns category breakdown with counts and values';
COMMENT ON FUNCTION detect_duplicate_items(UUID, DECIMAL) IS 'Detects and clusters potential duplicate items';
COMMENT ON FUNCTION update_batch_currency_conversion(UUID, TEXT, DECIMAL) IS 'Updates currency conversion for all items in a batch';
COMMENT ON FUNCTION get_latest_currency_rate(TEXT, TEXT) IS 'Gets the most recent exchange rate between two currencies';

-- =====================================================
-- END OF SCHEMA
-- =====================================================
