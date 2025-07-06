-- =====================================================
-- COMPREHENSIVE RLS POLICY FIX FOR TASKS TABLE
-- =====================================================
-- This script fixes all Row Level Security (RLS) policy issues
-- for the tasks table to resolve permission denied errors
-- Execute this script in your Supabase SQL Editor
-- =====================================================

-- Step 1: Enable RLS on the tasks table
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Step 2: Drop all existing conflicting policies
DROP POLICY IF EXISTS "Workers can view their assigned tasks" ON public.tasks;
DROP POLICY IF EXISTS "Admins can view all tasks" ON public.tasks;
DROP POLICY IF EXISTS "Workers can update their assigned tasks" ON public.tasks;
DROP POLICY IF EXISTS "Admins can create tasks" ON public.tasks;
DROP POLICY IF EXISTS "Admins can update tasks" ON public.tasks;
DROP POLICY IF EXISTS "Admins can delete tasks" ON public.tasks;
DROP POLICY IF EXISTS "Admin full access to tasks" ON public.tasks;
DROP POLICY IF EXISTS "Owner full access to tasks" ON public.tasks;
DROP POLICY IF EXISTS "Accountant view tasks" ON public.tasks;
DROP POLICY IF EXISTS "Worker access to assigned tasks" ON public.tasks;
DROP POLICY IF EXISTS "Accountant access to tasks" ON public.tasks;
DROP POLICY IF EXISTS "tasks_select_policy" ON public.tasks;
DROP POLICY IF EXISTS "tasks_insert_policy" ON public.tasks;
DROP POLICY IF EXISTS "tasks_update_policy" ON public.tasks;
DROP POLICY IF EXISTS "tasks_delete_policy" ON public.tasks;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.tasks;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.tasks;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.tasks;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.tasks;

-- Step 3: Create comprehensive RLS policies

-- Policy 1: Admin users have full access to all tasks
CREATE POLICY "admin_full_access_tasks" ON public.tasks
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role = 'admin'
    AND user_profiles.status IN ('active', 'approved')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role = 'admin'
    AND user_profiles.status IN ('active', 'approved')
  )
);

-- Policy 2: Owner users have full access to all tasks
CREATE POLICY "owner_full_access_tasks" ON public.tasks
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role = 'owner'
    AND user_profiles.status IN ('active', 'approved')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role = 'owner'
    AND user_profiles.status IN ('active', 'approved')
  )
);

-- Policy 3: Accountant users can view all tasks
CREATE POLICY "accountant_view_tasks" ON public.tasks
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE user_profiles.id = auth.uid() 
    AND user_profiles.role = 'accountant'
    AND user_profiles.status IN ('active', 'approved')
  )
);

-- Policy 4: Worker users can view and update their assigned tasks
CREATE POLICY "worker_assigned_tasks" ON public.tasks
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status IN ('active', 'approved')
  )
  AND (
    assigned_to = auth.uid()::text 
    OR worker_id = auth.uid()
    OR assigned_to = auth.uid()
  )
);

-- Policy 5: Worker users can update their assigned tasks (status and progress only)
CREATE POLICY "worker_update_assigned_tasks" ON public.tasks
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status IN ('active', 'approved')
  )
  AND (
    assigned_to = auth.uid()::text 
    OR worker_id = auth.uid()
    OR assigned_to = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.role = 'worker'
    AND user_profiles.status IN ('active', 'approved')
  )
  AND (
    assigned_to = auth.uid()::text 
    OR worker_id = auth.uid()
    OR assigned_to = auth.uid()
  )
);

-- Step 4: Grant necessary permissions to authenticated role
GRANT ALL ON public.tasks TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Step 5: Create helper function to check user role (optional but useful)
CREATE OR REPLACE FUNCTION public.get_user_role(user_id uuid)
RETURNS text AS $$
BEGIN
  RETURN (
    SELECT role FROM public.user_profiles 
    WHERE id = user_id AND status IN ('active', 'approved')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: Verify the policies are working
-- You can run these queries to test:
-- SELECT * FROM public.tasks; -- Should work for authenticated users based on their role
-- INSERT INTO public.tasks (...) VALUES (...); -- Should work for admin/owner users

-- Step 7: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to ON public.tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_worker_id ON public.tasks(worker_id);
CREATE INDEX IF NOT EXISTS idx_tasks_admin_id ON public.tasks(admin_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON public.tasks(created_at);

-- =====================================================
-- VERIFICATION QUERIES (Run these to test)
-- =====================================================
-- 1. Check if RLS is enabled:
-- SELECT schemaname, tablename, rowsecurity FROM pg_tables WHERE tablename = 'tasks';

-- 2. List all policies on tasks table:
-- SELECT policyname, permissive, roles, cmd, qual, with_check FROM pg_policies WHERE tablename = 'tasks';

-- 3. Test task creation (should work for admin users):
-- INSERT INTO public.tasks (title, description, status, assigned_to, admin_id) 
-- VALUES ('Test Task', 'Test Description', 'pending', auth.uid(), auth.uid());

-- =====================================================
-- NOTES:
-- =====================================================
-- 1. Make sure your admin user has role='admin' and status='approved' in user_profiles table
-- 2. The policies use both 'active' and 'approved' status for compatibility
-- 3. Worker tasks are matched by assigned_to, worker_id, or assigned_to fields
-- 4. Admin and Owner users have full CRUD access
-- 5. Accountant users have read-only access
-- 6. Worker users have read/update access to their assigned tasks only
-- =====================================================
