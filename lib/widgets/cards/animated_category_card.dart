import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Modern animated category card with optimized performance and Material Design 3 styling
class AnimatedCategoryCard extends StatefulWidget {

  const AnimatedCategoryCard({
    super.key,
    required this.categoryName,
    this.icon = Icons.category_rounded,
    required this.themeColor,
    required this.onTap,
    this.isSelected = false,
  });
  final String categoryName;
  final IconData icon;
  final Color themeColor;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  State<AnimatedCategoryCard> createState() => _AnimatedCategoryCardState();
}

class _AnimatedCategoryCardState extends State<AnimatedCategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    // Reduced debug logging for performance
    if (kDebugMode && widget.categoryName.length < 30) {
      AppLogger.info('🎨 AnimatedCategoryCard initialized for: "${widget.categoryName}"');
    }
  }

  void _initializeAnimations() {
    // Optimized scale animation for better performance
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 120), // Faster animation
      vsync: this,
    );

    // Scale animation: 1.0 -> 0.97 -> 1.0 (less dramatic)
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97, // Less scale change for better performance
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut, // Simpler curve
    ));
  }

  Future<void> _handleTap() async {
    // Reduced logging for performance
    if (kDebugMode) {
      AppLogger.info('🎯 Category card tapped: "${widget.categoryName}"');
    }

    // Quick scale animation
    await _scaleController.forward();
    await _scaleController.reverse();

    // Trigger callback
    widget.onTap();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _scaleController.reverse();
  }

  IconData _getCategoryIcon(String categoryName) {
    final category = categoryName.toLowerCase();

    // SAMA Store specific Arabic lighting categories
    if (category.contains('دلاية') || category.contains('pendant')) {
      return Icons.lightbulb_outline_rounded;
    } else if (category.contains('ابليك') || category.contains('applique') || category.contains('wall')) {
      return Icons.light_rounded;
    } else if (category.contains('مفرد') || category.contains('single')) {
      return Icons.lightbulb_rounded;
    } else if (category.contains('اباجورة') || category.contains('table') || category.contains('lamp')) {
      return Icons.table_restaurant_rounded; // Alternative for table lamp
    } else if (category.contains('كريستال') || category.contains('crystal')) {
      return Icons.diamond_rounded;
    } else if (category.contains('لامبدير') || category.contains('lampshade') || category.contains('shade')) {
      return Icons.light_rounded; // Alternative for lamp
    } else if (category.contains('مميز') || category.contains('featured') || category.contains('special')) {
      return Icons.star_rounded;
    }
    // General categories fallback
    else if (category.contains('إلكترونيات') || category.contains('electronics')) {
      return Icons.devices_rounded;
    } else if (category.contains('ملابس') || category.contains('clothes') || category.contains('fashion')) {
      return Icons.checkroom_rounded;
    } else if (category.contains('طعام') || category.contains('food') || category.contains('غذاء')) {
      return Icons.restaurant_rounded;
    } else if (category.contains('كتب') || category.contains('books') || category.contains('تعليم')) {
      return Icons.menu_book_rounded;
    } else if (category.contains('رياضة') || category.contains('sports') || category.contains('fitness')) {
      return Icons.fitness_center_rounded;
    } else if (category.contains('منزل') || category.contains('home') || category.contains('أثاث')) {
      return Icons.home_rounded;
    } else if (category.contains('سيارات') || category.contains('cars') || category.contains('automotive')) {
      return Icons.directions_car_rounded;
    } else if (category.contains('جمال') || category.contains('beauty') || category.contains('تجميل')) {
      return Icons.face_rounded;
    } else if (category.contains('ألعاب') || category.contains('games') || category.contains('toys')) {
      return Icons.sports_esports_rounded;
    } else if (category.contains('صحة') || category.contains('health') || category.contains('طب')) {
      return Icons.health_and_safety_rounded;
    }

    // Default to lightbulb for lighting store
    return Icons.lightbulb_outline_rounded;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 160,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isPressed
                      ? [
                          widget.themeColor.withValues(alpha: 0.9),
                          widget.themeColor.withValues(alpha: 0.7),
                        ]
                      : [
                          const Color(0xFF1e293b), // slate-800
                          const Color(0xFF0f172a), // slate-950
                        ],
                ),
                border: Border.all(
                  color: _isPressed
                      ? widget.themeColor.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: _isPressed ? 12 : 8,
                    offset: const Offset(0, 4),
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  if (_isPressed)
                    BoxShadow(
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                      color: widget.themeColor.withValues(alpha: 0.4),
                    ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getCategoryIcon(widget.categoryName),
                    size: 32,
                    color: _isPressed
                        ? Colors.white
                        : widget.themeColor,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      widget.categoryName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                        color: _isPressed
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
