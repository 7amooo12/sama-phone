import 'dart:async';
import '../models/invoice_models.dart';
import '../models/product_model.dart';
import '../services/unified_products_service.dart';
import '../utils/app_logger.dart';

class ProductSearchService {
  factory ProductSearchService() => _instance;
  ProductSearchService._internal();
  static final ProductSearchService _instance = ProductSearchService._internal();

  final UnifiedProductsService _productsService = UnifiedProductsService();
  List<ProductSearchResult> _cachedProducts = [];
  DateTime? _lastCacheUpdate;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Search products with live filtering
  Future<List<ProductSearchResult>> searchProducts(String query) async {
    try {
      // Update cache if needed
      await _updateCacheIfNeeded();

      if (query.isEmpty) {
        return _cachedProducts.take(20).toList(); // Return first 20 products
      }

      // Filter products based on query
      final filteredProducts = _cachedProducts.where((product) {
        final searchQuery = query.toLowerCase();
        return product.name.toLowerCase().contains(searchQuery) ||
               (product.description?.toLowerCase().contains(searchQuery) ?? false) ||
               (product.category?.toLowerCase().contains(searchQuery) ?? false) ||
               (product.sku?.toLowerCase().contains(searchQuery) ?? false);
      }).toList();

      // Sort by relevance (exact matches first, then partial matches)
      filteredProducts.sort((a, b) {
        final aExact = a.name.toLowerCase().startsWith(query.toLowerCase()) ? 0 : 1;
        final bExact = b.name.toLowerCase().startsWith(query.toLowerCase()) ? 0 : 1;
        
        if (aExact != bExact) return aExact.compareTo(bExact);
        
        // Then sort by availability
        if (a.inStock && !b.inStock) return -1;
        if (!a.inStock && b.inStock) return 1;
        
        // Finally sort alphabetically
        return a.name.compareTo(b.name);
      });

      return filteredProducts.take(50).toList(); // Limit to 50 results
    } catch (e) {
      AppLogger.error('خطأ في البحث عن المنتجات: $e');
      return [];
    }
  }

  /// Get product by ID
  Future<ProductSearchResult?> getProductById(String productId) async {
    try {
      await _updateCacheIfNeeded();
      return _cachedProducts.firstWhere(
        (product) => product.id == productId,
        orElse: () => throw Exception('Product not found'),
      );
    } catch (e) {
      AppLogger.error('خطأ في جلب المنتج: $e');
      return null;
    }
  }

  /// Get products by category
  Future<List<ProductSearchResult>> getProductsByCategory(String category) async {
    try {
      await _updateCacheIfNeeded();
      return _cachedProducts
          .where((product) => product.category?.toLowerCase() == category.toLowerCase())
          .toList();
    } catch (e) {
      AppLogger.error('خطأ في جلب منتجات الفئة: $e');
      return [];
    }
  }

  /// Get all available categories
  Future<List<String>> getCategories() async {
    try {
      await _updateCacheIfNeeded();
      final categories = _cachedProducts
          .where((product) => product.category != null && product.category!.isNotEmpty)
          .map((product) => product.category!)
          .toSet()
          .toList();
      categories.sort();
      return categories;
    } catch (e) {
      AppLogger.error('خطأ في جلب الفئات: $e');
      return [];
    }
  }

  /// Update cache if needed
  Future<void> _updateCacheIfNeeded() async {
    if (_shouldUpdateCache()) {
      await _updateCache();
    }
  }

  /// Check if cache should be updated
  bool _shouldUpdateCache() {
    if (_cachedProducts.isEmpty) return true;
    if (_lastCacheUpdate == null) return true;
    return DateTime.now().difference(_lastCacheUpdate!) > _cacheDuration;
  }

  /// Update the products cache
  Future<void> _updateCache() async {
    try {
      AppLogger.info('تحديث كاش المنتجات...');
      
      final products = await _productsService.getProducts();
      _cachedProducts = products.map((product) => _convertToSearchResult(product)).toList();
      _lastCacheUpdate = DateTime.now();
      
      AppLogger.info('تم تحديث كاش المنتجات: ${_cachedProducts.length} منتج');
    } catch (e) {
      AppLogger.error('خطأ في تحديث كاش المنتجات: $e');
      // Keep existing cache if update fails
    }
  }

  /// Convert ProductModel to ProductSearchResult
  ProductSearchResult _convertToSearchResult(ProductModel product) {
    return ProductSearchResult(
      id: product.id ?? '',
      name: product.name ?? 'منتج غير معروف',
      description: product.description,
      price: product.price ?? 0.0,
      availableQuantity: product.quantity ?? 0,
      imageUrl: _getBestImageUrl(product),
      category: product.category,
      sku: product.sku,
    );
  }

  /// Get the best available image URL from product
  String? _getBestImageUrl(ProductModel product) {
    // Try different image sources in order of preference
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return product.imageUrl;
    }
    
    if (product.images.isNotEmpty) {
      return product.images.first;
    }
    
    return null;
  }

  /// Force refresh cache
  Future<void> refreshCache() async {
    _lastCacheUpdate = null;
    await _updateCache();
  }

  /// Clear cache
  void clearCache() {
    _cachedProducts.clear();
    _lastCacheUpdate = null;
  }

  /// Get cache info
  Map<String, dynamic> getCacheInfo() {
    return {
      'products_count': _cachedProducts.length,
      'last_update': _lastCacheUpdate?.toIso8601String(),
      'cache_age_minutes': _lastCacheUpdate != null 
          ? DateTime.now().difference(_lastCacheUpdate!).inMinutes 
          : null,
    };
  }

  /// Check product availability
  bool isProductAvailable(String productId, int requestedQuantity) {
    try {
      final product = _cachedProducts.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product not found'),
      );
      return product.availableQuantity >= requestedQuantity;
    } catch (e) {
      return false;
    }
  }

  /// Get low stock products (quantity <= 5)
  Future<List<ProductSearchResult>> getLowStockProducts() async {
    try {
      await _updateCacheIfNeeded();
      return _cachedProducts
          .where((product) => product.availableQuantity <= 5 && product.availableQuantity > 0)
          .toList();
    } catch (e) {
      AppLogger.error('خطأ في جلب المنتجات منخفضة المخزون: $e');
      return [];
    }
  }

  /// Get out of stock products
  Future<List<ProductSearchResult>> getOutOfStockProducts() async {
    try {
      await _updateCacheIfNeeded();
      return _cachedProducts
          .where((product) => product.availableQuantity <= 0)
          .toList();
    } catch (e) {
      AppLogger.error('خطأ في جلب المنتجات غير المتوفرة: $e');
      return [];
    }
  }

  /// Get products with highest stock
  Future<List<ProductSearchResult>> getHighStockProducts({int limit = 20}) async {
    try {
      await _updateCacheIfNeeded();
      final sortedProducts = List<ProductSearchResult>.from(_cachedProducts);
      sortedProducts.sort((a, b) => b.availableQuantity.compareTo(a.availableQuantity));
      return sortedProducts.take(limit).toList();
    } catch (e) {
      AppLogger.error('خطأ في جلب المنتجات عالية المخزون: $e');
      return [];
    }
  }

  /// Get recently added products (mock implementation)
  Future<List<ProductSearchResult>> getRecentProducts({int limit = 10}) async {
    try {
      await _updateCacheIfNeeded();
      // Since we don't have creation date, return first products as "recent"
      return _cachedProducts.take(limit).toList();
    } catch (e) {
      AppLogger.error('خطأ في جلب المنتجات الحديثة: $e');
      return [];
    }
  }
}
