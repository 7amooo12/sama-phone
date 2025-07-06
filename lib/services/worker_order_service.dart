import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/services/supabase_orders_service.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة جلب تفاصيل الطلبيات للعمال
class WorkerOrderService {
  static final WorkerOrderService _instance = WorkerOrderService._internal();
  factory WorkerOrderService() => _instance;
  WorkerOrderService._internal();

  final SupabaseOrdersService _supabaseOrdersService = SupabaseOrdersService();
  final StockWarehouseApiService _stockWarehouseApi = StockWarehouseApiService();

  /// جلب تفاصيل طلبية محددة
  Future<OrderModel?> getOrderDetails(String orderId) async {
    try {
      AppLogger.info('🔄 جلب تفاصيل الطلبية: $orderId');

      // محاولة جلب من Supabase أولاً
      try {
        final supabaseOrder = await _supabaseOrdersService.getOrderById(orderId);
        if (supabaseOrder != null) {
          AppLogger.info('✅ تم جلب الطلبية من Supabase');
          return _convertClientOrderToOrderModel(supabaseOrder);
        }
      } catch (e) {
        AppLogger.warning('⚠️ فشل جلب الطلبية من Supabase: $e');
      }

      // محاولة جلب من Stock Warehouse API
      try {
        final orderIdInt = int.tryParse(orderId);
        if (orderIdInt != null) {
          final stockOrder = await _stockWarehouseApi.getOrderDetail(orderIdInt);
          if (stockOrder != null) {
            AppLogger.info('✅ تم جلب الطلبية من Stock Warehouse API');
            return stockOrder;
          }
        }
      } catch (e) {
        AppLogger.warning('⚠️ فشل جلب الطلبية من Stock Warehouse API: $e');
      }

      AppLogger.error('❌ فشل في جلب تفاصيل الطلبية من جميع المصادر');
      return null;

    } catch (e) {
      AppLogger.error('❌ خطأ في جلب تفاصيل الطلبية: $e');
      return null;
    }
  }

  /// تحويل ClientOrder إلى OrderModel
  OrderModel _convertClientOrderToOrderModel(dynamic clientOrder) {
    try {
      // استخراج البيانات من ClientOrder
      final Map<String, dynamic> orderData = {
        'id': clientOrder.id?.toString() ?? '',
        'order_number': clientOrder.orderNumber ?? '',
        'customer_name': clientOrder.customerName ?? '',
        'customer_phone': clientOrder.customerPhone,
        'status': clientOrder.status ?? '',
        'total_amount': clientOrder.totalAmount ?? 0.0,
        'created_at': clientOrder.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'delivery_date': clientOrder.deliveryDate?.toIso8601String(),
        'notes': clientOrder.notes,
        'payment_method': clientOrder.paymentMethod,
        'address': clientOrder.address,
        'assigned_to': clientOrder.assignedTo,
        'tracking_number': clientOrder.trackingNumber,
        'client_id': clientOrder.clientId,
        'warehouse_name': clientOrder.warehouseName,
        'items_count': clientOrder.items?.length,
        'progress': clientOrder.progress,
      };

      // تحويل العناصر
      final List<Map<String, dynamic>> itemsData = [];
      if (clientOrder.items != null) {
        for (final item in clientOrder.items!) {
          itemsData.add({
            'id': item.id?.toString() ?? '',
            'product_id': item.productId?.toString() ?? '',
            'product_name': item.productName ?? '',
            'description': item.description,
            'price': item.price ?? 0.0,
            'purchase_price': item.purchasePrice ?? 0.0,
            'quantity': item.quantity ?? 0,
            'subtotal': item.subtotal ?? 0.0,
            'image_url': item.imageUrl,
          });
        }
      }

      orderData['items'] = itemsData;

      return OrderModel.fromJson(orderData);
    } catch (e) {
      AppLogger.error('❌ خطأ في تحويل ClientOrder إلى OrderModel: $e');
      rethrow;
    }
  }

  /// جلب قائمة المنتجات والكميات من الطلبية
  Future<List<Map<String, dynamic>>> getOrderProductsAndQuantities(String orderId) async {
    try {
      final order = await getOrderDetails(orderId);
      if (order == null || order.items.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> productsAndQuantities = [];
      
      for (final item in order.items) {
        productsAndQuantities.add({
          'productName': item.productName,
          'quantity': item.quantity,
          'price': item.price,
          'subtotal': item.subtotal,
          'description': item.description,
          'imageUrl': item.imageUrl,
        });
      }

      AppLogger.info('✅ تم جلب ${productsAndQuantities.length} منتج من الطلبية');
      return productsAndQuantities;

    } catch (e) {
      AppLogger.error('❌ خطأ في جلب منتجات الطلبية: $e');
      return [];
    }
  }

  /// التحقق من وجود طلبية
  Future<bool> orderExists(String orderId) async {
    try {
      final order = await getOrderDetails(orderId);
      return order != null;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من وجود الطلبية: $e');
      return false;
    }
  }
}
