import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:share_plus/share_plus.dart';
import 'package:smartbiztracker_new/models/product_model.dart';

class ARResultActions extends StatefulWidget {

  const ARResultActions({
    super.key,
    required this.resultImage,
    required this.product,
    required this.onSave,
    required this.onShare,
    required this.onAddToCart,
    required this.onRetry,
  });
  final File? resultImage;
  final ProductModel product;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onAddToCart;
  final VoidCallback onRetry;

  @override
  State<ARResultActions> createState() => _ARResultActionsState();
}

class _ARResultActionsState extends State<ARResultActions>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _bounceController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _bounceAnimation;

  bool _isVisible = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _showActions();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
  }

  void _showActions() {
    setState(() => _isVisible = true);
    _slideController.forward();
  }

  void _hideActions() {
    _slideController.reverse().then((_) {
      setState(() => _isVisible = false);
    });
  }

  Future<void> _handleSave() async {
    if (widget.resultImage == null) return;

    setState(() => _isProcessing = true);
    _bounceController.forward().then((_) => _bounceController.reverse());
    HapticFeedback.mediumImpact();

    try {
      widget.onSave();
      _showSuccessSnackBar('تم حفظ الصورة بنجاح!');
    } catch (e) {
      _showErrorSnackBar('فشل في حفظ الصورة');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleShare() async {
    if (widget.resultImage == null) return;

    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      // TODO: Implement share functionality
      // await Share.shareXFiles(
      //   [XFile(widget.resultImage!.path)],
      //   text: 'شاهد كيف تبدو ${widget.product.name} في مساحتي! 🏠✨\n\nتم إنشاؤها باستخدام تطبيق SAMA AR',
      //   subject: 'تجربة AR - ${widget.product.name}',
      // );

      widget.onShare();
      _showSuccessSnackBar('تم تحضير الصورة للمشاركة!');
    } catch (e) {
      _showErrorSnackBar('فشل في مشاركة الصورة');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _handleAddToCart() {
    HapticFeedback.heavyImpact();
    widget.onAddToCart();
    _showSuccessSnackBar('تم إضافة ${widget.product.name} إلى السلة!');
  }

  void _handleRetry() {
    HapticFeedback.lightImpact();
    _hideActions();
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // Product info
            _buildProductInfo(theme),

            const SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(theme),

            const SizedBox(height: 16),

            // Secondary actions
            _buildSecondaryActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo(ThemeData theme) {
    return Row(
      children: [
        // Product image placeholder
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.dividerColor,
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.lightbulb_outline,
            color: Colors.grey,
            size: 30,
          ),
        ),

        const SizedBox(width: 16),

        // Product details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              if (widget.product.price > 0)
                Text(
                  '${widget.product.price.toStringAsFixed(0)} ج.م',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              const SizedBox(height: 4),

              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'تم إنشاء المعاينة بنجاح',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
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

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        // Add to cart button
        Expanded(
          flex: 2,
          child: AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _bounceAnimation.value,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _handleAddToCart,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('أضف للسلة'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(width: 12),

        // Save button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : _handleSave,
            icon: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt),
            label: const Text('حفظ'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Share button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : _handleShare,
            icon: const Icon(Icons.share),
            label: const Text('مشاركة'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryActions(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton.icon(
          onPressed: _handleRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),

        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          label: const Text('إغلاق'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
