import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/widgets/admin/dashboard_card.dart';
import 'package:smartbiztracker_new/widgets/admin/approval_card.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/providers/client_orders_provider.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'analytics_screen.dart';
import 'package:smartbiztracker_new/services/analytics_service.dart';
import 'package:smartbiztracker_new/models/analytics_dashboard_model.dart';
import 'package:smartbiztracker_new/services/samastock_api.dart';
import 'package:smartbiztracker_new/models/product_model.dart';

import 'package:smartbiztracker_new/screens/admin/user_management_screen.dart';
import 'package:smartbiztracker_new/screens/admin/admin_products_screen.dart';
import 'package:smartbiztracker_new/screens/admin/electronic_payment_management_screen.dart';
import 'package:smartbiztracker_new/screens/admin/new_users_screen.dart';
import 'package:smartbiztracker_new/screens/admin/waste_screen.dart';
import 'package:smartbiztracker_new/screens/orders/unified_orders_screen.dart';
import 'package:smartbiztracker_new/screens/admin/assign_tasks_screen.dart';
import 'package:smartbiztracker_new/screens/admin/distributors_screen.dart';
import 'package:smartbiztracker_new/screens/attendance/worker_attendance_reports_wrapper.dart';
import 'package:smartbiztracker_new/widgets/admin/competitors_widget.dart';
import 'package:smartbiztracker_new/screens/shared/product_movement_screen.dart';
import 'package:smartbiztracker_new/screens/admin/error_reports_returns_screen.dart';
import 'package:smartbiztracker_new/screens/admin/voucher_management_screen.dart';
import 'package:smartbiztracker_new/screens/shared/pending_orders_screen.dart';
import 'package:smartbiztracker_new/config/routes.dart' as app_routes;
import 'package:smartbiztracker_new/widgets/owner/worker_performance_card.dart';
import 'package:smartbiztracker_new/providers/worker_task_provider.dart';
import 'package:smartbiztracker_new/providers/worker_rewards_provider.dart';
import 'package:smartbiztracker_new/widgets/admin/location_management_widget.dart';
import 'package:smartbiztracker_new/models/worker_task_model.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/shared/warehouse_dispatch_tab.dart';

import 'package:smartbiztracker_new/utils/warehouse_permission_helper.dart';
import 'package:smartbiztracker_new/providers/warehouse_provider.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/shared/unified_warehouse_interface.dart';
import 'package:smartbiztracker_new/screens/shared/qr_scanner_screen.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPressTime; // لتتبع آخر ضغطة على زر العودة
  Key _futureBuilderKey = UniqueKey(); // مفتاح فريد للـ FutureBuilder
  bool _showTabs = false; // للتحكم في إظهار التابات

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

    // تهيئة TabController للتابات
    _tabController = TabController(length: 13, vsync: this); // إضافة تبويب تقارير الحضور

    // Add tab change listener for warehouse data loading
    _tabController.addListener(() {
      if (_tabController.index == 12) { // Warehouses tab (updated index)
        _loadWarehouseDataIfNeeded();
      }
    });

    // Initialize data loading only once to prevent infinite loops
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when the screen becomes visible again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDataIfNeeded();
    });
  }

  // Refresh data if it's been a while since last update
  Future<void> _refreshDataIfNeeded() async {
    if (!mounted) return;

    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

    // If no users loaded or it's been more than 5 minutes, refresh
    if (supabaseProvider.allUsers.isEmpty ||
        DateTime.now().difference(DateTime.now()).inMinutes > 5) {
      AppLogger.info('🔄 Admin Dashboard: Refreshing data due to staleness or empty state');
      await supabaseProvider.fetchAllUsers();
    }
  }

  // Initialize data loading only once to prevent infinite loops
  Future<void> _initializeData() async {
    if (!mounted) return;

    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

    try {
      AppLogger.info('🔄 Admin Dashboard: Initializing data loading...');

      // CRITICAL FIX: Always load all users for admin dashboard to show pending registrations
      AppLogger.info('📥 Admin Dashboard: Loading all users including pending registrations...');
      await supabaseProvider.fetchAllUsers();

      // Log the results for debugging
      final allUsersCount = supabaseProvider.allUsers.length;
      final pendingUsersCount = supabaseProvider.users.length; // This filters for pending users
      AppLogger.info('✅ Admin Dashboard: Loaded $allUsersCount total users, $pendingUsersCount pending approval');

      // Debug: Log pending users details
      final pendingUsers = supabaseProvider.users;
      if (pendingUsers.isNotEmpty) {
        AppLogger.info('📋 Pending users for approval:');
        for (final user in pendingUsers) {
          AppLogger.info('   👤 ${user.name} (${user.email}) - Status: ${user.status}');
        }
      } else {
        AppLogger.info('📋 No pending users found');
      }

      // Load workers if not already cached
      final workers = supabaseProvider.workers;
      if (workers.isEmpty && !supabaseProvider.isLoading) {
        await supabaseProvider.getUsersByRole(UserRole.worker.value);
      }

      // Load client orders for the recent orders section
      try {
        final clientOrdersProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
        if (clientOrdersProvider.orders.isEmpty && !clientOrdersProvider.isLoading) {
          await clientOrdersProvider.loadAllOrders();
        }
      } catch (e) {
        AppLogger.error('❌ خطأ في تحميل طلبات العملاء: $e');
      }

      AppLogger.info('✅ Admin Dashboard: Data initialization completed');
    } catch (e) {
      AppLogger.error('❌ Admin Dashboard: Error during data initialization: $e');
    }
  }

  // دالة لتحميل بيانات المخازن
  Future<void> _loadWarehouseDataIfNeeded() async {
    try {
      final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);

      // تحميل المخازن إذا لم تكن محملة مسبقاً
      if (warehouseProvider.warehouses.isEmpty && !warehouseProvider.isLoadingWarehouses) {
        AppLogger.info('🏢 تحميل بيانات المخازن للأدمن...');
        await warehouseProvider.loadWarehouses();
        AppLogger.info('✅ تم تحميل بيانات المخازن بنجاح');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل بيانات المخازن: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
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
            preferredSize: Size.fromHeight(_showTabs ? 120 : 60),
            child: AppBar(
              title: const Text('لوحة تحكم المدير'),
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: _openDrawer,
              ),
              actions: [
                // QR Scanner Button
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.qrScanner);
                    },
                    tooltip: 'مسح QR للمنتجات',
                    splashRadius: 20,
                  ),
                ),

                IconButton(
                  icon: Icon(_showTabs ? Icons.dashboard : Icons.tab),
                  tooltip: _showTabs ? 'عرض الكروت' : 'عرض التابات',
                  onPressed: () {
                    setState(() {
                      _showTabs = !_showTabs;
                    });
                  },
                ),
              ],
              bottom: _showTabs ? TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                tabs: const [
                  Tab(text: 'الرئيسية', icon: Icon(Icons.dashboard)),
                  Tab(text: 'المستخدمين', icon: Icon(Icons.people)),
                  Tab(text: 'المنتجات', icon: Icon(Icons.inventory)),
                  Tab(text: 'الطلبات المعلقة', icon: Icon(Icons.pending_actions)),
                  Tab(text: 'الطلبات', icon: Icon(Icons.shopping_cart)),
                  Tab(text: 'التقارير والمرتجعات', icon: Icon(Icons.report_problem)),
                  Tab(text: 'التحليلات', icon: Icon(Icons.analytics)),
                  Tab(text: 'المدفوعات الإلكترونية', icon: Icon(Icons.payment)),
                  Tab(text: 'إدارة القسائم', icon: Icon(Icons.local_offer)),
                  Tab(text: 'تقارير الحضور', icon: Icon(Icons.access_time_rounded)),
                  Tab(text: 'إدارة المواقع', icon: Icon(Icons.location_on_rounded)),
                  Tab(text: 'الموزعين', icon: Icon(Icons.business)),
                  Tab(text: 'صرف من المخزون', icon: Icon(Icons.local_shipping_rounded)),
                  Tab(text: 'المخازن', icon: Icon(Icons.warehouse_rounded)),
                ],
              ) : null,
            ),
          ),
          drawer: MainDrawer(
            onMenuPressed: _openDrawer,
            currentRoute: AppRoutes.adminDashboard,
          ),
          body: _showTabs ? _buildTabView(theme, supabaseProvider, userModel) : _buildDashboardView(theme, supabaseProvider, userModel),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'chat',
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

  // عرض الكروت العادي
  Widget _buildDashboardView(ThemeData theme, SupabaseProvider supabaseProvider, UserModel userModel) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: RefreshIndicator(
        onRefresh: () async {
          // Only refresh if not already loading to prevent infinite refresh
          if (!supabaseProvider.isLoading) {
            await supabaseProvider.fetchAllUsers();
            if (mounted) {
              setState(() {
                _futureBuilderKey = UniqueKey();
              });
            }
          }
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
                        Row(
                          children: [
                            IconButton(
                              onPressed: () async {
                                // Refresh pending users data
                                final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
                                AppLogger.info('🔄 Refreshing pending users data...');
                                await supabaseProvider.fetchAllUsers();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم تحديث البيانات'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.refresh),
                              tooltip: 'تحديث البيانات',
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

            // Worker Analytics Section
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
                          'تحليلات العمال',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context)
                                .pushNamed(AppRoutes.analytics);
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('عرض التفاصيل'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildWorkerAnalytics(),
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

            // Recent Client Orders Section
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
                          'طلبات العملاء الحديثة',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context)
                                .pushNamed(AppRoutes.pendingOrders);
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('عرض الكل'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRecentClientOrders(),
                  ],
                ),
              ),
            ),

            // Bottom Padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }

  // عرض التابات
  Widget _buildTabView(ThemeData theme, SupabaseProvider supabaseProvider, UserModel userModel) {
    return TabBarView(
      controller: _tabController,
      children: [
        // تاب الرئيسية
        _buildDashboardView(theme, supabaseProvider, userModel),

        // تاب المستخدمين
        const UserManagementScreen(),

        // تاب المنتجات
        const AdminProductsScreen(),

        // تاب الطلبات المعلقة
        const PendingOrdersScreen(),

        // تاب الطلبات
        const UnifiedOrdersScreen(),

        // تاب التقارير والمرتجعات
        const ErrorReportsReturnsScreen(),

        // تاب التحليلات
        const AnalyticsScreen(),

        // تاب المدفوعات الإلكترونية
        const ElectronicPaymentManagementScreen(),

        // تاب إدارة القسائم
        const VoucherManagementScreen(),

        // تاب تقارير الحضور
        const WorkerAttendanceReportsWrapper(userRole: 'admin'),

        // تاب إدارة المواقع
        const LocationManagementWidget(),

        // تاب الموزعين
        const DistributorsScreen(),

        // تاب صرف من المخزون
        const WarehouseDispatchTab(userRole: 'admin'),

        // تاب المخازن - الواجهة الموحدة
        const UnifiedWarehouseInterface(userRole: 'admin'),
      ],
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
              color: Colors.white.withValues(alpha: 0.2),
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
      key: _futureBuilderKey,
      future: AnalyticsService().getAdminDashboardAnalytics(),
      builder: (context, snapshot) {
        // Default values for when data is loading or there's an error
        String userCount = '0';
        String orderCount = '0';
        String productCount = '0';
        const String errorCount = '0';

        // If we have data from the API, use it
        if (snapshot.hasData) {
          userCount = snapshot.data!.users.active.toString();
          orderCount = snapshot.data!.sales.totalInvoices.toString();
          productCount = snapshot.data!.products.visible.toString(); // Only visible products
          // We don't have error count in analytics model, so it stays 0
        } else if (snapshot.hasError) {
          // Error handling
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ملخص سريع',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (snapshot.hasError)
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          onPressed: () {
                            // Force rebuild by creating a new key for the FutureBuilder
                            if (mounted) {
                              setState(() {
                                _futureBuilderKey = UniqueKey();
                              });
                            }
                          },
                          tooltip: 'إعادة تحميل البيانات',
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                      ? Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'فشل في تحميل البيانات',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'تحقق من الاتصال بالإنترنت أو حاول مرة أخرى',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Force rebuild by creating a new key for the FutureBuilder
                                if (mounted) {
                                  setState(() {
                                    _futureBuilderKey = UniqueKey();
                                  });
                                }
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('إعادة المحاولة'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        )
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
              color: color.withValues(alpha: 0.1),
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
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovals(SupabaseProvider supabaseProvider) {
    final pendingUsers = supabaseProvider.users;
    final allUsersCount = supabaseProvider.allUsers.length;
    final theme = Theme.of(context);

    // Debug logging
    AppLogger.info('🔍 Admin Dashboard: Building pending approvals widget');
    AppLogger.info('📊 Total users: $allUsersCount, Pending users: ${pendingUsers.length}');
    AppLogger.info('🔄 Loading state: ${supabaseProvider.isLoading}');

    if (supabaseProvider.isLoading && pendingUsers.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل طلبات التسجيل...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (pendingUsers.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.8),
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
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
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
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
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
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد منتجات متاحة حالياً',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                      width: 64, // زيادة العرض من 48 إلى 64
                      height: 64, // زيادة الارتفاع من 48 إلى 64
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                            ? Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      color: theme.colorScheme.primary,
                                      strokeWidth: 2,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    child: Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                        size: 24,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                child: Center(
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                    size: 24,
                                  ),
                                ),
                              ),
                      ),
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
                    tileColor: index % 2 == 0 ? theme.colorScheme.surface.withValues(alpha: 0.5) : theme.colorScheme.surface.withValues(alpha: 0.3),
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
                  // استخدام التنقل المباشر بدلاً من الروت المسمى
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminProductsScreen(),
                    ),
                  );
                },
              ),
              DashboardCard(
                title: 'المستخدمين',
                description: 'إدارة حسابات المستخدمين',
                icon: Icons.people,
                color: Colors.purple,
                onTap: () async {
                  try {
                    // إضافة تسجيل للتنقل
                    AppLogger.info('Navigating to User Management Screen');

                    // استخدام التنقل المباشر مع معالجة الأخطاء
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserManagementScreen(),
                        settings: const RouteSettings(name: '/admin/users'),
                      ),
                    );

                    AppLogger.info('Returned from User Management Screen with result: $result');
                  } catch (e) {
                    AppLogger.error('Error navigating to User Management Screen: $e');

                    // محاولة التنقل باستخدام الروت المسمى كبديل
                    try {
                      AppLogger.info('Trying named route as fallback');
                      await Navigator.of(context).pushNamed(app_routes.AppRoutes.userManagement);
                    } catch (e2) {
                      AppLogger.error('Named route also failed: $e2');

                      // إظهار رسالة خطأ للمستخدم
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('حدث خطأ أثناء فتح صفحة إدارة المستخدمين: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                            action: SnackBarAction(
                              label: 'إعادة المحاولة',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const UserManagementScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              DashboardCard(
                title: 'إسناد مهام للعمال',
                description: 'تكليف العمال بمهام إنتاج المنتجات والطلبيات',
                icon: Icons.engineering,
                color: Colors.deepOrange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AssignTasksScreen(),
                    ),
                  );
                },
              ),
              DashboardCard(
                title: 'إدارة مكافآت العمال',
                description: 'منح المكافآت ومتابعة أرصدة العمال',
                icon: Icons.card_giftcard,
                color: Colors.amber,
                onTap: () {
                  Navigator.pushNamed(context, app_routes.AppRoutes.adminRewardsManagement);
                },
                badge: 'جديد',
                badgeColor: Colors.green,
              ),
              DashboardCard(
                title: 'مراجعة تقارير التقدم',
                description: 'مراجعة واعتماد تقارير العمال',
                icon: Icons.assignment_turned_in,
                color: Colors.green,
                onTap: () {
                  Navigator.pushNamed(context, app_routes.AppRoutes.adminTaskReview);
                },
                badge: 'مهم',
                badgeColor: Colors.green,
              ),
              DashboardCard(
                title: 'طلبات التسجيل',
                description: 'الموافقة على طلبات المستخدمين الجدد',
                icon: Icons.approval,
                color: Colors.green,
                onTap: () {
                  // استخدام التنقل المباشر
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NewUsersScreen(),
                    ),
                  );
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
                  // استخدام صفحة الطلبات الموحدة الجديدة
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UnifiedOrdersScreen(),
                    ),
                  );
                },
              ),
              DashboardCard(
                title: 'الطلبات المعلقة',
                description: 'موافقة على الطلبات الجديدة وإضافة روابط التتبع',
                icon: Icons.pending_actions,
                color: Colors.red,
                onTap: () {
                  Navigator.pushNamed(context, '/admin/pending-orders');
                },
                badge: 'جديد',
                badgeColor: Colors.red,
              ),
              DashboardCard(
                title: 'تحليل المنافسين',
                description: 'مراقبة أسعار ومنتجات المنافسين',
                icon: Icons.analytics,
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CompetitorsWidget(),
                    ),
                  );
                },
                badge: 'جديد',
                badgeColor: Colors.orange,
              ),
              DashboardCard(
                title: 'إدارة الهالك',
                description: 'متابعة العناصر التالفة',
                icon: Icons.inventory_2,
                color: Colors.red,
                onTap: () {
                  // استخدام التنقل المباشر
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WasteScreen(),
                    ),
                  );
                },
              ),
              DashboardCard(
                title: 'حركة صنف شاملة',
                description: 'تتبع مبيعات وحركة المنتجات',
                icon: Icons.track_changes,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductMovementScreen(),
                    ),
                  );
                },
                badge: 'جديد',
                badgeColor: Colors.purple,
              ),
              DashboardCard(
                title: 'إدارة الموزعين',
                description: 'إدارة مراكز التوزيع والموزعين',
                icon: Icons.business,
                color: Colors.indigo,
                onTap: () {
                  Navigator.pushNamed(context, app_routes.AppRoutes.distributors);
                },
                badge: 'جديد',
                badgeColor: Colors.indigo,
              ),
              DashboardCard(
                title: 'إدارة المحافظ',
                description: 'إدارة محافظ المستخدمين والمعاملات المالية',
                icon: Icons.account_balance_wallet,
                color: Colors.teal,
                onTap: () {
                  Navigator.pushNamed(context, app_routes.AppRoutes.walletManagement);
                },
                badge: 'نظام جديد',
                badgeColor: Colors.teal,
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
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
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
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'فشل في تحميل الطلبات',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'تحقق من الاتصال بالإنترنت أو حاول مرة أخرى',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                // This will trigger a rebuild and refetch the data
                              });
                            }
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد طلبات حديثة',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ستظهر الطلبات الجديدة هنا عند إنشائها',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const UnifiedOrdersScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_shopping_cart, size: 16),
                          label: const Text('عرض جميع الطلبات'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
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
                    order: order,
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
    OrderModel? order,
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.safeOpacity(0.6),
            ),
          ),
          // Show pricing information if order has total amount
          if (order != null && order.totalAmount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'المبلغ: ${AccountantThemeConfig.formatCurrency(order.totalAmount)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.arrow_forward_ios, size: 16),
        onPressed: () {
          // Navigate to activity details
        },
      ),
    );
  }

  /// Build recent client orders section with pricing approval awareness
  Widget _buildRecentClientOrders() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
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
                  Icons.receipt_long,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'طلبات العملاء الحديثة',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Consumer<ClientOrdersProvider>(
            builder: (context, clientOrdersProvider, child) {
              if (clientOrdersProvider.isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (clientOrdersProvider.error != null) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'فشل في تحميل طلبات العملاء',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'تحقق من الاتصال بالإنترنت أو حاول مرة أخرى',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            clientOrdersProvider.loadAllOrders();
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final orders = clientOrdersProvider.orders;

              if (orders.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_outlined,
                          size: 48,
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد طلبات عملاء حديثة',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ستظهر طلبات العملاء الجديدة هنا عند إنشائها',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Sort orders by date descending (newest first)
              final sortedOrders = List<ClientOrder>.from(orders);
              sortedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              // Take the 5 most recent orders
              final recentOrders = sortedOrders.take(5).toList();

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

                  return _buildClientOrderActivityItem(
                    order: order,
                    time: timeAgo,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build client order activity item with pricing approval awareness
  Widget _buildClientOrderActivityItem({
    required ClientOrder order,
    required String time,
  }) {
    final theme = Theme.of(context);
    final bool shouldShowPrices = _shouldShowPricesForClientOrder(order);

    // Determine status color based on order status and pricing approval
    Color statusColor = _getClientOrderStatusColor(order);
    IconData statusIcon = _getClientOrderStatusIcon(order);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          statusIcon,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Text(
        'طلب عميل #${order.id.substring(0, 8)} - ${order.clientName}',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          // Show pricing information with approval awareness
          if (shouldShowPrices) ...[
            Text(
              'المبلغ: ${AccountantThemeConfig.formatCurrency(order.total)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (order.requiresPricingApproval) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'في انتظار اعتماد التسعير',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
          // Show pricing status if order requires pricing approval
          if (order.requiresPricingApproval) ...[
            const SizedBox(height: 2),
            Text(
              order.pricingStatusText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _getPricingStatusColor(order.pricingStatus),
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.arrow_forward_ios, size: 16),
        onPressed: () {
          // Navigate to order details
          Navigator.pushNamed(
            context,
            '/admin/pending-orders',
            arguments: order.id,
          );
        },
      ),
    );
  }

  /// Determines if prices should be shown for a client order
  bool _shouldShowPricesForClientOrder(ClientOrder order) {
    // Show prices if:
    // 1. Order doesn't require pricing approval, OR
    // 2. Pricing has been approved
    return !order.requiresPricingApproval || order.isPricingApproved;
  }

  /// Get status color for client order based on status and pricing approval
  Color _getClientOrderStatusColor(ClientOrder order) {
    if (order.requiresPricingApproval && !order.isPricingApproved) {
      return Colors.orange; // Pending pricing approval
    }

    switch (order.status.toString().split('.').last) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'shipped':
        return Colors.green;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get status icon for client order
  IconData _getClientOrderStatusIcon(ClientOrder order) {
    if (order.requiresPricingApproval && !order.isPricingApproved) {
      return Icons.schedule; // Pending pricing approval
    }

    switch (order.status.toString().split('.').last) {
      case 'pending':
        return Icons.pending_actions;
      case 'confirmed':
        return Icons.check_circle;
      case 'processing':
        return Icons.settings;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.receipt;
    }
  }

  /// Get color for pricing status
  Color _getPricingStatusColor(String? pricingStatus) {
    switch (pricingStatus) {
      case 'pricing_approved':
        return Colors.green;
      case 'pricing_rejected':
        return Colors.red;
      case 'pending_pricing':
      default:
        return Colors.orange;
    }
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

  Widget _buildWorkerAnalytics() {
    final theme = Theme.of(context);

    return Consumer<SupabaseProvider>(
      builder: (context, supabaseProvider, child) {
        // Use cached workers from provider instead of FutureBuilder to prevent infinite loops
        final workers = supabaseProvider.workers;

        // Load workers if not already loaded (only once) - FIXED: Use initState instead of addPostFrameCallback
        // This prevents repeated calls during widget rebuilds

        // Show loading state
        if (supabaseProvider.isLoading && workers.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Show error state
        if (supabaseProvider.error != null && workers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'فشل في تحميل بيانات العمال',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تحقق من الاتصال بالإنترنت أو حاول مرة أخرى',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      supabaseProvider.forceRefreshUsersByRole(UserRole.worker.value);
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('إعادة المحاولة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final approvedWorkers = workers.where((worker) =>
          worker.status == 'approved' && worker.isApproved).toList();

        if (approvedWorkers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد عمال معتمدين',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ستظهر تحليلات العمال هنا عند اعتماد العمال',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(app_routes.AppRoutes.userManagement);
                    },
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('إدارة المستخدمين'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getWorkerTasksData(approvedWorkers),
          builder: (context, tasksSnapshot) {
            if (tasksSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final workersWithTasks = tasksSnapshot.data ?? [];

            if (workersWithTasks.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 48,
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد بيانات تحليلات للعمال',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ستظهر تحليلات الأداء هنا عند إسناد مهام للعمال',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushNamed(app_routes.AppRoutes.assignTasks);
                        },
                        icon: const Icon(Icons.assignment, size: 16),
                        label: const Text('إسناد مهام'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Take the top 3 performing workers
            final topWorkers = workersWithTasks.take(3).toList();

            return SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: topWorkers.length,
                itemBuilder: (context, index) {
                  final workerData = topWorkers[index];
                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: 16),
                    child: WorkerPerformanceCard(
                      name: workerData['name']?.toString() ?? 'عامل غير معروف',
                      productivity: (workerData['productivity'] as num?)?.toInt() ?? 0,
                      completedOrders: (workerData['completedTasks'] as num?)?.toInt() ?? 0,
                      onTap: () {
                        // Navigate to worker details
                        Navigator.of(context).pushNamed(app_routes.AppRoutes.analytics);
                      },
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getWorkerTasksData(List<UserModel> workers) async {
    final workerTaskProvider = Provider.of<WorkerTaskProvider>(context, listen: false);
    final workerRewardsProvider = Provider.of<WorkerRewardsProvider>(context, listen: false);

    final List<Map<String, dynamic>> workersData = [];

    for (final worker in workers) {
      try {
        // Get tasks data from WorkerTaskProvider
        await workerTaskProvider.fetchAssignedTasks();
        final assignedTasks = workerTaskProvider.assignedTasks.where((task) => task.assignedTo == worker.id).toList();
        final completedTasks = assignedTasks.where((task) => task.status == TaskStatus.completed).length;
        final totalTasks = assignedTasks.length;

        // Only include workers who have tasks assigned
        if (totalTasks > 0) {
          // Calculate productivity based on completed vs total tasks
          final int productivity = ((completedTasks / totalTasks) * 100).round();

          // Get rewards data
          final rewards = workerRewardsProvider.rewards
              .where((reward) => reward.workerId == worker.id)
              .toList();
          final totalRewards = rewards.fold(0.0, (sum, reward) => sum + reward.amount);

          workersData.add({
            'id': worker.id,
            'name': worker.name,
            'completedTasks': completedTasks,
            'totalTasks': totalTasks,
            'productivity': productivity,
            'totalRewards': totalRewards,
            'email': worker.email,
          });
        }
      } catch (e) {
        // Skip workers with errors - don't add them to the list
        AppLogger.warning('Error fetching data for worker ${worker.name}: $e');
      }
    }

    // Sort by productivity descending, then by completed tasks
    workersData.sort((a, b) {
      final productivityComparison = (b['productivity'] as int).compareTo(a['productivity'] as int);
      if (productivityComparison != 0) return productivityComparison;
      return (b['completedTasks'] as int).compareTo(a['completedTasks'] as int);
    });

    return workersData;
  }


}
