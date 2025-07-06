import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/global_withdrawal_models.dart';
import '../models/warehouse_request_model.dart';
import '../utils/app_logger.dart';

/// خدمة السحب العالمي المحسنة - تزيل الاعتماد على المخازن المحددة
class EnhancedGlobalWithdrawalService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// إنشاء طلب سحب عالمي (بدون تحديد مخزن)
  Future<GlobalWithdrawalRequest> createGlobalWithdrawalRequest({
    required String reason,
    required List<WithdrawalRequestItem> items,
    required String requestedBy,
    String allocationStrategy = 'balanced',
  }) async {
    try {
      AppLogger.info('🌍 إنشاء طلب سحب عالمي جديد');

      // إنشاء الطلب الأساسي بدون warehouse_id
      final requestResponse = await _supabase
          .from('warehouse_requests')
          .insert({
            'type': 'withdrawal',
            'status': 'pending',
            'reason': reason,
            'requested_by': requestedBy,
            'warehouse_id': null, // لا نحدد مخزن محدد
            'is_global_request': true,
            'processing_metadata': {
              'allocation_strategy': allocationStrategy,
              'created_as_global': true,
              'items_count': items.length,
            },
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final requestId = requestResponse['id'];

      // إضافة عناصر الطلب
      final itemsData = items.map((item) => {
        'request_id': requestId,
        'product_id': item.productId,
        'quantity': item.quantity,
        'notes': item.notes,
      }).toList();

      await _supabase
          .from('warehouse_request_items')
          .insert(itemsData);

      AppLogger.info('✅ تم إنشاء طلب السحب العالمي: $requestId');

      // إرجاع الطلب المنشأ
      return await getGlobalWithdrawalRequest(requestId);
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء طلب السحب العالمي: $e');
      throw Exception('فشل في إنشاء طلب السحب العالمي: $e');
    }
  }

  /// الحصول على طلب سحب عالمي مع تفاصيله
  Future<GlobalWithdrawalRequest> getGlobalWithdrawalRequest(String requestId) async {
    try {
      // الحصول على الطلب الأساسي
      final requestResponse = await _supabase
          .from('warehouse_requests')
          .select('''
            *,
            requester:user_profiles!requested_by (
              name
            )
          ''')
          .eq('id', requestId)
          .single();

      // الحصول على عناصر الطلب
      final itemsResponse = await _supabase
          .from('warehouse_request_items')
          .select('''
            *,
            product:products (
              name,
              sku
            )
          ''')
          .eq('request_id', requestId);

      final items = itemsResponse.map<WithdrawalRequestItem>((item) {
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

      final requesterData = requestResponse['requester'] as Map<String, dynamic>?;

      return GlobalWithdrawalRequest.fromJson({
        ...requestResponse,
        'requester_name': requesterData?['name'],
      }).copyWith(items: items);
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على طلب السحب العالمي: $e');
      throw Exception('فشل في الحصول على طلب السحب العالمي: $e');
    }
  }

  /// معالجة طلب سحب عالمي تلقائياً
  Future<EnhancedWithdrawalProcessingResult> processGlobalWithdrawalRequest({
    required String requestId,
    String allocationStrategy = 'balanced',
    String? performedBy,
  }) async {
    try {
      AppLogger.info('🔄 بدء معالجة طلب السحب العالمي: $requestId');

      // استدعاء دالة قاعدة البيانات للمعالجة
      final result = await _supabase.rpc(
        'process_global_withdrawal_request',
        params: {
          'p_request_id': requestId,
          'p_allocation_strategy': allocationStrategy,
          'p_performed_by': performedBy,
        },
      );

      if (result == null) {
        throw Exception('لم يتم إرجاع نتيجة من دالة المعالجة');
      }

      // الحصول على تفاصيل التخصيصات
      final allocations = await getRequestAllocations(requestId);

      final processingResult = EnhancedWithdrawalProcessingResult(
        requestId: requestId,
        success: result['success'] ?? false,
        isGlobalRequest: result['is_global_request'] ?? true,
        allocationStrategy: result['allocation_strategy'] ?? allocationStrategy,
        itemsProcessed: result['items_processed'] ?? 0,
        itemsSuccessful: result['items_successful'] ?? 0,
        totalRequested: result['total_requested'] ?? 0,
        totalProcessed: result['total_processed'] ?? 0,
        allocationsCreated: result['allocations_created'] ?? 0,
        deductionsSuccessful: result['deductions_successful'] ?? 0,
        warehousesInvolved: List<String>.from(result['warehouses_involved'] ?? []),
        errors: List<String>.from(result['errors'] ?? []),
        allocations: allocations,
        processingTime: DateTime.now(),
        performedBy: performedBy ?? 'system',
      );

      AppLogger.info('✅ نتائج معالجة الطلب العالمي: ${processingResult.summaryText}');
      return processingResult;
    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة طلب السحب العالمي: $e');
      throw Exception('فشل في معالجة طلب السحب العالمي: $e');
    }
  }

  /// الحصول على تخصيصات المخازن لطلب معين
  Future<List<WarehouseRequestAllocation>> getRequestAllocations(String requestId) async {
    try {
      final response = await _supabase.rpc(
        'get_request_allocation_details',
        params: {'p_request_id': requestId},
      );

      return response.map<WarehouseRequestAllocation>((item) {
        return WarehouseRequestAllocation.fromJson({
          'id': item['allocation_id'],
          'request_id': requestId,
          'warehouse_id': item['warehouse_id'],
          'warehouse_name': item['warehouse_name'],
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'allocated_quantity': item['allocated_quantity'],
          'deducted_quantity': item['deducted_quantity'],
          'allocation_strategy': item['allocation_strategy'],
          'allocation_priority': item['allocation_priority'],
          'allocation_reason': item['allocation_reason'],
          'status': item['status'],
          'created_at': item['created_at'],
          'processed_at': item['processed_at'],
        });
      }).toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على تخصيصات الطلب: $e');
      return [];
    }
  }

  /// معالجة جميع طلبات السحب المكتملة تلقائياً
  Future<List<EnhancedWithdrawalProcessingResult>> processAllCompletedRequests({
    String allocationStrategy = 'balanced',
    int? limit,
  }) async {
    try {
      AppLogger.info('🔄 معالجة جميع طلبات السحب المكتملة');

      // البحث عن طلبات السحب المكتملة غير المعالجة
      var query = _supabase
          .from('warehouse_requests')
          .select('id, created_at, is_global_request')
          .eq('type', 'withdrawal')
          .eq('status', 'completed')
          .is_('processing_metadata->processing_completed_at', null)
          .order('created_at', ascending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final requests = await query;

      if (requests.isEmpty) {
        AppLogger.info('ℹ️ لا توجد طلبات سحب مكتملة تحتاج معالجة');
        return [];
      }

      AppLogger.info('📋 تم العثور على ${requests.length} طلب للمعالجة');

      final results = <EnhancedWithdrawalProcessingResult>[];

      for (final request in requests) {
        try {
          final result = await processGlobalWithdrawalRequest(
            requestId: request['id'],
            allocationStrategy: allocationStrategy,
            performedBy: 'system_auto_processor',
          );
          results.add(result);
        } catch (e) {
          AppLogger.error('❌ فشل في معالجة الطلب ${request['id']}: $e');
        }
      }

      AppLogger.info('✅ تم معالجة ${results.length} طلب تلقائياً');
      return results;
    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة الطلبات المكتملة: $e');
      return [];
    }
  }

  /// تحويل طلب سحب تقليدي إلى عالمي
  Future<GlobalWithdrawalRequest> convertToGlobalRequest(String requestId) async {
    try {
      AppLogger.info('🔄 تحويل طلب سحب تقليدي إلى عالمي: $requestId');

      // تحديث الطلب ليصبح عالمي
      await _supabase
          .from('warehouse_requests')
          .update({
            'warehouse_id': null,
            'is_global_request': true,
            'processing_metadata': {
              'converted_to_global': true,
              'converted_at': DateTime.now().toIso8601String(),
              'allocation_strategy': 'balanced',
            },
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      AppLogger.info('✅ تم تحويل الطلب إلى عالمي');
      return await getGlobalWithdrawalRequest(requestId);
    } catch (e) {
      AppLogger.error('❌ خطأ في تحويل الطلب إلى عالمي: $e');
      throw Exception('فشل في تحويل الطلب إلى عالمي: $e');
    }
  }

  /// الحصول على قائمة طلبات السحب العالمية
  Future<List<GlobalWithdrawalRequest>> getGlobalWithdrawalRequests({
    String? status,
    int? limit,
    int? offset,
  }) async {
    try {
      var query = _supabase
          .from('warehouse_requests')
          .select('''
            *,
            requester:user_profiles!requested_by (
              name
            )
          ''')
          .eq('type', 'withdrawal')
          .eq('is_global_request', true)
          .order('created_at', ascending: false);

      if (status != null) {
        query = query.eq('status', status);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 50) - 1);
      }

      final response = await query;

      final requests = <GlobalWithdrawalRequest>[];
      for (final item in response) {
        try {
          final requesterData = item['requester'] as Map<String, dynamic>?;
          final request = GlobalWithdrawalRequest.fromJson({
            ...item,
            'requester_name': requesterData?['name'],
          });
          requests.add(request);
        } catch (e) {
          AppLogger.error('❌ خطأ في تحليل طلب السحب: $e');
        }
      }

      return requests;
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على طلبات السحب العالمية: $e');
      throw Exception('فشل في الحصول على طلبات السحب العالمية: $e');
    }
  }

  /// إحصائيات أداء المعالجة العالمية
  Future<GlobalProcessingPerformance> getProcessingPerformance({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final response = await _supabase
          .from('warehouse_requests')
          .select('processing_metadata, created_at')
          .eq('type', 'withdrawal')
          .eq('is_global_request', true)
          .filter('created_at', 'gte', start.toIso8601String())
          .filter('created_at', 'lte', end.toIso8601String());

      var totalRequests = 0;
      var successfulRequests = 0;
      var failedRequests = 0;
      var totalProcessingTime = 0.0;
      var totalWarehouses = 0;
      var totalEfficiency = 0.0;

      for (final item in response) {
        final metadata = item['processing_metadata'] as Map<String, dynamic>?;
        if (metadata?['processing_completed_at'] != null) {
          totalRequests++;
          
          if (metadata?['processing_success'] == true) {
            successfulRequests++;
          } else {
            failedRequests++;
          }

          // حساب وقت المعالجة (تقديري)
          totalProcessingTime += 2.5; // متوسط تقديري

          // عدد المخازن المستخدمة
          final warehouses = metadata?['warehouses_involved'] as List?;
          if (warehouses != null) {
            totalWarehouses += warehouses.length;
          }

          // كفاءة التخصيص
          final totalRequested = metadata?['total_requested'] ?? 0;
          final totalProcessed = metadata?['total_processed'] ?? 0;
          if (totalRequested > 0) {
            totalEfficiency += (totalProcessed / totalRequested * 100);
          }
        }
      }

      return GlobalProcessingPerformance(
        totalRequestsProcessed: totalRequests,
        successfulRequests: successfulRequests,
        failedRequests: failedRequests,
        averageProcessingTime: totalRequests > 0 ? totalProcessingTime / totalRequests : 0,
        averageWarehousesPerRequest: totalRequests > 0 ? totalWarehouses / totalRequests : 0,
        averageAllocationEfficiency: totalRequests > 0 ? totalEfficiency / totalRequests : 0,
        periodStart: start,
        periodEnd: end,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على إحصائيات الأداء: $e');
      throw Exception('فشل في الحصول على إحصائيات الأداء: $e');
    }
  }

  /// إلغاء تخصيص مخزن من طلب
  Future<bool> cancelAllocation(String allocationId) async {
    try {
      await _supabase
          .from('warehouse_request_allocations')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', allocationId);

      AppLogger.info('✅ تم إلغاء التخصيص: $allocationId');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في إلغاء التخصيص: $e');
      return false;
    }
  }
}

/// امتداد لإضافة وظائف مساعدة
extension GlobalWithdrawalRequestExtension on GlobalWithdrawalRequest {
  GlobalWithdrawalRequest copyWith({
    String? id,
    String? type,
    String? status,
    String? reason,
    String? requestedBy,
    String? requesterName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isGlobalRequest,
    Map<String, dynamic>? processingMetadata,
    List<WithdrawalRequestItem>? items,
  }) {
    return GlobalWithdrawalRequest(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      requestedBy: requestedBy ?? this.requestedBy,
      requesterName: requesterName ?? this.requesterName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isGlobalRequest: isGlobalRequest ?? this.isGlobalRequest,
      processingMetadata: processingMetadata ?? this.processingMetadata,
      items: items ?? this.items,
    );
  }
}
