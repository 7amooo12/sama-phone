import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/screens/auth/waiting_approval_screen.dart';
import 'package:smartbiztracker_new/screens/menu_screen.dart';
import 'package:smartbiztracker_new/utils/logger.dart';
import 'package:smartbiztracker_new/utils/safe_navigator.dart';
import 'package:smartbiztracker_new/utils/safe_provider_access.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with SafeProviderStateMixin {
  bool _navigationInProgress = false; // Prevent multiple navigation calls
  SupabaseProvider? _supabaseProvider;

  @override
  void initState() {
    super.initState();
    // Don't access Provider in initState - use didChangeDependencies instead
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe Provider access after widget tree is established
    _supabaseProvider ??= context.tryProvider<SupabaseProvider>();

    // Check auth state when Provider is available
    if (_supabaseProvider != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _supabaseProvider!.checkAuthState();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add error boundary and Directionality wrapper
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _buildAuthContent(context),
    );
  }

  Widget _buildAuthContent(BuildContext context) {
    try {
      // Use safe Provider access with fallback
      final supabaseProvider = context.tryProviderWithListen<SupabaseProvider>();
      if (supabaseProvider == null) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final user = supabaseProvider.user;

      // Show loading screen while checking authentication
      if (supabaseProvider.isLoading) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // If not authenticated, show menu screen
      if (user == null) {
        return const MenuScreen();
      }

    // If user is pending approval (except for admin users)
    if (user.status == 'pending' && !user.isAdmin()) {
      return const WaitingApprovalScreen();
    }

    // If user is not approved/active (except for admin users)
    if (!user.isApproved && !user.isAdmin()) {
      return const WaitingApprovalScreen();
    }

    // If user is rejected
    if (user.status == 'rejected') {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'تم رفض طلب التسجيل',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await supabaseProvider.signOut();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed(AppRoutes.menu);
                  }
                },
                child: const Text('العودة للقائمة الرئيسية'),
              ),
            ],
          ),
        ),
      );
    }

    // Navigate to appropriate dashboard based on user role with safe navigation
    _navigateBasedOnAuthState(user);

      // Return loading indicator while navigation is being processed
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } catch (e) {
      // Handle Provider exceptions gracefully
      AppLogger.error('❌ AuthWrapper error: $e');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'خطأ في تحميل البيانات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'يرجى إعادة تشغيل التطبيق',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Safe navigation method with race condition protection
  void _navigateBasedOnAuthState(UserModel user) {
    if (_navigationInProgress) {
      AppLogger.warning('⚠️ Navigation already in progress, skipping');
      return;
    }

    _navigationInProgress = true;

    SafeNavigator.executeWithSafeContext(context, () async {
      try {
        final dashboardRoute = _getDashboardRoute(user);

        // 🔒 SECURITY: Log final navigation decision
        AppLogger.info('🔒 FINAL NAVIGATION: ${user.email} -> $dashboardRoute');
        if (dashboardRoute == AppRoutes.warehouseManagerDashboard) {
          AppLogger.info('✅ SECURITY OK: Warehouse manager routed correctly');
        } else if (dashboardRoute == AppRoutes.adminDashboard && user.role != UserRole.admin) {
          AppLogger.error('🚨 SECURITY BREACH: Non-admin user routed to admin dashboard!');
        }

        await SafeNavigator.pushReplacementSafely(context, dashboardRoute);
      } finally {
        if (mounted) {
          _navigationInProgress = false;
        }
      }
    });
  }

  /// Get dashboard route based on user role
  String _getDashboardRoute(UserModel user) {
    final role = UserRole.fromString(user.userRole);

    // 🔒 SECURITY: Log critical role navigation
    AppLogger.info('🔒 ROLE NAVIGATION: ${user.email} -> Role: "${user.userRole}" -> Enum: $role');

    switch (role) {
      case UserRole.admin:
        return AppRoutes.adminDashboard;
      case UserRole.owner:
        return AppRoutes.ownerDashboard;
      case UserRole.worker:
        return AppRoutes.workerDashboard;
      case UserRole.client:
        return AppRoutes.clientDashboard;
      case UserRole.accountant:
        return AppRoutes.accountantDashboard;
      case UserRole.warehouseManager:
        return AppRoutes.warehouseManagerDashboard;
      default:
        AppLogger.warning('❌ UNKNOWN USER ROLE: "${user.userRole}" -> $role');
        return AppRoutes.menu;
    }
  }
}
