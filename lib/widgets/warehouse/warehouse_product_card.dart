import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/optimized_image.dart';

/// بطاقة منتج مخصصة لمدير المخزن
/// تعرض صورة المنتج، الاسم، والكمية المتاحة
class WarehouseProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const WarehouseProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  State<WarehouseProductCard> createState() => _WarehouseProductCardState();
}

class _WarehouseProductCardState extends State<WarehouseProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 0.4,
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

  void _onHoverChanged(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  Color _getStockStatusColor() {
    if (widget.product.quantity == 0) {
      return Colors.red;
    } else if (widget.product.quantity <= widget.product.reorderPoint) {
      return AccountantThemeConfig.warningOrange;
    } else {
      return AccountantThemeConfig.primaryGreen;
    }
  }

  /// الحصول على لون التوهج السفلي حسب حالة المخزون
  Color _getBottomGlowColor() {
    if (widget.product.quantity == 0) {
      return Colors.red; // توهج أحمر للمنتجات نفدت
    } else {
      return AccountantThemeConfig.primaryGreen; // توهج أخضر للمنتجات المتوفرة
    }
  }

  String _getStockStatusText() {
    if (widget.product.quantity == 0) {
      return 'نفد المخزون';
    } else if (widget.product.quantity <= widget.product.reorderPoint) {
      return 'مخزون منخفض';
    } else {
      return 'متوفر';
    }
  }

  /// Helper method to get properly formatted image URL like the working product details screen
  String _getProductImageUrl(ProductModel product) {
    // Check main image URL first
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      final imageUrl = product.imageUrl!;
      if (imageUrl.startsWith('http')) {
        return imageUrl;
      } else {
        return 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
      }
    }

    // Check additional images
    for (final image in product.images) {
      if (image.isNotEmpty) {
        final imageUrl = image.startsWith('http')
            ? image
            : 'https://samastock.pythonanywhere.com/static/uploads/$image';
        return imageUrl;
      }
    }

    // Return placeholder if no images found
    return 'https://via.placeholder.com/400x400/E0E0E0/757575?text=لا+توجد+صورة';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) => _onHoverChanged(true),
            onExit: (_) => _onHoverChanged(false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.cardGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isHovered
                        ? AccountantThemeConfig.primaryGreen.withOpacity(0.6)
                        : Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    // الظل الأساسي
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                    // التوهج الأخضر عند التمرير
                    if (_isHovered)
                      BoxShadow(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(_glowAnimation.value),
                        blurRadius: 20,
                        offset: const Offset(0, 0),
                      ),
                    // التوهج السفلي حسب حالة المخزون
                    BoxShadow(
                      color: _getBottomGlowColor().withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                      spreadRadius: -2,
                    ),
                    // توهج إضافي للمنتجات نفدت (أحمر قوي)
                    if (widget.product.quantity == 0)
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // محتوى البطاقة الرئيسي
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      // صورة المنتج
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // الصورة المحسنة
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                  child: OptimizedImage(
                                    imageUrl: _getProductImageUrl(widget.product),
                                    fit: BoxFit.cover,
                                    // Remove width/height: double.infinity to avoid Infinity calculations
                                    // The image will fill the available space from the parent container
                                  ),
                                ),
                              ),
                              
                              // مؤشر حالة المخزون
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStockStatusColor(),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getStockStatusColor().withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _getStockStatusText(),
                                    style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // معلومات المنتج
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // اسم المنتج
                              Text(
                                widget.product.name,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              
                              // الكمية المتاحة
                              Row(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 16,
                                    color: AccountantThemeConfig.primaryGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'الكمية: ${widget.product.quantity}',
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AccountantThemeConfig.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const Spacer(),
                              
                              // الفئة (إذا كانت متوفرة)
                              if (widget.product.category.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    widget.product.category,
                                    style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                        ],
                      ),

                      // مؤشر التوهج السفلي حسب حالة المخزون
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getBottomGlowColor().withOpacity(0.8),
                                _getBottomGlowColor().withOpacity(0.4),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _getBottomGlowColor().withOpacity(0.6),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// بناء صورة بديلة
  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.1),
            Colors.black.withOpacity(0.3),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد صورة',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء مؤشر تحميل الصورة
  Widget _buildLoadingImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.1),
            Colors.black.withOpacity(0.3),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen,
                    AccountantThemeConfig.primaryGreen.withOpacity(0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جاري التحميل...',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
