import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:smartbiztracker_new/models/warehouse_inventory_model.dart';
import 'package:smartbiztracker_new/models/warehouse_request_model.dart';
import 'package:smartbiztracker_new/models/warehouse_transaction_model.dart';
import 'package:smartbiztracker_new/models/warehouse_deletion_models.dart';
import 'package:smartbiztracker_new/services/warehouse_service.dart';
import 'package:smartbiztracker_new/services/warehouse_cache_service.dart';
import 'package:smartbiztracker_new/services/warehouse_performance_validator.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/utils/product_display_helper.dart';
import 'package:smartbiztracker_new/utils/api_test_helper.dart';
import 'package:smartbiztracker_new/utils/carton_debug_helper.dart';
import 'package:smartbiztracker_new/services/database_performance_optimizer.dart';

/// مزود إدارة المخازن
class WarehouseProvider with ChangeNotifier {
  final WarehouseService _warehouseService;

  // حالة التحميل
  bool _isLoading = false;
  bool _isLoadingWarehouses = false;
  bool _isLoadingInventory = false;
  bool _isLoadingRequests = false;
  String? _error;

  // البيانات
  List<WarehouseModel> _warehouses = [];
  List<WarehouseInventoryModel> _currentInventory = [];
  List<WarehouseRequestModel> _requests = [];
  List<WarehouseTransactionModel> _transactions = [];
  Map<String, dynamic> _statistics = {};

  // المخزن المحدد حالياً
  WarehouseModel? _selectedWarehouse;

  // تتبع المخزن الحالي للمعاملات لضمان عرض البيانات الصحيحة
  String? _currentWarehouseId;

  // التخزين المؤقت
  final Map<String, List<WarehouseInventoryModel>> _inventoryCache = {};
  final Map<String, Map<String, dynamic>> _statisticsCache = {};
  DateTime? _lastCacheUpdate;

  WarehouseProvider({WarehouseService? warehouseService})
      : _warehouseService = warehouseService ?? WarehouseService();

  // ==================== Getters ====================

  bool get isLoading => _isLoading;
  bool get isLoadingWarehouses => _isLoadingWarehouses;
  bool get isLoadingInventory => _isLoadingInventory;
  bool get isLoadingRequests => _isLoadingRequests;
  String? get error => _error;

  List<WarehouseModel> get warehouses => List.unmodifiable(_warehouses);
  List<WarehouseInventoryModel> get currentInventory => List.unmodifiable(_currentInventory);
  List<WarehouseRequestModel> get requests => List.unmodifiable(_requests);
  List<WarehouseTransactionModel> get transactions => List.unmodifiable(_transactions);
  Map<String, dynamic> get statistics => Map.unmodifiable(_statistics);

  WarehouseModel? get selectedWarehouse => _selectedWarehouse;

  /// الحصول على المخازن النشطة فقط
  List<WarehouseModel> get activeWarehouses => 
      _warehouses.where((w) => w.isActive).toList();

  /// الحصول على عدد المنتجات في المخزن المحدد
  int get totalProductsInSelectedWarehouse => _currentInventory.length;

  /// الحصول على إجمالي الكمية في المخزن المحدد
  int get totalQuantityInSelectedWarehouse => 
      _currentInventory.fold(0, (sum, item) => sum + item.quantity);

  /// الحصول على المنتجات منخفضة المخزون
  List<WarehouseInventoryModel> get lowStockProducts => 
      _currentInventory.where((item) => item.isLowStock).toList();

  /// الحصول على المنتجات نفدت من المخزون
  List<WarehouseInventoryModel> get outOfStockProducts => 
      _currentInventory.where((item) => item.isOutOfStock).toList();

  /// الحصول على الطلبات المعلقة
  List<WarehouseRequestModel> get pendingRequests => 
      _requests.where((r) => r.status == WarehouseRequestStatus.pending).toList();

  /// الحصول على الطلبات الموافق عليها
  List<WarehouseRequestModel> get approvedRequests => 
      _requests.where((r) => r.status == WarehouseRequestStatus.approved).toList();

  // ==================== إدارة المخازن ====================

  /// تحميل جميع المخازن مع تحسينات الأداء
  Future<void> loadWarehouses({bool forceRefresh = false}) async {
    if (_isLoadingWarehouses) return;

    // التحقق من التخزين المؤقت المحلي أولاً
    if (!forceRefresh && _warehouses.isNotEmpty && _isCacheValid()) {
      AppLogger.info('⚡ Using warehouses from local cache');
      return;
    }

    _isLoadingWarehouses = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('📦 Loading warehouses with performance optimization');

      // استخدام التخزين المؤقت المحسن في الخدمة
      final warehouses = await _warehouseService.getWarehouses(useCache: !forceRefresh);
      _warehouses = warehouses;
      _lastCacheUpdate = DateTime.now();

      // تحميل إحصائيات المخازن في الخلفية (غير متزامن)
      _loadAllWarehouseStatisticsInBackground();

      AppLogger.info('✅ Loaded ${warehouses.length} warehouses successfully');

      if (warehouses.isNotEmpty) {
        AppLogger.info('🏢 First warehouse: ${warehouses.first.name}');
      }

    } catch (e) {
      _error = 'Error loading warehouses: $e';
      AppLogger.error(_error!);

      // محاولة تشخيص سبب الفشل
      await _diagnoseFailureReason(e);

    } finally {
      _isLoadingWarehouses = false;
      notifyListeners();
    }
  }

  /// تحميل إحصائيات المخازن في الخلفية دون حجب واجهة المستخدم
  void _loadAllWarehouseStatisticsInBackground() {
    Future.delayed(Duration(milliseconds: 100), () async {
      try {
        await _loadAllWarehouseStatistics();
      } catch (e) {
        AppLogger.warning('⚠️ Background statistics loading failed: $e');
      }
    });
  }

  /// تشخيص حالة المصادقة قبل تحميل المخازن
  Future<void> _diagnoseAuthenticationState() async {
    try {
      AppLogger.info('🔍 تشخيص حالة المصادقة في WarehouseProvider...');

      // فحص Supabase.instance.client.auth.currentUser
      final currentUser = Supabase.instance.client.auth.currentUser;
      final currentSession = Supabase.instance.client.auth.currentSession;

      AppLogger.info('👤 المستخدم الحالي: ${currentUser?.id ?? 'null'}');
      AppLogger.info('📧 البريد الإلكتروني: ${currentUser?.email ?? 'null'}');
      AppLogger.info('🔐 الجلسة موجودة: ${currentSession != null}');
      AppLogger.info('⏰ الجلسة منتهية: ${currentSession?.isExpired ?? 'unknown'}');

      if (currentUser == null) {
        AppLogger.warning('⚠️ لا يوجد مستخدم مصادق - محاولة استرداد الجلسة...');

        try {
          final refreshResult = await Supabase.instance.client.auth.refreshSession();
          if (refreshResult.user != null) {
            AppLogger.info('✅ تم استرداد الجلسة بنجاح: ${refreshResult.user!.id}');
          } else {
            AppLogger.error('❌ فشل في استرداد الجلسة');
          }
        } catch (refreshError) {
          AppLogger.error('❌ خطأ في استرداد الجلسة: $refreshError');
        }
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في تشخيص المصادقة: $e');
    }
  }

  /// تشخيص سبب فشل تحميل المخازن
  Future<void> _diagnoseFailureReason(dynamic error) async {
    try {
      AppLogger.info('🔍 تشخيص سبب فشل تحميل المخازن...');

      final errorString = error.toString();

      if (errorString.contains('لا يوجد مستخدم مسجل دخول')) {
        AppLogger.error('🚨 السبب: فقدان سياق المصادقة');
        AppLogger.info('💡 الحل المقترح: إعادة تسجيل الدخول أو استرداد الجلسة');
      } else if (errorString.contains('row-level security policy')) {
        AppLogger.error('🚨 السبب: مشكلة في RLS policies');
        AppLogger.info('💡 الحل المقترح: التحقق من دور المستخدم وحالة الموافقة');
      } else if (errorString.contains('JWT')) {
        AppLogger.error('🚨 السبب: مشكلة في JWT token');
        AppLogger.info('💡 الحل المقترح: إعادة تسجيل الدخول');
      } else {
        AppLogger.error('🚨 السبب: خطأ غير محدد - $errorString');
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في تشخيص سبب الفشل: $e');
    }
  }

  /// إنشاء مخزن جديد
  Future<bool> createWarehouse({
    required String name,
    required String address,
    String? description,
    required String createdBy,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('📦 جاري إنشاء مخزن جديد: $name');

      final warehouse = await _warehouseService.createWarehouse(
        name: name,
        address: address,
        description: description,
        createdBy: createdBy,
      );

      if (warehouse != null) {
        _warehouses.add(warehouse);
        AppLogger.info('✅ تم إنشاء المخزن بنجاح');
        return true;
      } else {
        _error = 'فشل في إنشاء المخزن';
        return false;
      }
    } catch (e) {
      _error = 'خطأ في إنشاء المخزن: $e';
      AppLogger.error(_error!);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تحديث مخزن
  Future<bool> updateWarehouse({
    required String warehouseId,
    String? name,
    String? address,
    String? description,
    bool? isActive,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('📦 جاري تحديث المخزن: $warehouseId');

      final updatedWarehouse = await _warehouseService.updateWarehouse(
        warehouseId: warehouseId,
        name: name,
        address: address,
        description: description,
        isActive: isActive,
      );

      if (updatedWarehouse != null) {
        final index = _warehouses.indexWhere((w) => w.id == warehouseId);
        if (index != -1) {
          _warehouses[index] = updatedWarehouse;
        }

        // تحديث المخزن المحدد إذا كان هو نفسه
        if (_selectedWarehouse?.id == warehouseId) {
          _selectedWarehouse = updatedWarehouse;
        }

        AppLogger.info('✅ تم تحديث المخزن بنجاح');
        return true;
      } else {
        _error = 'فشل في تحديث المخزن';
        return false;
      }
    } catch (e) {
      _error = 'خطأ في تحديث المخزن: $e';
      AppLogger.error(_error!);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// حذف مخزن
  Future<bool> deleteWarehouse(String warehouseId, {bool forceDelete = false, String? targetWarehouseId}) async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('📦 جاري حذف المخزن: $warehouseId (قسري: $forceDelete)');

      final success = await _warehouseService.deleteWarehouse(
        warehouseId,
        forceDelete: forceDelete,
        targetWarehouseId: targetWarehouseId,
      );

      if (success) {
        _warehouses.removeWhere((w) => w.id == warehouseId);
        
        // إلغاء تحديد المخزن إذا كان محذوفاً
        if (_selectedWarehouse?.id == warehouseId) {
          _selectedWarehouse = null;
          _currentInventory.clear();
        }

        // مسح التخزين المؤقت للمخزن المحذوف
        _inventoryCache.remove(warehouseId);
        _statisticsCache.remove(warehouseId);

        AppLogger.info('✅ تم حذف المخزن بنجاح');
        return true;
      } else {
        _error = 'فشل في حذف المخزن';
        return false;
      }
    } catch (e) {
      _error = 'خطأ في حذف المخزن: $e';
      AppLogger.error(_error!);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تحليل إمكانية حذف المخزن مع تفاصيل شاملة
  Future<WarehouseDeletionAnalysis> analyzeWarehouseDeletion(String warehouseId) async {
    try {
      AppLogger.info('🔍 تحليل إمكانية حذف المخزن: $warehouseId');
      return await _warehouseService.analyzeWarehouseDeletion(warehouseId);
    } catch (e) {
      AppLogger.error('❌ خطأ في تحليل حذف المخزن: $e');
      rethrow;
    }
  }

  /// الحصول على المخازن المتاحة للنقل
  Future<List<dynamic>> getAvailableTargetWarehouses(String sourceWarehouseId) async {
    try {
      AppLogger.info('🔍 البحث عن المخازن المتاحة للنقل من: $sourceWarehouseId');
      return await _warehouseService.getAvailableTargetWarehouses(sourceWarehouseId);
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على المخازن المتاحة: $e');
      return [];
    }
  }

  /// التحقق من صحة نقل الطلبات
  Future<dynamic> validateOrderTransfer(String sourceWarehouseId, String targetWarehouseId) async {
    try {
      AppLogger.info('🔍 التحقق من صحة نقل الطلبات: $sourceWarehouseId -> $targetWarehouseId');
      return await _warehouseService.validateOrderTransfer(sourceWarehouseId, targetWarehouseId);
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من صحة النقل: $e');
      rethrow;
    }
  }

  /// تنفيذ نقل الطلبات
  Future<dynamic> executeOrderTransfer(String sourceWarehouseId, String targetWarehouseId) async {
    try {
      AppLogger.info('🔄 تنفيذ نقل الطلبات: $sourceWarehouseId -> $targetWarehouseId');
      return await _warehouseService.executeOrderTransfer(sourceWarehouseId, targetWarehouseId);
    } catch (e) {
      AppLogger.error('❌ خطأ في تنفيذ نقل الطلبات: $e');
      rethrow;
    }
  }

  /// إحصائيات النقل للمخزن
  Future<Map<String, dynamic>> getTransferStatistics(String warehouseId) async {
    try {
      AppLogger.info('📊 الحصول على إحصائيات النقل للمخزن: $warehouseId');
      return await _warehouseService.getTransferStatistics(warehouseId);
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على إحصائيات النقل: $e');
      return {};
    }
  }

  /// تحديد مخزن للعمل عليه
  Future<void> selectWarehouse(WarehouseModel warehouse) async {
    if (_selectedWarehouse?.id == warehouse.id) return;

    _selectedWarehouse = warehouse;
    AppLogger.info('📦 تم تحديد المخزن: ${warehouse.name}');

    // تحميل بيانات المخزن المحدد
    await Future.wait([
      loadWarehouseInventory(warehouse.id),
      loadWarehouseRequests(warehouseId: warehouse.id),
      loadWarehouseStatistics(warehouse.id),
    ]);

    notifyListeners();
  }

  /// إلغاء تحديد المخزن
  void clearSelectedWarehouse() {
    _selectedWarehouse = null;
    _currentInventory.clear();
    _requests.clear();
    _transactions.clear();
    _statistics.clear();
    _currentWarehouseId = null; // مسح معرف المخزن الحالي
    notifyListeners();
  }

  // ==================== إدارة المخزون ====================

  /// تحميل مخزون مخزن معين مع تحسينات الأداء ومنع التكرار
  Future<void> loadWarehouseInventory(String warehouseId, {bool forceRefresh = false}) async {
    final operationKey = 'inventory_$warehouseId';
    final performanceTimer = Stopwatch()..start();

    // منع العمليات المكررة
    if (WarehouseCacheService.isOperationPending(operationKey) && !forceRefresh) {
      AppLogger.info('⏳ مخزون المخزن $warehouseId قيد التحميل بالفعل');
      return;
    }

    if (_isLoadingInventory) return;

    // التحقق من التخزين المؤقت المحسن أولاً
    if (!forceRefresh) {
      final cachedInventory = await WarehouseCacheService.loadInventory(warehouseId);
      if (cachedInventory != null) {
        _currentInventory = cachedInventory;
        _inventoryCache[warehouseId] = cachedInventory;
        AppLogger.info('⚡ استخدام المخزون من التخزين المؤقت المحسن');

        // Record cache performance
        performanceTimer.stop();
        WarehousePerformanceValidator().recordPerformance(
          'warehouse_inventory_loading',
          performanceTimer.elapsedMilliseconds
        );

        notifyListeners();
        return;
      }
    }

    // تنفيذ العملية مع منع التكرار
    await WarehouseCacheService.preventDuplicateOperation(operationKey, () async {
      _isLoadingInventory = true;
      _error = null;
      notifyListeners();

      try {
        WarehouseCacheService.markOperationPending(operationKey);
        AppLogger.info('📦 Loading warehouse inventory with performance optimization: $warehouseId');

        // استخدام التخزين المؤقت المحسن في الخدمة
        final inventory = await _warehouseService.getWarehouseInventory(warehouseId, useCache: !forceRefresh);

        // تحديث المخزون المحلي
        _currentInventory = inventory;
        _inventoryCache[warehouseId] = inventory;

        // حفظ في التخزين المؤقت المحسن
        await WarehouseCacheService.saveInventory(warehouseId, inventory);

        AppLogger.info('✅ Loaded ${inventory.length} inventory items successfully');

        // Record database performance
        performanceTimer.stop();
        WarehousePerformanceValidator().recordPerformance(
          'warehouse_inventory_loading',
          performanceTimer.elapsedMilliseconds
        );

      } catch (e) {
        _error = 'Error loading inventory: $e';
        AppLogger.error(_error!);

        // Record failed performance
        performanceTimer.stop();
        WarehousePerformanceValidator().recordPerformance(
          'warehouse_inventory_loading',
          performanceTimer.elapsedMilliseconds
        );
      } finally {
        WarehouseCacheService.markOperationComplete(operationKey);
        _isLoadingInventory = false;
        notifyListeners();
      }
    });
  }

  /// إضافة منتج إلى المخزن أو تحديث الكمية إذا كان موجوداً
  Future<bool> addProductToWarehouse({
    required String warehouseId,
    required String productId,
    required int quantity,
    required String addedBy,
    int? minimumStock,
    int? maximumStock,
    int quantityPerCarton = 1, // الكمية في الكرتونة الواحدة
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('📦 جاري إضافة منتج إلى المخزن...');

      // اختبار API المحسن في وضع التطوير
      if (kDebugMode) {
        await ApiTestHelper.testEnhancedApiIntegration(productId);
      }

      // التحقق من جودة بيانات المنتج قبل الإضافة
      AppLogger.info('🔍 التحقق من جودة بيانات المنتج $productId قبل الإضافة...');

      final inventoryItem = await _warehouseService.addProductToWarehouse(
        warehouseId: warehouseId,
        productId: productId,
        quantity: quantity,
        addedBy: addedBy,
        minimumStock: minimumStock,
        maximumStock: maximumStock,
        quantityPerCarton: quantityPerCarton,
      );

      if (inventoryItem != null) {
        // تحسين عرض المنتج بالحصول على البيانات الحقيقية (فقط عند الإضافة الصريحة)
        // هذا التحسين مسموح هنا لأنه جزء من عملية إضافة منتج جديد وليس مجرد تحميل مخزون
        WarehouseInventoryModel enhancedInventoryItem = inventoryItem;
        if (inventoryItem.product != null) {
          try {
            AppLogger.info('🔄 تحسين عرض المنتج المضاف حديثاً: ${inventoryItem.product!.name}');
            final enhancedProduct = await ProductDisplayHelper.enhanceProductDisplay(inventoryItem.product!);
            enhancedInventoryItem = inventoryItem.copyWith(product: enhancedProduct);
            AppLogger.info('✅ تم تحسين عرض المنتج المضاف: ${enhancedProduct.name}');
          } catch (e) {
            AppLogger.warning('⚠️ فشل في تحسين عرض المنتج المضاف: $e');
            // استخدام المنتج الأصلي في حالة فشل التحسين
            enhancedInventoryItem = inventoryItem;
          }
        }

        // تحديث المخزون المحلي
        if (_selectedWarehouse?.id == warehouseId) {
          // البحث عن المنتج الموجود وتحديثه أو إضافة منتج جديد
          final existingIndex = _currentInventory.indexWhere(
            (item) => item.productId == productId
          );

          if (existingIndex != -1) {
            // تحديث المنتج الموجود
            final oldItem = _currentInventory[existingIndex];
            _currentInventory[existingIndex] = enhancedInventoryItem;
            AppLogger.info('📦 تم تحديث المنتج الموجود في المخزون المحلي');
            AppLogger.info('🔍 قبل التحديث - quantity: ${oldItem.quantity}, quantityPerCarton: ${oldItem.quantityPerCarton}, cartons: ${oldItem.cartonsCount}');
            AppLogger.info('🔍 بعد التحديث - quantity: ${enhancedInventoryItem.quantity}, quantityPerCarton: ${enhancedInventoryItem.quantityPerCarton}, cartons: ${enhancedInventoryItem.cartonsCount}');

            // استخدام مساعد التشخيص لمقارنة القيم
            CartonDebugHelper.compareCartonValues(
              before: oldItem,
              after: enhancedInventoryItem,
              operation: 'تحديث منتج موجود',
            );
          } else {
            // إضافة منتج جديد
            _currentInventory.add(enhancedInventoryItem);
            AppLogger.info('📦 تم إضافة منتج جديد إلى المخزون المحلي');
            AppLogger.info('🔍 منتج جديد - quantity: ${enhancedInventoryItem.quantity}, quantityPerCarton: ${enhancedInventoryItem.quantityPerCarton}, cartons: ${enhancedInventoryItem.cartonsCount}');
          }

          // إشعار الواجهة فوراً بالتحديث
          notifyListeners();
        }

        // مسح التخزين المؤقت للمخزن
        _inventoryCache.remove(warehouseId);

        // تحديث إحصائيات المخزن
        await _updateWarehouseStatistics(warehouseId);

        AppLogger.info('✅ تم إضافة/تحديث المنتج في المخزن بنجاح');
        return true;
      } else {
        _error = 'فشل في إضافة المنتج إلى المخزن';
        return false;
      }
    } catch (e) {
      // تحسين رسائل الخطأ للمستخدم
      String errorMessage = 'خطأ في إضافة المنتج';

      if (e.toString().contains('بيانات المنتج المستلمة من API عامة أو غير صحيحة')) {
        errorMessage = 'فشل في إضافة المنتج: البيانات المستلمة من API عامة أو غير صحيحة. يرجى التحقق من معرف المنتج أو المحاولة مرة أخرى.';
      } else if (e.toString().contains('المنتج موجود بالفعل')) {
        errorMessage = 'المنتج موجود بالفعل في هذا المخزن';
      } else if (e.toString().contains('ليس لديك صلاحية')) {
        errorMessage = 'ليس لديك صلاحية لإضافة منتجات إلى هذا المخزن';
      } else if (e.toString().contains('duplicate key')) {
        errorMessage = 'المنتج موجود بالفعل في المخزن';
      } else {
        errorMessage = 'حدث خطأ في إضافة المنتج: ${e.toString()}';
      }

      _error = errorMessage;
      AppLogger.error(_error!);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تحديث كمية منتج في المخزن
  Future<bool> updateProductQuantity({
    required String warehouseId,
    required String productId,
    required int quantityChange,
    required String performedBy,
    required String reason,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('📦 جاري تحديث كمية المنتج...');

      final success = await _warehouseService.updateInventory(
        warehouseId: warehouseId,
        productId: productId,
        quantityChange: quantityChange,
        performedBy: performedBy,
        reason: reason,
        referenceType: 'manual',
      );

      if (success) {
        // تحديث المخزون المحلي
        if (_selectedWarehouse?.id == warehouseId) {
          final index = _currentInventory.indexWhere((item) => item.productId == productId);
          if (index != -1) {
            final currentItem = _currentInventory[index];
            final newQuantity = currentItem.quantity + quantityChange;
            _currentInventory[index] = currentItem.copyWith(
              quantity: newQuantity,
              lastUpdated: DateTime.now(),
              updatedBy: performedBy,
            );
            // إشعار الواجهة فوراً بالتحديث
            notifyListeners();
          }
        }

        // مسح التخزين المؤقت
        _inventoryCache.remove(warehouseId);

        // تحديث إحصائيات المخزن
        await _updateWarehouseStatistics(warehouseId);

        AppLogger.info('✅ تم تحديث كمية المنتج بنجاح');
        return true;
      } else {
        _error = 'فشل في تحديث كمية المنتج';
        return false;
      }
    } catch (e) {
      _error = 'خطأ في تحديث الكمية: $e';
      AppLogger.error(_error!);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// حذف منتج من المخزن
  Future<bool> removeProductFromWarehouse({
    required String warehouseId,
    required String productId,
    required String performedBy,
    String? reason,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🗑️ جاري حذف المنتج من المخزن...');

      // البحث عن المنتج في المخزون المحلي
      final productIndex = _currentInventory.indexWhere((item) => item.productId == productId);
      if (productIndex == -1) {
        _error = 'المنتج غير موجود في المخزن';
        return false;
      }

      final currentItem = _currentInventory[productIndex];

      // استخدام الطريقة الآمنة الجديدة لحذف المنتج
      final success = await _warehouseService.removeProductFromWarehouse(
        warehouseId: warehouseId,
        productId: productId,
        performedBy: performedBy,
        reason: reason ?? 'حذف المنتج من المخزن',
      );

      if (success) {
        // حذف المنتج من المخزون المحلي
        if (_selectedWarehouse?.id == warehouseId) {
          _currentInventory.removeAt(productIndex);
          // إشعار الواجهة فوراً بالتحديث
          notifyListeners();
        }

        // مسح التخزين المؤقت
        _inventoryCache.remove(warehouseId);

        // تحديث إحصائيات المخزن
        await _updateWarehouseStatistics(warehouseId);

        AppLogger.info('✅ تم حذف المنتج من المخزن بنجاح');
        return true;
      } else {
        _error = 'فشل في حذف المنتج من المخزن';
        return false;
      }
    } catch (e) {
      _error = 'خطأ في حذف المنتج: $e';
      AppLogger.error(_error!);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// نقل منتج بين المخازن
  Future<bool> transferProductBetweenWarehouses({
    required String fromWarehouseId,
    required String toWarehouseId,
    required String productId,
    required int quantity,
    required String performedBy,
    String? notes,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔄 جاري نقل المنتج بين المخازن...');

      // التحقق من وجود كمية كافية في المخزن المصدر
      final sourceInventory = await _warehouseService.getWarehouseInventory(fromWarehouseId);
      final sourceItem = sourceInventory.firstWhere(
        (item) => item.productId == productId,
        orElse: () => throw Exception('المنتج غير موجود في المخزن المصدر'),
      );

      if (sourceItem.quantity < quantity) {
        _error = 'الكمية المطلوبة غير متوفرة في المخزن المصدر';
        return false;
      }

      // سحب من المخزن المصدر
      final withdrawSuccess = await _warehouseService.updateInventory(
        warehouseId: fromWarehouseId,
        productId: productId,
        quantityChange: -quantity,
        performedBy: performedBy,
        reason: 'نقل إلى مخزن آخر',
        referenceType: 'transfer',
      );

      if (!withdrawSuccess) {
        _error = 'فشل في سحب المنتج من المخزن المصدر';
        return false;
      }

      // إضافة إلى المخزن الهدف
      final addSuccess = await addProductToWarehouse(
        warehouseId: toWarehouseId,
        productId: productId,
        quantity: quantity,
        addedBy: performedBy,
      );

      if (!addSuccess) {
        // إعادة الكمية إلى المخزن المصدر في حالة الفشل
        await _warehouseService.updateInventory(
          warehouseId: fromWarehouseId,
          productId: productId,
          quantityChange: quantity,
          performedBy: performedBy,
          reason: 'إعادة بعد فشل النقل',
          referenceType: 'transfer_rollback',
        );
        _error = 'فشل في إضافة المنتج إلى المخزن الهدف';
        return false;
      }

      // تحديث المخزون المحلي إذا كان أحد المخازن محدد حالياً
      if (_selectedWarehouse?.id == fromWarehouseId || _selectedWarehouse?.id == toWarehouseId) {
        await loadWarehouseInventory(_selectedWarehouse!.id, forceRefresh: true);
      }

      // مسح التخزين المؤقت للمخازن المتأثرة
      _inventoryCache.remove(fromWarehouseId);
      _inventoryCache.remove(toWarehouseId);

      // تحديث إحصائيات المخازن
      await _updateWarehouseStatistics(fromWarehouseId);
      await _updateWarehouseStatistics(toWarehouseId);

      AppLogger.info('✅ تم نقل المنتج بين المخازن بنجاح');
      return true;
    } catch (e) {
      _error = 'خطأ في نقل المنتج: $e';
      AppLogger.error(_error!);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== إدارة الطلبات ====================

  /// تحميل طلبات السحب
  Future<void> loadWarehouseRequests({
    String? warehouseId,
    WarehouseRequestStatus? status,
    String? requestedBy,
    bool forceRefresh = false,
  }) async {
    if (_isLoadingRequests) return;

    _isLoadingRequests = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('📋 جاري تحميل طلبات السحب...');

      final requests = await _warehouseService.getWarehouseRequests(
        warehouseId: warehouseId,
        status: status,
        requestedBy: requestedBy,
        limit: 100,
      );

      _requests = requests;

      AppLogger.info('✅ تم تحميل ${requests.length} طلب سحب');
    } catch (e) {
      _error = 'خطأ في تحميل الطلبات: $e';
      AppLogger.error(_error!);
    } finally {
      _isLoadingRequests = false;
      notifyListeners();
    }
  }

  // ==================== إدارة المعاملات ====================

  /// تحميل معاملات المخزن مع منع التكرار وتحسين الأداء
  Future<void> loadWarehouseTransactions(
    String warehouseId, {
    int limit = 50,
    int offset = 0,
    String? transactionType,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    final operationKey = 'transactions_$warehouseId';
    final performanceTimer = Stopwatch()..start();

    // منع العمليات المكررة
    if (WarehouseCacheService.isOperationPending(operationKey) && !forceRefresh) {
      AppLogger.info('⏳ معاملات المخزن $warehouseId قيد التحميل بالفعل');
      return;
    }

    if (_isLoading && !forceRefresh) return;

    // التحقق من التخزين المؤقت المحسن أولاً
    if (!forceRefresh) {
      final cachedTransactions = await WarehouseCacheService.loadWarehouseTransactions(warehouseId);
      if (cachedTransactions != null) {
        _transactions = cachedTransactions.cast<WarehouseTransactionModel>();
        AppLogger.info('⚡ استخدام معاملات المخزن من التخزين المؤقت المحسن');

        // Record cache performance
        performanceTimer.stop();
        WarehousePerformanceValidator().recordPerformance(
          'warehouse_transactions_loading',
          performanceTimer.elapsedMilliseconds
        );

        notifyListeners();
        return;
      }
    }

    // تنفيذ العملية مع منع التكرار
    await WarehouseCacheService.preventDuplicateOperation(operationKey, () async {
      _isLoading = true;
      _error = null;
      notifyListeners();

      try {
        WarehouseCacheService.markOperationPending(operationKey);
        AppLogger.info('📋 Loading warehouse transactions for: $warehouseId (forceRefresh: $forceRefresh)');

        // Clear existing transactions if force refresh or different warehouse
        if (forceRefresh || _currentWarehouseId != warehouseId) {
          _transactions.clear();
          _currentWarehouseId = warehouseId;
          AppLogger.info('🔄 Cleared existing transactions for fresh data');
        }

        final transactions = await _warehouseService.getWarehouseTransactions(
          warehouseId,
          limit: limit,
          offset: offset,
          transactionType: transactionType,
          startDate: startDate,
          endDate: endDate,
        );

        _transactions = transactions;

        // حفظ في التخزين المؤقت المحسن
        await WarehouseCacheService.saveWarehouseTransactions(warehouseId, transactions);

        AppLogger.info('✅ Loaded ${transactions.length} warehouse transactions for warehouse: $warehouseId');

        // Record database performance
        performanceTimer.stop();
        WarehousePerformanceValidator().recordPerformance(
          'warehouse_transactions_loading',
          performanceTimer.elapsedMilliseconds
        );

      } catch (e) {
        _error = 'خطأ في تحميل المعاملات: $e';
        AppLogger.error(_error!);

        // Record failed performance
        performanceTimer.stop();
        WarehousePerformanceValidator().recordPerformance(
          'warehouse_transactions_loading',
          performanceTimer.elapsedMilliseconds
        );
      } finally {
        WarehouseCacheService.markOperationComplete(operationKey);
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  /// تحميل جميع معاملات المخازن
  Future<void> loadAllWarehouseTransactions({
    int limit = 100,
    int offset = 0,
    String? transactionType,
    String? warehouseId,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('📋 Loading all warehouse transactions');

      final transactions = await _warehouseService.getAllWarehouseTransactions(
        limit: limit,
        offset: offset,
        transactionType: transactionType,
        warehouseId: warehouseId,
        startDate: startDate,
        endDate: endDate,
      );

      _transactions = transactions;

      AppLogger.info('✅ Loaded ${transactions.length} total warehouse transactions');
    } catch (e) {
      _error = 'خطأ في تحميل جميع المعاملات: $e';
      AppLogger.error(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// مسح جميع معاملات مخزن محدد
  Future<void> clearAllWarehouseTransactions(String warehouseId) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🗑️ Clearing all transactions for warehouse: $warehouseId');

      // Call the warehouse service to clear transactions
      await _warehouseService.clearAllWarehouseTransactions(warehouseId);

      // Clear local transactions if they belong to this warehouse
      if (_currentWarehouseId == warehouseId) {
        _transactions.clear();
      }

      // Clear cache for this warehouse
      await WarehouseCacheService.clearWarehouseTransactions(warehouseId);

      AppLogger.info('✅ Successfully cleared all transactions for warehouse: $warehouseId');
    } catch (e) {
      _error = 'خطأ في مسح المعاملات: $e';
      AppLogger.error(_error!);
      rethrow; // Re-throw to allow UI to handle the error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// إنشاء طلب سحب جديد
  Future<bool> createWarehouseRequest({
    required WarehouseRequestType type,
    required String requestedBy,
    required String warehouseId,
    String? targetWarehouseId,
    required String reason,
    String? notes,
    required List<WarehouseRequestItemModel> items,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('📋 جاري إنشاء طلب سحب جديد...');

      final request = await _warehouseService.createWarehouseRequest(
        type: type,
        requestedBy: requestedBy,
        warehouseId: warehouseId,
        targetWarehouseId: targetWarehouseId,
        reason: reason,
        notes: notes,
        items: items,
      );

      if (request != null) {
        _requests.insert(0, request); // إضافة في المقدمة
        AppLogger.info('✅ تم إنشاء طلب السحب بنجاح');
        return true;
      } else {
        _error = 'فشل في إنشاء طلب السحب';
        return false;
      }
    } catch (e) {
      _error = 'خطأ في إنشاء الطلب: $e';
      AppLogger.error(_error!);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== إدارة الإحصائيات ====================

  /// تحميل إحصائيات المخزن مع منع التكرار
  Future<void> loadWarehouseStatistics(String warehouseId, {bool forceRefresh = false}) async {
    final operationKey = 'statistics_$warehouseId';

    // منع العمليات المكررة
    if (WarehouseCacheService.isOperationPending(operationKey) && !forceRefresh) {
      AppLogger.info('⏳ إحصائيات المخزن $warehouseId قيد التحميل بالفعل');
      return;
    }

    // التحقق من التخزين المؤقت المحسن
    if (!forceRefresh) {
      final cachedStatistics = await WarehouseCacheService.loadWarehouseStatistics(warehouseId);
      if (cachedStatistics != null) {
        _statistics = cachedStatistics;
        _statisticsCache[warehouseId] = cachedStatistics;
        AppLogger.info('📊 استخدام الإحصائيات من التخزين المؤقت المحسن');
        notifyListeners();
        return;
      }
    }

    // تنفيذ العملية مع منع التكرار
    await WarehouseCacheService.preventDuplicateOperation(operationKey, () async {
      try {
        WarehouseCacheService.markOperationPending(operationKey);
        AppLogger.info('📊 جاري تحميل إحصائيات المخزن...');

        final statistics = await _warehouseService.getWarehouseStatistics(warehouseId);
        _statistics = statistics;
        _statisticsCache[warehouseId] = statistics;

        // حفظ في التخزين المؤقت المحسن
        await WarehouseCacheService.saveWarehouseStatistics(warehouseId, statistics);

        AppLogger.info('✅ تم تحميل إحصائيات المخزن بنجاح');
      } catch (e) {
        _error = 'خطأ في تحميل الإحصائيات: $e';
        AppLogger.error(_error!);
      } finally {
        WarehouseCacheService.markOperationComplete(operationKey);
        notifyListeners();
      }
    });
  }

  // ==================== مساعدات ====================

  /// التحقق من صحة التخزين المؤقت
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    final now = DateTime.now();
    final difference = now.difference(_lastCacheUpdate!);
    return difference.inMinutes < 5; // صالح لمدة 5 دقائق
  }

  /// مسح جميع البيانات المؤقتة
  void clearCache() {
    _inventoryCache.clear();
    _statisticsCache.clear();
    _lastCacheUpdate = null;
    AppLogger.info('🗑️ تم مسح التخزين المؤقت');
  }

  /// تحديث البيانات
  Future<void> refreshData() async {
    if (_selectedWarehouse != null) {
      await Future.wait([
        loadWarehouses(forceRefresh: true),
        loadWarehouseInventory(_selectedWarehouse!.id, forceRefresh: true),
        loadWarehouseRequests(warehouseId: _selectedWarehouse!.id, forceRefresh: true),
        loadWarehouseStatistics(_selectedWarehouse!.id, forceRefresh: true),
        loadWarehouseTransactions(_selectedWarehouse!.id, forceRefresh: true),
      ]);
    } else {
      await loadWarehouses(forceRefresh: true);
      await _loadAllWarehouseStatistics();
    }
  }

  /// تحديث بيانات مخزن معين مع تحسين الأداء ومنع التكرار
  Future<void> refreshWarehouseData(String warehouseId) async {
    AppLogger.info('🔄 Refreshing data for warehouse: $warehouseId');

    // منع التحديث المتكرر للمخزن نفسه
    final refreshKey = 'refresh_$warehouseId';
    if (WarehouseCacheService.isOperationPending(refreshKey)) {
      AppLogger.info('⏳ تحديث المخزن $warehouseId قيد التنفيذ بالفعل');
      return;
    }

    await WarehouseCacheService.preventDuplicateOperation(refreshKey, () async {
      try {
        WarehouseCacheService.markOperationPending(refreshKey);

        // مسح البيانات المؤقتة للمخزن المحدد
        _inventoryCache.remove(warehouseId);
        _statisticsCache.remove(warehouseId);
        await WarehouseCacheService.clearWarehouseCache(warehouseId);

        // إذا كان هذا مخزن مختلف، مسح المعاملات
        if (_currentWarehouseId != warehouseId) {
          _transactions.clear();
          _currentWarehouseId = warehouseId;
        }

        // تحميل البيانات الجديدة بشكل متوازي مع تحسين الأداء
        await Future.wait([
          loadWarehouseInventory(warehouseId, forceRefresh: true),
          loadWarehouseTransactions(warehouseId, forceRefresh: true),
          loadWarehouseStatistics(warehouseId, forceRefresh: true),
        ]);

        AppLogger.info('✅ Warehouse data refreshed successfully');
      } finally {
        WarehouseCacheService.markOperationComplete(refreshKey);
      }
    });
  }

  // ==================== إحصائيات المخازن ====================

  /// إحصائيات المخازن (عدد المنتجات والكمية الإجمالية)
  Map<String, Map<String, int>> _warehouseStatistics = {};

  /// الحصول على جميع إحصائيات المخازن
  Map<String, Map<String, int>> get warehouseStatistics => Map.unmodifiable(_warehouseStatistics);

  /// الحصول على إحصائيات مخزن معين
  Map<String, int> getWarehouseStatistics(String warehouseId) {
    return _warehouseStatistics[warehouseId] ?? {'productCount': 0, 'totalQuantity': 0, 'totalCartons': 0};
  }

  /// تحديث إحصائيات مخزن معين مع منع التكرار
  Future<void> _updateWarehouseStatistics(String warehouseId) async {
    final operationKey = 'update_stats_$warehouseId';

    // منع التحديث المتكرر لنفس المخزن
    if (WarehouseCacheService.isOperationPending(operationKey)) {
      AppLogger.info('⏳ تحديث إحصائيات المخزن $warehouseId قيد التنفيذ بالفعل');
      return;
    }

    await WarehouseCacheService.preventDuplicateOperation(operationKey, () async {
      try {
        WarehouseCacheService.markOperationPending(operationKey);
        AppLogger.info('📊 بدء تحديث إحصائيات المخزن: $warehouseId');

        final inventory = await _warehouseService.getWarehouseInventory(warehouseId);
        AppLogger.info('📦 تم تحميل ${inventory.length} عنصر من المخزون');

        final productCount = inventory.length;
        final totalQuantity = inventory.fold<int>(0, (sum, item) => sum + item.quantity);

        // حساب إجمالي الكراتين مع تسجيل تفصيلي
        int totalCartons = 0;
        for (final item in inventory) {
          final itemCartons = item.cartonsCount;
          totalCartons += itemCartons;
          AppLogger.info('🔍 منتج ${item.productId}: كمية=${item.quantity}, كمية/كرتونة=${item.quantityPerCarton}, كراتين=$itemCartons');
        }

        _warehouseStatistics[warehouseId] = {
          'productCount': productCount,
          'totalQuantity': totalQuantity,
          'totalCartons': totalCartons,
        };

        AppLogger.info('📊 تم تحديث إحصائيات المخزن $warehouseId: $productCount منتج، $totalQuantity كمية إجمالية، $totalCartons كرتونة');
        AppLogger.info('📊 الإحصائيات المحفوظة: ${_warehouseStatistics[warehouseId]}');

        // تحديث واحد للواجهة بدلاً من تحديثات متعددة
        notifyListeners();
      } catch (e) {
        AppLogger.error('❌ خطأ في تحديث إحصائيات المخزن: $e');
        AppLogger.error('❌ تفاصيل الخطأ: ${e.toString()}');
      } finally {
        WarehouseCacheService.markOperationComplete(operationKey);
      }
    });
  }

  /// تحميل إحصائيات جميع المخازن مع تحسين الأداء ومنع التكرار
  Future<void> _loadAllWarehouseStatistics() async {
    const operationKey = 'load_all_statistics';

    // منع التحميل المتكرر لجميع الإحصائيات
    if (WarehouseCacheService.isOperationPending(operationKey)) {
      AppLogger.info('⏳ تحميل إحصائيات جميع المخازن قيد التنفيذ بالفعل');
      return;
    }

    await WarehouseCacheService.preventDuplicateOperation(operationKey, () async {
      try {
        WarehouseCacheService.markOperationPending(operationKey);
        AppLogger.info('📊 جاري تحميل إحصائيات جميع المخازن...');

        // تحميل الإحصائيات بشكل متوازي لتحسين الأداء
        final futures = _warehouses.map((warehouse) =>
          _updateWarehouseStatistics(warehouse.id)
        ).toList();

        await Future.wait(futures);

        AppLogger.info('✅ تم تحميل إحصائيات ${_warehouses.length} مخزن');

        // تحديث واحد للواجهة بعد انتهاء جميع العمليات
        notifyListeners();
      } catch (e) {
        AppLogger.error('❌ خطأ في تحميل إحصائيات المخازن: $e');
      } finally {
        WarehouseCacheService.markOperationComplete(operationKey);
      }
    });
  }

  // ==================== Optimized State Management ====================

  /// Optimized loading state setter - only notifies if value changed
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Optimized warehouse loading state setter
  void _setLoadingWarehouses(bool loading) {
    if (_isLoadingWarehouses != loading) {
      _isLoadingWarehouses = loading;
      notifyListeners();
    }
  }

  /// Optimized inventory loading state setter
  void _setLoadingInventory(bool loading) {
    if (_isLoadingInventory != loading) {
      _isLoadingInventory = loading;
      notifyListeners();
    }
  }

  /// Optimized requests loading state setter
  void _setLoadingRequests(bool loading) {
    if (_isLoadingRequests != loading) {
      _isLoadingRequests = loading;
      notifyListeners();
    }
  }

  /// Optimized error state setter - only notifies if value changed
  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  /// Batch state update to reduce rebuilds
  void _batchStateUpdate({
    bool? loading,
    bool? loadingWarehouses,
    bool? loadingInventory,
    bool? loadingRequests,
    String? error,
  }) {
    bool shouldNotify = false;

    if (loading != null && _isLoading != loading) {
      _isLoading = loading;
      shouldNotify = true;
    }

    if (loadingWarehouses != null && _isLoadingWarehouses != loadingWarehouses) {
      _isLoadingWarehouses = loadingWarehouses;
      shouldNotify = true;
    }

    if (loadingInventory != null && _isLoadingInventory != loadingInventory) {
      _isLoadingInventory = loadingInventory;
      shouldNotify = true;
    }

    if (loadingRequests != null && _isLoadingRequests != loadingRequests) {
      _isLoadingRequests = loadingRequests;
      shouldNotify = true;
    }

    if (error != _error) {
      _error = error;
      shouldNotify = true;
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}
