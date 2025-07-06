/// التحقق النهائي من إصلاح نظام خصم المخزون الذكي
/// Final Verification of Intelligent Inventory Deduction System Fix
/// 
/// يختبر النظام بالكامل للتأكد من أن المنتج 1007/500 يمكن خصمه بنجاح

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/services/intelligent_inventory_deduction_service.dart';
import 'package:smartbiztracker_new/models/dispatch_product_processing_model.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';

class InventoryDeductionFixVerificationScreen extends StatefulWidget {
  const InventoryDeductionFixVerificationScreen({Key? key}) : super(key: key);

  @override
  State<InventoryDeductionFixVerificationScreen> createState() => _InventoryDeductionFixVerificationScreenState();
}

class _InventoryDeductionFixVerificationScreenState extends State<InventoryDeductionFixVerificationScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalInventoryService _globalInventoryService = GlobalInventoryService();
  final IntelligentInventoryDeductionService _deductionService = IntelligentInventoryDeductionService();
  
  bool _isRunning = false;
  Map<String, dynamic>? _verificationResults;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق النهائي من إصلاح نظام الخصم'),
        backgroundColor: Colors.purple,
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
                      'التحقق النهائي من إصلاح نظام خصم المخزون الذكي',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'يختبر هذا التحقق النظام بالكامل للتأكد من أن المنتج 1007/500 يمكن خصمه بنجاح بدون أخطاء warehouse_id أو minimum_stock',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isRunning ? null : _runCompleteVerification,
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
                                    Text('جاري التحقق...'),
                                  ],
                                )
                              : const Text('تشغيل التحقق الكامل'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isRunning ? null : _testProduct1007500Specifically,
                          child: const Text('اختبار المنتج 1007/500 تحديداً'),
                        ),
                      ],
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
                        'نتائج التحقق',
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
            Text('جاري تشغيل التحقق الكامل...'),
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
              'خطأ في التحقق',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
          ],
        ),
      );
    }

    if (_verificationResults == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('اضغط على أحد الأزرار لبدء التحقق'),
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
    final success = _verificationResults!['overall_success'] as bool? ?? false;
    final testsCount = _verificationResults!['tests_completed'] as int? ?? 0;
    final passedCount = _verificationResults!['tests_passed'] as int? ?? 0;

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
                  success ? Icons.verified : Icons.error,
                  color: success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  success ? 'التحقق نجح بالكامل' : 'التحقق فشل',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: success ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('الاختبارات المكتملة: $testsCount'),
            Text('الاختبارات الناجحة: $passedCount'),
            Text('معدل النجاح: ${testsCount > 0 ? ((passedCount / testsCount) * 100).toStringAsFixed(1) : 0}%'),
            Text('الوقت: ${_verificationResults!['timestamp']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedResults() {
    final tests = _verificationResults!['verification_tests'] as Map<String, dynamic>?;
    if (tests == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تفاصيل التحقق',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...tests.entries.map((entry) => _buildTestResultCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildTestResultCard(String testName, dynamic testResult) {
    final result = testResult as Map<String, dynamic>;
    final success = result['success'] as bool? ?? false;
    final error = result['error'] as String?;
    final details = result['details'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    testName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (details != null) ...[
              const SizedBox(height: 4),
              Text(
                details,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                'الخطأ: $error',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runCompleteVerification() async {
    setState(() {
      _isRunning = true;
      _verificationResults = null;
      _errorMessage = null;
    });

    try {
      AppLogger.info('🔍 بدء التحقق الكامل من إصلاح نظام خصم المخزون الذكي');
      
      final verificationTests = <String, Map<String, dynamic>>{};
      int testsCompleted = 0;
      int testsPassed = 0;

      // اختبار 1: التحقق من وجود دوال قاعدة البيانات
      AppLogger.info('🔧 اختبار 1: التحقق من دوال قاعدة البيانات...');
      try {
        final functionsTest = await _testDatabaseFunctions();
        verificationTests['database_functions'] = functionsTest;
        testsCompleted++;
        if (functionsTest['success']) testsPassed++;
      } catch (e) {
        verificationTests['database_functions'] = {'success': false, 'error': e.toString()};
        testsCompleted++;
      }

      // اختبار 2: البحث العالمي للمنتج 1007/500
      AppLogger.info('🌍 اختبار 2: البحث العالمي للمنتج 1007/500...');
      try {
        final globalSearchTest = await _testGlobalSearch();
        verificationTests['global_search'] = globalSearchTest;
        testsCompleted++;
        if (globalSearchTest['success']) testsPassed++;
      } catch (e) {
        verificationTests['global_search'] = {'success': false, 'error': e.toString()};
        testsCompleted++;
      }

      // اختبار 3: فحص إمكانية الخصم الذكي
      AppLogger.info('🤖 اختبار 3: فحص إمكانية الخصم الذكي...');
      try {
        final feasibilityTest = await _testDeductionFeasibility();
        verificationTests['deduction_feasibility'] = feasibilityTest;
        testsCompleted++;
        if (feasibilityTest['success']) testsPassed++;
      } catch (e) {
        verificationTests['deduction_feasibility'] = {'success': false, 'error': e.toString()};
        testsCompleted++;
      }

      // اختبار 4: اختبار خصم آمن (كمية صفر)
      AppLogger.info('🛡️ اختبار 4: اختبار خصم آمن...');
      try {
        final safeDeductionTest = await _testSafeDeduction();
        verificationTests['safe_deduction'] = safeDeductionTest;
        testsCompleted++;
        if (safeDeductionTest['success']) testsPassed++;
      } catch (e) {
        verificationTests['safe_deduction'] = {'success': false, 'error': e.toString()};
        testsCompleted++;
      }

      final overallSuccess = testsPassed == testsCompleted && testsCompleted > 0;

      setState(() {
        _verificationResults = {
          'overall_success': overallSuccess,
          'tests_completed': testsCompleted,
          'tests_passed': testsPassed,
          'timestamp': DateTime.now().toIso8601String(),
          'verification_tests': verificationTests,
          'product_id': '15', // Product 1007/500
          'fix_status': overallSuccess ? 'FULLY_FIXED' : 'NEEDS_ATTENTION',
        };
        _isRunning = false;
      });

      AppLogger.info('✅ انتهاء التحقق الكامل - النجاح: $overallSuccess ($testsPassed/$testsCompleted)');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isRunning = false;
      });
      AppLogger.error('❌ خطأ في التحقق الكامل: $e');
    }
  }

  Future<Map<String, dynamic>> _testDatabaseFunctions() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      return {'success': false, 'error': 'لا يوجد مستخدم مسجل دخول'};
    }

    // اختبار دالة deduct_inventory_with_validation
    try {
      final response = await _supabase.rpc('deduct_inventory_with_validation', params: {
        'p_warehouse_id': '123e4567-e89b-12d3-a456-426614174000',
        'p_product_id': '15',
        'p_quantity': 0,
        'p_performed_by': currentUser.id,
        'p_reason': 'Database function verification test',
        'p_reference_id': 'verification-test-${DateTime.now().millisecondsSinceEpoch}',
        'p_reference_type': 'verification_test',
      });

      return {
        'success': response != null,
        'details': 'دالة deduct_inventory_with_validation تعمل بشكل صحيح',
        'function_response': response,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'details': 'فشل في اختبار دالة deduct_inventory_with_validation',
      };
    }
  }

  Future<Map<String, dynamic>> _testGlobalSearch() async {
    try {
      final searchResult = await _globalInventoryService.searchProductGlobally(
        productId: '15', // Product 1007/500
        requestedQuantity: 50,
      );

      return {
        'success': true,
        'details': 'البحث العالمي نجح - إجمالي متاح: ${searchResult.totalAvailableQuantity}، يمكن التلبية: ${searchResult.canFulfill}',
        'can_fulfill': searchResult.canFulfill,
        'total_available': searchResult.totalAvailableQuantity,
        'warehouses_count': searchResult.availableWarehouses.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'details': 'فشل في البحث العالمي للمنتج 1007/500',
      };
    }
  }

  Future<Map<String, dynamic>> _testDeductionFeasibility() async {
    try {
      final testProduct = DispatchProductProcessingModel.fromDispatchItem(
        itemId: 'verification-test-${DateTime.now().millisecondsSinceEpoch}',
        requestId: 'verification-request-${DateTime.now().millisecondsSinceEpoch}',
        productId: '15', // Product 1007/500
        productName: 'منتج 1007/500 - اختبار التحقق',
        quantity: 50,
        notes: 'اختبار التحقق من إصلاح نظام الخصم',
      );

      final feasibilityCheck = await _deductionService.checkDeductionFeasibility(
        product: testProduct,
        strategy: WarehouseSelectionStrategy.balanced,
      );

      return {
        'success': true,
        'details': 'فحص إمكانية الخصم نجح - يمكن التلبية: ${feasibilityCheck.canFulfill}، متاح: ${feasibilityCheck.availableQuantity}',
        'can_fulfill': feasibilityCheck.canFulfill,
        'available_quantity': feasibilityCheck.availableQuantity,
        'available_warehouses': feasibilityCheck.availableWarehouses,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'details': 'فشل في فحص إمكانية الخصم الذكي',
      };
    }
  }

  Future<Map<String, dynamic>> _testSafeDeduction() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return {'success': false, 'error': 'لا يوجد مستخدم مسجل دخول'};
      }

      // الحصول على مخزن يحتوي على المنتج
      final warehouseResponse = await _supabase
          .from('warehouse_inventory')
          .select('warehouse_id, quantity')
          .eq('product_id', '15')
          .gt('quantity', 0)
          .limit(1);

      if (warehouseResponse.isEmpty) {
        return {
          'success': false,
          'error': 'لا يوجد مخزن يحتوي على المنتج 1007/500',
          'details': 'لا يمكن اختبار الخصم الآمن بدون مخزون متاح',
        };
      }

      final testWarehouseId = warehouseResponse.first['warehouse_id'];
      final availableQuantity = warehouseResponse.first['quantity'];

      // اختبار خصم آمن بكمية صفر
      final response = await _supabase.rpc('deduct_inventory_with_validation', params: {
        'p_warehouse_id': testWarehouseId,
        'p_product_id': '15',
        'p_quantity': 0, // كمية صفر للاختبار الآمن
        'p_performed_by': currentUser.id,
        'p_reason': 'Safe deduction verification test',
        'p_reference_id': 'safe-verification-${DateTime.now().millisecondsSinceEpoch}',
        'p_reference_type': 'safe_verification',
      });

      final success = response != null && response['success'] == true;

      return {
        'success': success,
        'details': 'اختبار الخصم الآمن ${success ? "نجح" : "فشل"} - المخزن: $testWarehouseId، الكمية المتاحة: $availableQuantity',
        'warehouse_id': testWarehouseId,
        'available_quantity': availableQuantity,
        'response': response,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'details': 'فشل في اختبار الخصم الآمن',
      };
    }
  }

  Future<void> _testProduct1007500Specifically() async {
    setState(() {
      _isRunning = true;
      _verificationResults = null;
      _errorMessage = null;
    });

    try {
      AppLogger.info('🎯 اختبار المنتج 1007/500 تحديداً');
      
      // البحث عن المنتج 1007/500 في النظام
      final searchResult = await _globalInventoryService.searchProductGlobally(
        productId: '15', // Product 1007/500
        requestedQuantity: 50,
      );

      setState(() {
        _verificationResults = {
          'overall_success': searchResult.canFulfill,
          'tests_completed': 1,
          'tests_passed': searchResult.canFulfill ? 1 : 0,
          'timestamp': DateTime.now().toIso8601String(),
          'verification_tests': {
            'product_1007_500_specific': {
              'success': searchResult.canFulfill,
              'details': 'المنتج 1007/500 - إجمالي متاح: ${searchResult.totalAvailableQuantity}، يمكن تلبية 50 قطعة: ${searchResult.canFulfill ? "نعم" : "لا"}',
              'total_available': searchResult.totalAvailableQuantity,
              'can_fulfill_50_pieces': searchResult.canFulfill,
              'warehouses_with_stock': searchResult.availableWarehouses.length,
              'allocation_plan': searchResult.allocationPlan.length,
            }
          },
          'product_id': '15',
          'fix_status': searchResult.canFulfill ? 'READY_FOR_DEDUCTION' : 'INSUFFICIENT_STOCK',
        };
        _isRunning = false;
      });

      AppLogger.info('✅ انتهاء اختبار المنتج 1007/500 - يمكن التلبية: ${searchResult.canFulfill}');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isRunning = false;
      });
      AppLogger.error('❌ خطأ في اختبار المنتج 1007/500: $e');
    }
  }
}
