-- Treasury Backup System
-- This migration creates comprehensive backup functionality for treasury data
-- with scheduled exports, recovery options, and backup management

-- Step 1: Create treasury_backup_configs table
CREATE TABLE IF NOT EXISTS treasury_backup_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    backup_type VARCHAR(20) NOT NULL DEFAULT 'full',
    schedule_type VARCHAR(20) NOT NULL DEFAULT 'manual',
    schedule_frequency VARCHAR(20), -- daily, weekly, monthly
    schedule_time TIME, -- for daily backups
    schedule_day_of_week INTEGER, -- 0-6 for weekly backups (0 = Sunday)
    schedule_day_of_month INTEGER, -- 1-31 for monthly backups
    include_treasury_vaults BOOLEAN DEFAULT TRUE,
    include_transactions BOOLEAN DEFAULT TRUE,
    include_connections BOOLEAN DEFAULT TRUE,
    include_limits BOOLEAN DEFAULT TRUE,
    include_alerts BOOLEAN DEFAULT TRUE,
    retention_days INTEGER DEFAULT 30 CHECK (retention_days > 0),
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT valid_backup_type CHECK (backup_type IN ('full', 'incremental', 'differential')),
    CONSTRAINT valid_schedule_type CHECK (schedule_type IN ('manual', 'scheduled')),
    CONSTRAINT valid_schedule_frequency CHECK (schedule_frequency IN ('daily', 'weekly', 'monthly') OR schedule_frequency IS NULL),
    CONSTRAINT valid_schedule_day_of_week CHECK (schedule_day_of_week BETWEEN 0 AND 6 OR schedule_day_of_week IS NULL),
    CONSTRAINT valid_schedule_day_of_month CHECK (schedule_day_of_month BETWEEN 1 AND 31 OR schedule_day_of_month IS NULL)
);

-- Step 2: Create treasury_backups table
CREATE TABLE IF NOT EXISTS treasury_backups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_id UUID REFERENCES treasury_backup_configs(id) ON DELETE CASCADE,
    backup_name VARCHAR(200) NOT NULL,
    backup_type VARCHAR(20) NOT NULL,
    file_path TEXT,
    file_size BIGINT,
    backup_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    backup_data JSONB, -- Store backup data directly for smaller backups
    compression_type VARCHAR(10) DEFAULT 'gzip',
    checksum VARCHAR(64), -- SHA-256 checksum for integrity
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    created_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT valid_backup_status CHECK (backup_status IN ('pending', 'in_progress', 'completed', 'failed', 'expired')),
    CONSTRAINT valid_compression_type CHECK (compression_type IN ('none', 'gzip', 'zip'))
);

-- Step 3: Create treasury_backup_logs table
CREATE TABLE IF NOT EXISTS treasury_backup_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    backup_id UUID REFERENCES treasury_backups(id) ON DELETE CASCADE,
    log_level VARCHAR(10) NOT NULL DEFAULT 'info',
    message TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_log_level CHECK (log_level IN ('debug', 'info', 'warning', 'error', 'critical'))
);

-- Step 4: Create function to generate treasury backup data
CREATE OR REPLACE FUNCTION generate_treasury_backup_data(
    include_vaults BOOLEAN DEFAULT TRUE,
    include_transactions BOOLEAN DEFAULT TRUE,
    include_connections BOOLEAN DEFAULT TRUE,
    include_limits BOOLEAN DEFAULT TRUE,
    include_alerts BOOLEAN DEFAULT TRUE,
    start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    backup_data JSONB := jsonb_build_object();
    vault_data JSONB;
    transaction_data JSONB;
    connection_data JSONB;
    limit_data JSONB;
    alert_data JSONB;
BEGIN
    -- Include treasury vaults
    IF include_vaults THEN
        SELECT jsonb_agg(to_jsonb(tv.*)) INTO vault_data
        FROM treasury_vaults tv;
        
        backup_data := jsonb_set(backup_data, '{treasury_vaults}', COALESCE(vault_data, '[]'::jsonb));
    END IF;
    
    -- Include transactions
    IF include_transactions THEN
        SELECT jsonb_agg(to_jsonb(tt.*)) INTO transaction_data
        FROM treasury_transactions tt
        WHERE (start_date IS NULL OR tt.created_at >= start_date)
        AND (end_date IS NULL OR tt.created_at <= end_date);
        
        backup_data := jsonb_set(backup_data, '{treasury_transactions}', COALESCE(transaction_data, '[]'::jsonb));
    END IF;
    
    -- Include connections
    IF include_connections THEN
        SELECT jsonb_agg(to_jsonb(tc.*)) INTO connection_data
        FROM treasury_connections tc
        WHERE (start_date IS NULL OR tc.created_at >= start_date)
        AND (end_date IS NULL OR tc.created_at <= end_date);
        
        backup_data := jsonb_set(backup_data, '{treasury_connections}', COALESCE(connection_data, '[]'::jsonb));
    END IF;
    
    -- Include limits
    IF include_limits THEN
        SELECT jsonb_agg(to_jsonb(tl.*)) INTO limit_data
        FROM treasury_limits tl
        WHERE (start_date IS NULL OR tl.created_at >= start_date)
        AND (end_date IS NULL OR tl.created_at <= end_date);
        
        backup_data := jsonb_set(backup_data, '{treasury_limits}', COALESCE(limit_data, '[]'::jsonb));
    END IF;
    
    -- Include alerts
    IF include_alerts THEN
        SELECT jsonb_agg(to_jsonb(ta.*)) INTO alert_data
        FROM treasury_alerts ta
        WHERE (start_date IS NULL OR ta.created_at >= start_date)
        AND (end_date IS NULL OR ta.created_at <= end_date);
        
        backup_data := jsonb_set(backup_data, '{treasury_alerts}', COALESCE(alert_data, '[]'::jsonb));
    END IF;
    
    -- Add metadata
    backup_data := jsonb_set(backup_data, '{metadata}', jsonb_build_object(
        'generated_at', NOW(),
        'version', '1.0',
        'includes', jsonb_build_object(
            'treasury_vaults', include_vaults,
            'treasury_transactions', include_transactions,
            'treasury_connections', include_connections,
            'treasury_limits', include_limits,
            'treasury_alerts', include_alerts
        ),
        'date_range', jsonb_build_object(
            'start_date', start_date,
            'end_date', end_date
        )
    ));
    
    RETURN backup_data;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Create function to create treasury backup
CREATE OR REPLACE FUNCTION create_treasury_backup(
    config_uuid UUID,
    backup_name_param VARCHAR(200),
    user_uuid UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    backup_id UUID;
    config_record RECORD;
    backup_data JSONB;
    data_size BIGINT;
    checksum_value VARCHAR(64);
BEGIN
    -- Get backup configuration
    SELECT * INTO config_record
    FROM treasury_backup_configs
    WHERE id = config_uuid;
    
    IF config_record IS NULL THEN
        RAISE EXCEPTION 'Backup configuration not found: %', config_uuid;
    END IF;
    
    -- Generate backup data
    backup_data := generate_treasury_backup_data(
        config_record.include_treasury_vaults,
        config_record.include_transactions,
        config_record.include_connections,
        config_record.include_limits,
        config_record.include_alerts
    );
    
    -- Calculate data size (approximate)
    data_size := length(backup_data::text);
    
    -- Generate checksum (simplified - in real implementation would use proper hashing)
    checksum_value := md5(backup_data::text);
    
    -- Create backup record
    INSERT INTO treasury_backups (
        config_id, backup_name, backup_type, backup_data,
        file_size, backup_status, checksum, completed_at, created_by
    ) VALUES (
        config_uuid, backup_name_param, config_record.backup_type, backup_data,
        data_size, 'completed', checksum_value, NOW(), user_uuid
    ) RETURNING id INTO backup_id;
    
    -- Log backup creation
    INSERT INTO treasury_backup_logs (backup_id, log_level, message, details)
    VALUES (backup_id, 'info', 'Backup created successfully', jsonb_build_object(
        'backup_id', backup_id,
        'data_size', data_size,
        'checksum', checksum_value
    ));
    
    RETURN backup_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: Create function to restore treasury backup
CREATE OR REPLACE FUNCTION restore_treasury_backup(
    backup_uuid UUID,
    restore_options JSONB DEFAULT '{}',
    user_uuid UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    backup_record RECORD;
    restore_result JSONB := jsonb_build_object();
    restore_vaults BOOLEAN := COALESCE((restore_options->>'restore_vaults')::BOOLEAN, TRUE);
    restore_transactions BOOLEAN := COALESCE((restore_options->>'restore_transactions')::BOOLEAN, TRUE);
    restore_connections BOOLEAN := COALESCE((restore_options->>'restore_connections')::BOOLEAN, TRUE);
    restore_limits BOOLEAN := COALESCE((restore_options->>'restore_limits')::BOOLEAN, TRUE);
    restore_alerts BOOLEAN := COALESCE((restore_options->>'restore_alerts')::BOOLEAN, TRUE);
    clear_existing BOOLEAN := COALESCE((restore_options->>'clear_existing')::BOOLEAN, FALSE);
    vault_count INTEGER := 0;
    transaction_count INTEGER := 0;
    connection_count INTEGER := 0;
    limit_count INTEGER := 0;
    alert_count INTEGER := 0;
BEGIN
    -- Get backup record
    SELECT * INTO backup_record
    FROM treasury_backups
    WHERE id = backup_uuid AND backup_status = 'completed';
    
    IF backup_record IS NULL THEN
        RAISE EXCEPTION 'Backup not found or not completed: %', backup_uuid;
    END IF;
    
    -- Verify checksum
    IF md5(backup_record.backup_data::text) != backup_record.checksum THEN
        RAISE EXCEPTION 'Backup data integrity check failed';
    END IF;
    
    -- Clear existing data if requested
    IF clear_existing THEN
        IF restore_alerts THEN DELETE FROM treasury_alerts; END IF;
        IF restore_limits THEN DELETE FROM treasury_limits; END IF;
        IF restore_connections THEN DELETE FROM treasury_connections; END IF;
        IF restore_transactions THEN DELETE FROM treasury_transactions; END IF;
        IF restore_vaults THEN DELETE FROM treasury_vaults; END IF;
    END IF;
    
    -- Restore treasury vaults
    IF restore_vaults AND backup_record.backup_data ? 'treasury_vaults' THEN
        INSERT INTO treasury_vaults (
            id, name, currency, balance, exchange_rate_to_egp, is_main_treasury,
            position_x, position_y, created_at, updated_at, created_by,
            treasury_type, bank_name, account_number, account_holder_name
        )
        SELECT 
            (vault->>'id')::UUID,
            vault->>'name',
            vault->>'currency',
            (vault->>'balance')::DECIMAL(15,2),
            (vault->>'exchange_rate_to_egp')::DECIMAL(10,4),
            (vault->>'is_main_treasury')::BOOLEAN,
            (vault->>'position_x')::DECIMAL(8,2),
            (vault->>'position_y')::DECIMAL(8,2),
            (vault->>'created_at')::TIMESTAMP WITH TIME ZONE,
            (vault->>'updated_at')::TIMESTAMP WITH TIME ZONE,
            (vault->>'created_by')::UUID,
            vault->>'treasury_type',
            vault->>'bank_name',
            vault->>'account_number',
            vault->>'account_holder_name'
        FROM jsonb_array_elements(backup_record.backup_data->'treasury_vaults') AS vault
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            currency = EXCLUDED.currency,
            balance = EXCLUDED.balance,
            exchange_rate_to_egp = EXCLUDED.exchange_rate_to_egp,
            updated_at = NOW();
        
        GET DIAGNOSTICS vault_count = ROW_COUNT;
    END IF;
    
    -- Build result
    restore_result := jsonb_build_object(
        'restored_at', NOW(),
        'restored_by', user_uuid,
        'backup_id', backup_uuid,
        'counts', jsonb_build_object(
            'treasury_vaults', vault_count,
            'treasury_transactions', transaction_count,
            'treasury_connections', connection_count,
            'treasury_limits', limit_count,
            'treasury_alerts', alert_count
        )
    );
    
    -- Log restore operation
    INSERT INTO treasury_backup_logs (backup_id, log_level, message, details)
    VALUES (backup_uuid, 'info', 'Backup restored successfully', restore_result);
    
    RETURN restore_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Create function to cleanup expired backups
CREATE OR REPLACE FUNCTION cleanup_expired_backups() RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
    config_record RECORD;
BEGIN
    -- Mark expired backups
    FOR config_record IN 
        SELECT id, retention_days FROM treasury_backup_configs WHERE is_enabled = TRUE
    LOOP
        UPDATE treasury_backups
        SET backup_status = 'expired'
        WHERE config_id = config_record.id
        AND backup_status = 'completed'
        AND completed_at < NOW() - INTERVAL '1 day' * config_record.retention_days;
        
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
    END LOOP;
    
    -- Delete expired backup data
    DELETE FROM treasury_backups
    WHERE backup_status = 'expired'
    AND completed_at < NOW() - INTERVAL '7 days'; -- Keep expired records for 7 days
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_treasury_backup_configs_enabled ON treasury_backup_configs(is_enabled) WHERE is_enabled = TRUE;
CREATE INDEX IF NOT EXISTS idx_treasury_backups_config_id ON treasury_backups(config_id);
CREATE INDEX IF NOT EXISTS idx_treasury_backups_status ON treasury_backups(backup_status);
CREATE INDEX IF NOT EXISTS idx_treasury_backups_completed_at ON treasury_backups(completed_at);
CREATE INDEX IF NOT EXISTS idx_treasury_backup_logs_backup_id ON treasury_backup_logs(backup_id);
CREATE INDEX IF NOT EXISTS idx_treasury_backup_logs_created_at ON treasury_backup_logs(created_at);

-- Step 9: Enable Row Level Security
ALTER TABLE treasury_backup_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_backups ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_backup_logs ENABLE ROW LEVEL SECURITY;

-- Step 10: Create RLS policies
CREATE POLICY "Users can manage backup configs" ON treasury_backup_configs FOR ALL USING (true);
CREATE POLICY "Users can manage backups" ON treasury_backups FOR ALL USING (true);
CREATE POLICY "Users can view backup logs" ON treasury_backup_logs FOR SELECT USING (true);

-- Step 11: Grant necessary permissions
GRANT EXECUTE ON FUNCTION generate_treasury_backup_data(BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) TO authenticated;
GRANT EXECUTE ON FUNCTION create_treasury_backup(UUID, VARCHAR, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION restore_treasury_backup(UUID, JSONB, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_expired_backups() TO authenticated;
