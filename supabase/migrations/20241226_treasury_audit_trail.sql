-- Treasury Audit Trail System
-- This migration creates comprehensive audit logging for all treasury operations
-- with detailed tracking of user actions, data changes, and system events

-- Step 1: Create treasury_audit_logs table
CREATE TABLE IF NOT EXISTS treasury_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID,
    action_type VARCHAR(30) NOT NULL,
    action_description TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id),
    user_email TEXT,
    user_role TEXT,
    ip_address INET,
    user_agent TEXT,
    session_id TEXT,
    old_values JSONB,
    new_values JSONB,
    changes_summary JSONB,
    metadata JSONB,
    severity VARCHAR(10) DEFAULT 'info',
    tags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_entity_type CHECK (entity_type IN (
        'treasury_vault', 'treasury_transaction', 'treasury_connection', 
        'treasury_limit', 'treasury_alert', 'treasury_backup', 
        'fund_transfer', 'user_session', 'system_event'
    )),
    CONSTRAINT valid_action_type CHECK (action_type IN (
        'create', 'update', 'delete', 'view', 'export', 'import',
        'transfer', 'backup', 'restore', 'login', 'logout', 'error'
    )),
    CONSTRAINT valid_severity CHECK (severity IN ('debug', 'info', 'warning', 'error', 'critical'))
);

-- Step 2: Create treasury_audit_sessions table for session tracking
CREATE TABLE IF NOT EXISTS treasury_audit_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id TEXT UNIQUE NOT NULL,
    user_id UUID REFERENCES auth.users(id),
    user_email TEXT,
    ip_address INET,
    user_agent TEXT,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE,
    session_duration_seconds INTEGER,
    actions_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    end_reason VARCHAR(20),
    
    -- Constraints
    CONSTRAINT valid_end_reason CHECK (end_reason IN ('logout', 'timeout', 'forced', 'error') OR end_reason IS NULL)
);

-- Step 3: Create function to log treasury audit events
CREATE OR REPLACE FUNCTION log_treasury_audit(
    entity_type_param VARCHAR(50),
    entity_id_param UUID,
    action_type_param VARCHAR(30),
    action_description_param TEXT,
    user_id_param UUID DEFAULT NULL,
    old_values_param JSONB DEFAULT NULL,
    new_values_param JSONB DEFAULT NULL,
    metadata_param JSONB DEFAULT NULL,
    severity_param VARCHAR(10) DEFAULT 'info',
    tags_param TEXT[] DEFAULT NULL,
    ip_address_param INET DEFAULT NULL,
    user_agent_param TEXT DEFAULT NULL,
    session_id_param TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    audit_id UUID;
    user_email_val TEXT;
    user_role_val TEXT;
    changes_summary_val JSONB := jsonb_build_object();
    field_name TEXT;
    old_val JSONB;
    new_val JSONB;
BEGIN
    -- Get user information if user_id is provided
    IF user_id_param IS NOT NULL THEN
        SELECT email INTO user_email_val
        FROM auth.users
        WHERE id = user_id_param;
        
        -- Get user role from metadata or profiles table if exists
        SELECT COALESCE(raw_user_meta_data->>'role', 'user') INTO user_role_val
        FROM auth.users
        WHERE id = user_id_param;
    END IF;
    
    -- Generate changes summary if both old and new values are provided
    IF old_values_param IS NOT NULL AND new_values_param IS NOT NULL THEN
        FOR field_name IN SELECT jsonb_object_keys(new_values_param)
        LOOP
            old_val := old_values_param->field_name;
            new_val := new_values_param->field_name;
            
            IF old_val IS DISTINCT FROM new_val THEN
                changes_summary_val := jsonb_set(
                    changes_summary_val,
                    ARRAY[field_name],
                    jsonb_build_object(
                        'old', old_val,
                        'new', new_val,
                        'changed', true
                    )
                );
            END IF;
        END LOOP;
    END IF;
    
    -- Insert audit log
    INSERT INTO treasury_audit_logs (
        entity_type, entity_id, action_type, action_description,
        user_id, user_email, user_role, ip_address, user_agent, session_id,
        old_values, new_values, changes_summary, metadata, severity, tags
    ) VALUES (
        entity_type_param, entity_id_param, action_type_param, action_description_param,
        user_id_param, user_email_val, user_role_val, ip_address_param, user_agent_param, session_id_param,
        old_values_param, new_values_param, changes_summary_val, metadata_param, severity_param, tags_param
    ) RETURNING id INTO audit_id;
    
    -- Update session activity if session_id is provided
    IF session_id_param IS NOT NULL THEN
        UPDATE treasury_audit_sessions
        SET last_activity_at = NOW(),
            actions_count = actions_count + 1
        WHERE session_id = session_id_param AND is_active = TRUE;
    END IF;
    
    RETURN audit_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Create function to start audit session
CREATE OR REPLACE FUNCTION start_treasury_audit_session(
    user_id_param UUID,
    ip_address_param INET DEFAULT NULL,
    user_agent_param TEXT DEFAULT NULL
) RETURNS TEXT AS $$
DECLARE
    session_id_val TEXT;
    user_email_val TEXT;
BEGIN
    -- Generate unique session ID
    session_id_val := gen_random_uuid()::text;
    
    -- Get user email
    SELECT email INTO user_email_val
    FROM auth.users
    WHERE id = user_id_param;
    
    -- Insert session record
    INSERT INTO treasury_audit_sessions (
        session_id, user_id, user_email, ip_address, user_agent
    ) VALUES (
        session_id_val, user_id_param, user_email_val, ip_address_param, user_agent_param
    );
    
    -- Log session start
    PERFORM log_treasury_audit(
        'user_session',
        user_id_param,
        'login',
        'User started treasury session',
        user_id_param,
        NULL,
        jsonb_build_object('session_id', session_id_val),
        jsonb_build_object('ip_address', ip_address_param, 'user_agent', user_agent_param),
        'info',
        ARRAY['session', 'login'],
        ip_address_param,
        user_agent_param,
        session_id_val
    );
    
    RETURN session_id_val;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Create function to end audit session
CREATE OR REPLACE FUNCTION end_treasury_audit_session(
    session_id_param TEXT,
    end_reason_param VARCHAR(20) DEFAULT 'logout'
) RETURNS VOID AS $$
DECLARE
    session_record RECORD;
    duration_seconds INTEGER;
BEGIN
    -- Get session information
    SELECT * INTO session_record
    FROM treasury_audit_sessions
    WHERE session_id = session_id_param AND is_active = TRUE;
    
    IF session_record IS NULL THEN
        RETURN; -- Session not found or already ended
    END IF;
    
    -- Calculate session duration
    duration_seconds := EXTRACT(EPOCH FROM (NOW() - session_record.started_at))::INTEGER;
    
    -- Update session record
    UPDATE treasury_audit_sessions
    SET ended_at = NOW(),
        session_duration_seconds = duration_seconds,
        is_active = FALSE,
        end_reason = end_reason_param
    WHERE session_id = session_id_param;
    
    -- Log session end
    PERFORM log_treasury_audit(
        'user_session',
        session_record.user_id,
        'logout',
        'User ended treasury session',
        session_record.user_id,
        NULL,
        jsonb_build_object(
            'session_id', session_id_param,
            'duration_seconds', duration_seconds,
            'actions_count', session_record.actions_count
        ),
        jsonb_build_object('end_reason', end_reason_param),
        'info',
        ARRAY['session', 'logout'],
        session_record.ip_address,
        session_record.user_agent,
        session_id_param
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: Create function to get audit trail
CREATE OR REPLACE FUNCTION get_treasury_audit_trail(
    entity_type_filter VARCHAR(50) DEFAULT NULL,
    entity_id_filter UUID DEFAULT NULL,
    user_id_filter UUID DEFAULT NULL,
    action_type_filter VARCHAR(30) DEFAULT NULL,
    severity_filter VARCHAR(10) DEFAULT NULL,
    start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    limit_count INTEGER DEFAULT 100,
    offset_count INTEGER DEFAULT 0
) RETURNS TABLE (
    id UUID,
    entity_type VARCHAR(50),
    entity_id UUID,
    action_type VARCHAR(30),
    action_description TEXT,
    user_id UUID,
    user_email TEXT,
    user_role TEXT,
    old_values JSONB,
    new_values JSONB,
    changes_summary JSONB,
    metadata JSONB,
    severity VARCHAR(10),
    tags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tal.id,
        tal.entity_type,
        tal.entity_id,
        tal.action_type,
        tal.action_description,
        tal.user_id,
        tal.user_email,
        tal.user_role,
        tal.old_values,
        tal.new_values,
        tal.changes_summary,
        tal.metadata,
        tal.severity,
        tal.tags,
        tal.created_at
    FROM treasury_audit_logs tal
    WHERE (entity_type_filter IS NULL OR tal.entity_type = entity_type_filter)
    AND (entity_id_filter IS NULL OR tal.entity_id = entity_id_filter)
    AND (user_id_filter IS NULL OR tal.user_id = user_id_filter)
    AND (action_type_filter IS NULL OR tal.action_type = action_type_filter)
    AND (severity_filter IS NULL OR tal.severity = severity_filter)
    AND (start_date IS NULL OR tal.created_at >= start_date)
    AND (end_date IS NULL OR tal.created_at <= end_date)
    ORDER BY tal.created_at DESC
    LIMIT limit_count
    OFFSET offset_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Create function to get audit statistics
CREATE OR REPLACE FUNCTION get_treasury_audit_statistics(
    start_date TIMESTAMP WITH TIME ZONE DEFAULT NOW() - INTERVAL '30 days',
    end_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
) RETURNS JSONB AS $$
DECLARE
    stats JSONB := jsonb_build_object();
    total_actions INTEGER;
    actions_by_type JSONB;
    actions_by_severity JSONB;
    actions_by_entity JSONB;
    top_users JSONB;
BEGIN
    -- Total actions
    SELECT COUNT(*) INTO total_actions
    FROM treasury_audit_logs
    WHERE created_at BETWEEN start_date AND end_date;
    
    -- Actions by type
    SELECT jsonb_object_agg(action_type, action_count) INTO actions_by_type
    FROM (
        SELECT action_type, COUNT(*) as action_count
        FROM treasury_audit_logs
        WHERE created_at BETWEEN start_date AND end_date
        GROUP BY action_type
        ORDER BY action_count DESC
    ) t;
    
    -- Actions by severity
    SELECT jsonb_object_agg(severity, severity_count) INTO actions_by_severity
    FROM (
        SELECT severity, COUNT(*) as severity_count
        FROM treasury_audit_logs
        WHERE created_at BETWEEN start_date AND end_date
        GROUP BY severity
        ORDER BY severity_count DESC
    ) t;
    
    -- Actions by entity type
    SELECT jsonb_object_agg(entity_type, entity_count) INTO actions_by_entity
    FROM (
        SELECT entity_type, COUNT(*) as entity_count
        FROM treasury_audit_logs
        WHERE created_at BETWEEN start_date AND end_date
        GROUP BY entity_type
        ORDER BY entity_count DESC
    ) t;
    
    -- Top users
    SELECT jsonb_agg(jsonb_build_object(
        'user_email', user_email,
        'action_count', action_count
    )) INTO top_users
    FROM (
        SELECT user_email, COUNT(*) as action_count
        FROM treasury_audit_logs
        WHERE created_at BETWEEN start_date AND end_date
        AND user_email IS NOT NULL
        GROUP BY user_email
        ORDER BY action_count DESC
        LIMIT 10
    ) t;
    
    -- Build final statistics
    stats := jsonb_build_object(
        'period', jsonb_build_object(
            'start_date', start_date,
            'end_date', end_date
        ),
        'total_actions', total_actions,
        'actions_by_type', COALESCE(actions_by_type, '{}'::jsonb),
        'actions_by_severity', COALESCE(actions_by_severity, '{}'::jsonb),
        'actions_by_entity', COALESCE(actions_by_entity, '{}'::jsonb),
        'top_users', COALESCE(top_users, '[]'::jsonb)
    );
    
    RETURN stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_treasury_audit_logs_entity ON treasury_audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_treasury_audit_logs_user ON treasury_audit_logs(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_treasury_audit_logs_action ON treasury_audit_logs(action_type, created_at);
CREATE INDEX IF NOT EXISTS idx_treasury_audit_logs_severity ON treasury_audit_logs(severity, created_at);
CREATE INDEX IF NOT EXISTS idx_treasury_audit_logs_created_at ON treasury_audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_treasury_audit_logs_session ON treasury_audit_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_treasury_audit_sessions_user ON treasury_audit_sessions(user_id, started_at);
CREATE INDEX IF NOT EXISTS idx_treasury_audit_sessions_active ON treasury_audit_sessions(is_active, last_activity_at);

-- Step 9: Enable Row Level Security
ALTER TABLE treasury_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_audit_sessions ENABLE ROW LEVEL SECURITY;

-- Step 10: Create RLS policies
CREATE POLICY "Users can view audit logs" ON treasury_audit_logs FOR SELECT USING (true);
CREATE POLICY "System can insert audit logs" ON treasury_audit_logs FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can view their sessions" ON treasury_audit_sessions FOR SELECT USING (true);
CREATE POLICY "System can manage sessions" ON treasury_audit_sessions FOR ALL USING (true);

-- Step 11: Grant necessary permissions
GRANT EXECUTE ON FUNCTION log_treasury_audit(VARCHAR, UUID, VARCHAR, TEXT, UUID, JSONB, JSONB, JSONB, VARCHAR, TEXT[], INET, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION start_treasury_audit_session(UUID, INET, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION end_treasury_audit_session(TEXT, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION get_treasury_audit_trail(VARCHAR, UUID, UUID, VARCHAR, VARCHAR, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_treasury_audit_statistics(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) TO authenticated;
