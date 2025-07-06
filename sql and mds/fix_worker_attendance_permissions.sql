-- =====================================================
-- Fix Worker Attendance Permissions for SmartBizTracker
-- =====================================================
-- 
-- This script fixes the database permission error preventing worker 
-- attendance check-in functionality by adding proper RLS policies
-- and permissions for the worker_attendance_profiles table.
--
-- Error: permission denied for table worker_attendance_profiles, code: 42501
-- Root Cause: The migration script revoked direct table access but 
-- BiometricAttendanceService needs to create/read worker profiles.
--
-- Execute this script in your Supabase SQL Editor
-- =====================================================

-- Step 1: Enable RLS on worker_attendance_profiles if not already enabled
ALTER TABLE public.worker_attendance_profiles ENABLE ROW LEVEL SECURITY;

-- Step 2: Drop any existing conflicting policies
DROP POLICY IF EXISTS "workers_can_read_own_profile" ON public.worker_attendance_profiles;
DROP POLICY IF EXISTS "workers_can_insert_own_profile" ON public.worker_attendance_profiles;
DROP POLICY IF EXISTS "workers_can_update_own_profile" ON public.worker_attendance_profiles;
DROP POLICY IF EXISTS "admins_full_access_profiles" ON public.worker_attendance_profiles;

-- Step 3: Create RLS policies for worker attendance profiles

-- Policy 1: Workers can read their own attendance profile
CREATE POLICY "workers_can_read_own_profile" ON public.worker_attendance_profiles
    FOR SELECT 
    TO authenticated
    USING (
        worker_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager')
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 2: Workers can insert their own attendance profile
CREATE POLICY "workers_can_insert_own_profile" ON public.worker_attendance_profiles
    FOR INSERT 
    TO authenticated
    WITH CHECK (
        worker_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager')
            AND user_profiles.status = 'approved'
        )
    );

-- Policy 3: Workers can update their own attendance profile
CREATE POLICY "workers_can_update_own_profile" ON public.worker_attendance_profiles
    FOR UPDATE 
    TO authenticated
    USING (
        worker_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager')
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        worker_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager')
            AND user_profiles.status = 'approved'
        )
    );

-- Step 4: Grant necessary table permissions back to authenticated users
-- The original migration revoked these, but we need them for direct table access
GRANT SELECT, INSERT, UPDATE ON public.worker_attendance_profiles TO authenticated;

-- Step 5: Also ensure worker_attendance_records has proper permissions
ALTER TABLE public.worker_attendance_records ENABLE ROW LEVEL SECURITY;

-- Drop existing policies for worker_attendance_records
DROP POLICY IF EXISTS "workers_can_read_own_records" ON public.worker_attendance_records;
DROP POLICY IF EXISTS "workers_can_insert_own_records" ON public.worker_attendance_records;
DROP POLICY IF EXISTS "admins_full_access_records" ON public.worker_attendance_records;

-- Policy for workers to read their own attendance records
CREATE POLICY "workers_can_read_own_records" ON public.worker_attendance_records
    FOR SELECT 
    TO authenticated
    USING (
        worker_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager')
            AND user_profiles.status = 'approved'
        )
    );

-- Policy for workers to insert their own attendance records (via stored procedures)
CREATE POLICY "workers_can_insert_own_records" ON public.worker_attendance_records
    FOR INSERT 
    TO authenticated
    WITH CHECK (
        worker_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role IN ('admin', 'owner', 'warehouseManager')
            AND user_profiles.status = 'approved'
        )
    );

-- Grant necessary permissions for worker_attendance_records
GRANT SELECT, INSERT ON public.worker_attendance_records TO authenticated;

-- Step 6: Ensure stored procedures have proper permissions
GRANT EXECUTE ON FUNCTION process_biometric_attendance TO authenticated;
GRANT EXECUTE ON FUNCTION process_qr_attendance TO authenticated;
GRANT EXECUTE ON FUNCTION get_worker_attendance_stats TO authenticated;

-- Step 7: Verification queries
-- Check if policies were created successfully
SELECT 
    '✅ WORKER_ATTENDANCE_PROFILES POLICIES' as check_type,
    schemaname, 
    tablename, 
    policyname, 
    cmd,
    CASE 
        WHEN cmd = 'SELECT' THEN '👁️ READ'
        WHEN cmd = 'INSERT' THEN '➕ CREATE'
        WHEN cmd = 'UPDATE' THEN '✏️ MODIFY'
        WHEN cmd = 'DELETE' THEN '🗑️ DELETE'
        ELSE cmd
    END as operation
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename = 'worker_attendance_profiles'
ORDER BY tablename, cmd;

-- Check table permissions
SELECT 
    '🔐 TABLE PERMISSIONS' as check_type,
    grantee,
    table_name,
    privilege_type,
    is_grantable
FROM information_schema.table_privileges 
WHERE table_schema = 'public' 
AND table_name IN ('worker_attendance_profiles', 'worker_attendance_records')
AND grantee = 'authenticated'
ORDER BY table_name, privilege_type;

-- Check function permissions
SELECT 
    '⚙️ FUNCTION PERMISSIONS' as check_type,
    routine_name,
    routine_type,
    CASE 
        WHEN has_function_privilege('authenticated', routine_name, 'EXECUTE') 
        THEN '✅ GRANTED' 
        ELSE '❌ DENIED' 
    END as execute_permission
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN (
    'process_biometric_attendance',
    'process_qr_attendance', 
    'get_worker_attendance_stats'
)
ORDER BY routine_name;

-- Final success message
DO $$
BEGIN
    RAISE NOTICE '🎉 Worker attendance permissions have been fixed!';
    RAISE NOTICE '✅ Workers can now create and manage their own attendance profiles';
    RAISE NOTICE '✅ RLS policies ensure workers can only access their own data';
    RAISE NOTICE '✅ Admin roles maintain full access to all attendance data';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Please restart your Flutter app to test the fix';
END $$;
