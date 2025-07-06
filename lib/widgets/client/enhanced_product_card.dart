import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/widgets/common/optimized_image.dart';
import 'package:smartbiztracker_new/utils/product_card_zoom_helper.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

/// بطاقة منتج محسنة مع تصميم عصري وأنيميشن
class EnhancedProductCard extends StatefulWidget {

  const EnhancedProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.showPrice = true,
    this.currencySymbol = 'جنيه',
    this.showAddToCartButton = true,
    this.enableHeroAnimation = true,
  });
  final ProductModel product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final bool showPrice;
  final String currencySymbol;
  final bool showAddToCartButton;
  final bool enableHeroAnimation;

  @override
  State<EnhancedProductCard> createState() => _EnhancedProductCardState();
}

class _EnhancedProductCardState extends State<EnhancedProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _elevationAnimation = Tween<double>(
      begin: 4.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = widget.product.quantity > 0;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: () {
              // Show zoom overlay first
              ProductCardZoomHelper.showProductZoom(
                context: context,
                product: widget.product,
                originalCard: Container(), // Will be replaced with actual card
                currencySymbol: widget.currencySymbol,
                showAdminButtons: false, // Enhanced card is for clients
              );

              // Then call original onTap if provided
              widget.onTap?.call();
            },
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.safeOpacity(0.1),
                    blurRadius: _elevationAnimation.value,
                    offset: Offset(0, _elevationAnimation.value / 2),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // صورة المنتج
                    _buildProductImage(theme, isAvailable),

                    // تفاصيل المنتج
                    _buildProductDetails(theme, isAvailable),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductImage(ThemeData theme, bool isAvailable) {
    return Expanded(
      flex: 3,
      child: Stack(
        children: [
          // الصورة الرئيسية
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: widget.enableHeroAnimation
                ? Hero(
                    tag: 'enhanced_product_${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}',
                    child: OptimizedImage(
                      imageUrl: widget.product.bestImageUrl,
                      fit: BoxFit.cover,
                    ),
                  )
                : OptimizedImage(
                    imageUrl: widget.product.bestImageUrl,
                    fit: BoxFit.cover,
                  ),
          ),

          // تدرج في الأسفل لتحسين قراءة النص
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.safeOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),

          // شارة عدم التوفر
          if (!isAvailable)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.safeOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
            ).animate().fadeIn().slideX(begin: -0.3),

          // شارة التخفيض
          if (widget.product.discountPrice != null)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.safeOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
            ).animate().fadeIn().slideX(begin: 0.3),
        ],
      ),
    );
  }

  Widget _buildProductDetails(ThemeData theme, bool isAvailable) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اسم المنتج
            Text(
              widget.product.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.2,
                color: isAvailable ? null : Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // الفئة
            if (widget.product.category.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.safeOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.secondary.safeOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.product.category,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            const Spacer(),

            // السعر
            if (widget.showPrice && widget.product.price > 0) ...[
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.product.price.toStringAsFixed(0)} ${widget.currencySymbol}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.product.discountPrice != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.product.discountPrice!.toStringAsFixed(0),
                      style: theme.textTheme.bodySmall?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],

            // زر الإضافة للسلة أو عرض التفاصيل
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isAvailable ? (widget.onAddToCart ?? widget.onTap) : widget.onTap,
                icon: Icon(
                  isAvailable && widget.showAddToCartButton
                    ? Icons.add_shopping_cart
                    : Icons.visibility,
                  size: 16,
                ),
                label: Text(
                  isAvailable && widget.showAddToCartButton
                    ? 'أضف للسلة'
                    : 'عرض التفاصيل',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAvailable
                    ? theme.colorScheme.primary
                    : Colors.grey[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isAvailable ? 2 : 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
