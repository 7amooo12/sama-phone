import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../models/order_model.dart';

class OrderService {
  final _supabase = Supabase.instance.client;

  Future<List<OrderModel>> getOrders() async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((order) => OrderModel.fromJson(order)).toList();
    } catch (e) {
      AppLogger.error('Error getting orders: $e');
      rethrow;
    }
  }

  Future<void> createOrder(OrderModel order) async {
    try {
      await _supabase.from('orders').insert(order.toJson());
    } catch (e) {
      AppLogger.error('Error creating order: $e');
      rethrow;
    }
  }

  Future<void> updateOrder(OrderModel order) async {
    try {
      await _supabase
          .from('orders')
          .update(order.toJson())
          .eq('id', order.id);
    } catch (e) {
      AppLogger.error('Error updating order: $e');
      rethrow;
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await _supabase
          .from('orders')
          .delete()
          .eq('id', orderId);
    } catch (e) {
      AppLogger.error('Error deleting order: $e');
      rethrow;
    }
  }

  Future<List<OrderModel>> getOrdersByUserId(String userId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((order) => OrderModel.fromJson(order)).toList();
    } catch (e) {
      AppLogger.error('Error getting orders by user ID: $e');
      rethrow;
    }
  }
}