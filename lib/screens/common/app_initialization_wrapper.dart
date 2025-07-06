import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/screens/common/professional_loading_screen.dart';
import 'package:smartbiztracker_new/services/initialization_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/models/user_role.dart';

/// Wrapper that handles app initialization flow
/// Shows professional loading screen during heavy initialization tasks
/// Then transitions to normal splash screen for authentication flow
class AppInitializationWrapper extends StatefulWidget {
  const AppInitializationWrapper({super.key});

  @override
  State<AppInitializationWrapper> createState() => _AppInitializationWrapperState();
}

class _AppInitializationWrapperState extends State<AppInitializationWrapper> {
  bool _isInitializationComplete = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    try {
      AppLogger.info('🚀 Starting app initialization wrapper...');
      
      // The InitializationService will be called from ProfessionalLoadingScreen
      // This wrapper just manages the flow
      
    } catch (e) {
      AppLogger.error('❌ App initialization wrapper failed: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onInitializationComplete() {
    AppLogger.info('✅ Initialization complete, checking authentication...');
    if (mounted) {
      setState(() {
        _isInitializationComplete = true;
      });
      _checkAuthenticationAndNavigate();
    }
  }

  Future<void> _checkAuthenticationAndNavigate() async {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      await supabaseProvider.checkAuthState();

      if (!mounted) return;

      final user = supabaseProvider.user;

      if (user == null) {
        AppLogger.info('🚪 No authenticated user found, navigating to login');
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      AppLogger.info('👤 Authenticated user found: ${user.email} (${user.role.value})');

      if (!user.isApproved && !user.isAdmin()) {
        AppLogger.info('⏳ User not approved, navigating to waiting screen');
        Navigator.of(context).pushReplacementNamed('/waiting-approval');
        return;
      }

      AppLogger.info('✅ User approved, navigating to dashboard');
      _navigateToUserDashboard(user.role);
    } catch (e) {
      AppLogger.error('❌ Error checking auth state: $e');
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _navigateToUserDashboard(UserRole role) {
    String route;
    switch (role) {
      case UserRole.admin:
        route = '/admin/dashboard';
        break;
      case UserRole.owner:
        route = '/owner/dashboard';
        break;
      case UserRole.client:
        route = '/client/dashboard';
        break;
      case UserRole.worker:
        route = '/worker/dashboard';
        break;
      case UserRole.accountant:
        route = '/accountant/dashboard';
        break;
      case UserRole.warehouseManager:
        route = '/warehouse-manager';
        break;
      default:
        route = '/login';
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorScreen();
    }

    if (!_isInitializationComplete) {
      return ProfessionalLoadingScreen(
        onInitializationComplete: _onInitializationComplete,
      );
    }

    // Show a simple loading indicator while checking authentication
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                'حدث خطأ في تهيئة التطبيق',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = '';
                  });
                  _startInitialization();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
