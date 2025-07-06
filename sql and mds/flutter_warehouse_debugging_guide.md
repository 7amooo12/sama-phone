# 🔍 Flutter Warehouse Debugging Guide

## **Step 1: Run Database Diagnostic**

First, run the `warehouse_troubleshooting_diagnostic.sql` script in Supabase SQL Editor to verify:
- ✅ RLS policies are correctly applied
- ✅ Database data is accessible
- ✅ User permissions are working

## **Step 2: Flutter App Debugging Steps**

### **2.1 Check Authentication State**

Add this debug code to your warehouse service or provider:

```dart
// In WarehouseService.getWarehouses() method
Future<List<WarehouseModel>> getWarehouses({bool activeOnly = true}) async {
  try {
    // DEBUG: Check authentication
    final currentUser = Supabase.instance.client.auth.currentUser;
    print('🔍 DEBUG - Current User: ${currentUser?.id}');
    print('🔍 DEBUG - User Email: ${currentUser?.email}');
    
    // DEBUG: Check user profile
    final userProfile = await Supabase.instance.client
        .from('user_profiles')
        .select('id, email, role, status')
        .eq('id', currentUser!.id)
        .single();
    print('🔍 DEBUG - User Profile: $userProfile');
    
    // DEBUG: Test direct warehouse query
    final directQuery = await Supabase.instance.client
        .from('warehouses')
        .select('*');
    print('🔍 DEBUG - Direct Warehouse Query Result: ${directQuery.length} warehouses');
    print('🔍 DEBUG - Warehouse Data: $directQuery');
    
    // Your existing code continues...
  } catch (e) {
    print('❌ DEBUG - Error in getWarehouses: $e');
    rethrow;
  }
}
```

### **2.2 Check Supabase Client Configuration**

Verify your Supabase client is properly configured:

```dart
// Check if RLS is being bypassed (should be false for security)
print('🔍 DEBUG - Supabase URL: ${Supabase.instance.client.supabaseUrl}');
print('🔍 DEBUG - Auth Headers: ${Supabase.instance.client.headers}');
```

### **2.3 Test Raw Supabase Queries**

Add this test function to your warehouse service:

```dart
Future<void> debugWarehouseAccess() async {
  try {
    print('🔍 === WAREHOUSE DEBUG TEST ===');
    
    // Test 1: Check authentication
    final user = Supabase.instance.client.auth.currentUser;
    print('User ID: ${user?.id}');
    print('User Email: ${user?.email}');
    
    // Test 2: Check user profile
    final profile = await Supabase.instance.client
        .from('user_profiles')
        .select('*')
        .eq('id', user!.id)
        .single();
    print('User Profile: $profile');
    
    // Test 3: Raw warehouse query
    final warehouses = await Supabase.instance.client
        .from('warehouses')
        .select('*');
    print('Warehouses Count: ${warehouses.length}');
    print('Warehouses Data: $warehouses');
    
    // Test 4: Raw inventory query
    final inventory = await Supabase.instance.client
        .from('warehouse_inventory')
        .select('*');
    print('Inventory Count: ${inventory.length}');
    print('Inventory Data: $inventory');
    
    // Test 5: Check specific warehouse with inventory
    final warehouseWithInventory = await Supabase.instance.client
        .from('warehouses')
        .select('''
          *,
          warehouse_inventory(*)
        ''');
    print('Warehouse with Inventory: $warehouseWithInventory');
    
  } catch (e) {
    print('❌ Debug Error: $e');
  }
}
```

### **2.4 Check Provider State**

Add debug prints to your WarehouseProvider:

```dart
// In WarehouseProvider.loadWarehouses()
Future<void> loadWarehouses({bool forceRefresh = false}) async {
  print('🔍 DEBUG - loadWarehouses called, forceRefresh: $forceRefresh');
  print('🔍 DEBUG - Current warehouses count: ${_warehouses.length}');
  print('🔍 DEBUG - Is loading: $_isLoadingWarehouses');
  print('🔍 DEBUG - Error: $_error');
  
  // Your existing code...
  
  try {
    final warehouses = await _warehouseService.getWarehouses();
    print('🔍 DEBUG - Service returned ${warehouses.length} warehouses');
    _warehouses = warehouses;
    // Continue with existing code...
  } catch (e) {
    print('❌ DEBUG - Provider error: $e');
    _error = 'خطأ في تحميل المخازن: $e';
  }
}
```

## **Step 3: UI Component Debugging**

### **3.1 Check Widget State**

Add debug prints to your warehouse UI components:

```dart
// In UnifiedWarehouseInterface or warehouse dashboard
Widget _buildWarehousesContent(WarehouseProvider provider) {
  print('🔍 DEBUG - Building warehouses content');
  print('🔍 DEBUG - Is loading: ${provider.isLoadingWarehouses}');
  print('🔍 DEBUG - Error: ${provider.error}');
  print('🔍 DEBUG - Warehouses count: ${provider.warehouses.length}');
  print('🔍 DEBUG - Warehouses data: ${provider.warehouses}');
  
  if (provider.isLoadingWarehouses) {
    print('🔍 DEBUG - Showing loading state');
    return _buildWarehousesLoadingState();
  }

  if (provider.error != null) {
    print('🔍 DEBUG - Showing error state: ${provider.error}');
    return _buildWarehousesErrorState(provider.error!, provider);
  }

  if (provider.warehouses.isEmpty) {
    print('🔍 DEBUG - Showing empty state');
    return _buildEmptyWarehousesState();
  }

  print('🔍 DEBUG - Showing warehouses grid with ${provider.warehouses.length} items');
  return _buildWarehousesGrid(provider.warehouses);
}
```

## **Step 4: Systematic Testing by Role**

### **4.1 Admin Role Testing**
1. Login as admin user
2. Navigate to Admin Dashboard → Warehouses tab
3. Check console logs for debug output
4. Verify API calls in network tab

### **4.2 Owner Role Testing**
1. Login as owner user
2. Navigate to Owner Dashboard → Warehouses tab
3. Check console logs for debug output
4. Compare with admin results

### **4.3 Accountant Role Testing**
1. Login as accountant user
2. Navigate to Accountant Dashboard → Warehouses tab
3. Check console logs for debug output
4. Compare with previous roles

### **4.4 Warehouse Manager Testing**
1. Login as warehouse manager user
2. Navigate to Warehouse Manager Dashboard
3. Check if data appears (this should work based on your description)
4. Compare implementation differences

## **Step 5: Common Issues and Solutions**

### **Issue 1: Authentication Context Lost**
```dart
// Solution: Ensure user is authenticated before making calls
final user = Supabase.instance.client.auth.currentUser;
if (user == null) {
  throw Exception('User not authenticated');
}
```

### **Issue 2: RLS Policy Not Applied**
```dart
// Solution: Verify headers include authentication
final response = await Supabase.instance.client
    .from('warehouses')
    .select('*')
    .withConverter((data) => data); // This ensures RLS is applied
```

### **Issue 3: Provider Not Notifying Listeners**
```dart
// Solution: Ensure notifyListeners() is called
_warehouses = warehouses;
notifyListeners(); // Make sure this is called
```

### **Issue 4: UI Not Rebuilding**
```dart
// Solution: Use Consumer widget properly
Consumer<WarehouseProvider>(
  builder: (context, provider, child) {
    // Make sure this rebuilds when provider changes
    return _buildWarehousesContent(provider);
  },
)
```

## **Step 6: Quick Test Implementation**

Add this test button to your dashboard for quick testing:

```dart
ElevatedButton(
  onPressed: () async {
    final warehouseService = WarehouseService();
    await warehouseService.debugWarehouseAccess();
  },
  child: Text('🔍 Debug Warehouse Access'),
)
```

## **Next Steps**

1. **Run the SQL diagnostic** first to confirm database access
2. **Add debug prints** to your Flutter code
3. **Test each user role** systematically
4. **Check console logs** for specific error messages
5. **Compare working vs non-working roles** to identify differences

The debug output will help us identify exactly where the data flow is breaking!
