import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/sama_store_service.dart';
import '../services/samastock_api.dart';
import '../utils/app_logger.dart';
import 'package:http/http.dart' as http;
import '../services/database_service.dart';

class ProductProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SamaStoreService _samaStoreService = SamaStoreService();

  List<ProductModel> _products = [];
  List<Product> _samaProducts = [];
  List<ProductModel> _samaAdminProducts = []; // New list for SAMA admin products
  bool _isLoading = false;
  String? _error;
  bool _useSamaStore = false; // Flag to determine which service to use
  bool _useSamaAdmin = false; // New flag for SAMA admin products

  List<ProductModel> get products => _products;
  List<Product> get samaProducts => _samaProducts;
  List<ProductModel> get samaAdminProducts => _samaAdminProducts; // Getter for SAMA admin products
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get useSamaStore => _useSamaStore;
  bool get useSamaAdmin => _useSamaAdmin; // Getter for SAMA admin flag

  // Helpers to set state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Set which service to use
  void setUseSamaStore(bool value) {
    _useSamaStore = value;
    notifyListeners();

    // Load products from the selected service
    if (_useSamaStore) {
      loadSamaProducts();
    } else {
      loadProducts();
    }
  }

  // Set which service to use for SAMA admin products
  void setUseSamaAdmin(bool value) {
    // إذا كان لدينا منتجات بالفعل ويحاول تفعيل استخدام SAMA admin، نتجاهل الطلب
    if (value == true && _products.isNotEmpty) {
      AppLogger.info("تم تجاهل محاولة تفعيل SAMA Admin API لأن هناك منتجات محملة بالفعل (${_products.length} منتج)");
      return; // لا تفعل شيئاً، للحفاظ على المنتجات الحالية
    }
    
    _useSamaAdmin = value;
    notifyListeners();

    // Load products from SAMA admin API only if enabled AND we don't have products already AND not in the middle of loading products
    if (_useSamaAdmin && _products.isEmpty && !_isLoading) {
      AppLogger.info("جاري تحميل المنتجات من SAMA Admin API");
      loadSamaAdminProducts();
    }
  }

  Future<void> loadProducts() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Load products from database
      // Implementation will depend on your database service
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load products';
      _isLoading = false;
      AppLogger.error('Error loading products', e);
      notifyListeners();
    }
  }

  // Load products from SamaStoreService
  Future<List<Product>> loadSamaProducts({
    String? category,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
  }) async {
    setLoading(true);
    
    try {
      final products = await _samaStoreService.getProducts(
        category: category,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );
      
      // Apply sorting if specified
      List<Product> sortedProducts = List.from(products);
      if (sortBy != null) {
        switch (sortBy) {
          case 'latest':
            // Products are assumed to come newest first from API
            break;
          case 'priceAsc':
            sortedProducts.sort((a, b) => a.price.compareTo(b.price));
            break;
          case 'priceDesc':
            sortedProducts.sort((a, b) => b.price.compareTo(a.price));
            break;
          case 'popular':
            // Sort by rating if available
            sortedProducts.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
            break;
        }
      }
      
      _samaProducts = sortedProducts;
      setLoading(false);
      
      // Return the products for use in UI
      return _samaProducts;
    } catch (e) {
      setLoading(false);
      setError('فشل تحميل المنتجات: ${e.toString()}');
      rethrow;
    }
  }

  // Load products from SAMA Admin API
  Future<List<ProductModel>> loadSamaAdminProducts() async {
    try {
      // إذا كان لدينا منتجات محملة بالفعل من API key، لا نقوم بتحميل المنتجات من مصدر آخر
      if (_products.isNotEmpty) {
        AppLogger.info("تم تجاهل تحميل منتجات SAMA Admin لأن هناك منتجات موجودة بالفعل (${_products.length} منتج)");
        return _products;
      }
      
      _isLoading = true;
      notifyListeners();
      
      // Instantiate the SamaStockApiService
      final samaStockApi = SamaStockApiService(client: http.Client());
      
      // Log that we're fetching from SAMA Admin API
      AppLogger.info('جاري تحميل المنتجات من SAMA Admin API...');
      
      // Initialize the API service
      await samaStockApi.initialize();
      
      // Fetch products using the Admin API instead
      final products = await samaStockApi.getAdminProducts();
      
      // تخزين المنتجات في _samaAdminProducts وليس في _products لتجنب التعارض
      _samaAdminProducts = products;
      
      AppLogger.info('تم تحميل ${_samaAdminProducts.length} منتج من SAMA Admin API');
      
      // Update loading state
      _isLoading = false;
      notifyListeners();
      
      return _samaAdminProducts;
    } catch (e) {
      _isLoading = false;
      AppLogger.error('خطأ أثناء تحميل منتجات SAMA Admin', e);
      notifyListeners();
      rethrow;
    }
  }

  // تحميل منتجات الأدمن من SAMA API مع استخدام طريقة toJSON
  Future<List<ProductModel>> loadSamaAdminProductsWithToJSON() async {
    try {
      // تعيين حالة التحميل
      _isLoading = true;
      _error = null;
      notifyListeners();

      AppLogger.info("بدء تحميل منتجات SAMA Admin باستخدام toJSON API");

      // إنشاء نسخة من خدمة SamaStock API
      final samaApi = SamaStockApiService(client: http.Client());
      
      // استخدام الدالة التي تعمل مع مفتاح API مباشرة دون تسجيل دخول
      final products = await samaApi.getProductsWithApiKey();
      
      // تسجيل عدد المنتجات التي تم استردادها
      AppLogger.info("تم استرداد ${products.length} منتج من SAMA Admin API");
      
      if (products.isEmpty) {
        // تسجيل عدم وجود منتجات وإرجاع خطأ
        AppLogger.warning("لم يتم استرداد أي منتجات من API");
        _isLoading = false;
        _error = "لم يتم العثور على أي منتجات. يرجى التحقق من اتصال الشبكة وإعادة المحاولة.";
        notifyListeners();
        return [];
      }
      
      // تخزين المنتجات في Provider بعد تأكيد استلامها بنجاح
      _samaAdminProducts = List<ProductModel>.from(products);
      AppLogger.info("تم تخزين ${_samaAdminProducts.length} منتج في Provider");
      
      _isLoading = false;
      _error = null;
      
      notifyListeners();
      return _samaAdminProducts;
    } catch (e) {
      // تعيين حالة الخطأ
      _isLoading = false;
      _error = "فشل تحميل المنتجات: ${e.toString()}";
      notifyListeners();
      AppLogger.error("فشل تحميل منتجات SAMA Admin باستخدام toJSON: $e");
      
      // في حالة الفشل، نعيد قائمة فارغة
      return [];
    }
  }

  // Get product details from SamaStoreService
  Future<Product?> getSamaProductDetails(int productId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Check if product is already in loaded products
      Product? cachedProduct = _samaProducts.firstWhere(
        (p) => p.id == productId,
        orElse: () => null as Product,
      );

      // If product has a description, we likely already have the full details
      if (cachedProduct != null && cachedProduct.description != null && 
          cachedProduct.description!.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
        return cachedProduct;
      }

      // Otherwise fetch fresh data from service
      final product = await _samaStoreService.getProduct(productId);
      
      // If product found, update the cached list
      if (product != null) {
        final index = _samaProducts.indexWhere((p) => p.id == productId);
        if (index != -1) {
          _samaProducts[index] = product;
        } else {
          _samaProducts.add(product);
        }
      }

      _isLoading = false;
      notifyListeners();
      return product;
    } catch (e) {
      _error = 'فشل في تحميل تفاصيل المنتج: ${e.toString()}';
      AppLogger.error('خطأ في تحميل تفاصيل المنتج', e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Get categories from SamaStoreService
  Future<List<String>> getSamaCategories() async {
    try {
      return await _samaStoreService.getCategories();
    } catch (e) {
      AppLogger.error('خطأ في تحميل التصنيفات', e);
      return [];
    }
  }

  // Search products from SamaStoreService
  Future<List<Product>> searchSamaProducts(String query) async {
    try {
      if (query.isEmpty) {
        return _samaProducts;
      }

      return await _samaStoreService.searchProducts(query);
    } catch (e) {
      AppLogger.error('خطأ في البحث عن المنتجات', e);
      return [];
    }
  }

  // Clear any stored caches for SAMA products
  void clearSamaStoreCache() {
    try {
      _samaStoreService.clearCache();
      AppLogger.info('SAMA store cache cleared successfully');
    } catch (e) {
      AppLogger.error('Error clearing SAMA store cache', e);
    }
  }

  // Search products from current source
  List<ProductModel> searchProducts(String query) {
    if (query.isEmpty) {
      return _products;
    }

    query = query.toLowerCase();
    return _products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> addProduct(ProductModel product) async {
    try {
      // Save product to database
      // Implementation will depend on your database service
      _products.insert(0, product);
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error adding product', e);
      rethrow;
    }
  }

  Future<void> updateProduct(ProductModel product) async {
    try {
      // Update product in database
      // Implementation will depend on your database service
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Error updating product', e);
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // استخدام ApiService لحذف منتج
      final response = await _apiService.httpDelete(
        'products/$productId',
      );

      if (response['success'] == true) {
        // إذا كان الحذف ناجحًا، نقوم بحذف المنتج من القائمة المحلية
        _products.removeWhere((product) => product.id == productId);
      } else {
        _error = 'فشل في حذف المنتج: ${response['message']}';
        AppLogger.error('خطأ في حذف المنتج', response['message']);
      }
    } catch (e) {
      _error = 'فشل في حذف المنتج: ${e.toString()}';
      AppLogger.error('خطأ في حذف المنتج', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // تحميل منتجات باستخدام API key مباشرة وتخزينها في Provider
  Future<List<ProductModel>> fetchProductsWithApiKey() async {
    try {
      // فحص إذا كانت المنتجات موجودة بالفعل وعددها > 0
      if (_products.isNotEmpty) {
        AppLogger.info("استخدام المنتجات المخزنة مسبقًا (${_products.length} منتج)");
        // منع استدعاء loadSamaAdminProducts بعد ذلك
        _useSamaAdmin = false;
        // إعادة المنتجات المخزنة مباشرة دون أي استدعاء لـ API
        return _products;
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      AppLogger.info("بدء تحميل المنتجات باستخدام API key");

      // إنشاء نسخة من خدمة SamaStock API
      final samaApi = SamaStockApiService(client: http.Client());
      
      // استخدام الدالة التي تعمل مع مفتاح API مباشرة
      final products = await samaApi.getProductsWithApiKey();
      
      // تسجيل عدد المنتجات التي تم استردادها
      AppLogger.info("تم استرداد ${products.length} منتج باستخدام API key");

      // تخزين المنتجات في Provider للحفاظ عليها - فقط إذا كانت القائمة غير فارغة
      if (products.isNotEmpty) {
        // تعيين المنتجات
        _products = products;
        // تعطيل استخدام SAMA Admin API لمنع تعارض البيانات
        _useSamaAdmin = false;
        _isLoading = false;
        _error = null;
        notifyListeners();
      } else {
        AppLogger.warning("API أرجع قائمة منتجات فارغة");
        _isLoading = false;
        _error = "لم يتم العثور على منتجات. يرجى التحقق من اتصال الشبكة.";
        notifyListeners();
      }
      
      return products;
    } catch (e) {
      // تعيين حالة الخطأ
      _isLoading = false;
      _error = "فشل تحميل المنتجات: ${e.toString()}";
      AppLogger.error("فشل تحميل المنتجات باستخدام API key: $e");
      
      notifyListeners();
      
      // إرجاع المنتجات المخزنة إذا كانت موجودة، وإلا قائمة فارغة
      return _products.isNotEmpty ? _products : [];
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
