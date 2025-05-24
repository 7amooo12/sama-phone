import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
// import '../providers/auth_provider.dart';
import '../providers/supabase_provider.dart';
import '../utils/logger.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._supabaseProvider) {
    // Create mock notifications for testing
    _createMockNotifications();
  }
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseProvider _supabaseProvider;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  // Create mock notifications for testing
  void _createMockNotifications() {
    if (_supabaseProvider.user == null) return;

    _notifications = [
      NotificationModel(
        id: 'notification-1',
        userId: _supabaseProvider.user!.id,
        title: 'مرحبًا بك في التطبيق',
        body: 'شكرًا لاستخدامك تطبيق SmartBizTracker. نتمنى لك تجربة ممتعة.',
        type: 'system',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      NotificationModel(
        id: 'notification-2',
        userId: _supabaseProvider.user!.id,
        title: 'تم تحديث الطلب #12345',
        body: 'تم تغيير حالة الطلب إلى "قيد التنفيذ"',
        type: 'order',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        route: '/orders/details',
        data: {'orderId': '12345'},
      ),
      NotificationModel(
        id: 'notification-3',
        userId: _supabaseProvider.user!.id,
        title: 'عرض خاص',
        body: 'استمتع بخصم 20% على جميع المنتجات لمدة 24 ساعة فقط!',
        type: 'promotion',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    _updateUnreadCount();
  }

  // Mock implementation for testing
  Future<void> fetchNotifications() async {
    if (_supabaseProvider.user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Notifications are already created in constructor
      // Just update the unread count
      _updateUnreadCount();

      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      // Handle error
      AppLogger.error('Error fetching notifications', error);
    }
  }

  // Mock implementation for testing
  Future<void> markAsRead(String notificationId) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 300));

      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _updateUnreadCount();
        notifyListeners();
      }
    } catch (error) {
      // Handle error
      AppLogger.error('Error marking notification as read', error);
    }
  }

  // Mock implementation for testing
  Future<void> markAllAsRead() async {
    if (_supabaseProvider.user == null) return;

    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Update local state
      _notifications = _notifications.map((notification) {
        return notification.copyWith(isRead: true);
      }).toList();

      _unreadCount = 0;
      notifyListeners();
    } catch (error) {
      // Handle error
      AppLogger.error('Error marking all notifications as read', error);
    }
  }

  // Mock implementation for testing
  Future<void> deleteNotification(String notificationId) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 300));

      // Update local state
      _notifications.removeWhere((n) => n.id == notificationId);
      _updateUnreadCount();
      notifyListeners();
    } catch (error) {
      // Handle error
      AppLogger.error('Error deleting notification', error);
    }
  }

  // Update unread count
  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }

  // Mock implementation for testing
  Future<void> createNotification({
    required String title,
    required String body,
    required String type,
    String? route,
    Map<String, dynamic>? data,
  }) async {
    if (_supabaseProvider.user == null) return;

    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      final notification = NotificationModel(
        id: 'notification-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        type: type,
        isRead: false,
        createdAt: DateTime.now(),
        userId: _supabaseProvider.user!.id,
        route: route,
        data: data,
      );

      // Update local state
      _notifications.insert(0, notification);
      _updateUnreadCount();
      notifyListeners();
    } catch (error) {
      // Handle error
      AppLogger.error('Error creating notification', error);
    }
  }
}
