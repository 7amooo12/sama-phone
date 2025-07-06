# 🔧 WAREHOUSE ACCESS TROUBLESHOOTING GUIDE

## 🚨 IMMEDIATE FIX (Choose One Option)

### Option 1: Function-Based Fix (Recommended)
If you got the "function does not exist" error, run this updated script:
```sql
-- File: sql/immediate_warehouse_access_fix.sql (updated version)
```

### Option 2: Simple Fix (If Option 1 Fails)
If the function approach still fails, use the simple approach:
```sql
-- File: sql/simple_warehouse_access_fix.sql
```

## 📋 Step-by-Step Execution

### Step 1: Choose Your Approach

**For Function-Based Fix:**
1. Open Supabase SQL Editor
2. Copy and paste the entire content of `sql/immediate_warehouse_access_fix.sql`
3. Run the script
4. Look for success messages in the output

**For Simple Fix:**
1. Open Supabase SQL Editor
2. Copy and paste the entire content of `sql/simple_warehouse_access_fix.sql`
3. Run the script
4. This will disable RLS entirely (less secure but immediate fix)

### Step 2: Test Access

**In Supabase SQL Editor:**
```sql
-- Test if you can see warehouse data
SELECT COUNT(*) FROM warehouses;
SELECT COUNT(*) FROM warehouse_inventory;
SELECT COUNT(*) FROM warehouse_transactions;
SELECT COUNT(*) FROM warehouse_requests;
```

**In Flutter App:**
1. Restart your Flutter application
2. Login with different user roles (admin, owner, accountant, warehouseManager)
3. Navigate to warehouse screens
4. Check if data is now visible

### Step 3: Verify Fix

**Expected Results:**
- ✅ Admin accounts: Can see all warehouse data
- ✅ Owner accounts: Can see all warehouse data
- ✅ Accountant accounts: Can see all warehouse data
- ✅ Warehouse Manager accounts: Can see all warehouse data (should continue working)

## 🔍 Diagnostic Commands

### Check Current User Context
```sql
SELECT 
  auth.uid() as current_user_id,
  up.email,
  up.name,
  up.role,
  up.status
FROM user_profiles up
WHERE up.id = auth.uid();
```

### Check RLS Status
```sql
SELECT 
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests')
  AND schemaname = 'public';
```

### Check Current Policies
```sql
SELECT 
  tablename,
  policyname,
  cmd as operation
FROM pg_policies 
WHERE tablename IN ('warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests')
ORDER BY tablename, cmd;
```

## 🛠️ Troubleshooting Common Issues

### Issue 1: "Function does not exist" Error
**Solution:** Use the simple fix approach (Option 2) which doesn't rely on functions.

### Issue 2: Still No Access After Running Scripts
**Check:**
1. User is properly authenticated in Flutter app
2. User has `status = 'approved'` in user_profiles table
3. User has appropriate role (admin, owner, accountant, warehouseManager)

**Fix User Status:**
```sql
-- Update user status to approved (replace with actual user ID)
UPDATE user_profiles 
SET status = 'approved' 
WHERE id = 'USER_ID_HERE';
```

### Issue 3: Some Users Have Access, Others Don't
**Check User Profiles:**
```sql
-- Check all user profiles
SELECT id, email, name, role, status 
FROM user_profiles 
ORDER BY role;
```

**Fix Roles:**
```sql
-- Update user role (replace with actual user ID and desired role)
UPDATE user_profiles 
SET role = 'admin', status = 'approved' 
WHERE id = 'USER_ID_HERE';
```

### Issue 4: Flutter App Still Shows Empty Data
**Solutions:**
1. **Restart Flutter App:** Hot reload may not be enough
2. **Clear App Cache:** Uninstall and reinstall the app
3. **Check Logs:** Look for error messages in Flutter console
4. **Test Direct Database Access:** Use Supabase dashboard to verify data exists

## 🔄 Recovery Steps

### If Something Goes Wrong
```sql
-- Emergency: Disable all RLS to restore access
ALTER TABLE warehouses DISABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_requests DISABLE ROW LEVEL SECURITY;
```

### To Re-enable Security Later
```sql
-- Re-enable RLS when ready
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_requests ENABLE ROW LEVEL SECURITY;

-- Then create appropriate policies
```

## 📞 Support Information

### What to Check Before Asking for Help
1. ✅ Ran one of the SQL fix scripts
2. ✅ Restarted Flutter application
3. ✅ Verified user has approved status
4. ✅ Tested with multiple user roles
5. ✅ Checked Supabase SQL editor for direct data access

### Information to Provide
- Which SQL script you ran (Option 1 or Option 2)
- Any error messages from SQL execution
- User role and status from user_profiles table
- Flutter console error messages
- Whether warehouse manager accounts still work

## 🎯 Quick Success Test

**Run this in Supabase SQL Editor:**
```sql
-- Quick test - should return data if fix worked
SELECT 
  'SUCCESS TEST' as test,
  COUNT(*) as warehouse_count,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ FIX SUCCESSFUL'
    ELSE '❌ STILL ISSUES'
  END as result
FROM warehouses;
```

**Test in Flutter App:**
1. Login as admin/owner/accountant
2. Navigate to warehouse section
3. Should see warehouse data and inventory

If you see warehouse data in both tests, the fix was successful! 🎉
