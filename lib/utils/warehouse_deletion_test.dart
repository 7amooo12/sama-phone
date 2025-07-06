import '../services/warehouse_service.dart';
import '../models/warehouse_deletion_models.dart';
import 'app_logger.dart';

/// اختبار وظائف حذف المخزن
class WarehouseDeletionTest {
  static final WarehouseService _warehouseService = WarehouseService();

  /// اختبار تحليل حذف المخزن للمخزن المحدد في المشكلة
  static Future<void> testWarehouseDeletionAnalysis() async {
    const String problematicWarehouseId = '77510647-5f3b-49e9-8a8a-bcd8e77eaecd';
    
    try {
      AppLogger.info('🧪 بدء اختبار تحليل حذف المخزن للمخزن: $problematicWarehouseId');
      
      // اختبار تحليل إمكانية الحذف
      final analysis = await _warehouseService.analyzeWarehouseDeletion(problematicWarehouseId);
      
      AppLogger.info('📊 نتائج التحليل:');
      AppLogger.info('   اسم المخزن: ${analysis.warehouseName}');
      AppLogger.info('   يمكن الحذف: ${analysis.canDelete ? "نعم" : "لا"}');
      AppLogger.info('   العوامل المانعة: ${analysis.blockingFactors.length}');
      AppLogger.info('   الطلبات النشطة: ${analysis.activeRequests.length}');
      AppLogger.info('   عناصر المخزون: ${analysis.inventoryAnalysis.totalItems}');
      AppLogger.info('   الوقت المقدر للتنظيف: ${analysis.estimatedCleanupTime}');
      AppLogger.info('   مستوى المخاطر: ${analysis.riskLevelText}');
      
      // طباعة تفاصيل العوامل المانعة
      if (analysis.blockingFactors.isNotEmpty) {
        AppLogger.info('🚫 العوامل المانعة للحذف:');
        for (final factor in analysis.blockingFactors) {
          AppLogger.info('   • $factor');
        }
      }
      
      // طباعة الإجراءات المطلوبة
      if (analysis.requiredActions.isNotEmpty) {
        AppLogger.info('📋 الإجراءات المطلوبة:');
        for (final action in analysis.requiredActions) {
          AppLogger.info('   ${action.icon} ${action.title}');
          AppLogger.info('     الوصف: ${action.description}');
          AppLogger.info('     الأولوية: ${action.priorityText}');
          AppLogger.info('     الوقت المقدر: ${action.estimatedTime}');
          AppLogger.info('     العناصر المتأثرة: ${action.affectedItems}');
        }
      }
      
      // طباعة تفاصيل الطلبات النشطة
      if (analysis.activeRequests.isNotEmpty) {
        AppLogger.info('📝 تفاصيل الطلبات النشطة:');
        for (final request in analysis.activeRequests) {
          AppLogger.info('   📄 ${request.typeText} - ${request.statusText}');
          AppLogger.info('     المعرف: ${request.id}');
          AppLogger.info('     طلب من: ${request.requesterName}');
          AppLogger.info('     العمر: ${request.ageInDays} يوم');
          if (request.reason.isNotEmpty) {
            AppLogger.info('     السبب: ${request.reason}');
          }
        }
      }
      
      AppLogger.info('✅ تم اختبار تحليل حذف المخزن بنجاح');
      
    } catch (e) {
      AppLogger.error('❌ فشل في اختبار تحليل حذف المخزن: $e');
      rethrow;
    }
  }

  /// اختبار الحصول على مخزن واحد
  static Future<void> testGetWarehouse() async {
    const String problematicWarehouseId = '77510647-5f3b-49e9-8a8a-bcd8e77eaecd';
    
    try {
      AppLogger.info('🧪 اختبار الحصول على المخزن: $problematicWarehouseId');
      
      final warehouse = await _warehouseService.getWarehouse(problematicWarehouseId);
      
      if (warehouse != null) {
        AppLogger.info('✅ تم العثور على المخزن:');
        AppLogger.info('   الاسم: ${warehouse.name}');
        AppLogger.info('   العنوان: ${warehouse.address}');
        AppLogger.info('   الحالة: ${warehouse.isActive ? "نشط" : "غير نشط"}');
        AppLogger.info('   تاريخ الإنشاء: ${warehouse.createdAt}');
      } else {
        AppLogger.warning('⚠️ لم يتم العثور على المخزن');
      }
      
    } catch (e) {
      AppLogger.error('❌ فشل في اختبار الحصول على المخزن: $e');
      rethrow;
    }
  }

  /// اختبار شامل لجميع وظائف حذف المخزن
  static Future<void> runComprehensiveTest() async {
    AppLogger.info('🚀 بدء الاختبار الشامل لوظائف حذف المخزن');
    
    try {
      // اختبار 1: الحصول على المخزن
      await testGetWarehouse();
      
      // اختبار 2: تحليل إمكانية الحذف
      await testWarehouseDeletionAnalysis();
      
      AppLogger.info('🎉 تم إكمال جميع الاختبارات بنجاح');
      
    } catch (e) {
      AppLogger.error('💥 فشل في الاختبار الشامل: $e');
      rethrow;
    }
  }

  /// اختبار سريع للتحقق من أن الكود يعمل
  static Future<bool> quickCompilationTest() async {
    try {
      // إنشاء كائنات للتأكد من أن جميع الأنواع متاحة
      const analysis = WarehouseDeletionAnalysis(
        warehouseId: 'test',
        warehouseName: 'اختبار',
        canDelete: false,
        blockingFactors: ['اختبار'],
        requiredActions: [],
        activeRequests: [],
        inventoryAnalysis: InventoryAnalysis(
          totalItems: 0,
          totalQuantity: 0,
          lowStockItems: 0,
          highValueItems: 0,
        ),
        transactionAnalysis: TransactionAnalysis(
          totalTransactions: 0,
          recentTransactions: 0,
        ),
        estimatedCleanupTime: '< 1 دقيقة',
        riskLevel: DeletionRiskLevel.none,
      );
      
      const action = WarehouseDeletionAction(
        type: DeletionActionType.manageRequests,
        title: 'اختبار',
        description: 'اختبار الوصف',
        priority: DeletionActionPriority.high,
        estimatedTime: '5 دقائق',
        affectedItems: 1,
      );
      
      const request = WarehouseRequestSummary(
        id: 'test',
        type: 'withdrawal',
        status: 'pending',
        reason: 'اختبار',
        requestedBy: 'test-user',
        requesterName: 'مستخدم اختبار',
        createdAt: null,
      );
      
      AppLogger.info('✅ اختبار التجميع نجح - جميع الأنواع متاحة');
      AppLogger.info('   تحليل الحذف: ${analysis.warehouseName}');
      AppLogger.info('   إجراء الحذف: ${action.title}');
      AppLogger.info('   ملخص الطلب: ${request.requesterName}');
      
      return true;
    } catch (e) {
      AppLogger.error('❌ فشل في اختبار التجميع: $e');
      return false;
    }
  }
}

/// دالة مساعدة للاختبار السريع
Future<void> testWarehouseDeletionFunctionality() async {
  await WarehouseDeletionTest.runComprehensiveTest();
}

/// دالة للاختبار السريع للتجميع
Future<bool> testCompilation() async {
  return await WarehouseDeletionTest.quickCompilationTest();
}
