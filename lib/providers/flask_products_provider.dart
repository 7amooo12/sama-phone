import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/models/flask_models.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';

enum ProductLoadingStatus {
  /// Initial state
  initial,

  /// Loading products
  loading,

  /// Products loaded successfully
  loaded,

  /// Error loading products
  error,
}

class FlaskProductsProvider with ChangeNotifier {
  // Services
  final FlaskApiService _apiService = FlaskApiService();

  // Internal state
  ProductLoadingStatus _status = ProductLoadingStatus.initial;
  List<FlaskProductModel> _products = [];
  FlaskProductModel? _selectedProduct;
  String? _errorMessage;

  // Filtering and sorting state
  double? _minPrice;
  double? _maxPrice;
  String? _searchQuery;
  String? _selectedColor;
  bool _showInStockOnly = false;
  bool _showDiscountedOnly = false;
  String _sortBy = 'name';
  String _sortOrder = 'asc';

  // Getters
  ProductLoadingStatus get status => _status;
  List<FlaskProductModel> get products => _products;
  FlaskProductModel? get selectedProduct => _selectedProduct;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ProductLoadingStatus.loading;

  // Filter and sort getters
  double? get minPrice => _minPrice;
  double? get maxPrice => _maxPrice;
  String? get searchQuery => _searchQuery;
  String? get selectedColor => _selectedColor;
  bool get showInStockOnly => _showInStockOnly;
  bool get showDiscountedOnly => _showDiscountedOnly;
  String get sortBy => _sortBy;
  String get sortOrder => _sortOrder;

  // Load products with filters
  Future<void> loadProducts({
    double? minPrice,
    double? maxPrice,
    String? color,
    String? search,
    bool? inStock,
    bool? hasDiscount,
    String? sortBy,
    String? sortOrder,
    int? limit,
    bool forceRefresh = false,
  }) async {
    // Update filter values if provided
    if (minPrice != null) _minPrice = minPrice;
    if (maxPrice != null) _maxPrice = maxPrice;
    if (color != null) _selectedColor = color;
    if (search != null) _searchQuery = search;
    if (inStock != null) _showInStockOnly = inStock;
    if (hasDiscount != null) _showDiscountedOnly = hasDiscount;
    if (sortBy != null) _sortBy = sortBy;
    if (sortOrder != null) _sortOrder = sortOrder;

    // If we have products and not forcing refresh, just apply filters locally
    if (_products.isNotEmpty && !forceRefresh) {
      _applyFiltersLocally();
      return;
    }

    _status = ProductLoadingStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _products = await _apiService.getProducts(
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        color: _selectedColor,
        search: _searchQuery,
        inStock: _showInStockOnly,
        hasDiscount: _showDiscountedOnly,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        limit: limit,
      );

      _status = ProductLoadingStatus.loaded;
    } catch (e) {
      _status = ProductLoadingStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Apply filters locally without making a new API call
  void _applyFiltersLocally() {
    notifyListeners();
  }

  // Load specific product
  Future<void> loadProduct(int productId) async {
    _status = ProductLoadingStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if product is already in the list
      _selectedProduct = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product not found'),
      );

      // If not found, fetch from API
      if (_selectedProduct == null) {
        _selectedProduct = await _apiService.getProduct(productId);
        if (_selectedProduct == null) {
          throw Exception('Product not found');
        }
      }

      _status = ProductLoadingStatus.loaded;
    } catch (e) {
      _status = ProductLoadingStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Reset all filters
  void resetFilters() {
    _minPrice = null;
    _maxPrice = null;
    _searchQuery = null;
    _selectedColor = null;
    _showInStockOnly = false;
    _showDiscountedOnly = false;
    _sortBy = 'name';
    _sortOrder = 'asc';
    loadProducts(forceRefresh: true);
  }

  // Update search query
  void updateSearchQuery(String query) {
    _searchQuery = query.isEmpty ? null : query;
    loadProducts(forceRefresh: true);
  }

  // Filter by price range
  void filterByPriceRange(double min, double max) {
    _minPrice = min;
    _maxPrice = max;
    loadProducts(forceRefresh: true);
  }

  // Filter by color
  void filterByColor(String? color) {
    _selectedColor = color;
    loadProducts(forceRefresh: true);
  }

  // Toggle in-stock filter
  void toggleInStock(bool value) {
    _showInStockOnly = value;
    loadProducts(forceRefresh: true);
  }

  // Toggle discounted filter
  void toggleDiscounted(bool value) {
    _showDiscountedOnly = value;
    loadProducts(forceRefresh: true);
  }

  // Sort products
  void sortProducts(String sortBy, String sortOrder) {
    _sortBy = sortBy;
    _sortOrder = sortOrder;
    loadProducts(forceRefresh: true);
  }

  // Get on-sale products
  List<FlaskProductModel> get onSaleProducts {
    return _products.where((product) => product.isOnSale).toList();
  }

  // Get in-stock products
  List<FlaskProductModel> get inStockProducts {
    return _products.where((product) => product.isInStock).toList();
  }
} 