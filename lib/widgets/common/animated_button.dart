import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';

/// زر متحرك احترافي
/// يوفر هذا الزر تأثيرات حركية متعددة وخيارات تخصيص متقدمة
class AnimatedButton extends StatefulWidget {
  
  const AnimatedButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.onLongPress,
    this.style,
    this.isLoading = false,
    this.isDisabled = false,
    this.showShadow = true,
    this.enablePressAnimation = true,
    this.enableHoverAnimation = true,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeInOut,
    this.loadingWidget,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.splashColor,
    this.highlightColor,
    this.elevation = 0,
    this.hoverElevation = 2,
    this.pressedElevation = 0,
    this.disabledElevation = 0,
    this.side,
    this.textStyle,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.min,
  });
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ButtonStyle? style;
  final bool isLoading;
  final bool isDisabled;
  final bool showShadow;
  final bool enablePressAnimation;
  final bool enableHoverAnimation;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Duration animationDuration;
  final Curve animationCurve;
  final Widget? loadingWidget;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final Color? splashColor;
  final Color? highlightColor;
  final double elevation;
  final double hoverElevation;
  final double pressedElevation;
  final double disabledElevation;
  final BorderSide? side;
  final TextStyle? textStyle;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  
  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  bool _isPressed = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
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
    if (widget.enablePressAnimation && !widget.isDisabled && !widget.isLoading) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }
  
  void _handleTapUp(TapUpDetails details) {
    if (widget.enablePressAnimation && !widget.isDisabled && !widget.isLoading) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }
  
  void _handleTapCancel() {
    if (widget.enablePressAnimation && !widget.isDisabled && !widget.isLoading) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultBorderRadius = widget.borderRadius ?? StyleSystem.borderRadiusMedium;
    final defaultBackgroundColor = widget.backgroundColor ?? StyleSystem.primaryColor;
    final defaultForegroundColor = widget.foregroundColor ?? Colors.white;
    final defaultDisabledBackgroundColor = widget.disabledBackgroundColor ?? StyleSystem.neutralLight;
    final defaultDisabledForegroundColor = widget.disabledForegroundColor ?? StyleSystem.neutralMedium;
    
    final bool isEnabled = !widget.isDisabled && !widget.isLoading && widget.onPressed != null;
    
    final buttonStyle = widget.style ?? ElevatedButton.styleFrom(
      backgroundColor: isEnabled ? defaultBackgroundColor : defaultDisabledBackgroundColor,
      foregroundColor: isEnabled ? defaultForegroundColor : defaultDisabledForegroundColor,
      disabledBackgroundColor: defaultDisabledBackgroundColor,
      disabledForegroundColor: defaultDisabledForegroundColor,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: defaultBorderRadius,
        side: widget.side ?? BorderSide.none,
      ),
      elevation: widget.isDisabled 
          ? widget.disabledElevation 
          : (_isPressed 
              ? widget.pressedElevation 
              : (_isHovered ? widget.hoverElevation : widget.elevation)),
      shadowColor: widget.showShadow ? null : Colors.transparent,
      splashFactory: InkRipple.splashFactory,
      textStyle: widget.textStyle ?? StyleSystem.labelLarge,
    );
    
    return MouseRegion(
      onEnter: widget.enableHoverAnimation && isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.enableHoverAnimation && isEnabled ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.enablePressAnimation ? _scaleAnimation.value : 1.0,
              child: child,
            );
          },
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: ElevatedButton(
              onPressed: isEnabled ? widget.onPressed : null,
              onLongPress: isEnabled ? widget.onLongPress : null,
              style: buttonStyle,
              child: widget.isLoading
                  ? _buildLoadingWidget()
                  : _buildButtonContent(),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingWidget() {
    return widget.loadingWidget ?? SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          widget.foregroundColor ?? Colors.white,
        ),
      ),
    );
  }
  
  Widget _buildButtonContent() {
    return Row(
      mainAxisAlignment: widget.mainAxisAlignment,
      mainAxisSize: widget.mainAxisSize,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon),
          const SizedBox(width: 8),
        ],
        Text(widget.text),
      ],
    );
  }
}

/// زر متحرك مع تأثير تدرج لوني
class GradientAnimatedButton extends StatelessWidget {
  
  const GradientAnimatedButton({
    super.key,
    required this.text,
    required this.gradientColors,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.begin = Alignment.centerLeft,
    this.end = Alignment.centerRight,
    this.foregroundColor,
    this.textStyle,
  });
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<Color> gradientColors;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final Color? foregroundColor;
  final TextStyle? textStyle;
  
  @override
  Widget build(BuildContext context) {
    final defaultBorderRadius = borderRadius ?? StyleSystem.borderRadiusMedium;
    final defaultForegroundColor = foregroundColor ?? Colors.white;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: isDisabled
            ? null
            : LinearGradient(
                colors: gradientColors,
                begin: begin,
                end: end,
              ),
        borderRadius: defaultBorderRadius,
        color: isDisabled ? StyleSystem.neutralLight : null,
      ),
      child: AnimatedButton(
        text: text,
        icon: icon,
        onPressed: onPressed,
        isLoading: isLoading,
        isDisabled: isDisabled,
        width: width,
        height: height,
        padding: padding,
        borderRadius: defaultBorderRadius,
        foregroundColor: defaultForegroundColor,
        disabledForegroundColor: StyleSystem.neutralMedium,
        textStyle: textStyle,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: defaultForegroundColor,
          disabledForegroundColor: StyleSystem.neutralMedium,
          elevation: 0,
        ),
      ),
    );
  }
}

/// زر متحرك مع تأثير نبض
class PulsingAnimatedButton extends StatelessWidget {
  
  const PulsingAnimatedButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.pulseDuration = const Duration(milliseconds: 1500),
    this.minScale = 1.0,
    this.maxScale = 1.05,
  });
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Duration pulseDuration;
  final double minScale;
  final double maxScale;
  
  @override
  Widget build(BuildContext context) {
    return AnimationSystem.pulse(
      AnimatedButton(
        text: text,
        icon: icon,
        onPressed: onPressed,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        isLoading: isLoading,
        isDisabled: isDisabled,
        width: width,
        height: height,
        padding: padding,
        borderRadius: borderRadius,
        enablePressAnimation: false,
      ),
      duration: pulseDuration,
      minScale: minScale,
      maxScale: maxScale,
      repeat: !isDisabled && !isLoading,
    );
  }
}
