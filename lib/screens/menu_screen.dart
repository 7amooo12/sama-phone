import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/screens/auth/login_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToStore(BuildContext context) {
    // Navigate to store/browse functionality
    Navigator.pushNamed(context, '/sama-store');
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return PopScope(
      canPop: false, // Prevent back navigation from menu screen
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0A0A), // Professional luxurious black
                Color(0xFF1A1A2E), // Darkened blue-black
                Color(0xFF16213E), // Deep blue-black
                Color(0xFF0F0F23), // Rich dark blue
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  // Main content area
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Header section with title and subtitle
                          _buildHeaderSection(screenSize),

                          const SizedBox(height: 80),

                          // Professional action cards
                          _buildActionCards(context, screenSize),
                        ],
                      ),
                    ),
                  ),

                  // Footer section
                  _buildFooter(),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(Size screenSize) {
    return Column(
      children: [
        // Main title with professional Arabic typography
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.blue.shade200,
              Colors.white,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: Text(
            'اختر وجهتك',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: screenSize.width > 600 ? 48 : 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 3.0,
              height: 1.1,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.9),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                Shadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
                Shadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 40),

        // Elegant decorative line
        Container(
          width: screenSize.width * 0.6,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(0.6),
                Colors.blue.withOpacity(0.8),
                Colors.white.withOpacity(0.6),
                Colors.transparent,
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Subtitle with professional styling
        Text(
          'Professional Business Solutions',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w300,
            color: Colors.white.withOpacity(0.8),
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCards(BuildContext context, Size screenSize) {
    return Column(
      children: [
        // Store Browse Card with neon blue glow
        _buildProfessionalCard(
          context: context,
          title: 'تصفح المتجر',
          icon: Icons.store_outlined,
          onTap: () => _navigateToStore(context),
          glowColor: Colors.blue,
          accentColor: Colors.blue.shade400,
        ),

        const SizedBox(height: 24),

        // Login Card with neon green glow
        _buildProfessionalCard(
          context: context,
          title: 'تسجيل الدخول',
          icon: Icons.login_outlined,
          onTap: () => _navigateToLogin(context),
          glowColor: const Color(0xFF4CAF50),
          accentColor: const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  Widget _buildProfessionalCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Color glowColor,
    required Color accentColor,
  }) {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: glowColor.withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: glowColor.withOpacity(0.1),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Icon container with accent color
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 20),

                // Title text with premium Arabic typography
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                // Arrow indicator
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'تطوير شركة سما للتكنولوجيا',
          style: GoogleFonts.cairo(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Holographic particle class
class HolographicParticle {
  HolographicParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.velocity,
    this.alpha = 1.0,
  });

  double x;
  double y;
  double size;
  Color color;
  Offset velocity;
  double alpha;

  // Position getter for compatibility
  Offset get position => Offset(x, y);

  void update() {
    x += velocity.dx;
    y += velocity.dy;

    // Update alpha for fade effect
    alpha = (alpha * 0.99).clamp(0.0, 1.0);
  }
}

// Holographic particle painter
class HolographicParticlePainter extends CustomPainter {

  HolographicParticlePainter(this.particles);
  final List<HolographicParticle> particles;

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