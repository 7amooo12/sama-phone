import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/providers/client_orders_provider.dart';
import 'package:smartbiztracker_new/services/client_orders_service.dart' as client_service;
import 'package:smartbiztracker_new/screens/client/cart_screen.dart';
import 'package:smartbiztracker_new/widgets/common/optimized_image.dart';
import 'package:smartbiztracker_new/widgets/common/enhanced_product_image.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

class ProductDetailsSheet extends StatefulWidget {

  const ProductDetailsSheet({
    super.key,
    required this.product,
    this.showPrice = true,
    this.currencySymbol = 'جنيه',
  });
  final ProductModel product;
  final bool showPrice;
  final String currencySymbol;

  @override
  State<ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends State<ProductDetailsSheet> {
  int _selectedImageIndex = 0;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.9,
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with SAMA branding
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AccountantThemeConfig.cardBackground1.withValues(alpha: 0.8),
                  AccountantThemeConfig.cardBackground2.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                // SAMA logo/text
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: Text(
                    'SAMA',
                    style: AccountantThemeConfig.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تفاصيل المنتج',
                    style: AccountantThemeConfig.headlineMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.cardGradient,
                    borderRadius: BorderRadius.circular(20),
                    border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product images
                  _buildImageSection(theme),

                  const SizedBox(height: 24),

                  // Product info
                  _buildProductInfo(theme),

                  const SizedBox(height: 24),

                  // Description if available
                  if (widget.product.description.isNotEmpty)
                    _buildDescription(theme),

                  const SizedBox(height: 24),

                  // Additional details
                  _buildAdditionalDetails(theme),

                  const SizedBox(height: 100), // Space for bottom actions
                ],
              ),
            ),
          ),

          // Bottom actions
          _buildBottomActions(theme),
        ],
      ),
    );
  }

  Widget _buildImageSection(ThemeData theme) {
    final images = _getProductImages();

    return Column(
      children: [
        // Main image
        Container(
          height: 300,
          width: double.infinity,
          decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: GestureDetector(
              onTap: () => _showImageViewer(images[_selectedImageIndex]),
              child: Hero(
                tag: 'product_image_${widget.product.id}',
                child: OptimizedImage(
                  imageUrl: images[_selectedImageIndex],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),

        // Image thumbnails if multiple images
        if (images.length > 1) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedImageIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedImageIndex = index),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AccountantThemeConfig.primaryGreen
                            : AccountantThemeConfig.neutralColor.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: OptimizedImage(
                        imageUrl: images[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product name
        Text(
          widget.product.name,
          style: AccountantThemeConfig.headlineMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 12),

        // Category
        if (widget.product.category.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.blueGradient,
              borderRadius: BorderRadius.circular(12),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
            ),
            child: Text(
              widget.product.category,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Price (if allowed to show)
        if (widget.showPrice && widget.product.price > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
              gradient: AccountantThemeConfig.greenGradient,
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'السعر: ',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${widget.product.price.toStringAsFixed(0)} ${widget.currencySymbol}',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Availability
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: widget.product.quantity > 0
                ? AccountantThemeConfig.greenGradient
                : LinearGradient(
                    colors: [AccountantThemeConfig.dangerRed, AccountantThemeConfig.dangerRed.withValues(alpha: 0.8)],
                  ),
            borderRadius: BorderRadius.circular(12),
            border: AccountantThemeConfig.glowBorder(
              widget.product.quantity > 0
                  ? AccountantThemeConfig.primaryGreen
                  : AccountantThemeConfig.dangerRed,
            ),
            boxShadow: AccountantThemeConfig.glowShadows(
              widget.product.quantity > 0
                  ? AccountantThemeConfig.primaryGreen
                  : AccountantThemeConfig.dangerRed,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  widget.product.quantity > 0 ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.product.quantity > 0
                  ? 'متوفر (${widget.product.quantity} قطعة)'
                  : 'غير متوفر',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الوصف',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
          ),
          child: Text(
            widget.product.description,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalDetails(ThemeData theme) {
    final details = <String, String>{};

    if (widget.product.sku.isNotEmpty) {
      details['رقم المنتج'] = widget.product.sku;
    }

    if (widget.product.tags?.isNotEmpty == true) {
      details['العلامات'] = widget.product.tags!.join(', ');
    }

    if (details.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تفاصيل إضافية',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.neutralColor),
          ),
          child: Column(
            children: details.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        entry.key,
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AccountantThemeConfig.primaryGreen,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: SafeArea(
        child: Consumer<ClientOrdersProvider>(
          builder: (context, orderProvider, child) {
            final isAvailable = widget.product.quantity > 0;

            return Row(
              children: [
                // Quantity selector
                Container(
                  decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
                    border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _quantity > 1 && isAvailable ? () => setState(() => _quantity--) : null,
                        icon: const Icon(Icons.remove),
                        style: IconButton.styleFrom(
                          foregroundColor: _quantity > 1 && isAvailable
                            ? AccountantThemeConfig.primaryGreen
                            : AccountantThemeConfig.neutralColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '$_quantity',
                          style: AccountantThemeConfig.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? Colors.white : AccountantThemeConfig.neutralColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _quantity < widget.product.quantity && isAvailable
                            ? () => setState(() => _quantity++)
                            : null,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          foregroundColor: _quantity < widget.product.quantity && isAvailable
                            ? AccountantThemeConfig.primaryGreen
                            : AccountantThemeConfig.neutralColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Add to cart button
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isAvailable
                          ? AccountantThemeConfig.greenGradient
                          : LinearGradient(
                              colors: [AccountantThemeConfig.neutralColor, AccountantThemeConfig.neutralColor.withValues(alpha: 0.8)],
                            ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isAvailable
                          ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                          : null,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: isAvailable ? () => _addToCart(orderProvider as ClientOrdersProvider) : null,
                      icon: Icon(isAvailable ? Icons.add_shopping_cart : Icons.block),
                      label: Text(isAvailable ? 'أضف للسلة' : 'غير متوفر'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<String> _getProductImages() {
    final images = <String>[];

    // Add main image if available
    if (widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty) {
      final imageUrl = widget.product.imageUrl!;
      if (imageUrl.startsWith('http')) {
        images.add(imageUrl);
      } else {
        images.add('https://samastock.pythonanywhere.com/static/uploads/$imageUrl');
      }
    }

    // Add additional images
    for (final image in widget.product.images) {
      if (image.isNotEmpty) {
        final imageUrl = image.startsWith('http')
            ? image
            : 'https://samastock.pythonanywhere.com/static/uploads/$image';

        if (!images.contains(imageUrl)) {
          images.add(imageUrl);
        }
      }
    }

    // If no images, add a placeholder
    if (images.isEmpty) {
      images.add('https://via.placeholder.com/400x400/E0E0E0/757575?text=لا+توجد+صورة');
    }

    return images;
  }

  // تم حذف _buildProductImage واستبدالها بـ OptimizedImage

  void _showImageViewer(String imageUrl) {
    if (imageUrl.isEmpty || imageUrl.startsWith('assets/')) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            OptimizedImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(ClientOrdersProvider orderProvider) {
    final cartItem = client_service.CartItem.fromProduct(widget.product, _quantity);
    orderProvider.addToCart(cartItem);

    Navigator.pop(context); // Close the details sheet

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إضافة ${widget.product.name} للسلة'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'عرض السلة',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CartScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}
