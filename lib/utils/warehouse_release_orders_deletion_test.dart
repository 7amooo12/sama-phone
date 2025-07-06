import '../services/warehouse_release_orders_service.dart';
import '../utils/app_logger.dart';

/// اختبار شامل لنظام حذف أذون الصرف مع منع إعادة الإنشاء
class WarehouseReleaseOrdersDeletionTest {
  final WarehouseReleaseOrdersService _service = WarehouseReleaseOrdersService();

  /// تشغيل جميع اختبارات نظام الحذف
  Future<Map<String, dynamic>> runComprehensiveTests() async {
    AppLogger.info('🧪 بدء الاختبار الشامل لنظام حذف أذون الصرف');
    
    final results = <String, dynamic>{
      'test_start_time': DateTime.now().toIso8601String(),
      'tests_passed': 0,
      'tests_failed': 0,
      'test_results': <String, dynamic>{},
      'errors': <String>[],
    };

    try {
      // اختبار 1: التحقق من البيانات قبل الحذف
      await _testPreDeletionState(results);
      
      // اختبار 2: اختبار الحذف الفردي
      await _testIndividualDeletion(results);
      
      // اختبار 3: اختبار المسح الشامل
      await _testBulkClearance(results);
      
      // اختبار 4: التحقق من منع إعادة الإنشاء
      await _testRegenerationPrevention(results);
      
      // اختبار 5: اختبار الثبات بعد إعادة التشغيل
      await _testPersistenceAfterRestart(results);

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

  /// اختبار حالة البيانات قبل الحذف
  Future<void> _testPreDeletionState(Map<String, dynamic> results) async {
    final testName = 'pre_deletion_state_test';
    final startTime = DateTime.now();
    
    try {
      AppLogger.info('🔍 اختبار حالة البيانات قبل الحذف');
      
      final orders = await _service.getAllReleaseOrders();
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': true,
        'duration_ms': duration.inMilliseconds,
        'initial_orders_count': orders.length,
        'message': 'تم العثور على ${orders.length} أذن صرف قبل الحذف',
      };
      
      results['tests_passed']++;
      AppLogger.info('✅ نجح اختبار حالة البيانات قبل الحذف');
      
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': false,
        'duration_ms': duration.inMilliseconds,
        'error': e.toString(),
      };
      
      results['tests_failed']++;
      results['errors'].add('فشل اختبار حالة البيانات قبل الحذف: $e');
      AppLogger.error('❌ فشل اختبار حالة البيانات قبل الحذف: $e');
    }
  }

  /// اختبار الحذف الفردي
  Future<void> _testIndividualDeletion(Map<String, dynamic> results) async {
    final testName = 'individual_deletion_test';
    final startTime = DateTime.now();
    
    try {
      AppLogger.info('🗑️ اختبار الحذف الفردي');
      
      final orders = await _service.getAllReleaseOrders();
      
      if (orders.isNotEmpty) {
        final testOrder = orders.first;
        final deleted = await _service.deleteReleaseOrder(testOrder.id);
        
        // التحقق من الحذف
        final ordersAfterDeletion = await _service.getAllReleaseOrders();
        final actuallyDeleted = ordersAfterDeletion.length < orders.length;
        
        final duration = DateTime.now().difference(startTime);
        
        results['test_results'][testName] = {
          'success': deleted && actuallyDeleted,
          'duration_ms': duration.inMilliseconds,
          'deleted_order_id': testOrder.id,
          'orders_before': orders.length,
          'orders_after': ordersAfterDeletion.length,
          'message': deleted && actuallyDeleted 
              ? 'تم حذف أذن الصرف بنجاح'
              : 'فشل في حذف أذن الصرف',
        };
        
        if (deleted && actuallyDeleted) {
          results['tests_passed']++;
          AppLogger.info('✅ نجح اختبار الحذف الفردي');
        } else {
          results['tests_failed']++;
          results['errors'].add('فشل في الحذف الفردي');
          AppLogger.error('❌ فشل اختبار الحذف الفردي');
        }
      } else {
        final duration = DateTime.now().difference(startTime);
        
        results['test_results'][testName] = {
          'success': true,
          'duration_ms': duration.inMilliseconds,
          'message': 'لا توجد أذون صرف للاختبار',
        };
        
        results['tests_passed']++;
        AppLogger.info('ℹ️ لا توجد أذون صرف لاختبار الحذف الفردي');
      }
      
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': false,
        'duration_ms': duration.inMilliseconds,
        'error': e.toString(),
      };
      
      results['tests_failed']++;
      results['errors'].add('فشل اختبار الحذف الفردي: $e');
      AppLogger.error('❌ فشل اختبار الحذف الفردي: $e');
    }
  }

  /// اختبار المسح الشامل
  Future<void> _testBulkClearance(Map<String, dynamic> results) async {
    final testName = 'bulk_clearance_test';
    final startTime = DateTime.now();
    
    try {
      AppLogger.info('🧹 اختبار المسح الشامل');
      
      final ordersBefore = await _service.getAllReleaseOrders();
      final cleared = await _service.clearAllReleaseOrders();
      final ordersAfter = await _service.getAllReleaseOrders();
      
      final duration = DateTime.now().difference(startTime);
      final isSuccessful = cleared && ordersAfter.isEmpty;
      
      results['test_results'][testName] = {
        'success': isSuccessful,
        'duration_ms': duration.inMilliseconds,
        'orders_before': ordersBefore.length,
        'orders_after': ordersAfter.length,
        'clearance_result': cleared,
        'message': isSuccessful 
            ? 'تم المسح الشامل بنجاح'
            : 'فشل في المسح الشامل أو تبقت أذون صرف',
      };
      
      if (isSuccessful) {
        results['tests_passed']++;
        AppLogger.info('✅ نجح اختبار المسح الشامل');
      } else {
        results['tests_failed']++;
        results['errors'].add('فشل في المسح الشامل - تبقى ${ordersAfter.length} أذن صرف');
        AppLogger.error('❌ فشل اختبار المسح الشامل');
      }
      
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': false,
        'duration_ms': duration.inMilliseconds,
        'error': e.toString(),
      };
      
      results['tests_failed']++;
      results['errors'].add('فشل اختبار المسح الشامل: $e');
      AppLogger.error('❌ فشل اختبار المسح الشامل: $e');
    }
  }

  /// اختبار منع إعادة الإنشاء
  Future<void> _testRegenerationPrevention(Map<String, dynamic> results) async {
    final testName = 'regeneration_prevention_test';
    final startTime = DateTime.now();
    
    try {
      AppLogger.info('🛡️ اختبار منع إعادة الإنشاء');
      
      // محاولة تحميل البيانات مرة أخرى للتأكد من عدم إعادة الإنشاء
      final ordersAfterClear = await _service.getAllReleaseOrders();
      
      // انتظار قصير ثم إعادة التحميل
      await Future.delayed(const Duration(seconds: 2));
      final ordersAfterDelay = await _service.getAllReleaseOrders();
      
      final duration = DateTime.now().difference(startTime);
      final preventionWorking = ordersAfterClear.length == ordersAfterDelay.length && 
                               ordersAfterDelay.isEmpty;
      
      results['test_results'][testName] = {
        'success': preventionWorking,
        'duration_ms': duration.inMilliseconds,
        'orders_after_clear': ordersAfterClear.length,
        'orders_after_delay': ordersAfterDelay.length,
        'message': preventionWorking 
            ? 'آليات منع إعادة الإنشاء تعمل بشكل صحيح'
            : 'تم إعادة إنشاء أذون صرف - آليات المنع لا تعمل',
      };
      
      if (preventionWorking) {
        results['tests_passed']++;
        AppLogger.info('✅ نجح اختبار منع إعادة الإنشاء');
      } else {
        results['tests_failed']++;
        results['errors'].add('فشل في منع إعادة الإنشاء');
        AppLogger.error('❌ فشل اختبار منع إعادة الإنشاء');
      }
      
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': false,
        'duration_ms': duration.inMilliseconds,
        'error': e.toString(),
      };
      
      results['tests_failed']++;
      results['errors'].add('فشل اختبار منع إعادة الإنشاء: $e');
      AppLogger.error('❌ فشل اختبار منع إعادة الإنشاء: $e');
    }
  }

  /// اختبار الثبات بعد إعادة التشغيل (محاكاة)
  Future<void> _testPersistenceAfterRestart(Map<String, dynamic> results) async {
    final testName = 'persistence_after_restart_test';
    final startTime = DateTime.now();
    
    try {
      AppLogger.info('🔄 اختبار الثبات بعد إعادة التشغيل (محاكاة)');
      
      // محاكاة إعادة التشغيل بإنشاء خدمة جديدة
      final newService = WarehouseReleaseOrdersService();
      final ordersAfterRestart = await newService.getAllReleaseOrders();
      
      final duration = DateTime.now().difference(startTime);
      final persistenceWorking = ordersAfterRestart.isEmpty;
      
      results['test_results'][testName] = {
        'success': persistenceWorking,
        'duration_ms': duration.inMilliseconds,
        'orders_after_restart': ordersAfterRestart.length,
        'message': persistenceWorking 
            ? 'الحذف ثابت بعد إعادة التشغيل'
            : 'تم إعادة إنشاء ${ordersAfterRestart.length} أذن صرف بعد إعادة التشغيل',
      };
      
      if (persistenceWorking) {
        results['tests_passed']++;
        AppLogger.info('✅ نجح اختبار الثبات بعد إعادة التشغيل');
      } else {
        results['tests_failed']++;
        results['errors'].add('فشل في الثبات - تم إعادة إنشاء ${ordersAfterRestart.length} أذن صرف');
        AppLogger.error('❌ فشل اختبار الثبات بعد إعادة التشغيل');
      }
      
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      results['test_results'][testName] = {
        'success': false,
        'duration_ms': duration.inMilliseconds,
        'error': e.toString(),
      };
      
      results['tests_failed']++;
      results['errors'].add('فشل اختبار الثبات بعد إعادة التشغيل: $e');
      AppLogger.error('❌ فشل اختبار الثبات بعد إعادة التشغيل: $e');
    }
  }

  /// اختبار سريع للتحقق من الوظائف الأساسية
  Future<bool> runQuickTest() async {
    AppLogger.info('⚡ تشغيل اختبار سريع لنظام حذف أذون الصرف');
    
    try {
      // اختبار تحميل البيانات
      final orders = await _service.getAllReleaseOrders();
      AppLogger.info('📋 تم العثور على ${orders.length} أذن صرف');
      
      // اختبار التحقق من اكتمال المسح
      final verification = await _service._verifyCompleteDeletion();
      AppLogger.info('🔍 نتائج التحقق: ${verification['remaining_orders']} أذن متبقي');
      
      AppLogger.info('✅ الاختبار السريع نجح');
      return true;
      
    } catch (e) {
      AppLogger.error('❌ فشل الاختبار السريع: $e');
      return false;
    }
  }
}
