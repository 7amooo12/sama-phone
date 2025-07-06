import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart' hide AnimationType;
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

    return Drawer(
      elevation: 0,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            _buildHeader(context, user),
            _buildMenuItems(context, user),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserModel user) {
    return Container(
      padding: const EdgeInsets.only(top: 50, bottom: 24, left: 20, right: 20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SAMA Branding Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAMA',
                      style: AccountantThemeConfig.headlineLarge.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..shader = AccountantThemeConfig.greenGradient.createShader(
                            const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                          ),
                      ),
                    ),
                    Text(
                      'Smart Business Tracker',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // User Profile Section
          Row(
            children: [
              // User Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  shape: BoxShape.circle,
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: user.profileImage != null
                    ? ClipOval(
                        child: Image.network(
                          user.profileImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(user),
                        ),
                      )
                    : _buildDefaultAvatar(user),
              ),

              const SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getRoleColor(user.role).withValues(alpha: 0.8),
                            _getRoleColor(user.role),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _getRoleColor(user.role).withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _getRoleText(user.role),
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.email,
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Profile Edit Button
              Container(
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                ),
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/profile');
                  },
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: 'تعديل الملف الشخصي',
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.3);
  }

  Widget _buildDefaultAvatar(UserModel user) {
    return Center(
      child: Text(
        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
        style: AccountantThemeConfig.headlineMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
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
      case UserRole.warehouseManager:
        return 'مدير مخزن';
      default:
        return 'مستخدم';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AccountantThemeConfig.warningOrange;
      case UserRole.owner:
        return AccountantThemeConfig.primaryGreen;
      case UserRole.client:
        return AccountantThemeConfig.accentBlue;
      case UserRole.worker:
        return AccountantThemeConfig.deepBlue;
      case UserRole.accountant:
        return AccountantThemeConfig.primaryGreen;
      case UserRole.warehouseManager:
        return AccountantThemeConfig.accentBlue;
      default:
        return AccountantThemeConfig.accentBlue;
    }
  }

  Widget _buildMenuItems(BuildContext context, UserModel user) {
    return Expanded(
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
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
              icon: Icons.access_time_rounded,
              title: 'تقارير الحضور',
              onTap: () => _navigateTo(context, '/worker-attendance-reports'),
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
              icon: Icons.app_settings_alt_rounded,
              title: 'إعدادات التطبيق',
              onTap: () => _navigateTo(context, '/admin/app-settings'),
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
              icon: Icons.pending_actions_rounded,
              title: 'الطلبات المعلقة',
              onTap: () => _navigateTo(context, '/admin/pending-orders'),
              route: currentRoute,
              badge: 'جديد',
            ),
            _buildMenuItem(
              context,
              icon: Icons.inventory_2_rounded,
              title: 'إدارة الهالك',
              onTap: () => _navigateTo(context, '/waste'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.business_rounded,
              title: 'إدارة الموزعين',
              onTap: () => _navigateTo(context, '/admin/distributors'),
              route: currentRoute,
              badge: 'جديد',
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
              icon: Icons.account_balance_rounded,
              title: 'الخزنة',
              onTap: () => _navigateTo(context, '/treasury-management'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.access_time_rounded,
              title: 'تقارير الحضور',
              onTap: () => _navigateTo(context, '/worker-attendance-reports'),
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
              icon: Icons.access_time_rounded,
              title: 'ملخص الحضور',
              onTap: () => _navigateTo(context, '/worker/attendance-summary'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.shopping_cart_rounded,
              title: 'الطلبات',
              onTap: () => _navigateTo(context, '/worker/orders'),
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
              icon: Icons.error_outline_rounded,
              title: 'الأعطال',
              onTap: () => _navigateTo(context, '/worker/faults'),
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
              onTap: () => _navigateTo(context, '/accountant/orders'),
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
            _buildMenuItem(
              context,
              icon: Icons.account_balance_rounded,
              title: 'الخزنة',
              onTap: () => _navigateTo(context, '/accountant/treasury-management'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.access_time_rounded,
              title: 'تقارير الحضور',
              onTap: () => _navigateTo(context, '/worker-attendance-reports'),
              route: currentRoute,
            ),
          ],

          // Warehouse Manager-specific menu items
          if (user.isWarehouseManager()) ...[
            _buildDivider('إدارة المخزن'),
            _buildMenuItem(
              context,
              icon: Icons.dashboard_rounded,
              title: 'لوحة التحكم',
              onTap: () => _navigateTo(context, '/warehouse/dashboard'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.shopping_cart_rounded,
              title: 'الطلبات',
              onTap: () => _navigateTo(context, '/warehouse/orders'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.local_shipping_rounded,
              title: 'طلبات الصرف',
              onTap: () => _navigateTo(context, '/warehouse/release-orders'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.warehouse_rounded,
              title: 'إدارة المخازن',
              onTap: () => _navigateTo(context, '/warehouse/management'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.inventory_2_rounded,
              title: 'المنتجات',
              onTap: () => _navigateTo(context, '/warehouse/products'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.precision_manufacturing_rounded,
              title: 'الإنتاج',
              onTap: () => _navigateTo(context, '/production'),
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
              onTap: () => _navigateTo(context, '/client/products/browser'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.track_changes_rounded,
              title: 'تتبع آخر طلب',
              onTap: () => _navigateTo(context, '/client/track-latest-order'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.local_shipping_rounded,
              title: 'تتبع الطلبات',
              onTap: () => _navigateTo(context, '/client/tracking'),
              route: currentRoute,
            ),
            _buildMenuItem(
              context,
              icon: Icons.assignment_return_rounded,
              title: 'طلباتي ومراجعاتي',
              onTap: () => _navigateTo(context, '/customer/requests'),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern divider line
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.5),
                  AccountantThemeConfig.accentBlue.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Enhanced section title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 400.ms, delay: 100.ms)
      .slideX(begin: -0.3, curve: Curves.easeOutBack);
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
    final isActive = route != null && route == currentRoute;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isActive
            ? AccountantThemeConfig.greenGradient
            : isLogout
                ? LinearGradient(
                    colors: [
                      AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
                      AccountantThemeConfig.warningDeep.withValues(alpha: 0.3),
                    ],
                  )
                : AccountantThemeConfig.cardGradient,
        boxShadow: isActive
            ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
            : isLogout
                ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange)
                : AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(
          isActive
              ? AccountantThemeConfig.primaryGreen
              : isLogout
                  ? AccountantThemeConfig.warningOrange
                  : AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: isActive
              ? Colors.white.withValues(alpha: 0.1)
              : AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
          highlightColor: isActive
              ? Colors.white.withValues(alpha: 0.05)
              : AccountantThemeConfig.primaryGreen.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Enhanced icon with modern design
                Container(
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.2),
                              Colors.white.withValues(alpha: 0.3),
                            ],
                          )
                        : isLogout
                            ? LinearGradient(
                                colors: [
                                  AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
                                  AccountantThemeConfig.warningDeep.withValues(alpha: 0.3),
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                                  AccountantThemeConfig.deepBlue.withValues(alpha: 0.3),
                                ],
                              ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isActive || isLogout
                        ? [
                            BoxShadow(
                              color: isActive
                                  ? AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)
                                  : AccountantThemeConfig.warningOrange.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    icon,
                    color: isActive
                        ? Colors.white
                        : isLogout
                            ? AccountantThemeConfig.warningOrange
                            : Colors.white70,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                // Enhanced title text
                Expanded(
                  child: Text(
                    title,
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: isActive
                          ? Colors.white
                          : isLogout
                              ? AccountantThemeConfig.warningOrange
                              : Colors.white,
                      fontWeight: isActive || isLogout ? FontWeight.bold : FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                // Enhanced badge design
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.8),
                                Colors.white
                              ],
                            )
                          : AccountantThemeConfig.orangeGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AccountantThemeConfig.glowShadows(
                        isActive
                            ? Colors.white
                            : AccountantThemeConfig.warningOrange
                      ),
                    ),
                    child: Text(
                      badge,
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: isActive
                            ? AccountantThemeConfig.primaryGreen
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: 300.ms, delay: (50).ms)
      .slideX(begin: -0.2, curve: Curves.easeOutBack);
  }

  void _navigateTo(BuildContext context, String route, {Map<String, dynamic>? arguments}) {
    // Close the drawer first
    Navigator.pop(context);

    // If already on the same route, don't navigate again
    if (ModalRoute.of(context)?.settings.name == route) return;

    // Add a small delay to ensure drawer is closed before navigation
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        // Check if user is authenticated before navigation
        final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = supabaseProvider.user ?? authProvider.user;

        if (user == null && route != '/login' && route != '/menu') {
          // User is not authenticated, redirect to login
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }

        // Use pushReplacementNamed for dashboard routes to avoid stack buildup
        if (route.contains('/dashboard') || route == '/notifications' || route == '/profile' || route == '/settings') {
          Navigator.pushReplacementNamed(
            context,
            route,
            arguments: arguments
          );
        } else {
          Navigator.pushNamed(
            context,
            route,
            arguments: arguments
          );
        }
      } catch (e) {
        print('Navigation error to $route: $e');
        // Fallback: try with pushReplacementNamed if pushNamed fails
        try {
          Navigator.pushReplacementNamed(
            context,
            route,
            arguments: arguments
          );
        } catch (e2) {
          print('Fallback navigation error to $route: $e2');
          // Last resort: show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في التنقل إلى $route'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AccountantThemeConfig.primaryCardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with gradient background and glow effect
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AccountantThemeConfig.dangerRed,
                      AccountantThemeConfig.dangerRed.withOpacity(0.8)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),

              const SizedBox(height: 24),

              // Title with modern typography
              Text(
                'تأكيد تسجيل الخروج',
                style: AccountantThemeConfig.headlineMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Content message with proper RTL support
              Text(
                'هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Modern gradient buttons
              Row(
                children: [
                  // Cancel button with orange gradient
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AccountantThemeConfig.orangeGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'إلغاء',
                          style: AccountantThemeConfig.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Logout button with red gradient
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AccountantThemeConfig.dangerRed,
                            AccountantThemeConfig.dangerRed.withOpacity(0.8)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'تسجيل الخروج',
                          style: AccountantThemeConfig.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
