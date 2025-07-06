import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/voucher_model.dart';
import '../../models/client_voucher_model.dart';
import '../../utils/accountant_theme_config.dart';

class VoucherCard extends StatefulWidget {

  const VoucherCard({
    super.key,
    this.voucher,
    this.clientVoucher,
    this.onEdit,
    this.onDelete,
    this.onAssign,
    this.onToggleStatus,
    this.showActions = true,
    this.isClientView = false,
  }) : assert(voucher != null || clientVoucher != null, 'Either voucher or clientVoucher must be provided');

  final VoucherModel? voucher;
  final ClientVoucherModel? clientVoucher;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAssign;
  final VoidCallback? onToggleStatus;
  final bool showActions;
  final bool isClientView;

  /// Get the voucher model from either direct voucher or clientVoucher
  VoucherModel get voucherModel => voucher ?? clientVoucher!.voucher!;

  /// Get the client voucher ID if available
  String? get clientVoucherId => clientVoucher?.id;

  @override
  State<VoucherCard> createState() => _VoucherCardState();
}

class _VoucherCardState extends State<VoucherCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 0.4,
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

  void _onHoverChanged(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });

    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) => _onHoverChanged(true),
            onExit: (_) => _onHoverChanged(false),
            child: Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isHovered
                      ? _getStatusColor().withOpacity(0.6)
                      : _getStatusColor().withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  // Basic shadow
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                  // Hover glow effect
                  if (_isHovered)
                    BoxShadow(
                      color: _getStatusColor().withOpacity(_glowAnimation.value),
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                  // Status glow at bottom
                  BoxShadow(
                    color: _getStatusColor().withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getStatusColor().withOpacity(0.8),
                            _getStatusColor().withOpacity(0.6),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.voucherModel.name,
                                  style: AccountantThemeConfig.headlineSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (widget.voucherModel.description != null && widget.voucherModel.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      widget.voucherModel.description!,
                                      style: AccountantThemeConfig.bodyMedium.copyWith(
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _buildStatusChip(),
                        ],
                      ),
                    ),

                    // Content area
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Voucher code
                          _buildVoucherCode(),

                          const SizedBox(height: 16),

                          // Voucher details
                          _buildVoucherDetails(),

                          const SizedBox(height: 16),

                          // Discount and expiration
                          Row(
                            children: [
                              Expanded(
                                child: _buildDiscountInfo(),
                              ),
                              Expanded(
                                child: _buildExpirationInfo(),
                              ),
                            ],
                          ),

                          if (widget.showActions && !widget.isClientView) ...[
                            const SizedBox(height: 16),
                            _buildActionButtons(),
                          ],

                          if (widget.isClientView) ...[
                            const SizedBox(height: 16),
                            _buildClientActions(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor(),
            _getStatusColor().withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        widget.voucherModel.status,
        style: AccountantThemeConfig.bodySmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVoucherCode() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AccountantThemeConfig.primaryGreen.withOpacity(0.1),
            AccountantThemeConfig.primaryGreen.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.local_offer,
              color: AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.voucherModel.code,
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: AccountantThemeConfig.primaryGreen,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Builder(
            builder: (context) => Container(
              decoration: BoxDecoration(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () => _copyToClipboard(widget.voucherModel.code, context),
                icon: Icon(
                  Icons.copy,
                  color: AccountantThemeConfig.primaryGreen,
                  size: 20,
                ),
                tooltip: 'نسخ الكود',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherDetails() {
    return Row(
      children: [
        Expanded(
          child: _buildDetailItem(
            icon: Icons.category,
            label: 'النوع',
            value: widget.voucherModel.type.displayName,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDetailItem(
            icon: Icons.label,
            label: 'المطبق على',
            value: widget.voucherModel.targetName,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AccountantThemeConfig.accentBlue,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AccountantThemeConfig.primaryGreen.withOpacity(0.15),
            AccountantThemeConfig.primaryGreen.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  widget.voucherModel.discountType == DiscountType.percentage
                      ? Icons.percent
                      : Icons.attach_money,
                  color: AccountantThemeConfig.primaryGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.voucherModel.discountType == DiscountType.percentage
                      ? 'نسبة الخصم'
                      : 'مبلغ الخصم',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.voucherModel.formattedDiscount,
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: AccountantThemeConfig.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationInfo() {
    final isExpiringSoon = widget.voucherModel.expiresSoon;
    final color = widget.voucherModel.isExpired
        ? Colors.red
        : isExpiringSoon
            ? Colors.orange
            : AccountantThemeConfig.accentBlue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.access_time,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'تاريخ الانتهاء',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.voucherModel.formattedExpirationDate,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!widget.voucherModel.isExpired && widget.voucherModel.daysUntilExpiration <= 30)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${widget.voucherModel.daysUntilExpiration} يوم متبقي',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (widget.onEdit != null)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.accentBlue.withOpacity(0.1),
                    AccountantThemeConfig.accentBlue.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
                ),
              ),
              child: OutlinedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit, size: 16),
                label: Text(
                  'تعديل',
                  style: AccountantThemeConfig.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AccountantThemeConfig.accentBlue,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        if (widget.onEdit != null && widget.onAssign != null) const SizedBox(width: 12),
        if (widget.onAssign != null)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                    AccountantThemeConfig.primaryGreen.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: OutlinedButton.icon(
                onPressed: widget.voucherModel.isValid ? widget.onAssign : null,
                icon: const Icon(Icons.person_add, size: 16),
                label: Text(
                  'تعيين',
                  style: AccountantThemeConfig.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AccountantThemeConfig.primaryGreen,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        if ((widget.onEdit != null || widget.onAssign != null) && (widget.onToggleStatus != null || widget.onDelete != null))
          const SizedBox(width: 12),
        if (widget.onToggleStatus != null)
          Container(
            decoration: BoxDecoration(
              color: (widget.voucherModel.isActive ? Colors.orange : AccountantThemeConfig.primaryGreen).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (widget.voucherModel.isActive ? Colors.orange : AccountantThemeConfig.primaryGreen).withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: widget.onToggleStatus,
              icon: Icon(
                widget.voucherModel.isActive ? Icons.pause_circle : Icons.play_circle,
                color: widget.voucherModel.isActive ? Colors.orange : AccountantThemeConfig.primaryGreen,
              ),
              tooltip: widget.voucherModel.isActive ? 'إلغاء التفعيل' : 'تفعيل',
            ),
          ),
        if (widget.onDelete != null)
          Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'حذف',
            ),
          ),
      ],
    );
  }

  Widget _buildClientActions() {
    return Builder(
      builder: (context) => Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                    AccountantThemeConfig.primaryGreen.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: OutlinedButton.icon(
                onPressed: () => _copyToClipboard(widget.voucherModel.code, context),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(
                  'نسخ الكود',
                  style: AccountantThemeConfig.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AccountantThemeConfig.primaryGreen,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.blueGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: widget.voucherModel.isValid ? () => _useNow(context) : null,
                icon: const Icon(Icons.shopping_cart, size: 16),
                label: Text(
                  'استخدم الآن',
                  style: AccountantThemeConfig.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (!widget.voucherModel.isActive) return Colors.grey;
    if (widget.voucherModel.isExpired) return Colors.red;
    if (widget.voucherModel.expiresSoon) return Colors.orange;
    return AccountantThemeConfig.primaryGreen;
  }

  void _copyToClipboard(String text, BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الكود: $text',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _useNow(BuildContext context) {
    // Navigate directly to enhanced voucher products screen
    Navigator.of(context).pushNamed(
      '/enhanced-voucher-products',
      arguments: {
        'voucher': widget.voucherModel,
        'clientVoucher': widget.clientVoucher,
        'clientVoucherId': widget.clientVoucherId,
        'highlightEligible': true,
        'filterByEligibility': true,
      },
    );
  }
}
