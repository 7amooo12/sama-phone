import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:smartbiztracker_new/widgets/orders/shared_order_details_dialog.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final StockWarehouseApiService _stockWarehouseApi = StockWarehouseApiService();
  bool _isLoading = true;
  String _searchQuery = '';
  List<OrderModel> _allOrders = [];
  List<OrderModel> _filteredOrders = [];

  @override
  void initState() {
    super.initState();
    // Load orders when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  // Load client's orders
  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final clientId = authProvider.user?.id;
      
      if (clientId == null) {
        setState(() {
          _isLoading = false;
          _allOrders = [];
          _filteredOrders = [];
        });
        return;
      }
      
      // Get orders for this client
      // In a real scenario, you would filter by client ID on the server
      final orders = await _stockWarehouseApi.getOrders();
      
      // Filter for this client (in real app, the API would handle this)
      final clientOrders = orders.where((order) => 
        order.clientId == clientId || order.customerName == authProvider.user?.name
      ).toList();
      
      setState(() {
        _allOrders = clientOrders;
        _filterOrders();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الطلبات: $e')),
        );
      }
    }
  }
  
  // Filter orders based on search query
  void _filterOrders() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredOrders = List.from(_allOrders);
      });
      return;
    }
    
    final filtered = _allOrders.where((order) {
      return order.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             order.status.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
    
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
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.user;

    if (userModel == null) {
      // Handle case where user is not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(
        title: 'طلباتي',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      drawer: MainDrawer(currentRoute: '/orders'),
      body: _isLoading
          ? const CustomLoader(message: 'جاري تحميل طلباتك...')
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
                
                // Orders content
                Expanded(
                  child: _filteredOrders.isEmpty
                      ? _buildEmptyOrdersView(theme)
                      : _buildOrdersList(),
                ),
              ],
            ),
    );
  }
  
  // Empty orders view with animation
  Widget _buildEmptyOrdersView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty_box.json',
            width: 200,
            height: 200,
            repeat: true,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد طلبات حالياً',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك التواصل معنا لتقديم طلب جديد',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Implement contact us functionality
            },
            icon: const Icon(Icons.phone),
            label: const Text('تواصل معنا'),
          ),
        ],
      ),
    );
  }
  
  // Build orders list 
  Widget _buildOrdersList() {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredOrders.length,
        itemBuilder: (context, index) {
          final order = _filteredOrders[index];
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          // Show order details when tapped
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
                  userRole: 'client',
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
              // Order header with number and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'طلب #${order.orderNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
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
              
              const Divider(height: 24),
              
              // Order summary
              Row(
                children: [
                  // Items count
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_basket,
                          size: 16,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text('${order.items.length} منتج'),
                      ],
                    ),
                  ),
                  
                  // Total amount
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_money,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${order.totalAmount.toStringAsFixed(2)} جنيه',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Thumbnail preview of items with images
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
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
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
              
              // Date and details button
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'التاريخ: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    TextButton.icon(
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
                                userRole: 'client',
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
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('التفاصيل'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
