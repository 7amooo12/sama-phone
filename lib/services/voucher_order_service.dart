import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/voucher_model.dart';
import '../services/client_orders_service.dart' as client_service;
import '../utils/app_logger.dart';
import '../services/real_notification_service.dart';

/// Service for handling voucher-specific order operations
/// Integrates with existing order system while adding voucher functionality
class VoucherOrderService {
  final SupabaseClient _client = Supabase.instance.client;
  final RealNotificationService _notificationService = RealNotificationService();
  static const String _ordersTable = 'client_orders';
  static const String _orderItemsTable = 'client_order_items';
  static const String _clientVouchersTable = 'client_vouchers';

  /// Create a voucher order with proper metadata and voucher usage tracking
  Future<String?> createVoucherOrder({
    required String clientId,
    required String clientName,
    required String clientEmail,
    required String clientPhone,
    required List<client_service.CartItem> voucherCartItems,
    required VoucherModel voucher,
    required String clientVoucherId,
    required double totalOriginalPrice,
    required double totalDiscountedPrice,
    required double totalSavings,
    String? notes,
    String? shippingAddress,
  }) async {
    try {
      AppLogger.info('🎫 Creating voucher order...');
      AppLogger.info('   - Voucher: ${voucher.name} (${voucher.discountPercentage}%)');
      AppLogger.info('   - Original total: $totalOriginalPrice');
      AppLogger.info('   - Discounted total: $totalDiscountedPrice');
      AppLogger.info('   - Total savings: $totalSavings');
      AppLogger.info('   - Client voucher ID: $clientVoucherId');
      AppLogger.info('   - Cart items count: ${voucherCartItems.length}');

      // Enhanced user authentication validation
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        AppLogger.error('❌ User not authenticated - currentUser is null');
        throw Exception('User not authenticated');
      }

      AppLogger.info('✅ Current user authenticated: ${currentUser.id}');

      if (currentUser.id != clientId) {
        AppLogger.error('❌ User ID mismatch: currentUser.id=${currentUser.id}, clientId=$clientId');
        throw Exception('User ID mismatch');
      }

      AppLogger.info('✅ User ID validation passed');

      // Validate voucher cart items
      if (voucherCartItems.isEmpty) {
        throw Exception('Voucher cart is empty');
      }

      // Validate all items are voucher items
      for (final item in voucherCartItems) {
        if (!item.isVoucherItem) {
          throw Exception('Non-voucher item found in voucher cart: ${item.productName}');
        }
      }

      // Generate order number
      final orderNumber = 'VOUCHER-${DateTime.now().millisecondsSinceEpoch}';

      // Prepare comprehensive voucher order metadata
      final voucherOrderMetadata = {
        'order_type': 'voucher_order',
        'voucher_id': voucher.id,
        'voucher_code': voucher.code,
        'voucher_name': voucher.name,
        'voucher_type': voucher.type.value,
        'voucher_target_id': voucher.targetId,
        'voucher_target_name': voucher.targetName,
        'discount_percentage': voucher.discountPercentage,
        'client_voucher_id': clientVoucherId,
        'pricing_details': {
          'original_total': totalOriginalPrice,
          'discounted_total': totalDiscountedPrice,
          'total_savings': totalSavings,
          'discount_applied': true,
        },
        'voucher_usage': {
          'used_at': DateTime.now().toIso8601String(),
          'used_by': clientId,
          'usage_type': 'order_creation',
        },
        'created_from': 'voucher_cart',
        'items_count': voucherCartItems.length,
        'requires_pricing_approval': false, // Voucher orders have pre-approved pricing
      };

      // Create order data
      final orderData = {
        'client_id': clientId,
        'client_name': clientName,
        'client_email': clientEmail,
        'client_phone': clientPhone,
        'order_number': orderNumber,
        'total_amount': totalDiscountedPrice, // Use discounted price as final amount
        'status': 'pending',
        'payment_status': 'pending',
        'pricing_status': 'pricing_approved', // Voucher orders are pre-approved
        'notes': notes,
        'shipping_address': shippingAddress != null ? {'address': shippingAddress} : null,
        'metadata': voucherOrderMetadata,
      };

      AppLogger.info('🔍 Voucher order data: $orderData');

      // Enhanced order insertion with detailed error handling
      AppLogger.info('📝 Inserting order into database...');

      dynamic orderResponse;
      try {
        orderResponse = await _client
            .from(_ordersTable)
            .insert(orderData)
            .select('id, order_number')
            .single();

        AppLogger.info('✅ Order insertion successful');
      } catch (insertError) {
        AppLogger.error('❌ Order insertion failed: $insertError');
        AppLogger.error('❌ Order data that failed: $orderData');
        throw Exception('Failed to insert order: $insertError');
      }

      if (orderResponse == null) {
        AppLogger.error('❌ Order response is null');
        throw Exception('Order creation failed - null response');
      }

      final orderId = orderResponse['id'] as String?;
      final createdOrderNumber = orderResponse['order_number'] as String?;

      if (orderId == null || orderId.isEmpty) {
        AppLogger.error('❌ Order ID is null or empty in response: $orderResponse');
        throw Exception('Order creation failed - invalid order ID');
      }

      if (createdOrderNumber == null || createdOrderNumber.isEmpty) {
        AppLogger.error('❌ Order number is null or empty in response: $orderResponse');
        throw Exception('Order creation failed - invalid order number');
      }

      AppLogger.info('✅ Voucher order created: $createdOrderNumber (ID: $orderId)');

      // Prepare order items with voucher information
      final orderItems = voucherCartItems.map((item) => {
        'order_id': orderId,
        'product_id': item.productId,
        'product_name': item.productName,
        'product_image': item.productImage,
        'product_category': item.category,
        'unit_price': item.price, // Discounted price
        'quantity': item.quantity,
        'subtotal': item.price * item.quantity, // Discounted subtotal
        // Store original pricing information
        'original_unit_price': item.originalPrice ?? item.price,
        'approved_unit_price': item.price, // Voucher price is pre-approved
        'approved_subtotal': item.price * item.quantity,
        'pricing_approved': true,
        'pricing_approved_by': clientId, // Self-approved via voucher
        'pricing_approved_at': DateTime.now().toIso8601String(),
        'metadata': {
          'item_type': 'voucher_item',
          'voucher_code': item.voucherCode,
          'voucher_name': item.voucherName,
          'discount_percentage': item.discountPercentage,
          'discount_amount': item.discountAmount,
          'original_price': item.originalPrice,
          'savings_per_item': item.discountAmount ?? 0,
          'total_item_savings': (item.discountAmount ?? 0) * item.quantity,
          'added_from': 'voucher_cart',
        },
      }).toList();

      // Enhanced order items insertion with detailed error handling
      AppLogger.info('📝 Inserting ${orderItems.length} order items...');
      AppLogger.info('🔍 Order items data: $orderItems');

      try {
        await _client.from(_orderItemsTable).insert(orderItems);
        AppLogger.info('✅ Added ${orderItems.length} voucher items to order');
      } catch (itemsInsertError) {
        AppLogger.error('❌ Order items insertion failed: $itemsInsertError');
        AppLogger.error('❌ Order items data that failed: $orderItems');

        // Try to clean up the order if items insertion failed
        try {
          await _client.from(_ordersTable).delete().eq('id', orderId);
          AppLogger.info('🧹 Cleaned up failed order: $orderId');
        } catch (cleanupError) {
          AppLogger.error('❌ Failed to cleanup order after items insertion failure: $cleanupError');
        }

        throw Exception('Failed to insert order items: $itemsInsertError');
      }

      // Mark voucher as used
      await _markVoucherAsUsed(clientVoucherId, orderId, totalSavings);

      // Create order history entry
      await _createOrderHistoryEntry(
        orderId: orderId,
        action: 'created',
        description: 'Voucher order created with ${voucher.name}',
        changedBy: clientId,
        changedByName: clientName,
        changedByRole: 'customer',
        metadata: {
          'voucher_applied': true,
          'voucher_name': voucher.name,
          'total_savings': totalSavings,
        },
      );

      AppLogger.info('🎫 Voucher order creation completed successfully');

      // 🔔 إرسال إشعارات إنشاء الطلب
      await _sendVoucherOrderNotifications(
        orderId: orderId,
        orderNumber: orderNumber,
        clientId: clientId,
        clientName: clientName,
        totalAmount: totalDiscountedPrice,
        voucherName: voucher.name,
      );

      return orderId;

    } catch (e) {
      AppLogger.error('❌ Error creating voucher order: $e');
      rethrow;
    }
  }

  /// Mark voucher as used and record usage details
  Future<void> _markVoucherAsUsed(String clientVoucherId, String orderId, double discountAmount) async {
    try {
      AppLogger.info('🎫 Marking voucher as used: $clientVoucherId');

      await _client
          .from(_clientVouchersTable)
          .update({
            'status': 'used',
            'used_at': DateTime.now().toIso8601String(),
            'order_id': orderId,
            'discount_amount': discountAmount,
          })
          .eq('id', clientVoucherId);

      AppLogger.info('✅ Voucher marked as used successfully');
    } catch (e) {
      AppLogger.error('❌ Error marking voucher as used: $e');
      rethrow;
    }
  }

  /// Create order history entry for voucher order
  Future<void> _createOrderHistoryEntry({
    required String orderId,
    required String action,
    required String description,
    required String changedBy,
    required String changedByName,
    required String changedByRole,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final historyData = {
        'order_id': orderId,
        'action': action,
        'description': description,
        'changed_by': changedBy,
        'changed_by_name': changedByName,
        'changed_by_role': changedByRole,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          'order_type': 'voucher_order',
          ...?metadata,
        },
      };

      await _client.from('order_history').insert(historyData);
      AppLogger.info('✅ Order history entry created');
    } catch (e) {
      AppLogger.error('❌ Error creating order history entry: $e');
      // Don't rethrow as this is not critical for order creation
    }
  }

  /// Get voucher order details with enhanced voucher information
  Future<Map<String, dynamic>?> getVoucherOrderDetails(String orderId) async {
    try {
      AppLogger.info('🔍 Getting voucher order details: $orderId');

      final response = await _client
          .from(_ordersTable)
          .select('''
            *,
            client_order_items(*),
            order_tracking_links(*),
            order_history(*)
          ''')
          .eq('id', orderId)
          .single();

      // Check if this is a voucher order
      final metadata = response['metadata'] as Map<String, dynamic>?;
      if (metadata?['order_type'] != 'voucher_order') {
        throw Exception('Order is not a voucher order');
      }

      AppLogger.info('✅ Voucher order details retrieved');
      return response;
    } catch (e) {
      AppLogger.error('❌ Error getting voucher order details: $e');
      return null;
    }
  }

  /// Validate voucher order eligibility
  Future<bool> validateVoucherOrderEligibility({
    required String clientId,
    required String clientVoucherId,
    required List<client_service.CartItem> cartItems,
  }) async {
    try {
      AppLogger.info('🔍 Validating voucher order eligibility');

      // Check if client voucher exists and is active
      final voucherResponse = await _client
          .from(_clientVouchersTable)
          .select('''
            *,
            vouchers(*)
          ''')
          .eq('id', clientVoucherId)
          .eq('client_id', clientId)
          .eq('status', 'active')
          .single();

      final voucher = VoucherModel.fromJson(voucherResponse['vouchers']);

      // Check if voucher is still valid
      if (!voucher.isValid) {
        AppLogger.warning('⚠️ Voucher is not valid');
        return false;
      }

      // Validate all cart items are eligible for the voucher
      for (final item in cartItems) {
        if (!item.isVoucherItem) {
          AppLogger.warning('⚠️ Non-voucher item found: ${item.productName}');
          return false;
        }
      }

      AppLogger.info('✅ Voucher order eligibility validated');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error validating voucher order eligibility: $e');
      return false;
    }
  }

  /// إرسال إشعارات إنشاء طلب القسيمة للمستخدمين المناسبين
  Future<void> _sendVoucherOrderNotifications({
    required String orderId,
    required String orderNumber,
    required String clientId,
    required String clientName,
    required double totalAmount,
    required String voucherName,
  }) async {
    try {
      AppLogger.info('🔔 إرسال إشعارات طلب القسيمة: $orderNumber');

      // إرسال إشعار للعميل
      await _notificationService.createOrderStatusNotification(
        userId: clientId,
        orderId: orderId,
        orderNumber: orderNumber,
        status: 'تم إنشاء طلب القسيمة بنجاح',
      );

      // إرسال إشعارات للإدارة والمحاسبين مع تفاصيل القسيمة
      await _notificationService.createNewOrderNotificationForStaff(
        orderId: orderId,
        orderNumber: orderNumber,
        clientName: '$clientName (قسيمة: $voucherName)',
        totalAmount: totalAmount,
      );

      AppLogger.info('✅ تم إرسال إشعارات طلب القسيمة بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في إرسال إشعارات طلب القسيمة: $e');
      // لا نرمي الخطأ هنا لأن إنشاء الطلب نجح، فقط الإشعارات فشلت
    }
  }
}
