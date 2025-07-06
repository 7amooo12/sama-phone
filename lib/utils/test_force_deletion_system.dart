import 'warehouse_force_deletion_test.dart';
import 'app_logger.dart';

/// تشغيل اختبار نظام الحذف القسري للمخازن
Future<void> testForceDeletionSystem() async {
  AppLogger.info('🧪 بدء اختبار نظام الحذف القسري للمخازن');
  
  final tester = WarehouseForceDeletionTest();
  
  try {
    // تشغيل الاختبار السريع أولاً
    AppLogger.info('⚡ تشغيل الاختبار السريع...');
    final quickTestResult = await tester.runQuickTest();
    
    if (quickTestResult) {
      AppLogger.info('✅ الاختبار السريع نجح - النظام يعمل بشكل أساسي');
      
      // تشغيل الاختبار الشامل
      AppLogger.info('🔍 تشغيل الاختبار الشامل...');
      final comprehensiveResults = await tester.runComprehensiveTests();
      
      // طباعة النتائج
      _printTestResults(comprehensiveResults);
      
    } else {
      AppLogger.error('❌ فشل الاختبار السريع - يرجى التحقق من الإعدادات');
    }
    
  } catch (e) {
    AppLogger.error('❌ خطأ في تشغيل اختبار النظام: $e');
  }
}

/// طباعة نتائج الاختبار
void _printTestResults(Map<String, dynamic> results) {
  AppLogger.info('📊 نتائج الاختبار الشامل:');
  AppLogger.info('   النجح: ${results['tests_passed']}');
  AppLogger.info('   فشل: ${results['tests_failed']}');
  AppLogger.info('   النجاح العام: ${results['overall_success']}');
  
  if (results['performance_metrics'] != null) {
    final perf = results['performance_metrics'];
    AppLogger.info('⏱️ مقاييس الأداء:');
    AppLogger.info('   المدة الإجمالية: ${perf['total_duration_ms']}ms');
    AppLogger.info('   أقل من 3 ثوانٍ: ${perf['under_3_second_threshold']}');
  }
  
  if (results['errors'] != null && results['errors'].isNotEmpty) {
    AppLogger.error('❌ الأخطاء:');
    for (final error in results['errors']) {
      AppLogger.error('   - $error');
    }
  }
  
  AppLogger.info('🎯 ملخص: نظام الحذف القسري ${results['overall_success'] ? 'جاهز للاستخدام' : 'يحتاج إلى إصلاحات'}');
}

/// اختبار سريع يمكن استدعاؤه من أي مكان
Future<bool> quickTestForceDeletion() async {
  try {
    final tester = WarehouseForceDeletionTest();
    return await tester.runQuickTest();
  } catch (e) {
    AppLogger.error('❌ خطأ في الاختبار السريع: $e');
    return false;
  }
}
