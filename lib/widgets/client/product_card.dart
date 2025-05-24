import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/widgets/common/cached_image.dart';

class ProductCard extends StatefulWidget {
  ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.showOwnerActions = false,
  })  : imageUrl = product.imageUrl,
        name = product.name,
        price = product.price,
        rating = null, // ProductModel doesn't have rating
        isAvailable = product.quantity > 0,
        isOnSale = product.discountPrice != null,
        originalPrice = product.discountPrice != null ? product.price : null;
  final String? imageUrl;
  final String name;
  final double price;
  final double? rating;
  final bool isAvailable;
  final VoidCallback? onTap;
  final bool isOnSale;
  final double? originalPrice;
  final bool showOwnerActions;
  final ProductModel product;

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
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onTap,
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
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.safeOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with availability badge
              Stack(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                          ? CachedImage(
                              imageUrl: widget.imageUrl!,
                              fit: BoxFit.cover,
                              backgroundColor: theme.colorScheme.primary.safeOpacity(0.1),
                              errorWidget: Container(
                                color: theme.colorScheme.primary.safeOpacity(0.1),
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: theme.colorScheme.primary.safeOpacity(0.4),
                                  size: 40,
                                ),
                              ),
                              placeholder: Container(
                                color: theme.colorScheme.primary.safeOpacity(0.1),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: theme.colorScheme.primary.safeOpacity(0.1),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: theme.colorScheme.primary.safeOpacity(0.4),
                                size: 40,
                              ),
                            ),
                    ),
                  ),

                  // Availability badge
                  if (!widget.isAvailable)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'غير متوفر',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Sale badge
                  if (widget.isOnSale)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'تخفيض',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Product details
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name
                    Text(
                      widget.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Rating
                    if (widget.rating != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.rating!.toString(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${widget.price.toStringAsFixed(2)} جنيه',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (widget.isOnSale &&
                            widget.originalPrice != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${widget.originalPrice!.toStringAsFixed(2)} جنيه',
                            style: theme.textTheme.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color:
                                  theme.colorScheme.onSurface.safeOpacity(0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
