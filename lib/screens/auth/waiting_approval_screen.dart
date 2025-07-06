import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_role.dart';

import 'dart:async';
import 'dart:ui' as ui;

class WaitingApprovalScreen extends StatefulWidget {

  const WaitingApprovalScreen({super.key, this.email});
  final String? email;

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  Timer? _checkApprovalTimer;

  @override
  void initState() {
    super.initState();

    // إعداد الأنيميشن
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // بدء الأنيميشن
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);

    // فحص دوري لحالة الموافقة
    _startApprovalCheck();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _checkApprovalTimer?.cancel();
    super.dispose();
  }

  void _startApprovalCheck() {
    // Increase interval to reduce excessive API calls and add exponential backoff
    _checkApprovalTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkUserApprovalStatus();
    });
  }

  Future<void> _checkUserApprovalStatus() async {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

    // إذا كان لدينا بريد إلكتروني، نفحص حالة المستخدم مباشرة
    if (widget.email != null) {
      try {
        final userData = await supabaseProvider.getUserDataByEmail(widget.email!);
        if (userData != null && (userData.isApproved || userData.isAdmin())) {
          _checkApprovalTimer?.cancel();
          if (mounted) {
            // محاولة تسجيل الدخول تلقائياً أو التوجه للوحة التحكم
            Navigator.of(context).pushReplacementNamed(_getDashboardRoute(userData));
          }
        }
      } catch (e) {
        // في حالة الخطأ، نستمر في الفحص
      }
    } else {
      // الطريقة القديمة - مع إجبار تحديث البيانات
      await supabaseProvider.forceRefreshUserData();
      final user = supabaseProvider.user;
      if (user != null && (user.isApproved || user.isAdmin())) {
        _checkApprovalTimer?.cancel();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(_getDashboardRoute(user));
        }
      }
    }
  }

  // Add this method to determine the dashboard route based on user role
  String _getDashboardRoute(UserModel user) {
    switch (user.role) {
      case UserRole.admin:
        return AppRoutes.adminDashboard;
      case UserRole.client:
        return AppRoutes.clientDashboard;
      case UserRole.worker:
        return AppRoutes.workerDashboard;
      case UserRole.owner:
        return AppRoutes.ownerDashboard;
      case UserRole.accountant:
        return AppRoutes.accountantDashboard;
      case UserRole.warehouseManager:
        return AppRoutes.warehouseManagerDashboard;
      default:
        return AppRoutes.login;
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final user = supabaseProvider.user;

    // Check if user is approved already or is admin
    if (user != null && (user.isApproved || user.isAdmin())) {
      // Navigate to appropriate dashboard
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(_getDashboardRoute(user));
      });
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Log user out when going back
        await supabaseProvider.signOut();
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        }
      },
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Modern animated waiting icon
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: AnimatedBuilder(
                              animation: _rotationAnimation,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _rotationAnimation.value * 2 * 3.14159,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      gradient: AccountantThemeConfig.blueGradient,
                                      shape: BoxShape.circle,
                                      boxShadow: AccountantThemeConfig.glowShadows(
                                        AccountantThemeConfig.accentBlue,
                                      ),
                                      border: AccountantThemeConfig.glowBorder(
                                        AccountantThemeConfig.accentBlue,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.hourglass_empty_rounded,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AccountantThemeConfig.largePadding),

                      // Modern title
                      Text(
                        'في انتظار الموافقة',
                        style: AccountantThemeConfig.headlineLarge.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AccountantThemeConfig.defaultPadding),

                      // Modern description card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
                        decoration: AccountantThemeConfig.primaryCardDecoration,
                        child: Column(
                          children: [
                            // Main message
                            Text(
                              'حسابك في انتظار الموافقة من الإدارة',
                              textAlign: TextAlign.center,
                              style: AccountantThemeConfig.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            // Email display if available
                            if (widget.email != null) ...[
                              const SizedBox(height: AccountantThemeConfig.smallPadding),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AccountantThemeConfig.defaultPadding,
                                  vertical: AccountantThemeConfig.smallPadding,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AccountantThemeConfig.accentBlue.withOpacity(0.2),
                                      AccountantThemeConfig.accentBlue.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                                  border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.email_rounded,
                                      color: AccountantThemeConfig.accentBlue,
                                      size: 16,
                                    ),
                                    const SizedBox(width: AccountantThemeConfig.smallPadding),
                                    Flexible(
                                      child: Text(
                                        widget.email!,
                                        style: AccountantThemeConfig.bodyMedium.copyWith(
                                          color: AccountantThemeConfig.accentBlue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: AccountantThemeConfig.defaultPadding),

                            // Status message
                            Text(
                              'سيتم إعلامك تلقائياً عندما يتم الموافقة على حسابك',
                              textAlign: TextAlign.center,
                              style: AccountantThemeConfig.bodyMedium.copyWith(
                                color: AccountantThemeConfig.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AccountantThemeConfig.largePadding),

                      // Modern retry button
                      if (widget.email != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: AccountantThemeConfig.defaultPadding),
                          decoration: BoxDecoration(
                            gradient: AccountantThemeConfig.greenGradient,
                            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // إجبار تحديث بيانات المستخدم
                              await supabaseProvider.forceRefreshUserData();
                              // فحص الحالة مرة أخرى
                              await _checkUserApprovalStatus();
                            },
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                            label: Text(
                              'إعادة المحاولة',
                              style: AccountantThemeConfig.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                              ),
                            ),
                          ),
                        ),

                      // Modern logout button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AccountantThemeConfig.dangerRed,
                              AccountantThemeConfig.dangerRed.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
                          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.dangerRed),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await supabaseProvider.signOut();

                            if (context.mounted) {
                              Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                            }
                          },
                          icon: const Icon(Icons.logout_rounded, color: Colors.white),
                          label: Text(
                            'تسجيل الخروج',
                            style: AccountantThemeConfig.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                            ),
                          ),
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
  }
}
