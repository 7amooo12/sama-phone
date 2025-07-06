/// خدمة الخصم الذكي للمخزون في طلبات الصرف
/// Service for intelligent inventory deduction in dispatch requests

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/dispatch_product_processing_model.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/services/auth_state_manager.dart';
import 'package:smartbiztracker_new/services/operation_isolation_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class IntelligentInventoryDeductionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalInventoryService _globalInventoryService = GlobalInventoryService();

  /// خصم ذكي للمنتج عند إكمال المعالجة
  Future<InventoryDeductionResult> deductProductInventory({
    required DispatchProductProcessingModel product,
    required String performedBy,
    required String requestId,
    WarehouseSelectionStrategy strategy = WarehouseSelectionStrategy.highestStock,
  }) async {
    // CRITICAL FIX: Preserve authentication state before starting operations
    User? authenticatedUser;
    try {
      // Ensure we have a valid authenticated user before starting
      authenticatedUser = await AuthStateManager.getCurrentUser(forceRefresh: false);
      if (authenticatedUser == null) {
        AppLogger.error('❌ لا يوجد مستخدم مصادق عليه لتنفيذ عملية الخصم');
        throw Exception('المستخدم غير مصادق عليه - يرجى تسجيل الدخول مرة أخرى');
      }

      AppLogger.info('✅ تم التحقق من المصادقة للمستخدم: ${authenticatedUser.id}');
    } catch (authError) {
      AppLogger.error('❌ خطأ في التحقق من المصادقة: $authError');
      throw Exception('فشل في التحقق من المصادقة: $authError');
    }

    try {
      AppLogger.info('🔄 بدء الخصم الذكي للمنتج: ${product.productName}');
      AppLogger.info('📦 الكمية المطلوبة: ${product.requestedQuantity}');
      AppLogger.info('🆔 معرف المنتج: ${product.productId}');
      AppLogger.info('👤 المنفذ: $performedBy');
      AppLogger.info('📋 معرف الطلب: $requestId');

      // التحقق من صحة البيانات الأساسية
      _validateDeductionData(product, performedBy, requestId);

      // التحقق من توفر معلومات المواقع
      if (!product.hasLocationData || product.warehouseLocations == null || product.warehouseLocations!.isEmpty) {
        AppLogger.warning('⚠️ لا توجد معلومات مواقع للمنتج، سيتم البحث أولاً');

        try {
          AppLogger.info('🔍 بدء البحث العالمي عن المنتج: ${product.productName}');

          // CRITICAL FIX: Verify authentication state before global search
          final currentUser = await AuthStateManager.getCurrentUser(forceRefresh: false);
          if (currentUser == null) {
            AppLogger.error('❌ فقدان المصادقة قبل البحث العالمي');
            throw Exception('فقدان المصادقة أثناء البحث العالمي - يرجى تسجيل الدخول مرة أخرى');
          }

          // CRITICAL FIX: Enhanced authentication preservation for global search
          AppLogger.info('🔐 Pre-search auth verification: ${currentUser.id}');

          final searchResult = await OperationIsolationService.executeIsolatedOperation<GlobalInventorySearchResult>(
            operationName: 'global_inventory_search_${product.productName}',
            operation: () async {
              // Double-check authentication state before search
              final preSearchUser = _supabase.auth.currentUser;
              if (preSearchUser == null || preSearchUser.id != currentUser.id) {
                AppLogger.error('❌ Authentication context lost before global search');
                throw Exception('فقدان المصادقة قبل البحث العالمي - يرجى تسجيل الدخول مرة أخرى');
              }

              AppLogger.info('🔍 Executing protected global search with preserved auth context');
              return await _performProtectedGlobalSearch(
                productId: product.productId,
                requestedQuantity: product.requestedQuantity,
                strategy: strategy,
                authenticatedUser: currentUser,
              );
            },
            fallbackValue: () {
              AppLogger.error('❌ Global search failed, returning zero-stock fallback');
              return GlobalInventorySearchResult(
                productId: product.productId,
                requestedQuantity: product.requestedQuantity,
                totalAvailableQuantity: 0,
                canFulfill: false,
                availableWarehouses: [],
                allocationPlan: [],
                searchStrategy: strategy,
                searchTimestamp: DateTime.now(),
                error: 'فشل في البحث العالمي - تم إرجاع نتيجة احتياطية',
              );
            },
            preserveAuthState: true,
            maxRetries: 2, // Increased retries for authentication issues
          );

          AppLogger.info('🔍 نتائج البحث العالمي:');
          AppLogger.info('   يمكن التلبية: ${searchResult.canFulfill}');
          AppLogger.info('   الكمية المتاحة: ${searchResult.totalAvailableQuantity}');
          AppLogger.info('   عدد المخازن: ${searchResult.availableWarehouses.length}');
          AppLogger.info('   معرف المنتج: ${product.productId}');
          AppLogger.info('   حالة المصادقة: ${_supabase.auth.currentUser?.id ?? "NULL"}');

          if (!searchResult.canFulfill) {
            final errorMsg = 'لا يمكن تلبية الطلب - الكمية المتاحة: ${searchResult.totalAvailableQuantity} من ${product.requestedQuantity} مطلوب';

            // Enhanced diagnostic logging for zero stock
            AppLogger.error('❌ $errorMsg');
            AppLogger.error('🔍 تشخيص مفصل للمشكلة:');
            AppLogger.error('   معرف المنتج: ${product.productId}');
            AppLogger.error('   الكمية المطلوبة: ${product.requestedQuantity}');
            AppLogger.error('   الكمية المتاحة: ${searchResult.totalAvailableQuantity}');
            AppLogger.error('   عدد المخازن المتاحة: ${searchResult.availableWarehouses.length}');
            AppLogger.error('   استراتيجية البحث: ${strategy.toString()}');
            AppLogger.error('   وقت البحث: ${searchResult.searchTimestamp}');
            AppLogger.error('   خطأ البحث: ${searchResult.error ?? "لا يوجد"}');
            AppLogger.error('   حالة المصادقة الحالية: ${_supabase.auth.currentUser?.id ?? "NULL"}');

            if (searchResult.availableWarehouses.isEmpty) {
              AppLogger.error('⚠️ لم يتم العثور على أي مخازن متاحة - قد تكون مشكلة في المصادقة أو RLS');
            }

            throw Exception(errorMsg);
          }

          // CRITICAL FIX: Use isolated operation for allocation plan execution
          AppLogger.info('⚡ تنفيذ خطة التخصيص من البحث العالمي...');
          final result = await OperationIsolationService.executeIsolatedOperation<InventoryDeductionResult>(
            operationName: 'allocation_execution_${product.productName}',
            operation: () => _globalInventoryService.executeAllocationPlan(
              allocationPlan: searchResult.allocationPlan,
              requestId: requestId,
              performedBy: performedBy,
              reason: 'خصم تلقائي لطلب الصرف - ${product.productName}',
            ),
            fallbackValue: () => InventoryDeductionResult(
              requestId: requestId,
              success: false,
              totalRequestedQuantity: product.requestedQuantity,
              totalDeductedQuantity: 0,
              warehouseResults: [],
              errors: ['فشل في تنفيذ خطة التخصيص - تم استخدام القيمة الاحتياطية'],
              executionTime: DateTime.now(),
              performedBy: performedBy,
            ),
            preserveAuthState: true,
            maxRetries: 1,
          );

          AppLogger.info('✅ تم تنفيذ خطة التخصيص من البحث العالمي بنجاح');
          AppLogger.info('📊 إجمالي المخصوم: ${result.totalDeductedQuantity} من ${result.totalRequestedQuantity}');

          return result;

        } catch (e) {
          AppLogger.error('❌ خطأ في البحث العالمي أو تنفيذ التخصيص: $e');

          // CRITICAL FIX: Attempt authentication recovery after failed global search
          try {
            AppLogger.info('🔄 محاولة استعادة المصادقة بعد فشل البحث العالمي...');
            final recoveredUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
            if (recoveredUser != null) {
              AppLogger.info('✅ تم استعادة المصادقة بنجاح: ${recoveredUser.id}');
            } else {
              AppLogger.warning('⚠️ فشل في استعادة المصادقة');
            }
          } catch (recoveryError) {
            AppLogger.error('❌ خطأ في استعادة المصادقة: $recoveryError');
          }

          throw Exception('فشل في البحث العالمي للمنتج ${product.productName}: $e');
        }
      }

      AppLogger.info('📍 استخدام معلومات المواقع المتاحة (${product.warehouseLocations!.length} مخزن)');

      // استخدام معلومات المواقع المتاحة لإنشاء خطة التخصيص
      final allocationPlan = await _createAllocationPlanFromLocations(
        product: product,
        strategy: strategy,
      );

      if (allocationPlan.isEmpty) {
        final errorMsg = 'فشل في إنشاء خطة التخصيص للمنتج - لا توجد مخازن متاحة';
        AppLogger.error('❌ $errorMsg');
        throw Exception(errorMsg);
      }

      AppLogger.info('📋 تم إنشاء خطة التخصيص: ${allocationPlan.length} مخزن');

      // تنفيذ خطة التخصيص
      AppLogger.info('⚡ تنفيذ خطة التخصيص...');
      final result = await _globalInventoryService.executeAllocationPlan(
        allocationPlan: allocationPlan,
        requestId: requestId,
        performedBy: performedBy,
        reason: 'خصم تلقائي لطلب الصرف - ${product.productName}',
      );

      AppLogger.info('✅ تم الخصم الذكي بنجاح للمنتج: ${product.productName}');
      AppLogger.info('📊 إجمالي المخصوم: ${result.totalDeductedQuantity} من ${result.totalRequestedQuantity}');
      AppLogger.info('🏪 المخازن المتأثرة: ${result.warehouseResults.length}');

      return result;
    } catch (e) {
      AppLogger.error('❌ خطأ في الخصم الذكي للمنتج ${product.productName}: $e');

      // CRITICAL FIX: Attempt authentication recovery after any failure
      try {
        AppLogger.info('🔄 محاولة استعادة المصادقة بعد فشل عملية الخصم...');
        final recoveredUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
        if (recoveredUser != null) {
          AppLogger.info('✅ تم استعادة المصادقة بنجاح بعد الفشل: ${recoveredUser.id}');
        } else {
          AppLogger.warning('⚠️ فشل في استعادة المصادقة بعد الفشل');
        }
      } catch (recoveryError) {
        AppLogger.error('❌ خطأ في استعادة المصادقة بعد الفشل: $recoveryError');
      }

      // تحليل نوع الخطأ وإرجاع رسالة مفصلة
      final detailedError = _analyzeDeductionError(e, product);
      throw Exception(detailedError);
    }
  }

  /// إنشاء خطة التخصيص من معلومات المواقع المتاحة
  Future<List<InventoryAllocation>> _createAllocationPlanFromLocations({
    required DispatchProductProcessingModel product,
    required WarehouseSelectionStrategy strategy,
  }) async {
    try {
      final locations = product.warehouseLocations!;
      var remainingQuantity = product.requestedQuantity;
      final allocations = <InventoryAllocation>[];

      // ترتيب المواقع حسب الاستراتيجية
      final sortedLocations = _sortLocationsByStrategy(locations, strategy);

      for (final location in sortedLocations) {
        if (remainingQuantity <= 0) break;

        // حساب الكمية المتاحة للتخصيص (مع احترام الحد الأدنى)
        final availableForAllocation = location.minimumStock != null
            ? (location.availableQuantity - location.minimumStock!).clamp(0, location.availableQuantity)
            : location.availableQuantity;

        if (availableForAllocation <= 0) continue;

        // تحديد الكمية المخصصة
        final allocatedQuantity = remainingQuantity.clamp(0, availableForAllocation);

        if (allocatedQuantity > 0) {
          allocations.add(InventoryAllocation(
            warehouseId: location.warehouseId,
            warehouseName: location.warehouseName,
            productId: product.productId,
            allocatedQuantity: allocatedQuantity,
            availableQuantity: location.availableQuantity,
            minimumStock: location.minimumStock ?? 0,
            allocationReason: _getAllocationReason(strategy, location),
            allocationPriority: allocations.length + 1,
            estimatedDeductionTime: DateTime.now(),
          ));

          remainingQuantity -= allocatedQuantity;
        }
      }

      AppLogger.info('📋 تم إنشاء خطة التخصيص: ${allocations.length} مخزن');
      AppLogger.info('📊 إجمالي المخصص: ${product.requestedQuantity - remainingQuantity} من ${product.requestedQuantity}');

      return allocations;
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء خطة التخصيص: $e');
      throw Exception('فشل في إنشاء خطة التخصيص: $e');
    }
  }

  /// ترتيب المواقع حسب الاستراتيجية
  List<WarehouseLocationInfo> _sortLocationsByStrategy(
    List<WarehouseLocationInfo> locations,
    WarehouseSelectionStrategy strategy,
  ) {
    switch (strategy) {
      case WarehouseSelectionStrategy.highestStock:
        return locations..sort((a, b) => b.availableQuantity.compareTo(a.availableQuantity));
      
      case WarehouseSelectionStrategy.lowestStock:
        return locations..sort((a, b) => a.availableQuantity.compareTo(b.availableQuantity));
      
      case WarehouseSelectionStrategy.fifo:
        return locations..sort((a, b) => a.lastUpdated.compareTo(b.lastUpdated));
      
      case WarehouseSelectionStrategy.priorityBased:
      case WarehouseSelectionStrategy.balanced:
      default:
        // ترتيب متوازن: أعلى كمية أولاً مع تفضيل المخازن ذات الحالة الجيدة
        return locations..sort((a, b) {
          // تفضيل المخازن ذات المخزون الجيد
          if (a.stockStatus == 'in_stock' && b.stockStatus != 'in_stock') return -1;
          if (b.stockStatus == 'in_stock' && a.stockStatus != 'in_stock') return 1;
          
          // ثم حسب الكمية المتاحة
          return b.availableQuantity.compareTo(a.availableQuantity);
        });
    }
  }

  /// الحصول على سبب التخصيص
  String _getAllocationReason(WarehouseSelectionStrategy strategy, WarehouseLocationInfo location) {
    switch (strategy) {
      case WarehouseSelectionStrategy.highestStock:
        return 'أعلى مخزون (${location.availableQuantity})';
      case WarehouseSelectionStrategy.lowestStock:
        return 'أقل مخزون (${location.availableQuantity})';
      case WarehouseSelectionStrategy.fifo:
        return 'الأقدم أولاً';
      case WarehouseSelectionStrategy.priorityBased:
        return 'حسب الأولوية';
      case WarehouseSelectionStrategy.balanced:
      default:
        return 'توزيع متوازن (${location.availableQuantity})';
    }
  }

  /// خصم متعدد المنتجات
  Future<Map<String, InventoryDeductionResult>> deductMultipleProducts({
    required List<DispatchProductProcessingModel> products,
    required String performedBy,
    required String requestId,
    WarehouseSelectionStrategy strategy = WarehouseSelectionStrategy.highestStock,
  }) async {
    try {
      AppLogger.info('🔄 بدء الخصم المتعدد لـ ${products.length} منتج');

      final results = <String, InventoryDeductionResult>{};
      final errors = <String>[];

      for (final product in products) {
        try {
          final result = await deductProductInventory(
            product: product,
            performedBy: performedBy,
            requestId: requestId,
            strategy: strategy,
          );
          results[product.productId] = result;
        } catch (e) {
          final error = 'فشل في خصم المنتج ${product.productName}: $e';
          errors.add(error);
          AppLogger.error('❌ $error');
        }
      }

      final successCount = results.length;
      final failureCount = errors.length;

      AppLogger.info('📊 نتائج الخصم المتعدد:');
      AppLogger.info('   نجح: $successCount منتج');
      AppLogger.info('   فشل: $failureCount منتج');

      if (errors.isNotEmpty) {
        AppLogger.warning('⚠️ أخطاء الخصم المتعدد:');
        for (final error in errors) {
          AppLogger.warning('   - $error');
        }
      }

      return results;
    } catch (e) {
      AppLogger.error('❌ خطأ عام في الخصم المتعدد: $e');
      throw Exception('فشل في الخصم المتعدد للمنتجات: $e');
    }
  }

  /// التحقق من إمكانية الخصم قبل التنفيذ
  Future<DeductionFeasibilityCheck> checkDeductionFeasibility({
    required DispatchProductProcessingModel product,
    WarehouseSelectionStrategy strategy = WarehouseSelectionStrategy.highestStock,
  }) async {
    try {
      AppLogger.info('🔍 فحص إمكانية الخصم للمنتج: ${product.productName}');

      if (!product.hasLocationData || product.warehouseLocations == null) {
        // البحث عن المنتج إذا لم تكن المعلومات متاحة
        // استخدام استراتيجية أعلى مخزون أولاً لضمان اختيار المخازن ذات الكمية الأكبر
        final searchResult = await _globalInventoryService.searchProductGlobally(
          productId: product.productId,
          requestedQuantity: product.requestedQuantity,
          strategy: WarehouseSelectionStrategy.highestStock,
        );

        return DeductionFeasibilityCheck(
          productId: product.productId,
          productName: product.productName,
          requestedQuantity: product.requestedQuantity,
          availableQuantity: searchResult.totalAvailableQuantity,
          canFulfill: searchResult.canFulfill,
          availableWarehouses: searchResult.availableWarehouses.length,
          shortfall: searchResult.canFulfill ? 0 : (product.requestedQuantity - searchResult.totalAvailableQuantity),
          checkTime: DateTime.now(),
        );
      }

      // استخدام المعلومات المتاحة
      final totalAvailable = product.totalAvailableQuantity;
      final canFulfill = totalAvailable >= product.requestedQuantity;
      final shortfall = canFulfill ? 0 : (product.requestedQuantity - totalAvailable);

      return DeductionFeasibilityCheck(
        productId: product.productId,
        productName: product.productName,
        requestedQuantity: product.requestedQuantity,
        availableQuantity: totalAvailable,
        canFulfill: canFulfill,
        availableWarehouses: product.warehouseLocations!.length,
        shortfall: shortfall,
        checkTime: DateTime.now(),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في فحص إمكانية الخصم: $e');
      throw Exception('فشل في فحص إمكانية الخصم: $e');
    }
  }

  /// إنشاء تقرير الخصم
  DeductionReport createDeductionReport(Map<String, InventoryDeductionResult> results) {
    final totalProducts = results.length;
    final successfulDeductions = results.values.where((r) => r.success).length;
    final failedDeductions = totalProducts - successfulDeductions;
    
    final totalRequested = results.values.fold<int>(0, (sum, r) => sum + r.totalRequestedQuantity);
    final totalDeducted = results.values.fold<int>(0, (sum, r) => sum + r.totalDeductedQuantity);
    
    final allWarehouses = <String>{};
    for (final result in results.values) {
      for (final warehouseResult in result.warehouseResults) {
        if (warehouseResult.success) {
          allWarehouses.add(warehouseResult.warehouseName);
        }
      }
    }

    return DeductionReport(
      totalProducts: totalProducts,
      successfulDeductions: successfulDeductions,
      failedDeductions: failedDeductions,
      totalRequestedQuantity: totalRequested,
      totalDeductedQuantity: totalDeducted,
      affectedWarehouses: allWarehouses.toList(),
      deductionResults: results,
      reportTime: DateTime.now(),
    );
  }

  /// التحقق من صحة بيانات الخصم
  void _validateDeductionData(DispatchProductProcessingModel product, String performedBy, String requestId) {
    if (product.productId.isEmpty) {
      throw Exception('معرف المنتج مطلوب ولا يمكن أن يكون فارغاً');
    }

    if (product.productName.isEmpty) {
      throw Exception('اسم المنتج مطلوب ولا يمكن أن يكون فارغاً');
    }

    if (product.requestedQuantity <= 0) {
      throw Exception('الكمية المطلوبة يجب أن تكون أكبر من صفر');
    }

    if (performedBy.isEmpty) {
      throw Exception('معرف المنفذ مطلوب ولا يمكن أن يكون فارغاً');
    }

    if (requestId.isEmpty) {
      throw Exception('معرف الطلب مطلوب ولا يمكن أن يكون فارغاً');
    }

    AppLogger.info('✅ تم التحقق من صحة بيانات الخصم');
  }

  /// البحث العالمي المحمي مع حفظ حالة المصادقة
  Future<GlobalInventorySearchResult> _performProtectedGlobalSearch({
    required String productId,
    required int requestedQuantity,
    required WarehouseSelectionStrategy strategy,
    required User authenticatedUser,
  }) async {
    try {
      AppLogger.info('🔒 تنفيذ البحث العالمي المحمي للمنتج: $productId');

      // التحقق من حالة المصادقة قبل البحث
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != authenticatedUser.id) {
        AppLogger.warning('⚠️ تغيرت حالة المصادقة أثناء البحث، محاولة الاستعادة...');

        // محاولة استعادة المصادقة
        final recoveredUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
        if (recoveredUser == null || recoveredUser.id != authenticatedUser.id) {
          throw Exception('فقدان المصادقة أثناء البحث العالمي');
        }
      }

      // تنفيذ البحث العالمي
      final searchResult = await _globalInventoryService.searchProductGlobally(
        productId: productId,
        requestedQuantity: requestedQuantity,
        strategy: strategy,
      );

      // التحقق من حالة المصادقة بعد البحث
      final postSearchUser = _supabase.auth.currentUser;
      if (postSearchUser == null || postSearchUser.id != authenticatedUser.id) {
        AppLogger.warning('⚠️ تأثرت حالة المصادقة بعد البحث العالمي');

        // محاولة استعادة المصادقة
        await AuthStateManager.getCurrentUser(forceRefresh: true);
      }

      AppLogger.info('✅ تم البحث العالمي المحمي بنجاح');
      return searchResult;

    } catch (e) {
      AppLogger.error('❌ خطأ في البحث العالمي المحمي: $e');

      // محاولة استعادة المصادقة في حالة الخطأ
      try {
        await AuthStateManager.getCurrentUser(forceRefresh: true);
      } catch (recoveryError) {
        AppLogger.error('❌ فشل في استعادة المصادقة بعد خطأ البحث: $recoveryError');
      }

      rethrow;
    }
  }

  /// تحليل خطأ الخصم وإرجاع رسالة مفصلة
  String _analyzeDeductionError(dynamic error, DispatchProductProcessingModel product) {
    final errorString = error.toString().toLowerCase();

    // خطأ قاعدة البيانات
    if (errorString.contains('connection') || errorString.contains('network')) {
      return 'خطأ في الاتصال بقاعدة البيانات أثناء خصم ${product.productName}. يرجى التحقق من الاتصال والمحاولة مرة أخرى.';
    }

    // خطأ المصادقة
    if (errorString.contains('auth') || errorString.contains('unauthorized')) {
      return 'خطأ في المصادقة أثناء خصم ${product.productName}. يرجى تسجيل الدخول مرة أخرى.';
    }

    // خطأ الصلاحيات
    if (errorString.contains('permission') || errorString.contains('forbidden') || errorString.contains('غير مصرح')) {
      return 'ليس لديك صلاحية لخصم ${product.productName} من المخزون. يرجى التواصل مع المدير.';
    }

    // خطأ المخزون غير كافي
    if (errorString.contains('لا يمكن تلبية الطلب') || errorString.contains('الكمية المتاحة')) {
      return 'المخزون غير كافي لـ ${product.productName}. الكمية المطلوبة: ${product.requestedQuantity}';
    }

    // خطأ المنتج غير موجود
    if (errorString.contains('المنتج غير موجود') || errorString.contains('product not found')) {
      return 'المنتج ${product.productName} غير موجود في أي مخزن متاح.';
    }

    // خطأ المخزن غير متاح
    if (errorString.contains('warehouse') || errorString.contains('مخزن')) {
      return 'خطأ في الوصول للمخازن أثناء خصم ${product.productName}. قد تكون المخازن غير متاحة.';
    }

    // خطأ التخصيص
    if (errorString.contains('فشل في إنشاء خطة التخصيص') || errorString.contains('allocation')) {
      return 'فشل في تخصيص ${product.productName} على المخازن المتاحة. قد تكون جميع المخازن ممتلئة.';
    }

    // خطأ عام
    return 'حدث خطأ غير متوقع أثناء خصم ${product.productName}: ${error.toString()}';
  }
}

/// فحص إمكانية الخصم
class DeductionFeasibilityCheck {
  final String productId;
  final String productName;
  final int requestedQuantity;
  final int availableQuantity;
  final bool canFulfill;
  final int availableWarehouses;
  final int shortfall;
  final DateTime checkTime;

  const DeductionFeasibilityCheck({
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.availableQuantity,
    required this.canFulfill,
    required this.availableWarehouses,
    required this.shortfall,
    required this.checkTime,
  });

  /// نسبة التوفر
  double get availabilityPercentage => requestedQuantity > 0 ? (availableQuantity / requestedQuantity * 100).clamp(0, 100) : 0;

  /// نص الحالة
  String get statusText {
    if (canFulfill) return 'يمكن تلبية الطلب بالكامل';
    if (availableQuantity > 0) return 'تلبية جزئية ممكنة';
    return 'غير متوفر';
  }
}

/// تقرير الخصم
class DeductionReport {
  final int totalProducts;
  final int successfulDeductions;
  final int failedDeductions;
  final int totalRequestedQuantity;
  final int totalDeductedQuantity;
  final List<String> affectedWarehouses;
  final Map<String, InventoryDeductionResult> deductionResults;
  final DateTime reportTime;

  const DeductionReport({
    required this.totalProducts,
    required this.successfulDeductions,
    required this.failedDeductions,
    required this.totalRequestedQuantity,
    required this.totalDeductedQuantity,
    required this.affectedWarehouses,
    required this.deductionResults,
    required this.reportTime,
  });

  /// نسبة النجاح
  double get successRate => totalProducts > 0 ? (successfulDeductions / totalProducts * 100) : 0;

  /// نسبة الخصم المكتمل
  double get deductionCompletionRate => totalRequestedQuantity > 0 ? (totalDeductedQuantity / totalRequestedQuantity * 100) : 0;

  /// نص ملخص التقرير
  String get summaryText {
    return 'تم خصم $totalDeductedQuantity من $totalRequestedQuantity قطعة '
           'من $totalProducts منتج ($successfulDeductions نجح، $failedDeductions فشل) '
           'من ${affectedWarehouses.length} مخزن';
  }
}
