import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/notification_provider.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/services/enhanced_notification_service.dart';
import 'package:smartbiztracker_new/services/enhanced_notification_service_part2.dart';
import 'package:smartbiztracker_new/widgets/common/animated_widgets.dart';
import 'package:smartbiztracker_new/utils/responsive_builder.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final EnhancedNotificationService _notificationService = EnhancedNotificationService();
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    // Fetch notifications using both providers for backward compatibility
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNotifications();
    });
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      if (!_isRefreshing) {
        _isLoading = true;
      }
    });

    try {
      // Use the traditional provider for backward compatibility
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.fetchNotifications();

      // Also fetch using the enhanced service if the user is logged in
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        // Updated to match the new method signature without parameters
        await _notificationService.getUserNotifications();
      }
    } catch (e) {
      // Handle error
      debugPrint('Error fetching notifications: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _isRefreshing = true;
    });
    await _fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.user;

    if (userModel == null) {
      // Handle case where user is not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomAppBar(
          title: 'الإشعارات',
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
      ),
      drawer: MainDrawer(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        currentRoute: AppRoutes.notifications,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: _isLoading
            ? _buildLoadingIndicator()
            : _buildNotificationsList(theme),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/loading.json',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 16),
          const Text('جاري تحميل الإشعارات...'),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(ThemeData theme) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final notifications = notificationProvider.notifications;

    if (notifications.isEmpty) {
      return _buildEmptyState();
    }

    timeago.setLocaleMessages('ar', timeago.ArMessages());

    return ResponsiveBuilder(
      builder: (context, sizeInfo) {
        // Determine the padding based on screen size
        final padding = sizeInfo.isMobile ? 16.0 : 24.0;

        return AnimationLimiter(
          child: ListView.builder(
            padding: EdgeInsets.all(padding),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final time = timeago.format(notification.createdAt, locale: 'ar');

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 500),
                child: SlideAnimation(
                  horizontalOffset: 50.0,
                  child: FadeInAnimation(
                    child: Dismissible(
                      key: Key(notification.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('حذف الإشعار'),
                            content: const Text('هل أنت متأكد من حذف هذا الإشعار؟'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('إلغاء'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        notificationProvider.deleteNotification(notification.id);
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: notification.isRead
                              ? BorderSide.none
                              : BorderSide(
                                  color: theme.colorScheme.primary, width: 1.5),
                        ),
                        child: InkWell(
                          onTap: () {
                            if (!notification.isRead) {
                              notificationProvider.markAsRead(notification.id);
                            }

                            // Navigate to relevant screen based on notification type
                            if (notification.route != null &&
                                notification.route!.isNotEmpty) {
                              Navigator.of(context).pushNamed(notification.route!);
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color:
                                            _getNotificationColor(notification.type)
                                                .safeOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getNotificationIcon(notification.type),
                                        color:
                                            _getNotificationColor(notification.type),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            notification.title,
                                            style: TextStyle(
                                              fontWeight: notification.isRead
                                                  ? FontWeight.normal
                                                  : FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            time,
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurface
                                                  .safeOpacity(0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!notification.isRead)
                                      PulseAnimation(
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  notification.body,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        theme.colorScheme.onSurface.safeOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return ResponsiveBuilder(
      builder: (context, sizeInfo) {
        return Center(
          child: AnimatedAppear(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/animations/empty_notifications.json',
                  width: sizeInfo.isMobile ? 200 : 250,
                  height: sizeInfo.isMobile ? 200 : 250,
                  repeat: true,
                ),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد إشعارات حالياً',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'ستظهر الإشعارات هنا عندما تتلقى تحديثات جديدة',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _refreshNotifications,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'order':
        return Colors.blue;
      case 'fault':
        return Colors.orange;
      case 'system':
        return Colors.purple;
      case 'product':
        return Colors.green;
      case 'alert':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag;
      case 'fault':
        return Icons.error_outline;
      case 'system':
        return Icons.system_update;
      case 'product':
        return Icons.inventory;
      case 'alert':
        return Icons.notifications_active;
      default:
        return Icons.notifications;
    }
  }
}
