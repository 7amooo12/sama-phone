import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/models/models.dart';
import 'package:smartbiztracker_new/services/database_service.dart';
import 'package:smartbiztracker_new/services/notification_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/order_model.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../utils/app_logger.dart';

class OrderProvider with ChangeNotifier {

  OrderProvider(this._databaseService);
  final DatabaseService _databaseService;
  final NotificationService _notificationService = NotificationService();
  final ApiService _apiService = ApiService();

  List<OrderModel> _orders = [];
  List<OrderModel> _clientOrders = [];
  List<OrderModel> _workerOrders = [];
  List<OrderModel> _unassignedOrders = [];
  OrderModel? _selectedOrder;
  bool _isLoading = false;
  String? _error;

  List<OrderModel> get orders => _orders;
  List<OrderModel> get clientOrders => _clientOrders;
  List<OrderModel> get workerOrders => _workerOrders;
  List<OrderModel> get unassignedOrders => _unassignedOrders;
  OrderModel? get selectedOrder => _selectedOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadOrders() async {
    try {
      _isLoading = true;
      notifyListeners();

      final ordersList = await _databaseService.getAllOrders();
      _orders = ordersList;
      _error = null;
    } catch (e) {
      _error = 'Error loading orders: $e';
      AppLogger.error(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadClientOrders(String clientId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final ordersList = await _databaseService.getOrdersByClient(clientId);
      _clientOrders = ordersList;
      _error = null;
    } catch (e) {
      _error = 'Error loading client orders: $e';
      AppLogger.error(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWorkerOrders(String workerId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final ordersList = await _databaseService.getOrdersByWorker(workerId);
      _workerOrders = ordersList;
      _error = null;
    } catch (e) {
      _error = 'Error loading worker orders: $e';
      AppLogger.error(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUnassignedOrders() async {
    try {
      _isLoading = true;
      notifyListeners();

      final ordersList = await _databaseService.getUnassignedOrders();
      _unassignedOrders = ordersList;
      _error = null;
    } catch (e) {
      _error = 'Error loading unassigned orders: $e';
      AppLogger.error(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addOrder(OrderModel order) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.addOrder(order);
      await loadOrders();
      _error = null;
    } catch (e) {
      _error = 'Error adding order: $e';
      AppLogger.error(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateOrder(OrderModel order) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.updateOrder(order);
      await loadOrders();
      _error = null;
    } catch (e) {
      _error = 'Error updating order: $e';
      AppLogger.error(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> assignWorkerToOrder(String orderId, String workerId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.assignWorkerToOrder(orderId, workerId);
      await loadOrders();
      _error = null;
    } catch (e) {
      _error = 'Error assigning worker to order: $e';
      AppLogger.error(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.deleteOrder(orderId);
      await loadOrders();
      _error = null;
    } catch (e) {
      _error = 'Error deleting order: $e';
      AppLogger.error(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get order by ID
  Future<OrderModel?> getOrderById(String orderId) async {
    _setLoading(true);
    _clearError();

    try {
      // Check in all order lists
      for (final orders in [
        _orders,
        _clientOrders,
        _workerOrders,
        _unassignedOrders
      ]) {
        for (final order in orders) {
          if (order.id == orderId) {
            _selectedOrder = order;
            notifyListeners();
            return order;
          }
        }
      }

      return null;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Place order
  Future<String?> placeOrder({
    required String clientId,
    required String clientName,
    required List<OrderItem> items,
    required double totalAmount,
    String? notes,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Create order model
      final OrderModel order = OrderModel(
        id: '',
        orderNumber: DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8),
        customerName: clientName,
        customerPhone: '',
        status: OrderStatus.pending,
        totalAmount: totalAmount,
        items: items,
        createdAt: DateTime.now(),
        notes: notes,
        clientId: clientId,
      );

      // Add order to Firestore
      final String orderId = await _databaseService.addOrder(order);

      if (orderId.isNotEmpty) {
        // Send notification to admins/owners
        // This would be implemented in a real app with actual admin IDs

        // Update selectedOrder
        _selectedOrder = order.copyWith(id: orderId);
        notifyListeners();

        return orderId;
      }

      return null;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Update order status
  Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
    required String clientId,
    String? message,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.updateOrderStatus(orderId, status);

      // Send notification to client
      await _notificationService.sendOrderNotification(
        orderId: orderId,
        customerName: clientId,
        status: status,
      );

      // Update order in lists
      _updateOrderStatusInLists(orderId, status);

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update tracking code
  Future<bool> updateTrackingNumber({
    required String orderId,
    required String trackingNumber,
    required String clientId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _databaseService.updateTrackingNumber(
        orderId,
        trackingNumber,
      );

      // Send notification to client
      await _notificationService.sendOrderNotification(
        orderId: orderId,
        customerName: clientId,
        status: 'shipped',
      );

      // Update order in lists
      final int allIndex =
          _orders.indexWhere((order) => order.id == orderId);
      if (allIndex != -1) {
        _orders[allIndex] = _orders[allIndex].copyWith(
          trackingNumber: trackingNumber,
        );
      }

      final int clientIndex =
          _clientOrders.indexWhere((order) => order.id == orderId);
      if (clientIndex != -1) {
        _clientOrders[clientIndex] = _clientOrders[clientIndex].copyWith(
          trackingNumber: trackingNumber,
        );
      }

      final int workerIndex =
          _workerOrders.indexWhere((order) => order.id == orderId);
      if (workerIndex != -1) {
        _workerOrders[workerIndex] = _workerOrders[workerIndex].copyWith(
          trackingNumber: trackingNumber,
        );
      }

      if (_selectedOrder?.id == orderId) {
        _selectedOrder = _selectedOrder!.copyWith(
          trackingNumber: trackingNumber,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Set selected order
  void setSelectedOrder(OrderModel order) {
    _selectedOrder = order;
    notifyListeners();
  }

  // Clear selected order
  void clearSelectedOrder() {
    _selectedOrder = null;
    notifyListeners();
  }

  // Update order status in all lists
  void _updateOrderStatusInLists(String orderId, String status,
      {String? workerId, String? trackingNumber}) {
    // Update in all orders
    for (int i = 0; i < _orders.length; i++) {
      if (_orders[i].id == orderId) {
        _orders[i] = _orders[i].copyWith(
          status: status,
          assignedTo: workerId ?? _orders[i].assignedTo,
          trackingNumber: trackingNumber ?? _orders[i].trackingNumber,
        );
        break;
      }
    }

    // Update in client orders
    for (int i = 0; i < _clientOrders.length; i++) {
      if (_clientOrders[i].id == orderId) {
        _clientOrders[i] = _clientOrders[i].copyWith(
          status: status,
          assignedTo: workerId ?? _clientOrders[i].assignedTo,
          trackingNumber: trackingNumber ?? _clientOrders[i].trackingNumber,
        );
        break;
      }
    }

    // Update in worker orders
    for (int i = 0; i < _workerOrders.length; i++) {
      if (_workerOrders[i].id == orderId) {
        _workerOrders[i] = _workerOrders[i].copyWith(
          status: status,
          trackingNumber: trackingNumber ?? _workerOrders[i].trackingNumber,
        );
        break;
      }
    }

    // Remove from unassigned if needed
    if (workerId != null) {
      _unassignedOrders.removeWhere((order) => order.id == orderId);
    }

    // Update selected order if it's the updated one
    if (_selectedOrder?.id == orderId) {
      _selectedOrder = _selectedOrder!.copyWith(
        status: status,
        assignedTo: workerId ?? _selectedOrder!.assignedTo,
        trackingNumber: trackingNumber ?? _selectedOrder!.trackingNumber,
      );
    }

    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Create a new order from cart items
  Future<OrderModel?> createOrder({
    required List<Product> products,
    required Map<int, int> quantities,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? notes,
    String? address,
    String? paymentMethod,
  }) async {
    setLoading(true);

    try {
      // Prepare order items
      final List<OrderItem> orderItems = [];
      double totalAmount = 0;

      for (final product in products) {
        final quantity = quantities[product.id] ?? 0;
        if (quantity <= 0) continue;

        final subtotal = product.price * quantity;
        totalAmount += subtotal;

        orderItems.add(OrderItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_${product.id}',
          productId: product.id.toString(),
          productName: product.name,
          price: product.price,
          quantity: quantity,
          subtotal: subtotal,
          imageUrl: product.imageUrl,
        ));
      }

      if (orderItems.isEmpty) {
        setError('لا يمكن إنشاء طلب بدون منتجات');
        setLoading(false);
        return null;
      }

      // Create order object
      final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 10)}';
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      final order = OrderModel(
        id: orderId,
        orderNumber: orderNumber,
        customerName: customerName,
        customerPhone: customerPhone,
        status: OrderStatus.pending,
        totalAmount: totalAmount,
        items: orderItems,
        createdAt: DateTime.now(),
        notes: notes,
        address: address,
        paymentMethod: paymentMethod,
      );

      // Send order to API
      final success = await _apiService.submitOrder(order);

      if (success) {
        _orders.add(order);
        notifyListeners();
        setLoading(false);
        return order;
      } else {
        setError('فشل في إرسال الطلب للخادم');
        setLoading(false);
        return null;
      }

    } catch (e) {
      setError('حدث خطأ: ${e.toString()}');
      setLoading(false);
      return null;
    }
  }

  // Create order from the SAMA Store API
  Future<OrderModel?> createSamaOrder({
    required List<Map<String, dynamic>> items,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? notes,
    String? address,
  }) async {
    setLoading(true);

    try {
      // Prepare API request
      const url = 'https://samastock.pythonanywhere.com/flutter/api/checkout';
      const headers = {
        'Content-Type': 'application/json',
        'x-api-key': 'lux2025FlutterAccess',
      };

      final body = jsonEncode({
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_email': customerEmail ?? '',
        'notes': notes ?? '',
        'items': items,
        'address': address ?? '',
      });

      // Make API request
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          // Create order model from response
          final invoiceId = responseData['invoice_id'];
          final orderNumber = 'SMO-$invoiceId';

          // Get order details
          final orderDetails = await getSamaOrderDetails((invoiceId as num?)?.toInt() ?? 0);

          if (orderDetails != null) {
            _orders.add(orderDetails);
            notifyListeners();
            setLoading(false);
            return orderDetails;
          }

          // If we can't get order details, create a simplified order object
          final order = OrderModel(
            id: invoiceId.toString(),
            orderNumber: orderNumber,
            customerName: customerName,
            customerPhone: customerPhone,
            status: OrderStatus.pending,
            totalAmount: (responseData['total'] as num?)?.toDouble() ?? 0.0,
            items: _createOrderItemsFromRequestItems(items),
            createdAt: DateTime.now(),
            notes: notes,
            address: address,
          );

          _orders.add(order);
          notifyListeners();
          setLoading(false);
          return order;
        } else {
          setError(responseData['message']?.toString() ?? 'فشل في إنشاء الطلب');
          setLoading(false);
          return null;
        }
      } else {
        setError('فشل في الاتصال بالخادم: ${response.statusCode}');
        setLoading(false);
        return null;
      }
    } catch (e) {
      AppLogger.error('Error creating SAMA order', e);
      setError('حدث خطأ: ${e.toString()}');
      setLoading(false);
      return null;
    }
  }

  // Helper method to create order items from request items
  List<OrderItem> _createOrderItemsFromRequestItems(List<Map<String, dynamic>> items) {
    return items.map((item) {
      final productId = item['product_id']?.toString() ?? '';
      final productName = item['product_name']?.toString() ?? 'منتج';
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      final subtotal = price * quantity;

      return OrderItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_$productId',
        productId: productId,
        productName: productName,
        description: item['description']?.toString(),
        price: price,
        quantity: quantity,
        subtotal: subtotal,
        imageUrl: item['image_url']?.toString(),
      );
    }).toList();
  }

  // Get order details
  Future<OrderModel?> getSamaOrderDetails(int orderId) async {
    try {
      final url = 'https://samastock.pythonanywhere.com/flutter/api/orders/$orderId';
      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': 'lux2025FlutterAccess',
      };

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final orderData = responseData['order'];

          // Parse items
          final List<OrderItem> orderItems = [];
          if (orderData['items'] != null) {
            for (final item in (orderData['items'] as List<dynamic>? ?? [])) {
              orderItems.add(OrderItem(
                id: item['id']?.toString() ?? '',
                productId: item['product_id']?.toString() ?? '',
                productName: item['product_name']?.toString() ?? 'منتج',
                price: (item['price'] as num?)?.toDouble() ?? 0.0,
                quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                subtotal: (item['total'] as num?)?.toDouble() ?? 0.0,
                imageUrl: item['image_url']?.toString(),
              ));
            }
          }

          // Create order model
          return OrderModel(
            id: orderData['id']?.toString() ?? '',
            orderNumber: 'SMO-${orderData['id']}',
            customerName: orderData['customer_name']?.toString() ?? '',
            customerPhone: orderData['customer_phone']?.toString() ?? '',
            status: _parseOrderStatusToString(orderData['status'] as String?),
            totalAmount: (orderData['final_amount'] as num?)?.toDouble() ?? 0.0,
            items: orderItems,
            createdAt: orderData['created_at'] != null
                ? DateTime.parse(orderData['created_at'].toString())
                : DateTime.now(),
            notes: orderData['notes']?.toString(),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error fetching order details', e);
    }

    return null;
  }

  // Get user orders
  Future<List<OrderModel>> getUserOrders(String userId) async {
    setLoading(true);

    try {
      const url = 'https://samastock.pythonanywhere.com/flutter/api/orders';
      const headers = {
        'Content-Type': 'application/json',
        'x-api-key': 'lux2025FlutterAccess',
      };

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final List<OrderModel> userOrders = [];

          for (final orderData in (responseData['orders'] as List<dynamic>? ?? [])) {
            // Parse items
            final List<OrderItem> orderItems = [];
            if (orderData['items'] != null) {
              for (final item in (orderData['items'] as List<dynamic>? ?? [])) {
                orderItems.add(OrderItem(
                  id: item['id']?.toString() ?? '',
                  productId: item['product_id']?.toString() ?? '',
                  productName: item['product_name']?.toString() ?? 'منتج',
                  price: (item['price'] as num?)?.toDouble() ?? 0.0,
                  quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                  subtotal: (item['total'] as num?)?.toDouble() ?? 0.0,
                  imageUrl: item['image_url']?.toString(),
                ));
              }
            }

            // Create order model
            final order = OrderModel(
              id: orderData['id']?.toString() ?? '',
              orderNumber: 'SMO-${orderData['id']}',
              customerName: orderData['customer_name']?.toString() ?? '',
              customerPhone: orderData['customer_phone']?.toString() ?? '',
              status: _parseOrderStatusToString(orderData['status'] as String?),
              totalAmount: (orderData['final_amount'] as num?)?.toDouble() ?? 0.0,
              items: orderItems,
              createdAt: orderData['created_at'] != null
                  ? DateTime.parse(orderData['created_at'].toString())
                  : DateTime.now(),
              notes: orderData['notes']?.toString(),
            );

            userOrders.add(order);
          }

          _orders = userOrders;
          notifyListeners();
          setLoading(false);
          return userOrders;
        }
      }

      // If we reach here, something went wrong
      setError('فشل في جلب الطلبات');
      setLoading(false);
      return [];

    } catch (e) {
      AppLogger.error('Error fetching user orders', e);
      setError('حدث خطأ: ${e.toString()}');
      setLoading(false);
      return [];
    }
  }

  // Cancel an order
  Future<bool> cancelOrder(String orderId) async {
    setLoading(true);

    try {
      // Send API request to cancel order
      final success = await _apiService.cancelOrder(orderId);

      if (success) {
        // Update local order status
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          final updatedOrder = OrderModel(
            id: _orders[index].id,
            orderNumber: _orders[index].orderNumber,
            customerName: _orders[index].customerName,
            customerPhone: _orders[index].customerPhone,
            status: 'cancelled',
            totalAmount: _orders[index].totalAmount,
            items: _orders[index].items,
            createdAt: _orders[index].createdAt,
            notes: _orders[index].notes,
            paymentMethod: _orders[index].paymentMethod,
            address: _orders[index].address,
            deliveryDate: _orders[index].deliveryDate,
          );

          _orders[index] = updatedOrder;
          notifyListeners();
        }

        setLoading(false);
        return true;
      } else {
        setError('فشل في إلغاء الطلب');
        setLoading(false);
        return false;
      }
    } catch (e) {
      setError('حدث خطأ: ${e.toString()}');
      setLoading(false);
      return false;
    }
  }

  // Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _error = null;
    }
    notifyListeners();
  }

  // Set error message
  void setError(String errorMsg) {
    _error = errorMsg;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Helper method to parse order status to string
  String _parseOrderStatusToString(String? status) {
    if (status == null) return 'pending';

    switch (status.toLowerCase()) {
      case 'pending':
        return 'pending';
      case 'confirmed':
        return 'confirmed';
      case 'processing':
        return 'processing';
      case 'shipped':
        return 'shipped';
      case 'delivered':
        return 'delivered';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  // Helper method to parse order status to string (for compatibility)
  String _parseOrderStatusToEnum(String? status) {
    if (status == null) return OrderStatus.pending;

    switch (status.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'processing':
        return OrderStatus.processing;
      case 'shipped':
        return OrderStatus.shipped;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}
