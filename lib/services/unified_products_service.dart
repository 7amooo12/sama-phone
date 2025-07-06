import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/utils/network_utils.dart';

/// خدمة موحدة لجلب المنتجات من API واحد فقط
/// هذه هي الطريقة الوحيدة المعتمدة لجلب المنتجات في التطبيق
class UnifiedProductsService {

  UnifiedProductsService({http.Client? client}) : _client = client ?? http.Client();
  static const String _baseUrl = 'https://samastock.pythonanywhere.com';
  static const String _fallbackUrl = 'https://stockwarehouse.pythonanywhere.com';
  static const String _apiEndpoint = '/flutter/api/api/products';
  static const String _apiKey = 'lux2025FlutterAccess';
  static const String _fallbackApiKey = 'flutterSmartOrder2025Key';
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _shortTimeout = Duration(seconds: 10);

  final http.Client _client;
  List<ProductModel> _cachedProducts = [];
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// الطريقة الوحيدة لجلب المنتجات مع تحسينات الأداء
  /// هذه هي الطريقة المعتمدة الوحيدة في التطبيق
  Future<List<ProductModel>> getProducts() async {
    // Check if we have valid cached data first
    if (_isCacheValid()) {
      AppLogger.info('📦 إرجاع المنتجات من الكاش المحلي (${_cachedProducts.length} منتج)');
      return _cachedProducts;
    }

    try {
      AppLogger.info('🔄 بدء جلب المنتجات من API الموحد');
      final stopwatch = Stopwatch()..start();

      // Check network connectivity first with timeout
      final hasNetwork = await NetworkUtils.hasInternetConnection().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      if (!hasNetwork) {
        AppLogger.warning('⚠️ لا يوجد اتصال بالإنترنت');
        if (_cachedProducts.isNotEmpty) {
          AppLogger.info('📦 إرجاع البيانات المحفوظة - لا يوجد اتصال');
          return _cachedProducts;
        }
        throw Exception('لا يوجد اتصال بالإنترنت ولا توجد بيانات محفوظة');
      }

      // Try primary server first with performance monitoring
      final products = await _fetchFromPrimaryServer();
      if (products.isNotEmpty) {
        _updateCache(products);
        stopwatch.stop();
        AppLogger.info('✅ تم جلب ${products.length} منتج من الخادم الأساسي في ${stopwatch.elapsedMilliseconds}ms');
        return products;
      }

      // If primary fails, try fallback server
      AppLogger.warning('⚠️ الخادم الأساسي فشل، جاري المحاولة مع الخادم البديل');
      final fallbackProducts = await _fetchFromFallbackServer();
      if (fallbackProducts.isNotEmpty) {
        _updateCache(fallbackProducts);
        stopwatch.stop();
        AppLogger.info('✅ تم جلب ${fallbackProducts.length} منتج من الخادم البديل في ${stopwatch.elapsedMilliseconds}ms');
        return fallbackProducts;
      }

      // If both servers fail, return cached data if available
      if (_cachedProducts.isNotEmpty) {
        stopwatch.stop();
        AppLogger.warning('⚠️ كلا الخادمين فشل، إرجاع البيانات المحفوظة (${_cachedProducts.length} منتج)');
        return _cachedProducts;
      }

      // If no cached data, return empty list with error
      stopwatch.stop();
      throw Exception('فشل في الاتصال بجميع الخوادم ولا توجد بيانات محفوظة');
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب المنتجات: $e');

      // Return cached data if available, otherwise rethrow
      if (_cachedProducts.isNotEmpty) {
        AppLogger.info('📦 إرجاع البيانات المحفوظة بسبب الخطأ (${_cachedProducts.length} منتج)');
        return _cachedProducts;
      }

      rethrow;
    }
  }

  /// Check if cached data is still valid
  bool _isCacheValid() {
    if (_cachedProducts.isEmpty || _lastCacheTime == null) {
      return false;
    }

    final now = DateTime.now();
    final cacheAge = now.difference(_lastCacheTime!);
    return cacheAge < _cacheValidDuration;
  }

  /// Update the local cache
  void _updateCache(List<ProductModel> products) {
    _cachedProducts = products;
    _lastCacheTime = DateTime.now();
    AppLogger.info('📦 تم تحديث الكاش بـ ${products.length} منتج');
  }

  /// Fetch products from primary server
  Future<List<ProductModel>> _fetchFromPrimaryServer() async {
    try {
      const url = '$_baseUrl$_apiEndpoint';
      AppLogger.info('📡 الاتصال بالخادم الأساسي: $url');

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-api-key': _apiKey,
        },
      ).timeout(_shortTimeout);

      AppLogger.info('📊 رمز الاستجابة من الخادم الأساسي: ${response.statusCode}');

      if (response.statusCode == 200) {
        return await _parseProductsResponse(response.body);
      } else {
        throw _createHttpException(response.statusCode, response.body);
      }
    } catch (e) {
      AppLogger.warning('⚠️ فشل الخادم الأساسي: $e');
      return [];
    }
  }

  /// Fetch products from fallback server
  Future<List<ProductModel>> _fetchFromFallbackServer() async {
    try {
      const url = '$_fallbackUrl$_apiEndpoint';
      AppLogger.info('📡 الاتصال بالخادم البديل: $url');

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-api-key': _fallbackApiKey,
        },
      ).timeout(_shortTimeout);

      AppLogger.info('📊 رمز الاستجابة من الخادم البديل: ${response.statusCode}');

      if (response.statusCode == 200) {
        return await _parseProductsResponse(response.body);
      } else {
        throw _createHttpException(response.statusCode, response.body);
      }
    } catch (e) {
      AppLogger.warning('⚠️ فشل الخادم البديل: $e');
      return [];
    }
  }

  /// تحليل استجابة API وتحويلها إلى قائمة منتجات مع تحسينات الأداء
  Future<List<ProductModel>> _parseProductsResponse(String responseBody) async {
    try {
      final stopwatch = Stopwatch()..start();
      AppLogger.info('📄 تحليل استجابة API - حجم البيانات: ${responseBody.length} بايت');

      // Optimize JSON parsing for large responses
      final data = json.decode(responseBody);

      if (data is! Map<String, dynamic>) {
        throw Exception('تنسيق استجابة غير متوقع: ليس Map');
      }

      if (!data.containsKey('products')) {
        throw Exception('لا توجد مفتاح "products" في الاستجابة');
      }

      final productsList = data['products'];
      if (productsList is! List) {
        throw Exception('مفتاح "products" ليس قائمة');
      }

      AppLogger.info('📦 تم العثور على ${productsList.length} منتج في الاستجابة');

      // Optimize product parsing with batch processing
      final products = <ProductModel>[];
      int successCount = 0;
      int errorCount = 0;

      // Process in batches to prevent memory spikes
      const batchSize = 50;
      for (int batchStart = 0; batchStart < productsList.length; batchStart += batchSize) {
        final batchEnd = (batchStart + batchSize).clamp(0, productsList.length);
        final batch = productsList.sublist(batchStart, batchEnd);

        for (int i = 0; i < batch.length; i++) {
          try {
            final productData = batch[i];
            if (productData is Map<String, dynamic>) {
              // Reduce logging for performance
              if (successCount < 3) { // Log only first 3 products
                AppLogger.info('🖼️ منتج $successCount - imageUrl: ${productData['imageUrl']}');
              }

              final product = ProductModel.fromJson(productData);
              products.add(product);
              successCount++;
            } else {
              if (errorCount < 5) { // Limit error logging
                AppLogger.warning('⚠️ عنصر المنتج رقم ${batchStart + i} ليس Map صحيح');
              }
              errorCount++;
            }
          } catch (e) {
            if (errorCount < 5) { // Limit error logging
              AppLogger.error('❌ خطأ في تحويل المنتج رقم ${batchStart + i}: $e');
            }
            errorCount++;
          }
        }

        // Allow other operations to run between batches
        if (batchEnd < productsList.length) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      stopwatch.stop();
      AppLogger.info('✅ تم تحويل $successCount منتج بنجاح، فشل في $errorCount منتج في ${stopwatch.elapsedMilliseconds}ms');

      if (products.isEmpty && productsList.isNotEmpty) {
        throw Exception('فشل في تحويل جميع المنتجات من الاستجابة');
      }

      return products;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحليل استجابة المنتجات: $e');
      throw Exception('خطأ في تحليل البيانات: $e');
    }
  }

  /// إنشاء استثناء مناسب حسب رمز HTTP
  Exception _createHttpException(int statusCode, String responseBody) {
    switch (statusCode) {
      case 401:
        return Exception('غير مصرح بالوصول - تحقق من مفتاح API');
      case 403:
        return Exception('ممنوع الوصول - ليس لديك صلاحية');
      case 404:
        return Exception('نقطة النهاية غير موجودة - تحقق من عنوان API');
      case 429:
        return Exception('تم تجاوز حد الطلبات - حاول مرة أخرى لاحقاً');
      case 500:
      case 502:
      case 503:
      case 504:
        return Exception('خطأ في الخادم - حاول مرة أخرى لاحقاً');
      default:
        return Exception('فشل في تحميل المنتجات - رمز الخطأ: $statusCode');
    }
  }

  /// جلب منتج واحد بالمعرف
  Future<ProductModel?> getProductById(String productId) async {
    try {
      final products = await getProducts();
      return products.where((p) => p.id == productId).firstOrNull;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب المنتج بالمعرف $productId: $e');
      return null;
    }
  }

  /// جلب التصنيفات
  Future<List<String>> getCategories() async {
    try {
      final products = await getProducts();
      final categories = products
          .map((p) => p.category)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      return categories;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب التصنيفات: $e');
      return [];
    }
  }

  /// البحث في المنتجات
  Future<List<ProductModel>> searchProducts(String query) async {
    try {
      final products = await getProducts();
      if (query.isEmpty) return products;

      return products.where((p) =>
        p.name.toLowerCase().contains(query.toLowerCase()) ||
        p.description.toLowerCase().contains(query.toLowerCase()) ||
        p.category.toLowerCase().contains(query.toLowerCase())
      ).toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن المنتجات: $e');
      return [];
    }
  }

  /// حذف منتج (مؤقت - يحتاج تنفيذ API)
  Future<void> deleteProduct(String productId) async {
    try {
      AppLogger.info('🗑️ محاولة حذف المنتج: $productId');
      // TODO: تنفيذ حذف المنتج عبر API
      throw UnimplementedError('حذف المنتج غير مدعوم حالياً');
    } catch (e) {
      AppLogger.error('❌ خطأ في حذف المنتج $productId: $e');
      rethrow;
    }
  }

  /// مسح الكاش المحلي
  void clearCache() {
    _cachedProducts.clear();
    _lastCacheTime = null;
    AppLogger.info('🗑️ تم مسح كاش المنتجات');
  }

  /// الحصول على البيانات المحفوظة
  List<ProductModel> getCachedProducts() {
    return List.from(_cachedProducts);
  }

  /// التحقق من وجود بيانات محفوظة
  bool hasCachedData() {
    return _cachedProducts.isNotEmpty;
  }

  /// الحصول على عمر الكاش
  Duration? getCacheAge() {
    if (_lastCacheTime == null) return null;
    return DateTime.now().difference(_lastCacheTime!);
  }

  /// إجراء تشخيص شامل للشبكة والخدمة
  Future<Map<String, dynamic>> performDiagnostics() async {
    final diagnostics = await NetworkUtils.performNetworkDiagnostics();

    // Add service-specific information
    diagnostics['cacheInfo'] = {
      'hasCachedData': hasCachedData(),
      'cachedProductsCount': _cachedProducts.length,
      'cacheAge': getCacheAge()?.inMinutes,
      'lastCacheTime': _lastCacheTime?.toIso8601String(),
    };

    return diagnostics;
  }

  /// محاولة استعادة الاتصال
  Future<bool> attemptReconnection() async {
    try {
      AppLogger.info('🔄 محاولة استعادة الاتصال...');

      // Wait for connectivity to be restored
      final connected = await NetworkUtils.waitForConnectivity();
      if (!connected) {
        return false;
      }

      // Try to fetch fresh data
      final products = await getProducts();
      return products.isNotEmpty;
    } catch (e) {
      AppLogger.error('❌ فشل في استعادة الاتصال: $e');
      return false;
    }
  }

  /// تنظيف الموارد
  void dispose() {
    _client.close();
    clearCache();
  }
}
