/// أداة تشخيص مشاكل خصم المخزون الذكي
/// Inventory Deduction Debugging Utility

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/dispatch_product_processing_model.dart';
import 'package:smartbiztracker_new/services/intelligent_inventory_deduction_service.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class InventoryDeductionDebugger {
  static final IntelligentInventoryDeductionService _deductionService = IntelligentInventoryDeductionService();
  static final GlobalInventoryService _globalService = GlobalInventoryService();

  /// تشخيص شامل لمشكلة خصم المخزون
  static Future<void> diagnoseDeductionIssue({
    required DispatchProductProcessingModel product,
    required String performedBy,
    required String requestId,
  }) async {
    try {
      AppLogger.info('🔍 === بدء تشخيص مشكلة خصم المخزون ===');
      AppLogger.info('المنتج: ${product.productName} (${product.productId})');
      AppLogger.info('الكمية المطلوبة: ${product.requestedQuantity}');
      AppLogger.info('المنفذ: $performedBy');
      AppLogger.info('معرف الطلب: $requestId');

      // 1. فحص بيانات المنتج
      await _checkProductData(product);

      // 2. فحص توفر المنتج في المخازن
      await _checkProductAvailability(product);

      // 3. فحص صلاحيات المستخدم
      await _checkUserPermissions(performedBy);

      // 4. محاولة تنفيذ الخصم مع تسجيل مفصل
      await _attemptDeductionWithLogging(product, performedBy, requestId);

      AppLogger.info('=== انتهاء التشخيص ===');
    } catch (e) {
      AppLogger.error('❌ خطأ في التشخيص: $e');
    }
  }

  /// فحص بيانات المنتج
  static Future<void> _checkProductData(DispatchProductProcessingModel product) async {
    AppLogger.info('📦 فحص بيانات المنتج...');
    
    if (product.productId.isEmpty) {
      AppLogger.error('❌ معرف المنتج فارغ');
      return;
    }
    
    if (product.productName.isEmpty) {
      AppLogger.warning('⚠️ اسم المنتج فارغ');
    }
    
    if (product.requestedQuantity <= 0) {
      AppLogger.error('❌ الكمية المطلوبة غير صحيحة: ${product.requestedQuantity}');
      return;
    }

    AppLogger.info('✅ بيانات المنتج صحيحة');
    AppLogger.info('   معرف المنتج: ${product.productId}');
    AppLogger.info('   اسم المنتج: ${product.productName}');
    AppLogger.info('   الكمية المطلوبة: ${product.requestedQuantity}');
    AppLogger.info('   يحتوي على بيانات المواقع: ${product.hasLocationData}');
    AppLogger.info('   عدد المواقع: ${product.warehouseLocations?.length ?? 0}');
  }

  /// فحص توفر المنتج في المخازن
  static Future<void> _checkProductAvailability(DispatchProductProcessingModel product) async {
    try {
      AppLogger.info('🔍 فحص توفر المنتج في المخازن...');

      final searchResult = await _globalService.searchProductGlobally(
        productId: product.productId,
        requestedQuantity: product.requestedQuantity,
      );

      AppLogger.info('📊 نتائج البحث العالمي:');
      AppLogger.info('   يمكن التلبية: ${searchResult.canFulfill}');
      AppLogger.info('   الكمية المتاحة: ${searchResult.totalAvailableQuantity}');
      AppLogger.info('   عدد المخازن المتاحة: ${searchResult.availableWarehouses.length}');
      AppLogger.info('   عدد التخصيصات: ${searchResult.allocationPlan.length}');

      if (!searchResult.canFulfill) {
        AppLogger.warning('⚠️ لا يمكن تلبية الطلب بالكامل');
        AppLogger.info('   النقص: ${product.requestedQuantity - searchResult.totalAvailableQuantity}');
      }

      for (int i = 0; i < searchResult.availableWarehouses.length; i++) {
        final warehouse = searchResult.availableWarehouses[i];
        AppLogger.info('   مخزن ${i + 1}: ${warehouse.warehouseName} - ${warehouse.availableQuantity} متاح');
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في فحص توفر المنتج: $e');
    }
  }

  /// فحص صلاحيات المستخدم
  static Future<void> _checkUserPermissions(String performedBy) async {
    AppLogger.info('👤 فحص صلاحيات المستخدم...');

    if (performedBy.isEmpty) {
      AppLogger.error('❌ معرف المستخدم فارغ');
      return;
    }

    try {
      // فحص المستخدم في قاعدة البيانات
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('id, role, status, email')
          .eq('id', performedBy)
          .single();

      AppLogger.info('✅ معلومات المستخدم:');
      AppLogger.info('   المعرف: ${response['id']}');
      AppLogger.info('   الدور: ${response['role']}');
      AppLogger.info('   الحالة: ${response['status']}');
      AppLogger.info('   البريد: ${response['email']}');

      if (response['status'] != 'approved') {
        AppLogger.error('❌ المستخدم غير موافق عليه: ${response['status']}');
      }

      if (!['admin', 'owner', 'warehouseManager', 'accountant'].contains(response['role'])) {
        AppLogger.error('❌ دور المستخدم غير مصرح له بخصم المخزون: ${response['role']}');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في فحص صلاحيات المستخدم: $e');
    }
  }

  /// محاولة تنفيذ الخصم مع تسجيل مفصل
  static Future<void> _attemptDeductionWithLogging(
    DispatchProductProcessingModel product,
    String performedBy,
    String requestId,
  ) async {
    try {
      AppLogger.info('⚡ محاولة تنفيذ الخصم...');

      final result = await _deductionService.deductProductInventory(
        product: product,
        performedBy: performedBy,
        requestId: requestId,
      );

      if (result.success) {
        AppLogger.info('✅ تم الخصم بنجاح!');
        AppLogger.info('   الكمية المخصومة: ${result.totalDeductedQuantity}');
        AppLogger.info('   المخازن المتأثرة: ${result.warehouseResults.length}');
        
        for (final warehouseResult in result.warehouseResults) {
          AppLogger.info('   - ${warehouseResult.warehouseName}: ${warehouseResult.deductedQuantity} مخصوم');
        }
      } else {
        AppLogger.error('❌ فشل في الخصم');
        AppLogger.error('   الأخطاء: ${result.errors.join(', ')}');
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في تنفيذ الخصم: $e');
      
      // تحليل نوع الخطأ
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('connection') || errorString.contains('network')) {
        AppLogger.error('🔗 مشكلة في الاتصال بقاعدة البيانات');
      } else if (errorString.contains('auth') || errorString.contains('unauthorized')) {
        AppLogger.error('🔐 مشكلة في المصادقة');
      } else if (errorString.contains('permission') || errorString.contains('forbidden')) {
        AppLogger.error('🚫 مشكلة في الصلاحيات');
      } else if (errorString.contains('المنتج غير موجود')) {
        AppLogger.error('📦 المنتج غير موجود في المخازن');
      } else if (errorString.contains('الكمية المتاحة')) {
        AppLogger.error('📊 مشكلة في الكمية المتاحة');
      } else {
        AppLogger.error('❓ خطأ غير معروف');
      }
    }
  }

  /// اختبار سريع للنظام
  static Future<void> quickSystemTest() async {
    AppLogger.info('🧪 === اختبار سريع لنظام خصم المخزون ===');
    
    try {
      // إنشاء منتج تجريبي
      final testProduct = DispatchProductProcessingModel.fromDispatchItem(
        itemId: 'test_item_001',
        requestId: 'test_request_001',
        productId: 'test_product_001',
        productName: 'منتج تجريبي',
        quantity: 1,
      );

      // تشخيص المنتج التجريبي
      await diagnoseDeductionIssue(
        product: testProduct,
        performedBy: 'test_user_001',
        requestId: 'test_request_001',
      );

    } catch (e) {
      AppLogger.error('❌ خطأ في الاختبار السريع: $e');
    }
    
    AppLogger.info('=== انتهاء الاختبار السريع ===');
  }

  /// طباعة معلومات النظام
  static void printSystemInfo() {
    AppLogger.info('ℹ️ === معلومات نظام خصم المخزون ===');
    AppLogger.info('خدمة الخصم الذكي: IntelligentInventoryDeductionService');
    AppLogger.info('خدمة المخزون العالمي: GlobalInventoryService');
    AppLogger.info('دالة قاعدة البيانات: deduct_inventory_with_validation');
    AppLogger.info('=== نهاية معلومات النظام ===');
  }
}
