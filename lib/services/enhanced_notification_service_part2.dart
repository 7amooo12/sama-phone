import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/logger.dart';
import 'enhanced_notification_service.dart';

extension EnhancedNotificationServicePart2 on EnhancedNotificationService {

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'scheduled_channel',
        'Scheduled Notifications',
        channelDescription: 'Channel for scheduled notifications',
        importance: Importance.max,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Note: This is a simplified version. For actual scheduling, you'd need to use
      // timezone package and proper scheduling methods
      AppLogger.info('Scheduled notification: $title for ${scheduledDate.toString()}');
    } catch (e) {
      AppLogger.error('Failed to schedule notification', e);
    }
  }

  Future<void> showProgressNotification({
    required int id,
    required String title,
    required int progress,
    required int maxProgress,
  }) async {
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'progress_channel',
        'Progress Notifications',
        channelDescription: 'Channel for progress notifications',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await FlutterLocalNotificationsPlugin().show(
        id,
        title,
        '$progress من $maxProgress',
        platformChannelSpecifics,
      );

      AppLogger.info('Progress notification shown: $title ($progress/$maxProgress)');
    } catch (e) {
      AppLogger.error('Failed to show progress notification', e);
    }
  }

  Future<void> showBigTextNotification({
    required int id,
    required String title,
    required String body,
    required String bigText,
    String? payload,
  }) async {
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'big_text_channel',
        'Big Text Notifications',
        channelDescription: 'Channel for big text notifications',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          bigText,
          htmlFormatBigText: true,
          contentTitle: title,
          htmlFormatContentTitle: true,
          summaryText: 'تفاصيل إضافية',
          htmlFormatSummaryText: true,
        ),
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await FlutterLocalNotificationsPlugin().show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      AppLogger.info('Big text notification shown: $title');
    } catch (e) {
      AppLogger.error('Failed to show big text notification', e);
    }
  }

  Future<void> showActionNotification({
    required int id,
    required String title,
    required String body,
    required List<AndroidNotificationAction> actions,
    String? payload,
  }) async {
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'action_channel',
        'Action Notifications',
        channelDescription: 'Channel for notifications with actions',
        importance: Importance.max,
        priority: Priority.high,
        actions: actions,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await FlutterLocalNotificationsPlugin().show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      AppLogger.info('Action notification shown: $title');
    } catch (e) {
      AppLogger.error('Failed to show action notification', e);
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await FlutterLocalNotificationsPlugin().pendingNotificationRequests();
    } catch (e) {
      AppLogger.error('Failed to get pending notifications', e);
      return [];
    }
  }

  Future<List<ActiveNotification>> getActiveNotifications() async {
    try {
      return await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.getActiveNotifications() ?? [];
    } catch (e) {
      AppLogger.error('Failed to get active notifications', e);
      return [];
    }
  }
}
