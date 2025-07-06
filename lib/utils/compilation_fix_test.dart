import '../services/api_product_sync_service.dart';
import '../models/product_model.dart';
import '../models/flask_product_model.dart';
import 'app_logger.dart';

/// اختبار إصلاح أخطاء التجميع في نظام تكامل APIs
class CompilationFixTest {
  static final ApiProductSyncService _syncService = ApiProductSyncService();

  /// اختبار شامل لإصلاح أخطاء التجميع
  static Future<CompilationTestResult> runCompilationTest() async {
    AppLogger.info('🔧 بدء اختبار إصلاح أخطاء التجميع...');

    final result = CompilationTestResult();
    
    try {
      // اختبار ProductModel الجديد
      await _testProductModel(result);
      
      // اختبار FlaskProductModel المحسن
      await _testFlaskProductModel(result);
      
      // اختبار تكامل API
      await _testApiIntegration(result);

      result.overallSuccess = result.productModelTest && 
                             result.flaskModelTest && 
                             result.apiIntegrationTest;

      AppLogger.info('🎉 انتهى اختبار إصلاح التجميع:');
      AppLogger.info('   ProductModel: ${result.productModelTest ? "✅" : "❌"}');
      AppLogger.info('   FlaskProductModel: ${result.flaskModelTest ? "✅" : "❌"}');
      AppLogger.info('   API Integration: ${result.apiIntegrationTest ? "✅" : "❌"}');
      AppLogger.info('   النتيجة الإجمالية: ${result.overallSuccess ? "✅ نجح" : "❌ فشل"}');

    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار التجميع: $e');
      result.overallSuccess = false;
      result.errors.add('خطأ عام في الاختبار: $e');
    }

    return result;
  }

  /// اختبار ProductModel الجديد
  static Future<void> _testProductModel(CompilationTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار ProductModel...');
      
      // إنشاء منتج تجريبي
      final product = ProductModel(
        id: 'test_1',
        name: 'منتج تجريبي',
        description: 'وصف المنتج التجريبي',
        price: 100.0,
        quantity: 50,
        category: 'إلكترونيات',
        isActive: true,
        sku: 'TEST-001',
        reorderPoint: 10,
        images: ['https://example.com/image.jpg'],
        createdAt: DateTime.now(),
        barcode: '1234567890123',
        manufacturer: 'شركة تجريبية',
      );

      // اختبار الخصائص الجديدة
      final hasBarcode = product.barcode != null;
      final hasManufacturer = product.manufacturer != null;
      
      if (hasBarcode && hasManufacturer) {
        result.productModelTest = true;
        AppLogger.info('✅ ProductModel: جميع الخصائص متاحة');
        AppLogger.info('   الباركود: ${product.barcode}');
        AppLogger.info('   المصنع: ${product.manufacturer}');
      } else {
        result.productModelTest = false;
        result.errors.add('ProductModel: خصائص مفقودة');
      }

      // اختبار التحويل إلى JSON
      final json = product.toJson();
      final fromJson = ProductModel.fromJson(json);
      
      if (fromJson.barcode == product.barcode && fromJson.manufacturer == product.manufacturer) {
        AppLogger.info('✅ ProductModel: تحويل JSON يعمل بشكل صحيح');
      } else {
        result.errors.add('ProductModel: مشكلة في تحويل JSON');
      }

    } catch (e) {
      result.productModelTest = false;
      result.errors.add('خطأ في اختبار ProductModel: $e');
      AppLogger.error('❌ خطأ في اختبار ProductModel: $e');
    }
  }

  /// اختبار FlaskProductModel المحسن
  static Future<void> _testFlaskProductModel(CompilationTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار FlaskProductModel...');
      
      // إنشاء منتج Flask تجريبي
      final product = FlaskProductModel(
        id: 1,
        name: 'منتج Flask تجريبي',
        description: 'وصف منتج Flask',
        purchasePrice: 80.0,
        sellingPrice: 120.0,
        finalPrice: 100.0,
        stockQuantity: 25,
        imageUrl: 'https://example.com/flask_image.jpg',
        discountPercent: 10.0,
        discountFixed: 0.0,
        categoryName: 'فئة Flask',
        featured: true,
        isVisible: true,
      );

      // اختبار الخصائص الجديدة (getters)
      final sku = product.sku;
      final category = product.category;
      final images = product.images;
      final barcode = product.barcode;
      final supplier = product.supplier;
      final brand = product.brand;
      final quantity = product.quantity;
      final minimumStock = product.minimumStock;
      final isActive = product.isActive;
      final tags = product.tags;
      final discountPrice = product.discountPrice;

      AppLogger.info('✅ FlaskProductModel: جميع الخصائص متاحة');
      AppLogger.info('   SKU: $sku');
      AppLogger.info('   الفئة: $category');
      AppLogger.info('   عدد الصور: ${images.length}');
      AppLogger.info('   الكمية: $quantity');
      AppLogger.info('   الحد الأدنى: $minimumStock');
      AppLogger.info('   نشط: $isActive');
      AppLogger.info('   عدد العلامات: ${tags.length}');

      result.flaskModelTest = true;

    } catch (e) {
      result.flaskModelTest = false;
      result.errors.add('خطأ في اختبار FlaskProductModel: $e');
      AppLogger.error('❌ خطأ في اختبار FlaskProductModel: $e');
    }
  }

  /// اختبار تكامل API
  static Future<void> _testApiIntegration(CompilationTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار تكامل API...');
      
      // اختبار تحميل منتج من API
      final productData = await _syncService.getProductFromApi('1');
      
      if (productData != null) {
        AppLogger.info('✅ API Integration: تم تحميل بيانات المنتج بنجاح');
        AppLogger.info('   اسم المنتج: ${productData['name']}');
        AppLogger.info('   الفئة: ${productData['category']}');
        AppLogger.info('   السعر: ${productData['price']}');
        AppLogger.info('   المصدر: ${productData['metadata']?['api_source']}');
        
        // التحقق من جودة البيانات
        final productName = productData['name']?.toString() ?? '';
        final isRealData = !_isGenericProductName(productName);
        
        if (isRealData) {
          result.apiIntegrationTest = true;
          AppLogger.info('✅ API Integration: البيانات حقيقية وليست عامة');
        } else {
          result.apiIntegrationTest = false;
          result.errors.add('API Integration: البيانات لا تزال عامة');
          AppLogger.warning('⚠️ API Integration: البيانات لا تزال عامة: $productName');
        }
      } else {
        result.apiIntegrationTest = false;
        result.errors.add('API Integration: فشل في تحميل بيانات المنتج');
      }

    } catch (e) {
      result.apiIntegrationTest = false;
      result.errors.add('خطأ في اختبار API Integration: $e');
      AppLogger.error('❌ خطأ في اختبار API Integration: $e');
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

/// نتيجة اختبار إصلاح التجميع
class CompilationTestResult {
  bool productModelTest = false;
  bool flaskModelTest = false;
  bool apiIntegrationTest = false;
  bool overallSuccess = false;

  List<String> errors = [];

  /// تقرير مفصل عن النتائج
  String get detailedReport {
    final buffer = StringBuffer();
    buffer.writeln('=== تقرير اختبار إصلاح التجميع ===');
    buffer.writeln('');
    buffer.writeln('نتائج الاختبارات:');
    buffer.writeln('  • ProductModel: ${productModelTest ? "✅ نجح" : "❌ فشل"}');
    buffer.writeln('  • FlaskProductModel: ${flaskModelTest ? "✅ نجح" : "❌ فشل"}');
    buffer.writeln('  • API Integration: ${apiIntegrationTest ? "✅ نجح" : "❌ فشل"}');
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

/// دالة مساعدة للاختبار السريع
Future<void> quickCompilationTest() async {
  final result = await CompilationFixTest.runCompilationTest();
  print(result.detailedReport);
}
