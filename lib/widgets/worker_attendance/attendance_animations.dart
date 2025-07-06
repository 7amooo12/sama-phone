import 'dart:math' as dart_math;
import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// مجموعة الرسوم المتحركة الاحترافية لحضور العمال
class AttendanceAnimations {
  
  /// رسم متحرك للمسح الضوئي
  static Widget buildScanningAnimation({
    required AnimationController controller,
    required Widget child,
    Color? color,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Stack(
          children: [
            child,
            Positioned.fill(
              child: CustomPaint(
                painter: ScanLinePainter(
                  progress: controller.value,
                  color: color ?? AccountantThemeConfig.primaryGreen,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// رسم متحرك للنجاح مع تأثير الانفجار
  static Widget buildSuccessExplosion({
    required AnimationController controller,
    required Widget child,
  }) {
    final scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.elasticOut,
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Transform.scale(
          scale: scaleAnimation.value,
          child: Opacity(
            opacity: fadeAnimation.value,
            child: Stack(
              children: [
                child,
                // تأثير الانفجار
                if (controller.value > 0.3)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ExplosionPainter(
                        progress: (controller.value - 0.3) / 0.7,
                        color: AccountantThemeConfig.primaryGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// رسم متحرك للاهتزاز عند الخطأ
  static Widget buildShakeAnimation({
    required AnimationController controller,
    required Widget child,
  }) {
    final shakeAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.elasticIn,
    ));

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(shakeAnimation.value * 10, 0),
          child: child,
        );
      },
    );
  }

  /// رسم متحرك للنبض
  static Widget buildPulseAnimation({
    required AnimationController controller,
    required Widget child,
    double minScale = 0.95,
    double maxScale = 1.05,
  }) {
    final pulseAnimation = Tween<double>(
      begin: minScale,
      end: maxScale,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Transform.scale(
          scale: pulseAnimation.value,
          child: child,
        );
      },
    );
  }

  /// رسم متحرك للتحميل مع دوران
  static Widget buildLoadingSpinner({
    required AnimationController controller,
    Color? color,
    double size = 40,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Transform.rotate(
          angle: controller.value * 2 * 3.14159,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  (color ?? AccountantThemeConfig.primaryGreen).withOpacity(0.1),
                  color ?? AccountantThemeConfig.primaryGreen,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }

  /// رسم متحرك للعد التنازلي
  static Widget buildCountdownTimer({
    required AnimationController controller,
    required int totalSeconds,
    Color? color,
    double size = 60,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final remainingSeconds = (totalSeconds * (1 - controller.value)).ceil();
        final progress = controller.value;
        
        return Stack(
          alignment: Alignment.center,
          children: [
            // الدائرة الخلفية
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            // دائرة التقدم
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  color ?? AccountantThemeConfig.primaryGreen,
                ),
              ),
            ),
            // النص
            Text(
              remainingSeconds.toString(),
              style: AccountantThemeConfig.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: color ?? AccountantThemeConfig.primaryGreen,
              ),
            ),
          ],
        );
      },
    );
  }

  /// رسم متحرك للانتقال السلس
  static Widget buildSlideTransition({
    required AnimationController controller,
    required Widget child,
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
  }) {
    final slideAnimation = Tween<Offset>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));

    return SlideTransition(
      position: slideAnimation,
      child: child,
    );
  }

  /// رسم متحرك للتلاشي
  static Widget buildFadeTransition({
    required AnimationController controller,
    required Widget child,
  }) {
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));

    return FadeTransition(
      opacity: fadeAnimation,
      child: child,
    );
  }

  /// رسم متحرك للتوهج
  static Widget buildGlowAnimation({
    required AnimationController controller,
    required Widget child,
    Color? glowColor,
  }) {
    final glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: (glowColor ?? AccountantThemeConfig.primaryGreen)
                    .withOpacity(glowAnimation.value * 0.5),
                blurRadius: 20 * glowAnimation.value,
                spreadRadius: 5 * glowAnimation.value,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

/// رسام خط المسح
class ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  ScanLinePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final gradient = LinearGradient(
      colors: [
        Colors.transparent,
        color,
        Colors.transparent,
      ],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, 3);
    paint.shader = gradient.createShader(rect);

    final y = size.height * progress;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// رسام تأثير الانفجار
class ExplosionPainter extends CustomPainter {
  final double progress;
  final Color color;

  ExplosionPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    
    final paint = Paint()
      ..color = color.withOpacity(1 - progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // رسم دوائر متوسعة
    for (int i = 0; i < 3; i++) {
      final radius = maxRadius * progress * (1 + i * 0.3);
      canvas.drawCircle(center, radius, paint);
    }

    // رسم نقاط متطايرة
    final particlePaint = Paint()
      ..color = color.withOpacity(1 - progress)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * (3.14159 / 180);
      final distance = maxRadius * progress * 1.5;
      final x = center.dx + distance * cos(angle);
      final y = center.dy + distance * sin(angle);
      
      canvas.drawCircle(
        Offset(x, y),
        3 * (1 - progress),
        particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// دالة مساعدة لحساب الجيب التمام
double cos(double radians) {
  return radians.cos();
}

/// دالة مساعدة لحساب الجيب
double sin(double radians) {
  return radians.sin();
}

/// امتداد للأرقام لحساب الجيب والجيب التمام
extension MathExtension on double {
  double cos() {
    return dart_math.cos(this);
  }
  
  double sin() {
    return dart_math.sin(this);
  }
}
