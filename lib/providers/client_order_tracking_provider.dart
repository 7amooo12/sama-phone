import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class ClientOrderTrackingProvider extends ChangeNotifier {
  final FlaskApiService _apiService = FlaskApiService();

  List<ClientOrder> _ordersWithTracking = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ClientOrder> get ordersWithTracking => _ordersWithTracking;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get ordersCount => _ordersWithTracking.length;

  // Load client orders with tracking links
  Future<void> loadClientOrdersWithTracking(String clientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔄 Loading client orders with tracking for client: $clientId');

      final ordersData = await _apiService.getClientOrdersWithTracking(clientId);

      _ordersWithTracking = ordersData.map((orderData) {
        try {
          return ClientOrder.fromJson(orderData);
        } catch (e) {
          AppLogger.error('Error parsing order data: $orderData', e);
          // Return a fallback order if parsing fails
          return ClientOrder(
            id: orderData['id']?.toString() ?? 'unknown',
            clientId: orderData['client_id']?.toString() ?? '',
            clientName: orderData['client_name']?.toString() ?? 'عميل غير معروف',
            clientEmail: orderData['client_email']?.toString() ?? '',
            clientPhone: orderData['client_phone']?.toString() ?? '',
            items: [],
            total: (orderData['total'] as num?)?.toDouble() ?? 0.0,
            status: _parseOrderStatus(orderData['status']?.toString()),
            paymentStatus: _parsePaymentStatus(orderData['payment_status']?.toString()),
            createdAt: DateTime.tryParse(orderData['created_at']?.toString() ?? '') ?? DateTime.now(),
            trackingLinks: _parseTrackingLinks(orderData['tracking_links']),
          );
        }
      }).toList();

      // Sort orders by creation date (newest first)
      _ordersWithTracking.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      AppLogger.info('✅ Loaded ${_ordersWithTracking.length} orders with tracking');

    } catch (e) {
      _error = 'فشل في تحميل طلباتك: ${e.toString()}';
      AppLogger.error('Error loading client orders with tracking', e);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Parse order status from string
  OrderStatus _parseOrderStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'approved':
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

  // Parse payment status from string
  PaymentStatus _parsePaymentStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.pending;
    }
  }

  // Parse tracking links from API response
  List<TrackingLink> _parseTrackingLinks(dynamic trackingLinksData) {
    if (trackingLinksData == null) return [];

    try {
      if (trackingLinksData is List) {
        return trackingLinksData.map((linkData) {
          return TrackingLink(
            id: linkData['id']?.toString() ?? '',
            title: linkData['title']?.toString() ?? 'رابط التتبع',
            url: linkData['url']?.toString() ?? '',
            description: linkData['description']?.toString() ?? '',
            createdBy: linkData['added_by']?.toString() ?? 'المدير',
            createdAt: DateTime.tryParse(linkData['added_at']?.toString() ?? '') ?? DateTime.now(),
          );
        }).toList();
      }
    } catch (e) {
      AppLogger.error('Error parsing tracking links', e);
    }

    return [];
  }

  // Get order by ID
  ClientOrder? getOrderById(String orderId) {
    try {
      return _ordersWithTracking.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  // Get orders by status
  List<ClientOrder> getOrdersByStatus(OrderStatus status) {
    return _ordersWithTracking.where((order) => order.status == status).toList();
  }

  // Get orders with tracking links only
  List<ClientOrder> getOrdersWithTrackingLinks() {
    return _ordersWithTracking.where((order) => order.trackingLinks.isNotEmpty).toList();
  }

  // Get orders count by status
  int getOrdersCountByStatus(OrderStatus status) {
    return _ordersWithTracking.where((order) => order.status == status).length;
  }

  // Search orders
  List<ClientOrder> searchOrders(String query) {
    if (query.isEmpty) return _ordersWithTracking;

    final lowerQuery = query.toLowerCase();
    return _ordersWithTracking.where((order) {
      return order.id.toLowerCase().contains(lowerQuery) ||
             order.items.any((item) => item.productName.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // Get recent orders (last 30 days)
  List<ClientOrder> getRecentOrders() {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return _ordersWithTracking.where((order) => order.createdAt.isAfter(thirtyDaysAgo)).toList();
  }

  // Get orders with pending status
  List<ClientOrder> getPendingOrders() {
    return getOrdersByStatus(OrderStatus.pending);
  }

  // Get orders with confirmed status
  List<ClientOrder> getConfirmedOrders() {
    return getOrdersByStatus(OrderStatus.confirmed);
  }

  // Get orders with shipped status
  List<ClientOrder> getShippedOrders() {
    return getOrdersByStatus(OrderStatus.shipped);
  }

  // Get orders with delivered status
  List<ClientOrder> getDeliveredOrders() {
    return getOrdersByStatus(OrderStatus.delivered);
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Refresh orders
  Future<void> refresh(String clientId) async {
    await loadClientOrdersWithTracking(clientId);
  }

  // Check if order has tracking links
  bool hasTrackingLinks(String orderId) {
    final order = getOrderById(orderId);
    return order?.trackingLinks.isNotEmpty ?? false;
  }

  // Get tracking links for specific order
  List<TrackingLink> getTrackingLinksForOrder(String orderId) {
    final order = getOrderById(orderId);
    return order?.trackingLinks ?? [];
  }

  // Get order status text in Arabic
  String getOrderStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'في الانتظار';
      case OrderStatus.confirmed:
        return 'مؤكد';
      case OrderStatus.processing:
        return 'قيد التجهيز';
      case OrderStatus.shipped:
        return 'تم الشحن';
      case OrderStatus.delivered:
        return 'تم التسليم';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }

  // Get payment status text in Arabic
  String getPaymentStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'في الانتظار';
      case PaymentStatus.paid:
        return 'مدفوع';
      case PaymentStatus.failed:
        return 'فشل الدفع';
      case PaymentStatus.refunded:
        return 'مسترد';
    }
  }


}
