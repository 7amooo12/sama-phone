import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:uuid/uuid.dart';

class ClientOrdersService {
  static const String _baseUrl = 'https://samastock.pythonanywhere.com';
  static const String _ordersEndpoint = '/api/client-orders';
  static const String _trackingEndpoint = '/api/tracking-links';

  final http.Client _client = http.Client();
  final Uuid _uuid = const Uuid();

  // إنشاء طلب جديد
  Future<String?> createOrder({
    required String clientId,
    required String clientName,
    required String clientEmail,
    required String clientPhone,
    required List<CartItem> cartItems,
    String? notes,
    String? shippingAddress,
  }) async {
    try {
      // تحويل عناصر السلة إلى عناصر الطلب
      final orderItems = cartItems.map((cartItem) => OrderItem(
        id: null, // Will be set by database when order is created
        productId: cartItem.productId,
        productName: cartItem.productName,
        productImage: cartItem.productImage,
        price: cartItem.price,
        quantity: cartItem.quantity,
        total: cartItem.price * cartItem.quantity,
      )).toList();

      // حساب المجموع الإجمالي
      final total = orderItems.fold<double>(0, (sum, item) => sum + item.total);

      final order = ClientOrder(
        id: _uuid.v4(),
        clientId: clientId,
        clientName: clientName,
        clientEmail: clientEmail,
        clientPhone: clientPhone,
        items: orderItems,
        total: total,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        createdAt: DateTime.now(),
        notes: notes,
        shippingAddress: shippingAddress,
        trackingLinks: [],
      );

      final response = await _client.post(
        Uri.parse('$_baseUrl$_ordersEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(order.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        AppLogger.info('Order created successfully: ${order.id}');
        return responseData['order_id'] ?? order.id;
      } else {
        AppLogger.error('Failed to create order: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Error creating order: $e');
      return null;
    }
  }

  // جلب طلبات العميل
  Future<List<ClientOrder>> getClientOrders(String clientId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$_ordersEndpoint/client/$clientId'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> ordersJson = jsonDecode(response.body);
        final orders = ordersJson.map((json) => ClientOrder.fromJson(json)).toList();

        // ترتيب الطلبات حسب التاريخ (الأحدث أولاً)
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return orders;
      } else {
        AppLogger.error('Failed to fetch client orders: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      AppLogger.error('Error fetching client orders: $e');
      return [];
    }
  }

  // جلب جميع الطلبات (للإدارة)
  Future<List<ClientOrder>> getAllOrders() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$_ordersEndpoint'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> ordersJson = jsonDecode(response.body);
        final orders = ordersJson.map((json) => ClientOrder.fromJson(json)).toList();

        // ترتيب الطلبات حسب التاريخ (الأحدث أولاً)
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return orders;
      } else {
        AppLogger.error('Failed to fetch all orders: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      AppLogger.error('Error fetching all orders: $e');
      return [];
    }
  }

  // تحديث حالة الطلب
  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      final response = await _client.patch(
        Uri.parse('$_baseUrl$_ordersEndpoint/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'status': status.toString().split('.').last,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Order status updated successfully: $orderId');
        return true;
      } else {
        AppLogger.error('Failed to update order status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error updating order status: $e');
      return false;
    }
  }

  // إضافة رابط متابعة
  Future<bool> addTrackingLink({
    required String orderId,
    required String url,
    required String title,
    required String description,
    required String createdBy,
  }) async {
    try {
      final trackingLink = TrackingLink(
        id: _uuid.v4(),
        url: url,
        title: title,
        description: description,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      );

      final response = await _client.post(
        Uri.parse('$_baseUrl$_trackingEndpoint/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(trackingLink.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        AppLogger.info('Tracking link added successfully: $orderId');
        return true;
      } else {
        AppLogger.error('Failed to add tracking link: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error adding tracking link: $e');
      return false;
    }
  }

  // جلب تفاصيل طلب محدد
  Future<ClientOrder?> getOrderById(String orderId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$_ordersEndpoint/$orderId'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final orderJson = jsonDecode(response.body);
        return ClientOrder.fromJson(orderJson);
      } else {
        AppLogger.error('Failed to fetch order: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Error fetching order: $e');
      return null;
    }
  }

  // تعيين طلب لموظف
  Future<bool> assignOrderTo(String orderId, String assignedTo) async {
    try {
      final response = await _client.patch(
        Uri.parse('$_baseUrl$_ordersEndpoint/$orderId/assign'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'assigned_to': assignedTo,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Order assigned successfully: $orderId to $assignedTo');
        return true;
      } else {
        AppLogger.error('Failed to assign order: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error assigning order: $e');
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}

// نموذج عنصر السلة مع دعم القسائم
class CartItem { // إضافة خاصية الفئة ومعلومات القسيمة

  CartItem({
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.quantity,
    required this.category, // إضافة الفئة كمعامل مطلوب
    this.originalPrice, // السعر الأصلي قبل الخصم
    this.discountAmount, // مقدار الخصم
    this.voucherCode, // كود القسيمة المطبقة
    this.voucherName, // اسم القسيمة المطبقة
    this.discountPercentage, // نسبة الخصم
    this.isVoucherItem = false, // Flag to identify voucher cart items
  });

  factory CartItem.fromProduct(ProductModel product, int quantity) {
    return CartItem(
      productId: product.id,
      productName: product.name,
      productImage: product.bestImageUrl,
      price: product.price,
      quantity: quantity,
      category: product.category, // إضافة الفئة من المنتج
      isVoucherItem: false,
    );
  }

  // Factory method for creating cart item with voucher discount
  factory CartItem.fromProductWithVoucher({
    required ProductModel product,
    required int quantity,
    required double discountedPrice,
    required double originalPrice,
    required String voucherCode,
    required String voucherName,
    required double discountPercentage,
  }) {
    final discountAmount = originalPrice - discountedPrice;
    return CartItem(
      productId: product.id,
      productName: product.name,
      productImage: product.bestImageUrl,
      price: discountedPrice, // Use discounted price as the main price
      quantity: quantity,
      category: product.category,
      originalPrice: originalPrice,
      discountAmount: discountAmount,
      voucherCode: voucherCode,
      voucherName: voucherName,
      discountPercentage: discountPercentage,
      isVoucherItem: true, // Mark as voucher item
    );
  }

  // إنشاء من JSON
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: (json['productId'] ?? '').toString(),
      productName: (json['productName'] ?? '').toString(),
      productImage: (json['productImage'] ?? '').toString(),
      price: (json['price'] as num? ?? 0).toDouble(),
      quantity: (json['quantity'] as num? ?? 1).toInt(),
      category: (json['category'] ?? '').toString(), // إضافة الفئة من JSON
      originalPrice: json['originalPrice'] != null ? (json['originalPrice'] as num).toDouble() : null,
      discountAmount: json['discountAmount'] != null ? (json['discountAmount'] as num).toDouble() : null,
      voucherCode: json['voucherCode'] as String?,
      voucherName: json['voucherName'] as String?,
      discountPercentage: json['discountPercentage'] != null ? (json['discountPercentage'] as num).toDouble() : null,
      isVoucherItem: json['isVoucherItem'] == true,
    );
  }
  final String productId;
  final String productName;
  final String productImage;
  final double price;
  final int quantity;
  final String category;
  final double? originalPrice; // السعر الأصلي قبل الخصم
  final double? discountAmount; // مقدار الخصم
  final String? voucherCode; // كود القسيمة المطبقة
  final String? voucherName; // اسم القسيمة المطبقة
  final double? discountPercentage; // نسبة الخصم
  final bool isVoucherItem; // Flag to identify voucher cart items

  // تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'price': price,
      'quantity': quantity,
      'category': category, // إضافة الفئة إلى JSON
      'originalPrice': originalPrice,
      'discountAmount': discountAmount,
      'voucherCode': voucherCode,
      'voucherName': voucherName,
      'discountPercentage': discountPercentage,
      'isVoucherItem': isVoucherItem,
    };
  }

  // نسخ مع تعديل
  CartItem copyWith({
    String? productId,
    String? productName,
    String? productImage,
    double? price,
    int? quantity,
    String? category,
    double? originalPrice,
    double? discountAmount,
    String? voucherCode,
    String? voucherName,
    double? discountPercentage,
    bool? isVoucherItem,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category, // إضافة الفئة إلى copyWith
      originalPrice: originalPrice ?? this.originalPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      voucherCode: voucherCode ?? this.voucherCode,
      voucherName: voucherName ?? this.voucherName,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      isVoucherItem: isVoucherItem ?? this.isVoucherItem,
    );
  }

  // Helper methods for voucher functionality
  bool get hasVoucherDiscount => voucherCode != null && discountAmount != null && discountAmount! > 0;

  double get totalSavings => hasVoucherDiscount ? (discountAmount! * quantity) : 0.0;

  double get totalPrice => price * quantity;

  double get totalOriginalPrice => hasVoucherDiscount ? (originalPrice! * quantity) : totalPrice;
}
