import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';
import '../models/notification_model.dart';
import 'database_service.dart';

class EnhancedNotificationService {
  factory EnhancedNotificationService() => _instance;
  EnhancedNotificationService._internal();
  static final EnhancedNotificationService _instance = EnhancedNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final DatabaseService _databaseService = DatabaseService();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permissions
      await _requestPermissions();

      // Android initialization
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      AppLogger.info('Enhanced notification service initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize enhanced notification service', e);
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final status = await Permission.notification.request();
      if (status.isDenied) {
        AppLogger.warning('Notification permission denied');
      }
    } catch (e) {
      AppLogger.error('Failed to request notification permissions', e);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.info('Notification tapped: ${response.payload}');
    // Handle notification tap
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.defaultPriority,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'default_channel',
        'Default Channel',
        channelDescription: 'Default notification channel',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      AppLogger.info('Notification shown: $title');
    } catch (e) {
      AppLogger.error('Failed to show notification', e);
    }
  }

  Future<void> showOrderNotification({
    required String orderId,
    required String customerName,
    required String status,
  }) async {
    await showNotification(
      id: orderId.hashCode,
      title: 'طلب جديد',
      body: 'طلب جديد من $customerName - الحالة: $status',
      payload: 'order:$orderId',
    );
  }

  Future<void> showInventoryAlert({
    required String productName,
    required int currentStock,
    required int minStock,
  }) async {
    await showNotification(
      id: productName.hashCode,
      title: 'تنبيه المخزون',
      body: 'المنتج $productName أوشك على النفاد (المتوفر: $currentStock، الحد الأدنى: $minStock)',
      payload: 'inventory:$productName',
      priority: NotificationPriority.high,
    );
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      AppLogger.info('Notification cancelled: $id');
    } catch (e) {
      AppLogger.error('Failed to cancel notification', e);
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      AppLogger.info('All notifications cancelled');
    } catch (e) {
      AppLogger.error('Failed to cancel all notifications', e);
    }
  }

  // Get user notifications from database
  Future<List<NotificationModel>> getUserNotifications() async {
    try {
      // For now, return empty list since we need user ID
      // This should be called with proper user context
      return [];
    } catch (e) {
      AppLogger.error('Failed to get user notifications', e);
      return [];
    }
  }
}

enum NotificationPriority {
  min,
  low,
  defaultPriority,
  high,
  max,
}
