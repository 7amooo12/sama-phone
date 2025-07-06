/// Worker Check-In Screen for SmartBizTracker
///
/// This screen provides a dedicated interface for workers to check in
/// with biometric authentication and location validation capabilities.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/supabase_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../services/biometric_attendance_service.dart';
import '../../services/location_service.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../models/attendance_models.dart';
import '../../models/user_model.dart';

class WorkerCheckInScreen extends StatefulWidget {
  const WorkerCheckInScreen({super.key});

  @override
  State<WorkerCheckInScreen> createState() => _WorkerCheckInScreenState();
}

class _WorkerCheckInScreenState extends State<WorkerCheckInScreen>
    with TickerProviderStateMixin {
  final BiometricAttendanceService _biometricService = BiometricAttendanceService();
  final LocationService _locationService = LocationService();
  
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  
  bool _isProcessing = false;
  bool _isLocationValid = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _validateLocation();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _locationService.dispose();
    super.dispose();
  }

  /// Validate worker location for check-in
  Future<void> _validateLocation() async {
    try {
      AppLogger.info('🔍 Validating location for check-in...');
      
      final hasPermission = await _locationService.checkAndRequestLocationPermissions();
      if (!hasPermission) {
        setState(() {
          _statusMessage = 'يرجى تفعيل أذونات الموقع للمتابعة';
          _isLocationValid = false;
        });
        return;
      }

      // Additional location validation logic can be added here
      setState(() {
        _statusMessage = 'الموقع صالح - يمكنك تسجيل الحضور';
        _isLocationValid = true;
      });

    } catch (e) {
      AppLogger.error('❌ Error validating location: $e');
      setState(() {
        _statusMessage = 'خطأ في التحقق من الموقع';
        _isLocationValid = false;
      });
    }
  }

  /// Handle biometric check-in
  Future<void> _handleCheckIn() async {
    if (!_isLocationValid) {
      _showErrorMessage('يجب التحقق من الموقع أولاً');
      return;
    }

    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final userModel = supabaseProvider.user;
    
    if (userModel == null) {
      _showErrorMessage('خطأ في بيانات المستخدم');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      AppLogger.info('🔐 Processing check-in for worker: ${userModel.id}');

      final result = await _biometricService.processBiometricAttendance(
        workerId: userModel.id,
        attendanceType: AttendanceType.checkIn,
      );

      if (result.success) {
        AppLogger.info('✅ Check-in successful');
        _showSuccessMessage('تم تسجيل الحضور بنجاح');
        
        // Navigate back after successful check-in
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else {
        AppLogger.warning('⚠️ Check-in failed: ${result.errorMessage}');
        _showErrorMessage(result.errorMessage ?? 'فشل في تسجيل الحضور');
      }
    } catch (e) {
      AppLogger.error('❌ Error processing check-in: $e');
      _showErrorMessage('خطأ في معالجة الحضور: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final userModel = supabaseProvider.user;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
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
                _buildAppBar(),
                
                // Main Content
                Expanded(
                  child: _buildContent(userModel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Row(
        children: [
          // Back Button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AccountantThemeConfig.cardGradient,
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Text(
              'تسجيل الحضور',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Status Indicator
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
              _isLocationValid ? Icons.check_circle : Icons.warning,
              color: _isLocationValid 
                  ? AccountantThemeConfig.primaryGreen
                  : AccountantThemeConfig.warningOrange,
              size: 20,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildContent(UserModel? userModel) {
    if (userModel == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Status Card
          if (_statusMessage != null) ...[
            _buildStatusCard(),
            const SizedBox(height: 32),
          ],

          // Check-in Button
          _buildCheckInButton(),

          const SizedBox(height: 40),

          // Instructions
          _buildInstructions(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(
          _isLocationValid
              ? AccountantThemeConfig.primaryGreen
              : AccountantThemeConfig.warningOrange
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Row(
        children: [
          Icon(
            _isLocationValid ? Icons.check_circle : Icons.warning,
            color: _isLocationValid
                ? AccountantThemeConfig.primaryGreen
                : AccountantThemeConfig.warningOrange,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _statusMessage!,
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.3, end: 0);
  }

  Widget _buildCheckInButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseController.value * 0.05),
          child: GestureDetector(
            onTap: _isProcessing || !_isLocationValid ? null : _handleCheckIn,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen.withOpacity(0.8),
                    AccountantThemeConfig.primaryGreen.withOpacity(0.4),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 4,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.login,
                          size: 60,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'حضور',
                          style: AccountantThemeConfig.headlineSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildInstructions() {
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
            'تعليمات تسجيل الحضور',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInstructionItem(
            icon: Icons.location_on,
            text: 'تأكد من وجودك في موقع العمل المحدد',
          ),
          const SizedBox(height: 12),
          _buildInstructionItem(
            icon: Icons.fingerprint,
            text: 'اضغط على زر الحضور لبدء المصادقة البيومترية',
          ),
          const SizedBox(height: 12),
          _buildInstructionItem(
            icon: Icons.access_time,
            text: 'سيتم تسجيل وقت الحضور تلقائياً',
          ),
        ],
      ),
    ).animate().fadeIn(duration: 1000.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildInstructionItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: AccountantThemeConfig.accentBlue,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}
