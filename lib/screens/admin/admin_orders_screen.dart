import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/providers/client_orders_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _selectedFilter = 'الكل';
  final List<String> _filterOptions = [
    'الكل',
    'في انتظار التأكيد',
    'تم التأكيد',
    'قيد التجهيز',
    'تم الشحن',
    'تم التسليم',
    'ملغي',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    final orderProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
    await orderProvider.loadAllOrders();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'إدارة الطلبات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Consumer<ClientOrdersProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (orderProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ في تحميل الطلبات',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    orderProvider.error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadOrders,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final filteredOrders = _getFilteredOrders(orderProvider.orders);

          if (filteredOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 120,
                    color: Colors.grey[300],
                  ).animate().scale(duration: 800.ms),

                  const SizedBox(height: 24),

                  Text(
                    'لا توجد طلبات',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 12),

                  Text(
                    'لا توجد طلبات تطابق الفلتر المحدد',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 500.ms),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildFilterBar(theme),
              _buildOrdersStats(filteredOrders, theme),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return _buildOrderCard(order, theme, index);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final option = _filterOptions[index];
          final isSelected = _selectedFilter == option;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = option;
                });
              },
              backgroundColor: Colors.grey[100],
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              checkmarkColor: theme.colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? theme.colorScheme.primary : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersStats(List<ClientOrder> orders, ThemeData theme) {
    final totalOrders = orders.length;
    final totalAmount = orders.fold<double>(0, (sum, order) => sum + order.total);
    final pendingOrders = orders.where((o) => o.status == OrderStatus.pending).length;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'إجمالي الطلبات',
              totalOrders.toString(),
              Icons.shopping_bag_outlined,
              Colors.blue,
              theme,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          Expanded(
            child: _buildStatItem(
              'إجمالي المبيعات',
              '${totalAmount.toStringAsFixed(0)} ج.م',
              Icons.attach_money,
              Colors.green,
              theme,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          Expanded(
            child: _buildStatItem(
              'في الانتظار',
              pendingOrders.toString(),
              Icons.pending_outlined,
              Colors.orange,
              theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOrderCard(ClientOrder order, ThemeData theme, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showOrderActions(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس الطلب
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب #${order.id.substring(0, 8).toUpperCase()}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(order.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  _buildStatusChip(order.status, theme),
                ],
              ),

              const SizedBox(height: 12),

              // معلومات العميل
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          order.clientName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          order.clientPhone,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // تفاصيل الطلب
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} منتج',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    '${order.total.toStringAsFixed(2)} ج.م',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),

              // روابط المتابعة
              if (order.trackingLinks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'روابط المتابعة: ${order.trackingLinks.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // أزرار الإجراءات
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showOrderDetails(order),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('عرض'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddTrackingDialog(order),
                      icon: const Icon(Icons.add_link, size: 16),
                      label: const Text('إضافة رابط'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showOrderActions(order),
                    icon: const Icon(Icons.more_vert),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.3);
  }

  Widget _buildStatusChip(OrderStatus status, ThemeData theme) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case OrderStatus.pending:
        backgroundColor = Colors.orange.withValues(alpha: 0.2);
        textColor = Colors.orange[800]!;
        break;
      case OrderStatus.confirmed:
        backgroundColor = Colors.blue.withValues(alpha: 0.2);
        textColor = Colors.blue[800]!;
        break;
      case OrderStatus.processing:
        backgroundColor = Colors.purple.withValues(alpha: 0.2);
        textColor = Colors.purple[800]!;
        break;
      case OrderStatus.shipped:
        backgroundColor = Colors.teal.withValues(alpha: 0.2);
        textColor = Colors.teal[800]!;
        break;
      case OrderStatus.delivered:
        backgroundColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green[800]!;
        break;
      case OrderStatus.cancelled:
        backgroundColor = Colors.red.withValues(alpha: 0.2);
        textColor = Colors.red[800]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  List<ClientOrder> _getFilteredOrders(List<ClientOrder> orders) {
    if (_selectedFilter == 'الكل') {
      return orders;
    }

    OrderStatus? filterStatus;
    switch (_selectedFilter) {
      case 'في انتظار التأكيد':
        filterStatus = OrderStatus.pending;
        break;
      case 'تم التأكيد':
        filterStatus = OrderStatus.confirmed;
        break;
      case 'قيد التجهيز':
        filterStatus = OrderStatus.processing;
        break;
      case 'تم الشحن':
        filterStatus = OrderStatus.shipped;
        break;
      case 'تم التسليم':
        filterStatus = OrderStatus.delivered;
        break;
      case 'ملغي':
        filterStatus = OrderStatus.cancelled;
        break;
    }

    return orders.where((order) => order.status == filterStatus).toList();
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'قيد المعالجة';
      case OrderStatus.confirmed:
        return 'تم التأكيد';
      case OrderStatus.processing:
        return 'تحت التصنيع';
      case OrderStatus.shipped:
        return 'تم التجهيز';
      case OrderStatus.delivered:
        return 'تم التسليم';
      case OrderStatus.cancelled:
        return 'تالف / هوالك';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showOrderDetails(ClientOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailsSheet(order: order),
    );
  }

  void _showOrderActions(ClientOrder order) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _OrderActionsSheet(
        order: order,
        onStatusChanged: () => _loadOrders(),
      ),
    );
  }

  void _showAddTrackingDialog(ClientOrder order) {
    showDialog(
      context: context,
      builder: (context) => _AddTrackingDialog(
        order: order,
        onAdded: () => _loadOrders(),
      ),
    );
  }
}

// Dialog لإضافة رابط متابعة
class _AddTrackingDialog extends StatefulWidget {

  const _AddTrackingDialog({
    required this.order,
    required this.onAdded,
  });
  final ClientOrder order;
  final VoidCallback onAdded;

  @override
  State<_AddTrackingDialog> createState() => _AddTrackingDialogState();
}

class _AddTrackingDialogState extends State<_AddTrackingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {

    return AlertDialog(
      title: const Text('إضافة رابط متابعة'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'عنوان الرابط *',
                hintText: 'مثال: رابط شركة الشحن',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'العنوان مطلوب';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'الرابط *',
                hintText: 'https://example.com/tracking/123',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرابط مطلوب';
                }
                if (Uri.tryParse(value)?.hasAbsolutePath != true) {
                  return 'الرابط غير صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'الوصف (اختياري)',
                hintText: 'وصف إضافي للرابط',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addTrackingLink,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('إضافة'),
        ),
      ],
    );
  }

  Future<void> _addTrackingLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final orderProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

    final success = await orderProvider.addTrackingLink(
      orderId: widget.order.id,
      url: _urlController.text.trim(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      createdBy: supabaseProvider.user?.name ?? 'Admin',
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        Navigator.pop(context);
        widget.onAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة رابط المتابعة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(orderProvider.error ?? 'فشل في إضافة رابط المتابعة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Sheet لإجراءات الطلب
class _OrderActionsSheet extends StatelessWidget {

  const _OrderActionsSheet({
    required this.order,
    required this.onStatusChanged,
  });
  final ClientOrder order;
  final VoidCallback onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(
            'إجراءات الطلب #${order.id.substring(0, 8).toUpperCase()}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          // أزرار تغيير الحالة - محسنة للموافقة والرفض
          if (order.status == OrderStatus.pending) ...[
            _buildEnhancedActionButton(
              context,
              'موافقة على الطلب',
              Icons.check_circle_rounded,
              Colors.green,
              () => _showApprovalDialog(context),
              isApproval: true,
            ),
            const SizedBox(height: 12),
            _buildEnhancedActionButton(
              context,
              'رفض الطلب',
              Icons.cancel_rounded,
              Colors.red,
              () => _showRejectionDialog(context),
              isRejection: true,
            ),
          ] else ...[
            _buildActionButton(
              context,
              'بدء التجهيز',
              Icons.build_outlined,
              Colors.purple,
              () => _updateOrderStatus(context, OrderStatus.processing),
              enabled: order.status == OrderStatus.confirmed,
            ),

            _buildActionButton(
              context,
              'تم الشحن',
              Icons.local_shipping_outlined,
              Colors.teal,
              () => _updateOrderStatus(context, OrderStatus.shipped),
              enabled: order.status == OrderStatus.processing,
            ),

            _buildActionButton(
              context,
              'تم التسليم',
              Icons.done_all,
              Colors.green,
              () => _updateOrderStatus(context, OrderStatus.delivered),
              enabled: order.status == OrderStatus.shipped,
            ),

            const Divider(height: 30),

            _buildActionButton(
              context,
              'إلغاء الطلب',
              Icons.cancel_outlined,
              Colors.red,
              () => _updateOrderStatus(context, OrderStatus.cancelled),
              enabled: order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEnhancedActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isApproval = false,
    bool isRejection = false,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 4,
          shadowColor: color.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool enabled = true,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey[300],
          foregroundColor: enabled ? Colors.white : Colors.grey[600],
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _showApprovalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 48,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'موافقة على الطلب',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'هل أنت متأكد من الموافقة على هذا الطلب؟\nسيتم إشعار العميل بالموافقة',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateOrderStatus(context, OrderStatus.confirmed);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('موافقة'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectionDialog(BuildContext context) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: Colors.red,
                  size: 48,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'رفض الطلب',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'يرجى إدخال سبب رفض الطلب:',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'سبب الرفض...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateOrderStatus(context, OrderStatus.cancelled);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('رفض'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateOrderStatus(BuildContext context, OrderStatus newStatus) async {
    Navigator.pop(context);

    final orderProvider = Provider.of<ClientOrdersProvider>(context, listen: false);

    final success = await orderProvider.updateOrderStatus(order.id, newStatus);

    if (success) {
      onStatusChanged();
      _showStatusUpdateSuccess(context, newStatus);
    } else {
      _showStatusUpdateError(context, orderProvider.error ?? 'فشل في تحديث حالة الطلب');
    }
  }

  void _showStatusUpdateSuccess(BuildContext context, OrderStatus status) {
    String message;
    Color color;
    IconData icon;

    switch (status) {
      case OrderStatus.confirmed:
        message = 'تم قبول الطلب بنجاح! سيتم إشعار العميل';
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case OrderStatus.cancelled:
        message = 'تم رفض الطلب. سيتم إشعار العميل';
        color = Colors.red;
        icon = Icons.cancel_rounded;
        break;
      default:
        message = 'تم تحديث حالة الطلب بنجاح';
        color = Colors.blue;
        icon = Icons.info_rounded;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showStatusUpdateError(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(error)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// Sheet لتفاصيل الطلب
class _OrderDetailsSheet extends StatelessWidget {

  const _OrderDetailsSheet({required this.order});
  final ClientOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تفاصيل الطلب',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Info
                  _buildDetailSection(
                    'معلومات الطلب',
                    [
                      'رقم الطلب: #${order.id.substring(0, 8).toUpperCase()}',
                      'التاريخ: ${_formatDate(order.createdAt)}',
                      'الحالة: ${order.statusText}',
                      'حالة الدفع: ${order.paymentStatusText}',
                    ],
                    theme,
                  ),

                  const SizedBox(height: 20),

                  // Customer Info
                  _buildDetailSection(
                    'معلومات العميل',
                    [
                      'الاسم: ${order.clientName}',
                      'البريد الإلكتروني: ${order.clientEmail}',
                      'الهاتف: ${order.clientPhone}',
                    ],
                    theme,
                  ),

                  const SizedBox(height: 20),

                  // Items
                  _buildDetailSection(
                    'المنتجات',
                    order.items.map((item) =>
                      '${item.productName} × ${item.quantity} = ${(item.price * item.quantity).toStringAsFixed(2)} ج.م'
                    ).toList(),
                    theme,
                  ),

                  const SizedBox(height: 20),

                  // Totals
                  _buildDetailSection(
                    'المجموع',
                    [
                      'الإجمالي: ${order.total.toStringAsFixed(2)} ج.م',
                    ],
                    theme,
                  ),

                  if (order.shippingAddress != null) ...[
                    const SizedBox(height: 20),
                    _buildDetailSection(
                      'عنوان الشحن',
                      [order.shippingAddress!],
                      theme,
                    ),
                  ],

                  if (order.notes != null) ...[
                    const SizedBox(height: 20),
                    _buildDetailSection(
                      'ملاحظات',
                      [order.notes!],
                      theme,
                    ),
                  ],

                  if (order.trackingLinks.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildTrackingLinksSection(order.trackingLinks, theme),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> items, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            item,
            style: theme.textTheme.bodyMedium,
          ),
        )),
      ],
    );
  }

  Widget _buildTrackingLinksSection(List<TrackingLink> links, ThemeData theme) {
    // ترتيب الروابط حسب التاريخ (الأحدث أولاً)
    final sortedLinks = List<TrackingLink>.from(links);
    sortedLinks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'روابط المتابعة (${links.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...sortedLinks.map((link) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                link.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (link.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  link.description,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'تم الإضافة: ${_formatDate(link.createdAt)} بواسطة ${link.createdBy}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                link.url,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
