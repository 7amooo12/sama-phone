import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/services/warehouse_products_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// مزود المنتجات لمدير المخزن
/// يدير حالة المنتجات والبحث والتصفية
class WarehouseProductsProvider with ChangeNotifier {
  final WarehouseProductsService _service = WarehouseProductsService();

  // حالة البيانات
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  // Getters
  List<ProductModel> get products => _products;
  List<ProductModel> get filteredProducts => _filteredProducts;
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  /// تحميل المنتجات من API
  Future<void> loadProducts({bool forceRefresh = false}) async {
    try {
      // تجنب التحميل المتكرر إذا كانت البيانات موجودة
      if (_products.isNotEmpty && !forceRefresh) {
        _applyFilters();
        return;
      }

      _setLoading(true);
      _clearError();

      AppLogger.info('🏢 تحميل منتجات المخزن...');

      final products = await _service.getProducts();
      
      _products = products;
      _applyFilters();

      AppLogger.info('✅ تم تحميل ${products.length} منتج بنجاح');

      // تم تعطيل اختبار صور المنتجات لتجنب مشاكل واجهة المستخدم
      // if (kDebugMode && _products.isNotEmpty) {
      //   _testProductImages();
      // }

    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل المنتجات: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// تعيين استعلام البحث وتطبيق التصفية
  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _applyFilters();
    }
  }

  /// تطبيق التصفية على المنتجات
  void _applyFilters() {
    if (_searchQuery.isEmpty) {
      _filteredProducts = List.from(_products);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredProducts = _products.where((product) {
        return product.name.toLowerCase().contains(query) ||
               product.category.toLowerCase().contains(query) ||
               product.sku.toLowerCase().contains(query) ||
               product.description.toLowerCase().contains(query);
      }).toList();
    }
    
    notifyListeners();
  }

  /// تعيين حالة التحميل
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// تعيين رسالة الخطأ
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// مسح رسالة الخطأ
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }



  /// إعادة تعيين المزود
  void reset() {
    _products.clear();
    _filteredProducts.clear();
    _searchQuery = '';
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// البحث عن منتج بالمعرف
  ProductModel? findProductById(String id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  /// الحصول على المنتجات منخفضة المخزون
  List<ProductModel> getLowStockProducts({int threshold = 10}) {
    return _products.where((product) => product.quantity <= threshold).toList();
  }

  /// الحصول على المنتجات نفدت من المخزون
  List<ProductModel> getOutOfStockProducts() {
    return _products.where((product) => product.quantity == 0).toList();
  }

  /// الحصول على إحصائيات المنتجات
  Map<String, dynamic> getProductsStats() {
    final totalProducts = _products.length;
    final lowStockProducts = getLowStockProducts().length;
    final outOfStockProducts = getOutOfStockProducts().length;
    final totalQuantity = _products.fold<int>(0, (sum, product) => sum + product.quantity);

    return {
      'totalProducts': totalProducts,
      'lowStockProducts': lowStockProducts,
      'outOfStockProducts': outOfStockProducts,
      'totalQuantity': totalQuantity,
      'averageQuantity': totalProducts > 0 ? (totalQuantity / totalProducts).round() : 0,
    };
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
