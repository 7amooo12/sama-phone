/// أداة تشخيص معالجة أذون الصرف المحولة من طلبات الصرف
/// Diagnostic Tool for Dispatch-Converted Release Order Processing

import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/services/warehouse_release_orders_service.dart';
import 'package:smartbiztracker_new/services/warehouse_dispatch_service.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/services/intelligent_inventory_deduction_service.dart';
import 'package:smartbiztracker_new/models/dispatch_product_processing_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class DispatchReleaseOrderDiagnostic {
  static const String _problematicOrderId = 'WRO-DISPATCH-07ba6659-4a68-4019-8e35-5f9609ec0d98';
  static const String _warehouseManagerId = '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab';

  static final _releaseOrdersService = WarehouseReleaseOrdersService();
  static final _dispatchService = WarehouseDispatchService();
  static final _globalInventoryService = GlobalInventoryService();
  static final _intelligentDeductionService = IntelligentInventoryDeductionService();

  /// تشخيص شامل لمعالجة أذن الصرف المحول
  static Future<DiagnosticReport> runComprehensiveDiagnostic() async {
    final report = DiagnosticReport();
    
    try {
      AppLogger.info('🔍 بدء التشخيص الشامل لأذن الصرف: $_problematicOrderId');

      // الخطوة 1: التحقق من وجود الطلب الأصلي
      report.originalDispatchExists = await _checkOriginalDispatchRequest(report);

      // الخطوة 2: التحقق من إمكانية استرجاع أذن الصرف المحول
      report.releaseOrderRetrievable = await _checkReleaseOrderRetrieval(report);

      // الخطوة 3: فحص توفر المخزون
      report.inventoryAvailable = await _checkInventoryAvailability(report);

      // الخطوة 4: اختبار الخصم الذكي
      report.intelligentDeductionWorks = await _testIntelligentDeduction(report);

      // الخطوة 5: محاولة إكمال المعالجة
      report.processingCompleted = await _attemptCompleteProcessing(report);

      report.overallSuccess = report.originalDispatchExists && 
                             report.releaseOrderRetrievable && 
                             report.inventoryAvailable && 
                             report.intelligentDeductionWorks && 
                             report.processingCompleted;

      AppLogger.info('📊 نتائج التشخيص الشامل:');
      AppLogger.info('   الطلب الأصلي موجود: ${report.originalDispatchExists}');
      AppLogger.info('   أذن الصرف قابل للاسترجاع: ${report.releaseOrderRetrievable}');
      AppLogger.info('   المخزون متوفر: ${report.inventoryAvailable}');
      AppLogger.info('   الخصم الذكي يعمل: ${report.intelligentDeductionWorks}');
      AppLogger.info('   المعالجة مكتملة: ${report.processingCompleted}');
      AppLogger.info('   النجاح الإجمالي: ${report.overallSuccess}');

    } catch (e) {
      report.errors.add('خطأ في التشخيص الشامل: $e');
      AppLogger.error('❌ خطأ في التشخيص الشامل: $e');
    }

    return report;
  }

  /// التحقق من وجود الطلب الأصلي
  static Future<bool> _checkOriginalDispatchRequest(DiagnosticReport report) async {
    try {
      AppLogger.info('🔍 التحقق من وجود الطلب الأصلي...');
      
      final uuid = _problematicOrderId.replaceAll('WRO-DISPATCH-', '');
      final dispatchRequest = await _dispatchService.getDispatchRequestById(uuid);

      if (dispatchRequest != null) {
        report.notes.add('✅ تم العثور على الطلب الأصلي: ${dispatchRequest.requestNumber}');
        report.notes.add('   عدد العناصر: ${dispatchRequest.items.length}');
        report.notes.add('   الحالة: ${dispatchRequest.status}');
        
        for (final item in dispatchRequest.items) {
          report.notes.add('   منتج: ${item.productName} (ID: ${item.productId}, الكمية: ${item.quantity})');
        }
        
        return true;
      } else {
        report.errors.add('❌ لم يتم العثور على الطلب الأصلي');
        return false;
      }
    } catch (e) {
      report.errors.add('❌ خطأ في التحقق من الطلب الأصلي: $e');
      return false;
    }
  }

  /// التحقق من إمكانية استرجاع أذن الصرف المحول
  static Future<bool> _checkReleaseOrderRetrieval(DiagnosticReport report) async {
    try {
      AppLogger.info('🔍 التحقق من استرجاع أذن الصرف المحول...');
      
      final releaseOrder = await _releaseOrdersService.getReleaseOrder(_problematicOrderId);

      if (releaseOrder != null) {
        report.notes.add('✅ تم استرجاع أذن الصرف المحول بنجاح');
        report.notes.add('   معرف الأذن: ${releaseOrder.id}');
        report.notes.add('   رقم الأذن: ${releaseOrder.releaseOrderNumber}');
        report.notes.add('   عدد العناصر: ${releaseOrder.items.length}');
        report.notes.add('   الحالة: ${releaseOrder.status}');
        return true;
      } else {
        report.errors.add('❌ فشل في استرجاع أذن الصرف المحول');
        return false;
      }
    } catch (e) {
      report.errors.add('❌ خطأ في استرجاع أذن الصرف المحول: $e');
      return false;
    }
  }

  /// فحص توفر المخزون
  static Future<bool> _checkInventoryAvailability(DiagnosticReport report) async {
    try {
      AppLogger.info('🔍 فحص توفر المخزون للمنتج 190...');
      
      final searchResult = await _globalInventoryService.searchProductGlobally(
        productId: '190',
        requestedQuantity: 20,
        strategy: WarehouseSelectionStrategy.highestStock,
      );

      report.notes.add('📊 نتائج البحث العالمي:');
      report.notes.add('   يمكن التلبية: ${searchResult.canFulfill}');
      report.notes.add('   الكمية المتاحة: ${searchResult.totalAvailableQuantity}');
      report.notes.add('   عدد المخازن: ${searchResult.availableWarehouses.length}');
      report.notes.add('   خطة التخصيص: ${searchResult.allocationPlan.length} مخزن');

      for (final allocation in searchResult.allocationPlan) {
        report.notes.add('   - ${allocation.warehouseName}: ${allocation.allocatedQuantity} من ${allocation.availableQuantity}');
      }

      return searchResult.canFulfill;
    } catch (e) {
      report.errors.add('❌ خطأ في فحص توفر المخزون: $e');
      return false;
    }
  }

  /// اختبار الخصم الذكي
  static Future<bool> _testIntelligentDeduction(DiagnosticReport report) async {
    try {
      AppLogger.info('🔍 اختبار الخصم الذكي...');
      
      // إنشاء نموذج معالجة للاختبار
      final processingItem = DispatchProductProcessingModel.fromDispatchItem(
        itemId: 'test-item-id',
        requestId: '07ba6659-4a68-4019-8e35-5f9609ec0d98',
        productId: '190',
        productName: 'توزيع ذكي',
        quantity: 1, // كمية صغيرة للاختبار
        notes: 'اختبار تشخيصي',
      );

      final deductionResult = await _intelligentDeductionService.deductProductInventory(
        product: processingItem,
        performedBy: _warehouseManagerId,
        requestId: '07ba6659-4a68-4019-8e35-5f9609ec0d98',
      );

      report.notes.add('🧪 نتائج اختبار الخصم الذكي:');
      report.notes.add('   النجاح: ${deductionResult.success}');
      report.notes.add('   الكمية المطلوبة: ${deductionResult.totalRequestedQuantity}');
      report.notes.add('   الكمية المخصومة: ${deductionResult.totalDeductedQuantity}');
      report.notes.add('   عدد المخازن المتأثرة: ${deductionResult.warehouseResults.length}');

      for (final warehouseResult in deductionResult.warehouseResults) {
        report.notes.add('   - ${warehouseResult.warehouseName}: ${warehouseResult.success ? "نجح" : "فشل"} (${warehouseResult.deductedQuantity})');
        if (!warehouseResult.success && warehouseResult.error != null) {
          report.notes.add('     خطأ: ${warehouseResult.error}');
        }
      }

      return deductionResult.success;
    } catch (e) {
      report.errors.add('❌ خطأ في اختبار الخصم الذكي: $e');
      return false;
    }
  }

  /// محاولة إكمال المعالجة
  static Future<bool> _attemptCompleteProcessing(DiagnosticReport report) async {
    try {
      AppLogger.info('🔍 محاولة إكمال معالجة أذن الصرف...');
      
      final success = await _releaseOrdersService.processAllReleaseOrderItems(
        releaseOrderId: _problematicOrderId,
        warehouseManagerId: _warehouseManagerId,
        notes: 'معالجة تشخيصية لإصلاح المشكلة',
      );

      if (success) {
        report.notes.add('✅ تم إكمال معالجة أذن الصرف بنجاح');
      } else {
        report.errors.add('❌ فشل في إكمال معالجة أذن الصرف');
      }

      return success;
    } catch (e) {
      report.errors.add('❌ خطأ في محاولة إكمال المعالجة: $e');
      return false;
    }
  }

  /// إصلاح المشكلة تلقائياً
  static Future<bool> attemptAutomaticFix() async {
    try {
      AppLogger.info('🔧 محاولة الإصلاح التلقائي...');

      // تشغيل التشخيص أولاً
      final report = await runComprehensiveDiagnostic();

      if (report.overallSuccess) {
        AppLogger.info('✅ لا توجد مشاكل تحتاج إصلاح');
        return true;
      }

      // محاولة إصلاح المشاكل المحددة
      if (!report.inventoryAvailable) {
        AppLogger.warning('⚠️ مشكلة في توفر المخزون - قد تحتاج تدخل يدوي');
      }

      if (!report.intelligentDeductionWorks) {
        AppLogger.info('🔧 محاولة إصلاح مشكلة الخصم الذكي...');
        // يمكن إضافة منطق إصلاح محدد هنا
      }

      if (!report.processingCompleted) {
        AppLogger.info('🔧 محاولة إكمال المعالجة مرة أخرى...');
        final success = await _releaseOrdersService.processAllReleaseOrderItems(
          releaseOrderId: _problematicOrderId,
          warehouseManagerId: _warehouseManagerId,
          notes: 'إصلاح تلقائي للمعالجة المتقطعة',
        );

        if (success) {
          AppLogger.info('✅ تم إصلاح المشكلة وإكمال المعالجة');
          return true;
        }
      }

      AppLogger.warning('⚠️ لم يتم إصلاح جميع المشاكل تلقائياً');
      return false;

    } catch (e) {
      AppLogger.error('❌ خطأ في الإصلاح التلقائي: $e');
      return false;
    }
  }
}

/// تقرير التشخيص
class DiagnosticReport {
  bool originalDispatchExists = false;
  bool releaseOrderRetrievable = false;
  bool inventoryAvailable = false;
  bool intelligentDeductionWorks = false;
  bool processingCompleted = false;
  bool overallSuccess = false;

  final List<String> notes = [];
  final List<String> errors = [];

  /// ملخص التقرير
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('📋 تقرير التشخيص الشامل');
    buffer.writeln('=' * 40);
    buffer.writeln('النجاح الإجمالي: ${overallSuccess ? "✅" : "❌"}');
    buffer.writeln();
    
    buffer.writeln('📊 نتائج الفحوصات:');
    buffer.writeln('• الطلب الأصلي موجود: ${originalDispatchExists ? "✅" : "❌"}');
    buffer.writeln('• أذن الصرف قابل للاسترجاع: ${releaseOrderRetrievable ? "✅" : "❌"}');
    buffer.writeln('• المخزون متوفر: ${inventoryAvailable ? "✅" : "❌"}');
    buffer.writeln('• الخصم الذكي يعمل: ${intelligentDeductionWorks ? "✅" : "❌"}');
    buffer.writeln('• المعالجة مكتملة: ${processingCompleted ? "✅" : "❌"}');
    buffer.writeln();

    if (notes.isNotEmpty) {
      buffer.writeln('📝 ملاحظات:');
      for (final note in notes) {
        buffer.writeln('  $note');
      }
      buffer.writeln();
    }

    if (errors.isNotEmpty) {
      buffer.writeln('❌ أخطاء:');
      for (final error in errors) {
        buffer.writeln('  $error');
      }
    }

    return buffer.toString();
  }
}
