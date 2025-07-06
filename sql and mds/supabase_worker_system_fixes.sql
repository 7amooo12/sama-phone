-- =====================================================
-- WORKER SYSTEM FIXES AND IMPROVEMENTS
-- =====================================================

-- Ensure all required tables exist with proper structure

-- 1. Check and create worker_rewards table if missing
CREATE TABLE IF NOT EXISTS worker_rewards (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    worker_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    reward_type VARCHAR(50) DEFAULT 'monetary' CHECK (reward_type IN ('monetary', 'bonus', 'commission', 'penalty', 'adjustment')),
    description TEXT,
    awarded_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    awarded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    related_task_id UUID REFERENCES worker_tasks(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'pending', 'cancelled')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Check and create worker_reward_balances table if missing
CREATE TABLE IF NOT EXISTS worker_reward_balances (
    worker_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    current_balance DECIMAL(10,2) DEFAULT 0.00,
    total_earned DECIMAL(10,2) DEFAULT 0.00,
    total_withdrawn DECIMAL(10,2) DEFAULT 0.00,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create worker_tasks table (MUST BE CREATED FIRST)
CREATE TABLE IF NOT EXISTS worker_tasks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    assigned_to UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(20) DEFAULT 'assigned' CHECK (status IN ('assigned', 'inProgress', 'completed', 'approved', 'rejected')),
    due_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    estimated_hours INTEGER,
    category VARCHAR(100),
    location TEXT,
    requirements TEXT,
    is_active BOOLEAN DEFAULT true
);

-- 3.1. Create task_submissions table
CREATE TABLE IF NOT EXISTS task_submissions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    task_id UUID REFERENCES worker_tasks(id) ON DELETE CASCADE,
    worker_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    submission_text TEXT,
    attachments JSONB DEFAULT '[]',
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'revision_required')),
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    feedback TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3.2. Create task_feedback table
CREATE TABLE IF NOT EXISTS task_feedback (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    submission_id UUID REFERENCES task_submissions(id) ON DELETE CASCADE,
    reviewer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    feedback_text TEXT NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Add missing indexes for better performance
CREATE INDEX IF NOT EXISTS idx_worker_rewards_worker_id ON worker_rewards(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_rewards_awarded_at ON worker_rewards(awarded_at);
CREATE INDEX IF NOT EXISTS idx_worker_rewards_status ON worker_rewards(status);
CREATE INDEX IF NOT EXISTS idx_worker_reward_balances_worker_id ON worker_reward_balances(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_tasks_assigned_to ON worker_tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_worker_tasks_status ON worker_tasks(status);
CREATE INDEX IF NOT EXISTS idx_task_submissions_task_id ON task_submissions(task_id);
CREATE INDEX IF NOT EXISTS idx_task_submissions_worker_id ON task_submissions(worker_id);
CREATE INDEX IF NOT EXISTS idx_task_submissions_status ON task_submissions(status);
CREATE INDEX IF NOT EXISTS idx_task_feedback_submission_id ON task_feedback(submission_id);

-- 5. Enable RLS on tables
ALTER TABLE worker_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_reward_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_tasks ENABLE ROW LEVEL SECURITY;

-- 6. Drop existing policies if they exist and recreate them
DROP POLICY IF EXISTS "Workers can view their rewards" ON worker_rewards;
DROP POLICY IF EXISTS "Admins can manage all rewards" ON worker_rewards;
DROP POLICY IF EXISTS "Workers can view their balance" ON worker_reward_balances;
DROP POLICY IF EXISTS "Admins can view all balances" ON worker_reward_balances;

-- 7. Create comprehensive RLS policies

-- Worker Rewards Policies
CREATE POLICY "Workers can view their rewards" ON worker_rewards
    FOR SELECT USING (worker_id = auth.uid());

CREATE POLICY "Admins can view all rewards" ON worker_rewards
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'manager', 'owner')
        )
    );

CREATE POLICY "Admins can insert rewards" ON worker_rewards
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'manager', 'owner')
        )
    );

CREATE POLICY "Admins can update rewards" ON worker_rewards
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'manager', 'owner')
        )
    );

-- Worker Reward Balances Policies
CREATE POLICY "Workers can view their balance" ON worker_reward_balances
    FOR SELECT USING (worker_id = auth.uid());

CREATE POLICY "Admins can view all balances" ON worker_reward_balances
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'manager', 'owner')
        )
    );

CREATE POLICY "System can manage balances" ON worker_reward_balances
    FOR ALL USING (true);

-- 8. Create or replace the balance update function
CREATE OR REPLACE FUNCTION update_worker_reward_balance()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process if the reward is active
    IF NEW.status = 'active' THEN
        -- Insert or update the balance record
        INSERT INTO worker_reward_balances (worker_id, current_balance, total_earned, total_withdrawn, last_updated)
        VALUES (
            NEW.worker_id,
            NEW.amount,
            CASE WHEN NEW.amount > 0 THEN NEW.amount ELSE 0 END,
            CASE WHEN NEW.amount < 0 THEN ABS(NEW.amount) ELSE 0 END,
            NOW()
        )
        ON CONFLICT (worker_id) DO UPDATE SET
            current_balance = worker_reward_balances.current_balance + NEW.amount,
            total_earned = worker_reward_balances.total_earned + CASE WHEN NEW.amount > 0 THEN NEW.amount ELSE 0 END,
            total_withdrawn = worker_reward_balances.total_withdrawn + CASE WHEN NEW.amount < 0 THEN ABS(NEW.amount) ELSE 0 END,
            last_updated = NOW();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 9. Create the trigger
DROP TRIGGER IF EXISTS trigger_update_reward_balance ON worker_rewards;
CREATE TRIGGER trigger_update_reward_balance
    AFTER INSERT ON worker_rewards
    FOR EACH ROW
    EXECUTE FUNCTION update_worker_reward_balance();

-- 10. Insert some sample data for testing (only if tables are empty)
DO $$
BEGIN
    -- Check if we have any rewards data
    IF NOT EXISTS (SELECT 1 FROM worker_rewards LIMIT 1) THEN
        -- Insert sample rewards for testing (replace with actual worker IDs)
        INSERT INTO worker_rewards (worker_id, amount, reward_type, description, status)
        SELECT
            up.id,
            100.00,
            'monetary',
            'مكافأة تجريبية للاختبار',
            'active'
        FROM user_profiles up
        WHERE up.role = 'worker'
        AND up.is_approved = true
        LIMIT 3;
    END IF;
END $$;

-- 11. Refresh materialized views if any exist
-- (Add any materialized view refreshes here if needed)

-- 12. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON worker_rewards TO authenticated;
GRANT ALL ON worker_reward_balances TO authenticated;
GRANT ALL ON worker_tasks TO authenticated;
