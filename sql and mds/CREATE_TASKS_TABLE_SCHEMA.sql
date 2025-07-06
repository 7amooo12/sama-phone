-- =====================================================
-- CREATE TASKS TABLE SCHEMA FOR TASKMODEL
-- =====================================================
-- This script creates the 'tasks' table with the correct
-- schema to match the TaskModel structure used in the app
-- =====================================================

-- Drop the table if it exists (be careful in production!)
-- DROP TABLE IF EXISTS public.tasks CASCADE;

-- Create the tasks table with all required fields from TaskModel
CREATE TABLE IF NOT EXISTS public.tasks (
    -- Primary key
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Core task fields
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    assigned_to TEXT NOT NULL, -- Worker ID as text
    due_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    priority TEXT NOT NULL DEFAULT 'medium',
    attachments JSONB DEFAULT '[]'::jsonb,
    
    -- Admin and worker information
    admin_name TEXT NOT NULL,
    admin_id TEXT, -- Admin ID as text
    worker_id TEXT, -- Worker ID as text (same as assigned_to)
    worker_name TEXT,
    
    -- Product and order information
    category TEXT NOT NULL DEFAULT 'general',
    quantity INTEGER DEFAULT 0,
    completed_quantity INTEGER DEFAULT 0,
    product_name TEXT NOT NULL,
    product_id TEXT,
    product_image TEXT,
    order_id TEXT,
    
    -- Progress tracking
    progress DECIMAL(5,2) DEFAULT 0.0,
    deadline TIMESTAMP WITH TIME ZONE,
    
    -- Constraints
    CONSTRAINT check_progress_range CHECK (progress >= 0 AND progress <= 100),
    CONSTRAINT check_quantity_positive CHECK (quantity >= 0),
    CONSTRAINT check_completed_quantity_valid CHECK (completed_quantity >= 0 AND completed_quantity <= quantity),
    CONSTRAINT check_status_valid CHECK (status IN ('pending', 'in_progress', 'completed', 'approved', 'rejected', 'cancelled')),
    CONSTRAINT check_priority_valid CHECK (priority IN ('low', 'medium', 'high', 'urgent'))
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to ON public.tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_worker_id ON public.tasks(worker_id);
CREATE INDEX IF NOT EXISTS idx_tasks_admin_id ON public.tasks(admin_id);
CREATE INDEX IF NOT EXISTS idx_tasks_product_id ON public.tasks(product_id);
CREATE INDEX IF NOT EXISTS idx_tasks_order_id ON public.tasks(order_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON public.tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_category ON public.tasks(category);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON public.tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_deadline ON public.tasks(deadline);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON public.tasks(created_at);
CREATE INDEX IF NOT EXISTS idx_tasks_progress ON public.tasks(progress);

-- Enable Row Level Security
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Admin full access to tasks" ON public.tasks;
DROP POLICY IF EXISTS "Owner full access to tasks" ON public.tasks;
DROP POLICY IF EXISTS "Accountant view tasks" ON public.tasks;
DROP POLICY IF EXISTS "Worker view assigned tasks" ON public.tasks;
DROP POLICY IF EXISTS "Worker update assigned tasks" ON public.tasks;

-- Create RLS policies for the tasks table
-- Policy 1: Admin users can do everything
CREATE POLICY "Admin full access to tasks" ON public.tasks
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role = 'admin'
    AND user_profiles.status = 'approved'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role = 'admin'
    AND user_profiles.status = 'approved'
  )
);

-- Policy 2: Owner users can do everything
CREATE POLICY "Owner full access to tasks" ON public.tasks
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role = 'owner'
    AND user_profiles.status = 'approved'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role = 'owner'
    AND user_profiles.status = 'approved'
  )
);

-- Policy 3: Accountant users can view tasks
CREATE POLICY "Accountant view tasks" ON public.tasks
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role = 'accountant'
    AND user_profiles.status = 'approved'
  )
);

-- Policy 4: Workers can view their assigned tasks
CREATE POLICY "Worker view assigned tasks" ON public.tasks
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status = 'approved'
  )
  AND (assigned_to = auth.uid()::text OR worker_id = auth.uid()::text)
);

-- Policy 5: Workers can update their assigned tasks (status, progress, etc.)
CREATE POLICY "Worker update assigned tasks" ON public.tasks
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status = 'approved'
  )
  AND (assigned_to = auth.uid()::text OR worker_id = auth.uid()::text)
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status = 'approved'
  )
  AND (assigned_to = auth.uid()::text OR worker_id = auth.uid()::text)
);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.tasks TO authenticated;

-- Create a function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_tasks_updated_at ON public.tasks;
CREATE TRIGGER update_tasks_updated_at
    BEFORE UPDATE ON public.tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create a function to automatically set worker_id from assigned_to if not provided
CREATE OR REPLACE FUNCTION set_worker_id_from_assigned_to()
RETURNS TRIGGER AS $$
BEGIN
    -- If worker_id is not set but assigned_to is, copy assigned_to to worker_id
    IF NEW.worker_id IS NULL AND NEW.assigned_to IS NOT NULL THEN
        NEW.worker_id = NEW.assigned_to;
    END IF;
    
    -- If deadline is not set but due_date is, copy due_date to deadline
    IF NEW.deadline IS NULL AND NEW.due_date IS NOT NULL THEN
        NEW.deadline = NEW.due_date;
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically set worker_id and deadline
DROP TRIGGER IF EXISTS set_task_defaults ON public.tasks;
CREATE TRIGGER set_task_defaults
    BEFORE INSERT OR UPDATE ON public.tasks
    FOR EACH ROW
    EXECUTE FUNCTION set_worker_id_from_assigned_to();

-- Insert some sample data for testing (optional)
-- INSERT INTO public.tasks (
--     title, description, status, assigned_to, due_date, admin_name, 
--     category, quantity, product_name, progress, admin_id, worker_name
-- ) VALUES (
--     'Sample Task', 'This is a sample task for testing', 'pending', 
--     '3185a8c6-af71-448b-a305-6ca7fcae8491', now() + interval '7 days', 
--     'Admin User', 'production', 10, 'Sample Product', 0.0,
--     '577acd69-4d16-4677-8ed8-1cc5058423f3', 'Worker User'
-- );

-- Verify the table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'tasks' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Verify RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'tasks'
ORDER BY policyname;

-- =====================================================
-- END OF TASKS TABLE CREATION SCRIPT
-- =====================================================
