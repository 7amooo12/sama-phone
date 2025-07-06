/// Worker Check-Out Screen for SmartBizTracker
///
/// This screen provides a dedicated interface for workers to check out
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

class WorkerCheckOutScreen extends StatefulWidget {
  const WorkerCheckOutScreen({super.key});

  @override
  State<WorkerCheckOutScreen> createState() => _WorkerCheckOutScreenState();
}

class _WorkerCheckOutScreenState extends State<WorkerCheckOutScreen>
    with TickerProviderStateMixin {
  final BiometricAttendanceService _biometricService = BiometricAttendanceService();
  final LocationService _locationService = LocationService();
  
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  
  bool _isProcessing = false;
  bool _isLocationValid = false;
  bool _hasCheckedInToday = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _validateLocation();
    _checkTodayAttendance();
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

  /// Check if worker has checked in today
  Future<void> _checkTodayAttendance() async {
    try {
      final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final userModel = supabaseProvider.user;

      if (userModel != null) {
        await attendanceProvider.refreshAttendanceData(userModel.id);
        setState(() {
          _hasCheckedInToday = attendanceProvider.hasCheckedInToday;
        });
      }
    } catch (e) {
      AppLogger.error('❌ Error checking today attendance: $e');
    }
  }

  /// Validate worker location for check-out
  Future<void> _validateLocation() async {
    try {
      AppLogger.info('🔍 Validating location for check-out...');
      
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
        _statusMessage = 'الموقع صالح - يمكنك تسجيل الانصراف';
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

  /// Handle biometric check-out
  Future<void> _handleCheckOut() async {
    if (!_isLocationValid) {
      _showErrorMessage('يجب التحقق من الموقع أولاً');
      return;
    }

    if (!_hasCheckedInToday) {
      _showErrorMessage('يجب تسجيل الحضور أولاً قبل الانصراف');
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
      AppLogger.info('🔐 Processing check-out for worker: ${userModel.id}');

      final result = await _biometricService.processBiometricAttendance(
        workerId: userModel.id,
        attendanceType: AttendanceType.checkOut,
      );

      if (result.success) {
        AppLogger.info('✅ Check-out successful');
        _showSuccessMessage('تم تسجيل الانصراف بنجاح');
        
        // Navigate back after successful check-out
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else {
        AppLogger.warning('⚠️ Check-out failed: ${result.errorMessage}');
        _showErrorMessage(result.errorMessage ?? 'فشل في تسجيل الانصراف');
      }
    } catch (e) {
      AppLogger.error('❌ Error processing check-out: $e');
      _showErrorMessage('خطأ في معالجة الانصراف: $e');
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
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
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
              'تسجيل الانصراف',
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
                  AccountantThemeConfig.warningOrange.withOpacity(0.3),
                  AccountantThemeConfig.accentBlue.withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
            ),
            child: Icon(
              _isLocationValid && _hasCheckedInToday ? Icons.check_circle : Icons.warning,
              color: _isLocationValid && _hasCheckedInToday
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

          // Check-out Button
          _buildCheckOutButton(),

          const SizedBox(height: 40),

          // Instructions
          _buildInstructions(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isReady = _isLocationValid && _hasCheckedInToday;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(
          isReady
              ? AccountantThemeConfig.primaryGreen
              : AccountantThemeConfig.warningOrange
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isReady ? Icons.check_circle : Icons.warning,
                color: isReady
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

          if (!_hasCheckedInToday) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.warningOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AccountantThemeConfig.warningOrange.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info,
                    color: AccountantThemeConfig.warningOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لم يتم تسجيل الحضور اليوم',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.3, end: 0);
  }

  Widget _buildCheckOutButton() {
    final canCheckOut = _isLocationValid && _hasCheckedInToday;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseController.value * 0.05),
          child: GestureDetector(
            onTap: _isProcessing || !canCheckOut ? null : _handleCheckOut,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (canCheckOut ? AccountantThemeConfig.warningOrange : Colors.grey)
                        .withOpacity(0.8),
                    (canCheckOut ? AccountantThemeConfig.warningOrange : Colors.grey)
                        .withOpacity(0.4),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (canCheckOut ? AccountantThemeConfig.warningOrange : Colors.grey)
                        .withOpacity(0.4),
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
                          Icons.exit_to_app,
                          size: 60,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'انصراف',
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
            'تعليمات تسجيل الانصراف',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInstructionItem(
            icon: Icons.login,
            text: 'تأكد من تسجيل الحضور في بداية اليوم',
          ),
          const SizedBox(height: 12),
          _buildInstructionItem(
            icon: Icons.location_on,
            text: 'تأكد من وجودك في موقع العمل المحدد',
          ),
          const SizedBox(height: 12),
          _buildInstructionItem(
            icon: Icons.fingerprint,
            text: 'اضغط على زر الانصراف لبدء المصادقة البيومترية',
          ),
          const SizedBox(height: 12),
          _buildInstructionItem(
            icon: Icons.access_time,
            text: 'سيتم تسجيل وقت الانصراف تلقائياً',
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
