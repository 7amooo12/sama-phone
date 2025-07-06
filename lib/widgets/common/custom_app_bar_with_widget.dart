import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';

class CustomAppBarWithWidget extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBarWithWidget({
    super.key,
    this.titleWidget,
    this.title,
    this.actions,
    this.centerTitle = true,
    this.backgroundColor,
    this.foregroundColor,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.elevation = 0,
    this.showNotificationIcon = true,
  }) : assert(title != null || titleWidget != null, 'Either title or titleWidget must be provided');
  
  final Widget? titleWidget;
  final String? title;
  final List<Widget>? actions;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final double elevation;
  final bool showNotificationIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ألوان احترافية متناسقة مع المشروع
    final headerBackgroundColor = backgroundColor ?? (isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFFFFFFF));

    final headerForegroundColor = foregroundColor ?? (isDark
        ? Colors.white
        : const Color(0xFF1E293B));

    // Create title widget based on title string if titleWidget is not provided
    final Widget effectiveTitleWidget = titleWidget ?? Text(
      title!,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: headerForegroundColor,
        letterSpacing: 0.5,
        fontFamily: 'Cairo',
      ),
    );

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
        title: AnimationSystem.fadeSlideInWithDelay(
          effectiveTitleWidget,
          duration: AnimationSystem.medium,
          curve: AnimationSystem.easeOut,
          offset: AnimationSystem.smallBottomToTopOffset,
        ),
        actions: [
          if (showNotificationIcon) _buildNotificationIcon(context),
          ...(actions ?? []),
          const SizedBox(width: 8),
        ],
        centerTitle: centerTitle,
        backgroundColor: Colors.transparent,
        foregroundColor: headerForegroundColor,
        leading: leading != null
            ? AnimationSystem.fadeInWithDelay(
                leading!,
                duration: AnimationSystem.medium,
              )
            : _buildMenuButton(context),
        automaticallyImplyLeading: automaticallyImplyLeading,
        bottom: bottom,
        elevation: 0,
      ),
    );
  }

  // زر القائمة المحسن
  Widget _buildMenuButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimationSystem.fadeInWithDelay(
      Container(
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
      ),
      duration: AnimationSystem.medium,
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount;

        return AnimationSystem.fadeInWithDelay(
          Container(
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
                      Navigator.of(context).pushNamed(AppRoutes.notifications);
                    },
                    tooltip: 'الإشعارات',
                    splashRadius: 20,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: AnimationSystem.pulse(
                      Container(
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
                      duration: const Duration(milliseconds: 1500),
                      minScale: 0.9,
                      maxScale: 1.1,
                    ),
                  ),
              ],
            ),
          ),
          duration: AnimationSystem.medium,
          delay: AnimationSystem.shortDelay,
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
