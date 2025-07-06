import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/notification_provider.dart';
import 'package:smartbiztracker_new/providers/client_orders_provider.dart';
import 'package:smartbiztracker_new/providers/simplified_product_provider.dart';
import 'package:smartbiztracker_new/widgets/client/product_card.dart';
import 'package:smartbiztracker_new/widgets/client/order_summary_card.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/accountant/modern_widgets.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/screens/client/my_vouchers_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPressTime; // لتتبع آخر ضغطة على زر العودة

  // طريقة لفتح السلايدبار
  void _openDrawer() {
    if (_scaffoldKey.currentState != null && !_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  @override
  void initState() {
    super.initState();

    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final user = supabaseProvider.user;

    if (user != null) {
      // Load client orders
      final orderProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
      await orderProvider.loadClientOrders(user.id);

      // Load products
      final productProvider = Provider.of<SimplifiedProductProvider>(context, listen: false);
      await productProvider.loadProducts();
    }
  }

  // منطق التعامل مع زر العودة
  Future<bool> _onWillPop() async {
    // إذا كان مفتوح الدرج الجانبي، أغلقه عند الضغط على العودة بدلاً من إغلاق التطبيق
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      return false;
    }

    // في الشاشة الرئيسية، يتطلب ضغطتين متتاليتين خلال ثانيتين للخروج من التطبيق
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اضغط مرة أخرى للخروج من التطبيق'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AccountantThemeConfig.luxuryBlack,

        drawer: MainDrawer(
          onMenuPressed: _openDrawer,
          currentRoute: AppRoutes.clientDashboard,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16), // Increased top padding for better visual separation
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                _buildWelcomeCard(userModel, theme),
                const SizedBox(height: 24),

                // Quick Actions
                _buildQuickActions(theme),
                const SizedBox(height: 24),

                // Recent Orders
                _buildRecentOrders(theme),
                const SizedBox(height: 24),

                // Products
                _buildFeaturedProducts(theme),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'new_order',
          onPressed: () {
            Navigator.of(context).pushNamed(AppRoutes.clientProductsBrowser);
          },
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text(
            'طلب جديد',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(UserModel userModel, ThemeData theme) {
    final welcomeMessage = _getWelcomeMessage();

    return Consumer<ClientOrdersProvider>(
      builder: (context, orderProvider, child) {
        // Calculate real statistics from orders
        final orders = orderProvider.orders;
        final activeOrders = orders.where((order) =>
          order.status == OrderStatus.pending ||
          order.status == OrderStatus.confirmed ||
          order.status == OrderStatus.processing
        ).length;

        final shippingOrders = orders.where((order) =>
          order.status == OrderStatus.shipped
        ).length;

        final completedOrders = orders.where((order) =>
          order.status == OrderStatus.delivered
        ).length;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8), // Add bottom margin for better spacing
          padding: const EdgeInsets.all(24),
          decoration: AccountantThemeConfig.primaryCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.greenGradient,
                      shape: BoxShape.circle,
                      boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                    ),
                    child: Center(
                      child: Text(
                        userModel.name.isNotEmpty
                            ? userModel.name[0].toUpperCase()
                            : 'C',
                        style: AccountantThemeConfig.headlineMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          welcomeMessage,
                          style: AccountantThemeConfig.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userModel.name,
                          style: AccountantThemeConfig.headlineSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Header buttons positioned for RTL layout
                  Row(
                    children: [
                      _buildNotificationButton(),
                      const SizedBox(width: 8),
                      _buildHeaderButton(
                        icon: Icons.menu_rounded,
                        onPressed: _openDrawer,
                        tooltip: 'القائمة',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.shopping_cart,
                      title: 'الطلبات النشطة',
                      value: activeOrders.toString(),
                      color: AccountantThemeConfig.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.local_shipping,
                      title: 'قيد الشحن',
                      value: shippingOrders.toString(),
                      color: AccountantThemeConfig.accentBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.check_circle,
                      title: 'مكتمل',
                      value: completedOrders.toString(),
                      color: AccountantThemeConfig.secondaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(color),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.8)],
              ),
              shape: BoxShape.circle,
              boxShadow: AccountantThemeConfig.glowShadows(color),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإجراءات السريعة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        const SizedBox(height: 16),
        // First row of action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionButton(
              icon: Icons.shopping_basket,
              title: 'تصفح المنتجات',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.clientProductsBrowser);
              },
              color: AccountantThemeConfig.primaryGreen,
            ),
            _buildActionButton(
              icon: Icons.list_alt,
              title: 'طلباتي',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.clientTracking);
              },
              color: AccountantThemeConfig.secondaryGreen,
            ),
            _buildActionButton(
              icon: Icons.local_offer,
              title: 'قسائمي',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MyVouchersScreen(),
                  ),
                );
              },
              color: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row of action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionButton(
              icon: Icons.local_shipping_rounded,
              title: 'تتبع آخر طلب',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.clientTrackLatestOrder);
              },
              color: AccountantThemeConfig.accentBlue,
            ),
            _buildActionButton(
              icon: Icons.error_outline,
              title: 'إبلاغ عن خطأ',
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.customerService,
                  arguments: {'initialTabIndex': 0}, // Index for error report tab
                );
              },
              color: theme.colorScheme.error,
            ),
            _buildActionButton(
              icon: Icons.account_balance_wallet,
              title: 'محفظتي',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.userWallet);
              },
              color: Colors.teal,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Third row of action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionButton(
              icon: Icons.assignment_return,
              title: 'تتبع الاخطاء',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.customerRequests);
              },
              color: Colors.indigo,
            ),
          ],
        ),

      ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 75,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                ),
                shape: BoxShape.circle,
                boxShadow: AccountantThemeConfig.glowShadows(color),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders(ThemeData theme) {
    return Consumer<ClientOrdersProvider>(
      builder: (context, orderProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الطلبات الأخيرة',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.clientTracking);
                    },
                    icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                    label: const Text(
                      'الكل',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (orderProvider.isLoading)
              _buildOrdersLoadingState()
            else if (orderProvider.error != null)
              _buildOrdersErrorState(orderProvider.error.toString())
            else if (orderProvider.orders.isEmpty)
              _buildEmptyState(
                theme,
                'لا يوجد طلبات بعد',
                'ابدأ بتقديم طلب جديد لعرضه هنا.',
              )
            else
              _buildOrdersList(orderProvider.orders.take(3).cast<ClientOrder>().toList()),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedProducts(ThemeData theme) {
    return Consumer<SimplifiedProductProvider>(
      builder: (context, productProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'منتجات مميزة',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.clientProductsBrowser);
                    },
                    icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                    label: const Text(
                      'الكل',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (productProvider.isLoading)
              _buildProductsLoadingState()
            else if (productProvider.error != null)
              _buildProductsErrorState(productProvider.error.toString())
            else if (productProvider.products.isEmpty)
              _buildEmptyState(
                theme,
                'لا يوجد منتجات بعد',
                'سيتم عرض المنتجات المميزة هنا',
              )
            else
              _buildProductsList(_getFeaturedProducts(productProvider.products).take(6).cast<ProductModel>().toList()),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AccountantThemeConfig.transparentCardDecoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              shape: BoxShape.circle,
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Filter products to show only featured products (منتجات مميزة)
  List<ProductModel> _getFeaturedProducts(List<ProductModel> allProducts) {
    final featuredProducts = allProducts.where((product) {
      final categoryLower = product.category.toLowerCase();
      final nameLower = product.name.toLowerCase();

      // Smart filtering for featured products
      final isFeatured = (categoryLower.contains('منتجات مميزة') ||
                         categoryLower.contains('مميز') ||
                         categoryLower.contains('featured') ||
                         categoryLower.contains('مختار') ||
                         nameLower.contains('مميز')) &&
                        product.quantity > 0; // Only show products in stock

      // Debug logging to help troubleshoot filtering
      if (isFeatured) {
        print('✅ Featured product found: ${product.name} (Category: ${product.category})');
      }

      return isFeatured;
    }).toList();

    print('📊 Featured products filter result: ${featuredProducts.length} out of ${allProducts.length} total products');
    return featuredProducts;
  }

  String _getWelcomeMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير،';
    } else {
      // Combined afternoon and evening greeting since they were the same
      return 'مساء الخير،';
    }
  }

  // Header button styled for greeting section
  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 20,
      ),
    );
  }

  // Notification button with badge for greeting section
  Widget _buildNotificationButton() {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount as int;

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: IconButton(
                icon: Icon(
                  unreadCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.notifications);
                },
                tooltip: 'الإشعارات',
                splashRadius: 20,
              ),
            ),
            // Badge for unread notifications
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Orders loading state
  Widget _buildOrdersLoadingState() {
    return Container(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: AccountantThemeConfig.primaryCardDecoration,
            child: Column(
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const Spacer(),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Orders error state
  Widget _buildOrdersErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AccountantThemeConfig.transparentCardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'خطأ في تحميل الطلبات',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Orders list with professional cards
  Widget _buildOrdersList(List<ClientOrder> orders) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(order, index);
        },
      ),
    );
  }

  // Professional order card
  Widget _buildOrderCard(ClientOrder order, int index) {
    final statusColor = _getOrderStatusColor(order.status);
    final statusText = _getOrderStatusText(order.status);

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AccountantThemeConfig.luxuryBlack,
            AccountantThemeConfig.luxuryBlack.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRoutes.clientTracking,
              arguments: order.id,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'طلب #${order.id.substring(0, 8).toUpperCase()}',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _formatDate(order.createdAt),
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${order.items.length} منتج',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    // Price section with pricing approval logic
                    _shouldShowPricesForOrder(order)
                        ? Text(
                            AccountantThemeConfig.formatCurrency(order.total),
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: AccountantThemeConfig.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : _buildPendingPriceIndicator(),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _getOrderProgress(order.status),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [statusColor, statusColor.withValues(alpha: 0.7)],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.5),
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

  // Helper methods for order status
  Color _getOrderStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.shipped:
        return Colors.purple;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getOrderStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'قيد المراجعة';
      case OrderStatus.confirmed:
        return 'مؤكد';
      case OrderStatus.shipped:
        return 'قيد الشحن';
      case OrderStatus.delivered:
        return 'تم التسليم';
      case OrderStatus.cancelled:
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  double _getOrderProgress(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0.2;
      case OrderStatus.confirmed:
        return 0.4;
      case OrderStatus.shipped:
        return 0.7;
      case OrderStatus.delivered:
        return 1.0;
      case OrderStatus.cancelled:
        return 0.1;
      default:
        return 0.0;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'اليوم';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Determines if prices should be shown for a specific order based on pricing approval status
  bool _shouldShowPricesForOrder(ClientOrder order) {
    // Show prices if:
    // 1. Order doesn't require pricing approval, OR
    // 2. Pricing has been approved
    return !order.requiresPricingApproval || order.isPricingApproved;
  }

  /// Widget to show when order price is pending approval
  Widget _buildPendingPriceIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
            AccountantThemeConfig.warningOrange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 12,
            color: AccountantThemeConfig.warningOrange,
          ),
          const SizedBox(width: 4),
          Text(
            'في انتظار التسعير',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: AccountantThemeConfig.warningOrange,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // Products loading state
  Widget _buildProductsLoadingState() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            decoration: AccountantThemeConfig.primaryCardDecoration,
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 14,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Products error state
  Widget _buildProductsErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AccountantThemeConfig.transparentCardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'خطأ في تحميل المنتجات',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Products list with stunning cards
  Widget _buildProductsList(List<ProductModel> products) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(product, index);
        },
      ),
    );
  }

  // Stunning product card
  Widget _buildProductCard(ProductModel product, int index) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AccountantThemeConfig.luxuryBlack,
            AccountantThemeConfig.luxuryBlack.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRoutes.clientProductsBrowser,
              arguments: product.id,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                        AccountantThemeConfig.primaryGreen.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: _buildFeaturedProductImage(product),
                      ),
                      // Gradient overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AccountantThemeConfig.luxuryBlack.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Product details
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      // Only show availability status, no price for featured products
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: product.quantity > 0
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: product.quantity > 0
                                    ? Colors.green.withValues(alpha: 0.5)
                                    : Colors.red.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              product.quantity > 0 ? 'متوفر' : 'نفد المخزون',
                              style: TextStyle(
                                color: product.quantity > 0 ? Colors.green : Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Enhanced image loading for featured products using the same mechanism as products tab
  Widget _buildFeaturedProductImage(ProductModel product) {
    final imageUrl = product.bestImageUrl;

    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                    AccountantThemeConfig.primaryGreen.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      color: AccountantThemeConfig.primaryGreen,
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تحميل...',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildProductPlaceholder(),
        ),
      );
    } else {
      return _buildProductPlaceholder();
    }
  }

  // Product placeholder for missing images
  Widget _buildProductPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
            AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_rounded,
              size: 40,
              color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 4),
            Text(
              'منتج مميز',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
