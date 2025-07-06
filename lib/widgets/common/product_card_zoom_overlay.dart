import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_model.dart';
import '../../utils/style_system.dart';
import 'enhanced_product_image.dart';

/// Enhanced product card zoom overlay with professional animations and image enhancement
class ProductCardZoomOverlay extends StatefulWidget {

  const ProductCardZoomOverlay({
    super.key,
    required this.product,
    required this.originalCard,
    this.currencySymbol = 'جنيه',
    this.onEdit,
    this.onDelete,
    this.showAdminButtons = false,
  });
  final ProductModel product;
  final String currencySymbol;
  final Widget originalCard;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showAdminButtons;

  @override
  State<ProductCardZoomOverlay> createState() => _ProductCardZoomOverlayState();
}

class _ProductCardZoomOverlayState extends State<ProductCardZoomOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _overlayAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Create animations with professional easing
    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _overlayAnimation = Tween<double>(
      begin: 0.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _fadeController.forward();
    _scaleController.forward();

    // Add haptic feedback
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _closeZoom() async {
    // Add haptic feedback
    HapticFeedback.selectionClick();
    
    // Reverse animations
    await Future.wait([
      _scaleController.reverse(),
      _fadeController.reverse(),
    ]);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
        builder: (context, child) {
          return Stack(
            children: [
              // Semi-transparent overlay
              GestureDetector(
                onTap: _closeZoom,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(_overlayAnimation.value),
                ),
              ),
              
              // Zoomed card
              Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildZoomedCard(screenSize, isLandscape),
                  ),
                ),
              ),
              
              // Close button
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: _buildCloseButton(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildZoomedCard(Size screenSize, bool isLandscape) {
    final cardWidth = isLandscape 
        ? screenSize.width * 0.5 
        : screenSize.width * 0.85;
    final cardHeight = isLandscape 
        ? screenSize.height * 0.8 
        : screenSize.height * 0.7;

    return Container(
      width: cardWidth,
      height: cardHeight,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade900,
            Colors.black87,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: 5,
          ),
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: Colors.green,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Enhanced product image
            Expanded(
              flex: isLandscape ? 3 : 4,
              child: _buildEnhancedProductImage(),
            ),
            
            // Product details
            Expanded(
              flex: isLandscape ? 2 : 3,
              child: _buildProductDetails(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedProductImage() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.primaryColor.withOpacity(0.1),
            StyleSystem.accentColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Main image using EnhancedProductImage for consistency
          Positioned.fill(
            child: EnhancedProductImage(
              product: widget.product,
              fit: BoxFit.contain, // Better visibility for zoom overlay
              borderRadius: BorderRadius.zero, // No border radius for full fill
            ),
          ),

          // Status badges
          _buildZoomedStatusBadges(),
        ],
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.neutralLight,
            StyleSystem.neutralMedium.withOpacity(0.3),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_not_supported_rounded,
              size: 64,
              color: StyleSystem.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد صورة متاحة',
              style: StyleSystem.titleMedium.copyWith(
                color: StyleSystem.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.primaryColor.withOpacity(0.2),
            StyleSystem.accentColor.withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_rounded,
              size: 80,
              color: StyleSystem.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              widget.product.name,
              style: StyleSystem.titleLarge.copyWith(
                color: StyleSystem.primaryColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomedStatusBadges() {
    return Stack(
      children: [
        // Stock status badge
        if (widget.product.quantity <= 5 && widget.product.quantity > 0)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: StyleSystem.warningColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: StyleSystem.shadowMedium,
              ),
              child: Text(
                'كمية قليلة',
                style: StyleSystem.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Out of stock badge
        if (widget.product.quantity == 0)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: StyleSystem.errorColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: StyleSystem.shadowMedium,
              ),
              child: Text(
                'نفد المخزون',
                style: StyleSystem.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product name
          Text(
            widget.product.name,
            style: StyleSystem.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // Category
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.8),
                  Colors.green.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.product.category,
              style: StyleSystem.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Price and quantity info
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'السعر',
                  '${widget.product.price.toStringAsFixed(0)} ${widget.currencySymbol}',
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'الكمية',
                  '${widget.product.quantity}',
                  Icons.inventory,
                  widget.product.quantity > 0 ? Colors.blue : Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Admin buttons if needed
          if (widget.showAdminButtons) _buildAdminButtons(),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: StyleSystem.labelSmall.copyWith(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: StyleSystem.titleSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminButtons() {
    return Row(
      children: [
        if (widget.onEdit != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                _closeZoom();
                widget.onEdit?.call();
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('تعديل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        if (widget.onEdit != null && widget.onDelete != null)
          const SizedBox(width: 8),
        if (widget.onDelete != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                _closeZoom();
                widget.onDelete?.call();
              },
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('حذف'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: _closeZoom,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
