# 🔧 Recovery Guide for User hima@sama.com Database Access Issues

## **Problem Summary**
User `hima@sama.com` (UID: `4ac083bc-3e05-4456-8579-0877d2627b15`) lost database access after table recreation incident on June 16, 2025. The "Last signed in" timestamp corresponds exactly to when the database issues occurred.

## **Root Cause Analysis**
1. **Table Recreation Impact**: Database tables were recreated, potentially losing RLS policies and user permissions
2. **Authentication Session Issues**: Session isolation between services preventing proper authentication
3. **RLS Policy Corruption**: Row Level Security policies may have been misconfigured during restoration
4. **User Profile Inconsistencies**: User profile data may be incomplete or corrupted

## **Step-by-Step Recovery Process**

### **Phase 1: Database Diagnosis**
1. **Run Diagnostic Script**:
   ```sql
   -- Execute in Supabase SQL Editor
   \i sql/diagnose_user_hima_sama.sql
   ```
   This will check:
   - User existence in auth.users
   - User profile completeness
   - Table access permissions
   - RLS policy status
   - Database function availability

### **Phase 2: Database Access Restoration**
1. **Execute Comprehensive Fix**:
   ```sql
   -- Execute in Supabase SQL Editor
   \i sql/fix_user_hima_sama_access.sql
   ```
   This will:
   - Ensure user profile exists with correct role (accountant)
   - Fix user_profiles RLS policies
   - Restore warehouse table access
   - Create missing warehouse-related tables if needed
   - Set up proper RLS policies for all warehouse tables

### **Phase 3: Flutter App Authentication Fix**
1. **Updated WarehouseService**: 
   - Now uses `AuthStateManager` for consistent session management
   - Eliminates session isolation issues
   - Provides better error handling and diagnostics

2. **Enhanced Diagnostic Tools**:
   - `AuthSessionTest.testHimaSamaUserAccess()` - Specific test for this user
   - `AuthSessionTestWidget` - UI for testing authentication and database access
   - Comprehensive logging for troubleshooting

### **Phase 4: Verification and Testing**

#### **In Supabase Dashboard:**
1. **Verify User Profile**:
   ```sql
   SELECT * FROM user_profiles 
   WHERE id = '4ac083bc-3e05-4456-8579-0877d2627b15';
   ```
   Expected result:
   - Role: `accountant`
   - Status: `approved`
   - Email: `hima@sama.com`

2. **Test Warehouse Access**:
   ```sql
   -- Set user context
   SET LOCAL ROLE authenticated;
   SET LOCAL "request.jwt.claims" TO '{"sub": "4ac083bc-3e05-4456-8579-0877d2627b15"}';
   
   -- Test queries
   SELECT COUNT(*) FROM warehouses;
   SELECT COUNT(*) FROM warehouse_inventory;
   ```

#### **In Flutter App:**
1. **Use Debug Tools**:
   - Add `AuthSessionTestWidget` to any screen
   - Run "اختبار hima@sama.com" button
   - Verify all tests pass

2. **Test Warehouse Functionality**:
   - Navigate to AccountantDashboard
   - Go to Warehouse tab
   - Verify warehouses load correctly
   - Test warehouse operations

## **Expected Results After Fix**

### **Database Level:**
- ✅ User profile exists with `accountant` role and `approved` status
- ✅ All warehouse tables accessible (warehouses, warehouse_inventory, warehouse_requests, warehouse_transactions)
- ✅ RLS policies properly configured for accountant role access
- ✅ No permission errors when querying warehouse data

### **Flutter App Level:**
- ✅ AuthStateManager returns valid user session
- ✅ WarehouseService successfully loads warehouses
- ✅ AccountantDashboard warehouse tab displays data
- ✅ All warehouse management features functional

### **Specific Metrics:**
- **Warehouse Count**: Should load 4 warehouses (المعرض, جججج, جديد, دكتور)
- **Inventory Items**: Should show 19 inventory items with total quantity 85
- **Authentication**: Consistent user ID across all services
- **Session**: No session isolation issues

## **Troubleshooting Common Issues**

### **Issue 1: "No warehouses found"**
**Cause**: RLS policies blocking access
**Solution**: Re-run the fix script, ensure user has `accountant` role

### **Issue 2: "Authentication failed"**
**Cause**: Session isolation between services
**Solution**: Use AuthStateManager consistently, restart app if needed

### **Issue 3: "Permission denied"**
**Cause**: User profile missing or incorrect role
**Solution**: Verify user profile exists with correct role and status

### **Issue 4: "Table does not exist"**
**Cause**: Tables not recreated after incident
**Solution**: Run the fix script which includes CREATE TABLE IF NOT EXISTS statements

## **Monitoring and Maintenance**

### **Regular Checks:**
1. **Weekly**: Verify user can access warehouse data
2. **After any database changes**: Re-run diagnostic script
3. **Before major releases**: Test all authentication flows

### **Logging:**
- Monitor app logs for authentication errors
- Check Supabase logs for RLS policy violations
- Use diagnostic tools for proactive issue detection

## **Contact Information**
If issues persist after following this guide:
1. Check app logs for specific error messages
2. Run diagnostic tools and share results
3. Verify database state using provided SQL queries
4. Consider session refresh or app restart

## **Files Created/Modified**
- `sql/diagnose_user_hima_sama.sql` - Diagnostic script
- `sql/fix_user_hima_sama_access.sql` - Comprehensive fix script
- `lib/services/warehouse_service.dart` - Updated to use AuthStateManager
- `lib/utils/auth_session_test.dart` - Enhanced with specific user test
- `lib/widgets/debug/auth_session_test_widget.dart` - UI testing tool

This recovery process should restore full functionality for user `hima@sama.com` and prevent similar issues in the future.
