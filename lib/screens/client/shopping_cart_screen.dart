import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/client_orders_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/simplified_product_provider.dart';
import '../../services/client_orders_service.dart' as client_service;
import '../../config/style_system.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../models/product_model.dart';
import '../../widgets/common/optimized_image.dart';

class ShoppingCartScreen extends StatefulWidget {
  const ShoppingCartScreen({super.key});

  @override
  State<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends State<ShoppingCartScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'ج.م',
    decimalDigits: 2,
  );

  /// Calculate subtotal from cart items
  double get subtotal {
    final cartProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
    return cartProvider.cartItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
  }

  /// Calculate discount from cart items (voucher discounts)
  double get discount {
    final cartProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
    return cartProvider.cartItems.fold<double>(
      0.0,
      (sum, item) => sum + item.totalSavings,
    );
  }

  /// Calculate total after discount
  double get total {
    return subtotal - discount;
  }

  /// Helper method to get properly formatted image URL like the working product details screen
  String _getImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return 'https://via.placeholder.com/400x400/E0E0E0/757575?text=لا+توجد+صورة';
    }

    if (imageUrl.startsWith('http')) {
      return imageUrl;
    } else {
      return 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      appBar: AppBar(
        backgroundColor: AccountantThemeConfig.luxuryBlack,
        title: Text(
          'سلة التسوق',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: Consumer<ClientOrdersProvider>(
          builder: (context, cartProvider, child) {
            if (cartProvider.cartItems.isEmpty) {
              return _buildEmptyCart();
            }

            return Column(
              children: [
                // Cart Items List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartProvider.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartProvider.cartItems[index];
                      return _buildCartItemCard(item, cartProvider);
                    },
                  ),
                ),

                // Cart Summary and Checkout
                _buildCartSummary(cartProvider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: AccountantThemeConfig.transparentCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                shape: BoxShape.circle,
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'سلة التسوق فارغة',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'أضف بعض المنتجات لتبدأ التسوق',
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
                icon: const Icon(Icons.shopping_bag),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemCard(client_service.CartItem item, ClientOrdersProvider cartProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16), // Reduced from 20 to 16
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        children: [
          // Top Row: Image and Product Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: OptimizedImage(
                  imageUrl: _getImageUrl(item.productImage),
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.cardGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: Colors.white54,
                      size: 30,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16), // Increased spacing

              // Product Details - Now with more space
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      item.productName,
                      style: AccountantThemeConfig.bodyLarge.copyWith( // Changed from headlineSmall
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16, // Explicit font size
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6), // Reduced spacing

                    // Category
                    if (item.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.blueGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.category,
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
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
                              color: AccountantThemeConfig.dangerRed,
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
                                  style: AccountantThemeConfig.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final isAvailable = product.quantity > 0;
                        final stockColor = product.quantity > 10
                            ? AccountantThemeConfig.primaryGreen
                            : product.quantity > 0
                                ? AccountantThemeConfig.warningOrange
                                : AccountantThemeConfig.dangerRed;

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
                                style: AccountantThemeConfig.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    // Price per unit and total - Hidden during pricing approval workflow
                    Consumer<AppSettingsProvider>(
                      builder: (context, settingsProvider, child) {
                        if (settingsProvider.showPricesToPublic) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'السعر: ',
                                    style: AccountantThemeConfig.bodySmall.copyWith(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${item.price.toStringAsFixed(0)} ج.م',
                                    style: AccountantThemeConfig.bodyMedium.copyWith(
                                      color: AccountantThemeConfig.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'المجموع: ',
                                    style: AccountantThemeConfig.bodySmall.copyWith(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${(item.price * item.quantity).toStringAsFixed(0)} ج.م',
                                    style: AccountantThemeConfig.bodyMedium.copyWith(
                                      color: AccountantThemeConfig.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        } else {
                          // Show both pricing pending message AND actual price
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Pending pricing message
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 12,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'في انتظار التسعير',
                                      style: AccountantThemeConfig.bodySmall.copyWith(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Actual price information
                              Row(
                                children: [
                                  Text(
                                    'السعر الحالي: ',
                                    style: AccountantThemeConfig.bodySmall.copyWith(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${item.price.toStringAsFixed(0)} ج.م',
                                    style: AccountantThemeConfig.bodyMedium.copyWith(
                                      color: AccountantThemeConfig.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'المجموع: ',
                                    style: AccountantThemeConfig.bodySmall.copyWith(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${(item.price * item.quantity).toStringAsFixed(0)} ج.م',
                                    style: AccountantThemeConfig.bodyMedium.copyWith(
                                      color: AccountantThemeConfig.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16), // Spacing between sections

          // Bottom Row: Quantity Controls and Remove Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Quantity Controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'الكمية: ',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.red, Colors.redAccent],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: AccountantThemeConfig.glowShadows(Colors.red),
                    ),
                    child: IconButton(
                      onPressed: () => cartProvider.decreaseQuantity(item.productId),
                      icon: const Icon(Icons.remove),
                      color: Colors.white,
                      iconSize: 16, // Reduced size
                      padding: const EdgeInsets.all(8), // Reduced padding
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8), // Reduced margin
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced padding
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.greenGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                    ),
                    child: Text(
                      '${item.quantity}',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.greenGradient,
                      shape: BoxShape.circle,
                      boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                    ),
                    child: IconButton(
                      onPressed: () => cartProvider.increaseQuantity(item.productId),
                      icon: const Icon(Icons.add),
                      color: Colors.white,
                      iconSize: 16, // Reduced size
                      padding: const EdgeInsets.all(8), // Reduced padding
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                ],
              ),

              // Remove Button
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.redAccent],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AccountantThemeConfig.glowShadows(Colors.red),
                ),
                child: TextButton.icon(
                  onPressed: () => cartProvider.removeFromCart(item.productId),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text(
                    'حذف',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(ClientOrdersProvider cartProvider) {
    final totalAmount = cartProvider.totalAmount;
    final itemCount = cartProvider.cartItems.length;
    final totalQuantity = cartProvider.cartItems.fold<int>(0, (sum, item) => sum + item.quantity);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), // Responsive padding
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Minimize space usage
          children: [
            // Cart Summary Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Items Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'عدد الأصناف:',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$itemCount صنف',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Total Quantity
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي الكمية:',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$totalQuantity قطعة',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AccountantThemeConfig.primaryGreen.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Total Amount - Hidden during pricing approval workflow
                  Consumer<AppSettingsProvider>(
                    builder: (context, settingsProvider, child) {
                      if (settingsProvider.showPricesToPublic) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'المجموع الكلي:',
                              style: AccountantThemeConfig.headlineSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${totalAmount.toStringAsFixed(0)} ج.م',
                              style: AccountantThemeConfig.headlineMedium.copyWith(
                                color: AccountantThemeConfig.primaryGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Show both pricing pending message AND actual totals
                        return Column(
                          children: [
                            // Pending pricing message
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'سيتم تحديد الأسعار النهائية بعد مراجعة الطلب من قبل المحاسب',
                                      style: AccountantThemeConfig.bodyMedium.copyWith(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Current pricing information
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: AccountantThemeConfig.cardGradient,
                                borderRadius: BorderRadius.circular(12),
                                border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'الأسعار الحالية:',
                                        style: AccountantThemeConfig.bodyMedium.copyWith(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'المجموع الفرعي:',
                                        style: AccountantThemeConfig.bodyMedium.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '${subtotal.toStringAsFixed(0)} ج.م',
                                        style: AccountantThemeConfig.bodyMedium.copyWith(
                                          color: AccountantThemeConfig.primaryGreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (discount > 0) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'الخصم:',
                                          style: AccountantThemeConfig.bodyMedium.copyWith(
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          '-${discount.toStringAsFixed(0)} ج.م',
                                          style: AccountantThemeConfig.bodyMedium.copyWith(
                                            color: AccountantThemeConfig.warningOrange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const Divider(color: Colors.white24, height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'الإجمالي:',
                                        style: AccountantThemeConfig.headlineSmall.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${total.toStringAsFixed(0)} ج.م',
                                        style: AccountantThemeConfig.headlineSmall.copyWith(
                                          color: AccountantThemeConfig.primaryGreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Checkout Button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: ElevatedButton.icon(
                onPressed: () => _proceedToCheckout(cartProvider),
                icon: const Icon(
                  Icons.shopping_cart_checkout,
                  size: 24,
                ),
                label: Text(
                  'إتمام الطلب',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18), // Responsive padding
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// REQUIREMENT 4: Order submission using existing system
  Future<void> _proceedToCheckout(ClientOrdersProvider cartProvider) async {
    if (!mounted) return;

    try {
      // Get current user information
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final currentUser = supabaseProvider.user;

      if (currentUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'يجب تسجيل الدخول أولاً',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AccountantThemeConfig.primaryGreen),
        ),
      );

      // Submit order using existing system with user information
      await cartProvider.submitOrder(
        clientId: currentUser.id,
        clientName: currentUser.name ?? currentUser.email ?? 'عميل',
        clientEmail: currentUser.email ?? '',
        clientPhone: currentUser.phone ?? '',
      );

      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلبك بنجاح! سيتم مراجعته قريباً',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back to products
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);

      AppLogger.info('🛒 Order submitted successfully with ${cartProvider.cartItems.length} items');
    } catch (e) {
      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      AppLogger.error('❌ Error submitting order: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ في إرسال الطلب: ${e.toString()}',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
