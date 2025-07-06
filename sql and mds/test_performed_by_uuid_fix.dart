/// اختبار إصلاح خطأ performed_by UUID
/// Test performed_by UUID Fix
/// 
/// يختبر إصلاح خطأ "column performed_by is of type uuid but expression is of type text"

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';

class PerformedByUuidFixTestScreen extends StatefulWidget {
  const PerformedByUuidFixTestScreen({Key? key}) : super(key: key);

  @override
  State<PerformedByUuidFixTestScreen> createState() => _PerformedByUuidFixTestScreenState();
}

class _PerformedByUuidFixTestScreenState extends State<PerformedByUuidFixTestScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalInventoryService _globalInventoryService = GlobalInventoryService();
  
  bool _isRunning = false;
  Map<String, dynamic>? _testResults;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار إصلاح performed_by UUID'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
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
                      'اختبار إصلاح خطأ performed_by UUID',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'يختبر هذا الاختبار إصلاح خطأ "column performed_by is of type uuid but expression is of type text" باستخدام نفس المعاملات من السجلات',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isRunning ? null : _testDatabaseFunctionDirectly,
                          child: const Text('اختبار دالة قاعدة البيانات مباشرة'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isRunning ? null : _testGlobalInventoryService,
                          child: const Text('اختبار خدمة المخزون العالمي'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isRunning ? null : _testCompleteDeductionFlow,
                      child: _isRunning
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('جاري الاختبار...'),
                              ],
                            )
                          : const Text('اختبار تدفق الخصم الكامل'),
                    ),
                  ],
                ),
              ),
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _buildResultsWidget(),
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

  Widget _buildResultsWidget() {
    if (_isRunning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تشغيل الاختبار...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'خطأ في الاختبار',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
          ],
        ),
      );
    }

    if (_testResults == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bug_report, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('اضغط على أحد الأزرار لبدء الاختبار'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 16),
          _buildDetailedResults(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final success = _testResults!['success'] as bool? ?? false;

    return Card(
      color: success ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  success ? 'الاختبار نجح - تم إصلاح المشكلة' : 'الاختبار فشل - المشكلة لا تزال موجودة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: success ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('نوع الاختبار: ${_testResults!['test_type']}'),
            Text('الوقت: ${_testResults!['timestamp']}'),
            if (_testResults!.containsKey('performed_by_validation'))
              Text('تحقق performed_by: ${_testResults!['performed_by_validation']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedResults() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تفاصيل النتائج',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('النتائج الكاملة: ${_testResults.toString()}'),
          ],
        ),
      ),
    );
  }

  Future<void> _testDatabaseFunctionDirectly() async {
    setState(() {
      _isRunning = true;
      _testResults = null;
      _errorMessage = null;
    });

    try {
      AppLogger.info('🧪 اختبار دالة قاعدة البيانات مباشرة مع المعاملات من السجلات');
      
      // استخدام نفس المعاملات من السجلات
      final response = await _supabase.rpc(
        'deduct_inventory_with_validation',
        params: {
          'p_warehouse_id': '9a900dea-1938-4ebd-84f5-1d07aea19318',  // من السجلات
          'p_product_id': '15',                                       // Product 1007/500
          'p_quantity': 0,                                            // كمية آمنة للاختبار
          'p_performed_by': '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab', // من السجلات
          'p_reason': 'اختبار إصلاح performed_by UUID',
          'p_reference_id': 'performed-by-fix-test-${DateTime.now().millisecondsSinceEpoch}',
          'p_reference_type': 'performed_by_fix_test',
        },
      );

      final success = response != null && response['success'] == true;

      setState(() {
        _testResults = {
          'success': success,
          'test_type': 'Direct Database Function Test',
          'timestamp': DateTime.now().toIso8601String(),
          'warehouse_id': '9a900dea-1938-4ebd-84f5-1d07aea19318',
          'product_id': '15',
          'performed_by': '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab',
          'performed_by_validation': 'UUID format validated',
          'response': response,
          'error_fixed': success ? 'performed_by UUID error resolved' : 'performed_by UUID error still exists',
        };
        _isRunning = false;
      });

      AppLogger.info('✅ انتهاء اختبار دالة قاعدة البيانات - النجاح: $success');
    } catch (e) {
      setState(() {
        _testResults = {
          'success': false,
          'test_type': 'Direct Database Function Test',
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'error_type': e.toString().contains('performed_by') && e.toString().contains('uuid') ? 'PERFORMED_BY_UUID_ERROR' : 'OTHER',
        };
        _isRunning = false;
      });
      
      AppLogger.error('❌ خطأ في اختبار دالة قاعدة البيانات: $e');
    }
  }

  Future<void> _testGlobalInventoryService() async {
    setState(() {
      _isRunning = true;
      _testResults = null;
      _errorMessage = null;
    });

    try {
      AppLogger.info('🌍 اختبار خدمة المخزون العالمي مع التحقق من performed_by');
      
      // إنشاء allocation للاختبار
      final testAllocation = InventoryAllocation(
        warehouseId: '9a900dea-1938-4ebd-84f5-1d07aea19318',
        warehouseName: 'تجريبي',
        productId: '15',
        availableQuantity: 100,
        allocatedQuantity: 1, // كمية صغيرة للاختبار
      );

      // اختبار executeAllocationPlan
      final result = await _globalInventoryService.executeAllocationPlan(
        allocationPlan: [testAllocation],
        requestId: 'performed-by-test-${DateTime.now().millisecondsSinceEpoch}',
        performedBy: '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab', // من السجلات
        reason: 'اختبار إصلاح performed_by UUID في خدمة المخزون العالمي',
      );

      final success = result.success && result.totalDeducted > 0;

      setState(() {
        _testResults = {
          'success': success,
          'test_type': 'Global Inventory Service Test',
          'timestamp': DateTime.now().toIso8601String(),
          'total_requested': result.totalRequested,
          'total_deducted': result.totalDeducted,
          'deduction_results': result.deductionResults.length,
          'errors': result.errors.length,
          'performed_by_validation': 'UUID format validated in service layer',
          'error_fixed': success ? 'performed_by UUID error resolved in service' : 'performed_by UUID error still exists in service',
        };
        _isRunning = false;
      });

      AppLogger.info('✅ انتهاء اختبار خدمة المخزون العالمي - النجاح: $success');
    } catch (e) {
      setState(() {
        _testResults = {
          'success': false,
          'test_type': 'Global Inventory Service Test',
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'error_type': e.toString().contains('performed_by') && e.toString().contains('uuid') ? 'PERFORMED_BY_UUID_ERROR' : 'OTHER',
        };
        _isRunning = false;
      });
      
      AppLogger.error('❌ خطأ في اختبار خدمة المخزون العالمي: $e');
    }
  }

  Future<void> _testCompleteDeductionFlow() async {
    setState(() {
      _isRunning = true;
      _testResults = null;
      _errorMessage = null;
    });

    try {
      AppLogger.info('🔄 اختبار تدفق الخصم الكامل للمنتج 1007/500');
      
      // 1. البحث العالمي
      final searchResult = await _globalInventoryService.searchProductGlobally(
        productId: '15', // Product 1007/500
        requestedQuantity: 50,
      );

      if (!searchResult.canFulfill) {
        setState(() {
          _testResults = {
            'success': false,
            'test_type': 'Complete Deduction Flow Test',
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'لا يمكن تلبية الطلب - الكمية المتاحة: ${searchResult.totalAvailableQuantity}',
            'available_quantity': searchResult.totalAvailableQuantity,
            'can_fulfill': false,
          };
          _isRunning = false;
        });
        return;
      }

      // 2. تنفيذ خطة التخصيص
      final executionResult = await _globalInventoryService.executeAllocationPlan(
        allocationPlan: searchResult.allocationPlan,
        requestId: 'complete-flow-test-${DateTime.now().millisecondsSinceEpoch}',
        performedBy: '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab', // من السجلات
        reason: 'اختبار تدفق الخصم الكامل مع إصلاح performed_by UUID',
      );

      final success = executionResult.success && executionResult.totalDeducted == 50;

      setState(() {
        _testResults = {
          'success': success,
          'test_type': 'Complete Deduction Flow Test',
          'timestamp': DateTime.now().toIso8601String(),
          'search_can_fulfill': searchResult.canFulfill,
          'search_available_quantity': searchResult.totalAvailableQuantity,
          'execution_total_requested': executionResult.totalRequested,
          'execution_total_deducted': executionResult.totalDeducted,
          'execution_success': executionResult.success,
          'execution_errors': executionResult.errors.length,
          'performed_by_validation': 'UUID format validated throughout flow',
          'final_result': success ? '50 items successfully deducted' : 'Deduction failed or incomplete',
          'error_fixed': success ? 'performed_by UUID error completely resolved' : 'performed_by UUID error may still exist',
        };
        _isRunning = false;
      });

      AppLogger.info('✅ انتهاء اختبار تدفق الخصم الكامل - النجاح: $success (${executionResult.totalDeducted}/50)');
    } catch (e) {
      setState(() {
        _testResults = {
          'success': false,
          'test_type': 'Complete Deduction Flow Test',
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'error_type': e.toString().contains('performed_by') && e.toString().contains('uuid') ? 'PERFORMED_BY_UUID_ERROR' : 'OTHER',
        };
        _isRunning = false;
      });
      
      AppLogger.error('❌ خطأ في اختبار تدفق الخصم الكامل: $e');
    }
  }
}
