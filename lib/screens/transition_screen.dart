import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/screens/menu_screen.dart';
import 'package:smartbiztracker_new/screens/about_us_screen.dart';
import 'package:smartbiztracker_new/screens/sama_store_home_screen.dart';
import 'package:smartbiztracker_new/screens/auth/login_screen.dart';
import 'package:smartbiztracker_new/screens/welcome_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/unified_auth_provider.dart';
import 'package:smartbiztracker_new/screens/auth/auth_wrapper.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/config/routes.dart';

// Add a static preloader for robot WebView
class RobotWebViewPreloader {
  // Static instance for singleton pattern
  static final RobotWebViewPreloader _instance = RobotWebViewPreloader._internal();
  factory RobotWebViewPreloader() => _instance;
  RobotWebViewPreloader._internal();

  // Static controller that can be accessed from anywhere
  static WebViewController? _webViewController;
  static bool _isWebViewInitialized = false;
  static bool _isWebViewLoaded = false;
  static bool _isLoadInProgress = false;

  // Initialize the WebView before it's needed - now with proper lazy loading
  static Future<void> preloadRobotWebView() async {
    // Guard against multiple simultaneous initialization attempts
    if (_isLoadInProgress) return;
    if (_webViewController != null) return;
    
    _isLoadInProgress = true;
    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadRequest(Uri.parse('https://my.spline.design/genkubgreetingrobot-fPBEa36NwDk1RjClPxjur0T4/'))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              // Don't show loading indicator
            },
            onPageFinished: (String url) {
              _isWebViewLoaded = true;
              _hideSplineAttribution();
              _triggerRobotAnimation('wave');
              
              // Remove watermark immediately
              _removeSplineLogoInterval();
            },
            onWebResourceError: (WebResourceError error) {
              // Reset state on error so we can try again
              _isWebViewInitialized = false;
              _isWebViewLoaded = false;
              _isLoadInProgress = false;
            },
          ),
        );
      
      _isWebViewInitialized = true;
    } catch (e) {
      debugPrint('Error initializing WebView: $e');
    } finally {
      _isLoadInProgress = false;
    }
  }

  // Release resources properly
  static void dispose() {
    _webViewController = null;
    _isWebViewInitialized = false;
    _isWebViewLoaded = false;
    _isLoadInProgress = false;
  }

  static void _hideSplineAttribution() {
    if (_webViewController != null && _isWebViewLoaded) {
      _webViewController!.runJavaScript('''
        (function() {
          // Method 1: Direct hiding of Spline watermark
          var style = document.createElement('style');
          style.textContent = `
            .spline-watermark, 
            [class*="spline-watermark"], 
            [class*="watermark"],
            [class*="signature"],
            [class*="made-with"],
            a[href*="spline.design"],
            a[href*="app.spline.design"],
            div[style*="z-index: 9999"],
            div[style*="z-index:9999"],
            .spline-viewer-ui {
              display: none !important;
              opacity: 0 !important;
              visibility: hidden !important;
              pointer-events: none !important;
              height: 0 !important;
              width: 0 !important;
              transform: scale(0) !important;
            }
          `;
          document.head.appendChild(style);
          
          // Method 2: Hide specific elements immediately
          const possibleWatermarks = [
            ...document.querySelectorAll('a[href*="spline"]'),
            ...document.querySelectorAll('div[style*="position: absolute"]'),
            ...document.querySelectorAll('div[style*="position:absolute"]'),
            ...document.querySelectorAll('[class*="watermark"]'),
            ...document.querySelectorAll('[class*="attribution"]'),
            ...document.querySelectorAll('[class*="signature"]')
          ];
          
          // Hide everything found
          possibleWatermarks.forEach(element => {
            if (element) {
              element.style.display = 'none';
              element.style.opacity = '0';
              element.style.visibility = 'hidden';
            }
          });
          
          // Method 3: Get maximum space
          var viewer = document.querySelector('spline-viewer');
          if (viewer) {
            viewer.style.width = '100%';
            viewer.style.height = '100%';
            viewer.style.position = 'absolute';
            viewer.style.top = '0';
            viewer.style.left = '0';
          }
        })();
      ''');
    }
  }
  
  static void _removeSplineLogoInterval() {
    if (_webViewController != null && _isWebViewLoaded) {
      _hideSplineAttribution();
    }
  }
  
  static void _triggerRobotAnimation(String animation) {
    triggerRobotAnimation(animation);
  }
  
  static void triggerRobotAnimation(String animation) {
    if (_webViewController != null && _isWebViewLoaded) {
      try {
        _webViewController!.runJavaScript('''
          try {
            // This is a simplified example - the actual Spline API might differ
            if (window.spline && window.spline.triggerAnimation) {
              window.spline.triggerAnimation('$animation');
            } else if (window.splineApp) {
              // Alternative API that might be used
              window.splineApp.triggerAnimation('$animation');
            } else {
              // Generic interaction with the scene
              const scene = document.querySelector('spline-viewer');
              if (scene) {
                scene.dispatchEvent(new CustomEvent('animation', { detail: { name: '$animation' } }));
              }
            }
          } catch(e) { console.log('Robot animation error: ' + e); }
        ''');
      } catch (e) {
        // Silent error handling
      }
    }
  }
  
  static WebViewController? get webViewController => _webViewController;
  static bool get isWebViewLoaded => _isWebViewLoaded;
}

class TransitionScreen extends StatefulWidget {
  const TransitionScreen({Key? key}) : super(key: key);

  @override
  State<TransitionScreen> createState() => _TransitionScreenState();
}

class _TransitionScreenState extends State<TransitionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Start loading sequence
    _startLoadingSequence();
  }

  Future<void> _startLoadingSequence() async {
    await Future.delayed(const Duration(seconds: 2)); // Show loading for 2 seconds
    if (mounted && !_isNavigating) {
      _isNavigating = true;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MenuScreen(),
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
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loading animation
            Lottie.asset(
              'assets/animations/loading.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            // Loading text
            Text(
              'جاري التحميل...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 