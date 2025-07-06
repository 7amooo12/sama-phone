import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/providers/pending_orders_provider.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:intl/intl.dart';

class AccountantOrderDetailsScreen extends StatefulWidget {
  final ClientOrder order;

  const AccountantOrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  State<AccountantOrderDetailsScreen> createState() => _AccountantOrderDetailsScreenState();
}

class _AccountantOrderDetailsScreenState extends State<AccountantOrderDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل الطلب #${widget.order.id.substring(0, 8).toUpperCase()}'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderHeader(theme),
            const SizedBox(height: 24),
            _buildCustomerInfo(theme),
            const SizedBox(height: 24),
            _buildOrderItems(theme),
            const SizedBox(height: 24),
            _buildOrderSummary(theme),
            const SizedBox(height: 24),
            _buildActionButtons(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'طلب رقم',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
              _buildStatusChip(widget.order.statusText),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '#${widget.order.id.substring(0, 8).toUpperCase()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Colors.white.withValues(alpha: 0.9),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'تاريخ الطلب: ${_formatDate(widget.order.createdAt)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    IconData chipIcon;

    switch (status.toLowerCase()) {
      case 'معلق':
      case 'pending':
        chipColor = Colors.orange;
        chipIcon = Icons.hourglass_empty;
        break;
      case 'قيد التنفيذ':
      case 'processing':
        chipColor = Colors.blue;
        chipIcon = Icons.settings;
        break;
      case 'مكتمل':
      case 'completed':
        chipColor = Colors.green;
        chipIcon = Icons.check_circle;
        break;
      case 'ملغي':
      case 'cancelled':
        chipColor = Colors.red;
        chipIcon = Icons.cancel;
        break;
      default:
        chipColor = Colors.grey;
        chipIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: chipColor.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            chipIcon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'معلومات العميل',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.person_outline, 'اسم العميل', widget.order.clientName, theme),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, 'رقم الهاتف', widget.order.clientPhone.isNotEmpty ? widget.order.clientPhone : 'غير محدد', theme),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.email, 'البريد الإلكتروني', widget.order.clientEmail.isNotEmpty ? widget.order.clientEmail : 'غير محدد', theme),
            if (widget.order.shippingAddress != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.location_on, 'عنوان الشحن', widget.order.shippingAddress!, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItems(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shopping_bag,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'عناصر الطلب (${widget.order.items.length})',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...widget.order.items.map((item) => _buildOrderItem(item, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.surface,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.productImage.isNotEmpty
                  ? Image.network(
                      item.productImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: theme.colorScheme.surface,
                          child: Icon(
                            Icons.image_not_supported,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: theme.colorScheme.surface,
                      child: Icon(
                        Icons.image,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الكمية: ${item.quantity}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${NumberFormat.currency(symbol: '').format(item.price)} ج.م',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'الإجمالي: ${NumberFormat.currency(symbol: '').format(item.total)} ج.م',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'ملخص الطلب',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('عدد العناصر', '${widget.order.items.length}', theme),
            const SizedBox(height: 8),
            _buildSummaryRow('إجمالي الكمية', '${widget.order.items.fold<int>(0, (sum, item) => sum + item.quantity)}', theme),
            const SizedBox(height: 8),
            _buildSummaryRow('حالة الدفع', widget.order.paymentStatusText, theme),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'المبلغ الإجمالي',
              '${NumberFormat.currency(symbol: '').format(widget.order.total)} ج.م',
              theme,
              isTotal: true,
            ),
            if (widget.order.notes != null && widget.order.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'ملاحظات:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.order.notes!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, ThemeData theme, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isTotal ? 18 : 14,
            color: isTotal ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    // Only show action buttons if order is still pending
    if (widget.order.status != OrderStatus.pending) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showApprovalDialog(),
                icon: const Icon(Icons.check_circle),
                label: const Text('الموافقة على الطلب'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showRejectionDialog(),
                icon: const Icon(Icons.cancel),
                label: const Text('رفض الطلب'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showApprovalDialog() {
    showDialog(
      context: context,
      builder: (context) => _ApprovalDialog(
        order: widget.order,
        onApproved: () {
          Navigator.of(context).pop(); // Close details screen
        },
      ),
    );
  }

  void _showRejectionDialog() {
    showDialog(
      context: context,
      builder: (context) => _RejectionDialog(
        order: widget.order,
        onRejected: () {
          Navigator.of(context).pop(); // Close details screen
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd - HH:mm').format(date);
  }
}

// Dialog for order approval with tracking link
class _ApprovalDialog extends StatefulWidget {
  final ClientOrder order;
  final VoidCallback onApproved;

  const _ApprovalDialog({
    required this.order,
    required this.onApproved,
  });

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _trackingUrlController = TextEditingController();
  final _trackingTitleController = TextEditingController();
  final _trackingDescriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _trackingUrlController.dispose();
    _trackingTitleController.dispose();
    _trackingDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('الموافقة على الطلب'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'هل تريد الموافقة على الطلب #${widget.order.id.substring(0, 8).toUpperCase()}؟',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _trackingTitleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان رابط التتبع',
                  hintText: 'مثال: تتبع الشحنة',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال عنوان رابط التتبع';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _trackingUrlController,
                decoration: const InputDecoration(
                  labelText: 'رابط التتبع',
                  hintText: 'https://example.com/track/123',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال رابط التتبع';
                  }
                  final uri = Uri.tryParse(value.trim());
                  if (uri == null || !uri.hasAbsolutePath) {
                    return 'يرجى إدخال رابط صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _trackingDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'وصف رابط التتبع (اختياري)',
                  hintText: 'تفاصيل إضافية حول الشحنة',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _approveOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('موافقة'),
        ),
      ],
    );
  }

  Future<void> _approveOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final pendingOrdersProvider = Provider.of<PendingOrdersProvider>(context, listen: false);

    final success = await pendingOrdersProvider.approveOrderWithTracking(
      orderId: widget.order.id,
      trackingUrl: _trackingUrlController.text.trim(),
      trackingTitle: _trackingTitleController.text.trim(),
      trackingDescription: _trackingDescriptionController.text.trim(),
      adminName: 'محاسب', // You can get the actual accountant name from user context
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
      widget.onApproved();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت الموافقة على الطلب وإرسال رابط التتبع بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pendingOrdersProvider.error ?? 'فشل في الموافقة على الطلب'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Dialog for order rejection
class _RejectionDialog extends StatefulWidget {
  final ClientOrder order;
  final VoidCallback onRejected;

  const _RejectionDialog({
    required this.order,
    required this.onRejected,
  });

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('رفض الطلب'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'هل تريد رفض الطلب #${widget.order.id.substring(0, 8).toUpperCase()}؟',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'سبب الرفض',
              hintText: 'يرجى توضيح سبب رفض الطلب',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _rejectOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('رفض'),
        ),
      ],
    );
  }

  Future<void> _rejectOrder() async {
    setState(() => _isLoading = true);

    final pendingOrdersProvider = Provider.of<PendingOrdersProvider>(context, listen: false);
    final reason = _reasonController.text.trim().isEmpty ? 'لم يتم تحديد سبب' : _reasonController.text.trim();

    final success = await pendingOrdersProvider.rejectOrder(widget.order.id, reason);

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
      widget.onRejected();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفض الطلب بنجاح'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pendingOrdersProvider.error ?? 'فشل في رفض الطلب'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd - HH:mm').format(date);
  }
}
