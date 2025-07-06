import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Lightweight static background for optimal performance
class AnimatedBackground extends StatelessWidget {

  const AnimatedBackground({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  Widget build(BuildContext context) {
    AppLogger.info('🎨 Lightweight background rendered');

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a2e), // Dark blue-gray
            Color(0xFF16213e), // Darker blue-gray
            Color(0xFF0f172a), // Very dark slate
          ],
        ),
      ),
      child: child,
    );
  }
}
