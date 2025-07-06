# Owner Dashboard Worker Tracking Debug Guide

## Issue Description
The Owner Dashboard's "Worker Tracking" (متابعة العمال) tab displays "لا يوجد عمال مسجلين" (No workers registered) instead of showing actual worker data, even though workers exist in the system.

## Root Cause Analysis
The issue is caused by **missing RLS (Row Level Security) policies** that prevent the owner role from accessing worker profiles in the `user_profiles` table. This is the same issue that affected the accountant role.

## Fix Implementation

### 1. Database RLS Policy Fix
Run the SQL script: `fix_owner_worker_access.sql`

```sql
-- This script creates the missing RLS policy for owners to view all user profiles
CREATE POLICY "Owner can view all profiles" ON public.user_profiles
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role = 'owner'
            AND status IN ('approved', 'active')
        )
    );
```

### 2. Enhanced Debug Logging
The Flutter code now includes comprehensive debug logging in `_loadWorkerTrackingData()`:

- ✅ Current user authentication status
- ✅ Current user profile verification  
- ✅ Direct database query testing
- ✅ Worker data processing steps
- ✅ Detailed error categorization
- ✅ Empty state debugging information

## Testing Steps

### Step 1: Apply Database Fix
1. Open Supabase SQL Editor
2. Run the contents of `fix_owner_worker_access.sql`
3. Verify policies are created successfully

### Step 2: Test Database Access
Run this query in Supabase SQL Editor as an owner user:
```sql
SELECT * FROM test_owner_worker_access();
```

Expected results:
- ✅ Current User Role: PASS - User is owner
- ✅ Worker Profiles Access: PASS - Can access worker profiles
- ✅ Worker Tasks Access: PASS - Can access worker tasks
- ✅ Worker Rewards Access: PASS - Can access worker rewards

### Step 3: Test Flutter App
1. Login as an owner user
2. Navigate to: Owner Dashboard → Worker Tracking Tab
3. Check Flutter console for debug messages
4. Look for these key debug outputs:

```
🔄 Loading worker tracking data...
🔐 Current user ID: [user-id]
👤 Current user profile: {role: owner, status: approved}
🔍 Attempting to fetch workers...
📊 Workers loaded: [X]
👷 Worker: [Name] ([Email]) - Status: [status], Approved: [true/false]
✅ Worker tracking data loaded successfully
```

## Troubleshooting

### Issue: "RLS policy violation"
**Solution:** Ensure the RLS policy fix was applied correctly
```sql
-- Check if policy exists
SELECT * FROM pg_policies 
WHERE tablename = 'user_profiles' 
AND policyname = 'Owner can view all profiles';
```

### Issue: "No workers found - checking database access"
**Possible causes:**
1. No workers with status 'approved' or 'active' exist
2. RLS policy still blocking access
3. Owner user doesn't have proper status

**Debug queries:**
```sql
-- Check if workers exist (run as admin)
SELECT COUNT(*) FROM user_profiles WHERE role = 'worker';

-- Test owner access (run as owner)
SELECT COUNT(*) FROM user_profiles WHERE role = 'worker';

-- Check owner user status
SELECT role, status FROM user_profiles WHERE id = auth.uid();
```

### Issue: "Direct worker query failed"
**This indicates RLS policy issues**

**Solution:** Verify the owner RLS policy was created:
```sql
SELECT policyname, qual FROM pg_policies 
WHERE tablename = 'user_profiles' 
AND policyname LIKE '%owner%' OR policyname LIKE '%Owner%';
```

## Expected Behavior After Fix

### Successful Loading
1. **Loading State:** Shows appropriate loading indicators
2. **Success State:** Displays comprehensive worker tracking with:
   - List of all registered workers
   - Worker task assignments and completion status
   - Worker performance metrics and statistics
   - Professional dark theme styling
3. **Debug Logs:** Clear console output showing successful data loading

### Worker Tracking Features
- **Worker List:** All approved/active workers displayed
- **Task Statistics:** Assigned, in-progress, and completed tasks per worker
- **Performance Metrics:** Completion rates and productivity scores
- **Rewards Tracking:** Worker rewards and incentives
- **Real-time Data:** Live updates from Supabase database

## Debug Console Output Examples

### Successful Load:
```
🔄 Loading worker tracking data...
🔐 Current user ID: 12345-abcd-6789-efgh
👤 Current user profile: {id: 12345, name: مالك الشركة, role: owner, status: approved}
🔍 Attempting to fetch workers...
📊 Workers loaded: 8
👷 Worker: أحمد محمد (ahmed@example.com) - Status: approved, Approved: true
👷 Worker: سارة أحمد (sara@example.com) - Status: active, Approved: true
👷 Worker: محمد علي (mohamed@example.com) - Status: approved, Approved: true
✅ Worker tracking data loaded successfully
📊 Final Workers: 8
📋 Tasks: 25
🎁 Rewards: 12
```

### Error Examples:
```
❌ Error loading worker tracking data: RLS policy violation
📍 Stack trace: [detailed stack trace]
🔍 Debug - Total workers in provider: 0
🔍 Debug - Approved workers: 0
❌ Direct worker query failed: permission denied for table user_profiles
```

### Empty State Debug:
```
🔍 Debug - Total workers in provider: 0
🔍 Debug - Approved workers: 0
⚠️ No workers found - checking database access...
❌ Direct worker query failed: RLS policy violation
```

## Comparison with Admin Dashboard

The Admin Dashboard works because it has the proper RLS policy:
```sql
-- Admin policy (working)
CREATE POLICY "Admin can view all profiles" ON public.user_profiles
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );
```

The Owner Dashboard needs the same type of policy:
```sql
-- Owner policy (needed)
CREATE POLICY "Owner can view all profiles" ON public.user_profiles
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid() AND role = 'owner'
        )
    );
```

## Verification Checklist

- [ ] SQL script executed successfully
- [ ] RLS policies created and visible in Supabase
- [ ] Test function returns PASS for all tests
- [ ] Flutter app shows debug logs without RLS errors
- [ ] Worker data displays correctly in Owner Dashboard
- [ ] Worker tracking features work properly
- [ ] Performance metrics calculate correctly
- [ ] Task assignments display properly
- [ ] Rewards tracking functions correctly

## Files Modified

1. `lib/screens/owner/owner_dashboard.dart` - Enhanced debugging in `_loadWorkerTrackingData()` and `_buildEmptyWorkersCard()`
2. `fix_owner_worker_access.sql` - RLS policy fix for owner role
3. `OWNER_WORKER_TRACKING_DEBUG_GUIDE.md` - This debug guide

## Support Information

If issues persist after following this guide:

1. **Check Supabase Logs:** Look for RLS violations or query errors
2. **Verify User Status:** Ensure owner user has 'approved' or 'active' status
3. **Test with Admin:** Verify worker data exists by testing with admin user
4. **Console Logs:** Share Flutter debug console output for analysis
5. **Database State:** Verify worker data exists in database
6. **RLS Policies:** Confirm all policies are created and active
