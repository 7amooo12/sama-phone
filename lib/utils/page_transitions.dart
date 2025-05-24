import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';

/// نظام الانتقالات المخصصة بين الصفحات
/// يوفر هذا الملف مجموعة من الانتقالات المخصصة التي يمكن استخدامها للتنقل بين الصفحات
class PageTransitions {
  /// انتقال بتأثير التلاشي
  static PageRouteBuilder fadeTransition({
    required Widget page,
    required RouteSettings settings,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOut,
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );
        
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );
      },
    );
  }
  
  /// انتقال بتأثير الانزلاق من اليمين إلى اليسار
  static PageRouteBuilder slideRightToLeftTransition({
    required Widget page,
    required RouteSettings settings,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOut,
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );
        
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
    );
  }
  
  /// انتقال بتأثير الانزلاق من اليسار إلى اليمين
  static PageRouteBuilder slideLeftToRightTransition({
    required Widget page,
    required RouteSettings settings,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOut,
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );
        
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
    );
  }
  
  /// انتقال بتأثير الانزلاق من الأسفل إلى الأعلى
  static PageRouteBuilder slideBottomToTopTransition({
    required Widget page,
    required RouteSettings settings,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOut,
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );
        
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
    );
  }
  
  /// انتقال بتأثير الانزلاق من الأعلى إلى الأسفل
  static PageRouteBuilder slideTopToBottomTransition({
    required Widget page,
    required RouteSettings settings,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOut,
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );
        
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
    );
  }
  
  /// انتقال بتأثير التكبير
  static PageRouteBuilder scaleTransition({
    required Widget page,
    required RouteSettings settings,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOut,
    Alignment alignment = Alignment.center,
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );
        
        return ScaleTransition(
          scale: curvedAnimation,
          alignment: alignment,
          child: child,
        );
      },
    );
  }
  
  /// انتقال بتأثير التلاشي والانزلاق
  static PageRouteBuilder fadeSlideTransition({
    required Widget page,
    required RouteSettings settings,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOut,
    Offset beginOffset = const Offset(0, 0.1),
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );
        
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
  
  /// انتقال بتأثير الدوران
  static PageRouteBuilder rotationTransition({
    required Widget page,
    required RouteSettings settings,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeOut,
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );
        
        return RotationTransition(
          turns: Tween<double>(
            begin: 0.1,
            end: 1.0,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }
  
  /// انتقال بتأثير التلاشي والتكبير
  static PageRouteBuilder fadeScaleTransition({
    required Widget page,
    required RouteSettings settings,
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeOut,
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );
        
        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.9,
              end: 1.0,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
  
  /// انتقال بتأثير الانزلاق مع تغيير الحجم
  static PageRouteBuilder slideScaleTransition({
    required Widget page,
    required RouteSettings settings,
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeOut,
    Offset beginOffset = const Offset(1, 0),
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );
        
        return SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.8,
              end: 1.0,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
  
  /// انتقال بتأثير المكعب ثلاثي الأبعاد
  static PageRouteBuilder cubeTransition({
    required Widget page,
    required RouteSettings settings,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeOut,
    bool rightToLeft = true,
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );
        
        return _CubePageTransition(
          animation: curvedAnimation,
          child: child,
          rightToLeft: rightToLeft,
        );
      },
    );
  }
}

/// ويدجت للانتقال بتأثير المكعب ثلاثي الأبعاد
class _CubePageTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final bool rightToLeft;
  
  const _CubePageTransition({
    required this.animation,
    required this.child,
    this.rightToLeft = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;
        final angle = rightToLeft ? (1 - value) * -90.0 : (1 - value) * 90.0;
        final angleInRadians = angle * 3.14159265359 / 180.0;
        
        return Transform(
          alignment: rightToLeft ? Alignment.centerRight : Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angleInRadians)
            ..translate(rightToLeft ? (1 - value) * screenWidth : -(1 - value) * screenWidth),
          child: this.child,
        );
      },
      child: child,
    );
  }
}
