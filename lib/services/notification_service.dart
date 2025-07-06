import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../models/notification_model.dart';

class NotificationService {
  final _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    try {
      // Initialize local notifications
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsIOS = DarwinInitializationSettings();
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      AppLogger.info('Notification service initialized');
    } catch (error) {
      AppLogger.error('Error initializing notification service: $error');
    }
  }

  Future<void> subscribeToNotifications(String userId) async {
    try {
      final channel = _supabase.channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _handleNotificationPayload(payload.newRecord ?? {});
          }
        ).subscribe();

      AppLogger.info('Subscribed to notifications for user: $userId');
    } catch (e) {
      AppLogger.error('Error subscribing to notifications: $e');
    }
  }

  Future<void> _handleNotificationPayload(Map<String, dynamic> payload) async {
    try {
      final notification = NotificationModel.fromJson(payload);
      await showLocalNotification(
        notification.id,
        notification.title,
        notification.body,
      );
    } catch (e) {
      AppLogger.error('Error handling notification payload: $e');
    }
  }

  Future<void> showLocalNotification(
    String id,
    String title,
    String body, {
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'default_channel',
        'Default Channel',
        channelDescription: 'Default notification channel',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id.hashCode,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      AppLogger.error('Error showing local notification: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    try {
      final payload = response.payload;
      if (payload != null) {
        // Handle notification tap
        AppLogger.info('Notification tapped: $payload');
      }
    } catch (e) {
      AppLogger.error('Error handling notification tap: $e');
    }
  }

  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => NotificationModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting notifications: $e');
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      AppLogger.error('Error marking notification as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      AppLogger.error('Error deleting notification: $e');
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      AppLogger.error('Error getting unread count: $e');
      return 0;
    }
  }

  // Missing methods for compatibility
  Future<void> sendOrderNotification({
    required String orderId,
    required String customerName,
    required String status,
  }) async {
    try {
      await showLocalNotification(
        orderId,
        'طلب جديد',
        'طلب جديد من $customerName - الحالة: $status',
        payload: 'order:$orderId',
      );
      AppLogger.info('Order notification sent for order: $orderId');
    } catch (e) {
      AppLogger.error('Error sending order notification: $e');
    }
  }
}

