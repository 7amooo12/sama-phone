import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/providers/client_orders_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:provider/provider.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';
  List<ClientOrder> _filteredOrders = [];

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
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final user = supabaseProvider.user;

    if (user == null) return;

    final clientOrdersProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
    await clientOrdersProvider.loadClientOrders(user.id);

    // Apply current search filter
    _filterOrders();
  }

  // Filter orders based on search query
  void _filterOrders() {
    final clientOrdersProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
    final allOrders = clientOrdersProvider.orders;

    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredOrders = List.from(allOrders);
      });
      return;
    }

    final filtered = allOrders.where((order) {
      return order.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             order.statusText.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             order.clientName.toLowerCase().contains(_searchQuery.toLowerCase());
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
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final userModel = supabaseProvider.user;

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
      backgroundColor: StyleSystem.backgroundDark,
      appBar: CustomAppBar(
        title: 'طلباتي',
        backgroundColor: StyleSystem.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
            ),
            onPressed: _loadOrders,
          ),
        ],
      ),
      drawer: const MainDrawer(currentRoute: '/orders'),
      body: Consumer<ClientOrdersProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading) {
            return Container(
              color: StyleSystem.backgroundDark,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: StyleSystem.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'جاري تحميل طلباتك...',
                      style: StyleSystem.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Update filtered orders when provider data changes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _filterOrders();
          });

          return Column(
            children: [
              // Search bar
              _buildSearchBar(),

              // Orders content
              Expanded(
                child: _filteredOrders.isEmpty
                    ? _buildEmptyOrdersView()
                    : _buildOrdersList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.surfaceDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: StyleSystem.primaryColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: StyleSystem.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TextField(
        onChanged: _onSearchChanged,
        style: StyleSystem.bodyMedium.copyWith(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: 'البحث في الطلبات...',
          hintStyle: StyleSystem.bodyMedium.copyWith(
            color: Colors.white.withOpacity(0.6),
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StyleSystem.primaryColor,
                  StyleSystem.secondaryColor,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // Empty orders view with animation
  Widget _buildEmptyOrdersView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StyleSystem.primaryColor.withOpacity(0.1),
                  StyleSystem.secondaryColor.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: StyleSystem.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد طلبات حالياً',
            style: StyleSystem.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ابدأ بتصفح المنتجات وإضافة طلبات جديدة',
            style: StyleSystem.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/customer-products');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: StyleSystem.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.shopping_cart_rounded),
            label: const Text('تصفح المنتجات'),
          ),
        ],
      ),
    );
  }

  // Build orders list
  Widget _buildOrdersList() {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: StyleSystem.primaryColor,
      backgroundColor: StyleSystem.surfaceDark,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredOrders.length,
        itemBuilder: (context, index) {
          final order = _filteredOrders[index];
          return _buildOrderCard(order, index);
        },
      ),
    );
  }

  // Build order card
  Widget _buildOrderCard(ClientOrder order, int index) {
    // Get color for order status
    Color statusColor;
    IconData statusIcon;

    switch (order.status) {
      case OrderStatus.pending:
        statusColor = Colors.amber;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case OrderStatus.confirmed:
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case OrderStatus.processing:
        statusColor = Colors.purple;
        statusIcon = Icons.build_circle_outlined;
        break;
      case OrderStatus.shipped:
        statusColor = Colors.indigo;
        statusIcon = Icons.local_shipping_outlined;
        break;
      case OrderStatus.delivered:
        statusColor = Colors.green;
        statusIcon = Icons.done_all_rounded;
        break;
      case OrderStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.surfaceDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showOrderDetails(order),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order header with number and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                StyleSystem.primaryColor,
                                StyleSystem.secondaryColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'طلب #${order.id.substring(0, 8).toUpperCase()}',
                              style: StyleSystem.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _formatDate(order.createdAt),
                              style: StyleSystem.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order.statusText,
                            style: StyleSystem.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Order summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: StyleSystem.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: StyleSystem.primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Items count
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.shopping_basket_outlined,
                              size: 18,
                              color: StyleSystem.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${order.items.length} منتج',
                              style: StyleSystem.bodyMedium.copyWith(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Total amount
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.payments_outlined,
                              size: 18,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${order.total.toStringAsFixed(2)} ر.س',
                              style: StyleSystem.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Action button
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showOrderDetails(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StyleSystem.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: Text(
                      'عرض التفاصيل',
                      style: StyleSystem.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (index * 100).ms).fadeIn(duration: 400.ms).slideY(begin: 0.2);
  }

  void _showOrderDetails(ClientOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailsSheet(order: order),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Order Details Sheet
class _OrderDetailsSheet extends StatelessWidget {

  const _OrderDetailsSheet({required this.order});
  final ClientOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.backgroundDark,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: StyleSystem.primaryColor.withOpacity(0.6),
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
                  style: StyleSystem.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24),

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
                  ),

                  const SizedBox(height: 20),

                  // Items
                  _buildItemsSection(order.items),

                  const SizedBox(height: 20),

                  // Totals - Hide if pricing is pending
                  _buildDetailSection(
                    'المجموع',
                    [
                      order.status == OrderStatus.pending
                        ? 'سيتم تحديد السعر النهائي بعد مراجعة الطلب'
                        : 'الإجمالي: ${order.total.toStringAsFixed(2)} ر.س',
                    ],
                  ),

                  if (order.shippingAddress != null && order.shippingAddress!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildDetailSection(
                      'عنوان الشحن',
                      [order.shippingAddress!],
                    ),
                  ],

                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildDetailSection(
                      'ملاحظات',
                      [order.notes!],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: StyleSystem.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: StyleSystem.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StyleSystem.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: StyleSystem.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item,
                style: StyleSystem.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection(List<OrderItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المنتجات (${items.length})',
          style: StyleSystem.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: StyleSystem.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StyleSystem.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: StyleSystem.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: StyleSystem.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الكمية: ${item.quantity}',
                      style: StyleSystem.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(item.price * item.quantity).toStringAsFixed(2)} ر.س',
                style: StyleSystem.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
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
