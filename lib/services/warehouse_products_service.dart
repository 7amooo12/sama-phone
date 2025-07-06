import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/services/api_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة المنتجات لمدير المخزن
/// تستخدم نفس API المستخدم في الأدوار الأخرى
class WarehouseProductsService {
  final ApiService _apiService = ApiService();

  /// الحصول على جميع المنتجات من API
  Future<List<ProductModel>> getProducts() async {
    try {
      AppLogger.info('🔄 جاري تحميل المنتجات من API...');
      
      final products = await _apiService.getProducts();
      
      AppLogger.info('✅ تم تحميل ${products.length} منتج من API');
      
      // ترتيب المنتجات حسب الاسم
      products.sort((a, b) => a.name.compareTo(b.name));
      
      return products;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل المنتجات من API: $e');
      rethrow;
    }
  }

  /// البحث في المنتجات
  Future<List<ProductModel>> searchProducts(String query) async {
    try {
      if (query.isEmpty) {
        return await getProducts();
      }

      AppLogger.info('🔍 البحث في المنتجات: $query');
      
      final allProducts = await getProducts();
      final searchQuery = query.toLowerCase();
      
      final filteredProducts = allProducts.where((product) {
        return product.name.toLowerCase().contains(searchQuery) ||
               product.category.toLowerCase().contains(searchQuery) ||
               product.sku.toLowerCase().contains(searchQuery) ||
               product.description.toLowerCase().contains(searchQuery);
      }).toList();
      
      AppLogger.info('✅ تم العثور على ${filteredProducts.length} منتج');
      
      return filteredProducts;
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن المنتجات: $e');
      rethrow;
    }
  }

  /// الحصول على منتج بالمعرف
  Future<ProductModel?> getProductById(String id) async {
    try {
      final products = await getProducts();
      return products.firstWhere(
        (product) => product.id == id,
        orElse: () => throw Exception('المنتج غير موجود'),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على المنتج: $e');
      return null;
    }
  }

  /// الحصول على المنتجات حسب الفئة
  Future<List<ProductModel>> getProductsByCategory(String category) async {
    try {
      final products = await getProducts();
      return products.where((product) => 
        product.category.toLowerCase() == category.toLowerCase()
      ).toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على منتجات الفئة: $e');
      rethrow;
    }
  }

  /// الحصول على المنتجات منخفضة المخزون
  Future<List<ProductModel>> getLowStockProducts({int threshold = 10}) async {
    try {
      final products = await getProducts();
      return products.where((product) => 
        product.quantity <= threshold && product.quantity > 0
      ).toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على المنتجات منخفضة المخزون: $e');
      rethrow;
    }
  }

  /// الحصول على المنتجات نفدت من المخزون
  Future<List<ProductModel>> getOutOfStockProducts() async {
    try {
      final products = await getProducts();
      return products.where((product) => product.quantity == 0).toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على المنتجات نفدت من المخزون: $e');
      rethrow;
    }
  }

  /// الحصول على إحصائيات المنتجات
  Future<Map<String, dynamic>> getProductsStatistics() async {
    try {
      final products = await getProducts();
      
      final totalProducts = products.length;
      final lowStockProducts = products.where((p) => p.quantity <= 10 && p.quantity > 0).length;
      final outOfStockProducts = products.where((p) => p.quantity == 0).length;
      final totalQuantity = products.fold<int>(0, (sum, product) => sum + product.quantity);
      
      // الحصول على الفئات الفريدة
      final categories = products.map((p) => p.category).toSet().toList();
      
      return {
        'totalProducts': totalProducts,
        'lowStockProducts': lowStockProducts,
        'outOfStockProducts': outOfStockProducts,
        'totalQuantity': totalQuantity,
        'averageQuantity': totalProducts > 0 ? (totalQuantity / totalProducts).round() : 0,
        'categories': categories,
        'categoriesCount': categories.length,
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على إحصائيات المنتجات: $e');
      rethrow;
    }
  }

  /// الحصول على أفضل المنتجات (حسب الكمية)
  Future<List<ProductModel>> getTopProducts({int limit = 10}) async {
    try {
      final products = await getProducts();
      
      // ترتيب حسب الكمية (تنازلي)
      products.sort((a, b) => b.quantity.compareTo(a.quantity));
      
      return products.take(limit).toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على أفضل المنتجات: $e');
      rethrow;
    }
  }
}
