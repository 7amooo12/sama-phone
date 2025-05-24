import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import 'package:smartbiztracker_new/screens/transition_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _videoController = VideoPlayerController.asset('assets/videos/chandelier_video.mp4');
      
      await _videoController.initialize();
      _videoController.setLooping(false);
      _videoController.setVolume(0.0);
      
      _videoController.addListener(_checkVideoCompletion);
      
      setState(() {
        _isVideoInitialized = true;
      });
      
      _videoController.play();
    } catch (e) {
      _navigateToTransitionScreen();
    }
  }
  
  void _checkVideoCompletion() {
    if (_videoController.value.position >= _videoController.value.duration) {
      _navigateToTransitionScreen();
    }
  }

  void _navigateToTransitionScreen() {
    Navigator.pushReplacement(
      context, 
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const TransitionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
            ),
          );
          
          return FadeTransition(
            opacity: fadeAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  void dispose() {
    _videoController.removeListener(_checkVideoCompletion);
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video background
          if (_isVideoInitialized)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoPlayer(_videoController),
              ),
            ),
          
          // Skip button
          Positioned(
            bottom: 20,
            right: 20,
            child: TextButton(
              onPressed: _navigateToTransitionScreen,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(
                    color: const Color(0xFFD4AF37).withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'تخطي',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.skip_next,
                    color: const Color(0xFFD4AF37),
                    size: 16,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 2000.ms),
        ],
      ),
    );
  }
} 