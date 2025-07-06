import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/simplified_orders_provider.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/screens/admin/order_detail_screen.dart';

/// صفحة الطلبات الموحدة - تستخدم المزود المبسط فقط
class UnifiedOrdersScreen extends StatefulWidget {
  const UnifiedOrdersScreen({super.key});

  @override
  State<UnifiedOrdersScreen> createState() => _UnifiedOrdersScreenState();
}

class _UnifiedOrdersScreenState extends State<UnifiedOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final ordersProvider = Provider.of<SimplifiedOrdersProvider>(context, listen: false);
              ordersProvider.loadOrders(forceRefresh: true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث والفلاتر
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // شريط البحث
                ElegantSearchBar(
                  controller: _searchController,
                  hintText: 'البحث في الطلبات...',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // فلتر الحالة
                Consumer<SimplifiedOrdersProvider>(
                  builder: (context, ordersProvider, child) {
                    final statuses = ordersProvider.getAvailableStatuses();

                    return DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'فلترة حسب الحالة',
                        border: OutlineInputBorder(),
                      ),
                      items: statuses.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status == 'all' ? 'جميع الحالات' : status),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value ?? 'all';
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // قائمة الطلبات
          Expanded(
            child: Consumer<SimplifiedOrdersProvider>(
              builder: (context, ordersProvider, child) {
                // تحميل الطلبات إذا لم تكن محملة
                if (ordersProvider.orders.isEmpty && !ordersProvider.isLoading) {
                  ordersProvider.loadOrders();
                }

                // حالة التحميل
                if (ordersProvider.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('جاري تحميل الطلبات...'),
                      ],
                    ),
                  );
                }

                // حالة الخطأ
                if (ordersProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'خطأ في جلب الطلبات',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ordersProvider.error!,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ordersProvider.retry();
                          },
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                // فلترة الطلبات
                List<OrderModel> filteredOrders = ordersProvider.orders;

                // تطبيق البحث
                if (_searchQuery.isNotEmpty) {
                  filteredOrders = ordersProvider.searchOrders(_searchQuery);
                }

                // تطبيق فلتر الحالة
                if (_selectedStatus != 'all') {
                  filteredOrders = ordersProvider.filterByStatus(_selectedStatus);
                }

                // حالة عدم وجود طلبات
                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد طلبات',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _selectedStatus != 'all'
                              ? 'لا توجد طلبات تطابق البحث أو الفلتر'
                              : 'لا توجد طلبات متاحة حالياً',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // عرض قائمة الطلبات
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildOrderCard(order, theme);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رقم الطلب والحالة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(order.status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      order.status,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(order.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // اسم العميل
              Text(
                'العميل: ${order.customerName}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),

              // المستودع
              Text(
                'المستودع: ${order.warehouseName}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),

              // التقدم وعدد العناصر
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.itemsCount} عنصر',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    'التقدم: ${(order.progress ?? 0).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // شريط التقدم
              LinearProgressIndicator(
                value: (order.progress ?? 0) / 100,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getStatusColor(order.status),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'قيد المعالجة':
        return Colors.orange;
      case 'تحت التصنيع':
        return Colors.blue;
      case 'تم التجهيز':
        return Colors.purple;
      case 'تم التسليم':
        return Colors.green;
      case 'تالف / هوالك':
        return Colors.red;
      // Legacy support for old status names
      case 'قيد الانتظار':
        return Colors.orange;
      case 'قيد التنفيذ':
        return Colors.blue;
      case 'ملغي':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showOrderDetails(OrderModel order) {
    AppLogger.info('عرض تفاصيل الطلب: ${order.orderNumber}');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(order: order),
      ),
    );
  }
}
