import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/models/worker_attendance_model.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// مكون عرض فشل تسجيل الحضور
class AttendanceFailureWidget extends StatefulWidget {
  final String errorMessage;
  final String? errorCode;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final Duration displayDuration;

  const AttendanceFailureWidget({
    super.key,
    required this.errorMessage,
    this.errorCode,
    this.onRetry,
    this.onDismiss,
    this.displayDuration = const Duration(seconds: 6),
  });

  @override
  State<AttendanceFailureWidget> createState() => _AttendanceFailureWidgetState();
}

class _AttendanceFailureWidgetState extends State<AttendanceFailureWidget>
    with TickerProviderStateMixin {
  late AnimationController _mainAnimationController;
  late AnimationController _shakeAnimationController;
  late AnimationController _pulseAnimationController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _shakeAnimation;
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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _shakeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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

    _shakeAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeAnimationController,
      curve: Curves.elasticIn,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimationSequence() async {
    await _mainAnimationController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    await _shakeAnimationController.forward();
    _shakeAnimationController.reset();
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
    _shakeAnimationController.dispose();
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
              _shakeAnimationController,
              _pulseAnimationController,
            ]),
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.translate(
                  offset: Offset(_shakeAnimation.value * 10, 0),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: AccountantThemeConfig.cardGradient,
                        borderRadius: BorderRadius.circular(24),
                        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.dangerRed),
                        boxShadow: [
                          ...AccountantThemeConfig.cardShadows,
                          BoxShadow(
                            color: AccountantThemeConfig.dangerRed.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // أيقونة الخطأ المتحركة
                          _buildErrorIcon(),
                          
                          const SizedBox(height: 24),
                          
                          // رسالة الخطأ
                          _buildErrorMessage(),
                          
                          const SizedBox(height: 20),
                          
                          // تفاصيل الخطأ
                          if (widget.errorCode != null)
                            _buildErrorDetails(),
                          
                          const SizedBox(height: 24),
                          
                          // أزرار العمل
                          _buildActionButtons(),
                        ],
                      ),
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

  Widget _buildErrorIcon() {
    return Transform.scale(
      scale: _pulseAnimation.value,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AccountantThemeConfig.redGradient,
          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
        ),
        child: const Icon(
          Icons.error_outline,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Column(
      children: [
        Text(
          'فشل في تسجيل الحضور',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: AccountantThemeConfig.dangerRed,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.dangerRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AccountantThemeConfig.dangerRed.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AccountantThemeConfig.warningOrange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.errorMessage,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل الخطأ:',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'كود الخطأ: ${widget.errorCode}',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white60,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getErrorSolution(),
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (widget.onRetry != null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(
                'إعادة المحاولة',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: AccountantThemeConfig.primaryButtonStyle.copyWith(
                backgroundColor: WidgetStateProperty.all(AccountantThemeConfig.primaryGreen),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.onDismiss,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'إغلاق',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getErrorSolution() {
    switch (widget.errorCode) {
      case AttendanceErrorCodes.tokenExpired:
        return 'الحل: اطلب من العامل إنشاء رمز QR جديد';
      case AttendanceErrorCodes.invalidSignature:
        return 'الحل: تأكد من صحة رمز QR وأنه غير تالف';
      case AttendanceErrorCodes.replayAttack:
        return 'الحل: استخدم رمز QR جديد لم يتم استخدامه من قبل';
      case AttendanceErrorCodes.deviceMismatch:
        return 'الحل: استخدم نفس الجهاز المسجل للعامل';
      case AttendanceErrorCodes.gapViolation:
        return 'الحل: انتظر حتى انقضاء 15 ساعة من آخر تسجيل';
      case AttendanceErrorCodes.sequenceError:
        return 'الحل: تأكد من تسجيل الخروج قبل تسجيل دخول جديد';
      case AttendanceErrorCodes.workerNotFound:
        return 'الحل: تأكد من تسجيل العامل في النظام';
      case AttendanceErrorCodes.networkError:
        return 'الحل: تحقق من اتصال الإنترنت وأعد المحاولة';
      case AttendanceErrorCodes.cameraError:
        return 'الحل: تحقق من أذونات الكاميرا في إعدادات التطبيق';
      default:
        return 'الحل: تحقق من البيانات وأعد المحاولة';
    }
  }
}
