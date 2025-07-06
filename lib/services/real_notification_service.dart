import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../utils/logger.dart';

/// Enhanced Real Notification Service for SmartBizTracker
/// Production-ready service with role-based filtering, intelligent triggers, and comprehensive notification management
/// Supports all notification types: orders, vouchers, tasks, rewards, inventory, and system notifications
class RealNotificationService {
  factory RealNotificationService() => _instance;
  RealNotificationService._internal();
  static final RealNotificationService _instance = RealNotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Enhanced notification types matching database schema
  static const String typeOrderCreated = 'order_created';
  static const String typeOrderStatusChanged = 'order_status_changed';
  static const String typeOrderCompleted = 'order_completed';
  static const String typePaymentReceived = 'payment_received';
  static const String typeVoucherAssigned = 'voucher_assigned';
  static const String typeVoucherUsed = 'voucher_used';
  static const String typeVoucherExpired = 'voucher_expired';
  static const String typeTaskAssigned = 'task_assigned';
  static const String typeTaskCompleted = 'task_completed';
  static const String typeTaskFeedback = 'task_feedback';
  static const String typeRewardReceived = 'reward_received';
  static const String typePenaltyApplied = 'penalty_applied';
  static const String typeBonusAwarded = 'bonus_awarded';
  static const String typeInventoryLow = 'inventory_low';
  static const String typeInventoryUpdated = 'inventory_updated';
  static const String typeProductAdded = 'product_added';
  static const String typeAccountApproved = 'account_approved';
  static const String typeSystemAlert = 'system_alert';
  static const String typeGeneral = 'general';
  static const String typeCustomerServiceRequest = 'customer_service_request';
  static const String typeCustomerServiceUpdate = 'customer_service_update';

  // Notification categories
  static const String categoryOrders = 'orders';
  static const String categoryVouchers = 'vouchers';
  static const String categoryTasks = 'tasks';
  static const String categoryRewards = 'rewards';
  static const String categoryInventory = 'inventory';
  static const String categorySystem = 'system';
  static const String categoryGeneral = 'general';
  static const String categoryCustomerService = 'customer_service';

  // Priority levels
  static const String priorityLow = 'low';
  static const String priorityNormal = 'normal';
  static const String priorityHigh = 'high';
  static const String priorityUrgent = 'urgent';

  /// Enhanced notification creation with full schema support
  Future<bool> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String category,
    String priority = priorityNormal,
    String? route,
    String? referenceId,
    String? referenceType,
    Map<String, dynamic>? actionData,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notificationData = {
        'user_id': userId,
        'title': title,
        'body': body,
        'message': body, // For compatibility
        'type': type,
        'category': category,
        'priority': priority,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      if (route != null) notificationData['route'] = route;
      if (referenceId != null) notificationData['reference_id'] = referenceId;
      if (referenceType != null) notificationData['reference_type'] = referenceType;
      if (actionData != null) notificationData['action_data'] = actionData;
      if (metadata != null) notificationData['metadata'] = metadata;

      await _supabase.from('notifications').insert(notificationData);

      AppLogger.info('✅ Enhanced notification created: $title for user: $userId (Type: $type, Category: $category, Priority: $priority)');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error creating enhanced notification: $e');
      return false;
    }
  }

  /// Create notifications for multiple users with specific roles
  Future<int> createNotificationsForRoles({
    required List<String> roles,
    required String title,
    required String body,
    required String type,
    required String category,
    String priority = priorityNormal,
    String? route,
    String? referenceId,
    String? referenceType,
    Map<String, dynamic>? actionData,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Get all users with specified roles
      final usersResponse = await _supabase
          .from('user_profiles')
          .select('id, role, name')
          .inFilter('role', roles);

      final users = usersResponse as List;
      int notificationCount = 0;

      for (final user in users) {
        final success = await createNotification(
          userId: user['id'] as String,
          title: title,
          body: body,
          type: type,
          category: category,
          priority: priority,
          route: route,
          referenceId: referenceId,
          referenceType: referenceType,
          actionData: actionData,
          metadata: metadata,
        );

        if (success) notificationCount++;
      }

      AppLogger.info('✅ Created $notificationCount notifications for roles: ${roles.join(", ")}');
      return notificationCount;
    } catch (e) {
      AppLogger.error('❌ Error creating role-based notifications: $e');
      return 0;
    }
  }

  /// Create account approval notification
  Future<bool> createAccountApprovalNotification(String userId) async {
    return await createNotification(
      userId: userId,
      title: 'تم قبول حسابك',
      body: 'تم قبول حسابك بنجاح. يمكنك الآن استخدام التطبيق.',
      type: typeAccountApproved,
      category: categorySystem,
      priority: priorityHigh,
      route: '/dashboard',
      referenceType: 'account',
      metadata: {'currency': 'EGP'},
    );
  }

  /// Create order creation notification
  Future<bool> createOrderCreatedNotification({
    required String userId,
    required String orderId,
    required String orderNumber,
    double? totalAmount,
  }) async {
    return await createNotification(
      userId: userId,
      title: 'تم إنشاء طلبك بنجاح',
      body: 'تم إنشاء الطلب رقم $orderNumber بنجاح وسيتم مراجعته قريباً',
      type: typeOrderCreated,
      category: categoryOrders,
      priority: priorityNormal,
      route: '/orders/$orderId',
      referenceId: orderId,
      referenceType: 'order',
      actionData: {
        'order_number': orderNumber,
        'order_id': orderId,
        if (totalAmount != null) 'amount': totalAmount,
      },
      metadata: {'currency': 'EGP'},
    );
  }

  /// Create order status change notification
  Future<bool> createOrderStatusNotification({
    required String userId,
    required String orderId,
    required String orderNumber,
    required String status,
    double? totalAmount,
  }) async {
    return await createNotification(
      userId: userId,
      title: 'تم تحديث حالة طلبك',
      body: 'تم تحديث حالة طلبك رقم $orderNumber إلى: $status',
      type: typeOrderStatusChanged,
      category: categoryOrders,
      priority: status == 'completed' || status == 'delivered' ? priorityHigh : priorityNormal,
      route: '/orders/$orderId',
      referenceId: orderId,
      referenceType: 'order',
      actionData: {
        'order_number': orderNumber,
        'order_id': orderId,
        'status': status,
        if (totalAmount != null) 'amount': totalAmount,
      },
      metadata: {'currency': 'EGP'},
    );
  }

  /// Get role-specific route for order notifications - redirect to pending orders screen
  String _getOrderRouteForRole(String role, String orderId) {
    switch (role.toLowerCase()) {
      case 'accountant':
        return '/accountant/pending-orders';
      case 'admin':
      case 'manager':
        return '/admin/pending-orders';
      case 'owner':
        return '/admin/pending-orders'; // Owner uses admin pending orders screen
      default:
        return '/admin/pending-orders';
    }
  }

  /// Create notification for admin/staff about new order with role-based routing
  Future<bool> createNewOrderNotificationForStaff({
    required String orderId,
    required String orderNumber,
    required String clientName,
    required double totalAmount,
  }) async {
    try {
      // Create notifications for each role with appropriate routes
      final roles = ['admin', 'manager', 'accountant', 'owner'];
      bool allSuccess = true;

      for (final role in roles) {
        final route = _getOrderRouteForRole(role, orderId);

        final notificationCount = await createNotificationsForRoles(
          roles: [role],
          title: 'طلب جديد: $orderNumber',
          body: 'تم استلام طلب جديد من العميل $clientName بقيمة ${totalAmount.toStringAsFixed(2)} جنيه',
          type: typeOrderCreated,
          category: categoryOrders,
          priority: priorityHigh,
          route: route,
          referenceId: orderId,
          referenceType: 'order',
          actionData: {
            'order_id': orderId,
            'order_number': orderNumber,
            'client_name': clientName,
            'amount': totalAmount,
          },
          metadata: {'currency': 'EGP', 'requires_action': true},
        );

        if (notificationCount == 0) {
          allSuccess = false;
        }
      }

      return allSuccess;
    } catch (e) {
      AppLogger.error('❌ Error creating staff notifications: $e');
      return false;
    }
  }

  /// Create task assignment notification
  Future<bool> createTaskAssignmentNotification({
    required String userId,
    required String taskId,
    required String taskTitle,
    String? dueDate,
    String? priority,
  }) async {
    return await createNotification(
      userId: userId,
      title: 'تم تعيين مهمة جديدة لك',
      body: 'تم تعيين مهمة جديدة لك: $taskTitle${dueDate != null ? ' - موعد التسليم: $dueDate' : ''}',
      type: typeTaskAssigned,
      category: categoryTasks,
      priority: priority == 'high' ? priorityHigh : priorityNormal,
      route: '/worker/tasks/$taskId',
      referenceId: taskId,
      referenceType: 'task',
      actionData: {
        'task_id': taskId,
        'task_title': taskTitle,
        if (dueDate != null) 'due_date': dueDate,
        if (priority != null) 'task_priority': priority,
      },
      metadata: {'requires_action': true},
    );
  }

  /// Create voucher assignment notification
  Future<bool> createVoucherAssignmentNotification({
    required String userId,
    required String voucherId,
    required String voucherName,
    required int discountPercentage,
    required String expirationDate,
  }) async {
    return await createNotification(
      userId: userId,
      title: 'تم منحك قسيمة خصم جديدة!',
      body: 'تم منحك قسيمة خصم "$voucherName" بخصم $discountPercentage% صالحة حتى $expirationDate',
      type: typeVoucherAssigned,
      category: categoryVouchers,
      priority: priorityHigh,
      route: '/vouchers',
      referenceId: voucherId,
      referenceType: 'voucher',
      actionData: {
        'voucher_id': voucherId,
        'voucher_name': voucherName,
        'discount_percentage': discountPercentage,
        'expiration_date': expirationDate,
      },
      metadata: {'currency': 'EGP', 'action_required': false},
    );
  }

  /// Create reward/bonus notification
  Future<bool> createRewardNotification({
    required String userId,
    required String rewardId,
    required double amount,
    required String rewardType,
    String? description,
  }) async {
    final isPositive = amount > 0;
    final title = isPositive
        ? (rewardType == 'bonus' ? 'تم منحك مكافأة!' : 'تم إضافة مبلغ لحسابك')
        : 'تم خصم مبلغ من حسابك';

    final body = isPositive
        ? 'تم ${rewardType == 'bonus' ? 'منحك مكافأة' : 'إضافة'} ${amount.toStringAsFixed(2)} جنيه ${description != null ? '- $description' : ''}'
        : 'تم خصم ${amount.abs().toStringAsFixed(2)} جنيه من حسابك ${description != null ? '- $description' : ''}';

    return await createNotification(
      userId: userId,
      title: title,
      body: body,
      type: isPositive ? typeRewardReceived : typePenaltyApplied,
      category: categoryRewards,
      priority: priorityHigh,
      route: '/worker/rewards',
      referenceId: rewardId,
      referenceType: 'reward',
      actionData: {
        'reward_id': rewardId,
        'amount': amount,
        'reward_type': rewardType,
        if (description != null) 'description': description,
      },
      metadata: {'currency': 'EGP'},
    );
  }

  /// Create inventory update notification for clients
  Future<bool> createInventoryUpdateNotification({
    required String productId,
    required String productName,
    required int stockQuantity,
    double? price,
  }) async {
    try {
      return await createNotificationsForRoles(
        roles: ['client'],
        title: 'منتج جديد متوفر!',
        body: 'المنتج "$productName" أصبح متوفراً الآن في المتجر',
        type: typeInventoryUpdated,
        category: categoryInventory,
        priority: priorityNormal,
        route: '/products/$productId',
        referenceId: productId,
        referenceType: 'product',
        actionData: {
          'product_id': productId,
          'product_name': productName,
          'stock_quantity': stockQuantity,
          if (price != null) 'price': price,
        },
        metadata: {'currency': 'EGP', 'new_arrival': true},
      ) > 0;
    } catch (e) {
      AppLogger.error('❌ Error creating inventory update notifications: $e');
      return false;
    }
  }

  /// Create low inventory alert for staff
  Future<bool> createLowInventoryAlert({
    required String productId,
    required String productName,
    required int stockQuantity,
    int threshold = 5,
  }) async {
    try {
      return await createNotificationsForRoles(
        roles: ['admin', 'manager', 'owner', 'warehouseManager'],
        title: 'تحذير: مخزون منخفض',
        body: 'المنتج "$productName" يحتاج إعادة تموين - الكمية المتبقية: $stockQuantity',
        type: typeInventoryLow,
        category: categoryInventory,
        priority: priorityHigh,
        route: '/admin/products/$productId',
        referenceId: productId,
        referenceType: 'product',
        actionData: {
          'product_id': productId,
          'product_name': productName,
          'stock_quantity': stockQuantity,
          'threshold': threshold,
        },
        metadata: {'requires_action': true},
      ) > 0;
    } catch (e) {
      AppLogger.error('❌ Error creating low inventory alerts: $e');
      return false;
    }
  }

  /// Get notifications for a user with optional filtering
  Future<List<NotificationModel>> getUserNotifications(
    String userId, {
    String? category,
    String? type,
    bool? unreadOnly,
    int? limit,
  }) async {
    try {
      // Build query step by step without reassignment
      var queryBuilder = _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId);

      if (category != null) {
        queryBuilder = queryBuilder.eq('category', category);
      }

      if (type != null) {
        queryBuilder = queryBuilder.eq('type', type);
      }

      if (unreadOnly == true) {
        queryBuilder = queryBuilder.eq('is_read', false);
      }

      // Apply ordering and limit in final chain
      var finalQuery = queryBuilder.order('created_at', ascending: false);

      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }

      final response = await finalQuery;

      return (response as List<dynamic>? ?? [])
          .map((json) => NotificationModel.fromMap(json as Map<String, dynamic>, json['id'] as String?))
          .toList();
    } catch (e) {
      AppLogger.error('❌ Error fetching notifications: $e');
      return [];
    }
  }

  /// Get notifications by category for role-based filtering
  Future<List<NotificationModel>> getNotificationsByCategory(
    String userId,
    List<String> categories, {
    bool unreadOnly = false,
    int? limit,
  }) async {
    try {
      // Build query step by step without reassignment
      var queryBuilder = _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .inFilter('category', categories);

      if (unreadOnly) {
        queryBuilder = queryBuilder.eq('is_read', false);
      }

      // Apply ordering and limit in final chain
      var finalQuery = queryBuilder.order('created_at', ascending: false);

      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }

      final response = await finalQuery;

      return (response as List<dynamic>? ?? [])
          .map((json) => NotificationModel.fromMap(json as Map<String, dynamic>, json['id'] as String?))
          .toList();
    } catch (e) {
      AppLogger.error('❌ Error fetching notifications by category: $e');
      return [];
    }
  }

  /// Get role-specific notifications based on user role
  Future<List<NotificationModel>> getRoleSpecificNotifications(
    String userId,
    String userRole, {
    bool unreadOnly = false,
    int? limit,
  }) async {
    List<String> relevantCategories;

    switch (userRole.toLowerCase()) {
      case 'owner':
      case 'admin':
      case 'manager':
        relevantCategories = [categoryOrders, categoryInventory, categoryTasks, categoryRewards, categorySystem, categoryCustomerService];
        break;
      case 'worker':
        relevantCategories = [categoryTasks, categoryRewards, categorySystem];
        break;
      case 'client':
        relevantCategories = [categoryOrders, categoryVouchers, categoryInventory, categorySystem, categoryCustomerService];
        break;
      case 'accountant':
        relevantCategories = [categoryOrders, categoryRewards, categorySystem];
        break;
      case 'warehousemanager':
        relevantCategories = [categoryInventory, categoryOrders, categorySystem];
        break;
      default:
        relevantCategories = [categorySystem, categoryGeneral];
    }

    return await getNotificationsByCategory(
      userId,
      relevantCategories,
      unreadOnly: unreadOnly,
      limit: limit,
    );
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId, String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId)
          .eq('user_id', userId);

      AppLogger.info('✅ Notification marked as read: $notificationId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read for a user
  Future<bool> markAllAsRead(String userId, {String? category}) async {
    try {
      var query = _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);

      if (category != null) {
        query = query.eq('category', category);
      }

      await query;

      AppLogger.info('✅ All notifications marked as read for user: $userId${category != null ? ' (category: $category)' : ''}');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Delete notification
  Future<bool> deleteNotification(String notificationId, String userId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', userId);

      AppLogger.info('✅ Notification deleted: $notificationId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error deleting notification: $e');
      return false;
    }
  }

  /// Delete all read notifications for a user
  Future<bool> deleteAllReadNotifications(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId)
          .eq('is_read', true);

      AppLogger.info('✅ All read notifications deleted for user: $userId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error deleting read notifications: $e');
      return false;
    }
  }

  /// Get unread notification count for a user
  Future<int> getUnreadCount(String userId, {String? category}) async {
    try {
      var query = _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      if (category != null) {
        query = query.eq('category', category);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      AppLogger.error('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Get notification statistics for a user
  Future<Map<String, int>> getNotificationStats(String userId) async {
    try {
      final allResponse = await _supabase
          .from('notifications')
          .select('category, is_read')
          .eq('user_id', userId);

      final notifications = allResponse as List;
      final stats = <String, int>{
        'total': notifications.length,
        'unread': 0,
        'read': 0,
      };

      // Count by category
      for (final category in [categoryOrders, categoryVouchers, categoryTasks, categoryRewards, categoryInventory, categorySystem]) {
        stats['${category}_total'] = 0;
        stats['${category}_unread'] = 0;
      }

      for (final notification in notifications) {
        final isRead = notification['is_read'] as bool;
        final category = notification['category'] as String?;

        if (isRead) {
          stats['read'] = (stats['read'] ?? 0) + 1;
        } else {
          stats['unread'] = (stats['unread'] ?? 0) + 1;
        }

        if (category != null) {
          stats['${category}_total'] = (stats['${category}_total'] ?? 0) + 1;
          if (!isRead) {
            stats['${category}_unread'] = (stats['${category}_unread'] ?? 0) + 1;
          }
        }
      }

      return stats;
    } catch (e) {
      AppLogger.error('❌ Error getting notification stats: $e');
      return {'total': 0, 'unread': 0, 'read': 0};
    }
  }

  /// Clean up expired notifications
  Future<int> cleanupExpiredNotifications() async {
    try {
      final response = await _supabase
          .from('notifications')
          .delete()
          .lt('expires_at', DateTime.now().toIso8601String());

      final deletedCount = (response as List?)?.length ?? 0;
      AppLogger.info('✅ Cleaned up $deletedCount expired notifications');
      return deletedCount;
    } catch (e) {
      AppLogger.error('❌ Error cleaning up expired notifications: $e');
      return 0;
    }
  }


}
