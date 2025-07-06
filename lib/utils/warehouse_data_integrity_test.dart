import '../services/warehouse_service.dart';
import '../services/product_data_integrity_service.dart';
import '../providers/warehouse_provider.dart';
import '../models/warehouse_model.dart';
import '../models/product_model.dart';
import 'app_logger.dart';

/// اختبار شامل لسلامة البيانات في نظام إدارة المخازن
class WarehouseDataIntegrityTest {
  static final WarehouseService _warehouseService = WarehouseService();
  static final ProductDataIntegrityService _integrityService = ProductDataIntegrityService();

  /// اختبار شامل لسلامة البيانات
  static Future<WarehouseIntegrityTestResult> runComprehensiveIntegrityTest() async {
    AppLogger.info('🧪 بدء اختبار شامل لسلامة بيانات المخازن...');

    final result = WarehouseIntegrityTestResult();
    
    try {
      // اختبار 1: تحميل المخزون بدون تعديل البيانات
      await _testInventoryLoadingIntegrity(result);
      
      // اختبار 2: التحقق من عدم تعديل أسماء المنتجات
      await _testProductNameIntegrity(result);
      
      // اختبار 3: التحقق من عدم تعديل فئات المنتجات
      await _testProductCategoryIntegrity(result);
      
      // اختبار 4: اختبار العمليات الآمنة
      await _testSafeOperations(result);
      
      // اختبار 5: إحصائيات سلامة البيانات
      await _testDataIntegrityStats(result);

      result.overallSuccess = result.inventoryLoadingTest && 
                             result.productNameTest && 
                             result.productCategoryTest &&
                             result.safeOperationsTest &&
                             result.integrityStatsTest;

      AppLogger.info('🎉 انتهى اختبار سلامة البيانات:');
      AppLogger.info('   تحميل المخزون: ${result.inventoryLoadingTest ? "✅" : "❌"}');
      AppLogger.info('   أسماء المنتجات: ${result.productNameTest ? "✅" : "❌"}');
      AppLogger.info('   فئات المنتجات: ${result.productCategoryTest ? "✅" : "❌"}');
      AppLogger.info('   العمليات الآمنة: ${result.safeOperationsTest ? "✅" : "❌"}');
      AppLogger.info('   إحصائيات السلامة: ${result.integrityStatsTest ? "✅" : "❌"}');
      AppLogger.info('   النتيجة الإجمالية: ${result.overallSuccess ? "✅ نجح" : "❌ فشل"}');

    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار سلامة البيانات: $e');
      result.overallSuccess = false;
      result.errors.add('خطأ عام في الاختبار: $e');
    }

    return result;
  }

  /// اختبار تحميل المخزون بدون تعديل البيانات
  static Future<void> _testInventoryLoadingIntegrity(WarehouseIntegrityTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار تحميل المخزون بدون تعديل البيانات...');
      
      // الحصول على قائمة المخازن
      final warehouses = await _warehouseService.getWarehouses();
      
      if (warehouses.isEmpty) {
        result.inventoryLoadingTest = true;
        AppLogger.info('✅ لا توجد مخازن للاختبار');
        return;
      }

      final testWarehouse = warehouses.first;
      
      // تحميل المخزون مرتين والتحقق من عدم تغيير البيانات
      final inventory1 = await _warehouseService.getWarehouseInventory(testWarehouse.id);
      final inventory2 = await _warehouseService.getWarehouseInventory(testWarehouse.id);
      
      bool dataUnchanged = true;
      
      if (inventory1.length == inventory2.length) {
        for (int i = 0; i < inventory1.length; i++) {
          final item1 = inventory1[i];
          final item2 = inventory2[i];
          
          if (item1.product?.name != item2.product?.name ||
              item1.product?.category != item2.product?.category) {
            dataUnchanged = false;
            result.errors.add('تم تعديل بيانات المنتج ${item1.productId} أثناء تحميل المخزون');
            break;
          }
        }
      } else {
        dataUnchanged = false;
        result.errors.add('تغير عدد المنتجات في المخزون بين التحميلين');
      }
      
      result.inventoryLoadingTest = dataUnchanged;
      result.inventoryLoadingDetails = 'تم اختبار ${inventory1.length} منتج في المخزن ${testWarehouse.name}';
      
      if (dataUnchanged) {
        AppLogger.info('✅ تحميل المخزون لا يعدل بيانات المنتجات');
      } else {
        AppLogger.error('❌ تحميل المخزون يعدل بيانات المنتجات');
      }
      
    } catch (e) {
      result.inventoryLoadingTest = false;
      result.errors.add('خطأ في اختبار تحميل المخزون: $e');
      AppLogger.error('❌ خطأ في اختبار تحميل المخزون: $e');
    }
  }

  /// اختبار سلامة أسماء المنتجات
  static Future<void> _testProductNameIntegrity(WarehouseIntegrityTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار سلامة أسماء المنتجات...');
      
      final stats = await _integrityService.getIntegrityStats();
      
      result.productNameTest = stats.genericNames < (stats.totalProducts * 0.2); // أقل من 20% أسماء عامة
      result.productNameDetails = 'إجمالي المنتجات: ${stats.totalProducts}, أسماء عامة: ${stats.genericNames}';
      
      if (result.productNameTest) {
        AppLogger.info('✅ جودة أسماء المنتجات مقبولة: ${stats.genericNames}/${stats.totalProducts}');
      } else {
        AppLogger.warning('⚠️ نسبة عالية من الأسماء العامة: ${stats.genericNames}/${stats.totalProducts}');
      }
      
    } catch (e) {
      result.productNameTest = false;
      result.errors.add('خطأ في اختبار أسماء المنتجات: $e');
      AppLogger.error('❌ خطأ في اختبار أسماء المنتجات: $e');
    }
  }

  /// اختبار سلامة فئات المنتجات
  static Future<void> _testProductCategoryIntegrity(WarehouseIntegrityTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار سلامة فئات المنتجات...');
      
      final stats = await _integrityService.getIntegrityStats();
      
      result.productCategoryTest = stats.genericCategories < (stats.totalProducts * 0.3); // أقل من 30% فئات عامة
      result.productCategoryDetails = 'إجمالي المنتجات: ${stats.totalProducts}, فئات عامة: ${stats.genericCategories}';
      
      if (result.productCategoryTest) {
        AppLogger.info('✅ جودة فئات المنتجات مقبولة: ${stats.genericCategories}/${stats.totalProducts}');
      } else {
        AppLogger.warning('⚠️ نسبة عالية من الفئات العامة: ${stats.genericCategories}/${stats.totalProducts}');
      }
      
    } catch (e) {
      result.productCategoryTest = false;
      result.errors.add('خطأ في اختبار فئات المنتجات: $e');
      AppLogger.error('❌ خطأ في اختبار فئات المنتجات: $e');
    }
  }

  /// اختبار العمليات الآمنة
  static Future<void> _testSafeOperations(WarehouseIntegrityTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار العمليات الآمنة...');
      
      // اختبار القراءة الآمنة للمنتج
      final testProductId = 'test_product_123';
      
      // قراءة آمنة بدون إنشاء
      final product1 = await _integrityService.getProductSafely(testProductId, allowCreation: false);
      
      // قراءة آمنة مع إنشاء مؤقت
      final product2 = await _integrityService.getProductSafely(testProductId, allowCreation: true);
      
      bool safeOperationsWork = true;
      
      if (product1 != null) {
        result.errors.add('القراءة الآمنة أرجعت منتج غير موجود بدون إذن الإنشاء');
        safeOperationsWork = false;
      }
      
      if (product2 == null) {
        result.errors.add('القراءة الآمنة فشلت في إنشاء منتج مؤقت');
        safeOperationsWork = false;
      } else if (!product2.name.contains('مؤقت')) {
        result.errors.add('المنتج المؤقت لا يحتوي على تسمية واضحة');
        safeOperationsWork = false;
      }
      
      result.safeOperationsTest = safeOperationsWork;
      result.safeOperationsDetails = 'اختبار القراءة الآمنة للمنتج $testProductId';
      
      if (safeOperationsWork) {
        AppLogger.info('✅ العمليات الآمنة تعمل بشكل صحيح');
      } else {
        AppLogger.error('❌ مشاكل في العمليات الآمنة');
      }
      
    } catch (e) {
      result.safeOperationsTest = false;
      result.errors.add('خطأ في اختبار العمليات الآمنة: $e');
      AppLogger.error('❌ خطأ في اختبار العمليات الآمنة: $e');
    }
  }

  /// اختبار إحصائيات سلامة البيانات
  static Future<void> _testDataIntegrityStats(WarehouseIntegrityTestResult result) async {
    try {
      AppLogger.info('🔄 اختبار إحصائيات سلامة البيانات...');
      
      final stats = await _integrityService.getIntegrityStats();
      
      result.integrityStatsTest = stats.totalProducts >= 0 && 
                                 stats.validProducts >= 0 && 
                                 stats.integrityPercentage >= 0 && 
                                 stats.integrityPercentage <= 100;
      
      result.integrityStatsDetails = 'إجمالي: ${stats.totalProducts}, صالح: ${stats.validProducts}, نسبة السلامة: ${stats.integrityPercentage.toStringAsFixed(1)}%';
      
      if (result.integrityStatsTest) {
        AppLogger.info('✅ إحصائيات سلامة البيانات صحيحة');
        AppLogger.info('   إجمالي المنتجات: ${stats.totalProducts}');
        AppLogger.info('   المنتجات الصالحة: ${stats.validProducts}');
        AppLogger.info('   نسبة السلامة: ${stats.integrityPercentage.toStringAsFixed(1)}%');
      } else {
        AppLogger.error('❌ مشاكل في إحصائيات سلامة البيانات');
      }
      
    } catch (e) {
      result.integrityStatsTest = false;
      result.errors.add('خطأ في اختبار إحصائيات السلامة: $e');
      AppLogger.error('❌ خطأ في اختبار إحصائيات السلامة: $e');
    }
  }
}

/// نتيجة اختبار سلامة البيانات في المخازن
class WarehouseIntegrityTestResult {
  bool inventoryLoadingTest = false;
  bool productNameTest = false;
  bool productCategoryTest = false;
  bool safeOperationsTest = false;
  bool integrityStatsTest = false;
  bool overallSuccess = false;

  String inventoryLoadingDetails = '';
  String productNameDetails = '';
  String productCategoryDetails = '';
  String safeOperationsDetails = '';
  String integrityStatsDetails = '';

  List<String> errors = [];

  /// تقرير مفصل عن النتائج
  String get detailedReport {
    final buffer = StringBuffer();
    buffer.writeln('=== تقرير اختبار سلامة بيانات المخازن ===');
    buffer.writeln('');
    buffer.writeln('نتائج الاختبارات:');
    buffer.writeln('  • تحميل المخزون: ${inventoryLoadingTest ? "✅ نجح" : "❌ فشل"}');
    buffer.writeln('    التفاصيل: $inventoryLoadingDetails');
    buffer.writeln('  • أسماء المنتجات: ${productNameTest ? "✅ نجح" : "❌ فشل"}');
    buffer.writeln('    التفاصيل: $productNameDetails');
    buffer.writeln('  • فئات المنتجات: ${productCategoryTest ? "✅ نجح" : "❌ فشل"}');
    buffer.writeln('    التفاصيل: $productCategoryDetails');
    buffer.writeln('  • العمليات الآمنة: ${safeOperationsTest ? "✅ نجح" : "❌ فشل"}');
    buffer.writeln('    التفاصيل: $safeOperationsDetails');
    buffer.writeln('  • إحصائيات السلامة: ${integrityStatsTest ? "✅ نجح" : "❌ فشل"}');
    buffer.writeln('    التفاصيل: $integrityStatsDetails');
    buffer.writeln('');
    buffer.writeln('النتيجة الإجمالية: ${overallSuccess ? "✅ نجح" : "❌ فشل"}');
    
    if (errors.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('الأخطاء والمشاكل:');
      for (final error in errors) {
        buffer.writeln('  • $error');
      }
    }
    
    return buffer.toString();
  }
}

/// دالة مساعدة للاختبار السريع
Future<void> quickWarehouseIntegrityTest() async {
  final result = await WarehouseDataIntegrityTest.runComprehensiveIntegrityTest();
  print(result.detailedReport);
}
