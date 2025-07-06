import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class PendingOrdersProvider extends ChangeNotifier {
  final FlaskApiService _apiService = FlaskApiService();
  
  List<ClientOrder> _pendingOrders = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ClientOrder> get pendingOrders => _pendingOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingOrdersCount => _pendingOrders.length;

  // Load pending orders
  Future<void> loadPendingOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔄 Loading pending orders...');
      
      final ordersData = await _apiService.getPendingOrders();
      
      _pendingOrders = ordersData.map((orderData) {
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
            status: OrderStatus.pending,
            paymentStatus: PaymentStatus.pending,
            createdAt: DateTime.now(),
            trackingLinks: [],
          );
        }
      }).toList();

      AppLogger.info('✅ Loaded ${_pendingOrders.length} pending orders');
      
    } catch (e) {
      _error = 'فشل في تحميل الطلبات المعلقة: ${e.toString()}';
      AppLogger.error('Error loading pending orders', e);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Approve order with tracking link
  Future<bool> approveOrderWithTracking({
    required String orderId,
    required String trackingUrl,
    required String trackingTitle,
    String? trackingDescription,
    required String adminName,
  }) async {
    try {
      AppLogger.info('🔄 Approving order $orderId with tracking...');
      
      final success = await _apiService.approveOrderWithTracking(
        orderId: orderId,
        trackingUrl: trackingUrl,
        trackingTitle: trackingTitle,
        trackingDescription: trackingDescription,
        adminName: adminName,
      );

      if (success) {
        // Remove the approved order from pending list
        _pendingOrders.removeWhere((order) => order.id == orderId);
        notifyListeners();
        
        AppLogger.info('✅ Order $orderId approved successfully');
        return true;
      } else {
        _error = 'فشل في الموافقة على الطلب';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'خطأ في الموافقة على الطلب: ${e.toString()}';
      AppLogger.error('Error approving order with tracking', e);
      notifyListeners();
      return false;
    }
  }

  // Add tracking link to existing order
  Future<bool> addTrackingLink({
    required String orderId,
    required String trackingUrl,
    required String trackingTitle,
    String? trackingDescription,
    required String adminName,
  }) async {
    try {
      AppLogger.info('🔄 Adding tracking link to order $orderId...');
      
      final success = await _apiService.addTrackingLink(
        orderId: orderId,
        trackingUrl: trackingUrl,
        trackingTitle: trackingTitle,
        trackingDescription: trackingDescription,
        adminName: adminName,
      );

      if (success) {
        AppLogger.info('✅ Tracking link added to order $orderId successfully');
        return true;
      } else {
        _error = 'فشل في إضافة رابط التتبع';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'خطأ في إضافة رابط التتبع: ${e.toString()}';
      AppLogger.error('Error adding tracking link', e);
      notifyListeners();
      return false;
    }
  }

  // Reject order
  Future<bool> rejectOrder(String orderId, String reason) async {
    try {
      AppLogger.info('🔄 Rejecting order $orderId...');
      
      // For now, just remove from pending list
      // In a real implementation, you'd call an API to update the order status
      _pendingOrders.removeWhere((order) => order.id == orderId);
      notifyListeners();
      
      AppLogger.info('✅ Order $orderId rejected');
      return true;
    } catch (e) {
      _error = 'خطأ في رفض الطلب: ${e.toString()}';
      AppLogger.error('Error rejecting order', e);
      notifyListeners();
      return false;
    }
  }

  // Get order by ID
  ClientOrder? getOrderById(String orderId) {
    try {
      return _pendingOrders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Refresh pending orders
  Future<void> refresh() async {
    await loadPendingOrders();
  }

  // Get orders by status
  List<ClientOrder> getOrdersByStatus(OrderStatus status) {
    return _pendingOrders.where((order) => order.status == status).toList();
  }

  // Get orders count by status
  int getOrdersCountByStatus(OrderStatus status) {
    return _pendingOrders.where((order) => order.status == status).length;
  }

  // Search orders
  List<ClientOrder> searchOrders(String query) {
    if (query.isEmpty) return _pendingOrders;
    
    final lowerQuery = query.toLowerCase();
    return _pendingOrders.where((order) {
      return order.clientName.toLowerCase().contains(lowerQuery) ||
             order.clientPhone.toLowerCase().contains(lowerQuery) ||
             order.clientEmail.toLowerCase().contains(lowerQuery) ||
             order.id.toLowerCase().contains(lowerQuery);
    }).toList();
  }

}
