import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/models/purchase_invoice_models.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/services/purchase_invoice_service.dart';
import 'package:intl/intl.dart';

class FlippableInvoiceCard extends StatefulWidget {
  final PurchaseInvoice invoice;
  final VoidCallback onViewDetails;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final Function(PurchaseInvoice) onStatusChanged;
  final Function(PurchaseInvoice) onEdit;

  const FlippableInvoiceCard({
    super.key,
    required this.invoice,
    required this.onViewDetails,
    required this.onShare,
    required this.onDelete,
    required this.onStatusChanged,
    required this.onEdit,
  });

  @override
  State<FlippableInvoiceCard> createState() => _FlippableInvoiceCardState();
}

class _FlippableInvoiceCardState extends State<FlippableInvoiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'ar');

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
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

  void _flipCard() {
    HapticFeedback.mediumImpact();
    if (_isFlipped) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 180, // Reduced height to prevent overflow
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final isShowingFront = _flipAnimation.value < 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective
              ..rotateY(_flipAnimation.value * math.pi),
            child: isShowingFront ? _buildFrontCard() : _buildBackCard(),
          );
        },
      ),
    );
  }

  Widget _buildFrontCard() {
    return Container(
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        child: InkWell(
          onTap: widget.onViewDetails,
          onLongPress: _flipCard,
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with professional styling
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AccountantThemeConfig.greenGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'فاتورة #${widget.invoice.id.split('-').last}',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusChip(widget.invoice.status),
                  ],
                ),
                const SizedBox(height: 10),
                // Invoice details
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            'المورد:',
                            widget.invoice.supplierName ?? 'غير محدد',
                            Icons.business,
                          ),
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            'التاريخ:',
                            _dateFormat.format(widget.invoice.createdAt),
                            Icons.calendar_today,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: AccountantThemeConfig.greenGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AccountantThemeConfig.formatCurrency(widget.invoice.totalAmount),
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.invoice.itemsCount} منتج',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Compact action buttons with responsive layout
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildCompactActionButton(
                        'التفاصيل',
                        Icons.visibility,
                        const Color(0xFF3B82F6),
                        widget.onViewDetails,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 2,
                      child: _buildCompactActionButton(
                        'مشاركة',
                        Icons.share_rounded,
                        AccountantThemeConfig.primaryGreen,
                        widget.onShare,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildCompactIconButton(
                      Icons.delete,
                      Colors.red,
                      widget.onDelete,
                    ),
                  ],
                ),
                // Compact long press hint
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'اضغط مطولاً للمزيد',
                    style: GoogleFonts.cairo(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
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

  Widget _buildBackCard() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi), // Flip the back side
      child: Container(
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header with flip back button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'خيارات الفاتورة',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: _flipCard,
                      icon: const Icon(
                        Icons.flip_to_front_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'العودة للواجهة الأمامية',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Compact action buttons
                Column(
                  children: [
                    _buildCompactBackActionButton(
                      'تغيير الحالة',
                      Icons.swap_horiz_rounded,
                      AccountantThemeConfig.accentBlue,
                      _showStatusChangeDialog,
                    ),
                    const SizedBox(height: 8),
                    _buildCompactBackActionButton(
                      'تعديل الفاتورة',
                      Icons.edit_rounded,
                      AccountantThemeConfig.primaryGreen,
                      () => widget.onEdit(widget.invoice),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = AccountantThemeConfig.getStatusColor(status);
    String text = AccountantThemeConfig.getStatusText(status);
    IconData icon = AccountantThemeConfig.getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AccountantThemeConfig.primaryGreen,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      height: 32, // Fixed compact height
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 12, color: Colors.white),
        label: Text(
          text,
          style: GoogleFonts.cairo(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(0, 32),
        ),
      ),
    );
  }

  Widget _buildCompactIconButton(
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 14),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactBackActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      width: double.infinity,
      height: 40, // Fixed compact height
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: Colors.white),
        label: Text(
          text,
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          minimumSize: const Size(0, 40),
        ),
      ),
    );
  }

  void _showStatusChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        ),
        title: Text(
          'تغيير حالة الفاتورة',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption('pending', 'قيد الانتظار', Icons.pending_actions_rounded, AccountantThemeConfig.warningOrange),
            const SizedBox(height: 8),
            _buildStatusOption('completed', 'مكتملة', Icons.check_circle_rounded, AccountantThemeConfig.successGreen),
            const SizedBox(height: 8),
            _buildStatusOption('cancelled', 'ملغية', Icons.cancel_rounded, AccountantThemeConfig.dangerRed),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(String status, String label, IconData icon, Color color) {
    final isCurrentStatus = widget.invoice.status == status;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isCurrentStatus
          ? LinearGradient(colors: [color, color.withOpacity(0.8)])
          : null,
        color: isCurrentStatus ? null : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        child: InkWell(
          onTap: isCurrentStatus ? null : () => _changeStatus(status),
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: isCurrentStatus ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isCurrentStatus)
                  const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeStatus(String newStatus) async {
    Navigator.of(context).pop(); // Close dialog

    try {
      final service = PurchaseInvoiceService();

      // Create updated invoice with new status
      final updatedInvoice = widget.invoice.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      final result = await service.updatePurchaseInvoice(updatedInvoice);

      if (result['success'] == true) {
        // Notify parent about the change
        widget.onStatusChanged(updatedInvoice);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم تحديث حالة الفاتورة بنجاح',
                style: GoogleFonts.cairo(color: Colors.white),
              ),
              backgroundColor: AccountantThemeConfig.successGreen,
            ),
          );
        }

        // Flip back to front
        _flipCard();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                (result['message'] as String?) ?? 'فشل في تحديث حالة الفاتورة',
                style: GoogleFonts.cairo(color: Colors.white),
              ),
              backgroundColor: AccountantThemeConfig.dangerRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ غير متوقع',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.dangerRed,
          ),
        );
      }
    }
  }
}
