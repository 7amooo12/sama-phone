import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Provider لإدارة اعتماد التسعير
class PricingApprovalProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<ClientOrder> _pendingPricingOrders = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ClientOrder> get pendingPricingOrders => List.unmodifiable(_pendingPricingOrders);

  /// تحميل الطلبات المعلقة للتسعير
  Future<void> loadPendingPricingOrders() async {
    _setLoading(true);
    _setError(null);

    try {
      AppLogger.info('🔄 Loading orders pending pricing approval...');

      // Use the stored function to get pending pricing orders
      final response = await _supabase.rpc('get_orders_pending_pricing');

      // Convert the response to ClientOrder objects
      final List<ClientOrder> orders = [];
      for (final orderData in response as List) {
        try {
          // Get order items for each order
          final itemsResponse = await _supabase
              .from('client_order_items')
              .select('*')
              .eq('order_id', orderData['order_id']);

          // Create a complete order object
          final completeOrderData = {
            'id': orderData['order_id'],
            'order_number': orderData['order_number'],
            'client_name': orderData['client_name'],
            'client_email': orderData['client_email'],
            'client_phone': orderData['client_phone'],
            'total_amount': orderData['total_amount'],
            'created_at': orderData['created_at'],
            'pricing_status': orderData['pricing_status'],
            'status': orderData['status'],
            'client_order_items': itemsResponse,
          };

          orders.add(ClientOrder.fromJson(completeOrderData));
        } catch (e) {
          AppLogger.error('Error processing order ${orderData['order_id']}: $e');
        }
      }

      _pendingPricingOrders = orders;
      AppLogger.info('✅ Loaded ${_pendingPricingOrders.length} orders pending pricing');
    } catch (e) {
      _setError('فشل في تحميل الطلبات المعلقة للتسعير: $e');
      AppLogger.error('Error loading pending pricing orders: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// اعتماد تسعير الطلب
  Future<bool> approveOrderPricing({
    required String orderId,
    required String approvedBy,
    required String approvedByName,
    required List<Map<String, dynamic>> pricingItems,
    String? notes,
  }) async {
    try {
      AppLogger.info('🔄 Approving pricing for order: $orderId');

      // Debug: Log detailed information about the pricing items
      AppLogger.info('🔍 Detailed pricing items analysis:');
      for (int i = 0; i < pricingItems.length; i++) {
        final item = pricingItems[i];
        AppLogger.info('  Item $i: ${item.toString()}');
        AppLogger.info('    - item_id type: ${item['item_id'].runtimeType}');
        AppLogger.info('    - item_id value: "${item['item_id']}"');
        AppLogger.info('    - approved_price type: ${item['approved_price'].runtimeType}');
        AppLogger.info('    - approved_price value: ${item['approved_price']}');
      }

      // Call the stored procedure
      final response = await _supabase.rpc('approve_order_pricing', params: {
        'p_order_id': orderId,
        'p_approved_by': approvedBy,
        'p_approved_by_name': approvedByName,
        'p_items': pricingItems,
        'p_notes': notes,
      });

      if (response == true) {
        // Remove from pending list
        _pendingPricingOrders.removeWhere((order) => order.id == orderId);
        notifyListeners();
        
        AppLogger.info('✅ Order pricing approved successfully: $orderId');
        return true;
      } else {
        _setError('فشل في اعتماد التسعير');
        return false;
      }
    } catch (e) {
      _setError('خطأ في اعتماد التسعير: $e');
      AppLogger.error('Error approving order pricing: $e');
      return false;
    }
  }

  /// رفض تسعير الطلب
  Future<bool> rejectOrderPricing({
    required String orderId,
    required String rejectedBy,
    required String rejectedByName,
    String? reason,
  }) async {
    try {
      AppLogger.info('🔄 Rejecting pricing for order: $orderId');

      // Update order status to cancelled
      await _supabase
          .from('client_orders')
          .update({
            'status': 'cancelled',
            'pricing_status': 'pricing_rejected',
            'pricing_approved_by': rejectedBy,
            'pricing_approved_at': DateTime.now().toIso8601String(),
            'pricing_notes': reason ?? 'تم رفض التسعير',
          })
          .eq('id', orderId);

      // Add to order history
      await _supabase
          .from('order_history')
          .insert({
            'order_id': orderId,
            'action': 'pricing_rejected',
            'old_status': 'pending',
            'new_status': 'cancelled',
            'description': 'تم رفض التسعير وإلغاء الطلب',
            'changed_by': rejectedBy,
            'changed_by_name': rejectedByName,
            'changed_by_role': 'accountant',
          });

      // Remove from pending list
      _pendingPricingOrders.removeWhere((order) => order.id == orderId);
      notifyListeners();

      AppLogger.info('✅ Order pricing rejected successfully: $orderId');
      return true;
    } catch (e) {
      _setError('خطأ في رفض التسعير: $e');
      AppLogger.error('Error rejecting order pricing: $e');
      return false;
    }
  }

  /// الحصول على تفاصيل الطلب للتسعير
  Future<ClientOrder?> getOrderForPricing(String orderId) async {
    try {
      AppLogger.info('🔄 Loading order for pricing: $orderId');

      final response = await _supabase
          .from('client_orders')
          .select('''
            *,
            client_order_items (*)
          ''')
          .eq('id', orderId)
          .single();

      final order = ClientOrder.fromJson(response);
      AppLogger.info('✅ Order loaded for pricing: $orderId');
      return order;
    } catch (e) {
      _setError('فشل في تحميل تفاصيل الطلب: $e');
      AppLogger.error('Error loading order for pricing: $e');
      return null;
    }
  }

  /// الحصول على تاريخ التسعير للطلب
  Future<List<Map<String, dynamic>>> getPricingHistory(String orderId) async {
    try {
      AppLogger.info('🔄 Loading pricing history for order: $orderId');

      final response = await _supabase
          .from('order_pricing_history')
          .select('*')
          .eq('order_id', orderId)
          .order('created_at', ascending: false);

      AppLogger.info('✅ Pricing history loaded for order: $orderId');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _setError('فشل في تحميل تاريخ التسعير: $e');
      AppLogger.error('Error loading pricing history: $e');
      return [];
    }
  }

  /// إحصائيات التسعير
  Future<Map<String, dynamic>> getPricingStatistics() async {
    try {
      AppLogger.info('🔄 Loading pricing statistics...');

      // Get pending pricing count
      final pendingResponse = await _supabase
          .from('client_orders')
          .select('id')
          .or('pricing_status.eq.pending_pricing,and(pricing_status.is.null,status.eq.pending)');

      // Get approved pricing count
      final approvedResponse = await _supabase
          .from('client_orders')
          .select('id')
          .eq('pricing_status', 'pricing_approved');

      // Get rejected pricing count
      final rejectedResponse = await _supabase
          .from('client_orders')
          .select('id')
          .eq('pricing_status', 'pricing_rejected');

      final stats = {
        'pending_pricing': (pendingResponse as List).length,
        'pricing_approved': (approvedResponse as List).length,
        'pricing_rejected': (rejectedResponse as List).length,
      };

      AppLogger.info('✅ Pricing statistics loaded: $stats');
      return stats;
    } catch (e) {
      _setError('فشل في تحميل إحصائيات التسعير: $e');
      AppLogger.error('Error loading pricing statistics: $e');
      return {
        'pending_pricing': 0,
        'pricing_approved': 0,
        'pricing_rejected': 0,
      };
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
