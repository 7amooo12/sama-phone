# Warehouse Inventory Deduction Debugging Guide

## Problem Description

The warehouse manager's dispatch processing page is experiencing errors when attempting to complete product items. The automatic inventory deduction system fails when warehouse managers try to mark dispatch request items as complete, affecting both single-warehouse and multi-warehouse dispatch requests.

## Debugging Tools Created

### 1. SQL Debugging Script (`debug_inventory_deduction.sql`)

**Purpose**: Tests the database layer step by step to identify where the issue occurs.

**How to use**:
1. Open Supabase SQL Editor
2. Copy and paste the entire script
3. Run it section by section or all at once
4. Check the output for any ❌ errors

**What it tests**:
- Database function existence
- User authentication and authorization
- Available inventory data
- `search_product_globally` function
- `deduct_inventory_with_validation` function
- Recent transactions and audit logs
- RLS policies

### 2. Flutter Inventory Deduction Tester (`lib/utils/inventory_deduction_tester.dart`)

**Purpose**: Tests the entire inventory deduction system from the Flutter app side.

**How to use**:
```dart
// Run comprehensive test
final results = await InventoryDeductionTester.runComprehensiveTest();
print(results['summary']);

// Quick test for specific product
final success = await InventoryDeductionTester.quickDeductionTest(
  productId: 'your-product-id',
  warehouseId: 'your-warehouse-id',
  quantity: 1,
  performedBy: 'user-id',
);
```

**What it tests**:
- Database connection
- User authentication and permissions
- Database functions availability
- Product search functionality
- Direct database function calls
- Full service layer integration

### 3. Enhanced Quick Test Button (`lib/widgets/warehouse/quick_warehouse_test_button.dart`)

**Purpose**: Provides an easy-to-access test button in the warehouse manager interface.

**How to use**:
1. The button should already be available in warehouse screens
2. Look for a red "Test Warehouse" floating action button
3. Tap it to run all tests including inventory deduction
4. Review the detailed results dialog

**What it shows**:
- Authentication status
- User profile and permissions
- Database access tests
- **NEW**: Comprehensive inventory deduction system test
- Service layer functionality
- Summary of all issues found

## Step-by-Step Debugging Process

### Step 1: Run SQL Debug Script

1. Open Supabase SQL Editor
2. Run `debug_inventory_deduction.sql`
3. Look for any ❌ errors in the output
4. Common issues to check:
   - Function doesn't exist
   - User not authenticated
   - User role not authorized
   - No inventory data available
   - RLS policies blocking access

### Step 2: Test in Flutter App

1. Open the warehouse manager dashboard
2. Look for the red "Test Warehouse" button (usually floating)
3. Tap the button and wait for results
4. Check the "نظام خصم المخزون" (Inventory Deduction System) section
5. Review any errors in the detailed results

### Step 3: Check Logs

1. Monitor Flutter console logs during testing
2. Look for AppLogger messages with these prefixes:
   - `🔄` - Process starting
   - `✅` - Success
   - `❌` - Error
   - `⚠️` - Warning

### Step 4: Test Real Dispatch Processing

1. Create a test dispatch request
2. Try to mark items as complete
3. Monitor logs for specific error messages
4. Compare with test results to identify discrepancies

## Common Issues and Solutions

### Issue 1: Database Function Missing
**Symptoms**: Function does not exist errors
**Solution**: Run the `global_inventory_database_functions.sql` script

### Issue 2: User Not Authorized
**Symptoms**: Permission denied or unauthorized errors
**Solution**: Check user role in `user_profiles` table, ensure it's one of: admin, owner, warehouseManager, accountant

### Issue 3: No Inventory Data
**Symptoms**: No products found for testing
**Solution**: Add some test inventory data or check existing data

### Issue 4: RLS Policies Blocking Access
**Symptoms**: Empty results despite data existing
**Solution**: Review and fix RLS policies on warehouse tables

### Issue 5: Service Layer Integration Issues
**Symptoms**: Database tests pass but Flutter tests fail
**Solution**: Check service layer code for proper error handling and parameter passing

## Expected Test Results

### Successful Test Output

```
✅ Database Connection: Working
✅ User Authentication: Authorized user
✅ Database Functions: All functions exist
✅ Product Search: Found products successfully
✅ Direct Database Call: Deduction successful
✅ Service Layer: Full integration working
✅ Inventory Deduction System: 6/6 tests passed
```

### Failed Test Output

```
❌ Database Functions: deduct_inventory_with_validation missing
⚠️ User Authentication: User role not authorized
❌ Service Layer: Integration failed
❌ Inventory Deduction System: 2/6 tests passed
```

## Next Steps After Debugging

1. **If SQL tests pass but Flutter tests fail**: Focus on service layer integration
2. **If database function tests fail**: Re-run database migration scripts
3. **If authentication tests fail**: Check user roles and permissions
4. **If all tests pass but real usage fails**: Add more detailed logging to the actual dispatch processing code

## Files Modified/Created

- `debug_inventory_deduction.sql` - SQL debugging script
- `lib/utils/inventory_deduction_tester.dart` - Flutter testing utility
- `lib/utils/inventory_deduction_debugger.dart` - Enhanced debugging utility
- `lib/widgets/warehouse/quick_warehouse_test_button.dart` - Enhanced test button
- `test_inventory_deduction_debug.dart` - Standalone test application

## Monitoring and Maintenance

1. Run these tests regularly to ensure system health
2. Add new test cases as new features are added
3. Monitor the audit logs for deduction patterns
4. Keep the debugging tools updated with system changes

## Contact and Support

If the debugging tools reveal issues that cannot be resolved:

1. Capture the full test output
2. Include relevant log messages
3. Note the specific error messages and codes
4. Provide context about when the issue occurs

This comprehensive debugging approach should identify exactly where the inventory deduction system is failing and provide clear guidance on how to fix it.
