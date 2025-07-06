import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/services/client_orders_service.dart' as client_service;
import 'package:smartbiztracker_new/services/supabase_orders_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/providers/app_settings_provider.dart';
import 'package:smartbiztracker_new/providers/simplified_product_provider.dart';

class ClientOrdersProvider with ChangeNotifier {

  // تهيئة Provider وتحميل السلة المحفوظة
  ClientOrdersProvider() {
    _loadCartFromStorage();
  }
  final client_service.ClientOrdersService _ordersService = client_service.ClientOrdersService();
  final SupabaseOrdersService _supabaseOrdersService = SupabaseOrdersService();
  static const String _cartKey = 'cart_items';

  // إعداد لاختيار نوع الخدمة
  bool _useSupabase = true; // تغيير إلى true لاستخدام Supabase

  List<ClientOrder> _orders = [];
  List<client_service.CartItem> _cartItems = [];
  bool _isLoading = false;
  String? _error;
  ClientOrder? _selectedOrder;
  SimplifiedProductProvider? _productProvider;

  // Getters
  List<ClientOrder> get orders => _orders;
  List<client_service.CartItem> get cartItems => _cartItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ClientOrder? get selectedOrder => _selectedOrder;
  bool get isUsingSupabase => _useSupabase;

  int get cartItemsCount => _cartItems.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotal => _cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  double get totalAmount => cartTotal; // Alias for compatibility

  // Voucher-related getters
  double get totalOriginalAmount => _cartItems.fold(0.0, (sum, item) => sum + item.totalOriginalPrice);
  double get totalSavings => _cartItems.fold(0.0, (sum, item) => sum + item.totalSavings);
  bool get hasVoucherItems => _cartItems.any((item) => item.hasVoucherDiscount);

  List<client_service.CartItem> get voucherItems => _cartItems.where((item) => item.hasVoucherDiscount).toList();
  List<client_service.CartItem> get regularItems => _cartItems.where((item) => !item.hasVoucherDiscount).toList();

  // Set product provider for stock validation
  void setProductProvider(SimplifiedProductProvider productProvider) {
    _productProvider = productProvider;
  }

  // Validate stock availability for a product
  bool _validateStock(String productId, int requestedQuantity) {
    if (_productProvider == null) {
      AppLogger.warning('Product provider not set for stock validation');
      return true; // Allow if no provider is set (fallback)
    }

    final product = _productProvider!.getProductById(productId);
    if (product == null) {
      AppLogger.warning('Product not found for stock validation: $productId');
      return false;
    }

    return product.quantity >= requestedQuantity;
  }

  // Get available stock for a product
  int _getAvailableStock(String productId) {
    if (_productProvider == null) return 999; // Fallback

    final product = _productProvider!.getProductById(productId);
    return product?.quantity ?? 0;
  }

  // Check if adding quantity would exceed stock
  bool _wouldExceedStock(String productId, int additionalQuantity) {
    final currentCartQuantity = getProductQuantity(productId);
    final totalRequested = currentCartQuantity + additionalQuantity;
    return !_validateStock(productId, totalRequested);
  }

  // Set AppSettingsProvider for automatic price hiding during pricing approval
  void setAppSettingsProvider(AppSettingsProvider provider) {
    _supabaseOrdersService.setAppSettingsProvider(provider);
  }

  // تحميل السلة من التخزين المحلي
  Future<void> _loadCartFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_cartKey);

      if (cartJson != null) {
        final List<dynamic> cartList = json.decode(cartJson) as List<dynamic>;
        _cartItems = cartList.map((item) => client_service.CartItem.fromJson(item as Map<String, dynamic>)).toList();
        AppLogger.info('Cart loaded from storage: ${_cartItems.length} items');
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Error loading cart from storage: $e');
    }
  }

  // حفظ السلة في التخزين المحلي
  Future<void> _saveCartToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode(_cartItems.map((item) => item.toJson()).toList());
      await prefs.setString(_cartKey, cartJson);
      AppLogger.info('Cart saved to storage: ${_cartItems.length} items');
    } catch (e) {
      AppLogger.error('Error saving cart to storage: $e');
    }
  }

  // إضافة منتج للسلة مع التحقق من المخزون
  bool addToCart(client_service.CartItem item) {
    // التحقق من توفر المخزون
    if (_wouldExceedStock(item.productId, item.quantity)) {
      final availableStock = _getAvailableStock(item.productId);
      final currentCartQuantity = getProductQuantity(item.productId);
      final maxCanAdd = availableStock - currentCartQuantity;

      AppLogger.warning('Cannot add ${item.quantity} of ${item.productName}. Available: $availableStock, In cart: $currentCartQuantity, Max can add: $maxCanAdd');
      _error = maxCanAdd > 0
          ? 'يمكن إضافة $maxCanAdd قطعة فقط من ${item.productName}'
          : 'لا يمكن إضافة المزيد من ${item.productName}. المخزون المتاح: $availableStock';
      notifyListeners();
      return false;
    }

    final existingIndex = _cartItems.indexWhere((cartItem) => cartItem.productId == item.productId);

    if (existingIndex >= 0) {
      // إذا كان المنتج موجود، زيادة الكمية مع الحفاظ على معلومات القسيمة
      final existingItem = _cartItems[existingIndex];
      _cartItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + item.quantity,
      );
      AppLogger.info('Updated existing cart item: ${item.productName} (New quantity: ${_cartItems[existingIndex].quantity})');
    } else {
      // إضافة منتج جديد
      _cartItems.add(item);
      AppLogger.info('Added new cart item: ${item.productName} (Quantity: ${item.quantity})');
    }

    _error = null; // Clear any previous errors
    _saveCartToStorage(); // حفظ السلة
    notifyListeners();
    AppLogger.info('Product added to cart: ${item.productName} (Total: ${_cartItems.length} items)');
    return true;
  }

  // إزالة منتج من السلة
  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.productId == productId);
    _saveCartToStorage(); // حفظ السلة
    notifyListeners();
    AppLogger.info('Product removed from cart: $productId (Remaining: ${_cartItems.length} items)');
  }

  // تحديث كمية منتج في السلة مع التحقق من المخزون
  bool updateCartItemQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return true;
    }

    // التحقق من توفر المخزون
    if (!_validateStock(productId, quantity)) {
      final availableStock = _getAvailableStock(productId);
      _error = 'الكمية المطلوبة ($quantity) تتجاوز المخزون المتاح ($availableStock)';
      notifyListeners();
      return false;
    }

    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      // استخدام copyWith للحفاظ على جميع معلومات القسيمة
      _cartItems[index] = _cartItems[index].copyWith(quantity: quantity);
      _error = null; // Clear any previous errors
      _saveCartToStorage(); // حفظ السلة
      notifyListeners();
      AppLogger.info('Updated cart item quantity: ${_cartItems[index].productName} to $quantity');
      return true;
    }
    return false;
  }

  // زيادة كمية منتج في السلة مع التحقق من المخزون
  bool increaseQuantity(String productId) {
    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      return updateCartItemQuantity(productId, _cartItems[index].quantity + 1);
    }
    return false;
  }

  // تقليل كمية منتج في السلة
  bool decreaseQuantity(String productId) {
    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      return updateCartItemQuantity(productId, _cartItems[index].quantity - 1);
    }
    return false;
  }

  // Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // مسح السلة
  void clearCart() {
    _cartItems.clear();
    _saveCartToStorage(); // حفظ السلة
    notifyListeners();
    AppLogger.info('Cart cleared');
  }

  // التحقق من وجود منتج في السلة
  bool isProductInCart(String productId) {
    return _cartItems.any((item) => item.productId == productId);
  }

  // الحصول على كمية منتج في السلة
  int getProductQuantity(String productId) {
    final item = _cartItems.firstWhere(
      (item) => item.productId == productId,
      orElse: () => client_service.CartItem(
        productId: '',
        productName: '',
        productImage: '',
        price: 0,
        quantity: 0,
        category: '',
      ),
    );
    return item.productId.isNotEmpty ? item.quantity : 0;
  }

  // تعيين عناصر السلة (لاستخدامها مع السلة من CustomerCartProvider)
  void setCartItems(List<client_service.CartItem> items) {
    _cartItems = List.from(items);
    _saveCartToStorage();
    notifyListeners();
    AppLogger.info('Cart items set: ${_cartItems.length} items');
  }

  /// REQUIREMENT 4: Simplified order submission for cart screen
  Future<void> submitOrder({String? clientId, String? clientName, String? clientEmail, String? clientPhone}) async {
    // Use provided client information or default values
    final orderId = await createOrder(
      clientId: clientId ?? 'client_001', // Default client ID
      clientName: clientName ?? 'عميل افتراضي', // Default client name
      clientEmail: clientEmail ?? 'client@example.com',
      clientPhone: clientPhone ?? '01000000000',
      notes: 'طلب من سلة التسوق',
    );

    if (orderId == null) {
      throw Exception(_error ?? 'فشل في إرسال الطلب');
    }
  }

  // إنشاء طلب جديد
  Future<String?> createOrder({
    required String clientId,
    required String clientName,
    required String clientEmail,
    required String clientPhone,
    String? notes,
    String? shippingAddress,
    Map<String, dynamic>? metadata,
  }) async {
    // التحقق من وجود عناصر في السلة
    if (_cartItems.isEmpty) {
      _error = 'السلة فارغة';
      notifyListeners();
      AppLogger.warning('⚠️ محاولة إنشاء طلب بسلة فارغة');
      return null;
    }

    // التحقق من صحة البيانات المطلوبة
    if (clientId.isEmpty || clientName.isEmpty) {
      _error = 'بيانات العميل غير مكتملة';
      notifyListeners();
      AppLogger.error('❌ بيانات العميل غير مكتملة - ID: $clientId, Name: $clientName');
      return null;
    }

    AppLogger.info('🚀 بدء إنشاء طلب جديد للعميل: $clientName ($clientId)');
    AppLogger.info('📦 عدد العناصر في السلة: ${_cartItems.length}');

    _setLoading(true);
    _error = null;

    try {
      String? orderId;

      if (_useSupabase) {
        // استخدام خدمة Supabase
        AppLogger.info('📦 إنشاء طلب في Supabase...');
        orderId = await _supabaseOrdersService.createOrder(
          clientId: clientId,
          clientName: clientName,
          clientEmail: clientEmail,
          clientPhone: clientPhone,
          cartItems: _cartItems,
          notes: notes,
          shippingAddress: shippingAddress,
          metadata: metadata,
        );
      } else {
        // استخدام الخدمة القديمة كـ fallback
        AppLogger.info('📦 إنشاء طلب في الخدمة القديمة...');
        orderId = await _ordersService.createOrder(
          clientId: clientId,
          clientName: clientName,
          clientEmail: clientEmail,
          clientPhone: clientPhone,
          cartItems: _cartItems,
          notes: notes,
          shippingAddress: shippingAddress,
        );
      }

      if (orderId != null && orderId.isNotEmpty) {
        AppLogger.info('✅ تم إنشاء الطلب بنجاح: $orderId');

        // مسح السلة بعد إنشاء الطلب بنجاح
        clearCart();
        AppLogger.info('🧹 تم مسح السلة بعد إنشاء الطلب');

        // Skip loading client orders to prevent hanging
        // The order was created successfully, no need to reload the list immediately
        AppLogger.info('🔄 تخطي تحديث قائمة الطلبات لتجنب التعليق');

        return orderId;
      } else {
        _error = 'فشل في إنشاء الطلب - لم يتم إرجاع معرف صحيح';
        AppLogger.error('❌ فشل في إنشاء الطلب - معرف الطلب فارغ أو null');
        return null;
      }
    } catch (e) {
      _error = 'خطأ في إنشاء الطلب: $e';
      AppLogger.error('❌ خطأ في إنشاء الطلب: $e');

      // إضافة تفاصيل إضافية للتشخيص
      if (e.toString().contains('JWT')) {
        AppLogger.error('🔐 خطأ في المصادقة - قد تحتاج لإعادة تسجيل الدخول');
        _error = 'خطأ في المصادقة - يرجى إعادة تسجيل الدخول';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        AppLogger.error('🌐 خطأ في الاتصال بالشبكة');
        _error = 'خطأ في الاتصال - تحقق من الإنترنت';
      }

      return null;
    } finally {
      _setLoading(false);
      AppLogger.info('🏁 انتهاء عملية إنشاء الطلب');
    }
  }

  // جلب طلبات العميل
  Future<void> loadClientOrders(String clientId) async {
    _setLoading(true);
    _error = null;

    try {
      if (_useSupabase) {
        _orders = await _supabaseOrdersService.getClientOrders(clientId);
        AppLogger.info('📦 تم جلب ${_orders.length} طلب من Supabase للعميل: $clientId');
      } else {
        _orders = await _ordersService.getClientOrders(clientId);
        AppLogger.info('📦 تم جلب ${_orders.length} طلب من الخدمة القديمة للعميل: $clientId');
      }
    } catch (e) {
      _error = 'فشل في جلب الطلبات: $e';
      AppLogger.error('❌ خطأ في جلب طلبات العميل: $e');
    } finally {
      _setLoading(false);
    }
  }

  // جلب جميع الطلبات (للإدارة)
  Future<void> loadAllOrders() async {
    _setLoading(true);
    _error = null;

    try {
      if (_useSupabase) {
        _orders = await _supabaseOrdersService.getAllOrders();
        AppLogger.info('📦 تم جلب ${_orders.length} طلب من Supabase');
      } else {
        _orders = await _ordersService.getAllOrders();
        AppLogger.info('📦 تم جلب ${_orders.length} طلب من الخدمة القديمة');
      }
    } catch (e) {
      _error = 'فشل في جلب الطلبات: $e';
      AppLogger.error('❌ خطأ في جلب جميع الطلبات: $e');
    } finally {
      _setLoading(false);
    }
  }

  // تحديث حالة الطلب
  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    _setLoading(true);
    _error = null;

    try {
      bool success;

      if (_useSupabase) {
        success = await _supabaseOrdersService.updateOrderStatus(orderId, status);
        AppLogger.info('📦 تم تحديث حالة الطلب في Supabase: $orderId إلى $status');
      } else {
        success = await _ordersService.updateOrderStatus(orderId, status);
        AppLogger.info('📦 تم تحديث حالة الطلب في الخدمة القديمة: $orderId إلى $status');
      }

      if (success) {
        // تحديث الطلب في القائمة المحلية
        final index = _orders.indexWhere((order) => order.id == orderId);
        if (index >= 0) {
          _orders[index] = _orders[index].copyWith(
            status: status,
            updatedAt: DateTime.now(),
          );
        }

        // تحديث الطلب المحدد إذا كان نفس الطلب
        if (_selectedOrder?.id == orderId) {
          _selectedOrder = _selectedOrder!.copyWith(
            status: status,
            updatedAt: DateTime.now(),
          );
        }

        AppLogger.info('✅ تم تحديث حالة الطلب: $orderId إلى $status');
      } else {
        _error = 'فشل في تحديث حالة الطلب';
      }

      return success;
    } catch (e) {
      _error = 'حدث خطأ أثناء تحديث حالة الطلب: $e';
      AppLogger.error('❌ خطأ في تحديث حالة الطلب: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // إضافة رابط متابعة
  Future<bool> addTrackingLink({
    required String orderId,
    required String url,
    required String title,
    required String description,
    required String createdBy,
    String linkType = 'tracking',
  }) async {
    _setLoading(true);
    _error = null;

    try {
      bool success;

      if (_useSupabase) {
        success = await _supabaseOrdersService.addTrackingLink(
          orderId: orderId,
          url: url,
          title: title,
          description: description,
          createdBy: createdBy,
          linkType: linkType,
        );
        AppLogger.info('📦 تم إضافة رابط المتابعة في Supabase: $orderId');
      } else {
        success = await _ordersService.addTrackingLink(
          orderId: orderId,
          url: url,
          title: title,
          description: description,
          createdBy: createdBy,
        );
        AppLogger.info('📦 تم إضافة رابط المتابعة في الخدمة القديمة: $orderId');
      }

      if (success) {
        // إعادة تحميل تفاصيل الطلب لتحديث روابط المتابعة
        await loadOrderDetails(orderId);
        AppLogger.info('✅ تم إضافة رابط المتابعة: $orderId');
      } else {
        _error = 'فشل في إضافة رابط المتابعة';
      }

      return success;
    } catch (e) {
      _error = 'حدث خطأ أثناء إضافة رابط المتابعة: $e';
      AppLogger.error('❌ خطأ في إضافة رابط المتابعة: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // جلب تفاصيل طلب محدد
  Future<void> loadOrderDetails(String orderId) async {
    _setLoading(true);
    _error = null;

    try {
      if (_useSupabase) {
        _selectedOrder = await _supabaseOrdersService.getOrderById(orderId);
        AppLogger.info('📦 تم جلب تفاصيل الطلب من Supabase: $orderId');
      } else {
        _selectedOrder = await _ordersService.getOrderById(orderId);
        AppLogger.info('📦 تم جلب تفاصيل الطلب من الخدمة القديمة: $orderId');
      }

      if (_selectedOrder != null) {
        // تحديث الطلب في القائمة المحلية أيضاً
        final index = _orders.indexWhere((order) => order.id == orderId);
        if (index >= 0) {
          _orders[index] = _selectedOrder!;
        }

        AppLogger.info('✅ تم تحميل تفاصيل الطلب: $orderId');
      } else {
        _error = 'لم يتم العثور على الطلب';
      }
    } catch (e) {
      _error = 'فشل في جلب تفاصيل الطلب: $e';
      AppLogger.error('Error loading order details: $e');
    } finally {
      _setLoading(false);
    }
  }

  // تعيين طلب لموظف
  Future<bool> assignOrderTo(String orderId, String assignedTo) async {
    _setLoading(true);
    _error = null;

    try {
      final success = await _ordersService.assignOrderTo(orderId, assignedTo);

      if (success) {
        // تحديث الطلب في القائمة المحلية
        final index = _orders.indexWhere((order) => order.id == orderId);
        if (index >= 0) {
          _orders[index] = _orders[index].copyWith(
            assignedTo: assignedTo,
            updatedAt: DateTime.now(),
          );
        }

        AppLogger.info('Order assigned: $orderId to $assignedTo');
      } else {
        _error = 'فشل في تعيين الطلب';
      }

      return success;
    } catch (e) {
      _error = 'حدث خطأ أثناء تعيين الطلب: $e';
      AppLogger.error('Error assigning order: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // مساعد لتعيين حالة التحميل
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // دوال جديدة خاصة بـ Supabase

  /// تحديث حالة الدفع
  Future<bool> updatePaymentStatus(String orderId, PaymentStatus paymentStatus) async {
    if (!_useSupabase) {
      AppLogger.warning('⚠️ تحديث حالة الدفع متاح فقط مع Supabase');
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final success = await _supabaseOrdersService.updatePaymentStatus(orderId, paymentStatus);

      if (success) {
        // تحديث الطلب في القائمة المحلية
        final index = _orders.indexWhere((order) => order.id == orderId);
        if (index >= 0) {
          _orders[index] = _orders[index].copyWith(
            paymentStatus: paymentStatus,
            updatedAt: DateTime.now(),
          );
        }

        // تحديث الطلب المحدد إذا كان نفس الطلب
        if (_selectedOrder?.id == orderId) {
          _selectedOrder = _selectedOrder!.copyWith(
            paymentStatus: paymentStatus,
            updatedAt: DateTime.now(),
          );
        }

        AppLogger.info('✅ تم تحديث حالة الدفع: $orderId إلى $paymentStatus');
      } else {
        _error = 'فشل في تحديث حالة الدفع';
      }

      return success;
    } catch (e) {
      _error = 'حدث خطأ أثناء تحديث حالة الدفع: $e';
      AppLogger.error('❌ خطأ في تحديث حالة الدفع: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// جلب تاريخ الطلب
  Future<List<Map<String, dynamic>>> getOrderHistory(String orderId) async {
    if (!_useSupabase) {
      AppLogger.warning('⚠️ تاريخ الطلبات متاح فقط مع Supabase');
      return [];
    }

    try {
      final history = await _supabaseOrdersService.getOrderHistory(orderId);
      AppLogger.info('✅ تم جلب ${history.length} سجل من تاريخ الطلب: $orderId');
      return history;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب تاريخ الطلب: $e');
      return [];
    }
  }

  /// جلب إشعارات المستخدم
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId, {bool unreadOnly = false}) async {
    if (!_useSupabase) {
      AppLogger.warning('⚠️ الإشعارات متاحة فقط مع Supabase');
      return [];
    }

    try {
      final notifications = await _supabaseOrdersService.getUserNotifications(userId, unreadOnly: unreadOnly);
      AppLogger.info('✅ تم جلب ${notifications.length} إشعار للمستخدم: $userId');
      return notifications;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب الإشعارات: $e');
      return [];
    }
  }

  /// تحديد إشعار كمقروء
  Future<bool> markNotificationAsRead(String notificationId) async {
    if (!_useSupabase) {
      AppLogger.warning('⚠️ الإشعارات متاحة فقط مع Supabase');
      return false;
    }

    try {
      final success = await _supabaseOrdersService.markNotificationAsRead(notificationId);
      if (success) {
        AppLogger.info('✅ تم تحديث الإشعار كمقروء: $notificationId');
      }
      return success;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث الإشعار: $e');
      return false;
    }
  }

  /// جلب إحصائيات الطلبات
  Future<Map<String, dynamic>?> getOrderStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_useSupabase) {
      AppLogger.warning('⚠️ الإحصائيات متاحة فقط مع Supabase');
      return null;
    }

    try {
      final stats = await _supabaseOrdersService.getOrderStatistics(
        startDate: startDate,
        endDate: endDate,
      );

      if (stats != null) {
        AppLogger.info('✅ تم جلب إحصائيات الطلبات');
      }

      return stats;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب الإحصائيات: $e');
      return null;
    }
  }

  /// تبديل نوع الخدمة (Supabase أو القديمة)
  void toggleServiceType() {
    _useSupabase = !_useSupabase;
    AppLogger.info('🔄 تم تبديل نوع الخدمة إلى: ${_useSupabase ? "Supabase" : "الخدمة القديمة"}');
    notifyListeners();
  }



  @override
  void dispose() {
    _ordersService.dispose();
    _supabaseOrdersService.dispose();
    super.dispose();
  }
}
