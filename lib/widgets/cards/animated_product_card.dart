import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Lightweight product card with cached image loading for optimal performance
class AnimatedProductCard extends StatefulWidget {

  const AnimatedProductCard({
    super.key,
    required this.productName,
    required this.price,
    this.imageUrl,
    this.description,
    this.onTap,
  });
  final String productName;
  final double price;
  final String? imageUrl;
  final String? description;
  final VoidCallback? onTap;

  @override
  State<AnimatedProductCard> createState() => _AnimatedProductCardState();
}

class _AnimatedProductCardState extends State<AnimatedProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    // Reduced logging for performance
    if (kDebugMode && widget.productName.length < 50) {
      AppLogger.info('🛍️ Product card initialized: ${widget.productName}');
    }
  }

  void _initializeAnimation() {
    // Optimized scale animation for tap feedback
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100), // Faster animation
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97, // Less dramatic scale for better performance
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut, // Simpler curve
    ));
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _scaleController.reverse();
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: RepaintBoundary(
              child: Container(
                width: 180,
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF1e293b), // slate-800
                  border: Border.all(
                    color: _isPressed
                        ? Colors.blue.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: _isPressed ? 12 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product image with cached loading
                      Expanded(
                        flex: 3,
                        child: _buildProductImage(),
                      ),
                      // Product details
                      Expanded(
                        flex: 2,
                        child: _buildProductDetails(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductImage() {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return Container(
        color: const Color(0xFF374151), // gray-700
        child: const Center(
          child: Icon(
            Icons.shopping_bag_outlined,
            size: 40,
            color: Colors.white54,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: widget.imageUrl!,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: const Color(0xFF374151), // gray-700
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF374151), // gray-700
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 40,
            color: Colors.white54,
          ),
        ),
      ),
      // Performance optimizations
      memCacheWidth: 360, // 2x the display width for high DPI
      memCacheHeight: 480, // 2x the display height for high DPI
      maxWidthDiskCache: 360,
      maxHeightDiskCache: 480,
    );
  }

  Widget _buildProductDetails() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.productName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Cairo',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.price.toStringAsFixed(2)} ج.م',
            style: const TextStyle(
              color: Color(0xFF10b981), // emerald-500
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          if (widget.description != null && widget.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                widget.description!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
