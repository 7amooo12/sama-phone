import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/notification_provider.dart';
import 'package:provider/provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = true,
    this.backgroundColor,
    this.foregroundColor,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.elevation = 0,
    this.showNotificationIcon = true,
    this.hideStatusBarHeader = true,
    this.showBackButton = false,
  });
  final String title;
  final List<Widget>? actions;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final double elevation;
  final bool showNotificationIcon;
  final bool hideStatusBarHeader;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ألوان احترافية متناسقة مع المشروع
    final headerBackgroundColor = backgroundColor ?? (isDark
        ? const Color(0xFF1E293B) // لون داكن احترافي
        : const Color(0xFFFFFFFF)); // لون فاتح نظيف

    final headerForegroundColor = foregroundColor ?? (isDark
        ? Colors.white
        : const Color(0xFF1E293B));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF334155),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF8FAFC),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 20,
              offset: const Offset(0, -1),
              spreadRadius: 0,
            ),
        ],
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: headerForegroundColor,
            letterSpacing: 0.5,
            fontFamily: 'Cairo', // خط احترافي
          ),
        ),
        actions: [
          if (showNotificationIcon) _buildNotificationIcon(context),
          ...(actions ?? []),
          const SizedBox(width: 8), // مساحة إضافية
        ],
        centerTitle: centerTitle,
        backgroundColor: Colors.transparent,
        foregroundColor: headerForegroundColor,
        leading: leading ?? (showBackButton ? _buildBackButton(context) : _buildMenuButton(context)),
        automaticallyImplyLeading: showBackButton ? true : automaticallyImplyLeading,
        bottom: bottom,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
    );
  }

  // زر الرجوع المحسن
  Widget _buildBackButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : const Color(0xFF1E293B)).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.white : const Color(0xFF1E293B)).withOpacity(0.2),
        ),
      ),
      child: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_rounded,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
          size: 20,
        ),
        onPressed: () => Navigator.of(context).pop(),
        splashRadius: 20,
        tooltip: 'رجوع',
      ),
    );
  }

  // زر القائمة المحسن
  Widget _buildMenuButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : const Color(0xFF1E293B)).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.white : const Color(0xFF1E293B)).withOpacity(0.2),
        ),
      ),
      child: IconButton(
        icon: Icon(
          Icons.menu_rounded,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
          size: 22,
        ),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
        splashRadius: 20,
        tooltip: 'القائمة',
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount;

        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : const Color(0xFF1E293B)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isDark ? Colors.white : const Color(0xFF1E293B)).withOpacity(0.2),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    unreadCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    size: 22,
                  ),
                  onPressed: () {
                    try {
                      Navigator.of(context).pushNamed(AppRoutes.notifications);
                    } catch (e) {
                      print('Navigation error to notifications: $e');
                      // Fallback navigation
                      try {
                        Navigator.of(context).pushReplacementNamed(AppRoutes.notifications);
                      } catch (e2) {
                        print('Fallback navigation error to notifications: $e2');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'خطأ في فتح الإشعارات',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  tooltip: 'الإشعارات',
                  splashRadius: 20,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFEF4444),
                          Color(0xFFDC2626),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
