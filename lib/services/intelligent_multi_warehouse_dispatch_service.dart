/// خدمة التوزيع الذكي متعدد المخازن لطلبات الصرف
/// Intelligent Multi-Warehouse Dispatch Service

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:smartbiztracker_new/models/warehouse_dispatch_model.dart';
import 'package:smartbiztracker_new/models/dispatch_product_processing_model.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';
import 'package:smartbiztracker_new/models/multi_warehouse_dispatch_models.dart';
import 'package:smartbiztracker_new/services/dispatch_location_service.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class IntelligentMultiWarehouseDispatchService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DispatchLocationService _locationService = DispatchLocationService();
  final GlobalInventoryService _globalInventoryService = GlobalInventoryService();

  /// إنشاء طلبات صرف متعددة من فاتورة واحدة باستخدام التوزيع الذكي
  Future<MultiWarehouseDispatchResult> createIntelligentDispatchFromInvoice({
    required String invoiceId,
    required String customerName,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    required String requestedBy,
    String? notes,
    WarehouseSelectionStrategy strategy = WarehouseSelectionStrategy.balanced,
  }) async {
    try {
      AppLogger.info('🤖 بدء التوزيع الذكي متعدد المخازن للفاتورة: $invoiceId');
      AppLogger.info('📦 عدد المنتجات: ${items.length}');

      // تحويل عناصر الفاتورة إلى نماذج معالجة
      final processingProducts = items.map((item) {
        return DispatchProductProcessingModel.fromDispatchItem(
          itemId: '${invoiceId}_${item['product_id']}',
          requestId: invoiceId,
          productId: item['product_id'].toString(),
          productName: item['product_name']?.toString() ?? 'منتج ${item['product_id']}',
          quantity: _parseInt(item['quantity']) ?? 1,
        );
      }).toList();

      // الكشف الذكي عن مواقع المنتجات
      final productsWithLocations = await _locationService.detectProductLocationsAdvanced(
        products: processingProducts,
        strategy: strategy,
        enrichWithDetails: true,
        respectMinimumStock: true,
        maxWarehousesPerProduct: 5,
      );

      // تحليل النتائج وإنشاء خطة التوزيع
      final distributionPlan = await _createDistributionPlan(
        products: productsWithLocations,
        invoiceId: invoiceId,
        customerName: customerName,
        totalAmount: totalAmount,
        requestedBy: requestedBy,
        notes: notes,
      );

      // تنفيذ خطة التوزيع
      final result = await _executeDistributionPlan(distributionPlan);

      AppLogger.info('✅ تم إكمال التوزيع الذكي متعدد المخازن');
      AppLogger.info('📊 تم إنشاء ${result.createdDispatches.length} طلب صرف');

      return result;
    } catch (e) {
      AppLogger.error('❌ خطأ في التوزيع الذكي متعدد المخازن: $e');

      // تحليل نوع الخطأ وإرجاع رسالة مناسبة
      String errorMessage = _getLocalizedErrorMessage(e);
      throw Exception(errorMessage);
    }
  }

  /// إنشاء خطة التوزيع الذكي
  Future<DistributionPlan> _createDistributionPlan({
    required List<DispatchProductProcessingModel> products,
    required String invoiceId,
    required String customerName,
    required double totalAmount,
    required String requestedBy,
    String? notes,
  }) async {
    try {
      AppLogger.info('📋 إنشاء خطة التوزيع الذكي...');

      final warehouseGroups = <String, List<DistributionItem>>{};
      final unfulfillableProducts = <DispatchProductProcessingModel>[];
      final partiallyFulfillableProducts = <DispatchProductProcessingModel>[];

      for (final product in products) {
        if (!product.hasLocationData || product.warehouseLocations == null || product.warehouseLocations!.isEmpty) {
          unfulfillableProducts.add(product);
          continue;
        }

        if (!product.canFulfillRequest) {
          partiallyFulfillableProducts.add(product);
        }

        // توزيع المنتج على المخازن المتاحة
        var remainingQuantity = product.requestedQuantity;
        
        for (final location in product.warehouseLocations!) {
          if (remainingQuantity <= 0) break;

          final allocatableQuantity = location.minimumStock != null
              ? (location.availableQuantity - location.minimumStock!).clamp(0, location.availableQuantity)
              : location.availableQuantity;

          if (allocatableQuantity <= 0) continue;

          final quantityToAllocate = remainingQuantity.clamp(0, allocatableQuantity);

          if (quantityToAllocate > 0) {
            final warehouseId = location.warehouseId;
            
            if (!warehouseGroups.containsKey(warehouseId)) {
              warehouseGroups[warehouseId] = [];
            }

            warehouseGroups[warehouseId]!.add(DistributionItem(
              productId: product.productId,
              productName: product.productName,
              requestedQuantity: product.requestedQuantity,
              allocatedQuantity: quantityToAllocate,
              warehouseId: warehouseId,
              warehouseName: location.warehouseName,
              unitPrice: 0.0, // سيتم تحديثه لاحقاً
            ));

            remainingQuantity -= quantityToAllocate;
          }
        }
      }

      // إنشاء طلبات الصرف لكل مخزن
      final warehouseDispatches = <WarehouseDispatchPlan>[];
      
      for (final entry in warehouseGroups.entries) {
        final warehouseId = entry.key;
        final items = entry.value;
        
        // الحصول على اسم المخزن
        final warehouseName = items.isNotEmpty ? items.first.warehouseName : 'مخزن غير معروف';
        
        // حساب المبلغ الإجمالي لهذا المخزن
        final warehouseTotalAmount = totalAmount * (items.length / products.length);

        warehouseDispatches.add(WarehouseDispatchPlan(
          warehouseId: warehouseId,
          warehouseName: warehouseName,
          items: items,
          totalAmount: warehouseTotalAmount,
          reason: 'صرف فاتورة: $customerName - توزيع ذكي من $warehouseName',
          notes: '${notes ?? ''}\nتوزيع ذكي متعدد المخازن - جزء من الفاتورة $invoiceId',
        ));
      }

      return DistributionPlan(
        invoiceId: invoiceId,
        customerName: customerName,
        totalAmount: totalAmount,
        requestedBy: requestedBy,
        warehouseDispatches: warehouseDispatches,
        unfulfillableProducts: unfulfillableProducts,
        partiallyFulfillableProducts: partiallyFulfillableProducts,
        distributionStrategy: WarehouseSelectionStrategy.balanced,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء خطة التوزيع: $e');
      throw Exception('فشل في إنشاء خطة التوزيع: $e');
    }
  }

  /// تنفيذ خطة التوزيع
  Future<MultiWarehouseDispatchResult> _executeDistributionPlan(DistributionPlan plan) async {
    try {
      AppLogger.info('⚡ تنفيذ خطة التوزيع...');

      final createdDispatches = <WarehouseDispatchModel>[];
      final errors = <String>[];

      for (final warehousePlan in plan.warehouseDispatches) {
        try {
          // إنشاء رقم طلب فريد
          final requestNumber = _generateRequestNumber();

          // إنشاء الطلب الرئيسي
          final requestData = {
            'request_number': requestNumber,
            'type': 'withdrawal',
            'status': 'pending',
            'reason': warehousePlan.reason,
            'requested_by': plan.requestedBy,
            'notes': warehousePlan.notes,
            'warehouse_id': warehousePlan.warehouseId,
            'metadata': {
              'source': 'intelligent_multi_warehouse_distribution',
              'original_invoice_id': plan.invoiceId,
              'customer_name': plan.customerName,
              'distribution_strategy': plan.distributionStrategy.toString(),
              'warehouse_name': warehousePlan.warehouseName,
            },
          };

          final requestResponse = await _supabase
              .from('warehouse_requests')
              .insert(requestData)
              .select()
              .single();

          final requestId = requestResponse['id'] as String;

          // إنشاء عناصر الطلب
          final itemsData = warehousePlan.items.map((item) => {
            'request_id': requestId,
            'product_id': item.productId,
            'quantity': item.allocatedQuantity,
            'notes': 'توزيع ذكي - ${item.allocatedQuantity} من ${item.requestedQuantity} مطلوب',
          }).toList();

          await _supabase
              .from('warehouse_request_items')
              .insert(itemsData);

          // إنشاء نموذج طلب الصرف
          final dispatch = WarehouseDispatchModel.fromJson({
            ...requestResponse,
            'items': itemsData.map((item) => WarehouseDispatchItemModel(
              id: '${requestId}_${item['product_id']}',
              requestId: requestId,
              productId: item['product_id'] as String,
              quantity: item['quantity'] as int,
              notes: item['notes'] as String?,
            ).toJson()).toList(),
          });

          createdDispatches.add(dispatch);

          AppLogger.info('✅ تم إنشاء طلب صرف للمخزن: ${warehousePlan.warehouseName}');
        } catch (e) {
          final error = 'فشل في إنشاء طلب صرف للمخزن ${warehousePlan.warehouseName}: $e';
          errors.add(error);
          AppLogger.error('❌ $error');
        }
      }

      return MultiWarehouseDispatchResult(
        success: errors.isEmpty,
        createdDispatches: createdDispatches,
        distributionPlan: plan,
        errors: errors,
        totalDispatchesCreated: createdDispatches.length,
        totalWarehousesInvolved: plan.warehouseDispatches.length,
        completionPercentage: errors.isEmpty ? 100.0 : (createdDispatches.length / plan.warehouseDispatches.length * 100),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في تنفيذ خطة التوزيع: $e');
      throw Exception('فشل في تنفيذ خطة التوزيع: $e');
    }
  }

  /// توليد رقم طلب فريد
  String _generateRequestNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'WR-$timestamp';
  }

  /// تحويل القيمة إلى عدد صحيح
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// الحصول على رسالة خطأ محلية
  String _getLocalizedErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // خطأ قاعدة البيانات
    if (errorString.contains('connection') || errorString.contains('network')) {
      return 'خطأ في الاتصال بقاعدة البيانات. يرجى التحقق من الاتصال بالإنترنت والمحاولة مرة أخرى.';
    }

    // خطأ المصادقة
    if (errorString.contains('auth') || errorString.contains('unauthorized')) {
      return 'خطأ في المصادقة. يرجى تسجيل الدخول مرة أخرى.';
    }

    // خطأ الصلاحيات
    if (errorString.contains('permission') || errorString.contains('forbidden')) {
      return 'ليس لديك صلاحية لتنفيذ هذا الإجراء. يرجى التواصل مع المدير.';
    }

    // خطأ المخزون
    if (errorString.contains('stock') || errorString.contains('inventory')) {
      return 'خطأ في بيانات المخزون. قد تكون بعض المنتجات غير متوفرة أو تم تحديث المخزون.';
    }

    // خطأ المنتجات
    if (errorString.contains('product') || errorString.contains('item')) {
      return 'خطأ في بيانات المنتجات. يرجى التحقق من صحة المنتجات المحددة.';
    }

    // خطأ المخازن
    if (errorString.contains('warehouse')) {
      return 'خطأ في بيانات المخازن. قد تكون بعض المخازن غير متاحة أو معطلة.';
    }

    // خطأ التوزيع
    if (errorString.contains('distribution') || errorString.contains('allocation')) {
      return 'فشل في توزيع المنتجات على المخازن. قد تكون الكميات المطلوبة غير متوفرة.';
    }

    // خطأ عام
    return 'حدث خطأ غير متوقع في النظام. يرجى المحاولة مرة أخرى أو التواصل مع الدعم الفني.';
  }

  /// التحقق من صحة البيانات قبل التوزيع
  void _validateDistributionData({
    required String invoiceId,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required String requestedBy,
  }) {
    // التحقق من معرف الفاتورة
    if (invoiceId.isEmpty) {
      throw Exception('معرف الفاتورة مطلوب ولا يمكن أن يكون فارغاً.');
    }

    // التحقق من اسم العميل
    if (customerName.isEmpty) {
      throw Exception('اسم العميل مطلوب ولا يمكن أن يكون فارغاً.');
    }

    // التحقق من العناصر
    if (items.isEmpty) {
      throw Exception('لا توجد منتجات في الفاتورة للتوزيع.');
    }

    // التحقق من صحة كل عنصر
    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      if (item['product_id'] == null || item['product_id'].toString().isEmpty) {
        throw Exception('معرف المنتج مطلوب للعنصر رقم ${i + 1}.');
      }

      final quantity = _parseInt(item['quantity']);
      if (quantity == null || quantity <= 0) {
        throw Exception('كمية غير صحيحة للمنتج ${item['product_name'] ?? 'غير معروف'} (العنصر رقم ${i + 1}).');
      }
    }

    // التحقق من معرف المستخدم
    if (requestedBy.isEmpty) {
      throw Exception('معرف المستخدم مطلوب ولا يمكن أن يكون فارغاً.');
    }
  }

  /// معالجة الأخطاء الجزئية في التوزيع
  MultiWarehouseDispatchResult _handlePartialDistributionFailure({
    required List<WarehouseDispatchModel> successfulDispatches,
    required List<String> errors,
    required DistributionPlan originalPlan,
  }) {
    AppLogger.warning('⚠️ تم التوزيع الجزئي: ${successfulDispatches.length}/${originalPlan.warehouseDispatches.length} نجح');

    final completionPercentage = originalPlan.warehouseDispatches.isNotEmpty
        ? (successfulDispatches.length / originalPlan.warehouseDispatches.length * 100)
        : 0.0;

    return MultiWarehouseDispatchResult(
      success: false,
      createdDispatches: successfulDispatches,
      distributionPlan: originalPlan,
      errors: [
        'تم التوزيع الجزئي فقط (${successfulDispatches.length}/${originalPlan.warehouseDispatches.length})',
        ...errors,
      ],
      totalDispatchesCreated: successfulDispatches.length,
      totalWarehousesInvolved: originalPlan.warehouseDispatches.length,
      completionPercentage: completionPercentage,
    );
  }

  /// إنشاء معاينة التوزيع قبل التنفيذ
  Future<DistributionPreview> createDistributionPreview({
    required List<Map<String, dynamic>> items,
    WarehouseSelectionStrategy strategy = WarehouseSelectionStrategy.balanced,
  }) async {
    try {
      AppLogger.info('👁️ إنشاء معاينة التوزيع...');

      // تحويل العناصر إلى نماذج معالجة
      final processingProducts = items.map((item) {
        return DispatchProductProcessingModel.fromDispatchItem(
          itemId: 'preview_${item['product_id']}',
          requestId: 'preview',
          productId: item['product_id'].toString(),
          productName: item['product_name']?.toString() ?? 'منتج ${item['product_id']}',
          quantity: _parseInt(item['quantity']) ?? 1,
        );
      }).toList();

      // الكشف عن المواقع
      final productsWithLocations = await _locationService.detectProductLocationsAdvanced(
        products: processingProducts,
        strategy: strategy,
        enrichWithDetails: true,
        respectMinimumStock: true,
        maxWarehousesPerProduct: 3,
      );

      // تحليل النتائج
      final warehouseSummary = <String, WarehouseDistributionSummary>{};
      var totalFulfillableProducts = 0;
      var totalPartiallyFulfillableProducts = 0;
      var totalUnfulfillableProducts = 0;

      for (final product in productsWithLocations) {
        if (!product.hasLocationData || product.warehouseLocations == null || product.warehouseLocations!.isEmpty) {
          totalUnfulfillableProducts++;
          continue;
        }

        if (product.canFulfillRequest) {
          totalFulfillableProducts++;
        } else if (product.totalAvailableQuantity > 0) {
          totalPartiallyFulfillableProducts++;
        } else {
          totalUnfulfillableProducts++;
        }

        // تجميع المخازن
        for (final location in product.warehouseLocations!) {
          final warehouseId = location.warehouseId;
          
          if (!warehouseSummary.containsKey(warehouseId)) {
            warehouseSummary[warehouseId] = WarehouseDistributionSummary(
              warehouseId: warehouseId,
              warehouseName: location.warehouseName,
              productCount: 0,
              totalQuantity: 0,
              canFulfillCompletely: true,
            );
          }

          final summary = warehouseSummary[warehouseId]!;
          warehouseSummary[warehouseId] = summary.copyWith(
            productCount: summary.productCount + 1,
            totalQuantity: summary.totalQuantity + location.availableQuantity,
            canFulfillCompletely: summary.canFulfillCompletely && product.canFulfillRequest,
          );
        }
      }

      return DistributionPreview(
        totalProducts: processingProducts.length,
        fulfillableProducts: totalFulfillableProducts,
        partiallyFulfillableProducts: totalPartiallyFulfillableProducts,
        unfulfillableProducts: totalUnfulfillableProducts,
        warehouseSummaries: warehouseSummary.values.toList(),
        canProceed: totalUnfulfillableProducts == 0,
        recommendedStrategy: strategy,
        previewTimestamp: DateTime.now(),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء معاينة التوزيع: $e');
      throw Exception('فشل في إنشاء معاينة التوزيع: $e');
    }
  }
}
