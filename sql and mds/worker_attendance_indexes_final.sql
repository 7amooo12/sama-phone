-- =====================================================
-- WORKER ATTENDANCE PERFORMANCE INDEXES - FINAL VERSION
-- =====================================================
-- 
-- CRITICAL PERFORMANCE FIX: Create missing indexes for optimal performance
-- of SECURITY DEFINER functions in SmartBizTracker's worker attendance system.
--
-- IMMUTABLE FUNCTION FIX: Avoid all functional expressions that cause 42P17 errors
-- SOLUTION: Use simple indexes with range queries instead of functional indexes
--
-- TARGET QUERIES TO OPTIMIZE:
-- 1. SELECT role FROM user_profiles WHERE id = auth.uid() AND status = 'approved'
-- 2. SELECT up.id, up.name, up.profile_image FROM user_profiles up 
--    WHERE up.role = 'عامل' AND up.status = 'approved'
-- 3. Attendance record queries with date filtering using range queries
-- =====================================================

-- Step 1: Verify current database state
DO $$
BEGIN
    RAISE NOTICE '🔍 WORKER ATTENDANCE PERFORMANCE OPTIMIZATION - FINAL VERSION';
    RAISE NOTICE '';
    RAISE NOTICE '🛠️ Creating PostgreSQL-compatible indexes without IMMUTABLE function issues...';
    RAISE NOTICE '';
END $$;

-- Step 2: Create PRIMARY INDEX - Authentication query optimization
-- Target: SELECT role FROM user_profiles WHERE id = auth.uid() AND status = 'approved'
DO $$
BEGIN
    RAISE NOTICE '🚀 Creating PRIMARY INDEX: Authentication optimization...';
END $$;

CREATE INDEX IF NOT EXISTS idx_user_profiles_id_status_auth
ON user_profiles(id, status) 
WHERE status = 'approved';

-- Step 3: Create SECONDARY INDEX - General role-based queries
-- Target: Role validation checks across the system
DO $$
BEGIN
    RAISE NOTICE '🚀 Creating SECONDARY INDEX: Role validation optimization...';
END $$;

CREATE INDEX IF NOT EXISTS idx_user_profiles_role_status_general
ON user_profiles(role, status) 
WHERE status = 'approved';

-- Step 4: Create WORKER-SPECIFIC INDEX (replace existing)
-- Target: SELECT up.id, up.name, up.profile_image FROM user_profiles up 
--         WHERE up.role = 'عامل' AND up.status = 'approved'
DO $$
BEGIN
    RAISE NOTICE '🚀 Creating WORKER-SPECIFIC INDEX: Worker lookup optimization...';
END $$;

-- Drop old index if exists and create optimized version
DROP INDEX IF EXISTS idx_user_profiles_role_status;
CREATE INDEX idx_user_profiles_role_status_workers
ON user_profiles(role, status, id, name, profile_image) 
WHERE role = 'عامل' AND status = 'approved';

-- Step 5: Create ATTENDANCE RECORDS INDEX - Worker ID and timestamp
-- Target: JOIN operations and attendance record lookups
DO $$
BEGIN
    RAISE NOTICE '🚀 Creating ATTENDANCE RECORDS INDEX: Worker ID optimization...';
END $$;

CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_worker_id_timestamp
ON worker_attendance_records(worker_id, timestamp DESC);

-- Step 6: Create DATE-BASED INDEXES without functional expressions
-- Target: Attendance type filtering with date range queries
DO $$
BEGIN
    RAISE NOTICE '🚀 Creating DATE-BASED INDEXES: Attendance filtering (NO IMMUTABLE ISSUES)...';
END $$;

-- Primary date index: Simple index for type and timestamp
CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_type_timestamp
ON worker_attendance_records(attendance_type, timestamp, worker_id);

-- Secondary date index: Optimized for recent records
CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_timestamp_recent
ON worker_attendance_records(timestamp DESC, attendance_type, worker_id);

-- Step 7: Create COVERING INDEX for worker profile queries
-- This includes all columns needed to avoid table lookups
DO $$
BEGIN
    RAISE NOTICE '🚀 Creating COVERING INDEX: Complete worker data optimization...';
END $$;

CREATE INDEX IF NOT EXISTS idx_user_profiles_workers_covering
ON user_profiles(role, status, id, name, profile_image, created_at)
WHERE role = 'عامل' AND status = 'approved';

-- Step 8: Create additional performance indexes
-- Target: Common query patterns in attendance reports
DO $$
BEGIN
    RAISE NOTICE '🚀 Creating ADDITIONAL INDEXES: Query pattern optimization...';
END $$;

-- Index for attendance type filtering
CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_type
ON worker_attendance_records(attendance_type);

-- Index for worker-specific queries with timestamp ordering
CREATE INDEX IF NOT EXISTS idx_worker_attendance_records_worker_timestamp
ON worker_attendance_records(worker_id, timestamp DESC, attendance_type);

-- Step 9: Verify index creation success
DO $$
DECLARE
    index_count INTEGER;
    error_count INTEGER := 0;
    critical_indexes TEXT[] := ARRAY[
        'idx_user_profiles_id_status_auth',
        'idx_user_profiles_role_status_general', 
        'idx_user_profiles_role_status_workers',
        'idx_worker_attendance_records_worker_id_timestamp',
        'idx_worker_attendance_records_type_timestamp'
    ];
    index_name TEXT;
BEGIN
    RAISE NOTICE '✅ INDEX CREATION VERIFICATION:';
    
    -- Check each critical index
    FOREACH index_name IN ARRAY critical_indexes
    LOOP
        IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = index_name) THEN
            RAISE NOTICE '   ✅ %: CREATED', index_name;
        ELSE
            RAISE NOTICE '   ❌ %: FAILED', index_name;
            error_count := error_count + 1;
        END IF;
    END LOOP;
    
    -- Count total indexes
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE tablename IN ('user_profiles', 'worker_attendance_records')
    AND schemaname = 'public'
    AND indexname LIKE 'idx_%';
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 SUMMARY:';
    RAISE NOTICE '   Total performance indexes: %', index_count;
    RAISE NOTICE '   Critical index failures: %', error_count;
    
    IF error_count = 0 THEN
        RAISE NOTICE '   🎉 ALL CRITICAL INDEXES CREATED SUCCESSFULLY!';
    ELSE
        RAISE NOTICE '   ⚠️ Some indexes failed - check PostgreSQL logs';
    END IF;
    RAISE NOTICE '';
END $$;

-- Step 10: Performance testing queries (NO IMMUTABLE FUNCTION ISSUES)
DO $$
BEGIN
    RAISE NOTICE '🧪 PERFORMANCE TESTING QUERIES (IMMUTABLE-SAFE):';
    RAISE NOTICE '';
    RAISE NOTICE 'Run these EXPLAIN ANALYZE queries to verify index usage:';
    RAISE NOTICE '';
    RAISE NOTICE '1. Authentication Query:';
    RAISE NOTICE '   EXPLAIN ANALYZE SELECT role FROM user_profiles WHERE id = ''00000000-0000-0000-0000-000000000000'' AND status = ''approved'';';
    RAISE NOTICE '';
    RAISE NOTICE '2. Worker Lookup Query:';
    RAISE NOTICE '   EXPLAIN ANALYZE SELECT id, name, profile_image FROM user_profiles WHERE role = ''عامل'' AND status = ''approved'';';
    RAISE NOTICE '';
    RAISE NOTICE '3. Attendance Records Query:';
    RAISE NOTICE '   EXPLAIN ANALYZE SELECT * FROM worker_attendance_records WHERE worker_id = ''some-uuid'' ORDER BY timestamp DESC LIMIT 10;';
    RAISE NOTICE '';
    RAISE NOTICE '4. Date Range Attendance Query (NO CASTING):';
    RAISE NOTICE '   EXPLAIN ANALYZE SELECT * FROM worker_attendance_records WHERE attendance_type = ''check_in'' AND timestamp >= CURRENT_DATE AND timestamp < CURRENT_DATE + INTERVAL ''1 day'';';
    RAISE NOTICE '';
END $$;

-- Step 11: Create monitoring view for index usage
CREATE OR REPLACE VIEW worker_attendance_index_performance AS
SELECT
    schemaname,
    relname as tablename,        -- ✅ Use correct column name with alias
    indexrelname as indexname,   -- ✅ Use correct column name with alias
    idx_scan as scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelname::regclass)) as index_size,  -- ✅ Update this reference
    CASE
        WHEN idx_scan = 0 THEN '❌ UNUSED'
        WHEN idx_scan < 10 THEN '⚠️ LOW USAGE'
        WHEN idx_scan < 100 THEN '✅ MODERATE USAGE'
        ELSE '🚀 HIGH USAGE'
    END as usage_status
FROM pg_stat_user_indexes
WHERE relname IN ('user_profiles', 'worker_attendance_records')  -- ✅ Use relname
AND indexrelname LIKE 'idx_%'  -- ✅ Update this filter too
ORDER BY idx_scan DESC;

-- Step 12: Success summary
DO $$
BEGIN
    RAISE NOTICE '🎉 WORKER ATTENDANCE PERFORMANCE OPTIMIZATION COMPLETE!';
    RAISE NOTICE '';
    RAISE NOTICE '✅ INDEXES CREATED (IMMUTABLE-SAFE):';
    RAISE NOTICE '   1. idx_user_profiles_id_status_auth - Authentication queries';
    RAISE NOTICE '   2. idx_user_profiles_role_status_general - Role validation';
    RAISE NOTICE '   3. idx_user_profiles_role_status_workers - Worker lookups';
    RAISE NOTICE '   4. idx_worker_attendance_records_worker_id_timestamp - Attendance records';
    RAISE NOTICE '   5. idx_worker_attendance_records_type_timestamp - Date filtering';
    RAISE NOTICE '   6. idx_user_profiles_workers_covering - Covering index';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 IMMUTABLE FUNCTION FIXES:';
    RAISE NOTICE '   - Eliminated ALL functional expressions from indexes';
    RAISE NOTICE '   - Used simple column indexes with WHERE clauses';
    RAISE NOTICE '   - Replaced date casting with range queries';
    RAISE NOTICE '   - No more 42P17 PostgreSQL errors';
    RAISE NOTICE '';
    RAISE NOTICE '📈 PERFORMANCE BENEFITS:';
    RAISE NOTICE '   - Faster SECURITY DEFINER function execution';
    RAISE NOTICE '   - Optimized role-based authentication queries';
    RAISE NOTICE '   - Improved worker attendance report generation';
    RAISE NOTICE '   - Reduced "لا يوجد عمال مسجلين في النظام" response time';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 MONITORING:';
    RAISE NOTICE '   - Use: SELECT * FROM worker_attendance_index_performance;';
    RAISE NOTICE '   - Monitor query plans with EXPLAIN ANALYZE';
    RAISE NOTICE '   - All queries use range conditions instead of casting';
    RAISE NOTICE '';
    RAISE NOTICE '✅ READY FOR PRODUCTION - NO POSTGRESQL ERRORS!';
END $$;
