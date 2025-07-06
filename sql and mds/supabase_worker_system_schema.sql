-- =====================================================
-- WORKER TASK MANAGEMENT & REWARDS SYSTEM SCHEMA
-- =====================================================

-- 1. Worker Tasks Table (Assigned Tasks)
CREATE TABLE IF NOT EXISTS worker_tasks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    assigned_to UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(20) DEFAULT 'assigned' CHECK (status IN ('assigned', 'in_progress', 'completed', 'approved', 'rejected')),
    due_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    estimated_hours INTEGER,
    category VARCHAR(100),
    location TEXT,
    requirements TEXT,
    is_active BOOLEAN DEFAULT true
);

-- 2. Task Submissions/Progress Table
CREATE TABLE IF NOT EXISTS task_submissions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    task_id UUID REFERENCES worker_tasks(id) ON DELETE CASCADE,
    worker_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    progress_report TEXT NOT NULL,
    completion_percentage INTEGER DEFAULT 0 CHECK (completion_percentage >= 0 AND completion_percentage <= 100),
    status VARCHAR(20) DEFAULT 'submitted' CHECK (status IN ('submitted', 'approved', 'rejected', 'needs_revision')),
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    hours_worked DECIMAL(5,2),
    attachments JSONB DEFAULT '[]'::jsonb,
    notes TEXT,
    is_final_submission BOOLEAN DEFAULT false
);

-- 3. Admin Comments/Feedback Table
CREATE TABLE IF NOT EXISTS task_feedback (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    submission_id UUID REFERENCES task_submissions(id) ON DELETE CASCADE,
    admin_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    feedback_text TEXT NOT NULL,
    feedback_type VARCHAR(20) DEFAULT 'comment' CHECK (feedback_type IN ('comment', 'approval', 'rejection', 'revision_request')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_read BOOLEAN DEFAULT false
);

-- 4. Worker Rewards/Incentives Table
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
    notes TEXT
);

-- 5. Worker Reward Balances (Summary Table)
CREATE TABLE IF NOT EXISTS worker_reward_balances (
    worker_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    current_balance DECIMAL(10,2) DEFAULT 0.00,
    total_earned DECIMAL(10,2) DEFAULT 0.00,
    total_withdrawn DECIMAL(10,2) DEFAULT 0.00,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_worker_tasks_assigned_to ON worker_tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_worker_tasks_status ON worker_tasks(status);
CREATE INDEX IF NOT EXISTS idx_worker_tasks_due_date ON worker_tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_task_submissions_task_id ON task_submissions(task_id);
CREATE INDEX IF NOT EXISTS idx_task_submissions_worker_id ON task_submissions(worker_id);
CREATE INDEX IF NOT EXISTS idx_task_submissions_status ON task_submissions(status);
CREATE INDEX IF NOT EXISTS idx_task_feedback_submission_id ON task_feedback(submission_id);
CREATE INDEX IF NOT EXISTS idx_worker_rewards_worker_id ON worker_rewards(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_rewards_awarded_at ON worker_rewards(awarded_at);

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE worker_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_reward_balances ENABLE ROW LEVEL SECURITY;

-- Worker Tasks Policies
CREATE POLICY "Workers can view their assigned tasks" ON worker_tasks
    FOR SELECT USING (assigned_to = auth.uid());

CREATE POLICY "Admins can view all tasks" ON worker_tasks
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

CREATE POLICY "Admins can create tasks" ON worker_tasks
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- Task Submissions Policies
CREATE POLICY "Workers can view their submissions" ON task_submissions
    FOR SELECT USING (worker_id = auth.uid());

CREATE POLICY "Workers can create submissions" ON task_submissions
    FOR INSERT WITH CHECK (worker_id = auth.uid());

CREATE POLICY "Admins can view all submissions" ON task_submissions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- Task Feedback Policies
CREATE POLICY "Workers can view feedback on their submissions" ON task_feedback
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM task_submissions ts 
            WHERE ts.id = submission_id 
            AND ts.worker_id = auth.uid()
        )
    );

CREATE POLICY "Admins can manage all feedback" ON task_feedback
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- Worker Rewards Policies
CREATE POLICY "Workers can view their rewards" ON worker_rewards
    FOR SELECT USING (worker_id = auth.uid());

CREATE POLICY "Admins can manage all rewards" ON worker_rewards
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- Worker Reward Balances Policies
CREATE POLICY "Workers can view their balance" ON worker_reward_balances
    FOR SELECT USING (worker_id = auth.uid());

CREATE POLICY "Admins can view all balances" ON worker_reward_balances
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'manager')
        )
    );

-- =====================================================
-- TRIGGERS AND FUNCTIONS
-- =====================================================

-- Function to update worker reward balance
CREATE OR REPLACE FUNCTION update_worker_reward_balance()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert or update the balance record
    INSERT INTO worker_reward_balances (worker_id, current_balance, total_earned, last_updated)
    VALUES (
        NEW.worker_id,
        NEW.amount,
        CASE WHEN NEW.amount > 0 THEN NEW.amount ELSE 0 END,
        NOW()
    )
    ON CONFLICT (worker_id) DO UPDATE SET
        current_balance = worker_reward_balances.current_balance + NEW.amount,
        total_earned = worker_reward_balances.total_earned + CASE WHEN NEW.amount > 0 THEN NEW.amount ELSE 0 END,
        total_withdrawn = worker_reward_balances.total_withdrawn + CASE WHEN NEW.amount < 0 THEN ABS(NEW.amount) ELSE 0 END,
        last_updated = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update balance when reward is added
CREATE TRIGGER trigger_update_reward_balance
    AFTER INSERT ON worker_rewards
    FOR EACH ROW
    EXECUTE FUNCTION update_worker_reward_balance();

-- Function to update task status when submission is approved
CREATE OR REPLACE FUNCTION update_task_status_on_approval()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
        UPDATE worker_tasks 
        SET status = 'approved', updated_at = NOW()
        WHERE id = NEW.task_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update task status
CREATE TRIGGER trigger_update_task_status
    AFTER UPDATE ON task_submissions
    FOR EACH ROW
    EXECUTE FUNCTION update_task_status_on_approval();

-- Function to send notification when task is assigned
CREATE OR REPLACE FUNCTION notify_task_assignment()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO notifications (user_id, title, body, type, created_at)
    VALUES (
        NEW.assigned_to,
        'مهمة جديدة مسندة إليك',
        'تم تعيين مهمة جديدة لك: ' || NEW.title,
        'TASK',
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for task assignment notification
CREATE TRIGGER trigger_notify_task_assignment
    AFTER INSERT ON worker_tasks
    FOR EACH ROW
    EXECUTE FUNCTION notify_task_assignment();
