import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';

/// بطاقة متحركة احترافية
/// توفر هذه البطاقة تأثيرات حركية متعددة وخيارات تخصيص متقدمة
class AnimatedCard extends StatefulWidget {

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.all(0),
    this.borderRadius,
    this.backgroundColor,
    this.boxShadow,
    this.width,
    this.height,
    this.enablePressAnimation = true,
    this.enableHoverAnimation = true,
    this.enableShadowAnimation = true,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeInOut,
    this.gradient,
    this.border,
    this.image,
    this.splashColor,
    this.highlightColor,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final bool enablePressAnimation;
  final bool enableHoverAnimation;
  final bool enableShadowAnimation;
  final Duration animationDuration;
  final Curve animationCurve;
  final Gradient? gradient;
  final Border? border;
  final DecorationImage? image;
  final Color? splashColor;
  final Color? highlightColor;

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enablePressAnimation && widget.onTap != null) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.enablePressAnimation && widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.enablePressAnimation && widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultBorderRadius = widget.borderRadius ?? StyleSystem.borderRadiusLarge;
    final defaultBoxShadow = widget.boxShadow ?? (_isHovered && widget.enableShadowAnimation
        ? StyleSystem.shadowMedium
        : StyleSystem.shadowSmall);
    final defaultBackgroundColor = widget.backgroundColor ?? theme.cardColor;

    return MouseRegion(
      onEnter: widget.enableHoverAnimation ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.enableHoverAnimation ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.enablePressAnimation ? _scaleAnimation.value : 1.0,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: widget.animationDuration,
            curve: widget.animationCurve,
            width: widget.width,
            height: widget.height,
            margin: widget.margin,
            decoration: BoxDecoration(
              color: widget.gradient != null ? null : defaultBackgroundColor,
              borderRadius: defaultBorderRadius,
              boxShadow: defaultBoxShadow,
              gradient: widget.gradient,
              border: widget.border,
              image: widget.image,
            ),
            child: ClipRRect(
              borderRadius: defaultBorderRadius,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  splashColor: widget.splashColor ?? theme.splashColor,
                  highlightColor: widget.highlightColor ?? theme.highlightColor,
                  onTap: widget.onTap != null ? () {} : null,
                  borderRadius: defaultBorderRadius,
                  child: Padding(
                    padding: widget.padding,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة متحركة مع تأثير تدرج لوني
class GradientAnimatedCard extends StatelessWidget {

  const GradientAnimatedCard({
    super.key,
    required this.child,
    required this.gradientColors,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.all(0),
    this.borderRadius,
    this.boxShadow,
    this.width,
    this.height,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });
  final Widget child;
  final VoidCallback? onTap;
  final List<Color> gradientColors;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  @override
  Widget build(BuildContext context) {
    return AnimatedCard(
      onTap: onTap,
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
      width: width,
      height: height,
      gradient: LinearGradient(
        colors: gradientColors,
        begin: begin,
        end: end,
      ),
      child: child,
    );
  }
}

/// بطاقة متحركة مع تأثير نبض
class PulsingAnimatedCard extends StatelessWidget {

  const PulsingAnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.all(0),
    this.borderRadius,
    this.backgroundColor,
    this.boxShadow,
    this.width,
    this.height,
    this.pulseDuration = const Duration(milliseconds: 1500),
    this.minScale = 1.0,
    this.maxScale = 1.03,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final Duration pulseDuration;
  final double minScale;
  final double maxScale;

  @override
  Widget build(BuildContext context) {
    return AnimationSystem.pulse(
      AnimatedCard(
        onTap: onTap,
        padding: padding,
        margin: margin,
        borderRadius: borderRadius,
        backgroundColor: backgroundColor,
        boxShadow: boxShadow,
        width: width,
        height: height,
        enablePressAnimation: false,
        child: child,
      ),
      duration: pulseDuration,
      minScale: minScale,
      maxScale: maxScale,
    );
  }
}

/// بطاقة متحركة مع تأثير ظهور
class FadeInAnimatedCard extends StatelessWidget {

  const FadeInAnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.all(0),
    this.borderRadius,
    this.backgroundColor,
    this.boxShadow,
    this.width,
    this.height,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.curve = Curves.easeOut,
    this.offset = const Offset(0, 50),
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return AnimationSystem.fadeSlideInWithDelay(
      AnimatedCard(
        onTap: onTap,
        padding: padding,
        margin: margin,
        borderRadius: borderRadius,
        backgroundColor: backgroundColor,
        boxShadow: boxShadow,
        width: width,
        height: height,
        child: child,
      ),
      delay: delay,
      duration: duration,
      curve: curve,
      offset: offset,
    );
  }
}
