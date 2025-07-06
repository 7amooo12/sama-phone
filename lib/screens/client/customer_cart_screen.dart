import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/providers/customer_cart_provider.dart';
import 'package:smartbiztracker_new/providers/app_settings_provider.dart';
import 'package:smartbiztracker_new/providers/client_orders_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/simplified_product_provider.dart';
import 'package:smartbiztracker_new/services/client_orders_service.dart' as client_service;
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/show_snackbar.dart';

class CustomerCartScreen extends StatefulWidget {
  const CustomerCartScreen({super.key});

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: StyleSystem.cardGradient,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: StyleSystem.elevatedCardShadow,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: StyleSystem.warningGradient,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'مسح السلة',
                  style: StyleSystem.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: StyleSystem.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'هل أنت متأكد من أنك تريد مسح جميع العناصر من السلة؟',
                  style: StyleSystem.bodyMedium.copyWith(
                    color: StyleSystem.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'إلغاء',
                          style: StyleSystem.titleMedium.copyWith(
                            color: StyleSystem.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Provider.of<CustomerCartProvider>(context, listen: false).clearCart();
                          ShowSnackbar.show(context, 'تم مسح السلة', isError: false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StyleSystem.errorColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'مسح',
                          style: StyleSystem.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: Consumer2<CustomerCartProvider, AppSettingsProvider>(
        builder: (context, cartProvider, settingsProvider, child) {
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(cartProvider),
              if (cartProvider.isEmpty)
                _buildEmptyCart()
              else ...[
                _buildCartItems(cartProvider, settingsProvider),
                _buildCartSummary(cartProvider, settingsProvider),
              ],
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(CustomerCartProvider cartProvider) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: StyleSystem.headerGradient,
          ),
        ),
        child: FlexibleSpaceBar(
          title: Text(
            'السلة (${cartProvider.itemCount})',
            style: StyleSystem.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
      ),
      actions: [
        if (cartProvider.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _showClearCartDialog,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
              ),
              tooltip: 'مسح السلة',
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return SliverFillRemaining(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        StyleSystem.primaryColor.withOpacity(0.1),
                        StyleSystem.accentColor.withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: StyleSystem.primaryColor,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'السلة فارغة',
                  style: StyleSystem.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ابدأ بإضافة المنتجات إلى سلتك',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(
                      'تصفح المنتجات',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartItems(CustomerCartProvider cartProvider, AppSettingsProvider settingsProvider) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = cartProvider.items[index];
            return _buildCartItemCard(item, cartProvider, settingsProvider, index)
                .animate(delay: (index * 100).ms)
                .fadeIn(duration: 600.ms)
                .slideX(begin: 0.3, curve: Curves.easeOutBack);
          },
          childCount: cartProvider.items.length,
        ),
      ),
    );
  }

  Widget _buildCartItemCard(
    CartItem item,
    CustomerCartProvider cartProvider,
    AppSettingsProvider settingsProvider,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.surfaceDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: StyleSystem.primaryColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: StyleSystem.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: StyleSystem.shadowSmall,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildProductImage(item),
              ),
            ),

            const SizedBox(width: 16),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    item.productName,
                    style: StyleSystem.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Category and SKU
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: StyleSystem.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category,
                          style: StyleSystem.labelSmall.copyWith(
                            color: StyleSystem.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'كود: ${item.sku}',
                        style: StyleSystem.labelSmall.copyWith(
                          color: StyleSystem.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Stock availability indicator
                  Consumer<SimplifiedProductProvider>(
                    builder: (context, productProvider, child) {
                      final product = productProvider.getProductById(item.productId);

                      if (product == null) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: StyleSystem.errorColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'المنتج غير متوفر',
                                style: StyleSystem.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final isAvailable = product.quantity > 0;
                      final stockColor = product.quantity > 10
                          ? StyleSystem.successColor
                          : product.quantity > 0
                              ? StyleSystem.warningColor
                              : StyleSystem.errorColor;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: stockColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAvailable ? Icons.inventory_2 : Icons.warning,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAvailable
                                  ? 'متوفر: ${product.quantity} قطعة'
                                  : 'غير متوفر',
                              style: StyleSystem.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Price and Quantity Controls
                  Row(
                    children: [
                      // Price - Hidden during pricing approval workflow
                      if (settingsProvider.showPricesToPublic) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.discountPrice != null && item.discountPrice! > 0) ...[
                              Text(
                                '${item.discountPrice!.toStringAsFixed(2)} ${settingsProvider.currencySymbol}',
                                style: StyleSystem.titleSmall.copyWith(
                                  color: StyleSystem.errorColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${item.price.toStringAsFixed(2)} ${settingsProvider.currencySymbol}',
                                style: StyleSystem.labelSmall.copyWith(
                                  color: StyleSystem.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ] else ...[
                              Text(
                                '${item.price.toStringAsFixed(2)} ${settingsProvider.currencySymbol}',
                                style: StyleSystem.titleSmall.copyWith(
                                  color: StyleSystem.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],

                      const Spacer(),

                      // Quantity Controls
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              StyleSystem.primaryColor.withOpacity(0.1),
                              StyleSystem.accentColor.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: StyleSystem.primaryColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Decrease button
                            Material(
                              color: Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => cartProvider.decreaseQuantity(item.productId),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.remove_rounded,
                                    size: 18,
                                    color: StyleSystem.primaryColor,
                                  ),
                                ),
                              ),
                            ),

                            // Quantity display
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: StyleSystem.primaryColor.withOpacity(0.1),
                              ),
                              child: Text(
                                '${item.quantity}',
                                style: StyleSystem.titleSmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: StyleSystem.primaryColor,
                                ),
                              ),
                            ),

                            // Increase button
                            Material(
                              color: Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => cartProvider.increaseQuantity(item.productId),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 18,
                                    color: StyleSystem.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Total Price and Remove Button
                  Row(
                    children: [
                      if (settingsProvider.showPricesToPublic) ...[
                        Text(
                          'المجموع: ${item.totalPrice.toStringAsFixed(2)} ${settingsProvider.currencySymbol}',
                          style: StyleSystem.titleSmall.copyWith(
                            color: StyleSystem.successColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Remove button
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => cartProvider.removeFromCart(item.productId),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: StyleSystem.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: StyleSystem.errorColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(CartItem item) {
    if (item.productImage != null && item.productImage!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: item.productImage!,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                StyleSystem.neutralLight,
                StyleSystem.neutralMedium.withOpacity(0.3),
              ],
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(
              color: StyleSystem.primaryColor,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                StyleSystem.neutralLight,
                StyleSystem.neutralMedium.withOpacity(0.3),
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.image_not_supported_rounded,
              size: 32,
              color: StyleSystem.textSecondary,
            ),
          ),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              StyleSystem.primaryColor.withOpacity(0.1),
              StyleSystem.accentColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.inventory_2_rounded,
            size: 32,
            color: StyleSystem.primaryColor,
          ),
        ),
      );
    }
  }

  Widget _buildCartSummary(CustomerCartProvider cartProvider, AppSettingsProvider settingsProvider) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              StyleSystem.surfaceDark,
              StyleSystem.backgroundDark,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: StyleSystem.primaryColor.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: StyleSystem.primaryColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: StyleSystem.elegantGradient,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: StyleSystem.shadowSmall,
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'ملخص الطلب',
                    style: StyleSystem.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: StyleSystem.elegantGradient,
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),

              const SizedBox(height: 20),

              // Items count
              _buildSummaryRow(
                'عدد العناصر',
                '${cartProvider.itemCount}',
                Icons.inventory_2_outlined,
                StyleSystem.infoColor,
              ),

              const SizedBox(height: 12),

              // Subtotal - Always show, with pending pricing message when needed
              if (settingsProvider.showPricesToPublic) ...[
                _buildSummaryRow(
                  'المجموع الفرعي',
                  '${cartProvider.subtotal.toStringAsFixed(2)} ${settingsProvider.currencySymbol}',
                  Icons.calculate_outlined,
                  StyleSystem.primaryColor,
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Show both pricing pending message AND actual subtotal
                Column(
                  children: [
                    // Pending pricing message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: StyleSystem.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: StyleSystem.warningColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: StyleSystem.warningColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'سيتم تحديد الأسعار النهائية بعد مراجعة الطلب من قبل المحاسب',
                              style: StyleSystem.bodyMedium.copyWith(
                                color: StyleSystem.warningColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Current subtotal
                    _buildSummaryRow(
                      'المجموع الحالي',
                      '${cartProvider.subtotal.toStringAsFixed(2)} ${settingsProvider.currencySymbol}',
                      Icons.calculate_outlined,
                      StyleSystem.primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Total - Show conditionally based on pricing visibility
              if (settingsProvider.showPricesToPublic)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        StyleSystem.successColor.withOpacity(0.1),
                        StyleSystem.successColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: StyleSystem.successColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: StyleSystem.successGradient,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'المجموع الإجمالي',
                        style: StyleSystem.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${cartProvider.total.toStringAsFixed(2)} ${settingsProvider.currencySymbol}',
                        style: StyleSystem.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: StyleSystem.successColor,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Checkout Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _showOrderConfirmationDialog(context, cartProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StyleSystem.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shopping_cart_checkout_rounded,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'إتمام الطلب',
                        style: StyleSystem.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: StyleSystem.titleMedium.copyWith(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: StyleSystem.titleMedium.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showOrderConfirmationDialog(BuildContext context, CustomerCartProvider cartProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  StyleSystem.surfaceDark,
                  StyleSystem.backgroundDark,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: StyleSystem.primaryColor.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        StyleSystem.primaryColor,
                        StyleSystem.secondaryColor,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_cart_checkout_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  'تأكيد الطلب',
                  style: StyleSystem.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // Message
                Text(
                  'هل أنت متأكد من إتمام هذا الطلب؟\nسيتم إرساله للمراجعة من قبل الإدارة',
                  style: StyleSystem.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Order Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: StyleSystem.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: StyleSystem.primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'عدد المنتجات:',
                            style: StyleSystem.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          Text(
                            '${cartProvider.itemCount}',
                            style: StyleSystem.bodyMedium.copyWith(
                              color: StyleSystem.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المجموع:',
                            style: StyleSystem.bodyMedium.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          Text(
                            '${cartProvider.total.toStringAsFixed(2)} ر.س',
                            style: StyleSystem.titleMedium.copyWith(
                              color: StyleSystem.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          'إلغاء',
                          style: StyleSystem.titleMedium.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _confirmOrder(context, cartProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StyleSystem.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'تأكيد',
                          style: StyleSystem.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmOrder(BuildContext context, CustomerCartProvider cartProvider) async {
    // Store the context and check if widget is mounted
    if (!mounted) return;

    final scaffoldContext = context;
    final navigator = Navigator.of(context);

    navigator.pop(); // Close dialog

    // Show loading indicator with proper context handling
    bool isLoadingDialogShown = false;
    try {
      if (mounted) {
        showDialog(
          context: scaffoldContext,
          barrierDismissible: false,
          builder: (dialogContext) => WillPopScope(
            onWillPop: () async => false,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: StyleSystem.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: StyleSystem.primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'جاري إرسال الطلب...',
                        style: StyleSystem.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        isLoadingDialogShown = true;
      }

    try {
      // Get current user with proper context handling
      final supabaseProvider = Provider.of<SupabaseProvider>(scaffoldContext, listen: false);
      final user = supabaseProvider.user;

      if (user == null) {
        // Close loading dialog safely
        if (mounted && isLoadingDialogShown && Navigator.of(scaffoldContext).canPop()) {
          Navigator.of(scaffoldContext).pop();
          isLoadingDialogShown = false;
        }
        if (mounted) {
          _showErrorMessage(scaffoldContext, 'يجب تسجيل الدخول أولاً');
        }
        return;
      }

      // Get user profile
      final userProfile = supabaseProvider.user;

      // Create order using ClientOrdersProvider
      final clientOrdersProvider = Provider.of<ClientOrdersProvider>(scaffoldContext, listen: false);

      // Convert cart items to the format expected by ClientOrdersProvider
      final cartItems = cartProvider.items.map((item) => client_service.CartItem(
        productId: item.productId,
        productName: item.productName,
        productImage: item.productImage ?? '',
        price: item.price,
        quantity: item.quantity,
        category: item.category, // إضافة الفئة
      )).toList();

      // Set cart items in provider
      clientOrdersProvider.setCartItems(cartItems);

      // Create the order
      final orderId = await clientOrdersProvider.createOrder(
        clientId: user.id,
        clientName: userProfile?.name ?? user.email ?? 'عميل',
        clientEmail: user.email ?? '',
        clientPhone: userProfile?.phone ?? '',
        notes: 'طلب من تطبيق العملاء',
        shippingAddress: '', // Address not available in current user model
      );

      // Close loading dialog safely
      if (mounted && isLoadingDialogShown && Navigator.of(scaffoldContext).canPop()) {
        Navigator.of(scaffoldContext).pop();
        isLoadingDialogShown = false;
      }

      if (orderId != null) {
        // Show success message only if widget is still mounted
        if (mounted) {
          _showSuccessMessage(scaffoldContext, orderId);
        }

        // Clear cart
        cartProvider.clearCart();

        // Navigate back to products safely
        if (mounted && Navigator.of(scaffoldContext).canPop()) {
          Navigator.of(scaffoldContext).pop();
        }
      } else {
        if (mounted) {
          _showErrorMessage(scaffoldContext, clientOrdersProvider.error ?? 'فشل في إرسال الطلب');
        }
      }
    } catch (e) {
      // Close loading dialog safely
      if (mounted && isLoadingDialogShown && Navigator.of(scaffoldContext).canPop()) {
        Navigator.of(scaffoldContext).pop();
        isLoadingDialogShown = false;
      }
      if (mounted) {
        _showErrorMessage(scaffoldContext, 'حدث خطأ أثناء إرسال الطلب: $e');
      }
    }
    } catch (e) {
      // Handle any errors in showing the loading dialog
      if (mounted) {
        _showErrorMessage(scaffoldContext, 'حدث خطأ أثناء إرسال الطلب: $e');
      }
    }
  }

  void _showSuccessMessage(BuildContext context, String orderId) {
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                StyleSystem.successColor,
                StyleSystem.successColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'تم إرسال الطلب بنجاح!',
                      style: StyleSystem.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'رقم الطلب: ${orderId.substring(0, 8).toUpperCase()}',
                      style: StyleSystem.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      'سيتم مراجعة طلبك من قبل الإدارة قريباً',
                      style: StyleSystem.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
    } catch (e) {
      // Fallback if SnackBar fails
      print('Error showing success message: $e');
    }
  }

  void _showErrorMessage(BuildContext context, String message) {
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                StyleSystem.errorColor,
                StyleSystem.errorColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: StyleSystem.bodyMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
    } catch (e) {
      // Fallback if SnackBar fails
      print('Error showing error message: $e');
    }
  }
}