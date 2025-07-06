-- Fix RLS policies for tasks table to resolve permission denied errors
-- Execute this script in your Supabase SQL Editor

-- First, ensure RLS is enabled on the tasks table
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to start fresh
DROP POLICY IF EXISTS "Enable read access for all users" ON public.tasks;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.tasks;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.tasks;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.tasks;

-- Create SELECT policy - Allow all users to read tasks
CREATE POLICY "Enable read access for all users" 
ON public.tasks 
FOR SELECT 
USING (true);

-- Create INSERT policy - Allow authenticated users to insert tasks
CREATE POLICY "Enable insert for authenticated users" 
ON public.tasks 
FOR INSERT 
TO authenticated 
WITH CHECK (true);

-- Create UPDATE policy - Allow authenticated users to update tasks
CREATE POLICY "Enable update for authenticated users" 
ON public.tasks 
FOR UPDATE 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- Create DELETE policy - Allow authenticated users to delete tasks
CREATE POLICY "Enable delete for authenticated users" 
ON public.tasks 
FOR DELETE 
TO authenticated 
USING (true);

-- Grant necessary permissions to roles
GRANT ALL ON public.tasks TO authenticated;
GRANT SELECT ON public.tasks TO anon;

-- Verify the policies are created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'tasks' AND schemaname = 'public';

-- Display success message
DO $$
BEGIN
    RAISE NOTICE 'SUCCESS: RLS policies for tasks table have been created successfully!';
    RAISE NOTICE 'The following policies are now active:';
    RAISE NOTICE '1. SELECT: Enable read access for all users';
    RAISE NOTICE '2. INSERT: Enable insert for authenticated users';
    RAISE NOTICE '3. UPDATE: Enable update for authenticated users';
    RAISE NOTICE '4. DELETE: Enable delete for authenticated users';
    RAISE NOTICE '';
    RAISE NOTICE 'You can now test task creation in your Flutter app.';
END $$;
