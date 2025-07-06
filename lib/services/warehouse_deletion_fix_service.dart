import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

/// خدمة إصلاح مشكلة حذف المخازن وتحويل الطلبات إلى عالمية
class WarehouseDeletionFixService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// تحويل طلب سحب تقليدي إلى عالمي
  Future<bool> convertRequestToGlobal(String requestId) async {
    try {
      AppLogger.info('🔄 تحويل طلب إلى عالمي: $requestId');

      final result = await _supabase.rpc(
        'convert_request_to_global',
        params: {'p_request_id': requestId},
      );

      if (result == true) {
        AppLogger.info('✅ تم تحويل الطلب إلى عالمي بنجاح');
        return true;
      } else {
        AppLogger.error('❌ فشل في تحويل الطلب إلى عالمي');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحويل الطلب إلى عالمي: $e');
      return false;
    }
  }

  /// فحص إمكانية حذف المخزن (النسخة المحدثة)
  Future<WarehouseDeletionCheck> checkWarehouseDeletion(String warehouseId) async {
    try {
      AppLogger.info('🔍 فحص إمكانية حذف المخزن: $warehouseId');

      final result = await _supabase.rpc(
        'can_delete_warehouse_v2',
        params: {'p_warehouse_id': warehouseId},
      );

      if (result.isNotEmpty) {
        final data = result.first;
        return WarehouseDeletionCheck(
          canDelete: data['can_delete'] ?? false,
          blockingReason: data['blocking_reason'] ?? '',
          activeRequests: data['active_requests'] ?? 0,
          inventoryItems: data['inventory_items'] ?? 0,
          recentTransactions: data['recent_transactions'] ?? 0,
        );
      } else {
        throw Exception('لم يتم إرجاع نتائج من فحص المخزن');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في فحص إمكانية حذف المخزن: $e');
      return WarehouseDeletionCheck(
        canDelete: false,
        blockingReason: 'خطأ في الفحص: $e',
        activeRequests: 0,
        inventoryItems: 0,
        recentTransactions: 0,
      );
    }
  }

  /// حذف المخزن بأمان باستخدام الدالة المحدثة
  Future<WarehouseDeletionResult> safeDeleteWarehouse(String warehouseId) async {
    try {
      AppLogger.info('🗑️ بدء الحذف الآمن للمخزن: $warehouseId');

      final result = await _supabase.rpc(
        'safe_delete_warehouse',
        params: {'p_warehouse_id': warehouseId},
      );

      if (result != null) {
        final success = result['success'] ?? false;
        final message = result['message'] ?? result['error'] ?? '';
        final convertedRequests = result['converted_requests'] ?? 0;
        final details = result['details'];

        if (success) {
          AppLogger.info('✅ تم حذف المخزن بنجاح');
        } else {
          AppLogger.error('❌ فشل في حذف المخزن: $message');
        }

        return WarehouseDeletionResult(
          success: success,
          message: message,
          convertedRequests: convertedRequests,
          details: details,
        );
      } else {
        throw Exception('لم يتم إرجاع نتيجة من دالة الحذف');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في الحذف الآمن للمخزن: $e');
      return WarehouseDeletionResult(
        success: false,
        message: 'خطأ في حذف المخزن: $e',
        convertedRequests: 0,
        details: null,
      );
    }
  }

  /// تحويل جميع طلبات مخزن معين إلى عالمية
  Future<int> convertAllWarehouseRequestsToGlobal(String warehouseId) async {
    try {
      AppLogger.info('🔄 تحويل جميع طلبات المخزن إلى عالمية: $warehouseId');

      // الحصول على جميع طلبات المخزن
      final requests = await _supabase
          .from('warehouse_requests')
          .select('id')
          .eq('warehouse_id', warehouseId)
          .eq('is_global_request', false);

      int convertedCount = 0;
      for (final request in requests) {
        final success = await convertRequestToGlobal(request['id']);
        if (success) {
          convertedCount++;
        }
      }

      AppLogger.info('✅ تم تحويل $convertedCount طلب إلى عالمي');
      return convertedCount;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحويل طلبات المخزن: $e');
      return 0;
    }
  }

  /// الحصول على قائمة الطلبات المرتبطة بمخزن معين
  Future<List<WarehouseRequestInfo>> getWarehouseRequests(String warehouseId) async {
    try {
      final response = await _supabase
          .from('warehouse_requests')
          .select('id, type, status, reason, created_at, is_global_request')
          .eq('warehouse_id', warehouseId)
          .order('created_at', ascending: false);

      return response.map<WarehouseRequestInfo>((item) {
        return WarehouseRequestInfo(
          id: item['id'],
          type: item['type'],
          status: item['status'],
          reason: item['reason'] ?? '',
          createdAt: DateTime.parse(item['created_at']),
          isGlobal: item['is_global_request'] ?? false,
        );
      }).toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على طلبات المخزن: $e');
      return [];
    }
  }

  /// إصلاح شامل لمشكلة حذف المخزن
  Future<WarehouseFixResult> comprehensiveWarehouseFix(String warehouseId) async {
    try {
      AppLogger.info('🔧 بدء الإصلاح الشامل للمخزن: $warehouseId');

      // الخطوة 1: فحص الوضع الحالي
      final check = await checkWarehouseDeletion(warehouseId);
      
      if (check.canDelete) {
        // يمكن الحذف مباشرة
        final deleteResult = await safeDeleteWarehouse(warehouseId);
        return WarehouseFixResult(
          success: deleteResult.success,
          message: deleteResult.message,
          stepsPerformed: ['فحص الوضع', 'حذف المخزن'],
          convertedRequests: deleteResult.convertedRequests,
          deletionResult: deleteResult,
        );
      }

      // الخطوة 2: تحويل الطلبات إلى عالمية
      final convertedCount = await convertAllWarehouseRequestsToGlobal(warehouseId);
      
      // الخطوة 3: فحص مرة أخرى
      final recheckResult = await checkWarehouseDeletion(warehouseId);
      
      if (recheckResult.canDelete) {
        // الخطوة 4: محاولة الحذف
        final deleteResult = await safeDeleteWarehouse(warehouseId);
        return WarehouseFixResult(
          success: deleteResult.success,
          message: deleteResult.message,
          stepsPerformed: [
            'فحص الوضع الأولي',
            'تحويل $convertedCount طلب إلى عالمي',
            'إعادة فحص الوضع',
            'حذف المخزن'
          ],
          convertedRequests: convertedCount + deleteResult.convertedRequests,
          deletionResult: deleteResult,
        );
      } else {
        return WarehouseFixResult(
          success: false,
          message: 'لا يزال لا يمكن حذف المخزن: ${recheckResult.blockingReason}',
          stepsPerformed: [
            'فحص الوضع الأولي',
            'تحويل $convertedCount طلب إلى عالمي',
            'إعادة فحص الوضع - فشل'
          ],
          convertedRequests: convertedCount,
          deletionResult: null,
        );
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في الإصلاح الشامل: $e');
      return WarehouseFixResult(
        success: false,
        message: 'خطأ في الإصلاح الشامل: $e',
        stepsPerformed: ['خطأ في البداية'],
        convertedRequests: 0,
        deletionResult: null,
      );
    }
  }
}

/// نتيجة فحص إمكانية حذف المخزن
class WarehouseDeletionCheck {
  final bool canDelete;
  final String blockingReason;
  final int activeRequests;
  final int inventoryItems;
  final int recentTransactions;

  const WarehouseDeletionCheck({
    required this.canDelete,
    required this.blockingReason,
    required this.activeRequests,
    required this.inventoryItems,
    required this.recentTransactions,
  });

  /// هل هناك عوامل مانعة
  bool get hasBlockingFactors => !canDelete;

  /// ملخص العوامل المانعة
  String get blockingSummary {
    if (canDelete) return 'لا توجد عوامل مانعة';
    
    final factors = <String>[];
    if (activeRequests > 0) factors.add('$activeRequests طلب نشط');
    if (inventoryItems > 0) factors.add('$inventoryItems منتج بمخزون');
    
    return factors.join(', ');
  }
}

/// نتيجة حذف المخزن
class WarehouseDeletionResult {
  final bool success;
  final String message;
  final int convertedRequests;
  final Map<String, dynamic>? details;

  const WarehouseDeletionResult({
    required this.success,
    required this.message,
    required this.convertedRequests,
    this.details,
  });
}

/// نتيجة الإصلاح الشامل
class WarehouseFixResult {
  final bool success;
  final String message;
  final List<String> stepsPerformed;
  final int convertedRequests;
  final WarehouseDeletionResult? deletionResult;

  const WarehouseFixResult({
    required this.success,
    required this.message,
    required this.stepsPerformed,
    required this.convertedRequests,
    this.deletionResult,
  });

  /// ملخص الإصلاح
  String get fixSummary {
    if (success) {
      return 'تم الإصلاح بنجاح - تحويل $convertedRequests طلب وحذف المخزن';
    } else {
      return 'فشل الإصلاح - تم تحويل $convertedRequests طلب فقط';
    }
  }
}

/// معلومات طلب المخزن
class WarehouseRequestInfo {
  final String id;
  final String type;
  final String status;
  final String reason;
  final DateTime createdAt;
  final bool isGlobal;

  const WarehouseRequestInfo({
    required this.id,
    required this.type,
    required this.status,
    required this.reason,
    required this.createdAt,
    required this.isGlobal,
  });

  /// نص نوع الطلب
  String get typeText {
    switch (type) {
      case 'withdrawal':
        return 'سحب';
      case 'addition':
        return 'إضافة';
      case 'transfer':
        return 'نقل';
      default:
        return type;
    }
  }

  /// نص حالة الطلب
  String get statusText {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'approved':
        return 'موافق عليه';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  /// نص نوع الطلب (عالمي أم تقليدي)
  String get requestTypeText => isGlobal ? 'عالمي' : 'تقليدي';
}
