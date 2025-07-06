import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_order_model.dart';
import '../services/client_orders_service.dart' as client_service;
import '../utils/app_logger.dart';
import '../providers/app_settings_provider.dart';
import '../services/real_notification_service.dart';

/// خدمة Supabase للطلبات مع تتبع كامل وتاريخ
class SupabaseOrdersService {
  // Lazy initialization to avoid accessing Supabase.instance before initialization
  SupabaseClient get _client {
    try {
      return Supabase.instance.client;
    } catch (e) {
      AppLogger.error('❌ Supabase not initialized yet in SupabaseOrdersService: $e');
      throw Exception('Supabase must be initialized before using SupabaseOrdersService');
    }
  }

  // AppSettingsProvider for price visibility control
  AppSettingsProvider? _appSettingsProvider;

  // Set AppSettingsProvider for price visibility control
  void setAppSettingsProvider(AppSettingsProvider provider) {
    _appSettingsProvider = provider;
  }

  // Notification service for order notifications
  final RealNotificationService _notificationService = RealNotificationService();

  // أسماء الجداول
  static const String _ordersTable = 'client_orders';
  static const String _orderItemsTable = 'client_order_items';
  static const String _trackingLinksTable = 'order_tracking_links';
  static const String _orderHistoryTable = 'order_history';
  static const String _notificationsTable = 'order_notifications';

  /// إنشاء طلب جديد في Supabase
  Future<String?> createOrder({
    required String clientId,
    required String clientName,
    required String clientEmail,
    required String clientPhone,
    required List<client_service.CartItem> cartItems,
    String? notes,
    String? shippingAddress,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger.info('🔄 إنشاء طلب جديد في Supabase...');

      // 🔍 DEBUG: Check authentication status
      final currentUser = _client.auth.currentUser;
      final currentSession = _client.auth.currentSession;
      AppLogger.info('🔍 DEBUG: Current user: ${currentUser?.id}');
      AppLogger.info('🔍 DEBUG: User email: ${currentUser?.email}');
      AppLogger.info('🔍 DEBUG: JWT token exists: ${currentSession?.accessToken != null}');

      if (currentUser == null) {
        AppLogger.error('❌ No authenticated user found');
        return null;
      }

      // 🔍 DEBUG: Check user profile
      try {
        final profileResponse = await _client
            .from('user_profiles')
            .select('id, email, name, role, status')
            .eq('id', currentUser.id)
            .maybeSingle();

        AppLogger.info('🔍 DEBUG: User profile: $profileResponse');

        if (profileResponse == null) {
          AppLogger.error('❌ User profile not found for: ${currentUser.id}');
          return null;
        }

        // Support both 'approved' and 'active' status values
        final userStatus = profileResponse['status'] as String?;
        if (userStatus != 'approved' && userStatus != 'active') {
          AppLogger.error('❌ User status not valid for order creation: $userStatus');
          return null;
        }

        AppLogger.info('✅ User profile OK: ${profileResponse['role']} - ${profileResponse['status']}');
      } catch (e) {
        AppLogger.error('❌ Error checking user profile: $e');
        return null;
      }

      // حساب المجموع الإجمالي
      final total = cartItems.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));

      // 🔍 DEBUG: Log order data before insert
      final orderData = {
        'client_id': clientId,
        'client_name': clientName,
        'client_email': clientEmail,
        'client_phone': clientPhone,
        'order_number': 'ORD-${DateTime.now().millisecondsSinceEpoch}', // Add order_number
        'total_amount': total,
        'status': 'pending',
        'payment_status': 'pending',
        'pricing_status': 'pending_pricing', // Add pricing approval status
        'notes': notes,
        'shipping_address': shippingAddress != null ? {'address': shippingAddress} : null,
        'metadata': {
          'created_from': 'mobile_app',
          'items_count': cartItems.length,
          'requires_pricing_approval': true,
          ...?metadata, // Merge voucher metadata if provided
        },
      };

      AppLogger.info('🔍 DEBUG: Order data to insert: $orderData');
      AppLogger.info('🔍 DEBUG: Client ID matches current user: ${clientId == currentUser.id}');

      final orderResponse = await _client
          .from(_ordersTable)
          .insert(orderData)
          .select('id, order_number')
          .single();

      final orderId = orderResponse['id'] as String;
      final orderNumber = orderResponse['order_number'] as String;

      AppLogger.info('✅ تم إنشاء الطلب: $orderNumber (ID: $orderId)');

      // إضافة عناصر الطلب
      final orderItems = cartItems.map((item) => {
        'order_id': orderId,
        'product_id': item.productId,
        'product_name': item.productName,
        'product_image': item.productImage,
        'unit_price': item.price,
        'quantity': item.quantity,
        'subtotal': item.price * item.quantity,
        'metadata': {
          'added_from': 'cart',
        },
      }).toList();

      await _client.from(_orderItemsTable).insert(orderItems);

      AppLogger.info('✅ تم إضافة ${orderItems.length} عنصر للطلب');

      // ===== PRICING APPROVAL WORKFLOW =====
      // Automatically hide prices when order requires pricing approval
      if (metadata?['requires_pricing_approval'] == true ||
          (metadata == null && true)) { // Default to true for all orders
        AppLogger.info('🔒 Order requires pricing approval - hiding prices from customers');

        if (_appSettingsProvider != null) {
          try {
            _appSettingsProvider!.hidePricesForPricingApproval();
            AppLogger.info('✅ Successfully hid prices for pricing approval workflow');
          } catch (e) {
            AppLogger.error('❌ Failed to hide prices for pricing approval: $e');
          }
        } else {
          AppLogger.warning('⚠️ AppSettingsProvider not set - cannot hide prices automatically');
        }
      }

      // 🔔 إرسال الإشعارات بعد إنشاء الطلب بنجاح
      await _sendOrderCreationNotifications(
        orderId: orderId,
        orderNumber: orderNumber,
        clientId: clientId,
        clientName: clientName,
        totalAmount: total,
      );

      return orderId;
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء الطلب: $e');

      // 🔍 DEBUG: Enhanced error logging
      if (e is PostgrestException) {
        AppLogger.error('🔍 DEBUG: PostgrestException details:');
        AppLogger.error('  - Message: ${e.message}');
        AppLogger.error('  - Code: ${e.code}');
        AppLogger.error('  - Details: ${e.details}');
        AppLogger.error('  - Hint: ${e.hint}');
      }

      return null;
    }
  }

  /// جلب طلبات العميل
  Future<List<ClientOrder>> getClientOrders(String clientId) async {
    try {
      AppLogger.info('🔄 جلب طلبات العميل: $clientId');

      final response = await _client
          .from(_ordersTable)
          .select('''
            *,
            client_order_items(*),
            order_tracking_links(*)
          ''')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      final orders = (response as List).map((orderData) {
        return _mapToClientOrder(orderData as Map<String, dynamic>);
      }).toList();

      AppLogger.info('✅ تم جلب ${orders.length} طلب للعميل');
      return orders;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب طلبات العميل: $e');
      return [];
    }
  }

  /// جلب جميع الطلبات (للإدارة)
  Future<List<ClientOrder>> getAllOrders() async {
    try {
      AppLogger.info('🔄 جلب جميع الطلبات...');

      final response = await _client
          .from(_ordersTable)
          .select('''
            *,
            client_order_items(*),
            order_tracking_links(*)
          ''')
          .order('created_at', ascending: false);

      final orders = <ClientOrder>[];
      for (final orderData in response) {
        final order = await _mapToClientOrderWithUserInfo(orderData);
        orders.add(order);
      }

      AppLogger.info('✅ تم جلب ${orders.length} طلب');
      return orders;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب جميع الطلبات: $e');
      return [];
    }
  }

  /// جلب تفاصيل طلب محدد
  Future<ClientOrder?> getOrderById(String orderId) async {
    try {
      AppLogger.info('🔄 جلب تفاصيل الطلب: $orderId');

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

      final order = _mapToClientOrder(response);
      AppLogger.info('✅ تم جلب تفاصيل الطلب');
      return order;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب تفاصيل الطلب: $e');
      return null;
    }
  }

  /// تحديث حالة الطلب
  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      AppLogger.info('🔄 تحديث حالة الطلب: $orderId إلى $status');

      // ===== CRITICAL PRICING APPROVAL VALIDATION =====
      // If trying to update to confirmed status, check pricing approval requirements
      if (status == OrderStatus.confirmed) {
        AppLogger.info('🔒 SERVICE VALIDATION: Checking pricing approval for order $orderId before confirming');

        // Get current order data to check pricing requirements
        final orderResponse = await _client
            .from(_ordersTable)
            .select('pricing_status, metadata')
            .eq('id', orderId)
            .single();

        final pricingStatus = orderResponse['pricing_status'] as String?;
        final metadata = orderResponse['metadata'] as Map<String, dynamic>?;
        final requiresPricingApproval = metadata?['requires_pricing_approval'] == true;

        AppLogger.info('  - requiresPricingApproval: $requiresPricingApproval');
        AppLogger.info('  - pricingStatus: $pricingStatus');

        // Block confirmation if pricing approval is required but not completed
        if (requiresPricingApproval && pricingStatus != 'pricing_approved') {
          AppLogger.error('❌ SERVICE VALIDATION FAILED: Order $orderId requires pricing approval but status is: $pricingStatus');
          throw Exception('لا يمكن تأكيد الطلب - يجب اعتماد التسعير أولاً');
        }

        AppLogger.info('✅ SERVICE VALIDATION PASSED: Order $orderId can be confirmed');
      }

      await _client
          .from(_ordersTable)
          .update({
            'status': status.toString().split('.').last,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      AppLogger.info('✅ تم تحديث حالة الطلب');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث حالة الطلب: $e');
      return false;
    }
  }

  /// تحديث حالة الدفع
  Future<bool> updatePaymentStatus(String orderId, PaymentStatus paymentStatus) async {
    try {
      AppLogger.info('🔄 تحديث حالة الدفع: $orderId إلى $paymentStatus');

      await _client
          .from(_ordersTable)
          .update({
            'payment_status': paymentStatus.toString().split('.').last,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      AppLogger.info('✅ تم تحديث حالة الدفع');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث حالة الدفع: $e');
      return false;
    }
  }

  /// تعيين طلب لموظف
  Future<bool> assignOrderTo(String orderId, String assignedTo) async {
    try {
      AppLogger.info('🔄 تعيين الطلب: $orderId للموظف: $assignedTo');

      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      await _client
          .from(_ordersTable)
          .update({
            'assigned_to': assignedTo,
            'assigned_by': currentUser.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      AppLogger.info('✅ تم تعيين الطلب');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في تعيين الطلب: $e');
      return false;
    }
  }

  /// إضافة رابط متابعة
  Future<bool> addTrackingLink({
    required String orderId,
    required String url,
    required String title,
    required String description,
    required String createdBy,
    String linkType = 'tracking',
  }) async {
    try {
      AppLogger.info('🔄 إضافة رابط متابعة للطلب: $orderId');

      // الحصول على اسم المستخدم
      final userProfile = await _client
          .from('user_profiles')
          .select('name')
          .eq('id', createdBy)
          .single();

      final trackingData = {
        'order_id': orderId,
        'title': title,
        'description': description,
        'url': url,
        'link_type': linkType,
        'created_by': createdBy,
        'created_by_name': userProfile['name'] ?? 'مستخدم غير معروف',
        'is_active': true,
        'metadata': {
          'created_from': 'admin_panel',
        },
      };

      await _client.from(_trackingLinksTable).insert(trackingData);

      AppLogger.info('✅ تم إضافة رابط المتابعة');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في إضافة رابط المتابعة: $e');
      return false;
    }
  }

  /// جلب تاريخ الطلب
  Future<List<Map<String, dynamic>>> getOrderHistory(String orderId) async {
    try {
      AppLogger.info('🔄 جلب تاريخ الطلب: $orderId');

      final response = await _client
          .from(_orderHistoryTable)
          .select('*')
          .eq('order_id', orderId)
          .order('created_at', ascending: false);

      AppLogger.info('✅ تم جلب ${response.length} سجل من تاريخ الطلب');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب تاريخ الطلب: $e');
      return [];
    }
  }

  /// جلب إشعارات المستخدم
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId, {bool unreadOnly = false}) async {
    try {
      AppLogger.info('🔄 جلب إشعارات المستخدم: $userId');

      var query = _client
          .from(_notificationsTable)
          .select('*')
          .eq('recipient_id', userId);

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response = await query.order('created_at', ascending: false);

      AppLogger.info('✅ تم جلب ${response.length} إشعار');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب الإشعارات: $e');
      return [];
    }
  }

  /// تحديد إشعار كمقروء
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _client
          .from(_notificationsTable)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث الإشعار: $e');
      return false;
    }
  }

  /// جلب إحصائيات الطلبات - محسّن لاستخدام البيانات الموجودة
  Future<Map<String, dynamic>?> getOrderStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('🔄 جلب إحصائيات الطلبات باستخدام البيانات المباشرة...');

      // استخدام نفس الطريقة المُجربة والناجحة في جلب الطلبات
      // بدلاً من الاعتماد على دوال Supabase غير الموجودة
      final response = await _client
          .from(_ordersTable)
          .select('id, status, total_amount, created_at, payment_status')
          .order('created_at', ascending: false);

      if (response == null || response.isEmpty) {
        AppLogger.warning('⚠️ لا توجد طلبات في قاعدة البيانات');
        return _getFallbackStatistics();
      }

      // تطبيق فلتر التاريخ إذا تم تحديده
      List<dynamic> filteredOrders = response;
      if (startDate != null || endDate != null) {
        filteredOrders = response.where((order) {
          final orderDate = DateTime.parse(order['created_at'] as String);

          if (startDate != null && orderDate.isBefore(startDate)) {
            return false;
          }
          if (endDate != null && orderDate.isAfter(endDate.add(const Duration(days: 1)))) {
            return false;
          }
          return true;
        }).toList();
      }

      // حساب الإحصائيات من البيانات المُستلمة
      final statistics = _calculateStatisticsFromOrders(filteredOrders);

      AppLogger.info('✅ تم حساب الإحصائيات بنجاح من ${filteredOrders.length} طلب');
      return statistics;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب إحصائيات الطلبات: $e');
      return _getFallbackStatistics();
    }
  }

  /// حساب الإحصائيات من قائمة الطلبات
  Map<String, dynamic> _calculateStatisticsFromOrders(List<dynamic> orders) {
    if (orders.isEmpty) {
      return _getFallbackStatistics();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeekStart = today.subtract(Duration(days: now.weekday - 1));
    final thisMonthStart = DateTime(now.year, now.month, 1);

    int totalOrders = orders.length;
    int pendingOrders = 0;
    int confirmedOrders = 0;
    int processingOrders = 0;
    int shippedOrders = 0;
    int deliveredOrders = 0;
    int cancelledOrders = 0;
    int todayOrders = 0;
    int thisWeekOrders = 0;
    int thisMonthOrders = 0;

    double totalRevenue = 0.0;
    double todayRevenue = 0.0;
    double thisWeekRevenue = 0.0;
    double thisMonthRevenue = 0.0;

    for (final order in orders) {
      final status = (order['status'] as String? ?? 'pending').toLowerCase();
      final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      final createdAt = DateTime.parse(order['created_at'] as String);
      final orderDate = DateTime(createdAt.year, createdAt.month, createdAt.day);

      // حساب الطلبات حسب الحالة
      switch (status) {
        case 'pending':
        case 'قيد المعالجة':
          pendingOrders++;
          break;
        case 'confirmed':
        case 'تم التأكيد':
          confirmedOrders++;
          break;
        case 'processing':
        case 'تحت التصنيع':
          processingOrders++;
          break;
        case 'shipped':
        case 'تم الشحن':
          shippedOrders++;
          break;
        case 'delivered':
        case 'تم التسليم':
          deliveredOrders++;
          break;
        case 'cancelled':
        case 'ملغي':
          cancelledOrders++;
          break;
      }

      // حساب الإيرادات (استثناء الطلبات الملغية)
      if (status != 'cancelled' && status != 'ملغي') {
        totalRevenue += totalAmount;

        // حساب الإيرادات حسب الفترة الزمنية
        if (orderDate.isAtSameMomentAs(today)) {
          todayRevenue += totalAmount;
        }
        if (orderDate.isAfter(thisWeekStart.subtract(const Duration(days: 1)))) {
          thisWeekRevenue += totalAmount;
        }
        if (orderDate.isAfter(thisMonthStart.subtract(const Duration(days: 1)))) {
          thisMonthRevenue += totalAmount;
        }
      }

      // حساب الطلبات حسب الفترة الزمنية
      if (orderDate.isAtSameMomentAs(today)) {
        todayOrders++;
      }
      if (orderDate.isAfter(thisWeekStart.subtract(const Duration(days: 1)))) {
        thisWeekOrders++;
      }
      if (orderDate.isAfter(thisMonthStart.subtract(const Duration(days: 1)))) {
        thisMonthOrders++;
      }
    }

    final averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    return {
      // Original format for backward compatibility
      'total_orders': totalOrders,
      'pending_orders': pendingOrders,
      'confirmed_orders': confirmedOrders,
      'processing_orders': processingOrders,
      'shipped_orders': shippedOrders,
      'delivered_orders': deliveredOrders,
      'cancelled_orders': cancelledOrders,
      'total_revenue': totalRevenue,
      'average_order_value': averageOrderValue,
      'today_orders': todayOrders,
      'this_week_orders': thisWeekOrders,
      'this_month_orders': thisMonthOrders,
      'today_revenue': todayRevenue,
      'this_week_revenue': thisWeekRevenue,
      'this_month_revenue': thisMonthRevenue,

      // Additional format for OptimizedAnalyticsService compatibility
      'totalOrders': totalOrders,
      'todayOrders': todayOrders,
      'pendingOrders': pendingOrders,
      'completedOrders': deliveredOrders,
      'totalOrderValue': totalRevenue,
    };
  }

  /// إحصائيات افتراضية في حالة فشل الدوال
  Map<String, dynamic> _getFallbackStatistics() {
    return {
      // Original format for backward compatibility
      'total_orders': 0,
      'pending_orders': 0,
      'confirmed_orders': 0,
      'processing_orders': 0,
      'shipped_orders': 0,
      'delivered_orders': 0,
      'cancelled_orders': 0,
      'total_revenue': 0.0,
      'average_order_value': 0.0,
      'today_orders': 0,
      'this_week_orders': 0,
      'this_month_orders': 0,
      'today_revenue': 0.0,
      'this_week_revenue': 0.0,
      'this_month_revenue': 0.0,

      // Additional format for OptimizedAnalyticsService compatibility
      'totalOrders': 0,
      'todayOrders': 0,
      'pendingOrders': 0,
      'completedOrders': 0,
      'totalOrderValue': 0.0,
    };
  }

  /// تحويل بيانات Supabase إلى ClientOrder مع معلومات المستخدم
  Future<ClientOrder> _mapToClientOrderWithUserInfo(Map<String, dynamic> data) async {
    // جلب معلومات المستخدم المعين إذا كان موجوداً
    String? assignedUserName;
    String? assignedUserRole;

    if (data['assigned_to'] != null) {
      try {
        final userProfile = await _client
            .from('user_profiles')
            .select('name, role')
            .eq('id', data['assigned_to'] as String)
            .maybeSingle();

        if (userProfile != null) {
          assignedUserName = userProfile['name'] as String?;
          assignedUserRole = userProfile['role'] as String?;
        }
      } catch (e) {
        AppLogger.warning('⚠️ لا يمكن جلب معلومات المستخدم المعين: $e');
      }
    }

    // تحويل عناصر الطلب
    final items = (data['client_order_items'] as List?)?.map((item) {
      return OrderItem(
        productId: (item['product_id'] as String?) ?? '',
        productName: (item['product_name'] as String?) ?? '',
        productImage: (item['product_image'] as String?) ?? '',
        price: ((item['unit_price'] as num?) ?? 0).toDouble(),
        quantity: (item['quantity'] as int?) ?? 0,
        total: ((item['subtotal'] as num?) ?? 0).toDouble(),
      );
    }).toList() ?? [];

    // تحويل روابط التتبع
    final trackingLinks = (data['order_tracking_links'] as List?)?.map((link) {
      return TrackingLink(
        id: (link['id'] as String?) ?? '',
        url: (link['url'] as String?) ?? '',
        title: (link['title'] as String?) ?? '',
        description: (link['description'] as String?) ?? '',
        createdAt: DateTime.parse((link['created_at'] as String?) ?? DateTime.now().toIso8601String()),
        createdBy: (link['created_by'] as String?) ?? '',
      );
    }).toList() ?? [];

    return ClientOrder(
      id: (data['id'] as String?) ?? '',
      clientId: (data['client_id'] as String?) ?? '',
      clientName: (data['client_name'] as String?) ?? '',
      clientEmail: (data['client_email'] as String?) ?? '',
      clientPhone: (data['client_phone'] as String?) ?? '',
      items: items,
      total: ((data['total_amount'] as num?) ?? 0).toDouble(),
      status: _parseOrderStatus(data['status'] as String?),
      paymentStatus: _parsePaymentStatus(data['payment_status'] as String?),
      createdAt: DateTime.parse((data['created_at'] as String?) ?? DateTime.now().toIso8601String()),
      updatedAt: data['updated_at'] != null ? DateTime.parse((data['updated_at'] as String?) ?? DateTime.now().toIso8601String()) : null,
      notes: (data['notes'] as String?),
      shippingAddress: _extractShippingAddress(data['shipping_address']),
      trackingLinks: trackingLinks,
      assignedTo: (data['assigned_to'] as String?),
      assignedUserName: assignedUserName,
      assignedUserRole: assignedUserRole,
      // Pricing approval fields
      pricingStatus: (data['pricing_status'] as String?),
      pricingApprovedBy: (data['pricing_approved_by'] as String?),
      pricingApprovedAt: data['pricing_approved_at'] != null
          ? DateTime.parse(data['pricing_approved_at'] as String)
          : null,
      pricingNotes: (data['pricing_notes'] as String?),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// تحويل بيانات Supabase إلى ClientOrder (بدون معلومات المستخدم)
  ClientOrder _mapToClientOrder(Map<String, dynamic> data) {
    // تحويل عناصر الطلب
    final items = (data['client_order_items'] as List?)?.map((item) {
      return OrderItem(
        productId: (item['product_id'] as String?) ?? '',
        productName: (item['product_name'] as String?) ?? '',
        productImage: (item['product_image'] as String?) ?? '',
        price: ((item['unit_price'] as num?) ?? 0).toDouble(),
        quantity: (item['quantity'] as int?) ?? 0,
        total: ((item['subtotal'] as num?) ?? 0).toDouble(),
      );
    }).toList() ?? [];

    // تحويل روابط التتبع
    final trackingLinks = (data['order_tracking_links'] as List?)?.map((link) {
      return TrackingLink(
        id: (link['id'] as String?) ?? '',
        url: (link['url'] as String?) ?? '',
        title: (link['title'] as String?) ?? '',
        description: (link['description'] as String?) ?? '',
        createdAt: DateTime.parse((link['created_at'] as String?) ?? DateTime.now().toIso8601String()),
        createdBy: (link['created_by'] as String?) ?? '',
      );
    }).toList() ?? [];

    return ClientOrder(
      id: (data['id'] as String?) ?? '',
      clientId: (data['client_id'] as String?) ?? '',
      clientName: (data['client_name'] as String?) ?? '',
      clientEmail: (data['client_email'] as String?) ?? '',
      clientPhone: (data['client_phone'] as String?) ?? '',
      items: items,
      total: ((data['total_amount'] as num?) ?? 0).toDouble(),
      status: _parseOrderStatus(data['status'] as String?),
      paymentStatus: _parsePaymentStatus(data['payment_status'] as String?),
      createdAt: DateTime.parse((data['created_at'] as String?) ?? DateTime.now().toIso8601String()),
      updatedAt: data['updated_at'] != null ? DateTime.parse((data['updated_at'] as String?) ?? DateTime.now().toIso8601String()) : null,
      notes: (data['notes'] as String?),
      shippingAddress: _extractShippingAddress(data['shipping_address']),
      trackingLinks: trackingLinks,
      assignedTo: (data['assigned_to'] as String?),
      // Pricing approval fields
      pricingStatus: (data['pricing_status'] as String?),
      pricingApprovedBy: (data['pricing_approved_by'] as String?),
      pricingApprovedAt: data['pricing_approved_at'] != null
          ? DateTime.parse(data['pricing_approved_at'] as String)
          : null,
      pricingNotes: (data['pricing_notes'] as String?),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// تحويل نص الحالة إلى enum
  OrderStatus _parseOrderStatus(String? status) {
    switch (status) {
      case 'pending': return OrderStatus.pending;
      case 'confirmed': return OrderStatus.confirmed;
      case 'processing': return OrderStatus.processing;
      case 'shipped': return OrderStatus.shipped;
      case 'delivered': return OrderStatus.delivered;
      case 'cancelled': return OrderStatus.cancelled;
      default: return OrderStatus.pending;
    }
  }

  /// تحويل نص حالة الدفع إلى enum
  PaymentStatus _parsePaymentStatus(String? status) {
    switch (status) {
      case 'pending': return PaymentStatus.pending;
      case 'paid': return PaymentStatus.paid;
      case 'failed': return PaymentStatus.failed;
      case 'refunded': return PaymentStatus.refunded;
      default: return PaymentStatus.pending;
    }
  }

  /// استخراج عنوان الشحن من البيانات
  String? _extractShippingAddress(dynamic shippingData) {
    if (shippingData == null) return null;

    // إذا كان نص مباشر
    if (shippingData is String) return shippingData;

    // إذا كان Map (الشكل الجديد)
    if (shippingData is Map<String, dynamic>) {
      return shippingData['address'] as String?;
    }

    return null;
  }

  /// إرسال إشعارات إنشاء الطلب للمستخدمين المناسبين
  Future<void> _sendOrderCreationNotifications({
    required String orderId,
    required String orderNumber,
    required String clientId,
    required String clientName,
    required double totalAmount,
  }) async {
    try {
      AppLogger.info('🔔 إرسال إشعارات إنشاء الطلب: $orderNumber');

      // إرسال إشعار للعميل
      await _notificationService.createOrderStatusNotification(
        userId: clientId,
        orderId: orderId,
        orderNumber: orderNumber,
        status: 'تم إنشاء طلبك بنجاح',
      );

      // إرسال إشعارات للإدارة والمحاسبين
      await _notificationService.createNewOrderNotificationForStaff(
        orderId: orderId,
        orderNumber: orderNumber,
        clientName: clientName,
        totalAmount: totalAmount,
      );

      AppLogger.info('✅ تم إرسال إشعارات إنشاء الطلب بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في إرسال إشعارات إنشاء الطلب: $e');
      // لا نرمي الخطأ هنا لأن إنشاء الطلب نجح، فقط الإشعارات فشلت
    }
  }

  void dispose() {
    // تنظيف الموارد إذا لزم الأمر
  }
}


