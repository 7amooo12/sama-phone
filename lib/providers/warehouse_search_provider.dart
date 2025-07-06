/// مزود البحث في المخازن
/// Provider for warehouse search functionality

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/models/warehouse_search_models.dart';
import 'package:smartbiztracker_new/services/warehouse_search_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class WarehouseSearchProvider with ChangeNotifier {
  final WarehouseSearchService _searchService;

  // حالة البحث
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  String _searchQuery = '';
  
  // نتائج البحث
  WarehouseSearchResults? _searchResults;
  List<String> _accessibleWarehouseIds = [];
  
  // ذاكرة التخزين المؤقت
  final Map<String, WarehouseSearchResults> _searchCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  // التحكم في التأخير (Debouncing)
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  
  // التصفح (Pagination)
  int _currentPage = 1;
  bool _hasMore = false;
  bool _isLoadingMore = false;

  WarehouseSearchProvider({WarehouseSearchService? searchService})
      : _searchService = searchService ?? WarehouseSearchService();

  // Getters
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  WarehouseSearchResults? get searchResults => _searchResults;
  List<String> get accessibleWarehouseIds => _accessibleWarehouseIds;
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;
  bool get hasResults => _searchResults?.isNotEmpty ?? false;
  bool get isEmpty => _searchResults?.isEmpty ?? true;

  /// تهيئة المزود
  Future<void> initialize(String userId) async {
    try {
      _setLoading(true);
      _clearError();

      AppLogger.info('🔄 تهيئة مزود البحث في المخازن للمستخدم: $userId');

      // جلب المخازن المتاحة
      _accessibleWarehouseIds = await _searchService.getAccessibleWarehouseIds(userId);
      
      AppLogger.info('✅ تم تهيئة مزود البحث مع ${_accessibleWarehouseIds.length} مخزن');
    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة مزود البحث: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// تعيين استعلام البحث مع التأخير
  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    
    // إلغاء المؤقت السابق
    _debounceTimer?.cancel();
    
    if (_searchQuery.isEmpty) {
      _clearSearchResults();
      return;
    }

    if (_searchQuery.length < 2) {
      AppLogger.info('⚠️ استعلام البحث قصير جداً: ${_searchQuery.length} أحرف');
      return;
    }

    // تعيين مؤقت جديد
    _debounceTimer = Timer(_debounceDelay, () {
      _performSearch();
    });
  }

  /// تنفيذ البحث فوراً (بدون تأخير)
  Future<void> searchImmediately() async {
    _debounceTimer?.cancel();
    await _performSearch();
  }

  /// تنفيذ البحث
  Future<void> _performSearch({bool loadMore = false}) async {
    if (_accessibleWarehouseIds.isEmpty) {
      AppLogger.warning('⚠️ لا توجد مخازن متاحة للبحث');
      return;
    }

    try {
      if (loadMore) {
        _setLoadingMore(true);
      } else {
        _setSearching(true);
        _currentPage = 1;
      }
      
      _clearError();

      // التحقق من ذاكرة التخزين المؤقت
      final cacheKey = '${_searchQuery}_${_currentPage}';
      if (!loadMore && _isCacheValid(cacheKey)) {
        AppLogger.info('📋 استخدام النتائج المخزنة مؤقتاً للاستعلام: $_searchQuery');
        _searchResults = _searchCache[cacheKey];
        notifyListeners();
        return;
      }

      AppLogger.info('🔍 تنفيذ البحث: "$_searchQuery" (صفحة $_currentPage)');

      final results = await _searchService.searchProductsAndCategories(
        query: _searchQuery,
        accessibleWarehouseIds: _accessibleWarehouseIds,
        page: _currentPage,
        limit: 20,
      );

      if (loadMore && _searchResults != null) {
        // دمج النتائج الجديدة مع الموجودة
        final combinedProductResults = [
          ..._searchResults!.productResults,
          ...results.productResults,
        ];
        
        final combinedCategoryResults = [
          ..._searchResults!.categoryResults,
          ...results.categoryResults,
        ];

        _searchResults = WarehouseSearchResults(
          searchQuery: results.searchQuery,
          productResults: combinedProductResults,
          categoryResults: combinedCategoryResults,
          totalResults: combinedProductResults.length + combinedCategoryResults.length,
          searchDuration: results.searchDuration,
          searchTime: results.searchTime,
          hasMore: results.hasMore,
          currentPage: _currentPage,
        );
      } else {
        _searchResults = results;
      }

      _hasMore = results.hasMore;

      // حفظ في ذاكرة التخزين المؤقت
      if (!loadMore) {
        _searchCache[cacheKey] = results;
        _cacheTimestamps[cacheKey] = DateTime.now();
      }

      AppLogger.info('✅ اكتمل البحث: ${_searchResults!.totalResults} نتيجة');
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث: $e');
      _setError(e.toString());
    } finally {
      if (loadMore) {
        _setLoadingMore(false);
      } else {
        _setSearching(false);
      }
    }
  }

  /// تحميل المزيد من النتائج
  Future<void> loadMoreResults() async {
    if (_isLoadingMore || !_hasMore || _searchQuery.isEmpty) return;

    _currentPage++;
    await _performSearch(loadMore: true);
  }

  /// إعادة تنفيذ البحث
  Future<void> refreshSearch() async {
    if (_searchQuery.isEmpty) return;

    // مسح ذاكرة التخزين المؤقت للاستعلام الحالي
    final cacheKey = '${_searchQuery}_1';
    _searchCache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);

    _currentPage = 1;
    await _performSearch();
  }

  /// مسح نتائج البحث
  void _clearSearchResults() {
    _searchResults = null;
    _currentPage = 1;
    _hasMore = false;
    _clearError();
    notifyListeners();
  }

  /// التحقق من صحة ذاكرة التخزين المؤقت
  bool _isCacheValid(String cacheKey) {
    if (!_searchCache.containsKey(cacheKey) || !_cacheTimestamps.containsKey(cacheKey)) {
      return false;
    }

    final cacheTime = _cacheTimestamps[cacheKey]!;
    final now = DateTime.now();
    return now.difference(cacheTime) < _cacheTimeout;
  }

  /// مسح ذاكرة التخزين المؤقت
  void clearCache() {
    _searchCache.clear();
    _cacheTimestamps.clear();
    _searchService.clearSearchCache();
    AppLogger.info('🧹 تم مسح ذاكرة التخزين المؤقت للبحث');
  }

  /// مسح ذاكرة التخزين المؤقت المنتهية الصلاحية
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) >= _cacheTimeout) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _searchCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      AppLogger.info('🧹 تم مسح ${expiredKeys.length} عنصر منتهي الصلاحية من ذاكرة التخزين المؤقت');
    }
  }

  /// تعيين حالة التحميل
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// تعيين حالة البحث
  void _setSearching(bool searching) {
    _isSearching = searching;
    notifyListeners();
  }

  /// تعيين حالة تحميل المزيد
  void _setLoadingMore(bool loadingMore) {
    _isLoadingMore = loadingMore;
    notifyListeners();
  }

  /// تعيين خطأ
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// مسح الخطأ
  void _clearError() {
    _error = null;
  }

  /// إعادة تعيين المزود
  void reset() {
    _debounceTimer?.cancel();
    _searchQuery = '';
    _searchResults = null;
    _accessibleWarehouseIds.clear();
    _currentPage = 1;
    _hasMore = false;
    _isLoading = false;
    _isSearching = false;
    _isLoadingMore = false;
    _error = null;
    clearCache();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    reset();
    super.dispose();
  }
}
