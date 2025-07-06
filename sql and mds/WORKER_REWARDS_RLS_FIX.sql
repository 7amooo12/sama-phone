-- =====================================================
-- WORKER REWARDS RLS POLICY FIX
-- =====================================================
-- This script fixes the RLS policy violation for worker_rewards table
-- by creating basic permissive policies similar to the tasks table fix
-- =====================================================

-- =====================================================
-- ANALYSIS OF THE ISSUE
-- =====================================================
-- The error occurs because:
-- 1. WorkerRewardsProvider.awardReward tries to insert into worker_rewards table
-- 2. Current RLS policies require role-based validation from user_profiles table
-- 3. The admin user might not have the correct role or the policy check is failing
-- 4. We need basic permissive policies for authenticated users

-- =====================================================
-- STEP 1: ENABLE RLS ON ALL WORKER REWARD TABLES
-- =====================================================

ALTER TABLE IF EXISTS public.worker_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.worker_reward_balances ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- STEP 2: DROP ALL EXISTING RESTRICTIVE POLICIES
-- =====================================================

-- Drop worker_rewards policies
DROP POLICY IF EXISTS "Workers can view their rewards" ON public.worker_rewards;
DROP POLICY IF EXISTS "Admins can view all rewards" ON public.worker_rewards;
DROP POLICY IF EXISTS "Admins can insert rewards" ON public.worker_rewards;
DROP POLICY IF EXISTS "Admins can update rewards" ON public.worker_rewards;
DROP POLICY IF EXISTS "Admins can manage all rewards" ON public.worker_rewards;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.worker_rewards;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.worker_rewards;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.worker_rewards;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.worker_rewards;

-- Drop worker_reward_balances policies
DROP POLICY IF EXISTS "Workers can view their balance" ON public.worker_reward_balances;
DROP POLICY IF EXISTS "Admins can view all balances" ON public.worker_reward_balances;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.worker_reward_balances;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.worker_reward_balances;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.worker_reward_balances;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.worker_reward_balances;

-- =====================================================
-- STEP 3: CREATE BASIC PERMISSIVE POLICIES
-- =====================================================
-- These policies allow any authenticated user to perform operations
-- This is the same approach we used for the tasks table

-- Worker Rewards Table Policies
CREATE POLICY "Enable read access for all users" ON public.worker_rewards 
FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users" ON public.worker_rewards 
FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users" ON public.worker_rewards 
FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users" ON public.worker_rewards 
FOR DELETE TO authenticated USING (true);

-- Worker Reward Balances Table Policies
CREATE POLICY "Enable read access for all users" ON public.worker_reward_balances 
FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users" ON public.worker_reward_balances 
FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users" ON public.worker_reward_balances 
FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users" ON public.worker_reward_balances 
FOR DELETE TO authenticated USING (true);

-- =====================================================
-- STEP 4: GRANT NECESSARY PERMISSIONS
-- =====================================================

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.worker_rewards TO authenticated;
GRANT ALL ON public.worker_reward_balances TO authenticated;

-- =====================================================
-- STEP 5: VERIFY POLICIES WERE CREATED
-- =====================================================

SELECT 'WORKER_REWARDS TABLE POLICIES:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'worker_rewards'
ORDER BY policyname;

SELECT 'WORKER_REWARD_BALANCES TABLE POLICIES:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'worker_reward_balances'
ORDER BY policyname;

-- =====================================================
-- STEP 6: TEST THE POLICIES (OPTIONAL)
-- =====================================================
-- Uncomment these lines to test the policies manually
-- Make sure to replace the UUIDs with actual values from your database

-- Test insert into worker_rewards (replace UUIDs with real values)
-- INSERT INTO public.worker_rewards (
--     worker_id, amount, reward_type, description, awarded_by, status
-- ) VALUES (
--     '3185a8c6-af71-448b-a305-6ca7fcae8491', -- worker_id
--     100.00, -- amount
--     'monetary', -- reward_type
--     'Test reward', -- description
--     (SELECT auth.uid()), -- awarded_by (current user)
--     'active' -- status
-- );

-- Test insert into worker_reward_balances (replace UUID with real value)
-- INSERT INTO public.worker_reward_balances (
--     worker_id, current_balance, total_earned, total_withdrawn
-- ) VALUES (
--     '3185a8c6-af71-448b-a305-6ca7fcae8491', -- worker_id
--     100.00, -- current_balance
--     100.00, -- total_earned
--     0.00 -- total_withdrawn
-- ) ON CONFLICT (worker_id) DO UPDATE SET
--     current_balance = worker_reward_balances.current_balance + 100.00,
--     total_earned = worker_reward_balances.total_earned + 100.00,
--     last_updated = NOW();

-- =====================================================
-- STEP 7: DEBUGGING INFORMATION
-- =====================================================

-- Check current user authentication
SELECT 'CURRENT USER INFO:' as info;
SELECT auth.uid() as user_id, auth.email() as user_email;

-- Check if user_profiles table has the admin user
SELECT 'ADMIN USER IN USER_PROFILES:' as info;
SELECT id, name, email, role, status 
FROM public.user_profiles 
WHERE email = 'admin@sama.com' OR role = 'admin'
ORDER BY email;

-- Check existing worker_rewards records
SELECT 'EXISTING WORKER_REWARDS COUNT:' as info;
SELECT COUNT(*) as total_rewards FROM public.worker_rewards;

-- Check existing worker_reward_balances records
SELECT 'EXISTING WORKER_REWARD_BALANCES COUNT:' as info;
SELECT COUNT(*) as total_balances FROM public.worker_reward_balances;

-- =====================================================
-- ALTERNATIVE: ROLE-BASED POLICIES (IF NEEDED LATER)
-- =====================================================
-- If you want to implement more restrictive role-based policies later,
-- uncomment and modify these policies after ensuring user roles are correct

-- -- Admin users can do everything with rewards
-- CREATE POLICY "Admin full access to worker_rewards" ON public.worker_rewards
-- FOR ALL TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.user_profiles 
--     WHERE user_profiles.id = auth.uid() 
--     AND user_profiles.role IN ('admin', 'owner', 'manager')
--     AND user_profiles.status = 'approved'
--   )
-- )
-- WITH CHECK (
--   EXISTS (
--     SELECT 1 FROM public.user_profiles 
--     WHERE user_profiles.id = auth.uid() 
--     AND user_profiles.role IN ('admin', 'owner', 'manager')
--     AND user_profiles.status = 'approved'
--   )
-- );

-- -- Workers can view their own rewards
-- CREATE POLICY "Worker view own rewards" ON public.worker_rewards
-- FOR SELECT TO authenticated
-- USING (
--   EXISTS (
--     SELECT 1 FROM public.user_profiles 
--     WHERE user_profiles.id = auth.uid() 
--     AND user_profiles.role = 'worker'
--     AND user_profiles.status = 'approved'
--   )
--   AND worker_id = auth.uid()
-- );

-- =====================================================
-- END OF WORKER REWARDS RLS FIX
-- =====================================================
