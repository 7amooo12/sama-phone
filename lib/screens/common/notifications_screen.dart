import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/notification_provider.dart';
import 'package:smartbiztracker_new/providers/pending_orders_provider.dart';
import 'package:smartbiztracker_new/services/real_notification_service.dart';
import 'package:smartbiztracker_new/models/notification_model.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/utils/responsive_builder.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/widgets/common/animated_widgets.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lottie/lottie.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final RealNotificationService _notificationService = RealNotificationService();

  bool _isLoading = true;
  bool _isRefreshing = false;
  String _selectedCategory = 'all';
  late AnimationController _headerAnimationController;
  late AnimationController _listAnimationController;

  // Category filters for role-based notifications
  final Map<String, String> _categoryFilters = {
    'all': 'جميع الإشعارات',
    'orders': 'الطلبات',
    'vouchers': 'قسائم الخصم',
    'tasks': 'المهام',
    'rewards': 'المكافآت',
    'inventory': 'المخزون',
    'system': 'النظام',
    'customer_service': 'خدمة العملاء',
  };

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _headerAnimationController = AnimationController(
      duration: AccountantThemeConfig.animationDuration,
      vsync: this,
    );
    _listAnimationController = AnimationController(
      duration: AccountantThemeConfig.longAnimationDuration,
      vsync: this,
    );

    // Start animations and fetch notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerAnimationController.forward();
      _fetchNotifications();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    if (!mounted) return;

    setState(() {
      if (!_isRefreshing) {
        _isLoading = true;
      }
    });

    try {
      // Use context.read for better performance
      final notificationProvider = context.read<NotificationProvider>();
      await notificationProvider.fetchNotifications();

      // Start list animation after data is loaded
      if (mounted) {
        _listAnimationController.forward();
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الإشعارات: $e'),
            backgroundColor: AccountantThemeConfig.warningOrange,
          ),
        );
      }
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
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        return Consumer<SupabaseProvider>(
          builder: (context, supabaseProvider, child) {
            final user = supabaseProvider.user;

            if (user == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              });
              return _buildLoadingScaffold();
            }

            return _buildMainScaffold(context, notificationProvider, user);
          },
        );
      },
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AccountantThemeConfig.primaryGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildMainScaffold(BuildContext context, NotificationProvider notificationProvider, dynamic user) {
    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackNavigation(context, user);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawer: MainDrawer(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          currentRoute: AppRoutes.notifications,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildModernHeader(context, notificationProvider),
                _buildCategoryFilters(context, user),
                Expanded(
                  child: _isLoading
                      ? _buildModernLoadingIndicator()
                      : _buildEnhancedNotificationsList(context, notificationProvider, user),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context, dynamic notificationProvider) {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      child: Column(
        children: [
          // SAMA Branding Header with Navigation Buttons - Optimized for RTL
          LayoutBuilder(
            builder: (context, constraints) {
              // Responsive layout based on available width
              final isNarrowScreen = constraints.maxWidth < 400;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side: Navigation buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Back Button
                      _buildProfessionalBackButton(),
                      SizedBox(width: isNarrowScreen ? 4 : 8), // Responsive spacing
                      // Professional Sidebar Button
                      _buildProfessionalSidebarButton(),
                    ],
                  ),
                  // Center: Notification icon and branding
                  Expanded(
                    flex: 2, // Give more space to the center section
                    child: Row(
                      children: [
                        SizedBox(width: isNarrowScreen ? 8 : 12), // Responsive spacing
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AccountantThemeConfig.greenGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                        SizedBox(width: isNarrowScreen ? 8 : 12), // Responsive spacing
                        // SAMA Branding and Arabic text section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min, // Prevent excessive height
                            children: [
                              // SAMA Branding Container with constraints
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: isNarrowScreen ? 100 : 120, // Responsive width
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AccountantThemeConfig.primaryGreen,
                                        AccountantThemeConfig.secondaryGreen,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                                  ),
                                  child: Text(
                                    'SAMA',
                                    style: AccountantThemeConfig.headlineSmall.copyWith(
                                      fontSize: isNarrowScreen ? 16 : 18, // Responsive font size
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                    textDirection: TextDirection.ltr, // Ensure LTR for English branding
                                    overflow: TextOverflow.ellipsis, // Prevent text overflow
                                  ),
                                ),
                              ),
                              // Proper spacing between SAMA and Arabic text
                              const SizedBox(height: 8),
                              // Arabic notifications text with proper RTL support
                              Text(
                                'الإشعارات',
                                style: AccountantThemeConfig.bodyLarge.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: isNarrowScreen ? 14 : 16, // Responsive font size
                                  fontWeight: FontWeight.w600,
                                ),
                                textDirection: TextDirection.rtl, // Ensure RTL for Arabic text
                                textAlign: TextAlign.start,
                                overflow: TextOverflow.ellipsis, // Prevent text overflow
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right side: Action buttons with responsive behavior
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeaderActionButton(
                          icon: Icons.mark_email_read,
                          onPressed: () => _markAllAsRead(notificationProvider),
                          tooltip: 'تحديد الكل كمقروء',
                        ),
                        SizedBox(width: isNarrowScreen ? 4 : 6), // Responsive spacing
                        _buildHeaderActionButton(
                          icon: Icons.refresh,
                          onPressed: _refreshNotifications,
                          tooltip: 'تحديث',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Statistics Row
          _buildNotificationStats(notificationProvider),
        ],
      ),
    );
  }

  Widget _buildProfessionalSidebarButton() {
    return Tooltip(
      message: 'فتح القائمة الجانبية',
      textStyle: AccountantThemeConfig.bodySmall.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.blueGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Add haptic feedback for better UX
              HapticFeedback.lightImpact();

              // Open the sidebar with smooth animation
              _scaffoldKey.currentState?.openDrawer();

              // Show professional feedback
              _showSidebarOpenedFeedback();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalBackButton() {
    return Consumer<SupabaseProvider>(
      builder: (context, supabaseProvider, child) {
        final user = supabaseProvider.user;

        return Tooltip(
          message: 'العودة إلى الرئيسية',
          textStyle: AccountantThemeConfig.bodySmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(8),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.orangeGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleBackNavigation(context, user),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSidebarOpenedFeedback() {
    // Optional: Show a subtle feedback when sidebar is opened
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.menu_open_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'تم فتح القائمة الجانبية',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.accentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(milliseconds: 1500),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      textStyle: AccountantThemeConfig.bodySmall.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Container(
        width: 44, // Fixed width for consistency
        height: 44, // Fixed height for consistency
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        ),
        child: IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
          iconSize: 20,
          padding: EdgeInsets.zero, // Remove default padding
          constraints: const BoxConstraints(), // Remove default constraints
        ),
      ),
    );
  }

  Widget _buildNotificationStats(dynamic notificationProvider) {
    final notifications = notificationProvider.notifications as List<NotificationModel>;
    final unreadCount = notifications.where((n) => !n.isRead).length;
    final totalCount = notifications.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AccountantThemeConfig.transparentCardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('المجموع', totalCount.toString(), Icons.notifications),
          _buildStatItem('غير مقروءة', unreadCount.toString(), Icons.mark_email_unread),
          _buildStatItem('مقروءة', (totalCount - unreadCount).toString(), Icons.mark_email_read),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AccountantThemeConfig.primaryGreen, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: AccountantThemeConfig.headlineSmall.copyWith(fontSize: 16),
        ),
        Text(
          label,
          style: AccountantThemeConfig.bodySmall,
        ),
      ],
    );
  }

  Widget _buildCategoryFilters(BuildContext context, dynamic user) {
    // Get user role for filtering relevant categories
    final userRole = user?.userRole ?? 'client';
    final relevantCategories = _getRelevantCategoriesForRole(userRole);

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: AccountantThemeConfig.defaultPadding),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: relevantCategories.length,
        itemBuilder: (context, index) {
          final category = relevantCategories[index];
          final isSelected = _selectedCategory == category;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                _categoryFilters[category] ?? category,
                style: TextStyle(
                  color: isSelected ? Colors.white : AccountantThemeConfig.primaryGreen,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              selectedColor: AccountantThemeConfig.primaryGreen,
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected ? AccountantThemeConfig.primaryGreen : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          );
        },
      ),
    );
  }

  List<String> _getRelevantCategoriesForRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
      case 'admin':
      case 'manager':
        return ['all', 'orders', 'inventory', 'tasks', 'rewards', 'system', 'customer_service'];
      case 'worker':
        return ['all', 'tasks', 'rewards', 'system'];
      case 'client':
        return ['all', 'orders', 'vouchers', 'inventory', 'system', 'customer_service'];
      case 'accountant':
        return ['all', 'orders', 'rewards', 'system'];
      case 'warehousemanager':
        return ['all', 'inventory', 'orders', 'system'];
      default:
        return ['all', 'system'];
    }
  }

  Widget _buildModernLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const CircularProgressIndicator(
              color: AccountantThemeConfig.primaryGreen,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'جاري تحميل الإشعارات...',
            style: AccountantThemeConfig.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedNotificationsList(BuildContext context, dynamic notificationProvider, dynamic user) {
    final notifications = notificationProvider.notifications as List<NotificationModel>;
    final filteredNotifications = _filterNotificationsByCategory(notifications);

    if (filteredNotifications.isEmpty) {
      return _buildModernEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      color: AccountantThemeConfig.primaryGreen,
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        itemCount: filteredNotifications.length,
        itemBuilder: (context, index) {
          final notification = filteredNotifications[index];
          return _buildEnhancedNotificationCard(context, notification, notificationProvider, index);
        },
      ),
    );
  }

  List<NotificationModel> _filterNotificationsByCategory(List<NotificationModel> notifications) {
    if (_selectedCategory == 'all') {
      return notifications;
    }

    return notifications.where((notification) {
      // Map old notification types to new categories
      switch (_selectedCategory) {
        case 'orders':
          return notification.type.toLowerCase().contains('order') ||
                 notification.type.toLowerCase().contains('payment');
        case 'vouchers':
          return notification.type.toLowerCase().contains('voucher');
        case 'tasks':
          return notification.type.toLowerCase().contains('task');
        case 'rewards':
          return notification.type.toLowerCase().contains('reward') ||
                 notification.type.toLowerCase().contains('bonus') ||
                 notification.type.toLowerCase().contains('penalty');
        case 'inventory':
          return notification.type.toLowerCase().contains('inventory') ||
                 notification.type.toLowerCase().contains('product');
        case 'system':
          return notification.type.toLowerCase().contains('system') ||
                 notification.type.toLowerCase().contains('account');
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildEnhancedNotificationCard(
    BuildContext context,
    NotificationModel notification,
    dynamic notificationProvider,
    int index
  ) {
    final timeAgo = _formatTimeAgo(notification.createdAt);
    final isUnread = !notification.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Dismissible(
        key: Key(notification.id),
        background: _buildDismissBackground(),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) => _showDeleteConfirmation(context),
        onDismissed: (direction) {
          notificationProvider.deleteNotification(notification.id);
          _showSnackBar(context, 'تم حذف الإشعار');
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: isUnread
                ? AccountantThemeConfig.cardGradient
                : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
            borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
            border: isUnread
                ? AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen)
                : Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: isUnread
                ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                : AccountantThemeConfig.cardShadows,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleNotificationTap(context, notification, notificationProvider),
              borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
              child: Padding(
                padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNotificationHeader(notification, timeAgo, isUnread),
                    const SizedBox(height: 12),
                    _buildNotificationBody(notification),
                    if (notification.data != null && notification.data!.isNotEmpty)
                      _buildNotificationMetadata(notification),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationHeader(NotificationModel notification, String timeAgo, bool isUnread) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: _getNotificationGradient(notification.type),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AccountantThemeConfig.glowShadows(_getNotificationColor(notification.type)),
          ),
          child: Icon(
            _getEnhancedNotificationIcon(notification.type),
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeAgo,
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isUnread)
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AccountantThemeConfig.primaryGreen,
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationBody(NotificationModel notification) {
    return Text(
      notification.body,
      style: AccountantThemeConfig.bodyLarge.copyWith(
        color: Colors.white.withValues(alpha: 0.9),
        height: 1.4,
      ),
    );
  }

  Widget _buildNotificationMetadata(NotificationModel notification) {
    final data = notification.data!;
    final hasAmount = data.containsKey('amount') || data.containsKey('total_amount');

    if (!hasAmount) return const SizedBox.shrink();

    final amount = data['amount'] ?? data['total_amount'];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.monetization_on,
            size: 16,
            color: AccountantThemeConfig.primaryGreen,
          ),
          const SizedBox(width: 6),
          Text(
            '$amount جنيه',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  void _markAllAsRead(dynamic notificationProvider) async {
    try {
      await notificationProvider.markAllAsRead();
      _showSnackBar(context, 'تم تحديد جميع الإشعارات كمقروءة');
    } catch (e) {
      _showSnackBar(context, 'خطأ في تحديث الإشعارات');
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inDays < 1) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return 'منذ ${(difference.inDays / 7).floor()} أسبوع';
    }
  }

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.red, Colors.redAccent],
        ),
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete, color: Colors.white, size: 28),
          SizedBox(height: 4),
          Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        ),
        title: Text(
          'حذف الإشعار',
          style: AccountantThemeConfig.headlineSmall,
        ),
        content: Text(
          'هل أنت متأكد من حذف هذا الإشعار؟',
          style: AccountantThemeConfig.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, NotificationModel notification, dynamic notificationProvider) {
    // Mark as read if unread
    if (!notification.isRead) {
      notificationProvider.markAsRead(notification.id);
    }

    // Add haptic feedback
    HapticFeedback.lightImpact();

    // Navigate based on notification route with role-based routing
    if (notification.route != null && notification.route!.isNotEmpty) {
      final route = _getCorrectRouteForUser(notification);

      if (route.isNotEmpty) {
        // For order details, pass the order ID as argument if needed
        if (route.contains('/orders/details') && notification.referenceId != null) {
          _navigateToOrderDetails(context, route, notification.referenceId!);
        } else {
          Navigator.of(context).pushNamed(route);
        }
      }
    }
  }

  String _getCorrectRouteForUser(NotificationModel notification) {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final userRole = supabaseProvider.user?.userRole?.toLowerCase() ?? 'client';

    // If it's an order notification, redirect to pending orders screen based on user role
    if (notification.referenceType == 'order' && notification.route != null) {
      switch (userRole) {
        case 'accountant':
          return '/accountant/pending-orders';
        case 'admin':
        case 'manager':
          return '/admin/pending-orders';
        case 'owner':
          return '/admin/pending-orders'; // Owner uses admin pending orders screen
        case 'client':
          return '/client/orders'; // Clients go to their orders screen
        default:
          return '/admin/pending-orders';
      }
    }

    // If it's a warehouse release order notification, redirect to appropriate screen based on user role
    if (notification.referenceType == 'warehouse_release_order' && notification.route != null) {
      switch (userRole) {
        case 'accountant':
          return '/accountant/warehouse-release-orders';
        case 'warehousemanager':
        case 'warehouse_manager':
          return '/warehouse/release-orders';
        case 'admin':
        case 'manager':
        case 'owner':
          return '/accountant/warehouse-release-orders'; // Admin/Owner can view accountant screen
        default:
          return '/accountant/warehouse-release-orders';
      }
    }

    // For other notifications, use the original route
    return notification.route ?? '';
  }

  void _navigateToOrderDetails(BuildContext context, String route, String orderId) {
    // For accountant order details, we need to fetch the order first
    if (route == '/accountant/orders/details') {
      _navigateToAccountantOrderDetails(context, orderId);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  void _navigateToAccountantOrderDetails(BuildContext context, String orderId) {
    // Get the pending orders provider to fetch the order
    final pendingOrdersProvider = Provider.of<PendingOrdersProvider>(context, listen: false);
    final order = pendingOrdersProvider.getOrderById(orderId);

    if (order != null) {
      Navigator.of(context).pushNamed(
        '/accountant/orders/details',
        arguments: order,
      );
    } else {
      // If order not found in pending orders, show error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على تفاصيل الطلب'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildModernEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد إشعارات',
            style: AccountantThemeConfig.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategory == 'all'
                ? 'ستظهر الإشعارات هنا عندما تتلقى تحديثات جديدة'
                : 'لا توجد إشعارات في هذه الفئة',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _refreshNotifications,
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث'),
            style: AccountantThemeConfig.primaryButtonStyle,
          ),
        ],
      ),
    );
  }

  // Enhanced notification styling methods
  Color _getNotificationColor(String type) {
    final lowerType = type.toLowerCase();

    if (lowerType.contains('order') || lowerType.contains('payment')) {
      return AccountantThemeConfig.accentBlue;
    } else if (lowerType.contains('voucher')) {
      return AccountantThemeConfig.primaryGreen;
    } else if (lowerType.contains('task')) {
      return AccountantThemeConfig.warningOrange;
    } else if (lowerType.contains('reward') || lowerType.contains('bonus')) {
      return AccountantThemeConfig.primaryGreen;
    } else if (lowerType.contains('penalty')) {
      return Colors.red;
    } else if (lowerType.contains('inventory') || lowerType.contains('product')) {
      return AccountantThemeConfig.accentBlue;
    } else if (lowerType.contains('system') || lowerType.contains('account')) {
      return AccountantThemeConfig.deepBlue;
    } else {
      return Colors.grey;
    }
  }

  LinearGradient _getNotificationGradient(String type) {
    final color = _getNotificationColor(type);
    return LinearGradient(
      colors: [color, color.withValues(alpha: 0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  IconData _getEnhancedNotificationIcon(String type) {
    final lowerType = type.toLowerCase();

    if (lowerType.contains('order_created')) {
      return Icons.shopping_cart_outlined;
    } else if (lowerType.contains('order_status') || lowerType.contains('order_completed')) {
      return Icons.local_shipping_outlined;
    } else if (lowerType.contains('payment')) {
      return Icons.payment;
    } else if (lowerType.contains('voucher_assigned')) {
      return Icons.card_giftcard;
    } else if (lowerType.contains('voucher_used')) {
      return Icons.redeem;
    } else if (lowerType.contains('task_assigned')) {
      return Icons.assignment_outlined;
    } else if (lowerType.contains('task_completed')) {
      return Icons.task_alt;
    } else if (lowerType.contains('reward') || lowerType.contains('bonus')) {
      return Icons.stars;
    } else if (lowerType.contains('penalty')) {
      return Icons.warning_amber;
    } else if (lowerType.contains('inventory_low')) {
      return Icons.inventory_2_outlined;
    } else if (lowerType.contains('inventory_updated') || lowerType.contains('product')) {
      return Icons.new_releases;
    } else if (lowerType.contains('account_approved')) {
      return Icons.verified_user;
    } else if (lowerType.contains('system')) {
      return Icons.settings_applications;
    } else {
      return Icons.notifications_outlined;
    }
  }

  // Legacy methods for backward compatibility
  IconData _getNotificationIcon(String type) {
    return _getEnhancedNotificationIcon(type);
  }

  // Handle back navigation based on user role
  void _handleBackNavigation(BuildContext context, dynamic user) {
    final userRole = user?.userRole?.toLowerCase() ?? 'client';
    final dashboardRoute = _getDashboardRouteForRole(userRole);

    // Log navigation for debugging
    debugPrint('🔙 Notifications back navigation: $userRole -> $dashboardRoute');

    // Add haptic feedback for better UX
    HapticFeedback.lightImpact();

    // Show a brief feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'العودة إلى الرئيسية',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(milliseconds: 1000),
        margin: const EdgeInsets.all(16),
      ),
    );

    // Navigate to the appropriate dashboard
    Navigator.of(context).pushReplacementNamed(dashboardRoute);
  }

  // Get the appropriate dashboard route based on user role
  String _getDashboardRouteForRole(String userRole) {
    switch (userRole) {
      case 'admin':
        return AppRoutes.adminDashboard;
      case 'accountant':
        return AppRoutes.accountantDashboard;
      case 'client':
        return AppRoutes.clientDashboard;
      case 'worker':
        return AppRoutes.workerDashboard;
      case 'owner':
        return AppRoutes.ownerDashboard;
      case 'warehousemanager':
      case 'warehouse_manager':
        return AppRoutes.warehouseManagerDashboard;
      default:
        // Fallback to client dashboard for unknown roles
        return AppRoutes.clientDashboard;
    }
  }
}
