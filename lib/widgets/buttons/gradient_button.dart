import 'package:flutter/material.dart';
import 'dart:math' as math;

/// GradientButton widget that replicates the React GradientButton component
/// with animated radial gradients and border effects
class GradientButton extends StatefulWidget {

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height,
    this.textStyle,
    this.padding,
    this.borderRadius,
    this.isVariant = false,
    this.icon,
  });
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool isVariant;
  final Widget? icon;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _borderController;
  
  late Animation<double> _gradientPositionX;
  late Animation<double> _gradientPositionY;
  late Animation<double> _gradientSpreadX;
  late Animation<double> _gradientSpreadY;
  late Animation<double> _borderAngle;
  
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Hover/press animation controller
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Border rotation animation controller
    _borderController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Gradient position animations
    _gradientPositionX = Tween<double>(
      begin: 0.1114, // 11.14%
      end: 0.0,      // 0%
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOut,
    ));

    _gradientPositionY = Tween<double>(
      begin: 1.4,    // 140%
      end: 0.9151,   // 91.51%
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOut,
    ));

    // Gradient spread animations
    _gradientSpreadX = Tween<double>(
      begin: 1.5,    // 150%
      end: 1.2024,   // 120.24%
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOut,
    ));

    _gradientSpreadY = Tween<double>(
      begin: 1.8006, // 180.06%
      end: 1.0318,   // 103.18%
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOut,
    ));

    // Border angle animation
    _borderAngle = Tween<double>(
      begin: 20 * math.pi / 180,  // 20deg
      end: 190 * math.pi / 180,   // 190deg
    ).animate(CurvedAnimation(
      parent: _borderController,
      curve: Curves.easeInOut,
    ));
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _hoverController.forward();
    _borderController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _hoverController.reverse();
    _borderController.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _hoverController.reverse();
    _borderController.reverse();
  }

  List<Color> _getDefaultGradientColors() {
    if (_isPressed) {
      // Hover state colors with better blending
      return [
        const Color(0xFF000000),
        const Color(0xFFc96287),
        const Color(0xFFc66c64),
        const Color(0xFFcc7d23),
        const Color(0xFF37140a),
        const Color(0xFF000000),
      ];
    } else {
      // Default state colors
      return [
        const Color(0xFF000000),
        const Color(0xFF08012c),
        const Color(0xFF4e1e40),
        const Color(0xFF70464e),
        const Color(0xFF88394c),
        const Color(0xFF000000),
      ];
    }
  }

  List<Color> _getVariantGradientColors() {
    if (_isPressed) {
      // Variant hover state colors with better blending (6 colors to match 6 stops)
      return [
        const Color(0xFF000022),
        const Color(0xFF469396),
        const Color(0xFF1f3f6d),
        const Color(0xFFf1ffa5),
        const Color(0xFF2a5a5c), // Added intermediate color for smooth transition
        const Color(0xFF000000),
      ];
    } else {
      // Variant default state colors (6 colors to match 6 stops)
      return [
        const Color(0xFF000022),
        const Color(0xFF1f3f6d),
        const Color(0xFF469396),
        const Color(0xFFf1ffa5),
        const Color(0xFF3a4a2c), // Added intermediate color for smooth transition
        const Color(0xFF000000),
      ];
    }
  }

  Color _getBorderColor() {
    // hsla(340, 75%, 60%, 0.2) to hsla(340, 75%, 40%, 0.75)
    if (_isPressed) {
      return const HSLColor.fromAHSL(0.75, 340, 0.75, 0.40).toColor();
    } else {
      return const HSLColor.fromAHSL(0.2, 340, 0.75, 0.60).toColor();
    }
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _gradientPositionX,
        _gradientPositionY,
        _gradientSpreadX,
        _gradientSpreadY,
        _borderAngle,
      ]),
      builder: (context, child) {
        return GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: SizedBox(
            width: widget.width ?? 132,
            height: widget.height ?? 56,
            child: Stack(
              children: [
                // Animated border layer
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius ?? BorderRadius.circular(11),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      transform: GradientRotation(_borderAngle.value),
                      colors: [
                        _getBorderColor(),
                        _getBorderColor().withOpacity(0.1),
                        _getBorderColor(),
                      ],
                    ),
                  ),
                ),
                
                // Main button container with animated radial gradient
                Container(
                  margin: const EdgeInsets.all(1), // Border width
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius ?? BorderRadius.circular(11),
                    gradient: RadialGradient(
                      center: Alignment(
                        _gradientPositionX.value * 2 - 1, // Convert to -1 to 1 range
                        _gradientPositionY.value * 2 - 1,
                      ),
                      radius: math.max(_gradientSpreadX.value, _gradientSpreadY.value) * 0.8,
                      colors: widget.isVariant
                          ? _getVariantGradientColors()
                          : _getDefaultGradientColors(),
                      stops: _isPressed
                          ? [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
                          : [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                      if (_isPressed)
                        BoxShadow(
                          color: widget.isVariant
                              ? const Color(0xFF469396).withOpacity(0.3)
                              : const Color(0xFFc96287).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 0),
                        ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onPressed,
                      borderRadius: widget.borderRadius ?? BorderRadius.circular(11),
                      child: Container(
                        padding: widget.padding ?? const EdgeInsets.symmetric(
                          horizontal: 36, // px-9
                          vertical: 16,   // py-4
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              widget.icon!,
                              const SizedBox(width: 12),
                            ],
                            Text(
                              widget.text,
                              style: widget.textStyle ?? const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
