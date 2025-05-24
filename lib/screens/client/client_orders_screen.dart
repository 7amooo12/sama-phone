import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../services/stockwarehouse_api.dart';
import '../../widgets/orders/shared_order_details_dialog.dart';
import '../../services/order_service.dart';

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({Key? key}) : super(key: key);

  @override
  _ClientOrdersScreenState createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  late Future<List<OrderModel>> _ordersFuture;
  bool _isLoading = false;
  String? _error;
  List<OrderModel> _orders = [];
  String _statusFilter = 'all';
  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _error = 'يرجى تسجيل الدخول لعرض الطلبات';
        });
        return;
      }

      _orders = await _orderService.getOrdersByUserId(userId);
      _ordersFuture = Future.value(_orders);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  List<OrderModel> get _filteredOrders {
    if (_statusFilter == 'all') {
      return _orders;
    } else {
      return _orders.where((order) => order.status == _statusFilter).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.translate('my_orders') ?? 'طلباتي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', appLocalizations.translate('all') ?? 'الكل'),
                  _buildFilterChip(OrderStatus.pending, appLocalizations.translate('pending') ?? 'قيد الانتظار'),
                  _buildFilterChip(OrderStatus.confirmed, appLocalizations.translate('confirmed') ?? 'مؤكد'),
                  _buildFilterChip(OrderStatus.processing, appLocalizations.translate('processing') ?? 'قيد المعالجة'),
                  _buildFilterChip(OrderStatus.shipped, appLocalizations.translate('shipped') ?? 'تم الشحن'),
                  _buildFilterChip(OrderStatus.delivered, appLocalizations.translate('delivered') ?? 'تم التسليم'),
                ],
              ),
            ),
          ),
          
          // Orders list
          Expanded(
            child: _isLoading
                ? const LoadingWidget()
                : _error != null
                    ? AppErrorWidget(message: _error!, onRetry: () => _loadOrders())
                    : _filteredOrders.isEmpty
                        ? _buildEmptyState(appLocalizations)
                        : _buildOrdersList(appLocalizations),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: _statusFilter == value,
        onSelected: (selected) {
          setState(() {
            _statusFilter = selected ? value : 'all';
          });
        },
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations appLocalizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            appLocalizations.translate('no_orders_found') ?? 'لا توجد طلبات',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _statusFilter == 'all'
                ? appLocalizations.translate('no_orders_message') ?? 'لم تقم بإنشاء أي طلبات بعد'
                : appLocalizations.translate('no_filtered_orders_message') ?? 'لا يوجد طلبات بهذه الحالة',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/products');
            },
            icon: const Icon(Icons.shopping_bag),
            label: Text(appLocalizations.translate('browse_products') ?? 'تصفح المنتجات'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(AppLocalizations appLocalizations) {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final timeFormatter = DateFormat('HH:mm');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
        final orderDate = order.createdAt;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          child: InkWell(
            onTap: () {
              _showOrderDetails(order);
            },
            child: Column(
              children: [
                // Order header with status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Theme.of(context).colorScheme.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${appLocalizations.translate('order_number') ?? 'طلب رقم'} #${order.orderNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dateFormatter.format(orderDate)} - ${timeFormatter.format(orderDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      _buildStatusChip(order.status, appLocalizations),
                    ],
                  ),
                ),
                
                // Order summary
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Items count and total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${order.items.length} ${appLocalizations.translate('items') ?? 'منتجات'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          Text(
                            '${order.totalAmount.toStringAsFixed(2)} جنيه',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Products preview (showing first 2 items)
                      if (order.items.isNotEmpty)
                        ...order.items.take(2).map((item) => _buildOrderItemPreview(item)),
                      
                      // Show more items indicator if needed
                      if (order.items.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '+ ${order.items.length - 2} ${appLocalizations.translate('more_items') ?? 'منتجات أخرى'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // View details button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      _showOrderDetails(order);
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: Text(
                      appLocalizations.translate('view_details') ?? 'عرض التفاصيل',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderItemPreview(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Item image if available
          if (item.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, size: 24),
                    );
                  },
                ),
              ),
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.shopping_bag, size: 24),
            ),
          
          const SizedBox(width: 12),
          
          // Product name and quantity
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'الكمية: ${item.quantity} × ${item.price.toStringAsFixed(2)} جنيه',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          
          // Subtotal
          Text(
            '${item.subtotal.toStringAsFixed(2)} جنيه',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, AppLocalizations appLocalizations) {
    Color statusColor;
    String statusText;
    
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 12,
          color: statusColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showOrderDetails(OrderModel order) {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تحميل تفاصيل الطلب...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    // Import services
    final stockWarehouseApi = StockWarehouseApiService();
    
    // Get order details
    Future.microtask(() async {
      try {
        // Try to get detailed order information
        final orderId = int.tryParse(order.id);
        OrderModel detailedOrder = order;
        
        if (orderId != null) {
          final orderDetail = await stockWarehouseApi.getOrderDetail(orderId);
          if (orderDetail != null) {
            detailedOrder = orderDetail;
          }
        }
        
        // Close loading dialog
        if (context.mounted) Navigator.of(context).pop();
        
        // Show order details dialog
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => SharedOrderDetailsDialog(
              order: detailedOrder,
              userRole: 'client',
            ),
          );
        }
      } catch (e) {
        // Close loading dialog
        if (context.mounted) Navigator.of(context).pop();
        
        // Show error
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في تحميل تفاصيل الطلب: $e')),
          );
          
          // Show basic details even if error
          showDialog(
            context: context,
            builder: (context) => SharedOrderDetailsDialog(
              order: order,
              userRole: 'client',
            ),
          );
        }
      }
    });
  }
} 