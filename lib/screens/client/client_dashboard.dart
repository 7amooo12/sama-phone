import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/widgets/client/product_card.dart';
import 'package:smartbiztracker_new/widgets/client/order_summary_card.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/models/product_model.dart';

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
      // final productProvider = Provider.of<ProductProvider>(context, listen: false);
      // productProvider.fetchClientProducts();

      // final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      // orderProvider.fetchClientOrders();
    });
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
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: CustomAppBar(
            title: 'لوحة تحكم العميل',
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: _openDrawer,
            ),
          ),
        ),
        drawer: MainDrawer(
          onMenuPressed: _openDrawer,
          currentRoute: AppRoutes.clientDashboard,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AnimationLimiter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 600),
                childAnimationBuilder: (widget) => SlideAnimation(
                  horizontalOffset: 50.0,
                  child: FadeInAnimation(
                    child: widget,
                  ),
                ),
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
                  const SizedBox(height: 24),

                  // Faults
                  _buildRecentFaults(theme),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            // Navigate to new order screen
          },
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('طلب جديد'),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(UserModel userModel, ThemeData theme) {
    final welcomeMessage = _getWelcomeMessage();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.safeOpacity(0.2),
                  child: Text(
                    userModel.name.isNotEmpty
                        ? userModel.name[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userModel.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  icon: Icons.shopping_cart,
                  title: 'الطلبات النشطة',
                  value: '0',
                  color: Colors.white,
                ),
                _buildStatCard(
                  icon: Icons.local_shipping,
                  title: 'قيد الشحن',
                  value: '0',
                  color: Colors.white,
                ),
                _buildStatCard(
                  icon: Icons.check_circle,
                  title: 'مكتمل',
                  value: '0',
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.safeOpacity(0.2),
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: color.safeOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الإجراءات السريعة',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionButton(
              icon: Icons.shopping_basket,
              title: 'تصفح المنتجات',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.clientProducts);
              },
              color: theme.colorScheme.primary,
            ),
            _buildActionButton(
              icon: Icons.add_shopping_cart,
              title: 'طلب جديد',
              onTap: () {
                // Navigate to new order screen
              },
              color: theme.colorScheme.secondary,
            ),
            _buildActionButton(
              icon: Icons.assignment_return,
              title: 'إرجاع منتج',
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.customerService,
                  arguments: {'initialTabIndex': 1}, // Index for return tab
                );
              },
              color: theme.colorScheme.tertiary,
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
          ],
        ),
      ],
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
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 75,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
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
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOrders(ThemeData theme) {
    const hasOrders = false; // Set to false to show empty state until real data is available

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الطلبات الأخيرة',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.clientOrders);
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('الكل'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasOrders)
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 0, // No items until real data is available
              itemBuilder: (context, index) {
                return const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 280,
                    child: OrderSummaryCard(
                      orderNumber: '',
                      date: '',
                      totalAmount: 0.0,
                      status: '',
                      itemCount: 0,
                      onTap: null,
                    ),
                  ),
                );
              },
            ),
          )
        else
          _buildEmptyState(
            theme,
            'لا يوجد طلبات بعد',
            'ابدأ بتقديم طلب جديد لعرضه هنا.',
          ),
      ],
    );
  }

  Widget _buildFeaturedProducts(ThemeData theme) {
    // Set to false to show empty state until real data is available
    const hasProducts = false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'منتجات مميزة',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.clientProducts);
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('الكل'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasProducts)
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 0, // No items until real data is available
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 160,
                    child: ProductCard(
                      product: ProductModel(
                        id: '',
                        name: '',
                        price: 0,
                        quantity: 0,
                        imageUrl: null,
                        description: '',
                        category: '',
                        tags: [],
                        images: [],
                        sku: '',
                        isActive: true,
                        createdAt: DateTime.now(),
                        reorderPoint: 0,
                      ),
                      onTap: () {},
                    ),
                  ),
                );
              },
            ),
          )
        else
          _buildEmptyState(
            theme,
            'لا يوجد منتجات بعد',
            'سيتم عرض المنتجات المميزة هنا',
          ),
      ],
    );
  }

  Widget _buildRecentFaults(ThemeData theme) {
    const hasFaults = false; // Change based on actual data

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الأخطاء المبلغ عنها',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.clientFaults);
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('الكل'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasFaults)
          const SizedBox(
            height: 200,
            // Replace with actual fault list
            child: Center(
              child: Text('قائمة الأخطاء المبلغ عنها'),
            ),
          )
        else
          _buildEmptyState(
            theme,
            'لا يوجد أخطاء مبلغ عنها',
            'جميع منتجاتك تعمل بشكل جيد!',
          ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor,
        ),
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
              return Icon(
                Icons.inbox,
                size: 48,
                color: theme.colorScheme.onSurface.safeOpacity(0.4),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.safeOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
}
