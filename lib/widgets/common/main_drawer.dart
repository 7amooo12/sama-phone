import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart' hide AnimationType;
import 'package:smartbiztracker_new/widgets/common/animated_list_view.dart';
import 'package:smartbiztracker_new/utils/localization.dart';
import 'package:smartbiztracker_new/models/user_role.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({
    super.key,
    this.onMenuPressed,
    this.currentRoute,
  });
  final Function()? onMenuPressed;
  final String? currentRoute;

  @override
  Widget build(BuildContext context) {
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final user = supabaseProvider.user;
    final theme = Theme.of(context);

    if (user == null) {
      return const SizedBox.shrink();
    }

    // استخدام تأثير haptic عند فتح القائمة الجانبية
    HapticFeedback.lightImpact();

    return Drawer(
      elevation: 2.0,
      shadowColor: Colors.black.withOpacity(0.3),
      backgroundColor: theme.colorScheme.surface.withOpacity(0.96),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(StyleSystem.radiusLarge),
          bottomRight: Radius.circular(StyleSystem.radiusLarge),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context, user),
          _buildMenuItems(context, user),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return AnimationSystem.fadeSlideInWithDelay(
      Container(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: StyleSystem.coolGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: StyleSystem.shadowSmall,
        ),
        child: Stack(
          children: [
            // Decorative elements
            Positioned(
              top: -15,
              right: -15,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            // User account details
            UserAccountsDrawerHeader(
              margin: EdgeInsets.zero,
              accountName: Row(
                children: [
                  Text(
                    user.name,
                    style: StyleSystem.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getRoleText(user.role),
                      style: StyleSystem.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              accountEmail: Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    user.email,
                    style: StyleSystem.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              currentAccountPicture: AnimationSystem.pulse(
                Hero(
                  tag: 'user_profile_pic',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          user.profileImage != null ? NetworkImage(user.profileImage!) : null,
                      child: user.profileImage == null
                          ? Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey[600],
                            )
                          : null,
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 2500),
                minScale: 0.98,
                maxScale: 1.02,
              ),
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              otherAccountsPictures: [
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/profile');
                    },
                    child: Ink(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.edit_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      duration: AnimationSystem.medium,
      curve: AnimationSystem.easeOut,
    );
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'مدير';
      case UserRole.owner:
        return 'صاحب عمل';
      case UserRole.client:
        return 'عميل';
      case UserRole.worker:
        return 'عامل';
      case UserRole.accountant:
        return 'محاسب';
      default:
        return 'مستخدم';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.owner:
        return Colors.blue;
      case UserRole.client:
        return Colors.green;
      case UserRole.worker:
        return Colors.orange;
      case UserRole.accountant:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMenuItems(BuildContext context, UserModel user) {
    return Expanded(
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        children: [
          _buildMenuItem(
            context,
            icon: Icons.notifications_rounded,
            title: 'الإشعارات',
            onTap: () => _navigateTo(context, '/notifications'),
            route: currentRoute,
          ),

          // Admin-specific menu items
          if (user.isAdmin()) ...[
            _buildDivider('الإدارة'),
            _buildMenuItem(
              context,
              icon: Icons.dashboard_rounded,
              title: 'لوحة التحكم',
              onTap: () => _navigateTo(context, '/admin/dashboard'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.people_rounded,
              title: 'إدارة المستخدمين',
              onTap: () => _navigateTo(context, '/admin/users'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.approval_rounded,
              title: 'طلبات التسجيل',
              onTap: () => _navigateTo(context, '/admin/approval-requests'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.engineering_rounded,
              title: 'إسناد المهام',
              onTap: () => _navigateTo(context, '/admin/assign-tasks'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.inventory_2_rounded,
              title: 'إدارة المنتجات',
              onTap: () => _navigateTo(context, '/admin/products'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.analytics_rounded,
              title: 'التحليلات',
              onTap: () => _navigateTo(context, '/admin/analytics'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.shopping_cart_rounded,
              title: 'الطلبات',
              onTap: () => _navigateTo(context, '/orders'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.inventory_2_rounded,
              title: 'إدارة الهالك',
              onTap: () => _navigateTo(context, '/waste'),
              route: currentRoute,
            ),
          ],

          // Owner-specific menu items
          if (user.isOwner()) ...[
            _buildDivider('الأعمال'),
            _buildMenuItem(
              context,
              icon: Icons.dashboard_rounded,
              title: 'لوحة التحكم',
              onTap: () => _navigateTo(context, '/owner/dashboard'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.shopping_cart_rounded,
              title: 'الطلبات',
              onTap: () => _navigateTo(context, '/orders'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.inventory_2_rounded,
              title: 'المنتجات',
              onTap: () => _navigateTo(context, '/owner/products'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.delete_rounded,
              title: 'إدارة الهالك',
              onTap: () => _navigateTo(context, '/waste'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.store_rounded,
              title: 'متجر SAMA',
              onTap: () => _navigateTo(context, '/sama-store'),
              route: currentRoute,
            ),
          ],

          // Worker-specific menu items
          if (user.isWorker()) ...[
            _buildDivider('العمل'),
            _buildMenuItem(
              context,
              icon: Icons.dashboard_rounded,
              title: 'لوحة التحكم',
              onTap: () => _navigateTo(context, '/worker/dashboard'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.assignment_rounded,
              title: 'الطلبات',
              onTap: () => _navigateTo(context, '/orders'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.trending_up_rounded,
              title: 'الإنتاجية',
              onTap: () => _navigateTo(context, '/worker/productivity'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.delete_outline_rounded,
              title: 'تتبع الهالك',
              onTap: () => _navigateTo(context, '/waste'),
              route: currentRoute,
            ),
          ],

          // Accountant-specific menu items
          if (user.isAccountant()) ...[
            _buildDivider('المحاسبة'),
            _buildMenuItem(
              context,
              icon: Icons.dashboard_rounded,
              title: 'الرئيسية',
              onTap: () => _navigateTo(context, '/accountant/dashboard'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.shopping_cart_rounded,
              title: 'الطلبات',
              onTap: () => _navigateTo(context, '/orders'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.inventory_2_rounded,
              title: 'المنتجات',
              onTap: () => _navigateTo(context, '/accountant/products'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.receipt_long_rounded,
              title: 'الفواتير',
              onTap: () => _navigateTo(context, '/accountant/invoices'),
              route: currentRoute,
            ),
          ],

          // Client-specific menu items
          if (user.isClient()) ...[
            _buildDivider('التسوق'),
            _buildMenuItem(
              context,
              icon: Icons.dashboard_rounded,
              title: 'لوحة التحكم',
              onTap: () => _navigateTo(context, '/client/dashboard'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.shopping_bag_rounded,
              title: 'المنتجات',
              onTap: () => _navigateTo(context, '/client/products'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.shopping_cart_rounded,
              title: 'الطلبات',
              onTap: () => _navigateTo(context, '/client/orders'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.local_shipping_rounded,
              title: 'تتبع الطلبات',
              onTap: () => _navigateTo(context, '/client/tracking'),
              route: currentRoute,
            ),
            _buildDivider('خدمة العملاء'),
            _buildMenuItem(
              context,
              icon: Icons.error_outline_rounded,
              title: 'الإبلاغ عن خطأ',
              onTap: () => _navigateTo(
                context, 
                '/customer-service', 
                arguments: {'initialTabIndex': 0}
              ),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.assignment_return_rounded,
              title: 'إرجاع منتج',
              onTap: () => _navigateTo(
                context, 
                '/customer-service', 
                arguments: {'initialTabIndex': 1}
              ),
              route: currentRoute,
            ),
          ],

          // Common menu items for all users
          _buildDivider('الحساب'),
          _buildMenuItem(
            context,
            icon: Icons.person_rounded,
            title: 'الملف الشخصي',
            onTap: () => _navigateTo(context, '/profile'),
            route: currentRoute,
          ),
          _buildMenuItem(
            context,
            icon: Icons.settings_rounded,
            title: 'الإعدادات',
            onTap: () => _navigateTo(context, '/settings'),
            route: currentRoute,
          ),
          _buildMenuItem(
            context,
            icon: Icons.logout_rounded,
            title: 'تسجيل الخروج',
            onTap: () => _handleLogout(context),
            route: currentRoute,
            isLogout: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(
            thickness: 1.0,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: StyleSystem.coolGradient.map((color) => color.withOpacity(0.15)).toList(),
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: StyleSystem.borderRadiusMedium,
              border: Border.all(
                color: StyleSystem.primaryColor.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Text(
              title,
              style: StyleSystem.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: StyleSystem.primaryColor.withOpacity(0.8),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? route,
    String? badge,
    bool isLogout = false,
  }) {
    final theme = Theme.of(context);
    final isActive = route != null && route == currentRoute;
    final color = isLogout ? theme.colorScheme.error : isActive ? StyleSystem.primaryColor : StyleSystem.neutralMedium;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: StyleSystem.borderRadiusMedium,
        gradient: isActive
            ? LinearGradient(
                colors: [
                  StyleSystem.primaryColor.withOpacity(0.2),
                  StyleSystem.primaryColor.withOpacity(0.3),
                ],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              )
            : isLogout 
                ? LinearGradient(
                    colors: [
                      theme.colorScheme.error.withOpacity(0.15),
                      theme.colorScheme.error.withOpacity(0.25),
                    ],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  )
                : LinearGradient(
                    colors: [
                      theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      theme.colorScheme.surfaceVariant.withOpacity(0.4),
                    ],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
        boxShadow: isActive ? StyleSystem.shadowSmall : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: StyleSystem.borderRadiusMedium,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          splashColor: color.withOpacity(0.1),
          highlightColor: color.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // أيقونة العنصر مع تأثير انتقال اللون
                Container(
                  decoration: BoxDecoration(
                    color: isActive || isLogout
                        ? color.withOpacity(0.1)
                        : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // عنوان العنصر
                Expanded(
                  child: Text(
                    title,
                    style: StyleSystem.bodyMedium.copyWith(
                      color: color,
                      fontWeight: isActive || isLogout ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                // إضافة شارة إذا كانت موجودة
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? StyleSystem.primaryColor
                          : StyleSystem.warningColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: StyleSystem.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String route, {Map<String, dynamic>? arguments}) {
    // Close the drawer before navigating
    Navigator.pop(context);

    // If already on the same route, don't navigate again
    if (ModalRoute.of(context)?.settings.name == route) return;

    // Navigate without animations to make it feel more responsive
    Navigator.pushNamed(
      context, 
      route, 
      arguments: arguments
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.logout_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('تأكيد تسجيل الخروج'),
          ],
        ),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        shape: RoundedRectangleBorder(
          borderRadius: StyleSystem.borderRadiusLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    // If user confirmed logout
    if (shouldLogout == true) {
      await supabaseProvider.signOut();

      // Check if the context is still valid before using it
      if (!context.mounted) return;

      // Close the drawer
      Navigator.pop(context);

      // Navigate to login screen
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}
