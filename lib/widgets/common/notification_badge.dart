import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/widgets/common/animated_widgets.dart';

/// A widget that displays a notification badge
class NotificationBadge extends StatelessWidget {
  final int count;
  final Color? color;
  final Color? textColor;
  final double size;
  final double fontSize;
  final Widget? child;
  final VoidCallback? onTap;
  final bool animate;
  
  const NotificationBadge({
    super.key,
    required this.count,
    this.color,
    this.textColor,
    this.size = 18,
    this.fontSize = 10,
    this.child,
    this.onTap,
    this.animate = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = color ?? theme.colorScheme.error;
    final badgeTextColor = textColor ?? Colors.white;
    
    if (count <= 0) {
      return child ?? const SizedBox.shrink();
    }
    
    return InkWell(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child ?? const SizedBox.shrink(),
          Positioned(
            right: -5,
            top: -5,
            child: animate
                ? PulseAnimation(
                    duration: const Duration(milliseconds: 1500),
                    child: _buildBadge(badgeColor, badgeTextColor),
                  )
                : _buildBadge(badgeColor, badgeTextColor),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBadge(Color badgeColor, Color badgeTextColor) {
    return Container(
      padding: const EdgeInsets.all(2),
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: TextStyle(
            color: badgeTextColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// A widget that displays a notification icon with a badge
class NotificationIconWithBadge extends StatelessWidget {
  final int count;
  final IconData icon;
  final double iconSize;
  final Color? iconColor;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final VoidCallback? onTap;
  final bool animate;
  
  const NotificationIconWithBadge({
    super.key,
    required this.count,
    this.icon = Icons.notifications_outlined,
    this.iconSize = 24,
    this.iconColor,
    this.badgeColor,
    this.badgeTextColor,
    this.onTap,
    this.animate = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.iconTheme.color;
    
    return NotificationBadge(
      count: count,
      color: badgeColor,
      textColor: badgeTextColor,
      onTap: onTap,
      animate: animate,
      child: Icon(
        icon,
        size: iconSize,
        color: color,
      ),
    );
  }
}

/// A widget that displays a notification bell with a badge
class NotificationBell extends StatelessWidget {
  final int count;
  final double size;
  final Color? color;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final VoidCallback? onTap;
  final bool animate;
  
  const NotificationBell({
    super.key,
    required this.count,
    this.size = 24,
    this.color,
    this.badgeColor,
    this.badgeTextColor,
    this.onTap,
    this.animate = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.iconTheme.color;
    
    return NotificationIconWithBadge(
      count: count,
      icon: count > 0 ? Icons.notifications_active : Icons.notifications_outlined,
      iconSize: size,
      iconColor: iconColor,
      badgeColor: badgeColor,
      badgeTextColor: badgeTextColor,
      onTap: onTap,
      animate: animate,
    );
  }
}
