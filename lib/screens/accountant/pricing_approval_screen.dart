import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/providers/pricing_approval_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/app_settings_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// شاشة اعتماد التسعير للمحاسبين
/// تسمح للمحاسب بمراجعة وتعديل أسعار المنتجات في الطلبات المعلقة
class PricingApprovalScreen extends StatefulWidget {
  final ClientOrder order;

  const PricingApprovalScreen({
    super.key,
    required this.order,
  });

  @override
  State<PricingApprovalScreen> createState() => _PricingApprovalScreenState();
}

class _PricingApprovalScreenState extends State<PricingApprovalScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, FocusNode> _priceFocusNodes = {};

  bool _isLoading = false;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePriceControllers();
    _calculateTotal();
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

  void _initializePriceControllers() {
    for (final item in widget.order.items) {
      final controller = TextEditingController(
        text: item.price.toStringAsFixed(2),
      );
      _priceControllers[item.productId] = controller;
      _priceFocusNodes[item.productId] = FocusNode();

      // Listen for price changes
      controller.addListener(() {
        _calculateTotal();
      });
    }
  }

  void _calculateTotal() {
    double total = 0.0;
    for (final item in widget.order.items) {
      final controller = _priceControllers[item.productId];
      if (controller != null) {
        final price = double.tryParse(controller.text) ?? 0.0;
        total += price * item.quantity;
      }
    }
    if (mounted) {
      setState(() {
        _totalAmount = total;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _priceFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AccountantThemeConfig.darkBlueBlack,
      elevation: 0,
      title: Text(
        'اعتماد التسعير',
        style: AccountantThemeConfig.headlineMedium,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.blueGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'طلب #${widget.order.id.substring(0, 8).toUpperCase()}',
            style: AccountantThemeConfig.labelMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildOrderSummaryCard(),
          Expanded(
            child: _buildProductsList(),
          ),
          _buildTotalCard(),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.order.clientName,
                      style: AccountantThemeConfig.headlineSmall,
                    ),
                    Text(
                      widget.order.clientEmail,
                      style: AccountantThemeConfig.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(
                Icons.shopping_bag_outlined,
                '${widget.order.items.length} منتج',
                AccountantThemeConfig.accentBlue,
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                Icons.access_time_rounded,
                _formatDate(widget.order.createdAt),
                AccountantThemeConfig.warningOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: AccountantThemeConfig.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.order.items.length,
      itemBuilder: (context, index) {
        final item = widget.order.items[index];
        return _buildProductCard(item, index);
      },
    );
  }

  Widget _buildProductCard(OrderItem item, int index) {
    final controller = _priceControllers[item.productId]!;
    final focusNode = _priceFocusNodes[item.productId]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Product Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: AccountantThemeConfig.cardGradient,
                ),
                child: item.productImage.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.productImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildProductPlaceholder(),
                        ),
                      )
                    : _buildProductPlaceholder(),
              ),
              const SizedBox(width: 16),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: AccountantThemeConfig.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الكمية: ${item.quantity}',
                      style: AccountantThemeConfig.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Pricing Section
          _buildPricingSection(item, controller, focusNode),
        ],
      ),
    );
  }

  Widget _buildProductPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: Colors.white54,
        size: 30,
      ),
    );
  }

  Widget _buildPricingSection(OrderItem item, TextEditingController controller, FocusNode focusNode) {
    final originalPrice = item.price;
    final currentPrice = double.tryParse(controller.text) ?? originalPrice;
    final priceDifference = currentPrice - originalPrice;
    final subtotal = currentPrice * item.quantity;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          // Original Price Display
          Row(
            children: [
              Icon(
                Icons.label_outline_rounded,
                size: 16,
                color: AccountantThemeConfig.accentBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'السعر الأصلي:',
                style: AccountantThemeConfig.bodyMedium,
              ),
              const Spacer(),
              Text(
                '${originalPrice.toStringAsFixed(2)} ج.م',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Price Input Field
          Row(
            children: [
              Icon(
                Icons.edit_rounded,
                size: 16,
                color: AccountantThemeConfig.primaryGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'السعر المعتمد:',
                style: AccountantThemeConfig.bodyMedium,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: AccountantThemeConfig.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    suffixText: 'ج.م',
                    suffixStyle: AccountantThemeConfig.bodyMedium,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AccountantThemeConfig.primaryGreen,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال السعر';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'يرجى إدخال سعر صحيح';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Price Difference and Subtotal
          Row(
            children: [
              // Price Difference
              if (priceDifference != 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priceDifference > 0
                        ? AccountantThemeConfig.primaryGreen.withOpacity(0.2)
                        : AccountantThemeConfig.dangerRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        priceDifference > 0 ? Icons.trending_up : Icons.trending_down,
                        size: 14,
                        color: priceDifference > 0
                            ? AccountantThemeConfig.primaryGreen
                            : AccountantThemeConfig.dangerRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${priceDifference > 0 ? '+' : ''}${priceDifference.toStringAsFixed(2)}',
                        style: AccountantThemeConfig.labelSmall.copyWith(
                          color: priceDifference > 0
                              ? AccountantThemeConfig.primaryGreen
                              : AccountantThemeConfig.dangerRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Subtotal
              Text(
                'المجموع: ${subtotal.toStringAsFixed(2)} ج.م',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calculate_rounded,
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
                  'إجمالي الطلب',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_totalAmount.toStringAsFixed(2)} ج.م',
                  style: AccountantThemeConfig.headlineLarge.copyWith(
                    color: Colors.white,
                    fontSize: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Notes Field
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            style: AccountantThemeConfig.bodyMedium,
            decoration: InputDecoration(
              labelText: 'ملاحظات التسعير (اختياري)',
              labelStyle: AccountantThemeConfig.bodyMedium,
              hintText: 'أضف أي ملاحظات حول التسعير المعتمد...',
              hintStyle: AccountantThemeConfig.bodySmall,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.primaryGreen,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'رفض التسعير',
                  Icons.cancel_rounded,
                  AccountantThemeConfig.redGradient,
                  _rejectPricing,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildActionButton(
                  'اعتماد التسعير',
                  Icons.check_circle_rounded,
                  AccountantThemeConfig.greenGradient,
                  _approvePricing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    LinearGradient gradient,
    VoidCallback onPressed,
  ) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading && onPressed == _approvePricing) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ] else ...[
                  Icon(icon, color: Colors.white, size: 20),
                ],
                const SizedBox(width: 12),
                Text(
                  text,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approvePricing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final currentUser = supabaseProvider.user;

      if (currentUser == null) {
        _showErrorMessage('خطأ في المصادقة');
        return;
      }

      // Prepare pricing data
      final List<Map<String, dynamic>> pricingItems = [];
      for (final item in widget.order.items) {
        final controller = _priceControllers[item.productId];
        if (controller != null) {
          final approvedPrice = double.tryParse(controller.text) ?? item.price;

          // Debug: Log the item data to understand what we're working with
          AppLogger.info('🔍 Item data: id=${item.id}, productId=${item.productId}, name=${item.productName}');

          pricingItems.add({
            'item_id': item.productId, // Use product_id as expected by the fixed stored procedure
            'approved_price': approvedPrice,
          });
        }
      }

      // Debug: Log the complete pricing items array
      AppLogger.info('🔍 Complete pricingItems array: $pricingItems');

      final pricingProvider = Provider.of<PricingApprovalProvider>(context, listen: false);

      AppLogger.info('Attempting to approve pricing for order: ${widget.order.id}');
      AppLogger.info('Pricing items: $pricingItems');

      final success = await pricingProvider.approveOrderPricing(
        orderId: widget.order.id,
        approvedBy: currentUser.id,
        approvedByName: currentUser.email ?? 'محاسب',
        pricingItems: pricingItems,
        notes: _notesController.text.trim(),
      );

      if (success) {
        // ===== PRICING APPROVAL WORKFLOW =====
        // Restore price visibility after successful pricing approval
        AppLogger.info('🔓 Pricing approved successfully - restoring price visibility');

        try {
          final appSettingsProvider = Provider.of<AppSettingsProvider>(context, listen: false);
          await appSettingsProvider.restorePricesAfterApproval();
          AppLogger.info('✅ Successfully restored price visibility after pricing approval');
        } catch (e) {
          AppLogger.error('❌ Failed to restore price visibility after pricing approval: $e');
          // Don't fail the entire operation if price restoration fails
        }

        _showSuccessMessage('تم اعتماد التسعير بنجاح');
        Navigator.of(context).pop(true); // Return true to indicate success
      } else {
        _showErrorMessage('فشل في اعتماد التسعير');
      }
    } catch (e) {
      AppLogger.error('Error approving pricing: $e');
      _showErrorMessage('حدث خطأ أثناء اعتماد التسعير');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectPricing() async {
    final confirmed = await _showConfirmationDialog(
      'تأكيد الرفض',
      'هل أنت متأكد من رفض تسعير هذا الطلب؟\nسيتم إلغاء الطلب نهائياً.',
      'رفض',
      AccountantThemeConfig.dangerRed,
    );

    if (confirmed == true) {
      Navigator.of(context).pop(false); // Return false to indicate rejection
    }
  }

  Future<bool?> _showConfirmationDialog(
    String title,
    String content,
    String confirmText,
    Color confirmColor,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        title: Text(
          title,
          style: AccountantThemeConfig.headlineSmall,
        ),
        content: Text(
          content,
          style: AccountantThemeConfig.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyMedium,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AccountantThemeConfig.dangerRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
