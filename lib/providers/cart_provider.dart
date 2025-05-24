import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/product.dart';
import '../utils/logger.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product']),
      quantity: json['quantity'],
    );
  }

  double get totalPrice => product.price * quantity;
}

class CartProvider with ChangeNotifier {
  List<CartItem> _items = [];
  bool _isLoading = false;

  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;
  
  // Get total number of items in cart
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  
  // Get total price of all items in cart
  double get totalAmount => _items.fold(
        0.0,
        (sum, item) => sum + (item.product.price * item.quantity),
      );

  // Check if a product is in the cart
  bool isInCart(int productId) {
    return _items.any((item) => item.product.id == productId);
  }

  // Get cart item for a specific product
  CartItem? getCartItem(int productId) {
    try {
      return _items.firstWhere((item) => item.product.id == productId);
    } catch (e) {
      return null;
    }
  }

  // Add item to cart
  void addItem(Product product, {int quantity = 1}) {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      // Product already in cart, increase quantity
      _items[existingIndex].quantity += quantity;
    } else {
      // Add new product to cart
      _items.add(CartItem(product: product, quantity: quantity));
    }

    _saveCartToPrefs();
    notifyListeners();
  }

  // Remove item from cart
  void removeItem(int productId) {
    _items.removeWhere((item) => item.product.id == productId);
    _saveCartToPrefs();
    notifyListeners();
  }

  // Increase quantity of an item
  void increaseQuantity(int productId) {
    final existingIndex = _items.indexWhere((item) => item.product.id == productId);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
      _saveCartToPrefs();
      notifyListeners();
    }
  }

  // Decrease quantity of an item
  void decreaseQuantity(int productId) {
    final existingIndex = _items.indexWhere((item) => item.product.id == productId);
    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity > 1) {
        _items[existingIndex].quantity--;
      } else {
        _items.removeAt(existingIndex);
      }
      _saveCartToPrefs();
      notifyListeners();
    }
  }

  // Clear cart
  void clear() {
    _items = [];
    _saveCartToPrefs();
    notifyListeners();
  }

  // Load cart from SharedPreferences
  Future<void> loadCart() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = prefs.getString('cart');

      if (cartData != null) {
        final List<dynamic> decodedData = json.decode(cartData);
        _items = decodedData
            .map((item) => CartItem.fromJson(item))
            .toList();
      }
    } catch (e) {
      AppLogger.error('Error loading cart', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save cart to SharedPreferences
  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = json.encode(_items.map((item) => item.toJson()).toList());
      await prefs.setString('cart', cartData);
    } catch (e) {
      AppLogger.error('Error saving cart', e);
    }
  }
}
