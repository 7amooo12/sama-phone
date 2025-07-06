import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../utils/app_localizations.dart';

class OrderDetailsScreen extends StatelessWidget {

  const OrderDetailsScreen({
    super.key,
    required this.order,
  });
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLocalizations = AppLocalizations.of(context);
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final timeFormatter = DateFormat('HH:mm');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.translate('order_details') ?? 'تفاصيل الطلب'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header with status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order number and date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${appLocalizations.translate('order_number') ?? 'طلب رقم'} #${order.orderNumber}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dateFormatter.format(order.createdAt)} - ${timeFormatter.format(order.createdAt)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      
                      // Status
                      _buildStatusChip(context, order.status),
                    ],
                  ),
                  
                  const Divider(height: 24),
                  
                  // Customer info
                  Text(
                    appLocalizations.translate('customer_information') ?? 'معلومات العميل',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Name
                  _buildInfoRow(
                    context, 
                    Icons.person,
                    appLocalizations.translate('name') ?? 'الاسم',
                    order.customerName,
                  ),
                  
                  // Phone
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context, 
                    Icons.phone,
                    appLocalizations.translate('phone') ?? 'رقم الهاتف',
                    order.customerPhone != null ? order.customerPhone! : 'N/A',
                  ),
                  
                  // Address if available
                  if (order.address != null && order.address!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      context, 
                      Icons.location_on,
                      appLocalizations.translate('address') ?? 'العنوان',
                      order.address!,
                    ),
                  ],
                ],
              ),
            ),
            
            // Order Items
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appLocalizations.translate('order_items') ?? 'منتجات الطلب',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  // Items list
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.items.length,
                    separatorBuilder: (context, index) => const Divider(height: 16),
                    itemBuilder: (context, index) => _buildOrderItemTile(
                      context,
                      order.items[index],
                    ),
                  ),
                  
                  const Divider(height: 32),
                  
                  // Order summary
                  Text(
                    appLocalizations.translate('order_summary') ?? 'ملخص الطلب',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Subtotal
                  _buildSummaryRow(
                    context,
                    appLocalizations.translate('subtotal') ?? 'المجموع الفرعي',
                    '${order.totalAmount.toStringAsFixed(2)} ج.م',
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Delivery fee - if applicable
                  if (order.deliveryFee != null && order.deliveryFee! > 0) ...[
                    _buildSummaryRow(
                      context,
                      appLocalizations.translate('delivery_fee') ?? 'رسوم التوصيل',
                      '${order.deliveryFee!.toStringAsFixed(2)} ج.م',
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Discount - if applicable
                  if (order.discount != null && order.discount! > 0) ...[
                    _buildSummaryRow(
                      context,
                      appLocalizations.translate('discount') ?? 'الخصم',
                      '- ${order.discount!.toStringAsFixed(2)} ج.م',
                      isNegative: true,
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Total
                  _buildSummaryRow(
                    context,
                    appLocalizations.translate('total') ?? 'الإجمالي',
                    '${order.totalAmount.toStringAsFixed(2)} ج.م',
                    isTotal: true,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Payment method
                  if (order.paymentMethod != null && order.paymentMethod!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.payment,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${appLocalizations.translate('payment_method') ?? 'طريقة الدفع'}: ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_getPaymentMethodText(order.paymentMethod!, appLocalizations)),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Notes
                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.note,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                appLocalizations.translate('notes') ?? 'ملاحظات',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(order.notes!),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Cancel order button - only for pending orders
                  if (order.status == OrderStatus.pending) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _showCancelDialog(context),
                        icon: const Icon(Icons.cancel),
                        label: Text(appLocalizations.translate('cancel_order') ?? 'إلغاء الطلب'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    Color statusColor;
    String statusText;
    
    final appLocalizations = AppLocalizations.of(context);
    
    switch (status) {
      case OrderStatus.pending:
        statusColor = Colors.amber;
        statusText = appLocalizations.translate('pending') ?? 'قيد الانتظار';
        break;
      case OrderStatus.confirmed:
        statusColor = Colors.blue;
        statusText = appLocalizations.translate('confirmed') ?? 'مؤكد';
        break;
      case OrderStatus.processing:
        statusColor = Colors.purple;
        statusText = appLocalizations.translate('processing') ?? 'قيد المعالجة';
        break;
      case OrderStatus.shipped:
        statusColor = Colors.indigo;
        statusText = appLocalizations.translate('shipped') ?? 'تم الشحن';
        break;
      case OrderStatus.delivered:
        statusColor = Colors.green;
        statusText = appLocalizations.translate('delivered') ?? 'تم التسليم';
        break;
      case OrderStatus.cancelled:
      case OrderStatus.canceled:
        statusColor = Colors.red;
        statusText = appLocalizations.translate('cancelled') ?? 'ملغي';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 14,
          color: statusColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItemTile(BuildContext context, OrderItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item image if available
        if (item.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, size: 30),
                  );
                },
              ),
            ),
          )
        else
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_bag, size: 30),
          ),
        
        const SizedBox(width: 16),
        
        // Item details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.price.toStringAsFixed(2)} ج.م × ${item.quantity}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        
        // Subtotal
        Text(
          '${item.subtotal.toStringAsFixed(2)} ج.م',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value, {
    bool isNegative = false,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
            color: isNegative
                ? Colors.red
                : isTotal
                    ? Theme.of(context).colorScheme.primary
                    : null,
          ),
        ),
      ],
    );
  }

  String _getPaymentMethodText(String method, AppLocalizations appLocalizations) {
    switch (method) {
      case 'cash':
        return appLocalizations.translate('cash_payment') ?? 'الدفع نقداً';
      case 'credit_card':
        return appLocalizations.translate('credit_card') ?? 'بطاقة ائتمان';
      case 'bank_transfer':
        return appLocalizations.translate('bank_transfer') ?? 'تحويل بنكي';
      case 'cheque':
        return appLocalizations.translate('cheque') ?? 'شيك';
      case 'online':
        return appLocalizations.translate('online_payment') ?? 'دفع إلكتروني';
      default:
        return method;
    }
  }

  void _showCancelDialog(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appLocalizations.translate('cancel_order') ?? 'إلغاء الطلب'),
        content: Text(appLocalizations.translate('cancel_order_confirm') ?? 'هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appLocalizations.translate('no') ?? 'لا'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final orderProvider = Provider.of<OrderProvider>(context, listen: false);
              final success = await orderProvider.cancelOrder(order.id);
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(appLocalizations.translate('order_cancelled') ?? 'تم إلغاء الطلب بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.of(context).pop(); // Return to orders list
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(orderProvider.error ?? (appLocalizations.translate('order_cancel_failed') ?? 'فشل إلغاء الطلب')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(appLocalizations.translate('yes') ?? 'نعم'),
          ),
        ],
      ),
    );
  }
} 