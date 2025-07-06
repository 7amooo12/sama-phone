import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../providers/voucher_cart_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../providers/simplified_product_provider.dart';
import '../../models/voucher_model.dart';
import '../../models/product_model.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../widgets/common/custom_loader.dart';

/// Dedicated voucher cart screen for voucher-based shopping
/// Displays voucher cart items with discount breakdowns and savings highlights
class VoucherCartScreen extends StatefulWidget {
  const VoucherCartScreen({
    super.key,
    this.voucher,
  });

  final VoucherModel? voucher;

  @override
  State<VoucherCartScreen> createState() => _VoucherCartScreenState();
}

class _VoucherCartScreenState extends State<VoucherCartScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'ج.م',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeVoucherCart();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  void _initializeVoucherCart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voucherCartProvider = Provider.of<VoucherCartProvider>(context, listen: false);
      
      // Set voucher if provided and not already set
      if (widget.voucher != null && voucherCartProvider.appliedVoucher == null) {
        voucherCartProvider.setVoucher(widget.voucher!);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: Consumer<VoucherCartProvider>(
          builder: (context, voucherCartProvider, child) {
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(voucherCartProvider),
                if (voucherCartProvider.isEmpty)
                  _buildEmptyCart()
                else ...[
                  _buildVoucherInfo(voucherCartProvider),
                  _buildCartItems(voucherCartProvider),
                  _buildCartSummary(voucherCartProvider),
                  _buildCheckoutSection(voucherCartProvider),
                ],
                // Add bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(VoucherCartProvider voucherCartProvider) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'سلة القسائم',
          style: AccountantThemeConfig.headlineMedium.copyWith(
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: Stack(
            children: [
              Positioned(
                right: 20,
                top: 60,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_offer,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${voucherCartProvider.itemCount} منتج',
                        style: AccountantThemeConfig.bodySmall.copyWith(
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
      actions: [
        if (!voucherCartProvider.isEmpty)
          IconButton(
            onPressed: () => _showClearCartDialog(voucherCartProvider),
            icon: const Icon(Icons.clear_all),
            tooltip: 'مسح السلة',
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.cardGradient,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: AccountantThemeConfig.cardShadows,
                  ),
                  child: Icon(
                    Icons.local_offer_outlined,
                    size: 80,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                ).animate().scale(delay: const Duration(milliseconds: 200)),
                const SizedBox(height: 24),
                Text(
                  'سلة القسائم فارغة',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                  ),
                ).animate().fadeIn(delay: const Duration(milliseconds: 400)),
                const SizedBox(height: 12),
                Text(
                  'ابدأ بإضافة المنتجات المؤهلة للقسيمة\nللاستفادة من الخصومات المتاحة',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: const Duration(milliseconds: 600)),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.shopping_bag, color: Colors.white),
                    label: Text(
                      'تصفح المنتجات',
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                ).animate().fadeIn(delay: const Duration(milliseconds: 800)).scale(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoucherInfo(VoucherCartProvider voucherCartProvider) {
    final voucher = voucherCartProvider.appliedVoucher;
    if (voucher == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
          gradient: AccountantThemeConfig.greenGradient,
          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_offer,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.name,
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'خصم ${voucher.discountPercentage}%',
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'نشط',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إجمالي التوفير:',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(voucherCartProvider.totalSavings),
                    style: AccountantThemeConfig.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: const Duration(milliseconds: 200)).slideX(begin: -0.3),
    );
  }

  Widget _buildCartItems(VoucherCartProvider voucherCartProvider) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = voucherCartProvider.voucherCartItems[index];
            return _buildCartItemCard(item, voucherCartProvider, index);
          },
          childCount: voucherCartProvider.voucherCartItems.length,
        ),
      ),
    );
  }

  Widget _buildCartItemCard(dynamic item, VoucherCartProvider voucherCartProvider, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AccountantThemeConfig.cardBackground1,
                borderRadius: BorderRadius.circular(12),
                border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.productImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.productImage,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const CustomLoader(message: 'جاري التحميل...'),
                        errorWidget: (context, url, error) => Icon(
                          Icons.image_not_supported,
                          color: AccountantThemeConfig.primaryGreen,
                        ),
                      )
                    : Icon(
                        Icons.inventory_2,
                        color: AccountantThemeConfig.primaryGreen,
                        size: 32,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Voucher Badge and Stock Info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.greenGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_offer,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${item.voucherName ?? 'قسيمة'}',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Stock availability indicator
                      Consumer<SimplifiedProductProvider>(
                        builder: (context, productProvider, child) {
                          final product = productProvider.products.firstWhere(
                            (p) => p.id == item.productId,
                            orElse: () => ProductModel(
                              id: '',
                              name: '',
                              description: '',
                              price: 0,
                              quantity: 0,
                              category: '',
                              createdAt: DateTime.now(),
                              isActive: false,
                              sku: '',
                              reorderPoint: 0,
                              images: [],
                            ),
                          );

                          if (product.id.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AccountantThemeConfig.dangerRed,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'غير متوفر',
                                style: AccountantThemeConfig.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: product.quantity > 10
                                  ? AccountantThemeConfig.primaryGreen
                                  : product.quantity > 0
                                      ? AccountantThemeConfig.warningOrange
                                      : AccountantThemeConfig.dangerRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'متوفر: ${product.quantity}',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Price Information
                  if (item.originalPrice != null) ...[
                    Row(
                      children: [
                        Text(
                          _currencyFormat.format(item.originalPrice!),
                          style: AccountantThemeConfig.bodyMedium.copyWith(
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currencyFormat.format(item.price),
                          style: AccountantThemeConfig.bodyLarge.copyWith(
                            color: AccountantThemeConfig.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'وفرت ${_currencyFormat.format((item.originalPrice! - item.price) * item.quantity)}',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else ...[
                    Text(
                      _currencyFormat.format(item.price),
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Quantity Controls
            _buildQuantityControls(item, voucherCartProvider),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).slideX(begin: 0.3);
  }

  Widget _buildQuantityControls(dynamic item, VoucherCartProvider voucherCartProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.primaryGreen.withOpacity(0.1),
            AccountantThemeConfig.secondaryGreen.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
      ),
      child: Column(
        children: [
          // Increase Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                try {
                  voucherCartProvider.updateVoucherCartItemQuantity(
                    item.productId as String,
                    (item.quantity as int) + 1,
                  );
                  // Check for errors after update
                  if (voucherCartProvider.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(voucherCartProvider.error!),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('حدث خطأ في تحديث الكمية: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.add,
                  color: AccountantThemeConfig.primaryGreen,
                  size: 20,
                ),
              ),
            ),
          ),
          // Quantity Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                ),
              ),
            ),
            child: Text(
              '${item.quantity}',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: AccountantThemeConfig.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Decrease Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => voucherCartProvider.updateVoucherCartItemQuantity(
                item.productId as String,
                (item.quantity as int) - 1,
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.remove,
                  color: AccountantThemeConfig.primaryGreen,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(VoucherCartProvider voucherCartProvider) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص الطلب',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
              'السعر الأصلي:',
              _currencyFormat.format(voucherCartProvider.totalOriginalPrice),
              isOriginal: true,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'الخصم:',
              '- ${_currencyFormat.format(voucherCartProvider.totalSavings)}',
              isDiscount: true,
            ),
            const Divider(color: Colors.white24, height: 24),
            _buildSummaryRow(
              'الإجمالي النهائي:',
              _currencyFormat.format(voucherCartProvider.totalDiscountedPrice),
              isFinal: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إجمالي التوفير:',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(voucherCartProvider.totalSavings),
                    style: AccountantThemeConfig.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: const Duration(milliseconds: 400)).slideY(begin: 0.3),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isOriginal = false, bool isDiscount = false, bool isFinal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: isOriginal ? Colors.grey : Colors.white,
            decoration: isOriginal ? TextDecoration.lineThrough : null,
          ),
        ),
        Text(
          value,
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: isDiscount
                ? AccountantThemeConfig.primaryGreen
                : isFinal
                    ? AccountantThemeConfig.primaryGreen
                    : isOriginal
                        ? Colors.grey
                        : Colors.white,
            fontWeight: isFinal ? FontWeight.bold : FontWeight.normal,
            fontSize: isFinal ? 18 : 16,
            decoration: isOriginal ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutSection(VoucherCartProvider voucherCartProvider) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.greenGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
          ),
          child: ElevatedButton.icon(
            onPressed: () => _proceedToCheckout(voucherCartProvider),
            icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
            label: Text(
              'إتمام الطلب',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 20),
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ).animate().fadeIn(delay: const Duration(milliseconds: 600)).scale(),
    );
  }

  void _showClearCartDialog(VoucherCartProvider voucherCartProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.luxuryBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'مسح سلة القسائم',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: Colors.white,
          ),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في مسح جميع المنتجات من سلة القسائم؟',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.grey,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.redGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () {
                voucherCartProvider.clearVoucherCart();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('تم مسح سلة القسائم'),
                    backgroundColor: AccountantThemeConfig.primaryGreen,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: Text(
                'مسح',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _proceedToCheckout(VoucherCartProvider voucherCartProvider) {
    // Navigate to voucher checkout screen
    Navigator.pushNamed(
      context,
      '/voucher-checkout',
      arguments: {
        'voucherCartSummary': voucherCartProvider.getVoucherCartSummary(),
        'voucher': voucherCartProvider.appliedVoucher,
      },
    );
  }
}
