import '../services/api_product_sync_service.dart';
import 'app_logger.dart';
import 'api_integration_test_helper.dart';

/// مساعد اختبار تكامل API
class ApiTestHelper {
  static final ApiProductSyncService _apiService = ApiProductSyncService();

  /// اختبار تحميل منتج من API المحسن
  static Future<void> testEnhancedApiIntegration(String productId) async {
    try {
      AppLogger.info('🧪 بدء اختبار تكامل API المحسن للمنتج: $productId');

      final startTime = DateTime.now();
      final productData = await _apiService.getProductFromApi(productId);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      if (productData != null) {
        AppLogger.info('✅ نجح اختبار API - المدة: ${duration.inMilliseconds}ms');
        _logProductData(productData);
        _validateProductData(productData);
      } else {
        AppLogger.error('❌ فشل اختبار API - لم يتم إرجاع بيانات');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار API: $e');
    }
  }

  /// تسجيل بيانات المنتج
  static void _logProductData(Map<String, dynamic> productData) {
    AppLogger.info('📊 بيانات المنتج المستلمة:');
    AppLogger.info('   الاسم: ${productData['name']}');
    AppLogger.info('   الوصف: ${productData['description']}');
    AppLogger.info('   السعر: ${productData['price']}');
    AppLogger.info('   الفئة: ${productData['category']}');
    AppLogger.info('   المورد: ${productData['supplier']}');
    AppLogger.info('   الكمية: ${productData['quantity']}');
    AppLogger.info('   الصور: ${productData['images']?.length ?? 0}');
    AppLogger.info('   العلامات: ${productData['tags']?.length ?? 0}');
  }

  /// التحقق من صحة بيانات المنتج
  static void _validateProductData(Map<String, dynamic> productData) {
    final issues = <String>[];

    // التحقق من الاسم
    final name = productData['name']?.toString() ?? '';
    if (name.isEmpty) {
      issues.add('اسم المنتج فارغ');
    } else if (name.contains('منتج') && name.contains('من API')) {
      issues.add('اسم المنتج عام (${name})');
    }

    // التحقق من الوصف
    final description = productData['description']?.toString() ?? '';
    if (description.isEmpty) {
      issues.add('وصف المنتج فارغ');
    } else if (description.contains('تم إنشاؤه تلقائياً')) {
      issues.add('وصف المنتج عام');
    }

    // التحقق من السعر
    final price = productData['price'];
    if (price == null || price == 0) {
      issues.add('سعر المنتج غير محدد');
    }

    // التحقق من الفئة
    final category = productData['category']?.toString() ?? '';
    if (category.isEmpty || category == 'عام') {
      issues.add('فئة المنتج عامة');
    }

    // التحقق من الصورة
    final imageUrl = productData['image_url']?.toString() ?? '';
    if (imageUrl.isEmpty) {
      issues.add('لا توجد صورة للمنتج');
    } else if (imageUrl.contains('placeholder')) {
      issues.add('صورة المنتج عامة');
    }

    // عرض النتائج
    if (issues.isEmpty) {
      AppLogger.info('✅ جميع بيانات المنتج صحيحة ومحسنة');
    } else {
      AppLogger.warning('⚠️ مشاكل في بيانات المنتج:');
      for (final issue in issues) {
        AppLogger.warning('   - $issue');
      }
    }
  }

  /// اختبار عدة منتجات
  static Future<void> testMultipleProducts(List<String> productIds) async {
    AppLogger.info('🧪 اختبار ${productIds.length} منتج...');

    int successCount = 0;
    int failureCount = 0;

    for (final productId in productIds) {
      try {
        await testEnhancedApiIntegration(productId);
        successCount++;
      } catch (e) {
        failureCount++;
        AppLogger.error('❌ فشل اختبار المنتج $productId: $e');
      }

      // تأخير قصير بين الطلبات
      await Future.delayed(const Duration(milliseconds: 100));
    }

    AppLogger.info('📊 نتائج الاختبار:');
    AppLogger.info('   نجح: $successCount');
    AppLogger.info('   فشل: $failureCount');
    AppLogger.info('   معدل النجاح: ${(successCount / productIds.length * 100).toStringAsFixed(1)}%');
  }

  /// اختبار أداء API
  static Future<void> testApiPerformance(String productId, {int iterations = 10}) async {
    AppLogger.info('⚡ اختبار أداء API للمنتج $productId ($iterations مرة)...');

    final durations = <int>[];
    int successCount = 0;

    for (int i = 0; i < iterations; i++) {
      try {
        final startTime = DateTime.now();
        final productData = await _apiService.getProductFromApi(productId);
        final endTime = DateTime.now();
        
        final duration = endTime.difference(startTime).inMilliseconds;
        durations.add(duration);

        if (productData != null) {
          successCount++;
        }
      } catch (e) {
        AppLogger.error('❌ خطأ في التكرار ${i + 1}: $e');
      }
    }

    if (durations.isNotEmpty) {
      final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
      final minDuration = durations.reduce((a, b) => a < b ? a : b);
      final maxDuration = durations.reduce((a, b) => a > b ? a : b);

      AppLogger.info('📊 نتائج اختبار الأداء:');
      AppLogger.info('   متوسط الوقت: ${avgDuration.toStringAsFixed(1)}ms');
      AppLogger.info('   أسرع وقت: ${minDuration}ms');
      AppLogger.info('   أبطأ وقت: ${maxDuration}ms');
      AppLogger.info('   معدل النجاح: ${(successCount / iterations * 100).toStringAsFixed(1)}%');
    }
  }

  /// اختبار شامل للنظام
  static Future<void> runComprehensiveTest() async {
    AppLogger.info('🚀 بدء الاختبار الشامل لنظام API المحسن...');

    // اختبار منتجات مختلفة
    final testProductIds = ['1', '7', '20', '50', '100'];

    AppLogger.info('📋 المرحلة 1: اختبار منتجات متعددة');
    await testMultipleProducts(testProductIds);

    AppLogger.info('📋 المرحلة 2: اختبار الأداء');
    await testApiPerformance('7', iterations: 5);

    AppLogger.info('📋 المرحلة 3: اختبار التحسين');
    for (final productId in testProductIds.take(3)) {
      await testEnhancedApiIntegration(productId);
    }

    AppLogger.info('📋 المرحلة 4: اختبار تكامل APIs الشامل');
    final integrationResult = await ApiIntegrationTestHelper.runComprehensiveTest();
    AppLogger.info('📊 تقرير التكامل:');
    AppLogger.info(integrationResult.detailedReport);

    AppLogger.info('✅ انتهى الاختبار الشامل');
  }
}

/// إضافة دالة مساعدة للاختبار السريع
Future<void> quickApiTest(String productId) async {
  await ApiTestHelper.testEnhancedApiIntegration(productId);
}
