import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import 'package:smartbiztracker_new/screens/transition_screen.dart';
import 'dart:developer' as developer;

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isVideoInitialized = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeVideoPlayer();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _videoController = VideoPlayerController.asset('assets/videos/chandelier_video.mp4');

      await _videoController.initialize();
      _videoController.setLooping(false);
      _videoController.setVolume(0.0);

      _videoController.addListener(_checkVideoCompletion);

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });

        _videoController.play();
      }
    } catch (e) {
      developer.log('Error loading video: $e', name: 'WelcomeScreen');
      // If video fails to load, navigate to transition screen after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _navigateToTransitionScreen();
        }
      });
    }
  }

  void _checkVideoCompletion() {
    if (_videoController.value.position >= _videoController.value.duration) {
      _navigateToTransitionScreen();
    }
  }

  void _navigateToTransitionScreen() {
    if (_isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    // Fade out animation before navigation
    _fadeController.reverse().then((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const TransitionScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _videoController.removeListener(_checkVideoCompletion);
    _videoController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Stack(
              children: [
                // Video background or fallback image
                if (_isVideoInitialized)
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController.value.size.width,
                        height: _videoController.value.size.height,
                        child: VideoPlayer(_videoController),
                      ),
                    ),
                  )
                else
                  // Fallback background with professional gradient
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1565C0),
                            Color(0xFF0D47A1),
                            Color(0xFF01579B),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Animated background pattern
                          Positioned.fill(
                            child: CustomPaint(
                              painter: BackgroundPatternPainter(),
                            ),
                          ),
                          // Sama logo overlay
                          Center(
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage('assets/images/sama.png'),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Dark overlay for better contrast
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),

                // Professional Skip button
                Positioned(
                  top: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isNavigating ? null : _navigateToTransitionScreen,
                          borderRadius: BorderRadius.circular(25),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'تخطي',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 1000.ms).slideX(begin: 0.3),

                // Welcome content overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Brand logo
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.white,
                              size: 40,
                            ),
                          ).animate().scale(delay: 500.ms),

                          const SizedBox(height: 32),

                          // Welcome text
                          Text(
                            'مرحباً بك في',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 20,
                              fontWeight: FontWeight.w300,
                              fontFamily: 'Cairo',
                            ),
                          ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3),

                          const SizedBox(height: 8),

                          // Brand name with gradient
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.blue.shade200,
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'SAMA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                                letterSpacing: 3,
                              ),
                            ),
                          ).animate().fadeIn(delay: 1200.ms).scale(begin: const Offset(0.8, 0.8)),

                          const SizedBox(height: 12),

                          // Subtitle
                          Text(
                            'نظام إدارة المخزون الذكي',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Cairo',
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 1600.ms).slideY(begin: 0.3),

                          const SizedBox(height: 8),

                          // Description
                          Text(
                            'حلول متقدمة لإدارة المخزون والمبيعات',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              fontFamily: 'Cairo',
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 2000.ms).slideY(begin: 0.3),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Custom painter for background pattern
class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    // Draw geometric pattern
    for (int i = 0; i < 20; i++) {
      for (int j = 0; j < 20; j++) {
        final x = (size.width / 20) * i;
        final y = (size.height / 20) * j;

        if ((i + j) % 3 == 0) {
          canvas.drawCircle(
            Offset(x, y),
            2,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}