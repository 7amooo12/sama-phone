import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/unified_products_service.dart';
import '../utils/app_logger.dart';

/// مزود المنتجات المبسط - يستخدم خدمة واحدة فقط لجلب المنتجات
/// هذا هو المزود الوحيد المعتمد لجلب المنتجات في التطبيق
class SimplifiedProductProvider with ChangeNotifier {
  final UnifiedProductsService _productsService = UnifiedProductsService();

  List<ProductModel> _products = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetchTime;
  bool _hasNetworkError = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  /// الحصول على قائمة المنتجات
  List<ProductModel> get products => _products;

  /// حالة التحميل
  bool get isLoading => _isLoading;

  /// رسالة الخطأ إن وجدت
  String? get error => _error;

  /// وقت آخر جلب للمنتجات
  DateTime? get lastFetchTime => _lastFetchTime;

  /// عدد المنتجات
  int get productsCount => _products.length;

  /// هل يوجد خطأ في الشبكة
  bool get hasNetworkError => _hasNetworkError;

  /// عدد محاولات إعادة الاتصال
  int get retryCount => _retryCount;

  /// تحديث حالة التحميل
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// تحديث رسالة الخطأ
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// تحديث حالة خطأ الشبكة
  void _setNetworkError(bool hasError) {
    _hasNetworkError = hasError;
    notifyListeners();
  }

  /// الطريقة الوحيدة لجلب المنتجات مع تحسينات الأداء
  /// هذه هي الطريقة المعتمدة الوحيدة في التطبيق
  Future<List<ProductModel>> loadProducts({bool forceRefresh = false}) async {
    // Prevent concurrent loading operations
    if (_isLoading) {
      AppLogger.info('📦 تحميل المنتجات قيد التنفيذ، انتظار النتيجة...');
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _products;
    }

    try {
      // Check cache validity with time-based expiration
      final now = DateTime.now();
      final cacheAge = _lastFetchTime != null ? now.difference(_lastFetchTime!) : null;
      final isCacheValid = cacheAge != null && cacheAge.inMinutes < 5; // 5-minute cache

      // إذا كانت المنتجات موجودة وليس مطلوب تحديث قسري، أرجعها
      if (_products.isNotEmpty && !forceRefresh && isCacheValid) {
        AppLogger.info('📦 استخدام المنتجات المخزنة (${_products.length} منتج) - عمر الكاش: ${cacheAge?.inMinutes} دقيقة');
        return _products;
      }

      AppLogger.info('🔄 بدء تحميل المنتجات...');
      final stopwatch = Stopwatch()..start();

      _setLoading(true);
      _setError(null);

      // جلب المنتجات من الخدمة الموحدة مع timeout
      final products = await _productsService.getProducts().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('انتهت مهلة تحميل المنتجات');
        },
      );

      // تحديث البيانات
      _products = products;
      _lastFetchTime = DateTime.now();
      _retryCount = 0; // Reset retry count on success

      stopwatch.stop();
      AppLogger.info('✅ تم تحميل ${products.length} منتج بنجاح في ${stopwatch.elapsedMilliseconds}ms');

      _setLoading(false);
      notifyListeners();

      return products;
    } catch (e) {
      AppLogger.error('❌ فشل في تحميل المنتجات: $e');

      _setLoading(false);
      _setError(_getErrorMessage(e.toString()));
      _setNetworkError(_isNetworkError(e.toString()));
      _retryCount++;

      // إرجاع المنتجات المخزنة إذا كانت موجودة
      return _products;
    }
  }

  /// تحديد نوع الخطأ وإرجاع رسالة مناسبة
  String _getErrorMessage(String error) {
    if (error.contains('Failed host lookup') || error.contains('No address associated with hostname')) {
      return 'لا يمكن الاتصال بالخادم. تحقق من اتصالك بالإنترنت';
    } else if (error.contains('Connection refused') || error.contains('Connection timed out')) {
      return 'انتهت مهلة الاتصال. يرجى المحاولة لاحقاً';
    } else if (error.contains('SocketException')) {
      return 'خطأ في الشبكة. تحقق من اتصالك بالإنترنت';
    } else if (error.contains('TimeoutException')) {
      return 'انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى';
    } else {
      return 'حدث خطأ في تحميل المنتجات. يرجى المحاولة مرة أخرى';
    }
  }

  /// التحقق من كون الخطأ متعلق بالشبكة
  bool _isNetworkError(String error) {
    return error.contains('Failed host lookup') ||
           error.contains('No address associated with hostname') ||
           error.contains('Connection refused') ||
           error.contains('Connection timed out') ||
           error.contains('SocketException') ||
           error.contains('TimeoutException');
  }

  /// إعادة المحاولة مع تأخير تدريجي
  Future<List<ProductModel>> retryWithBackoff() async {
    if (_retryCount >= _maxRetries) {
      AppLogger.warning('⚠️ تم الوصول للحد الأقصى من المحاولات');
      return _products;
    }

    // تأخير تدريجي: 2^retryCount ثواني
    final delaySeconds = (2 << _retryCount).clamp(2, 30);
    AppLogger.info('⏳ إعادة المحاولة بعد $delaySeconds ثانية...');

    await Future.delayed(Duration(seconds: delaySeconds));
    return loadProducts(forceRefresh: true);
  }

  /// البحث في المنتجات المحلية
  List<ProductModel> searchProducts(String query) {
    if (query.isEmpty) {
      return _products;
    }

    final lowerQuery = query.toLowerCase();
    return _products.where((product) {
      return product.name.toLowerCase().contains(lowerQuery) ||
             product.description.toLowerCase().contains(lowerQuery) ||
             product.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// فلترة المنتجات حسب التصنيف
  List<ProductModel> filterByCategory(String? category) {
    if (category == null || category.isEmpty || category == 'All') {
      return _products;
    }

    return _products.where((product) {
      return product.category.toLowerCase() == category.toLowerCase();
    }).toList();
  }

  /// فلترة المنتجات حسب النطاق السعري
  List<ProductModel> filterByPriceRange(double minPrice, double maxPrice) {
    return _products.where((product) {
      return product.price >= minPrice && product.price <= maxPrice;
    }).toList();
  }

  /// الحصول على التصنيفات المتاحة
  List<String> getAvailableCategories() {
    final categories = _products.map((product) => product.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  /// الحصول على منتج بالمعرف
  ProductModel? getProductById(String id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  /// مسح رسالة الخطأ
  void clearError() {
    _setError(null);
  }

  /// تهيئة المزود - يتم استدعاؤها عند إنشاء المزود
  Future<void> initialize() async {
    if (_products.isEmpty) {
      AppLogger.info('🚀 تهيئة مزود المنتجات...');
      await loadProducts(forceRefresh: true);
    }
  }

  /// مسح جميع البيانات
  void clearData() {
    _products.clear();
    _lastFetchTime = null;
    _setError(null);
    notifyListeners();
  }

  /// إعادة المحاولة في حالة الخطأ
  Future<List<ProductModel>> retry() async {
    return loadProducts(forceRefresh: true);
  }

  /// تنظيف الموارد
  @override
  void dispose() {
    _productsService.dispose();
    super.dispose();
  }
}
