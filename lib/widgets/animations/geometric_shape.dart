import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

/// Animated geometric shape widget with glassmorphism effect
/// Similar to the React ElegantShape component
class GeometricShape extends StatefulWidget {

  const GeometricShape({
    super.key,
    required this.width,
    required this.height,
    required this.rotation,
    required this.gradientColors,
    required this.position,
    this.animationDelay = Duration.zero,
    this.floatingDuration = const Duration(seconds: 12),
  });
  final double width;
  final double height;
  final double rotation;
  final List<Color> gradientColors;
  final Alignment position;
  final Duration animationDelay;
  final Duration floatingDuration;

  @override
  State<GeometricShape> createState() => _GeometricShapeState();
}

class _GeometricShapeState extends State<GeometricShape>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _floatingController;
  
  late Animation<double> _entranceOpacity;
  late Animation<double> _entranceScale;
  late Animation<Offset> _entranceSlide;
  late Animation<double> _entranceRotation;
  late Animation<double> _floatingOffset;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    // Entrance animation controller
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Floating animation controller
    _floatingController = AnimationController(
      duration: widget.floatingDuration,
      vsync: this,
    );

    // Entrance animations
    _entranceOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _entranceScale = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
    ));

    _entranceRotation = Tween<double>(
      begin: widget.rotation + (math.pi / 2), // Start rotated 90 degrees more
      end: widget.rotation,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
    ));

    // Floating animation
    _floatingOffset = Tween<double>(
      begin: -20.0,
      end: 20.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _startAnimations() async {
    // Wait for the delay before starting entrance animation
    await Future.delayed(widget.animationDelay);
    
    if (mounted) {
      _entranceController.forward();
      
      // Start floating animation after entrance completes
      _entranceController.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _floatingController.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _entranceOpacity,
        _entranceScale,
        _entranceSlide,
        _entranceRotation,
        _floatingOffset,
      ]),
      builder: (context, child) {
        return Positioned(
          left: widget.position == Alignment.centerLeft || 
                widget.position == Alignment.topLeft || 
                widget.position == Alignment.bottomLeft 
                ? 50 : null,
          right: widget.position == Alignment.centerRight || 
                 widget.position == Alignment.topRight || 
                 widget.position == Alignment.bottomRight 
                 ? 50 : null,
          top: widget.position == Alignment.topLeft || 
               widget.position == Alignment.topRight || 
               widget.position == Alignment.topCenter 
               ? 100 + _floatingOffset.value : null,
          bottom: widget.position == Alignment.bottomLeft || 
                  widget.position == Alignment.bottomRight || 
                  widget.position == Alignment.bottomCenter 
                  ? 150 + _floatingOffset.value : null,
          child: Opacity(
            opacity: _entranceOpacity.value,
            child: Transform.scale(
              scale: _entranceScale.value,
              child: Transform.translate(
                offset: Offset(
                  _entranceSlide.value.dx * 100,
                  _entranceSlide.value.dy * 100,
                ),
                child: Transform.rotate(
                  angle: _entranceRotation.value,
                  child: Container(
                    width: widget.width,
                    height: widget.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.elliptical(
                        widget.width / 2,
                        widget.height / 2,
                      )),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.gradientColors.map((color) => 
                          color.withOpacity(0.3)).toList(),
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.gradientColors.first.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: widget.gradientColors.last.withOpacity(0.1),
                          blurRadius: 40,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.elliptical(
                        widget.width / 2,
                        widget.height / 2,
                      )),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.1),
                                Colors.white.withOpacity(0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
