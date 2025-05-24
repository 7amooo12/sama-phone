import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:smartbiztracker_new/utils/app_constants.dart';

/// أنواع الرسوم المتحركة
enum AnimationType {
  none,
  fadeIn,
  fadeSlideFromBottom,
  fadeSlideFromTop,
  fadeSlideFromRight,
  fadeSlideFromLeft,
  scale,
}

/// نظام الرسوم المتحركة الموحد للتطبيق
/// يوفر هذا الملف مجموعة من الثوابت والدوال المساعدة للرسوم المتحركة
class AnimationSystem {
  // مدة الرسوم المتحركة
  static const ultraFast = Duration(milliseconds: 150);
  static const fast = Duration(milliseconds: 300);
  static const medium = Duration(milliseconds: 500);
  static const slow = Duration(milliseconds: 800);
  static const extraSlow = Duration(milliseconds: 1200);

  // منحنيات الرسوم المتحركة
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeIn = Curves.easeIn;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve bounceOut = Curves.bounceOut;
  static const Curve decelerate = Curves.decelerate;

  // قيم الإزاحة للرسوم المتحركة
  static const Offset rightToLeftOffset = Offset(50, 0);
  static const Offset leftToRightOffset = Offset(-50, 0);
  static const Offset bottomToTopOffset = Offset(0, 50);
  static const Offset topToBottomOffset = Offset(0, -50);
  static const Offset smallBottomToTopOffset = Offset(0, 20);

  // قيم التأخير للرسوم المتحركة المتتالية
  static const Duration noDelay = Duration.zero;
  static const Duration shortDelay = Duration(milliseconds: 50);
  static const Duration mediumDelay = Duration(milliseconds: 100);
  static const Duration longDelay = Duration(milliseconds: 200);

  // حساب تأخير الرسوم المتحركة المتتالية
  static Duration staggeredDelay(int index, {Duration base = shortDelay}) {
    return Duration(milliseconds: base.inMilliseconds * index);
  }

  // دالة لإنشاء منحنى مخصص للرسوم المتحركة
  static Curve customSpringCurve({double a = 0.1, double w = 19.4}) {
    return SpringCurve(a: a, w: w);
  }

  // دالة لإنشاء تأثير ظهور متدرج
  static Widget fadeInWithDelay(
    Widget child, {
    Duration delay = Duration.zero,
    Duration duration = medium,
    Curve curve = easeOut,
  }) {
    return _DelayedAnimation(
      delay: delay,
      duration: duration,
      curve: curve,
      builder: (context, controller) {
        return FadeTransition(
          opacity: controller,
          child: child,
        );
      },
    );
  }

  // دالة لإنشاء تأثير ظهور مع حركة
  static Widget fadeSlideInWithDelay(
    Widget child, {
    Duration delay = Duration.zero,
    Duration duration = medium,
    Curve curve = easeOut,
    Offset offset = bottomToTopOffset,
  }) {
    return _DelayedAnimation(
      delay: delay,
      duration: duration,
      curve: curve,
      builder: (context, controller) {
        return FadeTransition(
          opacity: controller,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: offset,
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: controller,
              curve: curve,
            )),
            child: child,
          ),
        );
      },
    );
  }

  // دالة لإنشاء تأثير نبض
  static Widget pulse(
    Widget child, {
    Duration duration = slow,
    double minScale = 1.0,
    double maxScale = 1.05,
    bool repeat = true,
  }) {
    return _PulseAnimation(
      duration: duration,
      minScale: minScale,
      maxScale: maxScale,
      repeat: repeat,
      child: child,
    );
  }

  // دالة لإنشاء تأثير وميض
  static Widget shimmer(
    Widget child, {
    Color? baseColor,
    Color? highlightColor,
    Duration duration = slow,
  }) {
    return _ShimmerEffect(
      baseColor: baseColor,
      highlightColor: highlightColor,
      duration: duration,
      child: child,
    );
  }

  // دالة لإنشاء قائمة متحركة متدرجة
  static List<Widget> staggeredListAnimation(
    List<Widget> children, {
    double intervalStart = 0.0,
    double intervalStep = 0.05,
  }) {
    // إرجاع نفس قائمة الـ widgets دون تغيير
    // يمكن تحسين هذه الطريقة لاحقًا لإضافة رسوم متحركة حقيقية
    return children;
  }
}

// منحنى مخصص للرسوم المتحركة
class SpringCurve extends Curve {
  final double a;
  final double w;

  const SpringCurve({this.a = 0.1, this.w = 19.4});

  @override
  double transformInternal(double t) {
    return -(math.pow(math.e, -t / a) * math.cos(t * w)) + 1;
  }
}

// ويدجت للرسوم المتحركة المتأخرة
class _DelayedAnimation extends StatefulWidget {
  final Widget Function(BuildContext, Animation<double>) builder;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  const _DelayedAnimation({
    required this.builder,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOut,
  });

  @override
  State<_DelayedAnimation> createState() => _DelayedAnimationState();
}

class _DelayedAnimationState extends State<_DelayedAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ),
    );
  }
}

// ويدجت لتأثير النبض
class _PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final bool repeat;

  const _PulseAnimation({
    required this.child,
    this.duration = const Duration(milliseconds: 800),
    this.minScale = 1.0,
    this.maxScale = 1.05,
    this.repeat = true,
  });

  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.repeat) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ويدجت لتأثير الوميض
class _ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const _ShimmerEffect({
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.baseColor ?? theme.colorScheme.surface;
    final highlightColor = widget.highlightColor ?? theme.colorScheme.primary.withOpacity(0.2);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// تحويل التدرج المتحرك
class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({
    required this.slidePercent,
  });

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 3 - 1),
      0.0,
      0.0,
    );
  }
}
