import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/widgets/owner/business_stats_card.dart';
import 'package:smartbiztracker_new/widgets/owner/worker_performance_card.dart';
import 'package:smartbiztracker_new/widgets/owner/product_status_card.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/services/samastock_api.dart';
import 'package:smartbiztracker_new/models/damaged_item_model.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';
import 'package:smartbiztracker_new/widgets/owner/sama_admin_dashboard_widget.dart';
import 'package:smartbiztracker_new/services/sama_analytics_service.dart';
import 'package:smartbiztracker_new/widgets/admin/order_management_widget.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPressTime; // لتتبع آخر ضغطة على زر العودة

  // طريقة لفتح السلايدبار
  void _openDrawer() {
    if (_scaffoldKey.currentState != null && !_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openDrawer();
    }
  }
  late TabController _tabController;
  int _selectedPeriod = 0; // 0: يومي، 1: أسبوعي، 2: شهري
  final List<String> _periods = ['يومي', 'أسبوعي', 'شهري'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // إضافة متغيرات لـ API الجديد
  bool _isLoadingSamaData = false;
  Map<String, dynamic>? _samaDashboardData;
  String? _samaDataError;
  
  // Create instances of services
  final StockWarehouseApiService _stockWarehouseApi = StockWarehouseApiService();
  final SamaStockApiService _samaStockApi = SamaStockApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize API services and fetch data
      // No need for initialize method on these APIs since it's not in their interface
      
      // Attempt to load dashboard data directly - removing login since it's not in our mock API
      _loadSamaDashboardData();
    });
  }
  
  // دالة لتحميل بيانات لوحة تحكم SAMA Admin
  Future<void> _loadSamaDashboardData() async {
    if (mounted) {
      setState(() {
        _isLoadingSamaData = true;
        _samaDataError = null;
      });
    }
    
    try {
      // إنشاء خدمة التحليلات
      final analyticsService = SamaAnalyticsService();
      
      // Get dashboard data using the analytics service
      final dashboardData = await analyticsService.getAllAnalytics();
      
      if (mounted) {
        setState(() {
          _samaDashboardData = dashboardData;
          _isLoadingSamaData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _samaDataError = e.toString();
          _isLoadingSamaData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            title: 'لوحة تحكم المالك',
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: _openDrawer,
            ),
            hideStatusBarHeader: true,
          ),
        ),
        drawer: MainDrawer(
          onMenuPressed: _openDrawer,
          currentRoute: AppRoutes.ownerDashboard,
        ),
        body: Column(
          children: [
            // Status tab bar - Eliminar el contenedor blanco y usar TabBar directamente
            TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.safeOpacity(0.7),
              tabs: [
                const Tab(text: 'نظرة عامة'),
                const Tab(text: 'المنتجات'),
                const Tab(text: 'الطلبات'),
                // Reports tab with "new" badge
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('التقارير'),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'جديد',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Agregar padding para dar mejor espaciado
              padding: const EdgeInsets.symmetric(vertical: 4),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Overview Tab
                  _buildOverviewTab(),

                  // Products Tab
                  _buildProductsTab(),

                  // Orders Tab
                  _buildOrdersTab(),

                  // Reports Tab
                  _buildReportsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
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
              // Business summary
              _buildBusinessSummary(theme),
              const SizedBox(height: 24),

              // Period selector for stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إحصائيات الأعمال',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.safeOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: _periods.asMap().entries.map((entry) {
                        final index = entry.key;
                        final title = entry.value;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedPeriod = index;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedPeriod == index
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              title,
                              style: TextStyle(
                                color: _selectedPeriod == index
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sales and Revenue Stats
              _buildBusinessStats(theme),
              const SizedBox(height: 24),

              // Top Workers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'متابعة الطلبات',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.ownerWorkers);
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('عرض الكل'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              _buildWorkerPerformance(theme),
              const SizedBox(height: 24),

              // Inventory Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'حالة المخزون',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.ownerProducts);
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('عرض الكل'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              _buildInventoryStatus(theme),
              const SizedBox(height: 24),

              // SAMA Store Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.samaStore);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.store,
                            color: theme.colorScheme.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'متجر SAMA',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'تصفح واستكشف منتجات متجر SAMA',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Setup for bottom spacing
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessSummary(ThemeData theme) {
    final stockWarehouseApi = Provider.of<StockWarehouseApiService>(context, listen: false);
    final samaStockApi = Provider.of<SamaStockApiService>(context, listen: false);
    
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
            const Text(
              'ملخص الأعمال',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<dynamic>>(
              future: Future.wait([
                stockWarehouseApi.getOrders(),
                samaStockApi.getProducts(),
                stockWarehouseApi.getDamagedItems(),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  );
                }
                
                final orders = snapshot.data?[0] as List<OrderModel>? ?? [];
                final products = snapshot.data?[1] as List<ProductModel>? ?? [];
                final damagedItems = snapshot.data?[2] as List<DamagedItemModel>? ?? [];
                
                // Filter today's orders
                final todayOrders = orders.where((order) {
                  final today = DateTime.now();
                  final orderDate = order.createdAt;
                  return orderDate.year == today.year && 
                         orderDate.month == today.month && 
                         orderDate.day == today.day;
                }).toList();

                // Filter products with stock > 0
                final inStockProducts = products.where((product) => product.quantity > 0).toList();
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryMetric(
                      icon: Icons.shopping_cart,
                      title: 'الطلبات اليوم',
                      value: todayOrders.length.toString(),
                      color: Colors.white,
                    ),
                    _buildSummaryMetric(
                      icon: Icons.inventory,
                      title: 'المنتجات',
                      value: inStockProducts.length.toString(),
                      color: Colors.white,
                    ),
                    _buildSummaryMetric(
                      icon: Icons.warning_amber,
                      title: 'العناصر التالفة',
                      value: damagedItems.length.toString(),
                      color: Colors.white,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
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

  Widget _buildBusinessStats(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: BusinessStatsCard(
            title: 'المبيعات',
            value: '14,580 جنيه',
            change: 12.5,
            isPositiveChange: true,
            chartData: const [3, 7, 5, 8, 14, 10, 15],
            period: _periods[_selectedPeriod],
            chartColor: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: BusinessStatsCard(
            title: 'الطلبات',
            value: '157',
            change: 8.2,
            isPositiveChange: true,
            chartData: const [8, 12, 10, 14, 13, 16, 18],
            period: _periods[_selectedPeriod],
            chartColor: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerPerformance(ThemeData theme) {
    final stockWarehouseApi = Provider.of<StockWarehouseApiService>(context, listen: false);
    
    return FutureBuilder<List<OrderModel>>(
      future: stockWarehouseApi.getOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('خطأ في جلب البيانات: ${snapshot.error}'),
          );
        }
        
        final orders = snapshot.data ?? [];
        
        if (orders.isEmpty) {
          return const Center(
            child: Text('لا توجد بيانات متاحة.'),
          );
        }
        
        // Process orders to get worker performance data
        // Group by worker/customer name and calculate metrics
        final Map<String, Map<String, dynamic>> workerStats = {};
        
        for (final order in orders) {
          final workerName = order.customerName; // Assuming customer name = worker name
          
          if (!workerStats.containsKey(workerName)) {
            workerStats[workerName] = {
              'completedOrders': 0,
              'totalValue': 0.0,
            };
          }
          
          if (order.status.toLowerCase() == 'completed' || 
              order.status.toLowerCase() == 'delivered' ||
              order.status.toLowerCase() == 'تم التسليم') {
            workerStats[workerName]!['completedOrders'] = 
                workerStats[workerName]!['completedOrders'] + 1;
          }
          
          workerStats[workerName]!['totalValue'] = 
              workerStats[workerName]!['totalValue'] + order.totalAmount;
        }
        
        // Sort workers by completed orders
        final sortedWorkers = workerStats.entries.toList()
          ..sort((a, b) => (b.value['completedOrders'] as int)
              .compareTo(a.value['completedOrders'] as int));
        
        // Take top 3 workers
        final topWorkers = sortedWorkers.take(3).toList();
        
        if (topWorkers.isEmpty) {
          return const Center(
            child: Text('لا توجد بيانات أداء متاحة.'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topWorkers.length,
          itemBuilder: (context, index) {
            final entry = topWorkers[index];
            final workerName = entry.key;
            final stats = entry.value;
            final completedOrders = stats['completedOrders'] as int;
            
            // Calculate productivity as a percentage (0-100)
            // This is a simplified metric - you may want to use a more complex calculation
            final productivity = (completedOrders / (orders.length > 0 ? orders.length : 1) * 100).clamp(0, 100).toInt();
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WorkerPerformanceCard(
                name: workerName,
                productivity: productivity,
                completedOrders: completedOrders,
                onTap: () {
                  // Navigate to worker details
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInventoryStatus(ThemeData theme) {
    final samaStockApi = Provider.of<SamaStockApiService>(context, listen: false);
    
    return FutureBuilder<List<ProductModel>>(
      future: samaStockApi.getProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('خطأ في جلب البيانات: ${snapshot.error}'),
          );
        }
        
        final products = snapshot.data ?? [];
        
        if (products.isEmpty) {
          return const Center(
            child: Text('لا توجد منتجات متاحة.'),
          );
        }
        
        // Filter products with quantity between 1 and 10
        final lowStockProducts = products.where((p) => p.quantity >= 1 && p.quantity <= 10).toList();
        
        // Sort products by stock quantity (ascending)
        lowStockProducts.sort((a, b) => a.quantity.compareTo(b.quantity));
        
        // Take the first 3 products or fewer if less are available
        final displayProducts = lowStockProducts.take(3).toList();
        
        if (displayProducts.isEmpty) {
          return const Center(
            child: Text('لا توجد منتجات في نطاق المخزون المنخفض (1-10).'),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayProducts.length,
          itemBuilder: (context, index) {
            final product = displayProducts[index];
            final isLowStock = product.quantity < 5; // Define threshold for very low stock
            final needsReorder = product.quantity < 3; // Almost out of stock
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ProductStatusCard(
                name: product.name,
                quantity: product.quantity,
                isLowStock: isLowStock,
                needsReorder: needsReorder,
                onTap: () {
                  // Navigate to product details
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductsTab() {
    final theme = Theme.of(context);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search and filter section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GlassSearchBar(
              controller: _searchController,
              hintText: 'البحث عن منتج...',
              accentColor: const Color(0xFF6C63FF),
              margin: EdgeInsets.zero,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 24),

          // Products grid view
          FutureBuilder<List<ProductModel>>(
            future: productProvider.loadSamaAdminProductsWithToJSON(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              
              if (snapshot.hasError) {
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
                      Text('خطأ في جلب البيانات: ${snapshot.error}'),
                    ],
                  ),
                );
              }
              
              // Use products from the provider
              final products = productProvider.samaAdminProducts;
              
              if (products.isEmpty) {
                return const Center(
                  child: Text('لا توجد منتجات متاحة.'),
                );
              }

              // Filter products based on search query
              final filteredProducts = _searchQuery.isEmpty
                  ? products
                  : products.where((product) =>
                      product.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              
              // Display all filtered products
              final displayProducts = filteredProducts;
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: displayProducts.length,
                itemBuilder: (context, index) {
                  final product = displayProducts[index];
                  return _buildProductCard(
                    name: product.name,
                    price: product.price,
                    quantity: product.quantity,
                    imageUrl: product.bestImageUrl,
                    onTap: () {
                      // Navigate to product details
                    },
                  );
                },
              );
            },
          ),

          // Add bottom spacing
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProductCard({
    required String name,
    required double price,
    required int quantity,
    String? imageUrl,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image placeholder
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Container(
                height: 120,
                width: double.infinity,
                color: theme.colorScheme.primary.withOpacity(0.1),
                child: imageUrl != null && imageUrl.isNotEmpty && !imageUrl.contains('placeholder.com')
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              size: 30,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'لا توجد صورة',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Optimize memory usage
                      memCacheWidth: 300,
                      maxWidthDiskCache: 600,
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'لا توجد صورة',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
              ),
            ),

            // Product details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${price.toStringAsFixed(2)} جنيه',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 14,
                        color: quantity > 10
                            ? Colors.green
                            : quantity > 0
                                ? Colors.orange
                                : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'المخزون: $quantity',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTab() {
    return const OrderManagementWidget(
      userRole: 'owner',
      showHeader: false,
      isEmbedded: true,
      showFilterOptions: true,
      showSearchBar: true,
      showStatusFilters: true,
      showStatusFilter: true,
      showDateFilter: true,
    );
  }

  Widget _buildReportsTab() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SAMA Admin Dashboard Widget taking all remaining space
          Expanded(
            child: SamaAdminDashboardWidget(
              dashboardData: _samaDashboardData,
              isLoading: _isLoadingSamaData,
              errorMessage: _samaDataError,
              onRefresh: _loadSamaDashboardData,
            ),
          ),
        ],
      ),
    );
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
}
