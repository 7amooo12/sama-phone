-- Treasury Limits and Alerts System
-- This migration creates comprehensive treasury limits and alerts functionality
-- with configurable thresholds, automated notifications, and alert management

-- Step 1: Create treasury_limits table
CREATE TABLE IF NOT EXISTS treasury_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    treasury_id UUID NOT NULL REFERENCES treasury_vaults(id) ON DELETE CASCADE,
    limit_type VARCHAR(20) NOT NULL,
    limit_value DECIMAL(15,2) NOT NULL CHECK (limit_value >= 0),
    warning_threshold DECIMAL(5,2) DEFAULT 80.0 CHECK (warning_threshold >= 0 AND warning_threshold <= 100),
    critical_threshold DECIMAL(5,2) DEFAULT 95.0 CHECK (critical_threshold >= 0 AND critical_threshold <= 100),
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT valid_limit_type CHECK (limit_type IN ('min_balance', 'max_balance', 'daily_transaction', 'monthly_transaction')),
    CONSTRAINT valid_thresholds CHECK (warning_threshold <= critical_threshold),
    CONSTRAINT unique_treasury_limit_type UNIQUE (treasury_id, limit_type)
);

-- Step 2: Create treasury_alerts table
CREATE TABLE IF NOT EXISTS treasury_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    treasury_id UUID NOT NULL REFERENCES treasury_vaults(id) ON DELETE CASCADE,
    alert_type VARCHAR(20) NOT NULL,
    severity VARCHAR(10) NOT NULL DEFAULT 'warning',
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    current_value DECIMAL(15,2),
    limit_value DECIMAL(15,2),
    threshold_percentage DECIMAL(5,2),
    is_acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    acknowledged_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_alert_type CHECK (alert_type IN ('balance_low', 'balance_high', 'transaction_limit', 'exchange_rate_change')),
    CONSTRAINT valid_severity CHECK (severity IN ('info', 'warning', 'critical', 'error'))
);

-- Step 3: Create treasury_alert_settings table for user preferences
CREATE TABLE IF NOT EXISTS treasury_alert_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    alert_type VARCHAR(20) NOT NULL,
    is_enabled BOOLEAN DEFAULT TRUE,
    notification_method VARCHAR(20) DEFAULT 'in_app',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_alert_type_settings CHECK (alert_type IN ('balance_low', 'balance_high', 'transaction_limit', 'exchange_rate_change', 'all')),
    CONSTRAINT valid_notification_method CHECK (notification_method IN ('in_app', 'email', 'both')),
    CONSTRAINT unique_user_alert_type UNIQUE (user_id, alert_type)
);

-- Step 4: Create function to check treasury limits
CREATE OR REPLACE FUNCTION check_treasury_limits(
    treasury_uuid UUID,
    current_balance DECIMAL(15,2) DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    limit_record RECORD;
    alert_data JSONB := jsonb_build_array();
    treasury_balance DECIMAL(15,2);
    percentage_used DECIMAL(5,2);
    alert_severity VARCHAR(10);
    alert_title TEXT;
    alert_message TEXT;
BEGIN
    -- Get current balance if not provided
    IF current_balance IS NULL THEN
        SELECT balance INTO treasury_balance FROM treasury_vaults WHERE id = treasury_uuid;
    ELSE
        treasury_balance := current_balance;
    END IF;
    
    -- Check all enabled limits for this treasury
    FOR limit_record IN 
        SELECT * FROM treasury_limits 
        WHERE treasury_id = treasury_uuid AND is_enabled = TRUE
    LOOP
        -- Check balance limits
        IF limit_record.limit_type = 'min_balance' THEN
            IF treasury_balance <= limit_record.limit_value THEN
                percentage_used := (limit_record.limit_value - treasury_balance) / limit_record.limit_value * 100;
                
                IF percentage_used >= limit_record.critical_threshold THEN
                    alert_severity := 'critical';
                    alert_title := 'تحذير حرج: الرصيد منخفض جداً';
                    alert_message := 'الرصيد الحالي أقل من الحد الأدنى المسموح به بشكل حرج';
                ELSIF percentage_used >= limit_record.warning_threshold THEN
                    alert_severity := 'warning';
                    alert_title := 'تحذير: الرصيد منخفض';
                    alert_message := 'الرصيد الحالي يقترب من الحد الأدنى المسموح به';
                ELSE
                    CONTINUE;
                END IF;
                
                alert_data := alert_data || jsonb_build_object(
                    'alert_type', 'balance_low',
                    'severity', alert_severity,
                    'title', alert_title,
                    'message', alert_message,
                    'current_value', treasury_balance,
                    'limit_value', limit_record.limit_value,
                    'threshold_percentage', percentage_used
                );
            END IF;
            
        ELSIF limit_record.limit_type = 'max_balance' THEN
            IF treasury_balance >= limit_record.limit_value THEN
                percentage_used := treasury_balance / limit_record.limit_value * 100;
                
                IF percentage_used >= limit_record.critical_threshold THEN
                    alert_severity := 'critical';
                    alert_title := 'تحذير حرج: الرصيد مرتفع جداً';
                    alert_message := 'الرصيد الحالي تجاوز الحد الأقصى المسموح به بشكل حرج';
                ELSIF percentage_used >= limit_record.warning_threshold THEN
                    alert_severity := 'warning';
                    alert_title := 'تحذير: الرصيد مرتفع';
                    alert_message := 'الرصيد الحالي يقترب من الحد الأقصى المسموح به';
                ELSE
                    CONTINUE;
                END IF;
                
                alert_data := alert_data || jsonb_build_object(
                    'alert_type', 'balance_high',
                    'severity', alert_severity,
                    'title', alert_title,
                    'message', alert_message,
                    'current_value', treasury_balance,
                    'limit_value', limit_record.limit_value,
                    'threshold_percentage', percentage_used
                );
            END IF;
        END IF;
    END LOOP;
    
    RETURN alert_data;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Create function to create treasury alert
CREATE OR REPLACE FUNCTION create_treasury_alert(
    treasury_uuid UUID,
    alert_type_param VARCHAR(20),
    severity_param VARCHAR(10),
    title_param TEXT,
    message_param TEXT,
    current_value_param DECIMAL(15,2) DEFAULT NULL,
    limit_value_param DECIMAL(15,2) DEFAULT NULL,
    threshold_percentage_param DECIMAL(5,2) DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    alert_id UUID;
    existing_alert_id UUID;
BEGIN
    -- Check if similar unacknowledged alert already exists
    SELECT id INTO existing_alert_id
    FROM treasury_alerts
    WHERE treasury_id = treasury_uuid
    AND alert_type = alert_type_param
    AND severity = severity_param
    AND is_acknowledged = FALSE
    AND created_at > NOW() - INTERVAL '1 hour'; -- Only check recent alerts
    
    -- If similar alert exists, update it instead of creating new one
    IF existing_alert_id IS NOT NULL THEN
        UPDATE treasury_alerts
        SET current_value = COALESCE(current_value_param, current_value),
            threshold_percentage = COALESCE(threshold_percentage_param, threshold_percentage),
            created_at = NOW()
        WHERE id = existing_alert_id;
        
        RETURN existing_alert_id;
    END IF;
    
    -- Create new alert
    INSERT INTO treasury_alerts (
        treasury_id, alert_type, severity, title, message,
        current_value, limit_value, threshold_percentage
    ) VALUES (
        treasury_uuid, alert_type_param, severity_param, title_param, message_param,
        current_value_param, limit_value_param, threshold_percentage_param
    ) RETURNING id INTO alert_id;
    
    RETURN alert_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: Create function to acknowledge alert
CREATE OR REPLACE FUNCTION acknowledge_treasury_alert(
    alert_uuid UUID,
    user_uuid UUID DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    UPDATE treasury_alerts
    SET is_acknowledged = TRUE,
        acknowledged_at = NOW(),
        acknowledged_by = user_uuid
    WHERE id = alert_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Create function to get treasury alerts
CREATE OR REPLACE FUNCTION get_treasury_alerts(
    treasury_uuid UUID DEFAULT NULL,
    include_acknowledged BOOLEAN DEFAULT FALSE,
    limit_count INTEGER DEFAULT 50
) RETURNS TABLE (
    id UUID,
    treasury_id UUID,
    treasury_name TEXT,
    alert_type VARCHAR(20),
    severity VARCHAR(10),
    title TEXT,
    message TEXT,
    current_value DECIMAL(15,2),
    limit_value DECIMAL(15,2),
    threshold_percentage DECIMAL(5,2),
    is_acknowledged BOOLEAN,
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ta.id,
        ta.treasury_id,
        tv.name as treasury_name,
        ta.alert_type,
        ta.severity,
        ta.title,
        ta.message,
        ta.current_value,
        ta.limit_value,
        ta.threshold_percentage,
        ta.is_acknowledged,
        ta.acknowledged_at,
        ta.created_at
    FROM treasury_alerts ta
    JOIN treasury_vaults tv ON ta.treasury_id = tv.id
    WHERE (treasury_uuid IS NULL OR ta.treasury_id = treasury_uuid)
    AND (include_acknowledged OR NOT ta.is_acknowledged)
    ORDER BY ta.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_treasury_limits_treasury_id ON treasury_limits(treasury_id);
CREATE INDEX IF NOT EXISTS idx_treasury_limits_enabled ON treasury_limits(is_enabled) WHERE is_enabled = TRUE;
CREATE INDEX IF NOT EXISTS idx_treasury_alerts_treasury_id ON treasury_alerts(treasury_id);
CREATE INDEX IF NOT EXISTS idx_treasury_alerts_acknowledged ON treasury_alerts(is_acknowledged, created_at);
CREATE INDEX IF NOT EXISTS idx_treasury_alerts_type_severity ON treasury_alerts(alert_type, severity);
CREATE INDEX IF NOT EXISTS idx_treasury_alert_settings_user_id ON treasury_alert_settings(user_id);

-- Step 9: Enable Row Level Security
ALTER TABLE treasury_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_alert_settings ENABLE ROW LEVEL SECURITY;

-- Step 10: Create RLS policies
CREATE POLICY "Users can view treasury limits" ON treasury_limits FOR SELECT USING (true);
CREATE POLICY "Users can manage treasury limits" ON treasury_limits FOR ALL USING (true);

CREATE POLICY "Users can view treasury alerts" ON treasury_alerts FOR SELECT USING (true);
CREATE POLICY "Users can manage treasury alerts" ON treasury_alerts FOR ALL USING (true);

CREATE POLICY "Users can manage their alert settings" ON treasury_alert_settings 
FOR ALL USING (auth.uid() = user_id);

-- Step 11: Grant necessary permissions
GRANT EXECUTE ON FUNCTION check_treasury_limits(UUID, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION create_treasury_alert(UUID, VARCHAR, VARCHAR, TEXT, TEXT, DECIMAL, DECIMAL, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION acknowledge_treasury_alert(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_treasury_alerts(UUID, BOOLEAN, INTEGER) TO authenticated;
