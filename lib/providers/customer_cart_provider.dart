import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartItem {

  CartItem({
    required this.productId,
    required this.productName,
    this.productImage,
    required this.price,
    this.discountPrice,
    required this.category,
    required this.sku,
    this.quantity = 1,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: (json['productId'] as String?) ?? '',
      productName: (json['productName'] as String?) ?? '',
      productImage: json['productImage'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      discountPrice: (json['discountPrice'] as num?)?.toDouble(),
      category: (json['category'] as String?) ?? '',
      sku: (json['sku'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  factory CartItem.fromProduct(ProductModel product, {int quantity = 1}) {
    return CartItem(
      productId: product.id,
      productName: product.name,
      productImage: product.imageUrl,
      price: product.price,
      discountPrice: product.discountPrice,
      category: product.category,
      sku: product.sku,
      quantity: quantity,
    );
  }
  final String productId;
  final String productName;
  final String? productImage;
  final double price;
  final double? discountPrice;
  final String category;
  final String sku;
  int quantity;

  double get effectivePrice => discountPrice ?? price;
  double get totalPrice => effectivePrice * quantity;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'price': price,
      'discountPrice': discountPrice,
      'category': category,
      'sku': sku,
      'quantity': quantity,
    };
  }

  CartItem copyWith({
    String? productId,
    String? productName,
    String? productImage,
    double? price,
    double? discountPrice,
    String? category,
    String? sku,
    int? quantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      price: price ?? this.price,
      discountPrice: discountPrice ?? this.discountPrice,
      category: category ?? this.category,
      sku: sku ?? this.sku,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CustomerCartProvider with ChangeNotifier { // Can add tax, shipping, etc. later

  // Initialize provider and load cart from storage
  CustomerCartProvider() {
    _initializeCart();
  }
  static const String _cartKeyPrefix = 'customer_cart_items';

  List<CartItem> _items = [];
  bool _isLoading = false;
  String? _currentUserId;

  // Getters
  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  
  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  
  double get total => subtotal;

  // Get user-specific cart key
  String get _cartKey {
    final userId = _currentUserId ?? Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    return '${_cartKeyPrefix}_$userId';
  }

  // Initialize cart with current user
  Future<void> _initializeCart() async {
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    await _loadCartFromStorage();
  }

  // Update user ID and reload cart (call when user logs in/out)
  Future<void> updateUser(String? userId) async {
    if (_currentUserId != userId) {
      // Clear current cart before switching users
      _items.clear();
      _currentUserId = userId;
      await _loadCartFromStorage();
      notifyListeners();
    }
  }

  // Clear cart when user logs out
  Future<void> clearUserCart() async {
    _items.clear();
    _currentUserId = null;
    notifyListeners();
  }

  // Check if a product is in the cart
  bool isInCart(String productId) {
    return _items.any((item) => item.productId == productId);
  }

  // Get cart item for a specific product
  CartItem? getCartItem(String productId) {
    try {
      return _items.firstWhere((item) => item.productId == productId);
    } catch (e) {
      return null;
    }
  }

  // Get quantity of a specific product in cart
  int getProductQuantity(String productId) {
    final item = getCartItem(productId);
    return item?.quantity ?? 0;
  }

  // Add product to cart
  void addToCart(ProductModel product, {int quantity = 1}) {
    final existingIndex = _items.indexWhere((item) => item.productId == product.id);

    if (existingIndex >= 0) {
      // Product already in cart, increase quantity
      _items[existingIndex].quantity += quantity;
    } else {
      // Add new product to cart
      _items.add(CartItem.fromProduct(product, quantity: quantity));
    }

    _saveCartToStorage();
    notifyListeners();
  }

  // Remove product from cart completely
  void removeFromCart(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    _saveCartToStorage();
    notifyListeners();
  }

  // Update quantity of a product in cart
  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }

    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      _items[index].quantity = quantity;
      _saveCartToStorage();
      notifyListeners();
    }
  }

  // Increase quantity by 1
  void increaseQuantity(String productId) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      _items[index].quantity++;
      _saveCartToStorage();
      notifyListeners();
    }
  }

  // Decrease quantity by 1
  void decreaseQuantity(String productId) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
        _saveCartToStorage();
        notifyListeners();
      } else {
        removeFromCart(productId);
      }
    }
  }

  // Clear entire cart
  void clearCart() {
    _items.clear();
    _saveCartToStorage();
    notifyListeners();
  }

  // Load cart from local storage
  Future<void> _loadCartFromStorage() async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_cartKey);

      if (cartJson != null && cartJson.isNotEmpty) {
        final List<dynamic> cartList = json.decode(cartJson) as List<dynamic>;
        _items = cartList.map((item) => CartItem.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading cart from storage: $e');
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save cart to local storage
  Future<void> _saveCartToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode(_items.map((item) => item.toJson()).toList());
      await prefs.setString(_cartKey, cartJson);
    } catch (e) {
      debugPrint('Error saving cart to storage: $e');
    }
  }

  // Get cart summary for display
  Map<String, dynamic> getCartSummary() {
    return {
      'itemCount': itemCount,
      'subtotal': subtotal,
      'total': total,
      'isEmpty': isEmpty,
    };
  }

  // Validate cart items (check if products still exist and have stock)
  Future<List<String>> validateCart(List<ProductModel> availableProducts) async {
    final List<String> removedItems = [];
    final List<CartItem> validItems = [];

    for (final cartItem in _items) {
      final product = availableProducts.firstWhere(
        (p) => p.id == cartItem.productId,
        orElse: () => ProductModel(
          id: '',
          name: '',
          description: '',
          price: 0,
          quantity: 0,
          category: '',
          createdAt: DateTime.now(),
          isActive: false,
          sku: '',
          reorderPoint: 0,
          images: [],
        ),
      );

      if (product.id.isEmpty || product.quantity <= 0) {
        // Product no longer exists or out of stock
        removedItems.add(cartItem.productName);
      } else if (cartItem.quantity > product.quantity) {
        // Adjust quantity to available stock
        cartItem.quantity = product.quantity;
        validItems.add(cartItem);
      } else {
        validItems.add(cartItem);
      }
    }

    if (removedItems.isNotEmpty || validItems.length != _items.length) {
      _items = validItems;
      _saveCartToStorage();
      notifyListeners();
    }

    return removedItems;
  }
}
