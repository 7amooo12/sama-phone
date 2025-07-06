import '../services/api_product_sync_service.dart';
import '../services/api_service.dart';
import '../services/flask_api_service.dart';
import '../services/unified_products_service.dart';
import 'app_logger.dart';

/// مساعد لاختبار تكامل APIs وجودة البيانات
class ApiIntegrationTestHelper {
  static final ApiProductSyncService _syncService = ApiProductSyncService();
  static final ApiService _apiService = ApiService();
  static final FlaskApiService _flaskService = FlaskApiService();
  static final UnifiedProductsService _unifiedService = UnifiedProductsService();

  /// اختبار شامل لتكامل APIs وجودة البيانات
  static Future<ApiIntegrationTestResult> runComprehensiveTest() async {
    AppLogger.info('🧪 بدء اختبار شامل لتكامل APIs...');

    final result = ApiIntegrationTestResult();
    
    try {
      // اختبار API الأساسي
      await _testMainApi(result);
      
      // اختبار Flask API
      await _testFlaskApi(result);
      
      // اختبار Unified API
      await _testUnifiedApi(result);
      
      // اختبار جودة البيانات
      await _testDataQuality(result);
      
      // اختبار تحسين المنتجات
      await _testProductEnhancement(result);

      result.overallSuccess = result.mainApiSuccess && 
                             result.flaskApiSuccess && 
                             result.unifiedApiSuccess &&
                             result.dataQualityGood;

      AppLogger.info('🎉 انتهى الاختبار الشامل:');
      AppLogger.info('   API الأساسي: ${result.mainApiSuccess ? "✅" : "❌"}');
      AppLogger.info('   Flask API: ${result.flaskApiSuccess ? "✅" : "❌"}');
      AppLogger.info('   Unified API: ${result.unifiedApiSuccess ? "✅" : "❌"}');
      AppLogger.info('   جودة البيانات: ${result.dataQualityGood ? "✅" : "❌"}');
      AppLogger.info('   النتيجة الإجمالية: ${result.overallSuccess ? "✅ نجح" : "❌ فشل"}');

    } catch (e) {
      AppLogger.error('❌ خطأ في الاختبار الشامل: $e');
      result.overallSuccess = false;
      result.errors.add('خطأ عام في الاختبار: $e');
    }

    return result;
  }

  /// اختبار API الأساسي
  static Future<void> _testMainApi(ApiIntegrationTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار API الأساسي...');
      
      final products = await _apiService.getProducts();
      
      if (products.isNotEmpty) {
        result.mainApiSuccess = true;
        result.mainApiProductCount = products.length;
        
        // اختبار جودة البيانات
        int realProductsCount = 0;
        for (final product in products.take(10)) { // اختبار أول 10 منتجات
          if (!_isGenericProductName(product.name)) {
            realProductsCount++;
          }
        }
        
        result.mainApiRealProductsRatio = realProductsCount / 10.0;
        AppLogger.info('✅ API الأساسي: ${products.length} منتج، نسبة المنتجات الحقيقية: ${(result.mainApiRealProductsRatio * 100).toStringAsFixed(1)}%');
      } else {
        result.mainApiSuccess = false;
        result.errors.add('API الأساسي لم يرجع أي منتجات');
      }
    } catch (e) {
      result.mainApiSuccess = false;
      result.errors.add('خطأ في API الأساسي: $e');
      AppLogger.error('❌ خطأ في اختبار API الأساسي: $e');
    }
  }

  /// اختبار Flask API
  static Future<void> _testFlaskApi(ApiIntegrationTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار Flask API...');
      
      final products = await _flaskService.getProducts();
      
      if (products.isNotEmpty) {
        result.flaskApiSuccess = true;
        result.flaskApiProductCount = products.length;
        
        // اختبار جودة البيانات
        int realProductsCount = 0;
        for (final product in products.take(10)) { // اختبار أول 10 منتجات
          if (!_isGenericProductName(product.name)) {
            realProductsCount++;
          }
        }
        
        result.flaskApiRealProductsRatio = realProductsCount / 10.0;
        AppLogger.info('✅ Flask API: ${products.length} منتج، نسبة المنتجات الحقيقية: ${(result.flaskApiRealProductsRatio * 100).toStringAsFixed(1)}%');
      } else {
        result.flaskApiSuccess = false;
        result.errors.add('Flask API لم يرجع أي منتجات');
      }
    } catch (e) {
      result.flaskApiSuccess = false;
      result.errors.add('خطأ في Flask API: $e');
      AppLogger.error('❌ خطأ في اختبار Flask API: $e');
    }
  }

  /// اختبار Unified API
  static Future<void> _testUnifiedApi(ApiIntegrationTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار Unified API...');
      
      final products = await _unifiedService.getProducts();
      
      if (products.isNotEmpty) {
        result.unifiedApiSuccess = true;
        result.unifiedApiProductCount = products.length;
        
        // اختبار جودة البيانات
        int realProductsCount = 0;
        for (final product in products.take(10)) { // اختبار أول 10 منتجات
          if (!_isGenericProductName(product.name)) {
            realProductsCount++;
          }
        }
        
        result.unifiedApiRealProductsRatio = realProductsCount / 10.0;
        AppLogger.info('✅ Unified API: ${products.length} منتج، نسبة المنتجات الحقيقية: ${(result.unifiedApiRealProductsRatio * 100).toStringAsFixed(1)}%');
      } else {
        result.unifiedApiSuccess = false;
        result.errors.add('Unified API لم يرجع أي منتجات');
      }
    } catch (e) {
      result.unifiedApiSuccess = false;
      result.errors.add('خطأ في Unified API: $e');
      AppLogger.error('❌ خطأ في اختبار Unified API: $e');
    }
  }

  /// اختبار جودة البيانات
  static Future<void> _testDataQuality(ApiIntegrationTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار جودة البيانات...');
      
      // حساب متوسط جودة البيانات من جميع APIs
      final ratios = [
        result.mainApiRealProductsRatio,
        result.flaskApiRealProductsRatio,
        result.unifiedApiRealProductsRatio,
      ].where((ratio) => ratio > 0).toList();
      
      if (ratios.isNotEmpty) {
        final averageRatio = ratios.reduce((a, b) => a + b) / ratios.length;
        result.overallDataQualityRatio = averageRatio;
        result.dataQualityGood = averageRatio >= 0.8; // 80% أو أكثر من المنتجات حقيقية
        
        AppLogger.info('✅ جودة البيانات الإجمالية: ${(averageRatio * 100).toStringAsFixed(1)}%');
      } else {
        result.dataQualityGood = false;
        result.errors.add('لا توجد بيانات كافية لتقييم الجودة');
      }
    } catch (e) {
      result.dataQualityGood = false;
      result.errors.add('خطأ في اختبار جودة البيانات: $e');
      AppLogger.error('❌ خطأ في اختبار جودة البيانات: $e');
    }
  }

  /// اختبار تحسين المنتجات
  static Future<void> _testProductEnhancement(ApiIntegrationTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار تحسين المنتجات...');
      
      // اختبار تحسين منتج بمعرف تجريبي
      final testProductId = '1';
      final enhancedProduct = await _syncService.getProductFromApi(testProductId);
      
      if (enhancedProduct != null) {
        final productName = enhancedProduct['name']?.toString() ?? '';
        final isRealData = !_isGenericProductName(productName);
        
        result.productEnhancementWorks = isRealData;
        result.enhancedProductName = productName;
        
        if (isRealData) {
          AppLogger.info('✅ تحسين المنتجات يعمل بشكل صحيح: $productName');
        } else {
          AppLogger.warning('⚠️ تحسين المنتجات لا يزال يرجع بيانات عامة: $productName');
        }
      } else {
        result.productEnhancementWorks = false;
        result.errors.add('فشل في تحسين المنتج التجريبي');
      }
    } catch (e) {
      result.productEnhancementWorks = false;
      result.errors.add('خطأ في اختبار تحسين المنتجات: $e');
      AppLogger.error('❌ خطأ في اختبار تحسين المنتجات: $e');
    }
  }

  /// التحقق من كون اسم المنتج عام
  static bool _isGenericProductName(String productName) {
    if (productName.isEmpty) return true;
    
    final genericPatterns = [
      'منتج تجريبي',
      'منتج افتراضي',
      'منتج غير معروف',
      'منتج غير محدد',
      RegExp(r'^منتج \d+$'), // منتج + رقم
      RegExp(r'^منتج \d+ من API$'), // منتج + رقم + من API
      RegExp(r'^منتج رقم \d+$'), // منتج رقم + رقم
      RegExp(r'^Product \d+$'), // Product + number
      RegExp(r'^Product \d+ from API$'), // Product + number + from API
    ];

    for (final pattern in genericPatterns) {
      if (pattern is String) {
        if (productName.contains(pattern)) {
          return true;
        }
      } else if (pattern is RegExp) {
        if (pattern.hasMatch(productName)) {
          return true;
        }
      }
    }

    return false;
  }
}

/// نتيجة اختبار تكامل APIs
class ApiIntegrationTestResult {
  bool mainApiSuccess = false;
  bool flaskApiSuccess = false;
  bool unifiedApiSuccess = false;
  bool dataQualityGood = false;
  bool productEnhancementWorks = false;
  bool overallSuccess = false;

  int mainApiProductCount = 0;
  int flaskApiProductCount = 0;
  int unifiedApiProductCount = 0;

  double mainApiRealProductsRatio = 0.0;
  double flaskApiRealProductsRatio = 0.0;
  double unifiedApiRealProductsRatio = 0.0;
  double overallDataQualityRatio = 0.0;

  String enhancedProductName = '';
  List<String> errors = [];

  /// تقرير مفصل عن النتائج
  String get detailedReport {
    final buffer = StringBuffer();
    buffer.writeln('=== تقرير اختبار تكامل APIs ===');
    buffer.writeln('');
    buffer.writeln('APIs المتاحة:');
    buffer.writeln('  • API الأساسي: ${mainApiSuccess ? "✅" : "❌"} ($mainApiProductCount منتج)');
    buffer.writeln('  • Flask API: ${flaskApiSuccess ? "✅" : "❌"} ($flaskApiProductCount منتج)');
    buffer.writeln('  • Unified API: ${unifiedApiSuccess ? "✅" : "❌"} ($unifiedApiProductCount منتج)');
    buffer.writeln('');
    buffer.writeln('جودة البيانات:');
    buffer.writeln('  • API الأساسي: ${(mainApiRealProductsRatio * 100).toStringAsFixed(1)}%');
    buffer.writeln('  • Flask API: ${(flaskApiRealProductsRatio * 100).toStringAsFixed(1)}%');
    buffer.writeln('  • Unified API: ${(unifiedApiRealProductsRatio * 100).toStringAsFixed(1)}%');
    buffer.writeln('  • الإجمالي: ${(overallDataQualityRatio * 100).toStringAsFixed(1)}%');
    buffer.writeln('');
    buffer.writeln('تحسين المنتجات: ${productEnhancementWorks ? "✅" : "❌"}');
    if (enhancedProductName.isNotEmpty) {
      buffer.writeln('  مثال: $enhancedProductName');
    }
    buffer.writeln('');
    buffer.writeln('النتيجة الإجمالية: ${overallSuccess ? "✅ نجح" : "❌ فشل"}');
    
    if (errors.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('الأخطاء:');
      for (final error in errors) {
        buffer.writeln('  • $error');
      }
    }
    
    return buffer.toString();
  }
}
