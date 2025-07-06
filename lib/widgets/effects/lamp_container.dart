import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui';

/// LampContainer widget that replicates the React LampDemo component
/// with animated lamp lighting effect and gradient text
class LampContainer extends StatefulWidget {

  const LampContainer({
    super.key,
    this.child,
    this.title = 'SAMA',
    this.animationDuration = const Duration(milliseconds: 800),
  });
  final Widget? child;
  final String title;
  final Duration animationDuration;

  @override
  State<LampContainer> createState() => _LampContainerState();
}

class _LampContainerState extends State<LampContainer>
    with TickerProviderStateMixin {
  late AnimationController _lampController;
  late AnimationController _rotationController;
  late AnimationController _titleController;
  
  late Animation<double> _lampWidthAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _titleOpacity;
  late Animation<double> _titleSlide;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    // Simplified lamp expansion animation controller
    _lampController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Slower rotation for better performance
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8), // Doubled duration for smoother performance
      vsync: this,
    );

    // Title animation controller
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 600), // Reduced duration
      vsync: this,
    );

    // Reduced lamp width expansion for better performance
    _lampWidthAnimation = Tween<double>(
      begin: 200.0, // Smaller initial size
      end: 320.0,   // Smaller final size
    ).animate(CurvedAnimation(
      parent: _lampController,
      curve: Curves.easeOut, // Simpler curve
    ));

    // Simplified rotation animation
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    // Title opacity animation
    _titleOpacity = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOut,
    ));

    // Reduced title slide animation
    _titleSlide = Tween<double>(
      begin: 50.0, // Reduced movement
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOut,
    ));
  }

  Future<void> _startAnimations() async {
    // Start lamp expansion
    _lampController.forward();
    
    // Start continuous rotation
    _rotationController.repeat();
    
    // Start title animation with 300ms delay
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _titleController.forward();
    }
  }

  @override
  void dispose() {
    _lampController.dispose();
    _rotationController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      height: 300,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0f172a), // bg-slate-950 equivalent
      ),
      child: Stack(
        children: [
          // First animated conic gradient (centered position) - Performance optimized
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _lampWidthAnimation,
              builder: (context, child) {
                return Positioned(
                  left: screenWidth * 0.5 - (_lampWidthAnimation.value / 2),
                  top: 50,
                  child: AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: Container(
                          width: _lampWidthAnimation.value,
                          height: _lampWidthAnimation.value,
                          decoration: BoxDecoration(
                            gradient: SweepGradient(
                              colors: [
                                Colors.cyan.shade400.withValues(alpha: 0.6), // Reduced opacity for performance
                                Colors.transparent,
                                Colors.cyan.shade400.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.3, 0.6, 1.0], // Adjusted stops
                            ),
                            shape: BoxShape.circle,
                          ),
                          // Removed BackdropFilter to fix overlay issue
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),



          // Animated title with gradient text effect
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_titleOpacity, _titleSlide]),
              builder: (context, child) {
                return Center(
                  child: Transform.translate(
                    offset: Offset(0, _titleSlide.value),
                    child: Opacity(
                      opacity: _titleOpacity.value,
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [
                              Color(0xFFcbd5e1), // slate-300
                              Color(0xFF64748b), // slate-500
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds);
                        },
                        child: Text(
                          widget.title,
                          style: GoogleFonts.oswald(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Child content overlay
          if (widget.child != null)
            Positioned.fill(
              child: widget.child!,
            ),
        ],
      ),
    );
  }
}
