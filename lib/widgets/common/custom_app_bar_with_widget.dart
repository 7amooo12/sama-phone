import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
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

    // Create title widget based on title string if titleWidget is not provided
    Widget effectiveTitleWidget = titleWidget ?? Text(
      title!,
      style: StyleSystem.titleLarge.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );

    return AppBar(
      title: AnimationSystem.fadeSlideInWithDelay(
        effectiveTitleWidget,
        duration: AnimationSystem.medium,
        curve: AnimationSystem.easeOut,
        offset: AnimationSystem.smallBottomToTopOffset,
      ),
      actions: [
        if (showNotificationIcon) _buildNotificationIcon(context),
        ...(actions ?? []),
      ],
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? theme.appBarTheme.backgroundColor,
      foregroundColor: foregroundColor ?? theme.appBarTheme.foregroundColor,
      leading: leading != null
          ? AnimationSystem.fadeInWithDelay(
              leading!,
              duration: AnimationSystem.medium,
            )
          : null,
      automaticallyImplyLeading: automaticallyImplyLeading,
      bottom: bottom,
      elevation: elevation,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: StyleSystem.borderRadiusBottomOnly,
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount;

        return AnimationSystem.fadeInWithDelay(
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.notifications);
                },
                tooltip: 'الإشعارات',
                splashRadius: 24,
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: AnimationSystem.pulse(
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: StyleSystem.errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: StyleSystem.errorColor.withOpacity(0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: StyleSystem.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
          duration: AnimationSystem.medium,
          delay: AnimationSystem.shortDelay,
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
