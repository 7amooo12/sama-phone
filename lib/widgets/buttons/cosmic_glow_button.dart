import 'package:flutter/material.dart';
import 'dart:math' as math;

/// CosmicGlowButton widget that creates a glowing animated button
/// Similar to the React CosmicGlowButton component with cosmic glow effects
class CosmicGlowButton extends StatefulWidget {

  const CosmicGlowButton({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height,
    this.textStyle,
    this.padding,
    this.borderRadius,
  });
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  @override
  State<CosmicGlowButton> createState() => _CosmicGlowButtonState();
}

class _CosmicGlowButtonState extends State<CosmicGlowButton>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _rotationController;
  late Animation<double> _glowScaleAnimation;
  late Animation<double> _glowOpacityAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    // Glow animation controller (scale and opacity)
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Rotation animation controller
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    );

    // Glow scale animation: 1.0 -> 1.15 -> 1.0
    _glowScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Glow opacity animation: 0.4 -> 0.7 -> 0.4
    _glowOpacityAnimation = Tween<double>(
      begin: 0.4,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Continuous rotation animation
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
  }

  void _startAnimations() {
    // Start glow animation (repeating)
    _glowController.repeat(reverse: true);
    
    // Start rotation animation (continuous)
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _glowScaleAnimation,
        _glowOpacityAnimation,
        _rotationAnimation,
      ]),
      builder: (context, child) {
        return GestureDetector(
          onTap: widget.onPressed,
          child: SizedBox(
            width: widget.width ?? 200,
            height: widget.height ?? 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background glow layer (radial gradient)
                Transform.scale(
                  scale: _glowScaleAnimation.value,
                  child: Container(
                    width: (widget.width ?? 200) + 20,
                    height: (widget.height ?? 56) + 20,
                    decoration: BoxDecoration(
                      borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
                      gradient: RadialGradient(
                        colors: [
                          Colors.blue.withOpacity(_glowOpacityAnimation.value * 0.6),
                          Colors.purple.withOpacity(_glowOpacityAnimation.value * 0.4),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),

                // Rotating conic gradient overlay
                Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Container(
                    width: widget.width ?? 200,
                    height: widget.height ?? 56,
                    decoration: BoxDecoration(
                      borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
                      gradient: SweepGradient(
                        colors: [
                          Colors.transparent,
                          Colors.blue.withOpacity(0.3),
                          Colors.purple.withOpacity(0.3),
                          Colors.cyan.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),

                // Main button container
                Container(
                  width: widget.width ?? 200,
                  height: widget.height ?? 56,
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF111827), // gray-900
                        Color(0xFF1F2937), // gray-800
                        Color(0xFF111827), // gray-900
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 40,
                        offset: const Offset(0, 0),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onPressed,
                      borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
                      child: Container(
                        padding: widget.padding ?? const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Center(
                          child: Text(
                            widget.text,
                            style: widget.textStyle ?? const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                            ),
                          ),
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
