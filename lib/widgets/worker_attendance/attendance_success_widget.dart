import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/models/worker_attendance_model.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:intl/intl.dart';

/// مكون عرض نجاح تسجيل الحضور
class AttendanceSuccessWidget extends StatefulWidget {
  final WorkerAttendanceModel attendanceRecord;
  final VoidCallback? onDismiss;
  final Duration displayDuration;

  const AttendanceSuccessWidget({
    super.key,
    required this.attendanceRecord,
    this.onDismiss,
    this.displayDuration = const Duration(seconds: 4),
  });

  @override
  State<AttendanceSuccessWidget> createState() => _AttendanceSuccessWidgetState();
}

class _AttendanceSuccessWidgetState extends State<AttendanceSuccessWidget>
    with TickerProviderStateMixin {
  late AnimationController _mainAnimationController;
  late AnimationController _checkmarkAnimationController;
  late AnimationController _pulseAnimationController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _checkmarkAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
    _scheduleAutoDismiss();
  }

  void _initializeAnimations() {
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _checkmarkAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _checkmarkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkmarkAnimationController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimationSequence() async {
    await _mainAnimationController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    await _checkmarkAnimationController.forward();
    _pulseAnimationController.repeat(reverse: true);
  }

  void _scheduleAutoDismiss() {
    Future.delayed(widget.displayDuration, () {
      if (mounted && widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    _checkmarkAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _mainAnimationController,
              _checkmarkAnimationController,
              _pulseAnimationController,
            ]),
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.cardGradient,
                      borderRadius: BorderRadius.circular(24),
                      border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                      boxShadow: [
                        ...AccountantThemeConfig.cardShadows,
                        BoxShadow(
                          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // أيقونة النجاح المتحركة
                        _buildSuccessIcon(),
                        
                        const SizedBox(height: 24),
                        
                        // رسالة النجاح
                        _buildSuccessMessage(),
                        
                        const SizedBox(height: 20),
                        
                        // معلومات العامل
                        _buildWorkerInfo(),
                        
                        const SizedBox(height: 20),
                        
                        // معلومات الحضور
                        _buildAttendanceInfo(),
                        
                        const SizedBox(height: 24),
                        
                        // زر الإغلاق
                        _buildDismissButton(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return Transform.scale(
      scale: _pulseAnimation.value,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AccountantThemeConfig.greenGradient,
          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
        ),
        child: Transform.scale(
          scale: _checkmarkAnimation.value,
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Column(
      children: [
        Text(
          'تم تسجيل الحضور بنجاح',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: AccountantThemeConfig.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _getAttendanceTypeMessage(),
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWorkerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AccountantThemeConfig.blueGradient,
            ),
            child: const Icon(
              Icons.person,
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
                  widget.attendanceRecord.workerName,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'رقم الموظف: ${widget.attendanceRecord.employeeId}',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceInfo() {
    final formatter = DateFormat('yyyy/MM/dd - HH:mm', 'ar');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _getAttendanceIcon(),
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getAttendanceTypeText(),
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                formatter.format(widget.attendanceRecord.timestamp),
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDismissButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.onDismiss,
        style: AccountantThemeConfig.primaryButtonStyle.copyWith(
          backgroundColor: WidgetStateProperty.all(AccountantThemeConfig.primaryGreen),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        child: Text(
          'موافق',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getAttendanceTypeMessage() {
    switch (widget.attendanceRecord.type) {
      case AttendanceType.checkIn:
        return 'تم تسجيل دخول العامل بنجاح';
      case AttendanceType.checkOut:
        return 'تم تسجيل خروج العامل بنجاح';
    }
  }

  String _getAttendanceTypeText() {
    switch (widget.attendanceRecord.type) {
      case AttendanceType.checkIn:
        return 'تسجيل دخول';
      case AttendanceType.checkOut:
        return 'تسجيل خروج';
    }
  }

  IconData _getAttendanceIcon() {
    switch (widget.attendanceRecord.type) {
      case AttendanceType.checkIn:
        return Icons.login;
      case AttendanceType.checkOut:
        return Icons.logout;
    }
  }
}
