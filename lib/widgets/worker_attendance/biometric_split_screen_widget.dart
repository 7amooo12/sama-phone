/// Biometric Split-Screen Attendance Widget
/// 
/// This widget provides a split-screen layout for worker attendance with
/// biometric authentication and location validation for SmartBizTracker.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/attendance_models.dart';
import '../../providers/attendance_provider.dart';
import '../../services/biometric_attendance_service.dart';
import '../../services/location_service.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../worker/qr_attendance_widget.dart';

class BiometricSplitScreenWidget extends StatefulWidget {
  final String workerId;
  final VoidCallback? onAttendanceSuccess;
  final Function(String)? onError;

  const BiometricSplitScreenWidget({
    super.key,
    required this.workerId,
    this.onAttendanceSuccess,
    this.onError,
  });

  @override
  State<BiometricSplitScreenWidget> createState() => _BiometricSplitScreenWidgetState();
}

class _BiometricSplitScreenWidgetState extends State<BiometricSplitScreenWidget>
    with TickerProviderStateMixin {
  
  final BiometricAttendanceService _biometricService = BiometricAttendanceService();
  final LocationService _locationService = LocationService();
  
  late AnimationController _pulseController;
  late AnimationController _slideController;
  
  bool _isProcessingCheckIn = false;
  bool _isProcessingCheckOut = false;
  bool _showQRCheckIn = false;
  bool _showQRCheckOut = false;

  // Previous attendance state for detecting changes
  bool? _previousHasCheckedIn;
  bool? _previousHasCheckedOut;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check for attendance changes to auto-toggle QR mode
    final attendanceProvider = context.watch<AttendanceProvider>();
    _checkAttendanceChanges(attendanceProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: _buildSplitScreen(),
            ),
          ],
        ),
      ),
    );
  }

  void _checkAttendanceChanges(AttendanceProvider attendanceProvider) {
    final currentHasCheckedIn = attendanceProvider.hasCheckedInToday;
    final currentHasCheckedOut = attendanceProvider.hasCheckedOutToday;

    // If check-in status changed from false to true, hide QR check-in
    if (_previousHasCheckedIn == false && currentHasCheckedIn == true) {
      if (_showQRCheckIn) {
        setState(() {
          _showQRCheckIn = false;
        });
        widget.onAttendanceSuccess?.call();
      }
    }

    // If check-out status changed from false to true, hide QR check-out
    if (_previousHasCheckedOut == false && currentHasCheckedOut == true) {
      if (_showQRCheckOut) {
        setState(() {
          _showQRCheckOut = false;
        });
        widget.onAttendanceSuccess?.call();
      }
    }

    // Update previous state
    _previousHasCheckedIn = currentHasCheckedIn;
    _previousHasCheckedOut = currentHasCheckedOut;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                AccountantThemeConfig.primaryGreen,
                AccountantThemeConfig.accentBlue,
              ],
            ).createShader(bounds),
            child: Text(
              'نظام الحضور والانصراف',
              style: AccountantThemeConfig.headlineLarge.copyWith(
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'استخدم البصمة أو رمز QR للتسجيل',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSplitScreen() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.elasticOut,
      )),
      child: Row(
        children: [
          // قسم تسجيل الحضور
          Expanded(
            child: _buildAttendanceSection(
              title: 'تسجيل حضور',
              subtitle: 'بداية يوم العمل',
              icon: Icons.login_rounded,
              color: AccountantThemeConfig.primaryGreen,
              attendanceType: AttendanceType.checkIn,
              isProcessing: _isProcessingCheckIn,
              showQR: _showQRCheckIn,
              onBiometricTap: () => _handleBiometricAttendance(AttendanceType.checkIn),
              onQRTap: () => _toggleQRMode(AttendanceType.checkIn),
            ),
          ),
          
          // خط فاصل
          Container(
            width: 2,
            margin: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          // قسم تسجيل الانصراف
          Expanded(
            child: _buildAttendanceSection(
              title: 'تسجيل انصراف',
              subtitle: 'نهاية يوم العمل',
              icon: Icons.logout_rounded,
              color: AccountantThemeConfig.dangerRed,
              attendanceType: AttendanceType.checkOut,
              isProcessing: _isProcessingCheckOut,
              showQR: _showQRCheckOut,
              onBiometricTap: () => _handleBiometricAttendance(AttendanceType.checkOut),
              onQRTap: () => _toggleQRMode(AttendanceType.checkOut),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required AttendanceType attendanceType,
    required bool isProcessing,
    required bool showQR,
    required VoidCallback onBiometricTap,
    required VoidCallback onQRTap,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(color),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // العنوان
          Text(
            title,
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 30),
          
          if (showQR) ...[
            // عرض QR
            _buildQRSection(attendanceType),
          ] else ...[
            // أزرار الحضور
            _buildAttendanceButtons(
              color: color,
              icon: icon,
              isProcessing: isProcessing,
              onBiometricTap: onBiometricTap,
              onQRTap: onQRTap,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceButtons({
    required Color color,
    required IconData icon,
    required bool isProcessing,
    required VoidCallback onBiometricTap,
    required VoidCallback onQRTap,
  }) {
    return Column(
      children: [
        // زر البصمة الرئيسي
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.1),
              child: GestureDetector(
                onTap: isProcessing ? null : onBiometricTap,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: 0.8),
                        color.withValues(alpha: 0.4),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: isProcessing
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        )
                      : Icon(
                          Icons.fingerprint_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 20),
        
        Text(
          'اضغط للمصادقة بالبصمة',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 30),
        
        // زر QR البديل
        TextButton.icon(
          onPressed: isProcessing ? null : onQRTap,
          icon: Icon(
            Icons.qr_code_rounded,
            color: Colors.white60,
            size: 20,
          ),
          label: Text(
            'استخدام رمز QR',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white60,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQRSection(AttendanceType attendanceType) {
    return Column(
      children: [
        Container(
          height: 200,
          child: const QRAttendanceWidget(),
        ),
        
        const SizedBox(height: 20),
        
        TextButton.icon(
          onPressed: () => _toggleQRMode(attendanceType),
          icon: Icon(
            Icons.fingerprint_rounded,
            color: Colors.white60,
            size: 20,
          ),
          label: Text(
            'استخدام البصمة',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white60,
            ),
          ),
        ),
      ],
    );
  }

  void _toggleQRMode(AttendanceType attendanceType) {
    setState(() {
      if (attendanceType == AttendanceType.checkIn) {
        _showQRCheckIn = !_showQRCheckIn;
      } else {
        _showQRCheckOut = !_showQRCheckOut;
      }
    });
  }

  Future<void> _handleBiometricAttendance(AttendanceType attendanceType) async {
    setState(() {
      if (attendanceType == AttendanceType.checkIn) {
        _isProcessingCheckIn = true;
      } else {
        _isProcessingCheckOut = true;
      }
    });

    try {
      AppLogger.info('🔐 بدء معالجة الحضور البيومتري: ${attendanceType.arabicLabel}');

      final result = await _biometricService.processBiometricAttendance(
        workerId: widget.workerId,
        attendanceType: attendanceType,
      );

      if (result.success) {
        AppLogger.info('✅ تم تسجيل الحضور بنجاح');
        widget.onAttendanceSuccess?.call();
        
        // عرض رسالة نجاح
        _showSuccessMessage(attendanceType);
      } else {
        AppLogger.warning('⚠️ فشل في تسجيل الحضور: ${result.errorMessage}');
        widget.onError?.call(result.errorMessage ?? 'فشل في تسجيل الحضور');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة الحضور البيومتري: $e');
      widget.onError?.call('خطأ في معالجة الحضور: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (attendanceType == AttendanceType.checkIn) {
            _isProcessingCheckIn = false;
          } else {
            _isProcessingCheckOut = false;
          }
        });
      }
    }
  }

  void _showSuccessMessage(AttendanceType attendanceType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تسجيل ${attendanceType.arabicLabel} بنجاح',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
