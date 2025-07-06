-- =====================================================
-- SUPABASE RLS POLICIES FIX FOR TASK ASSIGNMENT ISSUE
-- =====================================================
-- This script fixes the Row Level Security (RLS) policies
-- for the task management system in SmartBizTracker
--
-- IMPORTANT: Run CREATE_TASKS_TABLE_SCHEMA.sql first to create
-- the tasks table with the correct structure for TaskModel
-- =====================================================

-- First, let's check if the tables exist and enable RLS
-- =====================================================

-- Enable RLS for tasks table (used by TaskService with TaskModel)
ALTER TABLE IF EXISTS public.tasks ENABLE ROW LEVEL SECURITY;

-- Enable RLS for worker_tasks table (used by WorkerTaskProvider with WorkerTaskModel)
ALTER TABLE IF EXISTS public.worker_tasks ENABLE ROW LEVEL SECURITY;

-- Enable RLS for task_submissions table
ALTER TABLE IF EXISTS public.task_submissions ENABLE ROW LEVEL SECURITY;

-- Enable RLS for task_feedback table
ALTER TABLE IF EXISTS public.task_feedback ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- DROP EXISTING POLICIES (if any) TO AVOID CONFLICTS
-- =====================================================

-- Drop existing policies for tasks table
DROP POLICY IF EXISTS "Enable read access for all users" ON public.tasks;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.tasks;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.tasks;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.tasks;
DROP POLICY IF EXISTS "Admin can manage all tasks" ON public.tasks;
DROP POLICY IF EXISTS "Workers can view assigned tasks" ON public.tasks;

-- Drop existing policies for worker_tasks table
DROP POLICY IF EXISTS "Enable read access for all users" ON public.worker_tasks;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.worker_tasks;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.worker_tasks;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.worker_tasks;
DROP POLICY IF EXISTS "Admin can manage all worker tasks" ON public.worker_tasks;
DROP POLICY IF EXISTS "Workers can view assigned worker tasks" ON public.worker_tasks;

-- =====================================================
-- CREATE COMPREHENSIVE RLS POLICIES FOR TASKS TABLE
-- =====================================================

-- Policy 1: Admin users can do everything on tasks
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

-- Policy 2: Owner users can do everything on tasks
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

-- Policy 3: Accountant users can view and update tasks
CREATE POLICY "Accountant access to tasks" ON public.tasks
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role = 'accountant'
    AND user_profiles.status = 'approved'
  )
);

-- Policy 4: Workers can view and update their assigned tasks
CREATE POLICY "Worker access to assigned tasks" ON public.tasks
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status = 'approved'
  )
  AND (assigned_to = auth.uid()::text OR worker_id = auth.uid())
);

-- Policy 5: Workers can update their assigned tasks
CREATE POLICY "Worker update assigned tasks" ON public.tasks
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status = 'approved'
  )
  AND (assigned_to = auth.uid()::text OR worker_id = auth.uid())
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status = 'approved'
  )
  AND (assigned_to = auth.uid()::text OR worker_id = auth.uid())
);

-- =====================================================
-- CREATE COMPREHENSIVE RLS POLICIES FOR WORKER_TASKS TABLE
-- =====================================================

-- Policy 1: Admin users can do everything on worker_tasks
CREATE POLICY "Admin full access to worker_tasks" ON public.worker_tasks
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

-- Policy 2: Owner users can do everything on worker_tasks
CREATE POLICY "Owner full access to worker_tasks" ON public.worker_tasks
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

-- Policy 3: Accountant users can view worker_tasks
CREATE POLICY "Accountant view worker_tasks" ON public.worker_tasks
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role = 'accountant'
    AND user_profiles.status = 'approved'
  )
);

-- Policy 4: Workers can view their assigned worker_tasks
CREATE POLICY "Worker view assigned worker_tasks" ON public.worker_tasks
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status = 'approved'
  )
  AND assigned_to = auth.uid()
);

-- Policy 5: Workers can update their assigned worker_tasks
CREATE POLICY "Worker update assigned worker_tasks" ON public.worker_tasks
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status = 'approved'
  )
  AND assigned_to = auth.uid()
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status = 'approved'
  )
  AND assigned_to = auth.uid()
);

-- =====================================================
-- CREATE RLS POLICIES FOR TASK_SUBMISSIONS TABLE
-- =====================================================

-- Policy 1: Admin and Owner full access to task_submissions
CREATE POLICY "Admin Owner full access to task_submissions" ON public.task_submissions
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role IN ('admin', 'owner')
    AND user_profiles.status = 'approved'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role IN ('admin', 'owner')
    AND user_profiles.status = 'approved'
  )
);

-- Policy 2: Workers can manage their own task submissions
CREATE POLICY "Worker manage own task_submissions" ON public.task_submissions
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status = 'approved'
  )
  AND worker_id = auth.uid()
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status = 'approved'
  )
  AND worker_id = auth.uid()
);

-- =====================================================
-- CREATE RLS POLICIES FOR TASK_FEEDBACK TABLE
-- =====================================================

-- Policy 1: Admin and Owner full access to task_feedback
CREATE POLICY "Admin Owner full access to task_feedback" ON public.task_feedback
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role IN ('admin', 'owner')
    AND user_profiles.status = 'approved'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role IN ('admin', 'owner')
    AND user_profiles.status = 'approved'
  )
);

-- Policy 2: Workers can view feedback on their submissions
CREATE POLICY "Worker view own task_feedback" ON public.task_feedback
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status = 'approved'
  )
  AND EXISTS (
    SELECT 1 FROM public.task_submissions
    WHERE task_submissions.id = task_feedback.submission_id
    AND task_submissions.worker_id = auth.uid()
  )
);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check if policies were created successfully
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('tasks', 'worker_tasks', 'task_submissions', 'task_feedback')
ORDER BY tablename, policyname;

-- =====================================================
-- GRANT NECESSARY PERMISSIONS
-- =====================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO authenticated;

-- Grant permissions on tables
GRANT ALL ON public.tasks TO authenticated;
GRANT ALL ON public.worker_tasks TO authenticated;
GRANT ALL ON public.task_submissions TO authenticated;
GRANT ALL ON public.task_feedback TO authenticated;

-- =====================================================
-- END OF RLS POLICIES FIX
-- =====================================================
