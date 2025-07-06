import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/warehouse_request_model.dart';
import '../models/global_inventory_models.dart';
import '../models/global_withdrawal_models.dart';
import '../services/global_inventory_service.dart';
import '../utils/app_logger.dart';

/// خدمة معالجة طلبات السحب التلقائي
class AutomatedWithdrawalService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalInventoryService _globalInventoryService = GlobalInventoryService();

  /// معالجة طلب سحب عند تغيير الحالة إلى "مكتمل"
  Future<WithdrawalProcessingResult> processWithdrawalRequest({
    required String requestId,
    required String performedBy,
    WarehouseSelectionStrategy strategy = WarehouseSelectionStrategy.balanced,
  }) async {
    try {
      AppLogger.info('🔄 بدء معالجة طلب السحب: $requestId');

      // الحصول على تفاصيل الطلب
      final request = await _getWithdrawalRequest(requestId);
      if (request == null) {
        throw Exception('طلب السحب غير موجود: $requestId');
      }

      // التحقق من حالة الطلب
      if (request.status != 'completed') {
        throw Exception('طلب السحب ليس في حالة مكتمل: ${request.status}');
      }

      // الحصول على عناصر الطلب
      final requestItems = await _getWithdrawalRequestItems(requestId);
      if (requestItems.isEmpty) {
        throw Exception('لا توجد عناصر في طلب السحب');
      }

      AppLogger.info('📋 عناصر الطلب: ${requestItems.length}');

      // معالجة كل عنصر في الطلب
      final itemResults = <WithdrawalItemResult>[];
      var overallSuccess = true;
      final errors = <String>[];

      for (final item in requestItems) {
        try {
          final itemResult = await _processWithdrawalItem(
            item: item,
            requestId: requestId,
            performedBy: performedBy,
            strategy: strategy,
          );

          itemResults.add(itemResult);

          if (!itemResult.success) {
            overallSuccess = false;
            errors.addAll(itemResult.errors);
          }

          AppLogger.info('${itemResult.success ? "✅" : "❌"} معالجة العنصر ${item.productId}: ${itemResult.summaryText}');
        } catch (e) {
          final error = 'فشل في معالجة العنصر ${item.productId}: $e';
          errors.add(error);
          overallSuccess = false;
          AppLogger.error('❌ $error');

          // إضافة نتيجة فاشلة
          itemResults.add(WithdrawalItemResult(
            productId: item.productId,
            productName: item.productName ?? 'غير معروف',
            requestedQuantity: item.quantity,
            processedQuantity: 0,
            success: false,
            errors: [error],
            searchResult: null,
            deductionResult: null,
            processingTime: DateTime.now(),
          ));
        }
      }

      // تحديث حالة الطلب
      await _updateRequestProcessingStatus(
        requestId: requestId,
        success: overallSuccess,
        itemResults: itemResults,
        performedBy: performedBy,
      );

      final result = WithdrawalProcessingResult(
        requestId: requestId,
        success: overallSuccess,
        itemResults: itemResults,
        errors: errors,
        processingTime: DateTime.now(),
        performedBy: performedBy,
        strategy: strategy,
      );

      AppLogger.info('📊 نتائج معالجة الطلب:');
      AppLogger.info('   النجاح الإجمالي: ${overallSuccess ? "نعم" : "لا"}');
      AppLogger.info('   العناصر المعالجة: ${itemResults.length}');
      AppLogger.info('   العناصر الناجحة: ${result.successfulItemsCount}');
      AppLogger.info('   الأخطاء: ${errors.length}');

      return result;
    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة طلب السحب: $e');
      throw Exception('فشل في معالجة طلب السحب: $e');
    }
  }

  /// معالجة عنصر واحد من طلب السحب
  Future<WithdrawalItemResult> _processWithdrawalItem({
    required WithdrawalRequestItem item,
    required String requestId,
    required String performedBy,
    required WarehouseSelectionStrategy strategy,
  }) async {
    try {
      AppLogger.info('🔍 معالجة العنصر: ${item.productId} - الكمية: ${item.quantity}');

      // البحث العالمي عن المنتج
      final searchResult = await _globalInventoryService.searchProductGlobally(
        productId: item.productId,
        requestedQuantity: item.quantity,
        strategy: strategy,
      );

      if (!searchResult.canFulfill) {
        return WithdrawalItemResult(
          productId: item.productId,
          productName: item.productName ?? 'غير معروف',
          requestedQuantity: item.quantity,
          processedQuantity: 0,
          success: false,
          errors: ['المخزون غير كافي - متاح: ${searchResult.totalAvailableQuantity}, مطلوب: ${item.quantity}'],
          searchResult: searchResult,
          deductionResult: null,
          processingTime: DateTime.now(),
        );
      }

      // تنفيذ خطة التخصيص والخصم
      final deductionResult = await _globalInventoryService.executeAllocationPlan(
        allocationPlan: searchResult.allocationPlan,
        requestId: requestId,
        performedBy: performedBy,
        reason: 'سحب تلقائي للطلب $requestId - ${item.productName ?? item.productId}',
      );

      return WithdrawalItemResult(
        productId: item.productId,
        productName: item.productName ?? 'غير معروف',
        requestedQuantity: item.quantity,
        processedQuantity: deductionResult.totalDeductedQuantity,
        success: deductionResult.success,
        errors: deductionResult.errors,
        searchResult: searchResult,
        deductionResult: deductionResult,
        processingTime: DateTime.now(),
      );
    } catch (e) {
      return WithdrawalItemResult(
        productId: item.productId,
        productName: item.productName ?? 'غير معروف',
        requestedQuantity: item.quantity,
        processedQuantity: 0,
        success: false,
        errors: ['خطأ في المعالجة: $e'],
        searchResult: null,
        deductionResult: null,
        processingTime: DateTime.now(),
      );
    }
  }

  /// الحصول على تفاصيل طلب السحب
  Future<WarehouseRequestModel?> _getWithdrawalRequest(String requestId) async {
    try {
      final response = await _supabase
          .from('warehouse_requests')
          .select('*')
          .eq('id', requestId)
          .eq('type', 'withdrawal')
          .maybeSingle();

      if (response == null) return null;

      return WarehouseRequestModel.fromJson(response);
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على طلب السحب: $e');
      return null;
    }
  }

  /// الحصول على عناصر طلب السحب
  Future<List<WithdrawalRequestItem>> _getWithdrawalRequestItems(String requestId) async {
    try {
      final response = await _supabase
          .from('warehouse_request_items')
          .select('''
            *,
            product:products (
              id,
              name,
              sku,
              category
            )
          ''')
          .eq('request_id', requestId);

      return response.map<WithdrawalRequestItem>((item) {
        final productData = item['product'] as Map<String, dynamic>?;
        return WithdrawalRequestItem(
          id: item['id'],
          requestId: requestId,
          productId: item['product_id'],
          productName: productData?['name'],
          productSku: productData?['sku'],
          quantity: item['quantity'],
          notes: item['notes'],
        );
      }).toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على عناصر طلب السحب: $e');
      return [];
    }
  }

  /// تحديث حالة معالجة الطلب
  Future<void> _updateRequestProcessingStatus({
    required String requestId,
    required bool success,
    required List<WithdrawalItemResult> itemResults,
    required String performedBy,
  }) async {
    try {
      final processingMetadata = {
        'auto_processed': true,
        'processing_success': success,
        'processed_at': DateTime.now().toIso8601String(),
        'processed_by': performedBy,
        'items_processed': itemResults.length,
        'items_successful': itemResults.where((r) => r.success).length,
        'items_failed': itemResults.where((r) => !r.success).length,
        'total_requested': itemResults.fold<int>(0, (sum, r) => sum + r.requestedQuantity),
        'total_processed': itemResults.fold<int>(0, (sum, r) => sum + r.processedQuantity),
        'warehouses_involved': itemResults
            .expand((r) => r.deductionResult?.warehouseResults ?? [])
            .map((wr) => wr.warehouseId)
            .toSet()
            .toList(),
      };

      await _supabase
          .from('warehouse_requests')
          .update({
            'metadata': processingMetadata,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      AppLogger.info('✅ تم تحديث حالة معالجة الطلب: $requestId');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث حالة معالجة الطلب: $e');
    }
  }

  /// معالجة طلبات السحب المكتملة تلقائياً
  Future<List<WithdrawalProcessingResult>> processCompletedWithdrawals({
    WarehouseSelectionStrategy strategy = WarehouseSelectionStrategy.balanced,
    int? limit,
  }) async {
    try {
      AppLogger.info('🔄 البحث عن طلبات السحب المكتملة للمعالجة التلقائية');

      // البحث عن طلبات السحب المكتملة غير المعالجة
      var query = _supabase
          .from('warehouse_requests')
          .select('id, created_at')
          .eq('type', 'withdrawal')
          .eq('status', 'completed')
          .is_('metadata->auto_processed', null)
          .order('created_at', ascending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      if (response.isEmpty) {
        AppLogger.info('ℹ️ لا توجد طلبات سحب مكتملة تحتاج معالجة');
        return [];
      }

      AppLogger.info('📋 تم العثور على ${response.length} طلب سحب للمعالجة');

      final results = <WithdrawalProcessingResult>[];

      for (final request in response) {
        try {
          final result = await processWithdrawalRequest(
            requestId: request['id'],
            performedBy: 'system_auto_processor',
            strategy: strategy,
          );
          results.add(result);
        } catch (e) {
          AppLogger.error('❌ فشل في معالجة الطلب ${request['id']}: $e');
        }
      }

      AppLogger.info('✅ تم معالجة ${results.length} طلب سحب تلقائياً');
      return results;
    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة طلبات السحب المكتملة: $e');
      return [];
    }
  }

  /// التحقق من إمكانية تلبية طلب سحب قبل الموافقة عليه
  Future<WithdrawalFeasibilityCheck> checkWithdrawalFeasibility({
    required String requestId,
    WarehouseSelectionStrategy strategy = WarehouseSelectionStrategy.balanced,
  }) async {
    try {
      AppLogger.info('🔍 التحقق من إمكانية تلبية طلب السحب: $requestId');

      final requestItems = await _getWithdrawalRequestItems(requestId);
      if (requestItems.isEmpty) {
        throw Exception('لا توجد عناصر في طلب السحب');
      }

      final itemChecks = <WithdrawalItemFeasibility>[];
      var overallFeasible = true;
      var totalShortfall = 0;

      for (final item in requestItems) {
        final searchResult = await _globalInventoryService.searchProductGlobally(
          productId: item.productId,
          requestedQuantity: item.quantity,
          strategy: strategy,
        );

        final itemFeasible = searchResult.canFulfill;
        if (!itemFeasible) {
          overallFeasible = false;
          totalShortfall += searchResult.shortfallQuantity;
        }

        itemChecks.add(WithdrawalItemFeasibility(
          productId: item.productId,
          productName: item.productName ?? 'غير معروف',
          requestedQuantity: item.quantity,
          availableQuantity: searchResult.totalAvailableQuantity,
          canFulfill: itemFeasible,
          shortfall: searchResult.shortfallQuantity,
          requiredWarehouses: searchResult.requiredWarehousesCount,
          searchResult: searchResult,
        ));
      }

      return WithdrawalFeasibilityCheck(
        requestId: requestId,
        overallFeasible: overallFeasible,
        totalItems: requestItems.length,
        feasibleItems: itemChecks.where((c) => c.canFulfill).length,
        totalShortfall: totalShortfall,
        itemChecks: itemChecks,
        checkTime: DateTime.now(),
        strategy: strategy,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من إمكانية تلبية طلب السحب: $e');
      throw Exception('فشل في التحقق من إمكانية تلبية طلب السحب: $e');
    }
  }
}

/// عنصر في طلب السحب
class WithdrawalRequestItem {
  final String id;
  final String requestId;
  final String productId;
  final String? productName;
  final String? productSku;
  final int quantity;
  final String? notes;

  const WithdrawalRequestItem({
    required this.id,
    required this.requestId,
    required this.productId,
    this.productName,
    this.productSku,
    required this.quantity,
    this.notes,
  });
}

/// نتيجة معالجة طلب السحب
class WithdrawalProcessingResult {
  final String requestId;
  final bool success;
  final List<WithdrawalItemResult> itemResults;
  final List<String> errors;
  final DateTime processingTime;
  final String performedBy;
  final WarehouseSelectionStrategy strategy;

  const WithdrawalProcessingResult({
    required this.requestId,
    required this.success,
    required this.itemResults,
    required this.errors,
    required this.processingTime,
    required this.performedBy,
    required this.strategy,
  });

  /// عدد العناصر الناجحة
  int get successfulItemsCount => itemResults.where((r) => r.success).length;

  /// عدد العناصر الفاشلة
  int get failedItemsCount => itemResults.where((r) => !r.success).length;

  /// إجمالي الكمية المطلوبة
  int get totalRequestedQuantity => itemResults.fold(0, (sum, r) => sum + r.requestedQuantity);

  /// إجمالي الكمية المعالجة
  int get totalProcessedQuantity => itemResults.fold(0, (sum, r) => sum + r.processedQuantity);

  /// نسبة النجاح
  double get successPercentage => itemResults.isNotEmpty ? (successfulItemsCount / itemResults.length * 100) : 0;

  /// المخازن المشاركة
  Set<String> get involvedWarehouses => itemResults
      .expand((r) => r.deductionResult?.warehouseResults ?? [])
      .map((wr) => wr.warehouseId)
      .toSet();
}

/// نتيجة معالجة عنصر واحد
class WithdrawalItemResult {
  final String productId;
  final String productName;
  final int requestedQuantity;
  final int processedQuantity;
  final bool success;
  final List<String> errors;
  final GlobalInventorySearchResult? searchResult;
  final InventoryDeductionResult? deductionResult;
  final DateTime processingTime;

  const WithdrawalItemResult({
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.processedQuantity,
    required this.success,
    required this.errors,
    this.searchResult,
    this.deductionResult,
    required this.processingTime,
  });

  /// نسبة المعالجة
  double get processingPercentage => requestedQuantity > 0 ? (processedQuantity / requestedQuantity * 100) : 0;

  /// الكمية المتبقية
  int get remainingQuantity => requestedQuantity - processedQuantity;

  /// ملخص النتيجة
  String get summaryText {
    if (success) {
      return 'تم معالجة ${processingPercentage.toStringAsFixed(1)}% (${processedQuantity}/${requestedQuantity})';
    } else {
      return 'فشل في المعالجة - ${errors.length} خطأ';
    }
  }
}

/// فحص إمكانية تلبية طلب السحب
class WithdrawalFeasibilityCheck {
  final String requestId;
  final bool overallFeasible;
  final int totalItems;
  final int feasibleItems;
  final int totalShortfall;
  final List<WithdrawalItemFeasibility> itemChecks;
  final DateTime checkTime;
  final WarehouseSelectionStrategy strategy;

  const WithdrawalFeasibilityCheck({
    required this.requestId,
    required this.overallFeasible,
    required this.totalItems,
    required this.feasibleItems,
    required this.totalShortfall,
    required this.itemChecks,
    required this.checkTime,
    required this.strategy,
  });

  /// نسبة العناصر القابلة للتلبية
  double get feasibilityPercentage => totalItems > 0 ? (feasibleItems / totalItems * 100) : 0;

  /// عدد العناصر غير القابلة للتلبية
  int get infeasibleItems => totalItems - feasibleItems;
}

/// إمكانية تلبية عنصر واحد
class WithdrawalItemFeasibility {
  final String productId;
  final String productName;
  final int requestedQuantity;
  final int availableQuantity;
  final bool canFulfill;
  final int shortfall;
  final int requiredWarehouses;
  final GlobalInventorySearchResult searchResult;

  const WithdrawalItemFeasibility({
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.availableQuantity,
    required this.canFulfill,
    required this.shortfall,
    required this.requiredWarehouses,
    required this.searchResult,
  });

  /// نسبة التوفر
  double get availabilityPercentage => requestedQuantity > 0 ? (availableQuantity / requestedQuantity * 100).clamp(0, 100) : 0;
}
