import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../models/warehouse_model.dart';

/// نموذج بيانات نتيجة التحقق من صحة النقل
class TransferValidationResult {
  final bool isValid;
  final int transferableOrders;
  final int blockedOrders;
  final List<String> validationErrors;
  final Map<String, dynamic> transferSummary;

  const TransferValidationResult({
    required this.isValid,
    required this.transferableOrders,
    required this.blockedOrders,
    required this.validationErrors,
    required this.transferSummary,
  });

  factory TransferValidationResult.fromJson(Map<String, dynamic> json) {
    return TransferValidationResult(
      isValid: json['is_valid'] ?? false,
      transferableOrders: json['transferable_orders'] ?? 0,
      blockedOrders: json['blocked_orders'] ?? 0,
      validationErrors: List<String>.from(json['validation_errors'] ?? []),
      transferSummary: json['transfer_summary'] ?? {},
    );
  }
}

/// نموذج بيانات نتيجة تنفيذ النقل
class OrderTransferResult {
  final bool success;
  final int transferredCount;
  final int failedCount;
  final String? transferId;
  final List<String> errors;
  final Map<String, dynamic> summary;

  const OrderTransferResult({
    required this.success,
    required this.transferredCount,
    required this.failedCount,
    this.transferId,
    required this.errors,
    required this.summary,
  });

  factory OrderTransferResult.fromJson(Map<String, dynamic> json) {
    return OrderTransferResult(
      success: json['success'] ?? false,
      transferredCount: json['transferred_count'] ?? 0,
      failedCount: json['failed_count'] ?? 0,
      transferId: json['transfer_id'],
      errors: List<String>.from(json['errors'] ?? []),
      summary: json['summary'] ?? {},
    );
  }

  /// معدل النجاح كنسبة مئوية
  double get successRate {
    final total = transferredCount + failedCount;
    if (total == 0) return 0.0;
    return (transferredCount / total) * 100;
  }
}

/// نموذج بيانات المخزن المتاح للنقل
class AvailableTargetWarehouse {
  final String id;
  final String name;
  final String location;
  final int totalCapacity;
  final int currentInventoryCount;
  final int availableCapacity;
  final int suitabilityScore;

  const AvailableTargetWarehouse({
    required this.id,
    required this.name,
    required this.location,
    required this.totalCapacity,
    required this.currentInventoryCount,
    required this.availableCapacity,
    required this.suitabilityScore,
  });

  factory AvailableTargetWarehouse.fromJson(Map<String, dynamic> json) {
    return AvailableTargetWarehouse(
      id: json['warehouse_id'] ?? '',
      name: json['warehouse_name'] ?? '',
      location: json['warehouse_location'] ?? 'غير محدد',
      totalCapacity: json['total_capacity'] ?? 0,
      currentInventoryCount: json['current_inventory_count'] ?? 0,
      availableCapacity: json['available_capacity'] ?? 0,
      suitabilityScore: json['suitability_score'] ?? 0,
    );
  }
}

/// خدمة نقل الطلبات بين المخازن للحذف القسري
class WarehouseOrderTransferService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// الحصول على المخازن المتاحة للنقل
  Future<List<AvailableTargetWarehouse>> getAvailableTargetWarehouses(
    String sourceWarehouseId, {
    bool excludeEmpty = true,
  }) async {
    try {
      AppLogger.info('🔍 جاري البحث عن المخازن المتاحة للنقل من: $sourceWarehouseId');

      final response = await _supabase.rpc(
        'get_available_target_warehouses',
        params: {
          'p_source_warehouse_id': sourceWarehouseId,
          'p_exclude_empty': excludeEmpty,
        },
      );

      if (response == null) {
        AppLogger.warning('⚠️ لم يتم إرجاع بيانات من دالة المخازن المتاحة');
        return [];
      }

      final warehouses = (response as List)
          .map((item) => AvailableTargetWarehouse.fromJson(item))
          .toList();

      AppLogger.info('✅ تم العثور على ${warehouses.length} مخزن متاح للنقل');
      return warehouses;
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على المخازن المتاحة: $e');
      return [];
    }
  }

  /// التحقق من صحة عملية النقل
  Future<TransferValidationResult> validateOrderTransfer(
    String sourceWarehouseId,
    String targetWarehouseId, {
    List<String>? orderIds,
  }) async {
    try {
      AppLogger.info('🔍 التحقق من صحة نقل الطلبات من $sourceWarehouseId إلى $targetWarehouseId');

      final response = await _supabase.rpc(
        'validate_order_transfer',
        params: {
          'p_source_warehouse_id': sourceWarehouseId,
          'p_target_warehouse_id': targetWarehouseId,
          'p_order_ids': orderIds,
        },
      );

      if (response == null || response.isEmpty) {
        throw Exception('لم يتم إرجاع نتائج التحقق من صحة النقل');
      }

      final result = TransferValidationResult.fromJson(response.first);
      
      if (result.isValid) {
        AppLogger.info('✅ التحقق من صحة النقل نجح - يمكن نقل ${result.transferableOrders} طلب');
      } else {
        AppLogger.warning('⚠️ التحقق من صحة النقل فشل - ${result.validationErrors.join(', ')}');
      }

      return result;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من صحة النقل: $e');
      return TransferValidationResult(
        isValid: false,
        transferableOrders: 0,
        blockedOrders: 0,
        validationErrors: ['خطأ في التحقق: $e'],
        transferSummary: {},
      );
    }
  }

  /// تنفيذ نقل الطلبات
  Future<OrderTransferResult> executeOrderTransfer(
    String sourceWarehouseId,
    String targetWarehouseId, {
    List<String>? orderIds,
    String? performedBy,
    String transferReason = 'نقل طلبات لحذف المخزن',
  }) async {
    try {
      AppLogger.info('🔄 بدء تنفيذ نقل الطلبات من $sourceWarehouseId إلى $targetWarehouseId');

      // التحقق من صحة النقل أولاً
      final validation = await validateOrderTransfer(
        sourceWarehouseId,
        targetWarehouseId,
        orderIds: orderIds,
      );

      if (!validation.isValid) {
        return OrderTransferResult(
          success: false,
          transferredCount: 0,
          failedCount: validation.blockedOrders,
          errors: validation.validationErrors,
          summary: {
            'validation_failed': true,
            'validation_errors': validation.validationErrors,
          },
        );
      }

      // تنفيذ النقل
      final response = await _supabase.rpc(
        'execute_order_transfer',
        params: {
          'p_source_warehouse_id': sourceWarehouseId,
          'p_target_warehouse_id': targetWarehouseId,
          'p_order_ids': orderIds,
          'p_performed_by': performedBy,
          'p_transfer_reason': transferReason,
        },
      );

      if (response == null) {
        throw Exception('لم يتم إرجاع نتائج تنفيذ النقل');
      }

      final result = OrderTransferResult.fromJson(response);
      
      if (result.success) {
        AppLogger.info('✅ تم نقل ${result.transferredCount} طلب بنجاح');
        if (result.failedCount > 0) {
          AppLogger.warning('⚠️ فشل في نقل ${result.failedCount} طلب');
        }
      } else {
        AppLogger.error('❌ فشل في تنفيذ النقل - ${result.errors.join(', ')}');
      }

      return result;
    } catch (e) {
      AppLogger.error('❌ خطأ في تنفيذ نقل الطلبات: $e');
      return OrderTransferResult(
        success: false,
        transferredCount: 0,
        failedCount: 0,
        errors: ['خطأ في التنفيذ: $e'],
        summary: {'execution_error': e.toString()},
      );
    }
  }

  /// الحصول على تفاصيل الطلبات النشطة في مخزن معين
  Future<List<Map<String, dynamic>>> getActiveOrdersInWarehouse(
    String warehouseId,
  ) async {
    try {
      AppLogger.info('📋 جاري الحصول على الطلبات النشطة في المخزن: $warehouseId');

      final response = await _supabase
          .from('warehouse_requests')
          .select('''
            id,
            request_number,
            status,
            requested_by,
            created_at,
            reason,
            metadata
          ''')
          .eq('warehouse_id', warehouseId)
          .inFilter('status', ['pending', 'approved', 'in_progress'])
          .order('created_at', ascending: false);

      AppLogger.info('✅ تم العثور على ${response.length} طلب نشط');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على الطلبات النشطة: $e');
      return [];
    }
  }

  /// إحصائيات النقل لمخزن معين
  Future<Map<String, dynamic>> getTransferStatistics(String warehouseId) async {
    try {
      AppLogger.info('📊 جاري الحصول على إحصائيات النقل للمخزن: $warehouseId');

      final activeOrders = await getActiveOrdersInWarehouse(warehouseId);
      final availableWarehouses = await getAvailableTargetWarehouses(warehouseId);

      return {
        'active_orders_count': activeOrders.length,
        'available_target_warehouses': availableWarehouses.length,
        'suitable_warehouses': availableWarehouses
            .where((w) => w.suitabilityScore >= 60)
            .length,
        'high_capacity_warehouses': availableWarehouses
            .where((w) => w.availableCapacity > 500)
            .length,
        'transfer_feasible': activeOrders.isNotEmpty && availableWarehouses.isNotEmpty,
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على إحصائيات النقل: $e');
      return {
        'active_orders_count': 0,
        'available_target_warehouses': 0,
        'suitable_warehouses': 0,
        'high_capacity_warehouses': 0,
        'transfer_feasible': false,
        'error': e.toString(),
      };
    }
  }
}
