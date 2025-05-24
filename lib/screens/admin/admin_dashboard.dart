import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/widgets/admin/dashboard_card.dart';
import 'package:smartbiztracker_new/widgets/admin/approval_card.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'admin_products_screen.dart';
import 'analytics_screen.dart';
import 'package:smartbiztracker_new/screens/admin_products_page.dart';
import 'package:smartbiztracker_new/services/analytics_service.dart';
import 'package:smartbiztracker_new/models/analytics_dashboard_model.dart';
import 'package:smartbiztracker_new/services/samastock_api.dart';
import 'package:smartbiztracker_new/models/product_model.dart';

import 'package:smartbiztracker_new/widgets/feature_card.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المدير'),
      ),
      body: const Center(
        child: Text('لوحة تحكم المدير'),
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();

    // Fetch pending approval users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      supabaseProvider.fetchAllUsers();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      child: Directionality(
        // Support RTL for Arabic
        textDirection: TextDirection.rtl,
        child: Scaffold(
          key: _scaffoldKey,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: CustomAppBar(
              title: 'لوحة تحكم المدير',
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: _openDrawer,
              ),
              hideStatusBarHeader: true,
            ),
          ),
          drawer: MainDrawer(
            onMenuPressed: _openDrawer,
            currentRoute: AppRoutes.adminDashboard,
          ),
          body: Container(
            color: theme.scaffoldBackgroundColor,
            child: RefreshIndicator(
              onRefresh: () async {
                await supabaseProvider.fetchAllUsers();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Welcome Section
                  SliverToBoxAdapter(
                    child: _buildWelcomeSection(userModel),
                  ),

                  // Quick Stats
                  SliverToBoxAdapter(
                    child: _buildQuickStats(),
                  ),

                  // Pending Approvals Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'طلبات تسجيل جديدة',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(context)
                                      .pushNamed(AppRoutes.approvalRequests);
                                },
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('عرض الكل'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildPendingApprovals(supabaseProvider),
                        ],
                      ),
                    ),
                  ),

                  // Available Products Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'المنتجات المتاحة',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(context)
                                      .pushNamed(AppRoutes.adminProductsView);
                                },
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('عرض الكل'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildAvailableProducts(),
                        ],
                      ),
                    ),
                  ),

                  // Dashboard Cards
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: _buildDashboardCards(),
                  ),

                  // Recent Activities
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildRecentActivities(),
                    ),
                  ),

                  // Bottom Padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.chatList);
            },
            icon: const Icon(Icons.chat),
            label: const Text('الدردشات'),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(UserModel userModel) {
    final theme = Theme.of(context);
    final welcomeMessage = _getWelcomeMessage();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Text(
            welcomeMessage,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // User name
          Text(
            userModel.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Admin role tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.safeOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'مدير',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final theme = Theme.of(context);

    return FutureBuilder<AnalyticsDashboardModel>(
      future: AnalyticsService().getAdminDashboardAnalytics(),
      builder: (context, snapshot) {
        // Default values for when data is loading or there's an error
        String userCount = '0';
        String orderCount = '0';
        String productCount = '0';
        String errorCount = '0';
        
        // If we have data from the API, use it
        if (snapshot.hasData) {
          userCount = snapshot.data!.users.active.toString();
          orderCount = snapshot.data!.sales.totalInvoices.toString();
          productCount = snapshot.data!.products.visible.toString(); // Only visible products
          // We don't have error count in analytics model, so it stays 0
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.safeOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.safeOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    'ملخص سريع',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                      children: [
                        _buildStatItem(
                          title: 'المستخدمين',
                          value: userCount,
                          icon: Icons.people,
                          color: theme.colorScheme.primary,
                        ),
                        _buildStatItem(
                          title: 'الطلبات',
                          value: orderCount,
                          icon: Icons.shopping_cart,
                          color: Colors.amber,
                        ),
                        _buildStatItem(
                          title: 'المنتجات المتاحة',
                          value: productCount,
                          icon: Icons.inventory,
                          color: theme.colorScheme.secondary,
                        ),
                        _buildStatItem(
                          title: 'الأخطاء',
                          value: errorCount,
                          icon: Icons.error,
                          color: Colors.red,
                        ),
                      ],
                    ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.safeOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.safeOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovals(SupabaseProvider supabaseProvider) {
    final pendingUsers = supabaseProvider.users;
    final theme = Theme.of(context);

    if (supabaseProvider.isLoading && pendingUsers.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (pendingUsers.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.safeOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/empty_state.json',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.inbox,
                  size: 60,
                  color: Colors.grey,
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد طلبات تسجيل جديدة',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // Only show first 3 pending users in the dashboard
    final displayedUsers = pendingUsers.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.safeOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ...displayedUsers.map((user) => ApprovalCard(
                user: user,
                onApprove: (UserModel user, String role) async {
                  // Store whether context is mounted before the async call
                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                  await supabaseProvider.approveUserAndSetRole(
                    userId: user.id,
                    roleStr: role,
                  );

                  // Check if the context is still valid before showing the SnackBar
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('تمت الموافقة بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              )),
        ],
      ),
    );
  }

  Widget _buildAvailableProducts() {
    final theme = Theme.of(context);
    final samaStockApi = Provider.of<SamaStockApiService>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.safeOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.safeOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inventory,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'المنتجات المتاحة للبيع',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<List<ProductModel>>(
            future: samaStockApi.getProductsWithApiKey(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('حدث خطأ في جلب البيانات: ${snapshot.error}'),
                );
              }
              
              final allProducts = snapshot.data ?? [];
              
              // Filter only available products (those with quantity > 0)
              final availableProducts = allProducts
                  .where((product) => product.quantity > 0 && product.isActive)
                  .toList();
              
              if (availableProducts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: theme.colorScheme.primary.withOpacity(0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد منتجات متاحة حالياً',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Take the first 5 products
              final displayProducts = availableProducts.take(5).toList();
              
              return ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: displayProducts.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = displayProducts[index];
                  
                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                        image: product.imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(product.imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: product.imageUrl == null
                          ? Icon(
                              Icons.image_not_supported_outlined,
                              color: theme.colorScheme.primary.withOpacity(0.5),
                            )
                          : null,
                    ),
                    title: Text(
                      product.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'الكمية: ${product.quantity} | السعر: ${product.price.toStringAsFixed(2)} ج.م',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.safeOpacity(0.7),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.arrow_forward_ios, 
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        // Navigate to product details
                        Navigator.of(context).pushNamed(
                          AppRoutes.adminProductsView,
                        );
                      },
                    ),
                    tileColor: index % 2 == 0 ? theme.colorScheme.surface.withOpacity(0.5) : theme.colorScheme.surface.withOpacity(0.3),
                  );
                },
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCards() {
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final pendingUsersCount = supabaseProvider.users.length;
    
    return AnimationLimiter(
      child: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        delegate: SliverChildListDelegate(
          AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 375),
            childAnimationBuilder: (widget) => SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: [
              DashboardCard(
                title: 'المنتجات',
                description: 'عرض وإدارة جميع المنتجات',
                icon: Icons.inventory,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminProductsScreen(),
                    ),
                  );
                },
              ),
              DashboardCard(
                title: 'عرض المنتجات',
                description: 'عرض منتجات الـ API (مرئية وغير مرئية)',
                icon: Icons.grid_view,
                color: Colors.teal,
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.adminProductsView);
                },
              ),
              DashboardCard(
                title: 'المستخدمين',
                description: 'إدارة حسابات المستخدمين',
                icon: Icons.people,
                color: Colors.purple,
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.userManagement);
                },
              ),
              DashboardCard(
                title: 'إسناد مهام للعمال',
                description: 'تكليف العمال بمهام إنتاج المنتجات',
                icon: Icons.engineering,
                color: Colors.red,
                onTap: () {
                  Navigator.of(context).pushNamed('/admin/assign-tasks');
                },
              ),
              DashboardCard(
                title: 'طلبات التسجيل',
                description: 'الموافقة على طلبات المستخدمين الجدد',
                icon: Icons.approval,
                color: Colors.green,
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.approvalRequests);
                },
                badge: pendingUsersCount > 0 ? pendingUsersCount.toString() : null,
                badgeColor: Colors.red,
              ),
              DashboardCard(
                title: 'تحليلات الأعمال',
                description: 'إحصائيات ومؤشرات أداء العمل',
                icon: Icons.analytics,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalyticsScreen(),
                    ),
                  );
                },
              ),
              DashboardCard(
                title: 'إدارة الطلبات',
                description: 'متابعة جميع الطلبات النشطة',
                icon: Icons.shopping_cart,
                color: Colors.orange,
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.orders);
                },
              ),
              DashboardCard(
                title: 'إدارة الهالك',
                description: 'متابعة العناصر التالفة',
                icon: Icons.inventory_2,
                color: Colors.red,
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.waste);
                },
              ),
              
                            // Image search feature removed
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    final theme = Theme.of(context);
    final stockWarehouseApi = Provider.of<StockWarehouseApiService>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.safeOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.safeOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'النشاطات الأخيرة',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<List<OrderModel>>(
            future: stockWarehouseApi.getOrders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('حدث خطأ في جلب البيانات: ${snapshot.error}'),
                );
              }
              
              final orders = snapshot.data ?? [];
              
              if (orders.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 48,
                          color: theme.colorScheme.primary.withOpacity(0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد أنشطة حديثة',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Sort orders by date descending (newest first)
              orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              
              // Take the 5 most recent orders
              final recentOrders = orders.take(5).toList();
              
              return ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: recentOrders.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final order = recentOrders[index];
                  final timeDiff = DateTime.now().difference(order.createdAt);
                  final timeAgo = _getTimeAgo(timeDiff);
                  
                  return _buildActivityItem(
                    title: 'طلب جديد #${order.orderNumber} - ${order.customerName}',
                    time: timeAgo,
                    icon: Icons.shopping_bag,
                    iconColor: _getStatusColor(order.status),
                  );
                },
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required String title,
    required String time,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.safeOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        time,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.safeOpacity(0.6),
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.arrow_forward_ios, size: 16),
        onPressed: () {
          // Navigate to activity details
        },
      ),
    );
  }

  String _getWelcomeMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير،';
    } else if (hour < 18) {
      return 'مساء الخير،';
    } else {
      return 'مساء الخير،';
    }
  }

  // Helper for formatting time ago
  String _getTimeAgo(Duration difference) {
    if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} ${difference.inDays == 1 ? 'يوم' : 'أيام'}';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ${difference.inHours == 1 ? 'ساعة' : 'ساعات'}';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} ${difference.inMinutes == 1 ? 'دقيقة' : 'دقائق'}';
    } else {
      return 'منذ لحظات';
    }
  }
  
  // Helper for getting status color
  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status.contains('pending') || status.contains('قيد الانتظار') || status.contains('معلق')) {
      return Colors.orange;
    } else if (status.contains('delivered') || status.contains('completed') || 
               status.contains('تم التسليم') || status.contains('مكتمل')) {
      return Colors.green;
    } else if (status.contains('canceled') || status.contains('cancelled') || status.contains('ملغي')) {
      return Colors.red;
    } else if (status.contains('processing') || status.contains('قيد المعالجة')) {
      return Colors.blue;
    }
    return Colors.grey;
  }
}
