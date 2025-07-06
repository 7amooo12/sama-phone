import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Lightweight login card with simple fade animation for optimal performance
class AnimatedLoginCard extends StatefulWidget {

  const AnimatedLoginCard({
    super.key,
    required this.child,
    this.maxWidth = 400,
    this.maxHeight = 600,
  });
  final Widget child;
  final double maxWidth;
  final double maxHeight;

  @override
  State<AnimatedLoginCard> createState() => _AnimatedLoginCardState();
}

class _AnimatedLoginCardState extends State<AnimatedLoginCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    AppLogger.info('🎨 Lightweight login card initialized');
  }

  void _initializeAnimation() {
    // Simple fade animation for better performance
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Start animation
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardWidth = (widget.maxWidth < screenSize.width - 32)
        ? widget.maxWidth
        : screenSize.width - 32;
    final cardHeight = (widget.maxHeight < screenSize.height - 100)
        ? widget.maxHeight
        : screenSize.height - 100;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RepaintBoundary(
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1e293b), // slate-800
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
