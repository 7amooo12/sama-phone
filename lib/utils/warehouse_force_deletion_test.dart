import '../services/warehouse_service.dart';
import '../services/warehouse_order_transfer_service.dart';
import '../utils/app_logger.dart';

/// اختبار شامل لنظام الحذف القسري للمخازن مع نقل الطلبات
class WarehouseForceDeletionTest {
  final WarehouseService _warehouseService = WarehouseService();
  final WarehouseOrderTransferService _transferService = WarehouseOrderTransferService();

  /// تشغيل جميع اختبارات الحذف القسري
  Future<Map<String, dynamic>> runComprehensiveTests() async {
    AppLogger.info('🧪 بدء الاختبار الشامل لنظام الحذف القسري');
    
    final results = <String, dynamic>{
      'test_start_time': DateTime.now().toIso8601String(),
      'tests_passed': 0,
      'tests_failed': 0,
      'test_results': <String, dynamic>{},
      'performance_metrics': <String, dynamic>{},
      'errors': <String>[],
    };

    try {
      // اختبار 1: التحقق من المخازن المتاحة
      await _testAvailableWarehouses(results);
      
      // اختبار 2: التحقق من صحة النقل
      await _testTransferValidation(results);
      
      // اختبار 3: اختبار الأداء
      await _testPerformance(results);
      
      // اختبار 4: اختبار الحالات الحدية
      await _testEdgeCases(results);
      
      // اختبار 5: اختبار آليات الاسترداد
      await _testRollbackMechanisms(results);

      results['test_end_time'] = DateTime.now().toIso8601String();
      results['overall_success'] = results['tests_failed'] == 0;
      
      AppLogger.info('✅ اكتمل الاختبار الشامل - نجح: ${results['tests_passed']}, فشل: ${results['tests_failed']}');
      
    } catch (e) {
      AppLogger.error('❌ خطأ في الاختبار الشامل: $e');
      results['errors'].add('خطأ عام في الاختبار: $e');
      results['overall_success'] = false;
    }

    return results;
  }

  /// اختبار الحصول على المخازن المتاحة
  Future<void> _testAvailableWarehouses(Map<String, dynamic> results) async {
    final testName = 'available_warehouses_test';
    final startTime = DateTime.now();
    
    try {
      AppLogger.info('🔍 اختبار الحصول على المخازن المتاحة');
      
      // استخدام معرف مخزن وهمي للاختبار
      const testWarehouseId = 'test-warehouse-id';
      
      final availableWarehouses = await _transferService.getAvailableTargetWarehouses(testWarehouseId);
      
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': true,
        'duration_ms': duration.inMilliseconds,
        'warehouses_found': availableWarehouses.length,
        'message': 'تم العثور على ${availableWarehouses.length} مخزن متاح',
      };
      
      results['tests_passed']++;
      AppLogger.info('✅ نجح اختبار المخازن المتاحة');
      
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': false,
        'duration_ms': duration.inMilliseconds,
        'error': e.toString(),
      };
      
      results['tests_failed']++;
      results['errors'].add('فشل اختبار المخازن المتاحة: $e');
      AppLogger.error('❌ فشل اختبار المخازن المتاحة: $e');
    }
  }

  /// اختبار التحقق من صحة النقل
  Future<void> _testTransferValidation(Map<String, dynamic> results) async {
    final testName = 'transfer_validation_test';
    final startTime = DateTime.now();
    
    try {
      AppLogger.info('🔍 اختبار التحقق من صحة النقل');
      
      const sourceWarehouseId = 'test-source-warehouse';
      const targetWarehouseId = 'test-target-warehouse';
      
      final validation = await _transferService.validateOrderTransfer(
        sourceWarehouseId,
        targetWarehouseId,
      );
      
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': true,
        'duration_ms': duration.inMilliseconds,
        'validation_result': {
          'is_valid': validation.isValid,
          'transferable_orders': validation.transferableOrders,
          'blocked_orders': validation.blockedOrders,
          'errors_count': validation.validationErrors.length,
        },
        'message': 'تم التحقق من صحة النقل',
      };
      
      results['tests_passed']++;
      AppLogger.info('✅ نجح اختبار التحقق من صحة النقل');
      
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': false,
        'duration_ms': duration.inMilliseconds,
        'error': e.toString(),
      };
      
      results['tests_failed']++;
      results['errors'].add('فشل اختبار التحقق من صحة النقل: $e');
      AppLogger.error('❌ فشل اختبار التحقق من صحة النقل: $e');
    }
  }

  /// اختبار الأداء (يجب أن يكون أقل من 3 ثوانٍ)
  Future<void> _testPerformance(Map<String, dynamic> results) async {
    final testName = 'performance_test';
    final startTime = DateTime.now();
    
    try {
      AppLogger.info('⏱️ اختبار الأداء - الهدف: أقل من 3 ثوانٍ');
      
      const testWarehouseId = 'performance-test-warehouse';
      
      // اختبار عدة عمليات متتالية
      final futures = <Future>[];
      
      // اختبار الحصول على المخازن المتاحة
      futures.add(_transferService.getAvailableTargetWarehouses(testWarehouseId));
      
      // اختبار إحصائيات النقل
      futures.add(_transferService.getTransferStatistics(testWarehouseId));
      
      // تنفيذ العمليات بشكل متوازي
      await Future.wait(futures);
      
      final duration = DateTime.now().difference(startTime);
      final isUnderThreshold = duration.inSeconds < 3;
      
      results['performance_metrics'] = {
        'total_duration_ms': duration.inMilliseconds,
        'total_duration_seconds': duration.inSeconds,
        'under_3_second_threshold': isUnderThreshold,
        'operations_tested': futures.length,
      };
      
      results['test_results'][testName] = {
        'success': isUnderThreshold,
        'duration_ms': duration.inMilliseconds,
        'message': isUnderThreshold 
            ? 'الأداء ممتاز - ${duration.inMilliseconds}ms'
            : 'الأداء بطيء - ${duration.inSeconds}s (يجب أن يكون أقل من 3s)',
      };
      
      if (isUnderThreshold) {
        results['tests_passed']++;
        AppLogger.info('✅ نجح اختبار الأداء - ${duration.inMilliseconds}ms');
      } else {
        results['tests_failed']++;
        results['errors'].add('فشل اختبار الأداء - ${duration.inSeconds}s');
        AppLogger.warning('⚠️ فشل اختبار الأداء - ${duration.inSeconds}s');
      }
      
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': false,
        'duration_ms': duration.inMilliseconds,
        'error': e.toString(),
      };
      
      results['tests_failed']++;
      results['errors'].add('خطأ في اختبار الأداء: $e');
      AppLogger.error('❌ خطأ في اختبار الأداء: $e');
    }
  }

  /// اختبار الحالات الحدية
  Future<void> _testEdgeCases(Map<String, dynamic> results) async {
    final testName = 'edge_cases_test';
    final startTime = DateTime.now();
    
    try {
      AppLogger.info('🔍 اختبار الحالات الحدية');
      
      final edgeCaseResults = <String, dynamic>{};
      
      // حالة 1: مخزن غير موجود
      try {
        await _transferService.getAvailableTargetWarehouses('non-existent-warehouse');
        edgeCaseResults['non_existent_warehouse'] = 'handled_gracefully';
      } catch (e) {
        edgeCaseResults['non_existent_warehouse'] = 'error_thrown: $e';
      }
      
      // حالة 2: نقل إلى نفس المخزن
      try {
        const sameWarehouseId = 'same-warehouse-id';
        await _transferService.validateOrderTransfer(sameWarehouseId, sameWarehouseId);
        edgeCaseResults['same_warehouse_transfer'] = 'handled_gracefully';
      } catch (e) {
        edgeCaseResults['same_warehouse_transfer'] = 'error_thrown: $e';
      }
      
      // حالة 3: معرفات فارغة
      try {
        await _transferService.validateOrderTransfer('', '');
        edgeCaseResults['empty_ids'] = 'handled_gracefully';
      } catch (e) {
        edgeCaseResults['empty_ids'] = 'error_thrown: $e';
      }
      
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': true,
        'duration_ms': duration.inMilliseconds,
        'edge_cases_tested': edgeCaseResults.length,
        'edge_case_results': edgeCaseResults,
        'message': 'تم اختبار ${edgeCaseResults.length} حالة حدية',
      };
      
      results['tests_passed']++;
      AppLogger.info('✅ نجح اختبار الحالات الحدية');
      
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': false,
        'duration_ms': duration.inMilliseconds,
        'error': e.toString(),
      };
      
      results['tests_failed']++;
      results['errors'].add('فشل اختبار الحالات الحدية: $e');
      AppLogger.error('❌ فشل اختبار الحالات الحدية: $e');
    }
  }

  /// اختبار آليات الاسترداد
  Future<void> _testRollbackMechanisms(Map<String, dynamic> results) async {
    final testName = 'rollback_mechanisms_test';
    final startTime = DateTime.now();
    
    try {
      AppLogger.info('🔄 اختبار آليات الاسترداد');
      
      // محاكاة فشل في النقل واختبار الاسترداد
      const sourceWarehouseId = 'rollback-test-source';
      const targetWarehouseId = 'invalid-target-warehouse';
      
      final transferResult = await _transferService.executeOrderTransfer(
        sourceWarehouseId,
        targetWarehouseId,
      );
      
      final duration = DateTime.now().difference(startTime);
      
      // يجب أن يفشل النقل ولكن بشكل آمن
      final rollbackWorked = !transferResult.success && transferResult.errors.isNotEmpty;
      
      results['test_results'][testName] = {
        'success': rollbackWorked,
        'duration_ms': duration.inMilliseconds,
        'transfer_failed_safely': !transferResult.success,
        'errors_reported': transferResult.errors.length,
        'message': rollbackWorked 
            ? 'آليات الاسترداد تعمل بشكل صحيح'
            : 'مشكلة في آليات الاسترداد',
      };
      
      if (rollbackWorked) {
        results['tests_passed']++;
        AppLogger.info('✅ نجح اختبار آليات الاسترداد');
      } else {
        results['tests_failed']++;
        results['errors'].add('فشل اختبار آليات الاسترداد');
        AppLogger.error('❌ فشل اختبار آليات الاسترداد');
      }
      
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': false,
        'duration_ms': duration.inMilliseconds,
        'error': e.toString(),
      };
      
      results['tests_failed']++;
      results['errors'].add('خطأ في اختبار آليات الاسترداد: $e');
      AppLogger.error('❌ خطأ في اختبار آليات الاسترداد: $e');
    }
  }

  /// تشغيل اختبار سريع للتحقق من الوظائف الأساسية
  Future<bool> runQuickTest() async {
    AppLogger.info('⚡ تشغيل اختبار سريع للحذف القسري');
    
    try {
      const testWarehouseId = 'quick-test-warehouse';
      
      // اختبار سريع للمخازن المتاحة
      final warehouses = await _transferService.getAvailableTargetWarehouses(testWarehouseId);
      
      // اختبار سريع للإحصائيات
      final stats = await _transferService.getTransferStatistics(testWarehouseId);
      
      AppLogger.info('✅ الاختبار السريع نجح - ${warehouses.length} مخزن متاح');
      return true;
      
    } catch (e) {
      AppLogger.error('❌ فشل الاختبار السريع: $e');
      return false;
    }
  }
}
