/// تطبيق اختبار شامل لتشخيص مشاكل خصم المخزون
/// Comprehensive Inventory Deduction Debug Test Application

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/dispatch_product_processing_model.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';
import 'package:smartbiztracker_new/services/intelligent_inventory_deduction_service.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase (you'll need to add your credentials)
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  runApp(InventoryDeductionDebugApp());
}

class InventoryDeductionDebugApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Deduction Debug',
      home: InventoryDeductionDebugScreen(),
    );
  }
}

class InventoryDeductionDebugScreen extends StatefulWidget {
  @override
  _InventoryDeductionDebugScreenState createState() => _InventoryDeductionDebugScreenState();
}

class _InventoryDeductionDebugScreenState extends State<InventoryDeductionDebugScreen> {
  final IntelligentInventoryDeductionService _deductionService = IntelligentInventoryDeductionService();
  final GlobalInventoryService _globalService = GlobalInventoryService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String _testResults = '';
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Deduction Debug'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isRunning ? null : _runComprehensiveTest,
              child: Text(_isRunning ? 'Running Tests...' : 'Run Comprehensive Debug Test'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _testResults.isEmpty ? 'Click the button to run tests' : _testResults,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runComprehensiveTest() async {
    setState(() {
      _isRunning = true;
      _testResults = '';
    });

    try {
      await _addTestResult('🔄 بدء الاختبار الشامل لخصم المخزون...\n');
      
      // Test 1: Database Connection
      await _testDatabaseConnection();
      
      // Test 2: User Authentication
      await _testUserAuthentication();
      
      // Test 3: Database Function Existence
      await _testDatabaseFunctionExistence();
      
      // Test 4: Sample Product Search
      await _testProductSearch();
      
      // Test 5: Database Function Direct Call
      await _testDatabaseFunctionDirectCall();
      
      // Test 6: Full Deduction Flow
      await _testFullDeductionFlow();
      
      await _addTestResult('\n✅ اكتمل الاختبار الشامل');
      
    } catch (e) {
      await _addTestResult('\n❌ خطأ في الاختبار: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _addTestResult(String result) async {
    setState(() {
      _testResults += result + '\n';
    });
    AppLogger.info(result);
    await Future.delayed(Duration(milliseconds: 100)); // Allow UI to update
  }

  Future<void> _testDatabaseConnection() async {
    await _addTestResult('\n📡 اختبار الاتصال بقاعدة البيانات...');
    
    try {
      final response = await _supabase
          .from('warehouses')
          .select('id, name')
          .limit(1);
      
      await _addTestResult('✅ الاتصال بقاعدة البيانات يعمل');
      await _addTestResult('   عدد المخازن المتاحة: ${response.length}');
      
      if (response.isNotEmpty) {
        await _addTestResult('   مثال مخزن: ${response.first['name']}');
      }
    } catch (e) {
      await _addTestResult('❌ فشل الاتصال بقاعدة البيانات: $e');
    }
  }

  Future<void> _testUserAuthentication() async {
    await _addTestResult('\n👤 اختبار المصادقة...');
    
    try {
      final user = _supabase.auth.currentUser;
      
      if (user == null) {
        await _addTestResult('⚠️ لا يوجد مستخدم مسجل دخول');
        return;
      }
      
      await _addTestResult('✅ المستخدم مسجل دخول: ${user.id}');
      
      // Check user profile
      final profile = await _supabase
          .from('user_profiles')
          .select('id, role, status, email')
          .eq('id', user.id)
          .single();
      
      await _addTestResult('   الدور: ${profile['role']}');
      await _addTestResult('   الحالة: ${profile['status']}');
      await _addTestResult('   البريد: ${profile['email']}');
      
      if (profile['status'] != 'approved') {
        await _addTestResult('⚠️ المستخدم غير موافق عليه');
      }
      
      if (!['admin', 'owner', 'warehouseManager', 'accountant'].contains(profile['role'])) {
        await _addTestResult('⚠️ دور المستخدم لا يسمح بخصم المخزون');
      }
      
    } catch (e) {
      await _addTestResult('❌ خطأ في فحص المصادقة: $e');
    }
  }

  Future<void> _testDatabaseFunctionExistence() async {
    await _addTestResult('\n🔧 اختبار وجود دوال قاعدة البيانات...');
    
    try {
      // Test deduct_inventory_with_validation function
      final functions = await _supabase
          .rpc('deduct_inventory_with_validation', params: {
            'p_warehouse_id': 'test-warehouse-id',
            'p_product_id': 'test-product-id',
            'p_quantity': 0, // Zero quantity to avoid actual deduction
            'p_performed_by': 'test-user',
            'p_reason': 'Test function existence',
          });
      
      await _addTestResult('✅ دالة deduct_inventory_with_validation موجودة');
      await _addTestResult('   استجابة الاختبار: $functions');
      
    } catch (e) {
      if (e.toString().contains('function') && e.toString().contains('does not exist')) {
        await _addTestResult('❌ دالة deduct_inventory_with_validation غير موجودة');
      } else {
        await _addTestResult('✅ دالة deduct_inventory_with_validation موجودة (خطأ متوقع: $e)');
      }
    }
    
    try {
      // Test search_product_globally function
      final searchResult = await _supabase
          .rpc('search_product_globally', params: {
            'p_product_id': 'test-product-id',
            'p_requested_quantity': 1,
          });
      
      await _addTestResult('✅ دالة search_product_globally موجودة');
      await _addTestResult('   نتائج البحث: ${searchResult.length} مخزن');
      
    } catch (e) {
      if (e.toString().contains('function') && e.toString().contains('does not exist')) {
        await _addTestResult('❌ دالة search_product_globally غير موجودة');
      } else {
        await _addTestResult('✅ دالة search_product_globally موجودة (خطأ متوقع: $e)');
      }
    }
  }

  Future<void> _testProductSearch() async {
    await _addTestResult('\n🔍 اختبار البحث عن المنتجات...');
    
    try {
      // Get a real product from the database
      final products = await _supabase
          .from('warehouse_inventory')
          .select('product_id, quantity, warehouse_id')
          .gt('quantity', 0)
          .limit(1);
      
      if (products.isEmpty) {
        await _addTestResult('⚠️ لا توجد منتجات في المخزون للاختبار');
        return;
      }
      
      final testProduct = products.first;
      final productId = testProduct['product_id'];
      final availableQuantity = testProduct['quantity'];
      
      await _addTestResult('   منتج الاختبار: $productId');
      await _addTestResult('   الكمية المتاحة: $availableQuantity');
      
      // Test global search
      final searchResult = await _globalService.searchProductGlobally(
        productId: productId,
        requestedQuantity: 1,
      );
      
      await _addTestResult('✅ البحث العالمي نجح');
      await _addTestResult('   إجمالي المتاح: ${searchResult.totalAvailableQuantity}');
      await _addTestResult('   يمكن التلبية: ${searchResult.canFulfill}');
      await _addTestResult('   عدد المخازن: ${searchResult.availableWarehouses.length}');
      
    } catch (e) {
      await _addTestResult('❌ فشل البحث عن المنتجات: $e');
    }
  }

  Future<void> _testDatabaseFunctionDirectCall() async {
    await _addTestResult('\n⚡ اختبار استدعاء دالة قاعدة البيانات مباشرة...');
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        await _addTestResult('⚠️ تخطي الاختبار - لا يوجد مستخدم مسجل دخول');
        return;
      }
      
      // Get a real warehouse and product
      final inventory = await _supabase
          .from('warehouse_inventory')
          .select('warehouse_id, product_id, quantity')
          .gt('quantity', 5) // Ensure we have enough stock
          .limit(1);
      
      if (inventory.isEmpty) {
        await _addTestResult('⚠️ لا توجد منتجات كافية للاختبار');
        return;
      }
      
      final testItem = inventory.first;
      
      await _addTestResult('   اختبار خصم 1 قطعة من:');
      await _addTestResult('   المخزن: ${testItem['warehouse_id']}');
      await _addTestResult('   المنتج: ${testItem['product_id']}');
      await _addTestResult('   الكمية المتاحة: ${testItem['quantity']}');
      
      // Call the database function directly
      final result = await _supabase.rpc(
        'deduct_inventory_with_validation',
        params: {
          'p_warehouse_id': testItem['warehouse_id'],
          'p_product_id': testItem['product_id'],
          'p_quantity': 1,
          'p_performed_by': user.id,
          'p_reason': 'اختبار تشخيص خصم المخزون',
          'p_reference_id': 'debug-test-${DateTime.now().millisecondsSinceEpoch}',
          'p_reference_type': 'debug_test',
        },
      );
      
      await _addTestResult('✅ استدعاء دالة قاعدة البيانات نجح');
      await _addTestResult('   النتيجة: $result');
      
      if (result['success'] == true) {
        await _addTestResult('✅ الخصم نجح بالكامل');
        await _addTestResult('   معرف المعاملة: ${result['transaction_id']}');
        await _addTestResult('   الكمية قبل الخصم: ${result['quantity_before']}');
        await _addTestResult('   الكمية بعد الخصم: ${result['quantity_after']}');
      } else {
        await _addTestResult('❌ فشل الخصم: ${result['error']}');
      }
      
    } catch (e) {
      await _addTestResult('❌ خطأ في استدعاء دالة قاعدة البيانات: $e');
    }
  }

  Future<void> _testFullDeductionFlow() async {
    await _addTestResult('\n🔄 اختبار تدفق الخصم الكامل...');
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        await _addTestResult('⚠️ تخطي الاختبار - لا يوجد مستخدم مسجل دخول');
        return;
      }
      
      // Get a real product with sufficient stock
      final inventory = await _supabase
          .from('warehouse_inventory')
          .select('''
            warehouse_id,
            product_id,
            quantity,
            warehouse:warehouses!inner(name),
            product:products!inner(name)
          ''')
          .gt('quantity', 3)
          .limit(1);
      
      if (inventory.isEmpty) {
        await _addTestResult('⚠️ لا توجد منتجات كافية للاختبار');
        return;
      }
      
      final testItem = inventory.first;
      final productName = testItem['product']['name'] ?? 'منتج غير معروف';
      final warehouseName = testItem['warehouse']['name'] ?? 'مخزن غير معروف';
      
      await _addTestResult('   اختبار خصم 2 قطعة من:');
      await _addTestResult('   المنتج: $productName');
      await _addTestResult('   المخزن: $warehouseName');
      await _addTestResult('   الكمية المتاحة: ${testItem['quantity']}');
      
      // Create a mock dispatch product
      final mockProduct = DispatchProductProcessingModel.fromDispatchItem(
        itemId: 'debug-test-${DateTime.now().millisecondsSinceEpoch}',
        requestId: 'debug-request-${DateTime.now().millisecondsSinceEpoch}',
        productId: testItem['product_id'],
        productName: productName,
        quantity: 2,
        notes: 'اختبار تشخيص خصم المخزون',
      );
      
      // Test the full deduction flow
      final result = await _deductionService.deductProductInventory(
        product: mockProduct,
        performedBy: user.id,
        requestId: mockProduct.requestId,
        strategy: WarehouseSelectionStrategy.balanced,
      );
      
      await _addTestResult('✅ تدفق الخصم الكامل نجح');
      await _addTestResult('   النجاح: ${result.success}');
      await _addTestResult('   إجمالي المطلوب: ${result.totalRequestedQuantity}');
      await _addTestResult('   إجمالي المخصوم: ${result.totalDeductedQuantity}');
      await _addTestResult('   عدد المخازن المتأثرة: ${result.warehouseResults.length}');
      
      if (result.errors.isNotEmpty) {
        await _addTestResult('⚠️ أخطاء:');
        for (final error in result.errors) {
          await _addTestResult('   - $error');
        }
      }
      
    } catch (e) {
      await _addTestResult('❌ خطأ في تدفق الخصم الكامل: $e');
      await _addTestResult('   تفاصيل الخطأ: ${e.toString()}');
    }
  }
}
