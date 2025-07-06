import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_model.dart';
import '../../utils/style_system.dart';
import '../../utils/product_card_zoom_helper.dart';

enum ProductCardType {
  customer,  // للعملاء - بدون أسعار شراء أو ربحية
  admin,     // للأدمن - كل التفاصيل
  owner,     // لصاحب العمل - كل التفاصيل + تحليلات
  accountant // للمحاسب - التركيز على الأسعار والربحية
}

class ProfessionalProductCard extends StatelessWidget {

  const ProfessionalProductCard({
    super.key,
    required this.product,
    required this.cardType,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.showPrices = true,
    this.showStock = true,
    this.currencySymbol = 'جنيه',
  });
  final ProductModel product;
  final ProductCardType cardType;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showPrices;
  final bool showStock;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade900, // خلفية سوداء داكنة
            Colors.black87,       // تدرج أسود
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: _getBorderColor().withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: _getBorderColor(),
          width: _getBorderWidth(),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            // Show zoom overlay first
            ProductCardZoomHelper.showProductZoom(
              context: context,
              product: product,
              originalCard: Container(), // Will be replaced with actual card
              currencySymbol: currencySymbol,
              onEdit: onEdit,
              onDelete: onDelete,
              showAdminButtons: _shouldShowAdminButtons(),
            );

            // Then call original onTap if provided
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(20),
          splashColor: StyleSystem.primaryColor.withOpacity(0.1),
          highlightColor: StyleSystem.primaryColor.withOpacity(0.05),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 220,
              maxHeight: 320, // Increased max height to prevent overflow
            ),
            padding: const EdgeInsets.all(10), // Reduced padding to save space
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image - مساحة أكبر للصورة
                Expanded(
                  flex: 5, // Reduced flex to give more space for content
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: StyleSystem.shadowSmall,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          _buildProductImage(),
                          _buildStatusBadges(),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6), // Reduced spacing

                // Product Name - محسن للوضوح
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // Reduced padding
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getBorderColor().withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    product.name,
                    style: StyleSystem.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13, // Increased font size as per user preference
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 2), // Reduced spacing

                // Category Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getBorderColor().withOpacity(0.8),
                        _getBorderColor().withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _getBorderColor().withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    product.category,
                    style: StyleSystem.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 3), // Reduced spacing

                // Dynamic Content based on card type
                Expanded(
                  flex: 3, // Use Expanded instead of Flexible for better space management
                  child: _buildCardTypeSpecificContent(),
                ),

                const SizedBox(height: 4), // Reduced spacing

                // Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    final imageUrl = product.bestImageUrl;
    if (imageUrl.isNotEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              StyleSystem.primaryColor.withOpacity(0.05),
              StyleSystem.accentColor.withOpacity(0.02),
            ],
          ),
        ),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => Container(
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
                  CircularProgressIndicator(
                    color: StyleSystem.primaryColor,
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تحميل...',
                    style: StyleSystem.labelSmall.copyWith(
                      color: StyleSystem.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            // طباعة معلومات الخطأ للتشخيص
            print('DEBUG: Image error for product ${product.name}: $error');
            print('DEBUG: Failed URL: $url');
            print('DEBUG: Product imageUrl: ${product.imageUrl}');
            print('DEBUG: Product bestImageUrl: ${product.bestImageUrl}');

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
                      size: 32,
                      color: StyleSystem.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'لا توجد صورة',
                      style: StyleSystem.labelSmall.copyWith(
                        color: StyleSystem.textSecondary,
                        fontSize: 9,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (url.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'خطأ في التحميل',
                        style: StyleSystem.labelSmall.copyWith(
                          color: Colors.red.withOpacity(0.7),
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        height: double.infinity,
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_rounded,
                size: 36,
                color: StyleSystem.primaryColor,
              ),
              const SizedBox(height: 4),
              Text(
                'منتج',
                style: StyleSystem.labelSmall.copyWith(
                  color: StyleSystem.primaryColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildStatusBadges() {
    return Stack(
      children: [
        // Stock Status Badge
        if (product.quantity <= 5 && product.quantity > 0)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: StyleSystem.warningColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: StyleSystem.shadowSmall,
              ),
              child: Text(
                'كمية قليلة',
                style: StyleSystem.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
              ),
            ),
          ),

        // Out of Stock Badge
        if (product.quantity == 0)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: StyleSystem.errorColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: StyleSystem.shadowSmall,
              ),
              child: Text(
                'نفد المخزون',
                style: StyleSystem.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
              ),
            ),
          ),

        // Profit Badge (for admin/owner/accountant)
        if (_shouldShowProfitBadge())
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    StyleSystem.successColor,
                    StyleSystem.successColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: StyleSystem.shadowSmall,
              ),
              child: Text(
                '${_getProfitPercentage().toStringAsFixed(0)}%',
                style: StyleSystem.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCardTypeSpecificContent() {
    switch (cardType) {
      case ProductCardType.customer:
        return _buildCustomerContent();
      case ProductCardType.admin:
        return _buildAdminContent();
      case ProductCardType.owner:
        return _buildOwnerContent();
      case ProductCardType.accountant:
        return _buildAccountantContent();
    }
  }

  Widget _buildCustomerContent() {
    // محتوى العميل - أسعار وكمية حسب الإعدادات
    if (showPrices || showStock) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Price
          if (showPrices) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.discountPrice != null && product.discountPrice! > 0) ...[
                    Text(
                      '${product.discountPrice!.toStringAsFixed(0)} $currencySymbol',
                      style: StyleSystem.titleSmall.copyWith(
                        color: Colors.red.shade300,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      product.price.toStringAsFixed(0),
                      style: StyleSystem.bodySmall.copyWith(
                        color: Colors.grey.shade400,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 10,
                      ),
                    ),
                  ] else ...[
                    Text(
                      '${product.price.toStringAsFixed(0)} $currencySymbol',
                      style: StyleSystem.titleSmall.copyWith(
                        color: Colors.green.shade300,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Stock Quantity
          if (showStock) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: product.quantity > 0
                    ? StyleSystem.successColor.withOpacity(0.1)
                    : StyleSystem.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${product.quantity}',
                style: StyleSystem.labelSmall.copyWith(
                  color: product.quantity > 0
                      ? StyleSystem.successColor
                      : StyleSystem.errorColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 14,
              color: Colors.grey.shade400,
            ),
            const SizedBox(width: 4),
            Text(
              'معلومات المنتج مخفية',
              style: StyleSystem.labelSmall.copyWith(
                color: Colors.grey.shade400,
                fontSize: 9,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAdminContent() {
    // محتوى الأدمن - كل التفاصيل
    return Column(
      children: [
        // Prices Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Purchase Price
            if (product.purchasePrice != null && product.purchasePrice! > 0) ...[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'شراء: ${product.purchasePrice!.toStringAsFixed(0)}',
                      style: StyleSystem.labelSmall.copyWith(
                        color: Colors.blue.shade300,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      'بيع: ${product.price.toStringAsFixed(0)}',
                      style: StyleSystem.labelSmall.copyWith(
                        color: Colors.green.shade300,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Expanded(
                child: Text(
                  'بيع: ${product.price.toStringAsFixed(0)} $currencySymbol',
                  style: StyleSystem.titleSmall.copyWith(
                    color: Colors.green.shade300,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],

            // Stock
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: _getStockColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${product.quantity}',
                style: StyleSystem.labelSmall.copyWith(
                  color: _getStockColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),

        // Profit Info
        if (_shouldShowProfit()) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StyleSystem.successColor.withOpacity(0.1),
                  StyleSystem.successColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.trending_up,
                  size: 10,
                  color: StyleSystem.successColor,
                ),
                const SizedBox(width: 2),
                Text(
                  'ربح: ${_getProfit().toStringAsFixed(0)} $currencySymbol',
                  style: StyleSystem.labelSmall.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOwnerContent() {
    // محتوى صاحب العمل - مثل الأدمن مع تحليلات إضافية
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Prices and Stock Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (product.purchasePrice != null && product.purchasePrice! > 0) ...[
                    Text(
                      'شراء: ${product.purchasePrice!.toStringAsFixed(0)}',
                      style: StyleSystem.labelSmall.copyWith(
                        color: Colors.blue.shade300,
                        fontWeight: FontWeight.w600,
                        fontSize: 11, // Increased font size
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  Text(
                    'بيع: ${product.price.toStringAsFixed(0)} جنيه', // Added currency symbol
                    style: StyleSystem.labelSmall.copyWith(
                      color: Colors.green.shade300,
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Increased font size as per user preference
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Stock with Value
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: _getStockColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'كمية: ${product.quantity}',
                    style: StyleSystem.labelSmall.copyWith(
                      color: _getStockColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 11, // Increased font size as per user preference
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'قيمة: ${(product.price * product.quantity).toStringAsFixed(0)} جنيه',
                  style: StyleSystem.labelSmall.copyWith(
                    color: Colors.grey.shade400,
                    fontSize: 9, // Slightly increased
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),

        // Profitability Analysis
        if (_shouldShowProfit()) ...[
          const SizedBox(height: 2), // Reduced spacing
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StyleSystem.successColor.withOpacity(0.1),
                  StyleSystem.successColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  size: 8,
                  color: StyleSystem.successColor,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    'هامش: ${_getProfitPercentage().toStringAsFixed(1)}%',
                    style: StyleSystem.labelSmall.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade300,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAccountantContent() {
    // محتوى المحاسب - التركيز على الأسعار والربحية
    return Column(
      children: [
        // Financial Details
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.purchasePrice != null && product.purchasePrice! > 0) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.shopping_cart_outlined,
                          size: 10,
                          color: StyleSystem.infoColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          product.purchasePrice!.toStringAsFixed(0),
                          style: StyleSystem.labelSmall.copyWith(
                            color: Colors.blue.shade300,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    children: [
                      const Icon(
                        Icons.sell_outlined,
                        size: 10,
                        color: StyleSystem.successColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        product.price.toStringAsFixed(0),
                        style: StyleSystem.labelSmall.copyWith(
                          color: Colors.green.shade300,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stock Quantity
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: _getStockColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${product.quantity}',
                style: StyleSystem.labelSmall.copyWith(
                  color: _getStockColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),

        // Profit Analysis
        if (_shouldShowProfit()) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StyleSystem.primaryColor.withOpacity(0.1),
                  StyleSystem.primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: StyleSystem.primaryColor.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 10,
                      color: StyleSystem.primaryColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'ربح: ${_getProfit().toStringAsFixed(0)}',
                      style: StyleSystem.labelSmall.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade300,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_getProfitPercentage().toStringAsFixed(1)}%',
                  style: StyleSystem.labelSmall.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      height: 28, // تقليل الارتفاع لتجنب overflow
      child: _getActionButtonsContent(),
    );
  }

  Widget _getActionButtonsContent() {
    switch (cardType) {
      case ProductCardType.customer:
        return _buildCustomerButton();
      case ProductCardType.admin:
        return _buildAdminButtons();
      case ProductCardType.owner:
        return _buildOwnerButtons();
      case ProductCardType.accountant:
        return _buildAccountantButtons();
    }
  }

  Widget _buildCustomerButton() {
    return SizedBox(
      width: double.infinity,
      height: 28,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: StyleSystem.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_shopping_cart_rounded,
              size: 12,
            ),
            const SizedBox(width: 3),
            Text(
              'أضف للسلة',
              style: StyleSystem.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminButtons() {
    return Column(
      children: [
        // إزالة زر عرض التفاصيل - سيتم النقر على الكارد مباشرة
        const SizedBox(height: 4),
        // أزرار التعديل والحذف
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 24,
                child: ElevatedButton(
                  onPressed: onEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StyleSystem.infoColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.edit, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        'تعديل',
                        style: StyleSystem.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                height: 24,
                child: ElevatedButton(
                  onPressed: onDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StyleSystem.errorColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        'حذف',
                        style: StyleSystem.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOwnerButtons() {
    // إزالة زر عرض التفاصيل - سيتم النقر على الكارد مباشرة
    return const SizedBox.shrink();
  }

  Widget _buildAccountantButtons() {
    // إزالة زر عرض التفاصيل - سيتم النقر على الكارد مباشرة
    return const SizedBox.shrink();
  }

  // Helper methods
  Color _getBorderColor() {
    switch (cardType) {
      case ProductCardType.customer:
        return StyleSystem.primaryColor.withOpacity(0.1);
      case ProductCardType.admin:
        return StyleSystem.infoColor.withOpacity(0.3);
      case ProductCardType.owner:
        return StyleSystem.successColor.withOpacity(0.3);
      case ProductCardType.accountant:
        return StyleSystem.primaryColor.withOpacity(0.3);
    }
  }

  double _getBorderWidth() {
    return cardType == ProductCardType.customer ? 1 : 1.5;
  }

  Color _getStockColor() {
    if (product.quantity == 0) return StyleSystem.errorColor;
    if (product.quantity <= 5) return StyleSystem.warningColor;
    return StyleSystem.successColor;
  }

  bool _shouldShowProfitBadge() {
    return cardType != ProductCardType.customer &&
           product.purchasePrice != null &&
           product.purchasePrice! > 0 &&
           _getProfit() > 0;
  }

  bool _shouldShowProfit() {
    return cardType != ProductCardType.customer &&
           product.purchasePrice != null &&
           product.purchasePrice! > 0;
  }

  double _getProfit() {
    if (product.purchasePrice == null) return 0.0;
    return product.price - product.purchasePrice!;
  }

  double _getProfitPercentage() {
    if (product.purchasePrice == null || product.purchasePrice! == 0) return 0.0;
    return (_getProfit() / product.purchasePrice!) * 100;
  }

  bool _shouldShowAdminButtons() {
    return cardType == ProductCardType.admin || cardType == ProductCardType.owner;
  }
}