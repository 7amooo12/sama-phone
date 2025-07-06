import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../providers/supabase_provider.dart';
import '../services/real_notification_service.dart';
import '../utils/logger.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._supabaseProvider) {
    _initializeRealTimeSubscription();
  }

  final SupabaseProvider _supabaseProvider;
  final SupabaseClient _supabase = Supabase.instance.client;
  final RealNotificationService _notificationService = RealNotificationService();

  List<NotificationModel> _notifications = [];
  List<NotificationModel> _filteredNotifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;
  String? _currentCategory;
  RealtimeChannel? _notificationChannel;

  List<NotificationModel> get notifications => _filteredNotifications.isNotEmpty ? _filteredNotifications : _notifications;
  List<NotificationModel> get allNotifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;
  String? get currentCategory => _currentCategory;

  // Enhanced real-time subscription with optimized performance
  void _initializeRealTimeSubscription() {
    if (_supabaseProvider.user == null) return;

    try {
      // Dispose existing subscription if any
      _notificationChannel?.unsubscribe();

      final userId = _supabaseProvider.user!.id;
      final channelName = 'notifications_$userId';

      // Use periodic refresh for better compatibility
      _startPeriodicRefresh();

      AppLogger.info('🔄 Notification periodic refresh initialized for user: $userId');
    } catch (e) {
      AppLogger.error('❌ Failed to initialize notification subscription: $e');
      _retrySubscription();
    }
  }

  // Periodic refresh for notifications
  Timer? _refreshTimer;

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_supabaseProvider.user != null && !_isLoading) {
        _refreshNotificationsQuietly();
      }
    });
  }

  // Quiet refresh without loading indicators
  Future<void> _refreshNotificationsQuietly() async {
    try {
      final user = _supabaseProvider.user!;
      final newNotifications = await _notificationService.getRoleSpecificNotifications(
        user.id,
        user.userRole ?? 'client',
        unreadOnly: false,
      );

      // Only update if there are changes
      if (newNotifications.length != _notifications.length ||
          newNotifications.any((newNotif) =>
            !_notifications.any((oldNotif) =>
              oldNotif.id == newNotif.id &&
              oldNotif.isRead == newNotif.isRead))) {

        _notifications = newNotifications;

        // Apply category filter if active
        if (_currentCategory != null) {
          _applyRoleBasedFiltering();
        }

        _updateUnreadCount();
        notifyListeners();

        AppLogger.info('🔄 Notifications refreshed quietly: ${newNotifications.length} total');
      }
    } catch (e) {
      AppLogger.error('❌ Error in quiet refresh: $e');
    }
  }

  // Retry subscription with exponential backoff
  void _retrySubscription() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_supabaseProvider.user != null) {
        AppLogger.info('🔄 Retrying notification subscription...');
        _initializeRealTimeSubscription();
      }
    });
  }

  // Reinitialize subscription when user changes
  void reinitializeSubscription() {
    _refreshTimer?.cancel();
    _initializeRealTimeSubscription();
  }

  // Dispose method to clean up resources
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _notificationChannel?.unsubscribe();
    super.dispose();
  }

  // Enhanced role-based notification fetching
  Future<void> fetchNotifications({String? category}) async {
    if (_supabaseProvider.user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final user = _supabaseProvider.user!;

      // Fetch role-specific notifications
      _notifications = await _notificationService.getRoleSpecificNotifications(
        user.id,
        user.userRole ?? 'client',
        unreadOnly: false,
      );

      // Apply category filter if specified
      if (category != null) {
        _currentCategory = category;
        _applyRoleBasedFiltering();
      } else {
        _filteredNotifications = [];
        _currentCategory = null;
      }

      _updateUnreadCount();
      _isLoading = false;
      notifyListeners();

      AppLogger.info('✅ Fetched ${_notifications.length} role-specific notifications for ${user.userRole}');
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      AppLogger.error('❌ Error fetching notifications: $error');
    }
  }

  // Apply role-based filtering based on user role and category
  void _applyRoleBasedFiltering() {
    if (_supabaseProvider.user == null || _currentCategory == null) {
      _filteredNotifications = [];
      return;
    }

    final userRole = _supabaseProvider.user!.userRole?.toLowerCase() ?? 'client';

    _filteredNotifications = _notifications.where((notification) {
      return _isNotificationRelevantForRole(notification, userRole, _currentCategory!);
    }).toList();
  }

  // Check if notification is relevant for specific role and category
  bool _isNotificationRelevantForRole(NotificationModel notification, String userRole, String category) {
    final notificationType = notification.type.toLowerCase();

    // Category filtering
    if (category != 'all') {
      switch (category) {
        case 'orders':
          if (!notificationType.contains('order') && !notificationType.contains('payment')) {
            return false;
          }
          break;
        case 'vouchers':
          if (!notificationType.contains('voucher')) {
            return false;
          }
          break;
        case 'tasks':
          if (!notificationType.contains('task')) {
            return false;
          }
          break;
        case 'rewards':
          if (!notificationType.contains('reward') &&
              !notificationType.contains('bonus') &&
              !notificationType.contains('penalty')) {
            return false;
          }
          break;
        case 'inventory':
          if (!notificationType.contains('inventory') &&
              !notificationType.contains('product')) {
            return false;
          }
          break;
        case 'system':
          if (!notificationType.contains('system') &&
              !notificationType.contains('account')) {
            return false;
          }
          break;
        case 'customer_service':
          if (!notificationType.contains('customer_service')) {
            return false;
          }
          break;
      }
    }

    // Role-based filtering
    switch (userRole) {
      case 'owner':
      case 'admin':
      case 'manager':
        // Owners/admins see all business-related notifications
        return true;

      case 'worker':
        // Workers see task and reward notifications
        return notificationType.contains('task') ||
               notificationType.contains('reward') ||
               notificationType.contains('bonus') ||
               notificationType.contains('penalty') ||
               notificationType.contains('system');

      case 'client':
        // Clients see order, voucher, and inventory notifications
        return notificationType.contains('order') ||
               notificationType.contains('voucher') ||
               notificationType.contains('inventory') ||
               notificationType.contains('product') ||
               notificationType.contains('system');

      case 'accountant':
        // Accountants see order and financial notifications
        return notificationType.contains('order') ||
               notificationType.contains('payment') ||
               notificationType.contains('reward') ||
               notificationType.contains('system');

      case 'warehousemanager':
        // Warehouse managers see inventory and order notifications
        return notificationType.contains('inventory') ||
               notificationType.contains('product') ||
               notificationType.contains('order') ||
               notificationType.contains('system');

      default:
        // Default to system notifications only
        return notificationType.contains('system');
    }
  }

  // Filter notifications by category
  void filterByCategory(String category) {
    _currentCategory = category;
    _applyRoleBasedFiltering();
    notifyListeners();
  }

  // Clear category filter
  void clearCategoryFilter() {
    _currentCategory = null;
    _filteredNotifications = [];
    notifyListeners();
  }

  // Get notifications by priority
  List<NotificationModel> getNotificationsByPriority(String priority) {
    return _notifications.where((notification) {
      // Since the old model doesn't have priority, we'll infer it from type
      final type = notification.type.toLowerCase();
      switch (priority.toLowerCase()) {
        case 'high':
          return type.contains('urgent') ||
                 type.contains('penalty') ||
                 type.contains('payment') ||
                 type.contains('account_approved');
        case 'normal':
          return !type.contains('urgent') &&
                 !type.contains('penalty') &&
                 !type.contains('low');
        case 'low':
          return type.contains('low') || type.contains('info');
        default:
          return true;
      }
    }).toList();
  }

  // Get unread count by category
  int getUnreadCountByCategory(String category) {
    if (category == 'all') return _unreadCount;

    return _notifications.where((notification) {
      if (notification.isRead) return false;
      return _isNotificationRelevantForRole(
        notification,
        _supabaseProvider.user?.userRole?.toLowerCase() ?? 'client',
        category
      );
    }).length;
  }

  // Real implementation to mark notification as read using service
  Future<void> markAsRead(String notificationId) async {
    if (_supabaseProvider.user == null) return;

    try {
      final success = await _notificationService.markAsRead(notificationId, _supabaseProvider.user!.id);

      if (success) {
        // Update local state
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          _updateUnreadCount();
          notifyListeners();
        }
      }
    } catch (error) {
      AppLogger.error('❌ Error marking notification as read: $error');
    }
  }

  // Real implementation to mark all notifications as read using service
  Future<void> markAllAsRead() async {
    if (_supabaseProvider.user == null) return;

    try {
      final success = await _notificationService.markAllAsRead(_supabaseProvider.user!.id);

      if (success) {
        // Update local state
        _notifications = _notifications.map((notification) {
          return notification.copyWith(isRead: true);
        }).toList();

        _unreadCount = 0;
        notifyListeners();
      }
    } catch (error) {
      AppLogger.error('❌ Error marking all notifications as read: $error');
    }
  }

  // Real implementation to delete notification using service
  Future<void> deleteNotification(String notificationId) async {
    if (_supabaseProvider.user == null) return;

    try {
      final success = await _notificationService.deleteNotification(notificationId, _supabaseProvider.user!.id);

      if (success) {
        // Update local state
        _notifications.removeWhere((n) => n.id == notificationId);
        _updateUnreadCount();
        notifyListeners();
      }
    } catch (error) {
      AppLogger.error('❌ Error deleting notification: $error');
    }
  }

  // Update unread count
  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }

  // Enhanced notification creation with role-based targeting
  Future<void> createNotification({
    required String title,
    required String body,
    required String type,
    required String category,
    String priority = 'normal',
    String? route,
    String? referenceId,
    String? referenceType,
    Map<String, dynamic>? actionData,
    Map<String, dynamic>? metadata,
    String? targetUserId,
  }) async {
    final userId = targetUserId ?? _supabaseProvider.user?.id;
    if (userId == null) return;

    await _notificationService.createNotification(
      userId: userId,
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
  }

  // Create notifications for multiple users with specific roles
  Future<void> createNotificationsForRoles({
    required List<String> roles,
    required String title,
    required String body,
    required String type,
    required String category,
    String priority = 'normal',
    String? route,
    String? referenceId,
    String? referenceType,
    Map<String, dynamic>? actionData,
    Map<String, dynamic>? metadata,
  }) async {
    await _notificationService.createNotificationsForRoles(
      roles: roles,
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
  }

  // Enhanced specialized notification methods
  Future<void> createVoucherAssignmentNotification({
    required String userId,
    required String voucherId,
    required String voucherName,
    required int discountPercentage,
    required String expirationDate,
  }) async {
    await _notificationService.createVoucherAssignmentNotification(
      userId: userId,
      voucherId: voucherId,
      voucherName: voucherName,
      discountPercentage: discountPercentage,
      expirationDate: expirationDate,
    );
  }

  Future<void> createTaskAssignmentNotification({
    required String userId,
    required String taskId,
    required String taskTitle,
    String? dueDate,
    String? priority,
  }) async {
    await _notificationService.createTaskAssignmentNotification(
      userId: userId,
      taskId: taskId,
      taskTitle: taskTitle,
      dueDate: dueDate,
      priority: priority,
    );
  }

  Future<void> createRewardNotification({
    required String userId,
    required String rewardId,
    required double amount,
    required String rewardType,
    String? description,
  }) async {
    await _notificationService.createRewardNotification(
      userId: userId,
      rewardId: rewardId,
      amount: amount,
      rewardType: rewardType,
      description: description,
    );
  }

  Future<void> createInventoryUpdateNotification({
    required String productId,
    required String productName,
    required int stockQuantity,
    double? price,
  }) async {
    await _notificationService.createInventoryUpdateNotification(
      productId: productId,
      productName: productName,
      stockQuantity: stockQuantity,
      price: price,
    );
  }

  Future<void> createLowInventoryAlert({
    required String productId,
    required String productName,
    required int stockQuantity,
    int threshold = 5,
  }) async {
    await _notificationService.createLowInventoryAlert(
      productId: productId,
      productName: productName,
      stockQuantity: stockQuantity,
      threshold: threshold,
    );
  }

  // Get notification statistics
  Future<Map<String, int>> getNotificationStats() async {
    if (_supabaseProvider.user == null) return {};

    return await _notificationService.getNotificationStats(_supabaseProvider.user!.id);
  }

  // Clean up expired notifications
  Future<int> cleanupExpiredNotifications() async {
    return await _notificationService.cleanupExpiredNotifications();
  }

  // Optimized handlers for real-time notifications
  void _handleNewNotificationOptimized(Map<String, dynamic> data) {
    try {
      final notification = NotificationModel.fromMap(data, data['id']?.toString() ?? '');

      // Check if notification is relevant for current user role and category filter
      if (_shouldShowNotification(notification)) {
        _notifications.insert(0, notification);

        // Update filtered list if category filter is active
        if (_currentCategory != null) {
          _applyRoleBasedFiltering();
        }

        _updateUnreadCount();
        notifyListeners();

        AppLogger.info('🔔 New notification received: ${notification.title}');
      }
    } catch (e) {
      AppLogger.error('❌ Error handling new notification: $e');
    }
  }

  void _handleUpdatedNotificationOptimized(Map<String, dynamic> data) {
    try {
      final updatedNotification = NotificationModel.fromMap(data, data['id']?.toString() ?? '');
      final index = _notifications.indexWhere((n) => n.id == updatedNotification.id);

      if (index != -1) {
        _notifications[index] = updatedNotification;

        // Update filtered list if category filter is active
        if (_currentCategory != null) {
          _applyRoleBasedFiltering();
        }

        _updateUnreadCount();
        notifyListeners();

        AppLogger.info('🔄 Notification updated: ${updatedNotification.title}');
      }
    } catch (e) {
      AppLogger.error('❌ Error handling updated notification: $e');
    }
  }

  void _handleDeletedNotification(Map<String, dynamic> data) {
    try {
      final notificationId = data['id']?.toString();
      if (notificationId != null) {
        _notifications.removeWhere((n) => n.id == notificationId);

        // Update filtered list if category filter is active
        if (_currentCategory != null) {
          _applyRoleBasedFiltering();
        }

        _updateUnreadCount();
        notifyListeners();

        AppLogger.info('✅ Notification deleted: $notificationId');
      }
    } catch (e) {
      AppLogger.error('❌ Error handling deleted notification: $e');
    }
  }

  // Check if notification should be shown based on role and current filters
  bool _shouldShowNotification(NotificationModel notification) {
    if (_supabaseProvider.user == null) return false;

    final userRole = _supabaseProvider.user!.userRole?.toLowerCase() ?? 'client';

    // If no category filter, check role relevance
    if (_currentCategory == null) {
      return _isNotificationRelevantForRole(notification, userRole, 'all');
    }

    // If category filter is active, check both role and category relevance
    return _isNotificationRelevantForRole(notification, userRole, _currentCategory!);
  }

  // Legacy handlers for backward compatibility
  void _handleNewNotification(Map<String, dynamic> data) {
    _handleNewNotificationOptimized(data);
  }

  void _handleUpdatedNotification(Map<String, dynamic> data) {
    _handleUpdatedNotificationOptimized(data);
  }

  // Specialized methods for different notification types using service
  Future<void> createAccountApprovalNotification(String userId) async {
    await _notificationService.createAccountApprovalNotification(userId);
  }

  Future<void> createOrderCreatedNotification({
    required String orderId,
    required String orderNumber,
    required String userId,
  }) async {
    await _notificationService.createOrderCreatedNotification(
      userId: userId,
      orderId: orderId,
      orderNumber: orderNumber,
    );
  }

  Future<void> createOrderStatusNotification({
    required String orderId,
    required String orderNumber,
    required String userId,
    required String status,
  }) async {
    await _notificationService.createOrderStatusNotification(
      userId: userId,
      orderId: orderId,
      orderNumber: orderNumber,
      status: status,
    );
  }

  Future<void> createNewOrderNotificationForStaff({
    required String orderId,
    required String orderNumber,
    required String clientName,
    required double totalAmount,
  }) async {
    await _notificationService.createNewOrderNotificationForStaff(
      orderId: orderId,
      orderNumber: orderNumber,
      clientName: clientName,
      totalAmount: totalAmount,
    );
  }

}
