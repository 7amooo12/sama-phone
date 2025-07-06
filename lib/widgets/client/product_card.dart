import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/widgets/common/optimized_image.dart';
import 'package:smartbiztracker_new/utils/product_card_zoom_helper.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.showOwnerActions = false,
  });

  final ProductModel product;
  final VoidCallback? onTap;
  final bool showOwnerActions;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter out zero stock products at the widget level
    if (widget.product.quantity <= 0) {
      return const SizedBox.shrink();
    }

    final isAvailable = widget.product.quantity > 0;
    final isOnSale = widget.product.discountPrice != null;

    return GestureDetector(
      onTap: () {
        // Show zoom overlay first
        ProductCardZoomHelper.showProductZoom(
          context: context,
          product: widget.product,
          originalCard: Container(), // Will be replaced with actual card
          currencySymbol: 'جنيه',
          showAdminButtons: widget.showOwnerActions,
        );

        // Then call original onTap if provided
        widget.onTap?.call();
      },
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
            border: AccountantThemeConfig.glowBorder(
              isAvailable
                  ? AccountantThemeConfig.primaryGreen
                  : AccountantThemeConfig.neutralColor
            ),
            boxShadow: isAvailable
                ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                : AccountantThemeConfig.cardShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Fix overflow by constraining height
            children: [
              // Product Image with availability badge
              Flexible(
                flex: 3,
                child: Stack(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty
                            ? OptimizedImage(
                                imageUrl: widget.product.imageUrl!,
                                fit: BoxFit.cover,
                                // Remove width: double.infinity to avoid Infinity calculations
                                height: 120,
                                errorWidget: Container(
                                  decoration: BoxDecoration(
                                    gradient: AccountantThemeConfig.cardGradient,
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.6),
                                    size: 40,
                                  ),
                                ),
                                placeholder: Container(
                                  decoration: BoxDecoration(
                                    gradient: AccountantThemeConfig.cardGradient,
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AccountantThemeConfig.primaryGreen,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                useProgressIndicator: true,
                                memCacheWidth: 240, // Optimize memory cache for card size
                                memCacheHeight: 240,
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: AccountantThemeConfig.cardGradient,
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.6),
                                  size: 40,
                                ),
                              ),
                      ),
                    ),

                    // Availability badge
                    if (!isAvailable)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AccountantThemeConfig.dangerRed,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
                          ),
                          child: Text(
                            'غير متوفر',
                            style: AccountantThemeConfig.labelSmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // Sale badge
                    if (isOnSale)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: AccountantThemeConfig.greenGradient,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.successGreen),
                          ),
                          child: Text(
                            'تخفيض',
                            style: AccountantThemeConfig.labelSmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Product details - Remove price display for clients
              Flexible(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product name
                      Flexible(
                        child: Text(
                          widget.product.name,
                          style: AccountantThemeConfig.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Stock indicator with quantity display
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: isAvailable
                                ? AccountantThemeConfig.primaryGreen
                                : AccountantThemeConfig.dangerRed,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isAvailable
                                  ? 'متوفر (${widget.product.quantity} قطعة)'
                                  : 'غير متوفر',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: isAvailable
                                    ? AccountantThemeConfig.primaryGreen
                                    : AccountantThemeConfig.dangerRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: const Duration(milliseconds: 300), delay: const Duration(milliseconds: 100))
      .slideY(begin: 0.1, end: 0, duration: const Duration(milliseconds: 300), delay: const Duration(milliseconds: 100))
      .then()
      .shimmer(duration: const Duration(milliseconds: 1000), color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1));
  }
}
