import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/services/auth_service.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/widgets/orders/shared_order_details_dialog.dart';
import 'package:smartbiztracker_new/widgets/common/material_wrapper.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final StockWarehouseApiService _stockWarehouseApi = StockWarehouseApiService();
  bool _isLoading = true;
  TabController? _tabController;
  String _searchQuery = '';
  List<OrderModel> _allOrders = [];
  List<OrderModel> _filteredOrders = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load orders when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }
  
  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
  
  // Load worker's assigned orders
  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Get all orders, filter for assigned orders in UI
      final orders = await _stockWarehouseApi.getOrders();
      
      setState(() {
        _allOrders = orders;
        _filterOrders();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الطلبات: $e')),
      );
    }
  }
  
  // Filter orders based on search query and worker assignment
  void _filterOrders() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final worker = authProvider.user;
    
    if (worker == null) {
      setState(() {
        _filteredOrders = [];
      });
      return;
    }
    
    // Filter orders assigned to this worker
    var filtered = _allOrders.where((order) => 
      order.assignedTo == worker.id || order.assignedTo == worker.name
    ).toList();
    
    // Apply search filter if needed
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((order) {
        return order.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               order.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               order.status.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    setState(() {
      _filteredOrders = filtered;
    });
  }
  
  // Handle search query changes
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialWrapper(
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'الطلبات',
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadOrders,
            ),
          ],
        ),
        drawer: MainDrawer(currentRoute: '/orders'),
        body: _isLoading
            ? const CustomLoader(message: 'جار تحميل الطلبات...')
            : Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElegantSearchBar(
                      controller: TextEditingController(),
                      hintText: 'البحث في الطلبات...',
                      onChanged: _onSearchChanged,
                      prefixIcon: Icons.search,
                    ),
                  ),
                  
                  // Tab bar for order status
                  TabBar(
                    controller: _tabController,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'الطلبات الحالية'),
                      Tab(text: 'الطلبات المكتملة'),
                    ],
                  ),
                  
                  // Orders content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Active orders tab
                        _buildOrdersList(
                          _filteredOrders.where((order) => 
                            order.status != 'تم التسليم' && order.status != 'ملغي'
                          ).toList(),
                        ),
                        
                        // Completed orders tab
                        _buildOrdersList(
                          _filteredOrders.where((order) => 
                            order.status == 'تم التسليم' || order.status == 'ملغي'
                          ).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
  
  // Build orders list
  Widget _buildOrdersList(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text('لا توجد طلبات حالياً'),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }
  
  // Build order card
  Widget _buildOrderCard(OrderModel order) {
    final theme = Theme.of(context);
    
    // Get color for order status
    Color statusColor;
    switch (order.status) {
      case 'قيد الانتظار':
        statusColor = Colors.orange;
        break;
      case 'قيد التنفيذ':
        statusColor = Colors.blue;
        break;
      case 'تم التجهيز':
        statusColor = Colors.purple;
        break;
      case 'تم التسليم':
        statusColor = Colors.green;
        break;
      case 'ملغي':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () async {
          try {
            // Extract numeric part or use the order ID
            int orderId;
            try {
              // Try to extract numeric part from orderNumber
              final numericPart = order.orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
              if (numericPart.isNotEmpty) {
                orderId = int.parse(numericPart);
              } else {
                // If no numeric part, try using the ID directly 
                orderId = int.parse(order.id);
              }
            } catch (e) {
              // If all parsing fails, use a fallback
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري محاولة الحصول على تفاصيل الطلب بطريقة بديلة...')),
              );
              orderId = int.parse(order.id);
            }
            
            final orderDetails = await _stockWarehouseApi.getOrderDetail(orderId);
            if (!mounted) return;
            
            if (orderDetails != null) {
              showDialog(
                context: context,
                builder: (context) => SharedOrderDetailsDialog(
                  order: orderDetails,
                  userRole: 'worker',
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا يمكن الحصول على تفاصيل الطلب')),
              );
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('حدث خطأ: $e')),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shopping_cart, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'طلب #${order.orderNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.5), width: 1.5),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 24, thickness: 1),
              
              // Customer info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 18, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          // Implement call functionality
                        },
                        icon: Icon(Icons.phone, size: 16, color: theme.colorScheme.primary),
                        label: Text(
                          order.customerPhone!,
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Order summary
              Row(
                children: [
                  // Items count
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 16,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${order.items.length} منتج',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  
                  // Created at
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'تاريخ الإنشاء: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Thumbnail preview of first 3 items with images
              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    ...order.items.take(3).map((item) {
                      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
                        return Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image_not_supported),
                                );
                              },
                            ),
                          ),
                        );
                      } else {
                        return Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              item.productName.substring(0, item.productName.length > 2 ? 2 : item.productName.length),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      }
                    }).toList(),
                    
                    if (order.items.length > 3)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '+${order.items.length - 3}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              
              // View details button
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        // Extract numeric part or use the order ID
                        int orderId;
                        try {
                          // Try to extract numeric part from orderNumber
                          final numericPart = order.orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
                          if (numericPart.isNotEmpty) {
                            orderId = int.parse(numericPart);
                          } else {
                            // If no numeric part, try using the ID directly 
                            orderId = int.parse(order.id);
                          }
                        } catch (e) {
                          // If all parsing fails, use a fallback
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('جاري محاولة الحصول على تفاصيل الطلب بطريقة بديلة...')),
                          );
                          orderId = int.parse(order.id);
                        }
                        
                        final orderDetails = await _stockWarehouseApi.getOrderDetail(orderId);
                        if (!mounted) return;
                        
                        if (orderDetails != null) {
                          showDialog(
                            context: context,
                            builder: (context) => SharedOrderDetailsDialog(
                              order: orderDetails,
                              userRole: 'worker',
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('لا يمكن الحصول على تفاصيل الطلب')),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('حدث خطأ: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('عرض التفاصيل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
