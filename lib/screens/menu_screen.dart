import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/screens/auth/login_screen.dart';
import 'package:smartbiztracker_new/screens/auth/register_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleSystem.backgroundDark,
      body: SafeArea(
        child: Stack(
          children: [
            // Background pattern
            CustomPaint(
              painter: CircuitPatternPainter(),
              size: Size.infinite,
            ),
            
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo or Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 80,
                        height: 80,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.store,
                            size: 60,
                            color: StyleSystem.primaryColor,
                          );
                        },
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).scale(),
                  
                  const SizedBox(height: 40),
                  
                  // Welcome Text
                  Text(
                    'مرحباً بك في تطبيقنا',
                    style: TextStyle(
                      color: StyleSystem.primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
                  
                  const SizedBox(height: 60),
                  
                  // Login Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StyleSystem.primaryColor,
                        foregroundColor: StyleSystem.backgroundLight,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideX(),
                  
                  const SizedBox(height: 20),
                  
                  // Register Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: StyleSystem.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(color: StyleSystem.primaryColor, width: 2),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'إنشاء حساب جديد',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideX(begin: -0.2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Circuit pattern painter
class CircuitPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // Fixed seed for consistent pattern
    final paint = Paint()
      ..color = const Color(0xFF00FFFF).withOpacity(0.1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    const int lineCount = 20;
    
    for (int i = 0; i < lineCount; i++) {
      final path = Path();
      
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      
      path.moveTo(startX, startY);
      
      final segmentCount = 3 + random.nextInt(5);
      
      for (int j = 0; j < segmentCount; j++) {
        final directionChoice = random.nextInt(2);
        final length = 20.0 + random.nextInt(50);
        
        if (directionChoice == 0) {
          path.relativeLineTo(length, 0);
        } else {
          path.relativeLineTo(0, length);
        }
        
        final metrics = path.computeMetrics().last;
        final currentPoint = metrics.getTangentForOffset(metrics.length)?.position ?? const Offset(0, 0);
        canvas.drawCircle(
          currentPoint, 
          2.0, 
          Paint()
            ..color = const Color(0xFF00FFFF).withOpacity(0.3)
            ..style = PaintingStyle.fill
        );
      }
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Grid pattern painter
class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    const double spacing = 30.0;
    
    // Draw horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    
    // Draw vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Holographic particle
class HolographicParticle {
  Offset position;
  Offset velocity;
  double size;
  double alpha;
  Color color;
  
  HolographicParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.alpha,
    required this.color,
  });
  
  factory HolographicParticle.random(Random random) {
    final List<Color> colors = [
      const Color(0xFF00FFFF), // Cyan
      const Color(0xFFFF00FF), // Magenta
      const Color(0xFF2E5CFF), // Blue
      Colors.white,
    ];
    
    return HolographicParticle(
      position: Offset(
        random.nextDouble() * 500,
        random.nextDouble() * 800,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 0.5,
        -0.5 - random.nextDouble() * 1.5,
      ),
      size: random.nextDouble() * 3 + 1,
      alpha: random.nextDouble() * 0.6 + 0.2,
      color: colors[random.nextInt(colors.length)],
    );
  }
  
  void update() {
    position = position + velocity;
    alpha -= 0.005;
  }
  
  void reset(Random random) {
    position = Offset(
      random.nextDouble() * 500,
      random.nextDouble() * 100 + 700, // Start from bottom
    );
    velocity = Offset(
      (random.nextDouble() - 0.5) * 0.5,
      -0.5 - random.nextDouble() * 1.5,
    );
    size = random.nextDouble() * 3 + 1;
    alpha = random.nextDouble() * 0.6 + 0.2;
    
    final List<Color> colors = [
      const Color(0xFF00FFFF), // Cyan
      const Color(0xFFFF00FF), // Magenta 
      const Color(0xFF2E5CFF), // Blue
      Colors.white,
    ];
    color = colors[random.nextInt(colors.length)];
  }
}

// Holographic particle painter
class HolographicParticlePainter extends CustomPainter {
  final List<HolographicParticle> particles;
  
  HolographicParticlePainter(this.particles);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.alpha)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(particle.position.dx, particle.position.dy), 
        particle.size, 
        paint,
      );
      
      // Glow effect
      canvas.drawCircle(
        Offset(particle.position.dx, particle.position.dy), 
        particle.size * 2, 
        Paint()
          ..color = particle.color.withOpacity(particle.alpha * 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
} 