import 'package:flutter/foundation.dart';
import '../models/global_inventory_models.dart';
import '../services/global_inventory_service.dart';
import '../services/automated_withdrawal_service.dart';
import '../utils/app_logger.dart';

/// مزود إدارة المخزون العالمي والسحب التلقائي
class GlobalInventoryProvider with ChangeNotifier {
  final GlobalInventoryService _globalInventoryService = GlobalInventoryService();
  final AutomatedWithdrawalService _withdrawalService = AutomatedWithdrawalService();

  // حالة البحث العالمي
  bool _isSearching = false;
  GlobalInventorySearchResult? _lastSearchResult;
  String? _searchError;

  // حالة معالجة السحب
  bool _isProcessingWithdrawal = false;
  WithdrawalProcessingResult? _lastProcessingResult;
  String? _processingError;

  // إعدادات البحث
  GlobalSearchSettings _searchSettings = const GlobalSearchSettings();

  // تخزين مؤقت للنتائج
  final Map<String, GlobalInventorySearchResult> _searchCache = {};
  final Map<String, ProductGlobalInventorySummary> _summaryCache = {};
  DateTime? _lastCacheUpdate;

  // Getters
  bool get isSearching => _isSearching;
  bool get isProcessingWithdrawal => _isProcessingWithdrawal;
  GlobalInventorySearchResult? get lastSearchResult => _lastSearchResult;
  WithdrawalProcessingResult? get lastProcessingResult => _lastProcessingResult;
  String? get searchError => _searchError;
  String? get processingError => _processingError;
  GlobalSearchSettings get searchSettings => _searchSettings;

  /// البحث العالمي عن منتج
  Future<GlobalInventorySearchResult> searchProductGlobally({
    required String productId,
    required int requestedQuantity,
    List<String>? excludeWarehouses,
    WarehouseSelectionStrategy? strategy,
    bool useCache = true,
  }) async {
    final cacheKey = '$productId-$requestedQuantity-${strategy?.toString() ?? 'default'}';
    
    // التحقق من التخزين المؤقت
    if (useCache && _searchCache.containsKey(cacheKey) && _isCacheValid()) {
      _lastSearchResult = _searchCache[cacheKey];
      AppLogger.info('📦 استخدام نتيجة البحث من التخزين المؤقت');
      notifyListeners();
      return _lastSearchResult!;
    }

    _isSearching = true;
    _searchError = null;
    notifyListeners();

    try {
      AppLogger.info('🔍 بدء البحث العالمي: $productId، الكمية: $requestedQuantity');

      final result = await _globalInventoryService.searchProductGlobally(
        productId: productId,
        requestedQuantity: requestedQuantity,
        excludeWarehouses: excludeWarehouses,
        strategy: strategy ?? _searchSettings.defaultStrategy,
      );

      _lastSearchResult = result;
      _searchCache[cacheKey] = result;
      _lastCacheUpdate = DateTime.now();

      AppLogger.info('✅ نتائج البحث العالمي: ${result.summaryText}');
      return result;
    } catch (e) {
      _searchError = 'فشل في البحث العالمي: $e';
      AppLogger.error('❌ $_searchError');
      rethrow;
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// البحث عن منتجات متعددة
  Future<Map<String, GlobalInventorySearchResult>> searchMultipleProducts({
    required Map<String, int> productQuantities,
    WarehouseSelectionStrategy? strategy,
  }) async {
    _isSearching = true;
    _searchError = null;
    notifyListeners();

    try {
      AppLogger.info('🔍 بدء البحث العالمي لمنتجات متعددة: ${productQuantities.length}');

      final results = await _globalInventoryService.searchMultipleProductsGlobally(
        productQuantities: productQuantities,
        strategy: strategy ?? _searchSettings.defaultStrategy,
      );

      // تحديث التخزين المؤقت
      for (final entry in results.entries) {
        final cacheKey = '${entry.key}-${productQuantities[entry.key]}-${strategy?.toString() ?? 'default'}';
        _searchCache[cacheKey] = entry.value;
      }
      _lastCacheUpdate = DateTime.now();

      AppLogger.info('✅ تم البحث عن ${results.length} منتج');
      return results;
    } catch (e) {
      _searchError = 'فشل في البحث عن المنتجات المتعددة: $e';
      AppLogger.error('❌ $_searchError');
      rethrow;
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// معالجة طلب سحب تلقائياً
  Future<WithdrawalProcessingResult> processWithdrawalRequest({
    required String requestId,
    required String performedBy,
    WarehouseSelectionStrategy? strategy,
  }) async {
    _isProcessingWithdrawal = true;
    _processingError = null;
    notifyListeners();

    try {
      AppLogger.info('🔄 بدء معالجة طلب السحب: $requestId');

      final result = await _withdrawalService.processWithdrawalRequest(
        requestId: requestId,
        performedBy: performedBy,
        strategy: strategy ?? _searchSettings.defaultStrategy,
      );

      _lastProcessingResult = result;

      AppLogger.info('✅ نتائج معالجة الطلب: ${result.summaryText}');
      
      // تنظيف التخزين المؤقت بعد المعالجة الناجحة
      if (result.success) {
        _clearSearchCache();
      }

      return result;
    } catch (e) {
      _processingError = 'فشل في معالجة طلب السحب: $e';
      AppLogger.error('❌ $_processingError');
      rethrow;
    } finally {
      _isProcessingWithdrawal = false;
      notifyListeners();
    }
  }

  /// التحقق من إمكانية تلبية طلب سحب
  Future<WithdrawalFeasibilityCheck> checkWithdrawalFeasibility({
    required String requestId,
    WarehouseSelectionStrategy? strategy,
  }) async {
    try {
      AppLogger.info('🔍 التحقق من إمكانية تلبية طلب السحب: $requestId');

      final result = await _withdrawalService.checkWithdrawalFeasibility(
        requestId: requestId,
        strategy: strategy ?? _searchSettings.defaultStrategy,
      );

      AppLogger.info('✅ نتائج فحص الإمكانية: ${result.overallFeasible ? "قابل للتلبية" : "غير قابل للتلبية"}');
      return result;
    } catch (e) {
      AppLogger.error('❌ خطأ في فحص إمكانية التلبية: $e');
      rethrow;
    }
  }

  /// الحصول على ملخص المخزون العالمي لمنتج
  Future<ProductGlobalInventorySummary> getProductGlobalSummary({
    required String productId,
    bool useCache = true,
  }) async {
    // التحقق من التخزين المؤقت
    if (useCache && _summaryCache.containsKey(productId) && _isCacheValid()) {
      AppLogger.info('📊 استخدام ملخص المخزون من التخزين المؤقت');
      return _summaryCache[productId]!;
    }

    try {
      AppLogger.info('📊 جاري الحصول على ملخص المخزون العالمي: $productId');

      final summary = await _globalInventoryService.getProductGlobalSummary(productId);
      _summaryCache[productId] = summary;
      _lastCacheUpdate = DateTime.now();

      AppLogger.info('✅ ملخص المخزون: ${summary.totalAvailableQuantity} في ${summary.warehousesWithStock} مخزن');
      return summary;
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على ملخص المخزون: $e');
      rethrow;
    }
  }

  /// معالجة طلبات السحب المكتملة تلقائياً
  Future<List<WithdrawalProcessingResult>> processCompletedWithdrawals({
    WarehouseSelectionStrategy? strategy,
    int? limit,
  }) async {
    try {
      AppLogger.info('🔄 معالجة طلبات السحب المكتملة تلقائياً');

      final results = await _withdrawalService.processCompletedWithdrawals(
        strategy: strategy ?? _searchSettings.defaultStrategy,
        limit: limit,
      );

      if (results.isNotEmpty) {
        _clearSearchCache(); // تنظيف التخزين المؤقت بعد المعالجة
        notifyListeners();
      }

      AppLogger.info('✅ تم معالجة ${results.length} طلب سحب تلقائياً');
      return results;
    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة طلبات السحب المكتملة: $e');
      rethrow;
    }
  }

  /// تحديث إعدادات البحث
  void updateSearchSettings(GlobalSearchSettings settings) {
    _searchSettings = settings;
    _clearSearchCache(); // تنظيف التخزين المؤقت عند تغيير الإعدادات
    notifyListeners();
    AppLogger.info('⚙️ تم تحديث إعدادات البحث العالمي');
  }

  /// تنظيف التخزين المؤقت
  void _clearSearchCache() {
    _searchCache.clear();
    _summaryCache.clear();
    _lastCacheUpdate = null;
    AppLogger.info('🧹 تم تنظيف التخزين المؤقت للبحث العالمي');
  }

  /// التحقق من صحة التخزين المؤقت
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    final cacheAge = DateTime.now().difference(_lastCacheUpdate!);
    return cacheAge.inMinutes < 5; // صالح لمدة 5 دقائق
  }

  /// تحديث التخزين المؤقت يدوياً
  void refreshCache() {
    _clearSearchCache();
    notifyListeners();
    AppLogger.info('🔄 تم تحديث التخزين المؤقت يدوياً');
  }

  /// الحصول على إحصائيات الأداء
  Map<String, dynamic> getPerformanceStats() {
    return {
      'cache_size': _searchCache.length + _summaryCache.length,
      'last_cache_update': _lastCacheUpdate?.toIso8601String(),
      'cache_valid': _isCacheValid(),
      'is_searching': _isSearching,
      'is_processing': _isProcessingWithdrawal,
      'last_search_result': _lastSearchResult != null,
      'last_processing_result': _lastProcessingResult != null,
      'search_settings': {
        'default_strategy': _searchSettings.defaultStrategy.toString(),
        'respect_minimum_stock': _searchSettings.respectMinimumStock,
        'allow_partial_fulfillment': _searchSettings.allowPartialFulfillment,
        'max_warehouses_per_request': _searchSettings.maxWarehousesPerRequest,
      },
    };
  }

  /// تنظيف الموارد
  @override
  void dispose() {
    _clearSearchCache();
    super.dispose();
  }

  /// إعادة تعيين حالة الأخطاء
  void clearErrors() {
    _searchError = null;
    _processingError = null;
    notifyListeners();
  }

  /// الحصول على نتائج البحث المخزنة مؤقتاً
  List<GlobalInventorySearchResult> getCachedSearchResults() {
    return _searchCache.values.toList();
  }

  /// الحصول على ملخصات المخزون المخزنة مؤقتاً
  List<ProductGlobalInventorySummary> getCachedSummaries() {
    return _summaryCache.values.toList();
  }

  /// التحقق من توفر منتج بسرعة (من التخزين المؤقت)
  bool? isProductAvailableQuick(String productId, int quantity) {
    final cachedResults = _searchCache.entries.where((entry) => 
      entry.key.startsWith(productId) && entry.value.requestedQuantity >= quantity
    );

    if (cachedResults.isNotEmpty) {
      return cachedResults.first.value.canFulfill;
    }

    final summary = _summaryCache[productId];
    if (summary != null) {
      return summary.totalAvailableQuantity >= quantity;
    }

    return null; // غير متاح في التخزين المؤقت
  }
}
