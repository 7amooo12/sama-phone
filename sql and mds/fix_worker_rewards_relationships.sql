-- إصلاح مشاكل العلاقات في نظام المكافآت
-- Fix worker rewards relationships issues

-- 1. التأكد من وجود الجداول المطلوبة
-- Ensure required tables exist

-- تحقق من وجود جدول user_profiles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles') THEN
        CREATE TABLE user_profiles (
            id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
            name VARCHAR(255),
            email VARCHAR(255),
            role VARCHAR(50) DEFAULT 'client',
            status VARCHAR(50) DEFAULT 'pending',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    END IF;
END $$;

-- تحقق من وجود جدول worker_tasks
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'worker_tasks') THEN
        CREATE TABLE worker_tasks (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            description TEXT,
            assigned_to UUID REFERENCES auth.users(id) ON DELETE CASCADE,
            assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
            priority VARCHAR(20) DEFAULT 'medium',
            status VARCHAR(20) DEFAULT 'assigned',
            due_date TIMESTAMP WITH TIME ZONE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            estimated_hours INTEGER,
            category VARCHAR(100),
            location TEXT,
            requirements TEXT,
            is_active BOOLEAN DEFAULT true
        );
    END IF;
END $$;

-- تحقق من وجود جدول worker_rewards
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'worker_rewards') THEN
        CREATE TABLE worker_rewards (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            worker_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
            amount DECIMAL(10,2) NOT NULL,
            reward_type VARCHAR(50) DEFAULT 'monetary',
            description TEXT,
            awarded_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
            awarded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            related_task_id UUID REFERENCES worker_tasks(id) ON DELETE SET NULL,
            status VARCHAR(20) DEFAULT 'active',
            notes TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    END IF;
END $$;

-- تحقق من وجود جدول worker_reward_balances
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'worker_reward_balances') THEN
        CREATE TABLE worker_reward_balances (
            worker_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
            current_balance DECIMAL(10,2) DEFAULT 0.00,
            total_earned DECIMAL(10,2) DEFAULT 0.00,
            total_withdrawn DECIMAL(10,2) DEFAULT 0.00,
            last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    END IF;
END $$;

-- 2. إضافة الفهارس المطلوبة
-- Add required indexes
CREATE INDEX IF NOT EXISTS idx_worker_rewards_worker_id ON worker_rewards(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_rewards_awarded_at ON worker_rewards(awarded_at);
CREATE INDEX IF NOT EXISTS idx_worker_rewards_status ON worker_rewards(status);
CREATE INDEX IF NOT EXISTS idx_worker_reward_balances_worker_id ON worker_reward_balances(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_tasks_assigned_to ON worker_tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_worker_tasks_status ON worker_tasks(status);
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON user_profiles(role);
CREATE INDEX IF NOT EXISTS idx_user_profiles_status ON user_profiles(status);

-- 3. تفعيل RLS على الجداول
-- Enable RLS on tables
ALTER TABLE worker_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_reward_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- 4. إنشاء سياسات RLS
-- Create RLS policies

-- سياسات worker_rewards
DROP POLICY IF EXISTS "Workers can view their rewards" ON worker_rewards;
DROP POLICY IF EXISTS "Admins can view all rewards" ON worker_rewards;
DROP POLICY IF EXISTS "Admins can insert rewards" ON worker_rewards;
DROP POLICY IF EXISTS "Admins can update rewards" ON worker_rewards;

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

-- سياسات worker_reward_balances
DROP POLICY IF EXISTS "Workers can view their balance" ON worker_reward_balances;
DROP POLICY IF EXISTS "Admins can view all balances" ON worker_reward_balances;

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

-- 5. إدراج بيانات تجريبية للاختبار
-- Insert sample data for testing
DO $$
DECLARE
    worker_user_id UUID;
    admin_user_id UUID;
BEGIN
    -- البحث عن مستخدم عامل للاختبار
    SELECT id INTO worker_user_id 
    FROM user_profiles 
    WHERE role = 'worker' AND status = 'approved' 
    LIMIT 1;
    
    -- البحث عن مستخدم أدمن للاختبار
    SELECT id INTO admin_user_id 
    FROM user_profiles 
    WHERE role = 'admin' 
    LIMIT 1;
    
    -- إدراج مكافأة تجريبية إذا وجد عامل
    IF worker_user_id IS NOT NULL THEN
        -- إدراج مكافأة تجريبية
        INSERT INTO worker_rewards (worker_id, amount, reward_type, description, awarded_by, status)
        VALUES (
            worker_user_id,
            100.00,
            'monetary',
            'مكافأة تجريبية للاختبار',
            COALESCE(admin_user_id, worker_user_id),
            'active'
        )
        ON CONFLICT DO NOTHING;
        
        -- إدراج أو تحديث رصيد العامل
        INSERT INTO worker_reward_balances (worker_id, current_balance, total_earned, total_withdrawn)
        VALUES (worker_user_id, 100.00, 100.00, 0.00)
        ON CONFLICT (worker_id) DO UPDATE SET
            current_balance = worker_reward_balances.current_balance + 100.00,
            total_earned = worker_reward_balances.total_earned + 100.00,
            last_updated = NOW();
    END IF;
END $$;

-- 6. إنشاء دالة لتحديث أرصدة المكافآت تلقائياً
-- Create function to automatically update reward balances
CREATE OR REPLACE FUNCTION update_worker_reward_balance()
RETURNS TRIGGER AS $$
BEGIN
    -- تحديث رصيد العامل عند إضافة مكافأة جديدة
    INSERT INTO worker_reward_balances (worker_id, current_balance, total_earned, total_withdrawn)
    VALUES (NEW.worker_id, NEW.amount, NEW.amount, 0.00)
    ON CONFLICT (worker_id) DO UPDATE SET
        current_balance = worker_reward_balances.current_balance + NEW.amount,
        total_earned = worker_reward_balances.total_earned + NEW.amount,
        last_updated = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء trigger لتحديث الأرصدة تلقائياً
DROP TRIGGER IF EXISTS trigger_update_reward_balance ON worker_rewards;
CREATE TRIGGER trigger_update_reward_balance
    AFTER INSERT ON worker_rewards
    FOR EACH ROW
    EXECUTE FUNCTION update_worker_reward_balance();

-- 7. التحقق من صحة البيانات
-- Verify data integrity
DO $$
BEGIN
    RAISE NOTICE 'عدد المكافآت: %', (SELECT COUNT(*) FROM worker_rewards);
    RAISE NOTICE 'عدد أرصدة العمال: %', (SELECT COUNT(*) FROM worker_reward_balances);
    RAISE NOTICE 'عدد المهام: %', (SELECT COUNT(*) FROM worker_tasks);
    RAISE NOTICE 'عدد ملفات المستخدمين: %', (SELECT COUNT(*) FROM user_profiles);
END $$;
