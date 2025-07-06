import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/warehouse_inventory_model.dart';
import '../models/warehouse_model.dart';
import '../models/product_model.dart';
import '../models/global_inventory_models.dart';
import '../services/auth_state_manager.dart';
import '../services/transaction_isolation_service.dart';
import '../utils/app_logger.dart';

/// خدمة البحث العالمي في المخزون والخصم التلقائي
class GlobalInventoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==================== Type Validation Helpers ====================

  /// التحقق من صحة معرف المخزن (UUID)
  bool _isValidWarehouseId(String warehouseId) {
    if (warehouseId.isEmpty) return false;
    try {
      final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      return uuid.hasMatch(warehouseId);
    } catch (e) {
      return false;
    }
  }

  /// التحقق من صحة معرف المنتج (TEXT)
  bool _isValidProductId(String productId) {
    return productId.isNotEmpty && productId.trim().isNotEmpty;
  }

  /// التحقق من صحة معرف المستخدم (UUID)
  bool _isValidUserId(String userId) {
    if (userId.isEmpty) return false;
    try {
      final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      return uuid.hasMatch(userId);
    } catch (e) {
      return false;
    }
  }

  /// تحويل معرف المخزن إلى UUID آمن للاستعلامات
  String _ensureWarehouseIdFormat(String warehouseId) {
    if (!_isValidWarehouseId(warehouseId)) {
      throw Exception('معرف المخزن غير صحيح: $warehouseId. يجب أن يكون UUID صحيح.');
    }
    return warehouseId.toLowerCase();
  }

  /// تحويل معرف المنتج إلى TEXT آمن للاستعلامات
  String _ensureProductIdFormat(String productId) {
    if (!_isValidProductId(productId)) {
      throw Exception('معرف المنتج غير صحيح: $productId. لا يمكن أن يكون فارغاً.');
    }
    return productId.trim();
  }

  /// تحويل معرف المستخدم إلى UUID آمن للاستعلامات
  String _ensureUserIdFormat(String userId) {
    if (!_isValidUserId(userId)) {
      throw Exception('معرف المستخدم غير صحيح: $userId. يجب أن يكون UUID صحيح.');
    }
    return userId.toLowerCase();
  }

  /// البحث العالمي عن منتج في جميع المخازن
  Future<GlobalInventorySearchResult> searchProductGlobally({
    required String productId,
    required int requestedQuantity,
    List<String>? excludeWarehouses,
    WarehouseSelectionStrategy strategy = WarehouseSelectionStrategy.priorityBased,
  }) async {
    // CRITICAL FIX: Preserve authentication state before starting global search
    User? authenticatedUser;
    try {
      authenticatedUser = await AuthStateManager.getCurrentUser(forceRefresh: false);
      if (authenticatedUser == null) {
        AppLogger.error('❌ لا يوجد مستخدم مصادق عليه للبحث العالمي');
        throw Exception('المستخدم غير مصادق عليه - يرجى تسجيل الدخول مرة أخرى');
      }
      AppLogger.info('✅ تم التحقق من المصادقة للبحث العالمي: ${authenticatedUser.id}');
    } catch (authError) {
      AppLogger.error('❌ خطأ في التحقق من المصادقة للبحث العالمي: $authError');
      throw Exception('فشل في التحقق من المصادقة: $authError');
    }

    try {
      AppLogger.info('🔍 البحث العالمي عن المنتج: $productId، الكمية المطلوبة: $requestedQuantity');

      // التحقق من صحة معرف المنتج وتنسيقه
      final validProductId = _ensureProductIdFormat(productId);
      AppLogger.info('🔍 معرف المنتج المُنسق: $validProductId');

      // التحقق من صحة معرفات المخازن المستبعدة وتنسيقها
      List<String>? validExcludeWarehouses;
      if (excludeWarehouses != null && excludeWarehouses.isNotEmpty) {
        validExcludeWarehouses = excludeWarehouses
            .where((id) => _isValidWarehouseId(id))
            .map((id) => _ensureWarehouseIdFormat(id))
            .toList();
        AppLogger.info('🔍 المخازن المستبعدة المُنسقة: $validExcludeWarehouses');
      }

      AppLogger.info('🔍 بدء البحث العالمي عن المنتج: $validProductId');
      AppLogger.info('📊 الكمية المطلوبة: $requestedQuantity');
      AppLogger.info('🏪 المخازن المستبعدة: ${validExcludeWarehouses?.join(', ') ?? 'لا يوجد'}');
      AppLogger.info('📋 الاستراتيجية: ${strategy.toString()}');
      AppLogger.info('👤 المستخدم المصادق: ${authenticatedUser.id}');

      // CRITICAL FIX: Verify Supabase client auth context before database query
      final currentUser = _supabase.auth.currentUser;
      final currentSession = _supabase.auth.currentSession;
      AppLogger.info('🔒 حالة المصادقة في العميل:');
      AppLogger.info('   المستخدم الحالي: ${currentUser?.id ?? 'null'}');
      AppLogger.info('   الجلسة النشطة: ${currentSession != null ? 'موجودة' : 'غير موجودة'}');

      if (currentUser == null || currentUser.id != authenticatedUser.id) {
        AppLogger.error('❌ حالة المصادقة غير متطابقة في العميل قبل البحث العالمي');
        AppLogger.error('   متوقع: ${authenticatedUser.id}');
        AppLogger.error('   فعلي: ${currentUser?.id ?? 'null'}');
        throw Exception('حالة المصادقة غير صحيحة للبحث العالمي');
      }

      // CRITICAL FIX: Use transaction isolation for database query to prevent auth corruption
      // SCHEMA FIX: Handle product_id as TEXT and use LEFT JOIN for products to avoid empty results
      final response = await TransactionIsolationService.executeIsolatedReadTransaction<List<dynamic>>(
        queryName: 'global_inventory_search_${validProductId}',
        query: (client) => client
            .from('warehouse_inventory')
            .select('''
              id,
              warehouse_id,
              product_id,
              quantity,
              minimum_stock,
              maximum_stock,
              last_updated,
              warehouse:warehouses!inner (
                id,
                name,
                address,
                is_active,
                created_at
              ),
              product:products (
                id,
                name,
                category,
                price,
                sku
              )
            ''')
            .eq('product_id', validProductId)
            .eq('warehouse.is_active', true)
            .gt('quantity', 0),
        fallbackValue: () => <dynamic>[],
        preserveAuthState: true,
      );

      if (response.isEmpty) {
        AppLogger.warning('⚠️ لم يتم العثور على المنتج $validProductId في أي مخزن نشط');

        // DIAGNOSTIC: Try alternative query to check if product exists at all
        try {
          final diagnosticResponse = await TransactionIsolationService.executeIsolatedReadTransaction<List<dynamic>>(
            queryName: 'diagnostic_inventory_check_${validProductId}',
            query: (client) => client
                .from('warehouse_inventory')
                .select('id, warehouse_id, product_id, quantity')
                .eq('product_id', validProductId),
            fallbackValue: () => <dynamic>[],
            preserveAuthState: true,
          );

          AppLogger.info('🔍 تشخيص: وجد ${diagnosticResponse.length} سجل للمنتج $validProductId (بما في ذلك المخازن غير النشطة)');

          if (diagnosticResponse.isNotEmpty) {
            for (final record in diagnosticResponse) {
              AppLogger.info('📦 سجل مخزون: المخزن ${record['warehouse_id']}, الكمية: ${record['quantity']}');
            }
          }
        } catch (diagnosticError) {
          AppLogger.error('❌ خطأ في التشخيص: $diagnosticError');
        }

        return GlobalInventorySearchResult(
          productId: productId,
          requestedQuantity: requestedQuantity,
          totalAvailableQuantity: 0,
          canFulfill: false,
          availableWarehouses: [],
          allocationPlan: [],
          searchStrategy: strategy,
          searchTimestamp: DateTime.now(),
          error: 'المنتج غير متوفر في أي مخزن نشط',
        );
      }

      // تحويل النتائج إلى كائنات
      final availableWarehouses = response.map((item) {
        final warehouseData = item['warehouse'] as Map<String, dynamic>?;
        final productData = item['product'] as Map<String, dynamic>?;

        // SCHEMA FIX: Handle cases where product data might be null due to LEFT JOIN
        final productName = productData?['name']?.toString() ?? 'منتج غير معروف';
        final productSku = productData?['sku']?.toString() ?? '';

        AppLogger.info('📦 معالجة مخزون: المخزن ${warehouseData?['name']}, المنتج: $productName, الكمية: ${item['quantity']}');

        return WarehouseInventoryAvailability(
          warehouseId: item['warehouse_id']?.toString() ?? '',
          warehouseName: warehouseData?['name']?.toString() ?? '',
          warehouseAddress: warehouseData?['address']?.toString() ?? '',
          warehousePriority: 0, // Default priority since column doesn't exist
          productId: productId,
          availableQuantity: _parseInt(item['quantity']) ?? 0,
          minimumStock: _parseInt(item['minimum_stock']) ?? 0,
          maximumStock: _parseInt(item['maximum_stock']) ?? 0,
          productName: productName,
          productSku: productSku,
          lastUpdated: _parseDateTime(item['last_updated']) ?? DateTime.now(),
        );
      }).where((warehouse) {
        // استبعاد المخازن المحددة (مع مقارنة آمنة للـ UUID)
        if (validExcludeWarehouses?.contains(warehouse.warehouseId.toLowerCase()) == true) {
          return false;
        }
        return true;
      }).toList();

      // حساب إجمالي الكمية المتاحة
      final totalAvailable = availableWarehouses.fold<int>(
        0, 
        (sum, warehouse) => sum + warehouse.availableQuantity,
      );

      // تحديد إمكانية تلبية الطلب
      final canFulfill = totalAvailable >= requestedQuantity;

      // إنشاء خطة التخصيص
      final allocationPlan = canFulfill 
          ? _createAllocationPlan(availableWarehouses, requestedQuantity, strategy)
          : <InventoryAllocation>[];

      // CRITICAL FIX: Verify authentication state after database operations
      try {
        final postQueryUser = _supabase.auth.currentUser;
        if (postQueryUser == null || postQueryUser.id != authenticatedUser.id) {
          AppLogger.warning('⚠️ تأثرت حالة المصادقة بعد البحث العالمي');
          await AuthStateManager.getCurrentUser(forceRefresh: true);
        }
      } catch (authCheckError) {
        AppLogger.warning('⚠️ خطأ في التحقق من المصادقة بعد البحث: $authCheckError');
      }

      AppLogger.info('✅ نتائج البحث العالمي:');
      AppLogger.info('   إجمالي المتاح: $totalAvailable');
      AppLogger.info('   يمكن التلبية: ${canFulfill ? "نعم" : "لا"}');
      AppLogger.info('   عدد المخازن المتاحة: ${availableWarehouses.length}');
      AppLogger.info('   خطة التخصيص: ${allocationPlan.length} مخزن');

      return GlobalInventorySearchResult(
        productId: productId,
        requestedQuantity: requestedQuantity,
        totalAvailableQuantity: totalAvailable,
        canFulfill: canFulfill,
        availableWarehouses: availableWarehouses,
        allocationPlan: allocationPlan,
        searchStrategy: strategy,
        searchTimestamp: DateTime.now(),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث العالمي: $e');

      // CRITICAL FIX: Attempt authentication recovery after search failure
      try {
        AppLogger.info('🔄 محاولة استعادة المصادقة بعد فشل البحث العالمي...');
        final recoveredUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
        if (recoveredUser != null) {
          AppLogger.info('✅ تم استعادة المصادقة بنجاح بعد فشل البحث: ${recoveredUser.id}');
        } else {
          AppLogger.warning('⚠️ فشل في استعادة المصادقة بعد فشل البحث');
        }
      } catch (recoveryError) {
        AppLogger.error('❌ خطأ في استعادة المصادقة بعد فشل البحث: $recoveryError');
      }

      throw Exception('فشل في البحث العالمي عن المنتج: $e');
    }
  }

  /// إنشاء خطة تخصيص المخزون
  List<InventoryAllocation> _createAllocationPlan(
    List<WarehouseInventoryAvailability> warehouses,
    int requestedQuantity,
    WarehouseSelectionStrategy strategy,
  ) {
    final allocations = <InventoryAllocation>[];
    var remainingQuantity = requestedQuantity;

    // ترتيب المخازن حسب الاستراتيجية
    final sortedWarehouses = _sortWarehousesByStrategy(warehouses, strategy);

    for (final warehouse in sortedWarehouses) {
      if (remainingQuantity <= 0) break;

      // حساب الكمية القابلة للتخصيص من هذا المخزن
      final allocatableQuantity = _calculateAllocatableQuantity(
        warehouse,
        remainingQuantity,
      );

      if (allocatableQuantity > 0) {
        allocations.add(InventoryAllocation(
          warehouseId: warehouse.warehouseId,
          warehouseName: warehouse.warehouseName,
          productId: warehouse.productId,
          allocatedQuantity: allocatableQuantity,
          availableQuantity: warehouse.availableQuantity,
          minimumStock: warehouse.minimumStock,
          allocationReason: _getAllocationReason(strategy, warehouse),
          allocationPriority: allocations.length + 1,
          estimatedDeductionTime: DateTime.now().add(const Duration(minutes: 5)),
        ));

        remainingQuantity -= allocatableQuantity;
        AppLogger.info('📦 تخصيص ${allocatableQuantity} من المخزن: ${warehouse.warehouseName}');
      }
    }

    return allocations;
  }

  /// ترتيب المخازن حسب الاستراتيجية
  List<WarehouseInventoryAvailability> _sortWarehousesByStrategy(
    List<WarehouseInventoryAvailability> warehouses,
    WarehouseSelectionStrategy strategy,
  ) {
    switch (strategy) {
      case WarehouseSelectionStrategy.priorityBased:
        // Since priority column doesn't exist, fall back to balanced strategy
        AppLogger.info('⚠️ Priority column not available, using balanced strategy instead');
        return _sortWarehousesByStrategy(warehouses, WarehouseSelectionStrategy.balanced);
      
      case WarehouseSelectionStrategy.highestStock:
        return warehouses..sort((a, b) => b.availableQuantity.compareTo(a.availableQuantity));
      
      case WarehouseSelectionStrategy.lowestStock:
        return warehouses..sort((a, b) => a.availableQuantity.compareTo(b.availableQuantity));
      
      case WarehouseSelectionStrategy.fifo:
        return warehouses..sort((a, b) => a.lastUpdated.compareTo(b.lastUpdated));
      
      case WarehouseSelectionStrategy.balanced:
        // توزيع متوازن - أولوية للمخازن التي لديها مخزون أعلى من الحد الأدنى
        return warehouses..sort((a, b) {
          final aExcess = a.availableQuantity - a.minimumStock;
          final bExcess = b.availableQuantity - b.minimumStock;
          return bExcess.compareTo(aExcess);
        });
    }
  }

  /// حساب الكمية القابلة للتخصيص من مخزن معين
  int _calculateAllocatableQuantity(
    WarehouseInventoryAvailability warehouse,
    int requestedQuantity,
  ) {
    // الحد الأقصى المتاح للتخصيص (مع الحفاظ على الحد الأدنى)
    final maxAllocatable = (warehouse.availableQuantity - warehouse.minimumStock).clamp(0, warehouse.availableQuantity);
    
    // الكمية الفعلية للتخصيص
    return requestedQuantity.clamp(0, maxAllocatable);
  }

  /// الحصول على سبب التخصيص
  String _getAllocationReason(
    WarehouseSelectionStrategy strategy,
    WarehouseInventoryAvailability warehouse,
  ) {
    switch (strategy) {
      case WarehouseSelectionStrategy.priorityBased:
        return 'توزيع متوازن (بديل للأولوية)';
      case WarehouseSelectionStrategy.highestStock:
        return 'أعلى مخزون (${warehouse.availableQuantity})';
      case WarehouseSelectionStrategy.lowestStock:
        return 'أقل مخزون (${warehouse.availableQuantity})';
      case WarehouseSelectionStrategy.fifo:
        return 'الأقدم أولاً';
      case WarehouseSelectionStrategy.balanced:
        return 'توزيع متوازن';
    }
  }

  /// تنفيذ خطة التخصيص والخصم التلقائي
  Future<InventoryDeductionResult> executeAllocationPlan({
    required List<InventoryAllocation> allocationPlan,
    required String requestId,
    required String performedBy,
    String? reason,
  }) async {
    try {
      AppLogger.info('🔄 تنفيذ خطة التخصيص للطلب: $requestId');

      final deductionResults = <WarehouseDeductionResult>[];
      var totalDeducted = 0;
      final errors = <String>[];

      for (final allocation in allocationPlan) {
        try {
          final result = await _deductFromWarehouse(
            allocation: allocation,
            requestId: requestId,
            performedBy: performedBy,
            reason: reason ?? 'خصم تلقائي للطلب $requestId',
          );

          deductionResults.add(result);
          totalDeducted += result.deductedQuantity;

          AppLogger.info('✅ تم الخصم من ${allocation.warehouseName}: ${result.deductedQuantity}');
        } catch (e) {
          // FIXED: Better error categorization and handling
          final errorString = e.toString().toLowerCase();
          String errorCategory = 'تحذير';
          String errorMessage = 'فشل في الخصم من ${allocation.warehouseName}: $e';

          // Categorize errors by severity
          if (errorString.contains('connection') || errorString.contains('network')) {
            errorCategory = 'خطأ حرج';
            errorMessage = 'خطأ في الاتصال بقاعدة البيانات - ${allocation.warehouseName}: $e';
          } else if (errorString.contains('auth') || errorString.contains('المصادقة')) {
            errorCategory = 'خطأ حرج';
            errorMessage = 'خطأ في المصادقة - ${allocation.warehouseName}: $e';
          } else if (errorString.contains('permission') || errorString.contains('الصلاحيات')) {
            errorCategory = 'خطأ حرج';
            errorMessage = 'خطأ في الصلاحيات - ${allocation.warehouseName}: $e';
          } else if (errorString.contains('insufficient') || errorString.contains('غير كافي')) {
            errorCategory = 'تحذير';
            errorMessage = 'كمية غير كافية في ${allocation.warehouseName}: $e';
          } else if (errorString.contains('not found') || errorString.contains('غير موجود')) {
            errorCategory = 'تحذير';
            errorMessage = 'منتج غير موجود في ${allocation.warehouseName}: $e';
          }

          errors.add(errorMessage);
          AppLogger.error('❌ [$errorCategory] $errorMessage');

          // Add a failed deduction result for tracking
          deductionResults.add(WarehouseDeductionResult(
            warehouseId: allocation.warehouseId,
            warehouseName: allocation.warehouseName,
            productId: allocation.productId,
            requestedQuantity: allocation.allocatedQuantity,
            deductedQuantity: 0,
            remainingQuantity: allocation.allocatedQuantity,
            success: false,
            error: errorMessage,
            deductionTime: DateTime.now(),
          ));
        }
      }

      final totalRequested = allocationPlan.fold<int>(0, (sum, a) => sum + a.allocatedQuantity);

      // FIXED: Improved success determination logic
      // Success should be based on whether we deducted the required quantity, not just absence of errors
      // Some errors might be warnings or non-critical issues that don't affect the actual deduction
      final hasSuccessfulDeductions = deductionResults.any((r) => r.success && r.deductedQuantity > 0);
      final meetsQuantityRequirement = totalDeducted >= totalRequested;
      final hasCriticalErrors = errors.any((error) =>
        error.contains('فشل في الخصم') ||
        error.contains('خطأ في قاعدة البيانات') ||
        error.contains('المصادقة') ||
        error.contains('الصلاحيات') ||
        error.contains('connection') ||
        error.contains('network')
      );

      // Success if we have successful deductions, meet quantity requirements, and no critical errors
      final success = hasSuccessfulDeductions && meetsQuantityRequirement && !hasCriticalErrors;

      AppLogger.info('📊 نتائج تنفيذ التخصيص:');
      AppLogger.info('   إجمالي المطلوب: $totalRequested');
      AppLogger.info('   إجمالي المخصوم: $totalDeducted');
      AppLogger.info('   خصومات ناجحة: $hasSuccessfulDeductions');
      AppLogger.info('   يلبي متطلبات الكمية: $meetsQuantityRequirement');
      AppLogger.info('   أخطاء حرجة: $hasCriticalErrors');
      AppLogger.info('   النجاح: ${success ? "نعم" : "لا"}');
      AppLogger.info('   إجمالي الأخطاء: ${errors.length}');

      // Log detailed error analysis
      if (errors.isNotEmpty) {
        AppLogger.info('🔍 تحليل الأخطاء:');
        for (int i = 0; i < errors.length; i++) {
          final error = errors[i];
          final isCritical = error.contains('فشل في الخصم') ||
                           error.contains('خطأ في قاعدة البيانات') ||
                           error.contains('المصادقة') ||
                           error.contains('الصلاحيات') ||
                           error.contains('connection') ||
                           error.contains('network');
          AppLogger.info('   ${i + 1}. ${isCritical ? "🔴 حرج" : "🟡 تحذير"}: $error');
        }
      }

      return InventoryDeductionResult(
        requestId: requestId,
        totalRequestedQuantity: totalRequested,
        totalDeductedQuantity: totalDeducted,
        success: success,
        warehouseResults: deductionResults,
        errors: errors,
        executionTime: DateTime.now(),
        performedBy: performedBy,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في تنفيذ خطة التخصيص: $e');
      throw Exception('فشل في تنفيذ خطة التخصيص: $e');
    }
  }

  /// خصم الكمية من مخزن محدد
  Future<WarehouseDeductionResult> _deductFromWarehouse({
    required InventoryAllocation allocation,
    required String requestId,
    required String performedBy,
    required String reason,
  }) async {
    try {
      AppLogger.info('🔄 بدء خصم المخزون من المخزن: ${allocation.warehouseName}');
      AppLogger.info('   معرف المخزن: ${allocation.warehouseId}');
      AppLogger.info('   معرف المنتج: ${allocation.productId}');
      AppLogger.info('   الكمية: ${allocation.allocatedQuantity}');
      AppLogger.info('   المنفذ: $performedBy');

      // التحقق من صحة المعرفات وتنسيقها
      final validWarehouseId = _ensureWarehouseIdFormat(allocation.warehouseId);
      final validProductId = _ensureProductIdFormat(allocation.productId);
      final validPerformedBy = _ensureUserIdFormat(performedBy);

      AppLogger.info('🔍 معرفات مُنسقة - المخزن: $validWarehouseId، المنتج: $validProductId، المنفذ: $validPerformedBy');

      // تحديث المخزون في قاعدة البيانات مع إصلاح جميع أخطاء الأعمدة والقيود (النسخة النهائية)
      final response = await _supabase.rpc(
        'deduct_inventory_with_validation_v5',
        params: {
          'p_warehouse_id': validWarehouseId,
          'p_product_id': validProductId,
          'p_quantity': allocation.allocatedQuantity,
          'p_performed_by': validPerformedBy,
          'p_reason': reason,
          'p_reference_id': requestId,
          'p_reference_type': 'withdrawal_request',
        },
      );

      AppLogger.info('📤 استجابة قاعدة البيانات: $response');

      if (response == null) {
        throw Exception('لم يتم الحصول على استجابة من قاعدة البيانات');
      }

      if (response['success'] != true) {
        final error = response['error'] ?? 'فشل في تحديث المخزون';
        AppLogger.error('❌ خطأ من قاعدة البيانات: $error');
        throw Exception(error);
      }

      AppLogger.info('✅ تم الخصم بنجاح من المخزن: ${allocation.warehouseName}');
      AppLogger.info('   الكمية المخصومة: ${allocation.allocatedQuantity}');
      AppLogger.info('   الكمية المتبقية: ${response['remaining_quantity'] ?? 0}');
      AppLogger.info('   معرف المعاملة: ${response['transaction_id']}');

      return WarehouseDeductionResult(
        warehouseId: allocation.warehouseId,
        warehouseName: allocation.warehouseName,
        productId: allocation.productId,
        requestedQuantity: allocation.allocatedQuantity,
        deductedQuantity: allocation.allocatedQuantity,
        remainingQuantity: response['remaining_quantity'] ?? 0,
        success: true,
        transactionId: response['transaction_id'],
        deductionTime: DateTime.now(),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في خصم المخزون من ${allocation.warehouseName}: $e');

      return WarehouseDeductionResult(
        warehouseId: allocation.warehouseId,
        warehouseName: allocation.warehouseName,
        productId: allocation.productId,
        requestedQuantity: allocation.allocatedQuantity,
        deductedQuantity: 0,
        remainingQuantity: allocation.availableQuantity,
        success: false,
        error: e.toString(),
        deductionTime: DateTime.now(),
      );
    }
  }

  /// البحث عن منتجات متعددة عالمياً
  Future<Map<String, GlobalInventorySearchResult>> searchMultipleProductsGlobally({
    required Map<String, int> productQuantities, // productId -> quantity
    WarehouseSelectionStrategy strategy = WarehouseSelectionStrategy.balanced,
  }) async {
    final results = <String, GlobalInventorySearchResult>{};

    for (final entry in productQuantities.entries) {
      try {
        final result = await searchProductGlobally(
          productId: entry.key,
          requestedQuantity: entry.value,
          strategy: strategy,
        );
        results[entry.key] = result;
      } catch (e) {
        AppLogger.error('❌ خطأ في البحث عن المنتج ${entry.key}: $e');
        // إنشاء نتيجة فاشلة
        results[entry.key] = GlobalInventorySearchResult(
          productId: entry.key,
          requestedQuantity: entry.value,
          totalAvailableQuantity: 0,
          canFulfill: false,
          availableWarehouses: [],
          allocationPlan: [],
          searchStrategy: strategy,
          searchTimestamp: DateTime.now(),
          error: e.toString(),
        );
      }
    }

    return results;
  }

  /// الحصول على ملخص المخزون العالمي لمنتج
  Future<ProductGlobalInventorySummary> getProductGlobalSummary(String productId) async {
    try {
      final searchResult = await searchProductGlobally(
        productId: productId,
        requestedQuantity: 1, // كمية رمزية للبحث
      );

      final totalWarehouses = searchResult.availableWarehouses.length;
      final warehousesWithStock = searchResult.availableWarehouses.where((w) => w.availableQuantity > 0).length;
      final warehousesLowStock = searchResult.availableWarehouses.where((w) => 
        w.availableQuantity <= w.minimumStock && w.availableQuantity > 0
      ).length;

      return ProductGlobalInventorySummary(
        productId: productId,
        totalAvailableQuantity: searchResult.totalAvailableQuantity,
        totalWarehouses: totalWarehouses,
        warehousesWithStock: warehousesWithStock,
        warehousesLowStock: warehousesLowStock,
        warehousesOutOfStock: totalWarehouses - warehousesWithStock,
        lastUpdated: DateTime.now(),
        warehouseBreakdown: searchResult.availableWarehouses,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على ملخص المخزون العالمي: $e');
      throw Exception('فشل في الحصول على ملخص المخزون العالمي: $e');
    }
  }

  /// تحويل القيمة إلى عدد صحيح
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  /// تحويل القيمة إلى تاريخ
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
