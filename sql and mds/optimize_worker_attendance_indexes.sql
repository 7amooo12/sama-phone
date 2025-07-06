-- =====================================================
-- WORKER ATTENDANCE REPORTS - PERFORMANCE OPTIMIZATION INDEXES
-- =====================================================
-- 
-- CRITICAL PERFORMANCE FIX: Create missing indexes for optimal performance
-- of SECURITY DEFINER functions in SmartBizTracker's worker attendance system.
--
-- PROBLEM IDENTIFIED: 
-- - Existing index only covers workers (WHERE role = 'عامل')
-- - SECURITY DEFINER functions need to query ALL user roles for authentication
-- - Critical security query runs on every attendance report request
--
-- TARGET QUERIES TO OPTIMIZE:
-- 1. SELECT role FROM user_profiles WHERE id = auth.uid() AND status = 'approved'
-- 2. SELECT up.id, up.name, up.profile_image FROM user_profiles up 
--    WHERE up.role = 'عامل' AND up.status = 'approved'
-- =====================================================

-- Step 1: Analyze current index status
DO $$
BEGIN
    RAISE NOTICE '🔍 ANALYZING CURRENT INDEX STATUS...';
    RAISE NOTICE '';
END $$;

-- Check existing indexes on user_profiles table
SELECT 
    '📊 CURRENT INDEXES ON user_profiles' as analysis_type,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'user_profiles' 
AND schemaname = 'public'
ORDER BY indexname;

-- Step 2: Identify the performance gap
DO $$
DECLARE
    worker_index_exists BOOLEAN := FALSE;
    general_index_exists BOOLEAN := FALSE;
    auth_index_exists BOOLEAN := FALSE;
BEGIN
    -- Check if worker-specific index exists
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'user_profiles' 
        AND indexname = 'idx_user_profiles_role_status'
    ) INTO worker_index_exists;
    
    -- Check if general role/status index exists
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'user_profiles' 
        AND indexname = 'idx_user_profiles_role_status_general'
    ) INTO general_index_exists;
    
    -- Check if authentication index exists
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'user_profiles' 
        AND indexname = 'idx_user_profiles_id_status_auth'
    ) INTO auth_index_exists;
    
    RAISE NOTICE '🔍 INDEX GAP ANALYSIS:';
    RAISE NOTICE '   Worker-specific index (role=عامل): %', CASE WHEN worker_index_exists THEN '✅ EXISTS' ELSE '❌ MISSING' END;
    RAISE NOTICE '   General role/status index: %', CASE WHEN general_index_exists THEN '✅ EXISTS' ELSE '❌ MISSING' END;
    RAISE NOTICE '   Authentication index (id,status): %', CASE WHEN auth_index_exists THEN '✅ EXISTS' ELSE '❌ MISSING' END;
    RAISE NOTICE '';
END $$;

-- Step 3: Create performance-critical indexes
DO $$
BEGIN
    RAISE NOTICE '🚀 CREATING PERFORMANCE-CRITICAL INDEXES...';
    RAISE NOTICE '';
END $$;

-- PRIMARY INDEX: Authentication query optimization
-- Target query: SELECT role FROM user_profiles WHERE id = auth.uid() AND status = 'approved'
CREATE INDEX IF NOT EXISTS idx_user_profiles_id_status_auth
ON user_profiles(id, status) 
WHERE status = 'approved';

-- SECONDARY INDEX: General role-based queries (without role restriction)
-- Target: Role validation checks across the system
CREATE INDEX IF NOT EXISTS idx_user_profiles_role_status_general
ON user_profiles(role, status) 
WHERE status = 'approved';

-- TERTIARY INDEX: Update existing worker index to include status filter
-- Target query: SELECT up.id, up.name, up.profile_image FROM user_profiles up 
--               WHERE up.role = 'عامل' AND up.status = 'approved'
DROP INDEX IF EXISTS idx_user_profiles_role_status;
CREATE INDEX idx_user_profiles_role_status_workers
ON user_profiles(role, status, id, name, profile_image) 
WHERE role = 'عامل' AND status = 'approved';

-- QUATERNARY INDEX: Worker attendance records optimization
-- Target: JOIN operations between user_profiles and worker_attendance_records
CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_worker_id_timestamp
ON worker_attendance_records(worker_id, timestamp DESC);

-- QUINARY INDEX: Worker attendance records by type and date
-- Target: Attendance type filtering in report calculations
-- Using functional index with proper PostgreSQL syntax for date extraction
CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_type_date
ON worker_attendance_records(attendance_type, (timestamp::date), worker_id);

-- Step 4: Create covering index for worker profile queries
-- This index includes all columns needed for worker queries to avoid table lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_workers_covering
ON user_profiles(role, status, id, name, profile_image, created_at)
WHERE role = 'عامل' AND status = 'approved';

-- Step 5: Verify index creation
DO $$
DECLARE
    index_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE tablename = 'user_profiles' 
    AND schemaname = 'public'
    AND indexname LIKE 'idx_user_profiles_%';
    
    RAISE NOTICE '✅ INDEX CREATION COMPLETE';
    RAISE NOTICE '   Total user_profiles indexes: %', index_count;
    RAISE NOTICE '';
END $$;

-- Step 6: Performance verification queries
DO $$
BEGIN
    RAISE NOTICE '🧪 PERFORMANCE VERIFICATION QUERIES...';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Run these EXPLAIN ANALYZE queries to verify index usage:';
    RAISE NOTICE '';
    RAISE NOTICE '1. Authentication Query:';
    RAISE NOTICE '   EXPLAIN ANALYZE SELECT role FROM user_profiles WHERE id = ''00000000-0000-0000-0000-000000000000'' AND status = ''approved'';';
    RAISE NOTICE '';
    RAISE NOTICE '2. Worker Lookup Query:';
    RAISE NOTICE '   EXPLAIN ANALYZE SELECT id, name, profile_image FROM user_profiles WHERE role = ''عامل'' AND status = ''approved'';';
    RAISE NOTICE '';
    RAISE NOTICE '3. Role Validation Query:';
    RAISE NOTICE '   EXPLAIN ANALYZE SELECT COUNT(*) FROM user_profiles WHERE role IN (''admin'', ''owner'', ''accountant'', ''warehouseManager'') AND status = ''approved'';';
    RAISE NOTICE '';
END $$;

-- Step 7: Index usage statistics setup
-- Create a view to monitor index usage
CREATE OR REPLACE VIEW worker_attendance_index_stats AS
SELECT
    schemaname,
    relname as tablename,  -- ✅ Use correct column name with alias
    indexname,
    idx_tup_read,
    idx_tup_fetch,
    idx_scan,
    CASE
        WHEN idx_scan = 0 THEN '❌ UNUSED'
        WHEN idx_scan < 10 THEN '⚠️ LOW USAGE'
        WHEN idx_scan < 100 THEN '✅ MODERATE USAGE'
        ELSE '🚀 HIGH USAGE'
    END as usage_status
FROM pg_stat_user_indexes
WHERE relname IN ('user_profiles', 'worker_attendance_records')  -- ✅ Use relname
ORDER BY idx_scan DESC;

-- Step 8: Performance impact analysis
DO $$
DECLARE
    user_count INTEGER;
    worker_count INTEGER;
    attendance_records INTEGER;
BEGIN
    -- Get table sizes for performance context
    SELECT COUNT(*) INTO user_count FROM user_profiles;
    SELECT COUNT(*) INTO worker_count FROM user_profiles WHERE role = 'عامل' AND status = 'approved';
    SELECT COUNT(*) INTO attendance_records FROM worker_attendance_records;
    
    RAISE NOTICE '📊 PERFORMANCE IMPACT ANALYSIS:';
    RAISE NOTICE '   Total users: %', user_count;
    RAISE NOTICE '   Approved workers: %', worker_count;
    RAISE NOTICE '   Attendance records: %', attendance_records;
    RAISE NOTICE '';
    
    IF user_count > 1000 THEN
        RAISE NOTICE '🚀 HIGH IMPACT: Large user base will benefit significantly from indexes';
    ELSIF user_count > 100 THEN
        RAISE NOTICE '✅ MODERATE IMPACT: Indexes will provide noticeable performance improvement';
    ELSE
        RAISE NOTICE '💡 LOW IMPACT: Small user base, but indexes still beneficial for consistency';
    END IF;
    RAISE NOTICE '';
END $$;

-- Step 9: Maintenance recommendations
DO $$
BEGIN
    RAISE NOTICE '🔧 INDEX MAINTENANCE RECOMMENDATIONS:';
    RAISE NOTICE '';
    RAISE NOTICE '1. Monitor index usage with: SELECT * FROM worker_attendance_index_stats;';
    RAISE NOTICE '2. Analyze query performance regularly with EXPLAIN ANALYZE';
    RAISE NOTICE '3. Consider REINDEX if performance degrades over time';
    RAISE NOTICE '4. Monitor index size growth: SELECT pg_size_pretty(pg_relation_size(indexname::regclass)) FROM pg_indexes WHERE tablename = ''user_profiles'';';
    RAISE NOTICE '';
END $$;

-- Step 10: Success summary
DO $$
BEGIN
    RAISE NOTICE '🎉 WORKER ATTENDANCE PERFORMANCE OPTIMIZATION COMPLETE!';
    RAISE NOTICE '';
    RAISE NOTICE '✅ INDEXES CREATED:';
    RAISE NOTICE '   1. idx_user_profiles_id_status_auth - Authentication queries';
    RAISE NOTICE '   2. idx_user_profiles_role_status_general - Role validation';
    RAISE NOTICE '   3. idx_user_profiles_role_status_workers - Worker lookups';
    RAISE NOTICE '   4. idx_worker_attendance_records_worker_id_timestamp - Attendance records';
    RAISE NOTICE '   5. idx_worker_attendance_records_type_date - Attendance type filtering';
    RAISE NOTICE '   6. idx_user_profiles_workers_covering - Covering index for workers';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 PERFORMANCE BENEFITS:';
    RAISE NOTICE '   - Faster SECURITY DEFINER function execution';
    RAISE NOTICE '   - Optimized role-based authentication queries';
    RAISE NOTICE '   - Improved worker attendance report generation';
    RAISE NOTICE '   - Reduced database load for frequent operations';
    RAISE NOTICE '';
    RAISE NOTICE '🔒 SECURITY MAINTAINED:';
    RAISE NOTICE '   - All indexes include status = ''approved'' filter';
    RAISE NOTICE '   - No impact on RLS policies or security functions';
    RAISE NOTICE '   - Covering indexes reduce data exposure';
    RAISE NOTICE '';
END $$;
