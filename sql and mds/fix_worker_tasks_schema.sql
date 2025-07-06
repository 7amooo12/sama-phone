-- إصلاح مخطط جدول worker_tasks لإضافة الأعمدة المفقودة
-- Fix worker_tasks table schema to add missing columns

-- إضافة الأعمدة المفقودة إلى جدول worker_tasks
ALTER TABLE worker_tasks 
ADD COLUMN IF NOT EXISTS admin_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS completed_quantity INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS product_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS progress DECIMAL(5,2) DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS deadline TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS product_image TEXT,
ADD COLUMN IF NOT EXISTS worker_id UUID,
ADD COLUMN IF NOT EXISTS worker_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS admin_id UUID,
ADD COLUMN IF NOT EXISTS product_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS order_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::jsonb;

-- إضافة فهارس للأعمدة الجديدة
CREATE INDEX IF NOT EXISTS idx_worker_tasks_admin_id ON worker_tasks(admin_id);
CREATE INDEX IF NOT EXISTS idx_worker_tasks_worker_id ON worker_tasks(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_tasks_product_id ON worker_tasks(product_id);
CREATE INDEX IF NOT EXISTS idx_worker_tasks_order_id ON worker_tasks(order_id);
CREATE INDEX IF NOT EXISTS idx_worker_tasks_deadline ON worker_tasks(deadline);
CREATE INDEX IF NOT EXISTS idx_worker_tasks_progress ON worker_tasks(progress);

-- إضافة سياسات RLS للمهام
DROP POLICY IF EXISTS "Workers can view their tasks" ON worker_tasks;
DROP POLICY IF EXISTS "Admins can view all tasks" ON worker_tasks;
DROP POLICY IF EXISTS "Admins can insert tasks" ON worker_tasks;
DROP POLICY IF EXISTS "Admins can update tasks" ON worker_tasks;
DROP POLICY IF EXISTS "Workers can update their tasks" ON worker_tasks;

CREATE POLICY "Workers can view their tasks" ON worker_tasks
    FOR SELECT USING (assigned_to = auth.uid() OR worker_id = auth.uid());

CREATE POLICY "Admins can view all tasks" ON worker_tasks
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'manager', 'owner')
        )
    );

CREATE POLICY "Admins can insert tasks" ON worker_tasks
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'manager', 'owner')
        )
    );

CREATE POLICY "Admins can update tasks" ON worker_tasks
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'manager', 'owner')
        )
    );

CREATE POLICY "Workers can update their tasks" ON worker_tasks
    FOR UPDATE USING (assigned_to = auth.uid() OR worker_id = auth.uid());

-- تحديث البيانات الموجودة لملء الأعمدة الجديدة
UPDATE worker_tasks 
SET 
    worker_id = assigned_to,
    deadline = due_date,
    admin_id = assigned_by
WHERE worker_id IS NULL OR deadline IS NULL OR admin_id IS NULL;

-- إضافة قيود للتأكد من صحة البيانات
ALTER TABLE worker_tasks 
ADD CONSTRAINT check_progress_range CHECK (progress >= 0 AND progress <= 100),
ADD CONSTRAINT check_quantity_positive CHECK (quantity >= 0),
ADD CONSTRAINT check_completed_quantity_valid CHECK (completed_quantity >= 0 AND completed_quantity <= quantity);

-- إنشاء دالة لتحديث تقدم المهمة تلقائياً
CREATE OR REPLACE FUNCTION update_task_progress()
RETURNS TRIGGER AS $$
BEGIN
    -- حساب التقدم بناءً على الكمية المنجزة
    IF NEW.quantity > 0 THEN
        NEW.progress = (NEW.completed_quantity::DECIMAL / NEW.quantity::DECIMAL) * 100;
    END IF;
    
    -- تحديث حالة المهمة بناءً على التقدم
    IF NEW.progress >= 100 THEN
        NEW.status = 'completed';
    ELSIF NEW.progress > 0 THEN
        NEW.status = 'in_progress';
    END IF;
    
    -- تحديث وقت التعديل
    NEW.updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء trigger لتحديث التقدم تلقائياً
DROP TRIGGER IF EXISTS trigger_update_task_progress ON worker_tasks;
CREATE TRIGGER trigger_update_task_progress
    BEFORE UPDATE ON worker_tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_task_progress();

-- إنشاء دالة للحصول على إحصائيات المهام
CREATE OR REPLACE FUNCTION get_task_statistics(worker_uuid UUID DEFAULT NULL)
RETURNS TABLE(
    total_tasks BIGINT,
    completed_tasks BIGINT,
    in_progress_tasks BIGINT,
    pending_tasks BIGINT,
    average_progress DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_tasks,
        COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress_tasks,
        COUNT(*) FILTER (WHERE status IN ('assigned', 'pending')) as pending_tasks,
        COALESCE(AVG(progress), 0) as average_progress
    FROM worker_tasks
    WHERE (worker_uuid IS NULL OR assigned_to = worker_uuid OR worker_id = worker_uuid)
    AND is_active = true;
END;
$$ LANGUAGE plpgsql;

-- إنشاء دالة للحصول على مهام العامل مع التفاصيل
CREATE OR REPLACE FUNCTION get_worker_tasks_detailed(worker_uuid UUID)
RETURNS TABLE(
    task_id UUID,
    title VARCHAR,
    description TEXT,
    status VARCHAR,
    priority VARCHAR,
    category VARCHAR,
    progress DECIMAL,
    quantity INTEGER,
    completed_quantity INTEGER,
    product_name VARCHAR,
    admin_name VARCHAR,
    created_at TIMESTAMP WITH TIME ZONE,
    due_date TIMESTAMP WITH TIME ZONE,
    deadline TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wt.id as task_id,
        wt.title,
        wt.description,
        wt.status,
        wt.priority,
        wt.category,
        wt.progress,
        wt.quantity,
        wt.completed_quantity,
        wt.product_name,
        wt.admin_name,
        wt.created_at,
        wt.due_date,
        wt.deadline
    FROM worker_tasks wt
    WHERE (wt.assigned_to = worker_uuid OR wt.worker_id = worker_uuid)
    AND wt.is_active = true
    ORDER BY wt.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- التحقق من صحة التحديثات
DO $$
BEGIN
    RAISE NOTICE 'تم تحديث جدول worker_tasks بنجاح';
    RAISE NOTICE 'عدد المهام الإجمالي: %', (SELECT COUNT(*) FROM worker_tasks);
    RAISE NOTICE 'عدد المهام النشطة: %', (SELECT COUNT(*) FROM worker_tasks WHERE is_active = true);
END $$;
