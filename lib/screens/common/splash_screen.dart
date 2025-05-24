import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/home_provider.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';
import 'package:smartbiztracker_new/widgets/common/animated_screen.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/config/constants.dart' as app_constants;
import 'package:smartbiztracker_new/utils/app_logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward().then((_) => _checkAuthState());
  }

  Future<void> _checkAuthState() async {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      await supabaseProvider.checkAuthState();

      if (!mounted) return;

      final user = supabaseProvider.user;

      if (user == null) {
        // User is not logged in
        _handleNavigation(user);
        return;
      }

      if (user.status != 'approved') {
        // User is not approved yet
        _handleNavigation(user);
        return;
      }

      // User is logged in, navigate to the appropriate dashboard
      _handleNavigation(user);
    } catch (e) {
      AppLogger.error('Error checking auth state: $e');
      if (mounted) {
        _handleNavigation(null);
      }
    }
  }

  void _navigateToRoute(String route) {
    Navigator.pushReplacementNamed(context, route);
  }

  void _handleNavigation(UserModel? user) {
    if (user == null) {
      _navigateToRoute('/login');
      return;
    }

    if (user.status == 'pending') {
      _navigateToRoute('/waiting-approval');
      return;
    }

    switch (user.role) {
      case UserRole.admin:
        _navigateToRoute('/admin/dashboard');
        break;
      case UserRole.owner:
        _navigateToRoute('/owner/dashboard');
        break;
      case UserRole.client:
        _navigateToRoute('/client/dashboard');
        break;
      case UserRole.worker:
        _navigateToRoute('/worker/dashboard');
        break;
      case UserRole.accountant:
        _navigateToRoute('/accountant/dashboard');
        break;
      default:
        _navigateToRoute('/login');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientAnimatedScreen(
      gradientColors: StyleSystem.coolGradient,
      showAppBar: false,
      showDrawer: false,
      animationType: AnimationType.fadeIn,
      animationDuration: const Duration(milliseconds: 800),
      safeArea: false,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo container with shadow
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: StyleSystem.shadowLarge,
                  ),
                  child: Center(
                    child: AnimationSystem.pulse(
                      Lottie.asset(
                        'assets/animations/loading.json',
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                      duration: const Duration(milliseconds: 2000),
                      minScale: 0.95,
                      maxScale: 1.05,
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                // App name with shadow
                Text(
                  app_constants.AppConstants.appName,
                  style: StyleSystem.displayLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    shadows: [
                      const Shadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // App description
                AnimationSystem.fadeSlideInWithDelay(
                  Text(
                    app_constants.AppConstants.appNameArabic,
                    style: StyleSystem.headlineMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                ),

                const SizedBox(height: 70),

                // Loading indicator
                AnimationSystem.fadeSlideInWithDelay(
                  Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                  delay: const Duration(milliseconds: 600),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
