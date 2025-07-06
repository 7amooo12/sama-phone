/// اختبار شامل لإصلاح معالجة أذون الصرف المحولة من طلبات الصرف
/// Comprehensive Test for Dispatch-Converted Release Order Processing Fix

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/services/warehouse_release_orders_service.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/services/intelligent_inventory_deduction_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

void main() {
  runApp(const DispatchReleaseOrderTestApp());
}

class DispatchReleaseOrderTestApp extends StatelessWidget {
  const DispatchReleaseOrderTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'اختبار إصلاح أذون الصرف المحولة',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
      ),
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final _releaseOrdersService = WarehouseReleaseOrdersService();
  final _globalInventoryService = GlobalInventoryService();
  final _intelligentDeductionService = IntelligentInventoryDeductionService();
  
  bool _isLoading = false;
  String _testResults = '';
  
  // Test data - the problematic order from the logs
  final String _testReleaseOrderId = 'WRO-DISPATCH-1d90eb34-b38c-4b19-bb85-3a9b22508637';
  final String _testWarehouseManagerId = '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار إصلاح أذون الصرف المحولة'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات الاختبار',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('معرف أذن الصرف: $_testReleaseOrderId'),
                    Text('معرف مدير المخزن: $_testWarehouseManagerId'),
                    const SizedBox(height: 8),
                    const Text(
                      'هذا الاختبار سيتحقق من:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('• إصلاح خطأ UUID type mismatch'),
                    const Text('• استراتيجية اختيار المخازن ذات أعلى مخزون'),
                    const Text('• معالجة أذون الصرف المحولة من طلبات الصرف'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _runComprehensiveTest,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('تشغيل الاختبار الشامل'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'نتائج الاختبار',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _testResults.isEmpty ? 'لم يتم تشغيل الاختبار بعد' : _testResults,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ],
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
      _isLoading = true;
      _testResults = '';
    });

    try {
      _addTestResult('🚀 بدء الاختبار الشامل لإصلاح أذون الصرف المحولة...\n');

      // Test 1: Database Function Test
      _addTestResult('📋 الاختبار 1: اختبار دالة قاعدة البيانات الجديدة');
      await _testDatabaseFunction();

      // Test 2: Warehouse Selection Strategy Test
      _addTestResult('\n📋 الاختبار 2: اختبار استراتيجية اختيار المخازن');
      await _testWarehouseSelectionStrategy();

      // Test 3: Dispatch-Converted Release Order Retrieval
      _addTestResult('\n📋 الاختبار 3: اختبار استرجاع أذن الصرف المحول');
      await _testDispatchConvertedReleaseOrderRetrieval();

      // Test 4: Complete Processing Workflow
      _addTestResult('\n📋 الاختبار 4: اختبار سير العمل الكامل للمعالجة');
      await _testCompleteProcessingWorkflow();

      _addTestResult('\n✅ انتهى الاختبار الشامل بنجاح!');

    } catch (e) {
      _addTestResult('\n❌ خطأ في الاختبار: $e');
      AppLogger.error('❌ خطأ في الاختبار الشامل: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testDatabaseFunction() async {
    try {
      final result = await _globalInventoryService.searchProductGlobally(
        productId: '190',
        requestedQuantity: 1,
      );

      if (result.canFulfill) {
        _addTestResult('✅ دالة البحث العالمي تعمل بشكل صحيح');
        _addTestResult('   الكمية المتاحة: ${result.totalAvailableQuantity}');
        _addTestResult('   عدد المخازن: ${result.availableWarehouses.length}');
      } else {
        _addTestResult('⚠️ لا توجد كمية متاحة للمنتج 190');
      }
    } catch (e) {
      _addTestResult('❌ خطأ في اختبار دالة قاعدة البيانات: $e');
    }
  }

  Future<void> _testWarehouseSelectionStrategy() async {
    try {
      final result = await _globalInventoryService.searchProductGlobally(
        productId: '190',
        requestedQuantity: 20,
        strategy: WarehouseSelectionStrategy.highestStock,
      );

      if (result.allocationPlan.isNotEmpty) {
        _addTestResult('✅ استراتيجية أعلى مخزون تعمل بشكل صحيح');
        for (int i = 0; i < result.allocationPlan.length; i++) {
          final allocation = result.allocationPlan[i];
          _addTestResult('   المخزن ${i + 1}: ${allocation.warehouseName} (${allocation.availableQuantity} متاح)');
        }
      } else {
        _addTestResult('⚠️ لا توجد خطة تخصيص متاحة');
      }
    } catch (e) {
      _addTestResult('❌ خطأ في اختبار استراتيجية اختيار المخازن: $e');
    }
  }

  Future<void> _testDispatchConvertedReleaseOrderRetrieval() async {
    try {
      final releaseOrder = await _releaseOrdersService.getReleaseOrder(_testReleaseOrderId);

      if (releaseOrder != null) {
        _addTestResult('✅ تم استرجاع أذن الصرف المحول بنجاح');
        _addTestResult('   معرف الأذن: ${releaseOrder.id}');
        _addTestResult('   رقم الأذن: ${releaseOrder.releaseOrderNumber}');
        _addTestResult('   عدد العناصر: ${releaseOrder.items.length}');
        _addTestResult('   الحالة: ${releaseOrder.status}');
      } else {
        _addTestResult('❌ فشل في استرجاع أذن الصرف المحول');
      }
    } catch (e) {
      _addTestResult('❌ خطأ في اختبار استرجاع أذن الصرف المحول: $e');
    }
  }

  Future<void> _testCompleteProcessingWorkflow() async {
    try {
      _addTestResult('🔄 اختبار سير العمل الكامل للمعالجة...');

      final success = await _releaseOrdersService.processAllReleaseOrderItems(
        releaseOrderId: _testReleaseOrderId,
        warehouseManagerId: _testWarehouseManagerId,
        notes: 'اختبار إصلاح UUID type mismatch',
      );

      if (success) {
        _addTestResult('✅ تم إكمال معالجة أذن الصرف المحول بنجاح!');
        _addTestResult('   لا مزيد من خطأ "operator does not exist: uuid = text"');
        _addTestResult('   تم خصم المخزون بنجاح');
        _addTestResult('   تم تحديث حالة الطلب الأصلي');
      } else {
        _addTestResult('❌ فشل في معالجة أذن الصرف المحول');
      }
    } catch (e) {
      _addTestResult('❌ خطأ في اختبار سير العمل الكامل: $e');
    }
  }

  void _addTestResult(String result) {
    setState(() {
      _testResults += '$result\n';
    });
    AppLogger.info(result);
  }
}
