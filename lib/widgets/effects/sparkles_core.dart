import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Custom Particle class for sparkle effects
class Particle {

  Particle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    this.opacity = 1.0,
  });
  Offset position;
  Offset velocity;
  final double size;
  final Color color;
  double opacity;

  void update(Size canvasSize) {
    position += velocity;

    // Wrap around screen edges
    if (position.dx < 0) position = Offset(canvasSize.width, position.dy);
    if (position.dx > canvasSize.width) position = Offset(0, position.dy);
    if (position.dy < 0) position = Offset(position.dx, canvasSize.height);
    if (position.dy > canvasSize.height) position = Offset(position.dx, 0);
  }
}

/// Custom painter for particle effects
class ParticlePainter extends CustomPainter {

  ParticlePainter({
    required this.particles,
    required this.animationValue,
  });
  final List<Particle> particles;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      particle.update(size);

      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity * animationValue)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        particle.position,
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// SparklesCore widget that creates animated white particles on black background
/// Similar to the React SparklesCore component
class SparklesCore extends StatefulWidget {

  const SparklesCore({
    super.key,
    this.id,
    this.background,
    this.minSize,
    this.maxSize,
    this.speed,
    this.particleColor,
    this.particleDensity,
    this.child,
  });
  final String? id;
  final Color? background;
  final double? minSize;
  final double? maxSize;
  final double? speed;
  final Color? particleColor;
  final int? particleDensity;
  final Widget? child;

  @override
  State<SparklesCore> createState() => _SparklesCoreState();
}

class _SparklesCoreState extends State<SparklesCore>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _particleController;
  late Animation<double> _opacityAnimation;
  List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 16), // ~60 FPS
      vsync: this,
    );

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    // Start animations
    _controller.forward();
    _particleController.repeat();

    // Initialize particles after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      _particles = _generateParticles(size);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _particleController.dispose();
    super.dispose();
  }

  List<Particle> _generateParticles(Size size) {
    final random = math.Random();
    final particleCount = widget.particleDensity ?? 120;
    final particles = <Particle>[];

    for (int i = 0; i < particleCount; i++) {
      particles.add(
        Particle(
          position: Offset(
            random.nextDouble() * size.width,
            random.nextDouble() * size.height,
          ),
          velocity: Offset(
            (random.nextDouble() - 0.5) * (widget.speed ?? 1.0),
            (random.nextDouble() - 0.5) * (widget.speed ?? 1.0),
          ),
          size: (widget.minSize ?? 0.4) +
                random.nextDouble() * ((widget.maxSize ?? 1.0) - (widget.minSize ?? 0.4)),
          color: widget.particleColor ?? Colors.white,
          opacity: 0.5 + random.nextDouble() * 0.5,
        ),
      );
    }

    return particles;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_opacityAnimation, _particleController]),
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: widget.background ?? Colors.black,
            child: Stack(
              children: [
                // Particle background
                if (_particles.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ParticlePainter(
                        particles: _particles,
                        animationValue: _opacityAnimation.value,
                      ),
                    ),
                  ),
                // Child content overlay
                if (widget.child != null)
                  Positioned.fill(
                    child: widget.child!,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Enhanced SparklesCore with gradient effects similar to React version
class SparklesCoreWithGradients extends StatelessWidget {

  const SparklesCoreWithGradients({
    super.key,
    required this.child,
    this.background,
    this.minSize,
    this.maxSize,
    this.speed,
    this.particleColor,
    this.particleDensity,
  });
  final Widget child;
  final Color? background;
  final double? minSize;
  final double? maxSize;
  final double? speed;
  final Color? particleColor;
  final int? particleDensity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: background ?? Colors.black,
      child: Stack(
        children: [
          // Sparkles background
          SparklesCore(
            background: Colors.transparent,
            minSize: minSize ?? 0.4,
            maxSize: maxSize ?? 1.0,
            particleDensity: particleDensity ?? 1200,
            particleColor: particleColor ?? Colors.white,
            speed: speed ?? 1.0,
          ),
          
          // Gradient effects similar to React version
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 80),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.indigo.shade500,
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          
          // Secondary gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 240),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.lightBlue.shade500,
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          
          // Radial gradient mask to prevent sharp edges
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    background ?? Colors.black,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
            ),
          ),
          
          // Child content
          Positioned.fill(
            child: child,
          ),
        ],
      ),
    );
  }
}
