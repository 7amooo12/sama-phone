-- =====================================================
-- FINAL RLS FIX FOR TASK ASSIGNMENT ISSUE
-- =====================================================
-- This script creates the exact policies suggested by the app
-- and ensures the admin user can insert tasks
-- =====================================================

-- First, ensure the tasks table exists and RLS is enabled
ALTER TABLE IF EXISTS public.tasks ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Enable read access for all users" ON public.tasks;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.tasks;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.tasks;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.tasks;
DROP POLICY IF EXISTS "Admin full access to tasks" ON public.tasks;
DROP POLICY IF EXISTS "Owner full access to tasks" ON public.tasks;
DROP POLICY IF EXISTS "Accountant access to tasks" ON public.tasks;
DROP POLICY IF EXISTS "Worker access to assigned tasks" ON public.tasks;
DROP POLICY IF EXISTS "Worker update assigned tasks" ON public.tasks;

-- Create the basic policies as suggested by the app
CREATE POLICY "Enable read access for all users" ON public.tasks 
FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users" ON public.tasks 
FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users" ON public.tasks 
FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users" ON public.tasks 
FOR DELETE TO authenticated USING (true);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.tasks TO authenticated;

-- Verify the admin user exists and has the correct role
-- This is just for verification - run this separately to check
-- SELECT id, email, role, status FROM public.user_profiles WHERE email = 'admin@sama.com';

-- Test the policies by trying to insert a sample task
-- This is just for testing - run this separately as the admin user
-- INSERT INTO public.tasks (
--     title, description, status, assigned_to, due_date, 
--     admin_name, category, quantity, product_name, progress
-- ) VALUES (
--     'Test Task', 'Test Description', 'pending', 
--     '3185a8c6-af71-448b-a305-6ca7fcae8491', 
--     now() + interval '7 days',
--     'Admin User', 'production', 1, 'Test Product', 0.0
-- );

-- Verify the policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'tasks'
ORDER BY policyname;

-- =====================================================
-- ALTERNATIVE: More specific role-based policies
-- =====================================================
-- If the basic policies above don't work, uncomment and run these instead:

-- DROP POLICY IF EXISTS "Enable read access for all users" ON public.tasks;
-- DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.tasks;
-- DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.tasks;
-- DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.tasks;

-- -- Admin users can do everything
-- CREATE POLICY "Admin full access to tasks" ON public.tasks
-- FOR ALL TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.user_profiles 
--     WHERE user_profiles.id = auth.uid() 
--     AND user_profiles.role = 'admin'
--     AND user_profiles.status = 'approved'
--   )
-- )
-- WITH CHECK (
--   EXISTS (
--     SELECT 1 FROM public.user_profiles 
--     WHERE user_profiles.id = auth.uid() 
--     AND user_profiles.role = 'admin'
--     AND user_profiles.status = 'approved'
--   )
-- );

-- -- Owner users can do everything
-- CREATE POLICY "Owner full access to tasks" ON public.tasks
-- FOR ALL TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.user_profiles 
--     WHERE user_profiles.id = auth.uid() 
--     AND user_profiles.role = 'owner'
--     AND user_profiles.status = 'approved'
--   )
-- )
-- WITH CHECK (
--   EXISTS (
--     SELECT 1 FROM public.user_profiles 
--     WHERE user_profiles.id = auth.uid() 
--     AND user_profiles.role = 'owner'
--     AND user_profiles.status = 'approved'
--   )
-- );

-- -- Accountant users can view tasks
-- CREATE POLICY "Accountant view tasks" ON public.tasks
-- FOR SELECT TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.user_profiles 
--     WHERE user_profiles.id = auth.uid() 
--     AND user_profiles.role = 'accountant'
--     AND user_profiles.status = 'approved'
--   )
-- );

-- -- Workers can view and update their assigned tasks
-- CREATE POLICY "Worker view assigned tasks" ON public.tasks
-- FOR SELECT TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.user_profiles 
--     WHERE user_profiles.id = auth.uid() 
--     AND user_profiles.role = 'worker'
--     AND user_profiles.status = 'approved'
--   )
--   AND (assigned_to = auth.uid()::text OR worker_id = auth.uid()::text)
-- );

-- CREATE POLICY "Worker update assigned tasks" ON public.tasks
-- FOR UPDATE TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.user_profiles 
--     WHERE user_profiles.id = auth.uid() 
--     AND user_profiles.role = 'worker'
--     AND user_profiles.status = 'approved'
--   )
--   AND (assigned_to = auth.uid()::text OR worker_id = auth.uid()::text)
-- )
-- WITH CHECK (
--   EXISTS (
--     SELECT 1 FROM public.user_profiles 
--     WHERE user_profiles.id = auth.uid() 
--     AND user_profiles.role = 'worker'
--     AND user_profiles.status = 'approved'
--   )
--   AND (assigned_to = auth.uid()::text OR worker_id = auth.uid()::text)
-- );

-- =====================================================
-- DEBUGGING QUERIES
-- =====================================================
-- Run these to debug the issue:

-- 1. Check if the admin user exists and has the correct role
-- SELECT id, email, role, status FROM public.user_profiles WHERE email = 'admin@sama.com';

-- 2. Check the current authenticated user
-- SELECT auth.uid(), auth.email();

-- 3. Check if the user_profiles table has RLS enabled
-- SELECT schemaname, tablename, rowsecurity FROM pg_tables WHERE tablename = 'user_profiles';

-- 4. Check user_profiles RLS policies
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd 
-- FROM pg_policies 
-- WHERE schemaname = 'public' 
-- AND tablename = 'user_profiles'
-- ORDER BY policyname;

-- =====================================================
-- FIX FOR WORKER_TASKS TABLE (THE REAL ISSUE!)
-- =====================================================
-- The issue is that there's a database trigger that automatically
-- inserts into worker_tasks table when inserting into tasks table.
-- We need to create the same basic policies for worker_tasks table.

-- Enable RLS on worker_tasks table
ALTER TABLE IF EXISTS public.worker_tasks ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies for worker_tasks to start fresh
DROP POLICY IF EXISTS "Enable read access for all users" ON public.worker_tasks;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.worker_tasks;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.worker_tasks;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.worker_tasks;
DROP POLICY IF EXISTS "Admin full access to worker_tasks" ON public.worker_tasks;
DROP POLICY IF EXISTS "Owner full access to worker_tasks" ON public.worker_tasks;
DROP POLICY IF EXISTS "Accountant view worker_tasks" ON public.worker_tasks;
DROP POLICY IF EXISTS "Worker view assigned worker_tasks" ON public.worker_tasks;
DROP POLICY IF EXISTS "Worker update assigned worker_tasks" ON public.worker_tasks;
DROP POLICY IF EXISTS "Workers can view their assigned tasks" ON public.worker_tasks;
DROP POLICY IF EXISTS "Admins can view all tasks" ON public.worker_tasks;
DROP POLICY IF EXISTS "Admins can insert tasks" ON public.worker_tasks;
DROP POLICY IF EXISTS "Admins can update tasks" ON public.worker_tasks;
DROP POLICY IF EXISTS "Workers can update their tasks" ON public.worker_tasks;

-- Create the same basic policies for worker_tasks as we did for tasks
CREATE POLICY "Enable read access for all users" ON public.worker_tasks
FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users" ON public.worker_tasks
FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users" ON public.worker_tasks
FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users" ON public.worker_tasks
FOR DELETE TO authenticated USING (true);

-- Grant necessary permissions for worker_tasks
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.worker_tasks TO authenticated;

-- Also fix task_submissions and task_feedback tables
ALTER TABLE IF EXISTS public.task_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.task_feedback ENABLE ROW LEVEL SECURITY;

-- Drop existing policies for task_submissions
DROP POLICY IF EXISTS "Enable read access for all users" ON public.task_submissions;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.task_submissions;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.task_submissions;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.task_submissions;

-- Create basic policies for task_submissions
CREATE POLICY "Enable read access for all users" ON public.task_submissions
FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users" ON public.task_submissions
FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users" ON public.task_submissions
FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users" ON public.task_submissions
FOR DELETE TO authenticated USING (true);

-- Drop existing policies for task_feedback
DROP POLICY IF EXISTS "Enable read access for all users" ON public.task_feedback;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.task_feedback;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.task_feedback;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.task_feedback;

-- Create basic policies for task_feedback
CREATE POLICY "Enable read access for all users" ON public.task_feedback
FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users" ON public.task_feedback
FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users" ON public.task_feedback
FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users" ON public.task_feedback
FOR DELETE TO authenticated USING (true);

-- Grant permissions for all related tables
GRANT ALL ON public.task_submissions TO authenticated;
GRANT ALL ON public.task_feedback TO authenticated;

-- Verify all policies were created
SELECT 'TASKS TABLE POLICIES:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'tasks'
ORDER BY policyname;

SELECT 'WORKER_TASKS TABLE POLICIES:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'worker_tasks'
ORDER BY policyname;

SELECT 'TASK_SUBMISSIONS TABLE POLICIES:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'task_submissions'
ORDER BY policyname;

SELECT 'TASK_FEEDBACK TABLE POLICIES:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'task_feedback'
ORDER BY policyname;

-- =====================================================
-- DEBUGGING: Check if triggers exist
-- =====================================================
SELECT 'TRIGGERS ON TASKS TABLE:' as info;
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tasks'
AND event_object_schema = 'public';

-- =====================================================
-- END OF FINAL RLS FIX
-- =====================================================
