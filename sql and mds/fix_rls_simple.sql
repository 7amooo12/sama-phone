-- Simple RLS Fix for SmartBizTracker - No Helper Functions
-- This script avoids function conflicts by using direct SQL expressions
-- Execute this in your Supabase SQL Editor

BEGIN;

-- 1. Fix TASKS table first (Priority - this was causing the original error)
ALTER TABLE public.tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Enable read access for all users" ON public.tasks;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.tasks;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.tasks;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.tasks;

-- Create simple, permissive policies for tasks
CREATE POLICY "Enable read access for all users" 
ON public.tasks FOR SELECT 
USING (true);

CREATE POLICY "Enable insert for authenticated users" 
ON public.tasks FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users" 
ON public.tasks FOR UPDATE 
TO authenticated 
USING (true) 
WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users" 
ON public.tasks FOR DELETE 
TO authenticated 
USING (true);

-- 2. Fix TASK_FEEDBACK table (Priority - RLS enabled but no policies)
ALTER TABLE public.task_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.task_feedback;

CREATE POLICY "Allow all for authenticated users" 
ON public.task_feedback 
FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- 3. Fix TASK_SUBMISSIONS table (Priority - RLS enabled but no policies)
ALTER TABLE public.task_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for authenticated users" ON public.task_submissions;

CREATE POLICY "Allow all for authenticated users" 
ON public.task_submissions 
FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- 4. Fix USER_PROFILES table (Essential for role checking)
ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profiles;

CREATE POLICY "Users can view all profiles" 
ON public.user_profiles 
FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Users can update own profile" 
ON public.user_profiles 
FOR UPDATE 
TO authenticated 
USING (id = auth.uid()) 
WITH CHECK (id = auth.uid());

CREATE POLICY "Users can insert own profile" 
ON public.user_profiles 
FOR INSERT 
TO authenticated 
WITH CHECK (id = auth.uid());

-- 5. Fix PRODUCTS table (Public access needed)
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Products viewable by everyone" ON public.products;
DROP POLICY IF EXISTS "Authenticated users can manage products" ON public.products;

CREATE POLICY "Products viewable by everyone" 
ON public.products 
FOR SELECT 
USING (true);

CREATE POLICY "Authenticated users can manage products" 
ON public.products 
FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- 6. Fix NOTIFICATIONS table
ALTER TABLE public.notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own notifications" ON public.notifications;

CREATE POLICY "Users manage own notifications" 
ON public.notifications 
FOR ALL 
TO authenticated 
USING (user_id = auth.uid()) 
WITH CHECK (user_id = auth.uid());

-- 7. Fix FAVORITES table
ALTER TABLE public.favorites DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own favorites" ON public.favorites;

CREATE POLICY "Users manage own favorites" 
ON public.favorites 
FOR ALL 
TO authenticated 
USING (user_id = auth.uid()) 
WITH CHECK (user_id = auth.uid());

-- Grant necessary permissions
GRANT ALL ON public.tasks TO authenticated;
GRANT ALL ON public.task_feedback TO authenticated;
GRANT ALL ON public.task_submissions TO authenticated;
GRANT ALL ON public.user_profiles TO authenticated;
GRANT ALL ON public.products TO authenticated;
GRANT ALL ON public.notifications TO authenticated;
GRANT ALL ON public.favorites TO authenticated;

GRANT SELECT ON public.products TO anon;
GRANT SELECT ON public.tasks TO anon;

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '=== SIMPLE RLS FIX COMPLETED ===';
    RAISE NOTICE 'Fixed priority tables:';
    RAISE NOTICE '✅ tasks - Full access for authenticated users';
    RAISE NOTICE '✅ task_feedback - Full access for authenticated users';
    RAISE NOTICE '✅ task_submissions - Full access for authenticated users';
    RAISE NOTICE '✅ user_profiles - View all, manage own';
    RAISE NOTICE '✅ products - Public read, authenticated manage';
    RAISE NOTICE '✅ notifications - Users manage own';
    RAISE NOTICE '✅ favorites - Users manage own';
    RAISE NOTICE '';
    RAISE NOTICE 'Your task creation should now work!';
    RAISE NOTICE 'Test your Flutter app and check for any remaining errors.';
END $$;
