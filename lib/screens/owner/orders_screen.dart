import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/orders/shared_order_details_dialog.dart';
import 'package:flutter/rendering.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final StockWarehouseApiService _stockWarehouseApi = StockWarehouseApiService();
  bool _isLoading = true;
  TabController? _tabController;
  String _searchQuery = '';
  List<OrderModel> _allOrders = [];
  List<OrderModel> _filteredOrders = [];
  bool _showStats = true;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Load orders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }
  
  @override
  void dispose() {
    _tabController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Load owner's orders
  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Get all orders (as owner)
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
             order.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             order.status.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (order.warehouseName != null && order.warehouseName!.toLowerCase().contains(_searchQuery.toLowerCase()));
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
    
    // استخدام مزود Supabase أولاً
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final supabaseUser = supabaseProvider.user;
    
    // استخدام مزود Auth كإجراء احتياطي
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userModel = supabaseUser ?? authProvider.user;

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

    // إحصاء عدد الطلبات في كل حالة
    final pendingCount = _filteredOrders.where((o) => o.status == 'قيد الانتظار').length;
    final processingCount = _filteredOrders.where((o) => o.status == 'قيد التنفيذ' || o.status == 'تم التجهيز').length;
    final completedCount = _filteredOrders.where((o) => o.status == 'تم التسليم').length;
    final cancelledCount = _filteredOrders.where((o) => o.status == 'ملغي').length;

    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(
        title: 'إدارة الطلبات',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      drawer: MainDrawer(currentRoute: '/orders'),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Handle add new order
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ستتوفر ميزة إضافة طلب جديد قريباً'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const CustomLoader(message: 'جاري تحميل الطلبات...')
          : NotificationListener<ScrollNotification>(
              onNotification: (scrollNotification) {
                if (scrollNotification is ScrollUpdateNotification) {
                  if (scrollNotification.scrollDelta != null) {
                    // إخفاء الإحصائيات عند التمرير للأسفل
                    if (scrollNotification.scrollDelta! > 0 && _showStats) {
                      setState(() {
                        _showStats = false;
                      });
                    } 
                    // إظهار الإحصائيات عند التمرير للأعلى والوصول قريباً من القمة
                    else if (scrollNotification.scrollDelta! < 0 && !_showStats && 
                            scrollNotification.metrics.pixels < 50) {
                      setState(() {
                        _showStats = true;
                      });
                    }
                  }
                }
                return false;
              },
              child: Column(
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

                  // Collapsible Statistics
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _showStats ? null : 0.0,
                    child: Opacity(
                      opacity: _showStats ? 1.0 : 0.0,
                      child: CollapsibleOrderStats(
                        totalOrders: _allOrders.length,
                        pendingOrders: pendingCount,
                        processingOrders: processingCount,
                        completedOrders: completedCount,
                      ),
                    ),
                  ),
                  
                  // Tab bar for order status
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorWeight: 3,
                      indicatorColor: theme.colorScheme.primary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        Tab(
                          text: 'الكل (${_filteredOrders.length})',
                        ),
                        Tab(
                          text: 'قيد المعالجة (${pendingCount + processingCount})',
                        ),
                        Tab(
                          text: 'المكتملة (${completedCount + cancelledCount})',
                        ),
                      ],
                    ),
                  ),
                  
                  // Orders content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // All orders tab
                        _buildOrdersList(_filteredOrders),
                        
                        // Processing orders tab (everything not completed or cancelled)
                        _buildOrdersList(
                          _filteredOrders.where((order) => 
                            order.status == 'قيد الانتظار' || 
                            order.status == 'قيد التنفيذ' || 
                            order.status == 'تم التجهيز'
                          ).toList(),
                        ),
                        
                        // Completed orders tab (only completed or cancelled)
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
  
  // Build orders list with animations
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
            const Text('لا توجد طلبات مطابقة'),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: AnimationLimiter(
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _buildOrderCard(order),
                ),
              ),
            );
          },
        ),
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
        onTap: () => _showOrderDetails(order),
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
              
              // Customer info
              Row(
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (order.warehouseName != null && order.warehouseName!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order.warehouseName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
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
              
              // Action buttons
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'التاريخ: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showOrderDetails(order),
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
  
  // دالة موحدة لعرض تفاصيل الطلب
  Future<void> _showOrderDetails(OrderModel order) async {
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
    
    try {
      // محاولة الحصول على تفاصيل الطلب
      int orderId;
      try {
        // محاولة استخراج الرقم من رقم الطلب
        final numericPart = order.orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
        if (numericPart.isNotEmpty) {
          orderId = int.parse(numericPart);
        } else {
          // استخدام معرف الطلب إذا لم يكن هناك جزء رقمي
          orderId = int.parse(order.id);
        }
      } catch (e) {
        // استخدام طريقة بديلة في حالة فشل التحويل
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('جاري محاولة الحصول على تفاصيل الطلب بطريقة بديلة...')),
          );
        }
        orderId = int.parse(order.id);
      }
      
      OrderModel detailedOrder = order;
      final orderDetail = await _stockWarehouseApi.getOrderDetail(orderId);
      if (orderDetail != null) {
        detailedOrder = orderDetail;
      }
      
      // إغلاق مؤشر التحميل
      if (mounted) Navigator.of(context).pop();
      
      // عرض تفاصيل الطلب
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => SharedOrderDetailsDialog(
            order: detailedOrder,
            userRole: 'owner',
          ),
        );
      }
    } catch (e) {
      // إغلاق مؤشر التحميل في حالة الخطأ
      if (mounted) Navigator.of(context).pop();
      
      // عرض الخطأ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل تفاصيل الطلب: $e')),
        );
        
        // عرض التفاصيل الأساسية حتى في حالة الخطأ
        showDialog(
          context: context,
          builder: (context) => SharedOrderDetailsDialog(
            order: order,
            userRole: 'owner',
          ),
        );
      }
    }
  }
}

class CollapsibleOrderStats extends StatefulWidget {
  final int totalOrders;
  final int pendingOrders;
  final int processingOrders;
  final int completedOrders;

  const CollapsibleOrderStats({
    Key? key,
    required this.totalOrders,
    required this.pendingOrders,
    required this.processingOrders,
    required this.completedOrders,
  }) : super(key: key);

  @override
  State<CollapsibleOrderStats> createState() => _CollapsibleOrderStatsState();
}

class _CollapsibleOrderStatsState extends State<CollapsibleOrderStats> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'إحصائيات الطلبات',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),

              // Expandable content
              if (_isExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        context,
                        'إجمالي الطلبات',
                        widget.totalOrders.toString(),
                        Icons.receipt,
                        theme.colorScheme.primary,
                      ),
                      _buildStatItem(
                        context,
                        'قيد الانتظار',
                        widget.pendingOrders.toString(),
                        Icons.pending_actions,
                        Colors.orange,
                      ),
                      _buildStatItem(
                        context,
                        'قيد التنفيذ',
                        widget.processingOrders.toString(),
                        Icons.sync,
                        Colors.blue,
                      ),
                      _buildStatItem(
                        context,
                        'مكتملة',
                        widget.completedOrders.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
