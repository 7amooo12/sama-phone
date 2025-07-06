import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة إدارة اعتماد التسعير
class PricingApprovalService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// الحصول على الطلبات المعلقة للتسعير
  Future<List<ClientOrder>> getPendingPricingOrders() async {
    try {
      AppLogger.info('🔄 Fetching orders pending pricing approval...');

      final response = await _supabase
          .from('client_orders')
          .select('''
            *,
            client_order_items (*)
          ''')
          .eq('pricing_status', 'pending_pricing')
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      final orders = (response as List)
          .map((orderData) => ClientOrder.fromJson(orderData))
          .toList();

      AppLogger.info('✅ Found ${orders.length} orders pending pricing');
      return orders;
    } catch (e) {
      AppLogger.error('❌ Error fetching pending pricing orders: $e');
      throw Exception('فشل في تحميل الطلبات المعلقة للتسعير: $e');
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

      // Call the stored procedure
      final response = await _supabase.rpc('approve_order_pricing', params: {
        'p_order_id': orderId,
        'p_approved_by': approvedBy,
        'p_approved_by_name': approvedByName,
        'p_items': pricingItems,
        'p_notes': notes,
      });

      if (response == true) {
        AppLogger.info('✅ Order pricing approved successfully: $orderId');
        return true;
      } else {
        AppLogger.error('❌ Failed to approve order pricing: $orderId');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Error approving order pricing: $e');
      throw Exception('فشل في اعتماد التسعير: $e');
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

      AppLogger.info('✅ Order pricing rejected successfully: $orderId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error rejecting order pricing: $e');
      throw Exception('فشل في رفض التسعير: $e');
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
      AppLogger.error('❌ Error loading order for pricing: $e');
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
      AppLogger.error('❌ Error loading pricing history: $e');
      return [];
    }
  }

  /// إحصائيات التسعير
  Future<Map<String, int>> getPricingStatistics() async {
    try {
      AppLogger.info('🔄 Loading pricing statistics...');

      // Get pending pricing count
      final pendingResponse = await _supabase
          .from('client_orders')
          .select('id')
          .eq('pricing_status', 'pending_pricing')
          .count();

      // Get approved pricing count
      final approvedResponse = await _supabase
          .from('client_orders')
          .select('id')
          .eq('pricing_status', 'pricing_approved')
          .count();

      // Get rejected pricing count
      final rejectedResponse = await _supabase
          .from('client_orders')
          .select('id')
          .eq('pricing_status', 'pricing_rejected')
          .count();

      final stats = {
        'pending_pricing': pendingResponse.count ?? 0,
        'pricing_approved': approvedResponse.count ?? 0,
        'pricing_rejected': rejectedResponse.count ?? 0,
      };

      AppLogger.info('✅ Pricing statistics loaded: $stats');
      return stats;
    } catch (e) {
      AppLogger.error('❌ Error loading pricing statistics: $e');
      return {
        'pending_pricing': 0,
        'pricing_approved': 0,
        'pricing_rejected': 0,
      };
    }
  }

  /// تحديث حالة التسعير للطلب
  Future<bool> updateOrderPricingStatus({
    required String orderId,
    required String pricingStatus,
    String? approvedBy,
    String? notes,
  }) async {
    try {
      AppLogger.info('🔄 Updating pricing status for order: $orderId to $pricingStatus');

      final updateData = <String, dynamic>{
        'pricing_status': pricingStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (approvedBy != null) {
        updateData['pricing_approved_by'] = approvedBy;
        updateData['pricing_approved_at'] = DateTime.now().toIso8601String();
      }

      if (notes != null) {
        updateData['pricing_notes'] = notes;
      }

      await _supabase
          .from('client_orders')
          .update(updateData)
          .eq('id', orderId);

      AppLogger.info('✅ Pricing status updated successfully for order: $orderId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error updating pricing status: $e');
      return false;
    }
  }

  /// الحصول على عناصر الطلب للتسعير
  Future<List<Map<String, dynamic>>> getOrderItemsForPricing(String orderId) async {
    try {
      AppLogger.info('🔄 Loading order items for pricing: $orderId');

      final response = await _supabase
          .from('client_order_items')
          .select('*')
          .eq('order_id', orderId)
          .order('created_at', ascending: true);

      AppLogger.info('✅ Order items loaded for pricing: $orderId');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('❌ Error loading order items for pricing: $e');
      return [];
    }
  }

  /// إضافة سجل في تاريخ التسعير
  Future<bool> addPricingHistoryRecord({
    required String orderId,
    required String itemId,
    required double originalPrice,
    required double approvedPrice,
    required String approvedBy,
    required String approvedByName,
    String? notes,
  }) async {
    try {
      AppLogger.info('🔄 Adding pricing history record for order: $orderId');

      await _supabase
          .from('order_pricing_history')
          .insert({
            'order_id': orderId,
            'item_id': itemId,
            'original_price': originalPrice,
            'approved_price': approvedPrice,
            'price_difference': approvedPrice - originalPrice,
            'approved_by': approvedBy,
            'approved_by_name': approvedByName,
            'pricing_notes': notes,
          });

      AppLogger.info('✅ Pricing history record added for order: $orderId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error adding pricing history record: $e');
      return false;
    }
  }
}
