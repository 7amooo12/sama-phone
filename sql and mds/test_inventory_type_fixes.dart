/// اختبار شامل لإصلاحات أنواع البيانات في نظام المخزون
/// Comprehensive test for inventory type fixes
/// 
/// يختبر جميع الإصلاحات المطبقة ويحدد المشاكل المتبقية

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/utils/inventory_type_fix_tester.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';

class InventoryTypeFixTestScreen extends StatefulWidget {
  const InventoryTypeFixTestScreen({Key? key}) : super(key: key);

  @override
  State<InventoryTypeFixTestScreen> createState() => _InventoryTypeFixTestScreenState();
}

class _InventoryTypeFixTestScreenState extends State<InventoryTypeFixTestScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalInventoryService _globalInventoryService = GlobalInventoryService();
  
  bool _isRunning = false;
  Map<String, dynamic>? _testResults;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار إصلاحات أنواع البيانات'),
        backgroundColor: Colors.blue,
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
                      'اختبار إصلاحات أنواع البيانات',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'يختبر هذا الاختبار جميع الإصلاحات المطبقة لحل مشاكل "warehouse_id is of type uuid but expression is of type text"',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isRunning ? null : _runAllTests,
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
                                    Text('جاري التشغيل...'),
                                  ],
                                )
                              : const Text('تشغيل جميع الاختبارات'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isRunning ? null : _testSpecificProduct,
                          child: const Text('اختبار المنتج 1007/500'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isRunning ? null : _testDatabaseFunction,
                          child: const Text('اختبار دالة قاعدة البيانات'),
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
                        'نتائج الاختبارات',
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
            Text('جاري تشغيل الاختبارات...'),
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
            Text(
              'خطأ في تشغيل الاختبارات',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            Icon(Icons.play_circle_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('اضغط على أحد الأزرار لبدء الاختبارات'),
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
    final summary = _testResults!['summary'] as Map<String, dynamic>?;
    final overallSuccess = _testResults!['overall_success'] as bool? ?? false;

    return Card(
      color: overallSuccess ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  overallSuccess ? Icons.check_circle : Icons.error,
                  color: overallSuccess ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  overallSuccess ? 'جميع الاختبارات نجحت' : 'بعض الاختبارات فشلت',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: overallSuccess ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (summary != null) ...[
              const SizedBox(height: 8),
              Text('إجمالي الاختبارات: ${summary['total_tests']}'),
              Text('نجح: ${summary['successful_tests']}'),
              Text('فشل: ${summary['failed_tests']}'),
              Text('معدل النجاح: ${summary['success_rate']}%'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedResults() {
    final tests = _testResults!['tests'] as Map<String, dynamic>?;
    if (tests == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تفاصيل الاختبارات',
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
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                'الخطأ: $error',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            if (result.containsKey('response')) ...[
              const SizedBox(height: 8),
              Text(
                'الاستجابة: ${result['response']}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _testResults = null;
      _errorMessage = null;
    });

    try {
      AppLogger.info('🧪 بدء تشغيل جميع اختبارات إصلاحات أنواع البيانات');
      final results = await InventoryTypeFixTester.runAllTests();
      
      setState(() {
        _testResults = results;
        _isRunning = false;
      });

      AppLogger.info('✅ انتهاء جميع الاختبارات');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isRunning = false;
      });
      AppLogger.error('❌ خطأ في تشغيل الاختبارات: $e');
    }
  }

  Future<void> _testSpecificProduct() async {
    setState(() {
      _isRunning = true;
      _testResults = null;
      _errorMessage = null;
    });

    try {
      AppLogger.info('🧪 اختبار المنتج 1007/500 تحديداً');
      
      // اختبار البحث العالمي للمنتج 1007/500
      final searchResult = await _globalInventoryService.searchProductGlobally(
        productId: '15', // Product 1007/500 has ID 15
        requestedQuantity: 50,
      );

      final testResults = {
        'timestamp': DateTime.now().toIso8601String(),
        'overall_success': searchResult.canFulfill,
        'tests': {
          'product_1007_500_search': {
            'success': true,
            'can_fulfill': searchResult.canFulfill,
            'total_available': searchResult.totalAvailableQuantity,
            'warehouses_count': searchResult.availableWarehouses.length,
            'allocation_plan_count': searchResult.allocationPlan.length,
          }
        },
        'summary': {
          'total_tests': 1,
          'successful_tests': 1,
          'failed_tests': 0,
          'success_rate': '100.0',
        }
      };

      setState(() {
        _testResults = testResults;
        _isRunning = false;
      });

      AppLogger.info('✅ انتهاء اختبار المنتج 1007/500');
    } catch (e) {
      final testResults = {
        'timestamp': DateTime.now().toIso8601String(),
        'overall_success': false,
        'tests': {
          'product_1007_500_search': {
            'success': false,
            'error': e.toString(),
          }
        },
        'summary': {
          'total_tests': 1,
          'successful_tests': 0,
          'failed_tests': 1,
          'success_rate': '0.0',
        }
      };

      setState(() {
        _testResults = testResults;
        _isRunning = false;
      });
      
      AppLogger.error('❌ خطأ في اختبار المنتج 1007/500: $e');
    }
  }

  Future<void> _testDatabaseFunction() async {
    setState(() {
      _isRunning = true;
      _testResults = null;
      _errorMessage = null;
    });

    try {
      AppLogger.info('🧪 اختبار دالة قاعدة البيانات المُحدثة تحديداً');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('لا يوجد مستخدم مسجل دخول');
      }

      // الحصول على مخزن حقيقي للاختبار
      final warehousesResponse = await _supabase
          .from('warehouses')
          .select('id')
          .eq('is_active', true)
          .limit(1);

      String testWarehouseId;
      if (warehousesResponse.isNotEmpty) {
        testWarehouseId = warehousesResponse.first['id'];
        AppLogger.info('🏢 استخدام مخزن حقيقي للاختبار: $testWarehouseId');
      } else {
        testWarehouseId = '123e4567-e89b-12d3-a456-426614174000'; // UUID وهمي كبديل
        AppLogger.info('⚠️ استخدام مخزن وهمي للاختبار: $testWarehouseId');
      }

      // اختبار دالة deduct_inventory_with_validation مباشرة
      AppLogger.info('📞 استدعاء دالة قاعدة البيانات مع المعاملات:');
      AppLogger.info('   p_warehouse_id: $testWarehouseId');
      AppLogger.info('   p_product_id: 15');
      AppLogger.info('   p_quantity: 0');
      AppLogger.info('   p_performed_by: ${currentUser.id}');

      final response = await _supabase.rpc(
        'deduct_inventory_with_validation',
        params: {
          'p_warehouse_id': testWarehouseId,
          'p_product_id': '15', // Product 1007/500
          'p_quantity': 0, // كمية صفر للاختبار الآمن
          'p_performed_by': currentUser.id,
          'p_reason': 'اختبار دالة قاعدة البيانات المُحدثة',
          'p_reference_id': 'db-function-test-${DateTime.now().millisecondsSinceEpoch}',
          'p_reference_type': 'database_function_test',
        },
      );

      AppLogger.info('📤 استجابة دالة قاعدة البيانات: $response');

      final functionSuccess = response != null && response['success'] == true;

      final testResults = {
        'timestamp': DateTime.now().toIso8601String(),
        'overall_success': functionSuccess,
        'tests': {
          'database_function_direct': {
            'success': functionSuccess,
            'response': response,
            'warehouse_id_used': testWarehouseId,
            'function_version': 'FINAL_VERSION_DEPLOYED',
          }
        },
        'summary': {
          'total_tests': 1,
          'successful_tests': functionSuccess ? 1 : 0,
          'failed_tests': functionSuccess ? 0 : 1,
          'success_rate': functionSuccess ? '100.0' : '0.0',
        }
      };

      setState(() {
        _testResults = testResults;
        _isRunning = false;
      });

      AppLogger.info('✅ انتهاء اختبار دالة قاعدة البيانات - النجاح: $functionSuccess');
    } catch (e) {
      final testResults = {
        'timestamp': DateTime.now().toIso8601String(),
        'overall_success': false,
        'tests': {
          'database_function_direct': {
            'success': false,
            'error': e.toString(),
            'error_type': e.toString().contains('uuid') || e.toString().contains('type') ? 'TYPE_MISMATCH' : 'OTHER',
          }
        },
        'summary': {
          'total_tests': 1,
          'successful_tests': 0,
          'failed_tests': 1,
          'success_rate': '0.0',
        }
      };

      setState(() {
        _testResults = testResults;
        _isRunning = false;
      });

      AppLogger.error('❌ خطأ في اختبار دالة قاعدة البيانات: $e');
    }
  }
}
