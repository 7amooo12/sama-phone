import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/providers/client_orders_provider.dart';
import 'package:smartbiztracker_new/services/client_orders_service.dart';
import 'package:smartbiztracker_new/screens/client/checkout_screen.dart';
import 'package:smartbiztracker_new/widgets/cart/cart_voucher_section.dart';
import 'package:smartbiztracker_new/widgets/debug/voucher_debug_widget.dart';
import 'package:smartbiztracker_new/models/client_voucher_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  ClientVoucherModel? _appliedVoucher;
  double _discountAmount = 0.0;

  void _onVoucherApplied(ClientVoucherModel? voucher, double discountAmount) {
    AppLogger.info('🎯 Cart: Voucher applied callback triggered');
    AppLogger.info('   - Voucher: ${voucher?.voucher?.name ?? 'null'}');
    AppLogger.info('   - Discount: ${discountAmount.toStringAsFixed(2)} ج.م');

    setState(() {
      _appliedVoucher = voucher;
      _discountAmount = discountAmount;
    });

    AppLogger.info('✅ Cart: Voucher state updated successfully');
  }

  void _onVoucherRemoved() {
    AppLogger.info('🗑️ Cart: Voucher removed callback triggered');

    setState(() {
      _appliedVoucher = null;
      _discountAmount = 0.0;
    });

    AppLogger.info('✅ Cart: Voucher state cleared successfully');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'السلة',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<ClientOrdersProvider>(
            builder: (context, orderProvider, child) {
              if (orderProvider.cartItems.isEmpty) return const SizedBox.shrink();

              return TextButton(
                onPressed: () => _showClearCartDialog(context, orderProvider),
                child: const Text(
                  'مسح الكل',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<ClientOrdersProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.cartItems.isEmpty) {
            return _buildEmptyCart(context, theme);
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Cart items
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: orderProvider.cartItems.length,
                        itemBuilder: (context, index) {
                          final item = orderProvider.cartItems[index];
                          return _buildCartItem(
                            item,
                            theme,
                            orderProvider,
                            index,
                          ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.3);
                        },
                      ),

                      // Debug widget (only shows in debug mode)
                      const VoucherDebugWidget(),

                      // Voucher section
                      CartVoucherSection(
                        cartItems: orderProvider.cartItems,
                        appliedVoucher: _appliedVoucher,
                        discountAmount: _discountAmount,
                        onVoucherApplied: _onVoucherApplied,
                        onVoucherRemoved: _onVoucherRemoved,
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
                    ],
                  ),
                ),
              ),
              _buildCartSummary(context, theme, orderProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 120,
            color: Colors.grey[300],
          ).animate().scale(duration: 800.ms),

          const SizedBox(height: 24),

          Text(
            'السلة فارغة',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 12),

          Text(
            'أضف بعض المنتجات لتبدأ التسوق',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 500.ms),

          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('تصفح المنتجات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3),
        ],
      ),
    );
  }

  Widget _buildCartItem(
    CartItem item,
    ThemeData theme,
    ClientOrdersProvider orderProvider,
    int index,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // صورة المنتج
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildProductImage(item.productImage),
              ),
            ),

            const SizedBox(width: 12),

            // تفاصيل المنتج
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Price display with voucher discount support
                  _buildItemPriceDisplay(item, theme),

                  const SizedBox(height: 8),

                  // أدوات التحكم في الكمية
                  Row(
                    children: [
                      _buildQuantityButton(
                        icon: Icons.remove,
                        onPressed: () {
                          if (item.quantity > 1) {
                            orderProvider.updateCartItemQuantity(
                              item.productId,
                              item.quantity - 1,
                            );
                          } else {
                            orderProvider.removeFromCart(item.productId);
                          }
                        },
                        theme: theme,
                      ),

                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${item.quantity}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),

                      _buildQuantityButton(
                        icon: Icons.add,
                        onPressed: () {
                          orderProvider.updateCartItemQuantity(
                            item.productId,
                            item.quantity + 1,
                          );
                        },
                        theme: theme,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // السعر الإجمالي وزر الحذف
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => orderProvider.removeFromCart(item.productId),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                ),

                const SizedBox(height: 8),

                Text(
                  '${(item.price * item.quantity).toStringAsFixed(2)} ج.م',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemPriceDisplay(CartItem item, ThemeData theme) {
    // Check if this item has voucher discount applied
    final hasVoucherDiscount = item.hasVoucherDiscount;

    if (hasVoucherDiscount && item.originalPrice != null) {
      // Show original price with strikethrough and discounted price
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Original price with strikethrough
          Text(
            '${item.originalPrice!.toStringAsFixed(2)} ج.م',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.red,
              decorationThickness: 2,
            ),
          ),
          const SizedBox(height: 2),
          // Discounted price
          Row(
            children: [
              Text(
                '${item.price.toStringAsFixed(2)} ج.م',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'خصم',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Regular price display
      return Text(
        '${item.price.toStringAsFixed(2)} ج.م',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      );
    }
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        color: Colors.white,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildProductImage(String imageUrl) {
    if (imageUrl.isEmpty || imageUrl.startsWith('assets/')) {
      return Container(
        color: Colors.grey[200],
        child: Icon(
          Icons.image_not_supported,
          size: 30,
          color: Colors.grey[400],
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[200],
        child: Icon(
          Icons.broken_image,
          size: 30,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildCartSummary(BuildContext context, ThemeData theme, ClientOrdersProvider orderProvider) {
    final subtotal = orderProvider.cartTotal;
    final finalTotal = subtotal - _discountAmount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Subtotal
          _buildSummaryRow('المجموع الفرعي', subtotal, theme),

          // Discount (if applied)
          if (_appliedVoucher != null && _discountAmount > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              'الخصم',
              -_discountAmount,
              theme,
              subtitle: _appliedVoucher!.voucher?.name,
              isDiscount: true,
            ),
          ],

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          // Final total
          _buildSummaryRow('الإجمالي النهائي', finalTotal, theme, isTotal: true),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: orderProvider.isLoading ? null : () => _proceedToCheckout(context, orderProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: orderProvider.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'إتمام الطلب (${finalTotal.toStringAsFixed(2)} ج.م)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount,
    ThemeData theme, {
    bool isTotal = false,
    bool isDiscount = false,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 18 : 16,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDiscount ? Colors.green : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          Text(
            '${amount.toStringAsFixed(2)} ج.م',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 18 : 16,
              color: isTotal
                  ? theme.colorScheme.primary
                  : isDiscount
                      ? Colors.green
                      : null,
            ),
          ),
        ],
      ),
    );
  }

  void _proceedToCheckout(BuildContext context, ClientOrdersProvider orderProvider) {
    // Pass voucher data to checkout screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          appliedVoucher: _appliedVoucher,
          discountAmount: _discountAmount,
          originalTotal: orderProvider.cartTotal,
          finalTotal: orderProvider.cartTotal - _discountAmount,
        ),
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, ClientOrdersProvider orderProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح السلة'),
        content: const Text('هل أنت متأكد من مسح جميع المنتجات من السلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              orderProvider.clearCart();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم مسح السلة'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('مسح', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
