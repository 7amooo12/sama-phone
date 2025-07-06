import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/client_orders_service.dart' as client_service;
import '../services/voucher_order_service.dart';
import '../models/voucher_model.dart';
import '../models/product_model.dart';
import '../utils/app_logger.dart';

/// Dedicated provider for managing voucher-specific shopping cart
/// Separate from regular cart to handle voucher discounts and metadata
class VoucherCartProvider with ChangeNotifier {
  // Constructor
  VoucherCartProvider() {
    // Initialize asynchronously to avoid blocking the constructor
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVoucherCart();
    });
  }

  List<client_service.CartItem> _voucherCartItems = [];
  VoucherModel? _appliedVoucher;
  String? _clientVoucherId; // Track the client voucher assignment ID
  bool _isLoading = false;
  String? _error;
  final VoucherOrderService _voucherOrderService = VoucherOrderService();

  // Getters
  List<client_service.CartItem> get voucherCartItems => List.unmodifiable(_voucherCartItems);
  VoucherModel? get appliedVoucher => _appliedVoucher;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _voucherCartItems.isEmpty;
  int get itemCount => _voucherCartItems.length;

  /// Total quantity of all items in voucher cart
  int get totalQuantity => _voucherCartItems.fold(0, (sum, item) => sum + item.quantity);

  /// Total original price (before voucher discount)
  double get totalOriginalPrice => _voucherCartItems.fold(0.0, (sum, item) => sum + item.totalOriginalPrice);

  /// Total discounted price (after voucher discount)
  double get totalDiscountedPrice => _voucherCartItems.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Total savings from voucher
  double get totalSavings => totalOriginalPrice - totalDiscountedPrice;

  /// Discount percentage for display
  double get discountPercentage => _appliedVoucher?.discountPercentage.toDouble() ?? 0.0;

  /// Initialize voucher cart from storage
  Future<void> _initializeVoucherCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = prefs.getString('voucher_cart_items');
      final voucherData = prefs.getString('applied_voucher');

      if (cartData != null) {
        final cartJson = json.decode(cartData) as List<dynamic>;
        _voucherCartItems = cartJson.map((item) => client_service.CartItem.fromJson(item as Map<String, dynamic>)).toList();
      }

      if (voucherData != null) {
        final voucherJson = json.decode(voucherData) as Map<String, dynamic>;
        _appliedVoucher = VoucherModel.fromJson(voucherJson);
      }

      AppLogger.info('🎫 Voucher cart initialized: ${_voucherCartItems.length} items');
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Error initializing voucher cart: $e');
      _setError('فشل في تحميل سلة القسائم');
    }
  }

  /// Save voucher cart to storage
  Future<void> _saveVoucherCartToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save cart items
      final cartJson = _voucherCartItems.map((item) => item.toJson()).toList();
      await prefs.setString('voucher_cart_items', json.encode(cartJson));

      // Save applied voucher
      if (_appliedVoucher != null) {
        await prefs.setString('applied_voucher', json.encode(_appliedVoucher!.toJson()));
      } else {
        await prefs.remove('applied_voucher');
      }

      AppLogger.info('💾 Voucher cart saved to storage');
    } catch (e) {
      AppLogger.error('❌ Error saving voucher cart: $e');
    }
  }

  /// Set voucher for the cart
  void setVoucher(VoucherModel voucher, {String? clientVoucherId}) {
    _appliedVoucher = voucher;
    _clientVoucherId = clientVoucherId;
    _clearError();

    // Validate that clientVoucherId is provided for proper order creation
    if (clientVoucherId == null || clientVoucherId.isEmpty) {
      AppLogger.warning('⚠️ Client voucher ID not provided when setting voucher. This may cause issues during checkout.');
    }

    // Recalculate all items with new voucher
    _recalculateCartWithVoucher();

    _saveVoucherCartToStorage();
    notifyListeners();
    AppLogger.info('🎫 Voucher applied: ${voucher.name}${clientVoucherId != null ? ' (Client Voucher ID: $clientVoucherId)' : ' (NO CLIENT VOUCHER ID)'}');
  }

  /// Add product to voucher cart with discount applied
  void addToVoucherCart(ProductModel product, int quantity) {
    if (_appliedVoucher == null) {
      _setError('يجب تطبيق قسيمة أولاً');
      return;
    }

    _clearError();

    // Check if product is eligible for voucher
    if (!_isProductEligibleForVoucher(product)) {
      _setError('هذا المنتج غير مؤهل للقسيمة');
      return;
    }

    // Validate stock availability
    if (quantity <= 0) {
      _setError('الكمية يجب أن تكون أكبر من صفر');
      return;
    }

    if (product.quantity <= 0) {
      _setError('هذا المنتج غير متوفر في المخزون');
      return;
    }

    final existingIndex = _voucherCartItems.indexWhere((item) => item.productId == product.id);
    final currentCartQuantity = existingIndex >= 0 ? _voucherCartItems[existingIndex].quantity : 0;
    final totalRequestedQuantity = currentCartQuantity + quantity;

    // Check if total requested quantity exceeds available stock
    if (totalRequestedQuantity > product.quantity) {
      final availableToAdd = product.quantity - currentCartQuantity;
      if (availableToAdd <= 0) {
        _setError('تم إضافة الحد الأقصى المتاح من هذا المنتج');
        return;
      } else {
        _setError('الكمية المتاحة: $availableToAdd فقط');
        return;
      }
    }

    // Calculate discounted price based on voucher type
    final originalPrice = product.price;
    double discountedPrice;
    double discountAmount;

    switch (_appliedVoucher!.discountType) {
      case DiscountType.percentage:
        discountedPrice = originalPrice * (1 - _appliedVoucher!.discountPercentage / 100);
        discountAmount = originalPrice - discountedPrice;
        break;
      case DiscountType.fixedAmount:
        final fixedDiscount = _appliedVoucher!.discountAmount ?? 0.0;
        // Apply fixed discount but don't exceed item price
        final discountPerItem = fixedDiscount > originalPrice ? originalPrice : fixedDiscount;
        discountedPrice = originalPrice - discountPerItem;
        discountAmount = discountPerItem;
        break;
    }

    if (existingIndex >= 0) {
      // Update existing item quantity
      final existingItem = _voucherCartItems[existingIndex];
      _voucherCartItems[existingIndex] = existingItem.copyWith(
        quantity: totalRequestedQuantity,
      );
      AppLogger.info('🛒 Updated voucher cart item: ${product.name} (New quantity: $totalRequestedQuantity)');
    } else {
      // Add new item with voucher discount
      final cartItem = client_service.CartItem.fromProductWithVoucher(
        product: product,
        quantity: quantity,
        discountedPrice: discountedPrice,
        originalPrice: originalPrice,
        voucherCode: _appliedVoucher!.code,
        voucherName: _appliedVoucher!.name,
        discountPercentage: _appliedVoucher!.discountType == DiscountType.percentage
            ? _appliedVoucher!.discountPercentage.toDouble()
            : 0.0,
        // REMOVED: discountAmount parameter - it's calculated internally in the factory constructor
      );

      _voucherCartItems.add(cartItem);
      AppLogger.info('🛒 Added to voucher cart: ${product.name} (Quantity: $quantity, Discount: ${_appliedVoucher!.formattedDiscount})');
    }

    _saveVoucherCartToStorage();
    notifyListeners();
  }

  /// Remove item from voucher cart
  void removeFromVoucherCart(String productId) {
    _voucherCartItems.removeWhere((item) => item.productId == productId);
    _saveVoucherCartToStorage();
    notifyListeners();
    AppLogger.info('🗑️ Removed from voucher cart: $productId');
  }

  /// Update item quantity in voucher cart with stock validation
  void updateVoucherCartItemQuantity(String productId, int newQuantity, {ProductModel? product}) {
    if (newQuantity <= 0) {
      removeFromVoucherCart(productId);
      return;
    }

    final index = _voucherCartItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      // Validate stock if product is provided
      if (product != null) {
        if (newQuantity > product.quantity) {
          _setError('الكمية المطلوبة ($newQuantity) تتجاوز المتوفر في المخزون (${product.quantity})');
          return;
        }
      }

      _voucherCartItems[index] = _voucherCartItems[index].copyWith(quantity: newQuantity);
      _saveVoucherCartToStorage();
      notifyListeners();
      AppLogger.info('📝 Updated voucher cart quantity: $productId = $newQuantity');
    }
  }

  /// Check if product is in voucher cart
  bool isProductInVoucherCart(String productId) {
    return _voucherCartItems.any((item) => item.productId == productId);
  }

  /// Get product quantity in voucher cart
  int getVoucherCartProductQuantity(String productId) {
    final item = _voucherCartItems.firstWhere(
      (item) => item.productId == productId,
      orElse: () => client_service.CartItem(
        productId: '',
        productName: '',
        productImage: '',
        price: 0,
        quantity: 0,
        category: '',
        isVoucherItem: false,
      ),
    );
    return item.productId.isNotEmpty ? item.quantity : 0;
  }

  /// Clear voucher cart
  void clearVoucherCart() {
    _voucherCartItems.clear();
    _appliedVoucher = null;
    _clearError();
    _saveVoucherCartToStorage();
    notifyListeners();
    AppLogger.info('🧹 Voucher cart cleared');
  }

  /// Recalculate all cart items with current voucher
  void _recalculateCartWithVoucher() {
    if (_appliedVoucher == null) return;

    for (int i = 0; i < _voucherCartItems.length; i++) {
      final item = _voucherCartItems[i];
      final originalPrice = item.originalPrice ?? item.price;

      double discountedPrice;
      double discountAmount;

      switch (_appliedVoucher!.discountType) {
        case DiscountType.percentage:
          discountedPrice = originalPrice * (1 - _appliedVoucher!.discountPercentage / 100);
          discountAmount = originalPrice - discountedPrice;
          break;
        case DiscountType.fixedAmount:
          final fixedDiscount = _appliedVoucher!.discountAmount ?? 0.0;
          // Apply fixed discount but don't exceed item price
          final discountPerItem = fixedDiscount > originalPrice ? originalPrice : fixedDiscount;
          discountedPrice = originalPrice - discountPerItem;
          discountAmount = discountPerItem;
          break;
      }

      _voucherCartItems[i] = item.copyWith(
        price: discountedPrice,
        originalPrice: originalPrice,
        discountAmount: discountAmount,
        voucherCode: _appliedVoucher!.code,
        voucherName: _appliedVoucher!.name,
        discountPercentage: _appliedVoucher!.discountType == DiscountType.percentage
            ? _appliedVoucher!.discountPercentage.toDouble()
            : 0.0,
        isVoucherItem: true,
      );
    }
  }

  /// Check if product is eligible for current voucher
  bool _isProductEligibleForVoucher(ProductModel product) {
    if (_appliedVoucher == null) return false;

    switch (_appliedVoucher!.type) {
      case VoucherType.category:
        return product.category == _appliedVoucher!.targetId;
      case VoucherType.product:
        return product.id == _appliedVoucher!.targetId;
      case VoucherType.multipleProducts:
        // Check if product is in the selected products list
        return _appliedVoucher!.isProductApplicable(product.id, product.category);
    }
  }

  /// Validate voucher cart against current stock levels
  Future<Map<String, dynamic>> validateCartStock(List<ProductModel> availableProducts) async {
    final validationResult = <String, dynamic>{
      'isValid': true,
      'errors': <String>[],
      'adjustedItems': <String>[],
      'removedItems': <String>[],
    };

    final itemsToRemove = <String>[];
    final itemsToAdjust = <Map<String, dynamic>>[];

    for (int i = 0; i < _voucherCartItems.length; i++) {
      final cartItem = _voucherCartItems[i];
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

      if (product.id.isEmpty || !product.isActive) {
        // Product no longer exists or is inactive
        itemsToRemove.add(cartItem.productId);
        (validationResult['removedItems'] as List<String>).add(cartItem.productName);
        (validationResult['errors'] as List<String>).add('المنتج "${cartItem.productName}" لم يعد متوفراً');
      } else if (product.quantity <= 0) {
        // Product is out of stock
        itemsToRemove.add(cartItem.productId);
        (validationResult['removedItems'] as List<String>).add(cartItem.productName);
        (validationResult['errors'] as List<String>).add('المنتج "${cartItem.productName}" نفد من المخزون');
      } else if (cartItem.quantity > product.quantity) {
        // Adjust quantity to available stock
        itemsToAdjust.add({
          'productId': cartItem.productId,
          'productName': cartItem.productName,
          'oldQuantity': cartItem.quantity,
          'newQuantity': product.quantity,
        });
        (validationResult['adjustedItems'] as List<String>).add('${cartItem.productName}: ${cartItem.quantity} → ${product.quantity}');
      }
    }

    // Remove out-of-stock items
    for (final productId in itemsToRemove) {
      removeFromVoucherCart(productId);
    }

    // Adjust quantities
    for (final adjustment in itemsToAdjust) {
      final index = _voucherCartItems.indexWhere((item) => item.productId == adjustment['productId']);
      if (index >= 0) {
        _voucherCartItems[index] = _voucherCartItems[index].copyWith(
          quantity: adjustment['newQuantity'] as int,
        );
      }
    }

    if (itemsToRemove.isNotEmpty || itemsToAdjust.isNotEmpty) {
      validationResult['isValid'] = false;
      _saveVoucherCartToStorage();
      notifyListeners();
    }

    return validationResult;
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _error = null;
  }

  /// Create voucher order
  Future<String?> createVoucherOrder({
    required String clientId,
    required String clientName,
    required String clientEmail,
    required String clientPhone,
    required String clientVoucherId,
    String? notes,
    String? shippingAddress,
  }) async {
    if (_appliedVoucher == null || _voucherCartItems.isEmpty) {
      _setError('لا توجد قسيمة مطبقة أو السلة فارغة');
      return null;
    }

    _setLoading(true);
    _clearError();

    try {
      final orderId = await _voucherOrderService.createVoucherOrder(
        clientId: clientId,
        clientName: clientName,
        clientEmail: clientEmail,
        clientPhone: clientPhone,
        voucherCartItems: _voucherCartItems,
        voucher: _appliedVoucher!,
        clientVoucherId: clientVoucherId,
        totalOriginalPrice: totalOriginalPrice,
        totalDiscountedPrice: totalDiscountedPrice,
        totalSavings: totalSavings,
        notes: notes,
        shippingAddress: shippingAddress,
      );

      if (orderId != null) {
        // Clear voucher cart after successful order creation
        clearVoucherCart();
        AppLogger.info('✅ Voucher order created successfully: $orderId');
      }

      return orderId;
    } catch (e) {
      AppLogger.error('❌ Error creating voucher order: $e');
      _setError('فشل في إنشاء طلب القسيمة: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Set client voucher ID for order creation
  void setClientVoucherId(String clientVoucherId) {
    _clientVoucherId = clientVoucherId;
    notifyListeners();
  }

  /// Get client voucher ID
  String? get clientVoucherId => _clientVoucherId;

  /// Get voucher cart summary for order creation
  Map<String, dynamic> getVoucherCartSummary() {
    return {
      'voucher': _appliedVoucher?.toJson(),
      'cartItems': _voucherCartItems.map((item) => item.toJson()).toList(),
      'totalOriginalPrice': totalOriginalPrice,
      'totalDiscountedPrice': totalDiscountedPrice,
      'totalSavings': totalSavings,
      'discountPercentage': discountPercentage,
      'itemCount': itemCount,
      'totalQuantity': totalQuantity,
      'clientVoucherId': _clientVoucherId,
    };
  }
}
