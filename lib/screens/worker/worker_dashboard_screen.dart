/// Simplified Worker Dashboard Screen for SmartBizTracker
///
/// This screen provides a clean, attendance-focused interface for workers
/// with biometric authentication and location validation capabilities.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/supabase_provider.dart';
import '../../widgets/common/main_drawer.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../config/routes.dart';
import '../../models/user_model.dart';
// Removed BiometricSplitScreenWidget import - replaced with simple navigation buttons
import '../../services/location_service.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final LocationService _locationService = LocationService();
  DateTime? _lastBackPressTime;
  bool _isLoading = false;
  String? _attendanceStatus;

  @override
  void initState() {
    super.initState();
    _initializeAttendanceSystem();
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }

  /// Initialize the attendance system
  Future<void> _initializeAttendanceSystem() async {
    setState(() => _isLoading = true);

    try {
      AppLogger.info('🚀 تهيئة نظام الحضور...');

      // Check location permissions
      bool hasLocationPermission = await _locationService.checkAndRequestLocationPermissions();
      if (!hasLocationPermission) {
        setState(() {
          _attendanceStatus = 'يرجى تفعيل أذونات الموقع لاستخدام نظام الحضور';
        });
      } else {
        setState(() {
          _attendanceStatus = 'نظام الحضور جاهز للاستخدام';
        });
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة نظام الحضور: $e');
      setState(() {
        _attendanceStatus = 'خطأ في تهيئة نظام الحضور';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  /// Handle back button press with double-tap to exit
  Future<bool> _onWillPop() async {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'اضغط مرة أخرى للخروج من التطبيق',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AccountantThemeConfig.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return false;
    }
    return true;
  }

  /// Get appropriate welcome message based on time
  String _getWelcomeMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير';
    } else if (hour < 17) {
      return 'مساء الخير';
    } else {
      return 'مساء الخير';
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final userModel = supabaseProvider.user;

    if (userModel == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl, // Arabic RTL support
        child: Scaffold(
          key: _scaffoldKey,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Custom App Bar
                  _buildCustomAppBar(userModel),

                  // Main Content
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingState()
                        : _buildAttendanceView(userModel),
                  ),
                ],
              ),
            ),
          ),
          drawer: MainDrawer(
            onMenuPressed: _openDrawer,
            currentRoute: AppRoutes.workerDashboard,
          ),
        ),
      ),
    );
  }

  /// Build custom app bar with AccountantThemeConfig styling
  Widget _buildCustomAppBar(UserModel userModel) {
    final welcomeMessage = _getWelcomeMessage();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Row(
        children: [
          // Menu Button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AccountantThemeConfig.cardGradient,
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
            ),
            child: IconButton(
              onPressed: _openDrawer,
              icon: const Icon(
                Icons.menu,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Welcome Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  welcomeMessage,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userModel.name,
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Status Indicator
          if (_attendanceStatus != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                    AccountantThemeConfig.accentBlue.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
              ),
              child: Icon(
                _attendanceStatus!.contains('جاهز')
                    ? Icons.check_circle
                    : Icons.warning,
                color: _attendanceStatus!.contains('جاهز')
                    ? AccountantThemeConfig.primaryGreen
                    : AccountantThemeConfig.warningOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],

          // User Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AccountantThemeConfig.cardGradient,
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
              boxShadow: AccountantThemeConfig.cardShadows,
            ),
            child: Center(
              child: Text(
                userModel.name.isNotEmpty
                    ? userModel.name[0].toUpperCase()
                    : 'W',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
  }

  /// Build loading state with AccountantThemeConfig styling
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AccountantThemeConfig.cardGradient,
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
              boxShadow: AccountantThemeConfig.cardShadows,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'جاري تهيئة نظام الحضور...',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'يرجى الانتظار',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8));
  }

  /// Build simplified attendance view with enhanced UI
  Widget _buildAttendanceView(UserModel userModel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Status Card
          if (_attendanceStatus != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(16),
                border: AccountantThemeConfig.glowBorder(
                  _attendanceStatus!.contains('جاهز')
                      ? AccountantThemeConfig.primaryGreen
                      : AccountantThemeConfig.warningOrange
                ),
                boxShadow: AccountantThemeConfig.cardShadows,
              ),
              child: Row(
                children: [
                  Icon(
                    _attendanceStatus!.contains('جاهز')
                        ? Icons.check_circle
                        : Icons.warning,
                    color: _attendanceStatus!.contains('جاهز')
                        ? AccountantThemeConfig.primaryGreen
                        : AccountantThemeConfig.warningOrange,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _attendanceStatus!,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.3, end: 0),
          ],

          // Attendance Buttons Section
          _buildAttendanceButtons(),

          const SizedBox(height: 24),

          // Quick Actions
          _buildQuickActions(),
        ],
      ),
    );
  }

  /// Build attendance buttons section
  Widget _buildAttendanceButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        children: [
          // Title
          Text(
            'نظام الحضور والانصراف',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'اختر العملية المطلوبة',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Buttons Row
          Row(
            children: [
              // Check-In Button
              Expanded(
                child: _buildAttendanceButton(
                  title: 'حضور',
                  subtitle: 'تسجيل الحضور',
                  icon: Icons.login,
                  color: AccountantThemeConfig.primaryGreen,
                  onTap: () => _navigateToCheckIn(),
                ),
              ),

              const SizedBox(width: 16),

              // Check-Out Button
              Expanded(
                child: _buildAttendanceButton(
                  title: 'انصراف',
                  subtitle: 'تسجيل الانصراف',
                  icon: Icons.exit_to_app,
                  color: AccountantThemeConfig.warningOrange,
                  onTap: () => _navigateToCheckOut(),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.9, 0.9));
  }

  /// Build individual attendance button
  Widget _buildAttendanceButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: AccountantThemeConfig.glowBorder(color),
          ),
          child: Column(
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withOpacity(0.8),
                      color.withOpacity(0.4),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                title,
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 4),

              // Subtitle
              Text(
                subtitle,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigate to check-in screen
  void _navigateToCheckIn() {
    Navigator.of(context).pushNamed(AppRoutes.workerCheckIn).then((_) {
      // Refresh attendance status when returning from check-in
      _initializeAttendanceSystem();
    });
  }

  /// Navigate to check-out screen
  void _navigateToCheckOut() {
    Navigator.of(context).pushNamed(AppRoutes.workerCheckOut).then((_) {
      // Refresh attendance status when returning from check-out
      _initializeAttendanceSystem();
    });
  }

  /// Build quick actions section
  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إجراءات سريعة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.refresh,
                  label: 'تحديث النظام',
                  onTap: _initializeAttendanceSystem,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.location_on,
                  label: 'فحص الموقع',
                  onTap: _checkLocationStatus,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 1000.ms).slideY(begin: 0.3, end: 0);
  }

  /// Build individual quick action button
  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AccountantThemeConfig.accentBlue.withOpacity(0.3),
                AccountantThemeConfig.primaryGreen.withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Check location status
  Future<void> _checkLocationStatus() async {
    try {
      final cacheStatus = _locationService.getCacheStatus();
      final hasPermission = await _locationService.checkAndRequestLocationPermissions();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AccountantThemeConfig.darkBlueBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'حالة خدمة الموقع',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusRow('الأذونات', hasPermission ? 'متاحة' : 'غير متاحة'),
              _buildStatusRow('الموقع المحفوظ', cacheStatus['position_cached'] ? 'متاح' : 'غير متاح'),
              _buildStatusRow('إعدادات المخزن', cacheStatus['warehouse_settings_cached'] ? 'محفوظة' : 'غير محفوظة'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إغلاق',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.primaryGreen,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في فحص حالة الموقع: $e');
    }
  }

  /// Build status row for dialog
  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

}