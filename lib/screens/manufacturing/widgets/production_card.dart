import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/widgets/common/optimized_image.dart';

/// بطاقة دفعة الإنتاج مع عرض المعلومات والحالة
class ProductionCard extends StatefulWidget {
  final ProductionBatch batch;
  final ProductModel? product;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ProductionCard({
    super.key,
    required this.batch,
    this.product,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<ProductionCard> createState() => _ProductionCardState();
}

class _ProductionCardState extends State<ProductionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
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
      end: 0.98,
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

  /// الحصول على لون الحالة
  Color get _statusColor {
    switch (widget.batch.status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// الحصول على أيقونة الحالة
  IconData get _statusIcon {
    switch (widget.batch.status) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.hourglass_empty;
      case 'pending':
        return Icons.schedule;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  /// معالجة الضغط على البطاقة
  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  /// معالجة الضغط المطول
  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  /// معالجة بداية الضغط
  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  /// معالجة إلغاء الضغط
  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  /// معالجة انتهاء الضغط
  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
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
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: _handleTap,
            onLongPress: _handleLongPress,
            onTapDown: _handleTapDown,
            onTapCancel: _handleTapCancel,
            onTapUp: _handleTapUp,
            child: Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                border: AccountantThemeConfig.glowBorder(_statusColor),
                boxShadow: [
                  ...AccountantThemeConfig.cardShadows,
                  if (_isPressed)
                    BoxShadow(
                      color: _statusColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20), // Increased padding for better spacing
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align to top to prevent overflow
                  children: [
                    _buildProductIndicator(),
                    const SizedBox(width: 20), // Increased spacing
                    Expanded(child: _buildContent()),
                    const SizedBox(width: 12), // Add spacing before trailing info
                    _buildTrailingInfo(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// بناء مؤشر المنتج (صورة المنتج أو أيقونة الحالة)
  Widget _buildProductIndicator() {
    if (widget.product != null) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _statusColor.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _statusColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: OptimizedImage(
            imageUrl: _getProductImageUrl(widget.product!),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Fallback to status icon if no product available
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _statusColor.withOpacity(0.8),
            _statusColor,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _statusIcon,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  /// بناء المحتوى الرئيسي
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Prevent overflow by using minimum space
      children: [
        // اسم المنتج أو رقم الدفعة
        Text(
          widget.product?.name ?? 'دفعة إنتاج #${widget.batch.id}',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 4),

        // رقم الدفعة ومعرف المنتج
        Text(
          'دفعة #${widget.batch.id} - منتج ${widget.batch.productId}',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
        ),
        
        const SizedBox(height: 4),
        
        // الوحدات المنتجة
        Row(
          children: [
            Icon(
              Icons.inventory_2,
              size: 16,
              color: Colors.white54,
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.batch.unitsProduced.toStringAsFixed(widget.batch.unitsProduced.truncateToDouble() == widget.batch.unitsProduced ? 0 : 1)} وحدة',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // الحالة
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _statusColor.withOpacity(0.5)),
          ),
          child: Text(
            widget.batch.statusText,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: _statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// بناء المعلومات الجانبية
  Widget _buildTrailingInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min, // Prevent overflow by using minimum space
      children: [
        // التاريخ
        Text(
          widget.batch.formattedCompletionDate,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        const SizedBox(height: 4),
        
        // الوقت
        Text(
          widget.batch.formattedCompletionTime,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: Colors.white54,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // مدير المخزن
        if (widget.batch.warehouseManagerName != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.batch.warehouseManagerName!,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white70,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        
        const SizedBox(height: 4),
        
        // أيقونة التفاصيل
        Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.white54,
        ),
      ],
    );
  }
}

/// بطاقة دفعة إنتاج مبسطة للعرض السريع
class SimpleProductionCard extends StatelessWidget {
  final ProductionBatch batch;
  final ProductModel? product;
  final VoidCallback? onTap;

  const SimpleProductionCard({
    super.key,
    required this.batch,
    this.product,
    this.onTap,
  });

  /// الحصول على لون الحالة
  Color get _statusColor {
    switch (batch.status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// الحصول على أيقونة الحالة
  IconData get _statusIcon {
    switch (batch.status) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.hourglass_empty;
      case 'pending':
        return Icons.schedule;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(8),
          border: AccountantThemeConfig.glowBorder(_statusColor),
        ),
        child: Row(
          children: [
            // Product image or status icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _statusColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: product != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: OptimizedImage(
                        imageUrl: _getProductImageUrl(product!),
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      _statusIcon,
                      color: _statusColor,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product?.name ?? 'دفعة #${batch.id}',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${batch.unitsProduced} وحدة - ${batch.statusText}',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              batch.formattedCompletionDate,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة دفعة إنتاج للسحب والإفلات
class DraggableProductionCard extends StatelessWidget {
  final ProductionBatch batch;
  final ProductModel? product;
  final VoidCallback? onTap;

  const DraggableProductionCard({
    super.key,
    required this.batch,
    this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<ProductionBatch>(
      data: batch,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.1,
          child: Container(
            width: 200,
            height: 100,
            child: ProductionCard(batch: batch, product: product),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: ProductionCard(batch: batch, product: product, onTap: onTap),
      ),
      child: ProductionCard(batch: batch, product: product, onTap: onTap),
    );
  }
}
