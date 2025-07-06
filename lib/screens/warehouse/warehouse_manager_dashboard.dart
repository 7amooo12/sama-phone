import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_products_provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_dispatch_provider.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/widgets/common/advanced_search_bar.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_dashboard_card.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_stats_overview.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_product_card.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_card.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_skeleton_loader.dart';
import 'package:smartbiztracker_new/widgets/warehouse/add_warehouse_dialog.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_details_screen.dart';
import 'package:smartbiztracker_new/screens/warehouse/warehouse_reports_screen.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/models/warehouse_dispatch_model.dart';
import 'package:smartbiztracker_new/utils/warehouse_permission_helper.dart';
import 'package:smartbiztracker_new/screens/shared/dispatch_details_screen.dart';
import 'package:smartbiztracker_new/constants/warehouse_dispatch_constants.dart';
import 'package:smartbiztracker_new/providers/warehouse_search_provider.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_search_widget.dart';
import 'package:smartbiztracker_new/screens/warehouse/interactive_dispatch_processing_screen.dart';
import 'package:smartbiztracker_new/screens/shared/warehouse_release_orders_screen.dart';
import 'package:smartbiztracker_new/widgets/worker_attendance/worker_attendance_dashboard_tab.dart';
import 'package:smartbiztracker_new/providers/worker_attendance_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// شاشة لوحة تحكم مدير المخزن
class WarehouseManagerDashboard extends StatefulWidget {
  const WarehouseManagerDashboard({super.key});

  @override
  State<WarehouseManagerDashboard> createState() => _WarehouseManagerDashboardState();
}

class _WarehouseManagerDashboardState extends State<WarehouseManagerDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;
  late WorkerAttendanceProvider _workerAttendanceProvider;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Removed worker attendance tab
    _searchController = TextEditingController();
    _workerAttendanceProvider = WorkerAttendanceProvider();

    // إضافة مستمع لتغيير التبويبات لتحديث البيانات عند الحاجة
    _tabController.addListener(_onTabChanged);

    // تهيئة لوحة التحكم بعد بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
      // تهيئة مزود المنتجات
      final productsProvider = Provider.of<WarehouseProductsProvider>(context, listen: false);
      productsProvider.loadProducts();

      // تهيئة مزود طلبات الصرف
      final dispatchProvider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
      dispatchProvider.loadDispatchRequests();
    });
  }

  /// معالج تغيير التبويبات
  void _onTabChanged() {
    if (!mounted) return;

    final currentIndex = _tabController.index;
    AppLogger.info('🔄 تغيير التبويب إلى: $currentIndex');

    // تحديث بيانات المخازن عند الوصول لتبويب المخازن (index 2)
    if (currentIndex == 2) {
      _refreshWarehouseData();
    }

    // تهيئة مزود حضور العمال عند الوصول لتبويب حضور العمال (index 4)
    if (currentIndex == 4) {
      _initializeWorkerAttendanceProvider();
    }
  }

  /// تهيئة مزود حضور العمال
  Future<void> _initializeWorkerAttendanceProvider() async {
    if (!mounted) return;

    try {
      AppLogger.info('🚀 تهيئة مزود حضور العمال...');

      // التأكد من أن المزود لم يتم تهيئته مسبقاً
      if (!_workerAttendanceProvider.isInitialized && !_workerAttendanceProvider.isLoading) {
        await _workerAttendanceProvider.initialize();
        AppLogger.info('✅ تم تهيئة مزود حضور العمال بنجاح');
      } else {
        AppLogger.info('ℹ️ مزود حضور العمال مُهيأ مسبقاً أو قيد التهيئة');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة مزود حضور العمال: $e');
    }
  }

  /// تحديث بيانات المخازن
  Future<void> _refreshWarehouseData() async {
    try {
      final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);
      await warehouseProvider.refreshData();
      AppLogger.info('✅ تم تحديث بيانات المخازن');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث بيانات المخازن: $e');
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _workerAttendanceProvider.dispose();
    super.dispose();
  }

  /// تهيئة لوحة التحكم
  Future<void> _initializeDashboard() async {
    try {
      AppLogger.info('🏢 تهيئة لوحة تحكم مدير المخزن...');

      final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);

      // تحميل البيانات الأساسية
      await warehouseProvider.loadWarehouses();

      // تحديث إحصائيات المخازن لضمان عرض البيانات الصحيحة
      await warehouseProvider.refreshData();

      setState(() {
        _isInitialized = true;
      });

      AppLogger.info('✅ تم تهيئة لوحة تحكم مدير المخزن بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة لوحة التحكم: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final userModel = supabaseProvider.user;

    if (userModel == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const MainDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // شريط التطبيق المخصص
              _buildCustomAppBar(userModel.name),

              // محتوى التبويبات
              Expanded(
                child: !_isInitialized
                    ? _buildLoadingScreen()
                    : Column(
                        children: [
                          // شريط التبويبات
                          _buildTabBar(),

                          // محتوى التبويبات
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildOverviewTab(),
                                _buildProductsTab(),
                                _buildWarehousesTab(),
                                _buildRequestsTab(),
                                // Removed _buildWorkerAttendanceTab()
                              ],
                            ),
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

  /// بناء شريط التطبيق المخصص
  Widget _buildCustomAppBar(String userName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 28),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً، $userName',
                  style: GoogleFonts.cairo(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'لوحة تحكم مدير المخزن',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
            onPressed: _refreshData,
          ),
        ],
      ),
    );
  }

  /// بناء شريط التبويبات
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF10B981),
              const Color(0xFF059669),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.dashboard_rounded, size: 20),
            text: 'نظرة عامة',
          ),
          Tab(
            icon: Icon(Icons.inventory_2_rounded, size: 20),
            text: 'المنتجات',
          ),
          Tab(
            icon: Icon(Icons.warehouse_rounded, size: 20),
            text: 'المخازن',
          ),
          Tab(
            icon: Icon(Icons.local_shipping_rounded, size: 20),
            text: 'صرف مخزون',
          ),
          // Removed worker attendance tab
        ],
      ),
    );
  }

  /// بناء شاشة التحميل
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981),
                  const Color(0xFF059669),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'جاري تحميل بيانات المخزن...',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يرجى الانتظار',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء تبويب النظرة العامة
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // إحصائيات سريعة
          const WarehouseStatsOverview(),
          const SizedBox(height: 24),

          // بطاقات الوصول السريع
          Text(
            'الوصول السريع',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildQuickAccessCards(),
        ],
      ),
    );
  }

  /// بناء بطاقات الوصول السريع
  Widget _buildQuickAccessCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3, // تم تحسين النسبة لتوفير مساحة أفضل مع 3 بطاقات
      children: [
        WarehouseDashboardCard(
          title: 'إدارة المخازن',
          subtitle: 'إضافة وتعديل المخازن',
          icon: Icons.warehouse_rounded,
          color: const Color(0xFF3B82F6),
          onTap: () => _tabController.animateTo(2),
        ),
        WarehouseDashboardCard(
          title: 'إدارة المنتجات',
          subtitle: 'عرض وإدارة المخزون',
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF10B981),
          onTap: () => _tabController.animateTo(1),
        ),
        WarehouseDashboardCard(
          title: 'طلبات السحب',
          subtitle: 'معالجة الطلبات',
          icon: Icons.assignment_rounded,
          color: const Color(0xFFF59E0B),
          onTap: () => _tabController.animateTo(3),
        ),
        WarehouseDashboardCard(
          title: 'حضور العمال',
          subtitle: 'مسح QR وتسجيل الحضور',
          icon: Icons.qr_code_scanner,
          color: const Color(0xFF8B5CF6),
          onTap: () => _tabController.animateTo(4),
        ),
      ],
    );
  }

  /// بناء تبويب المنتجات
  Widget _buildProductsTab() {
    return Consumer<WarehouseProductsProvider>(
      builder: (context, productsProvider, child) {
        return Column(
          children: [
            // شريط البحث المتقدم
            Padding(
              padding: const EdgeInsets.all(16),
              child: AdvancedSearchBar(
                controller: _searchController,
                hintText: 'البحث في المنتجات (اسم، فئة، SKU)...',
                accentColor: AccountantThemeConfig.primaryGreen,
                showSearchAnimation: true,
                onChanged: (query) {
                  productsProvider.setSearchQuery(query);
                },
                onSubmitted: (query) {
                  productsProvider.setSearchQuery(query);
                },
              ),
            ),

            // محتوى المنتجات
            Expanded(
              child: _buildProductsContent(productsProvider),
            ),
          ],
        );
      },
    );
  }

  /// بناء محتوى المنتجات
  Widget _buildProductsContent(WarehouseProductsProvider provider) {
    if (provider.isLoading) {
      return _buildProductsLoadingState();
    }

    if (provider.hasError) {
      return _buildProductsErrorState(provider.errorMessage, provider);
    }

    if (provider.filteredProducts.isEmpty) {
      return _buildEmptyProductsState();
    }

    return _buildProductsGrid(provider.filteredProducts);
  }

  /// بناء تبويب المخازن
  Widget _buildWarehousesTab() {
    return Consumer<WarehouseProvider>(
      builder: (context, warehouseProvider, child) {
        return Column(
          children: [
            // شريط الأدوات مع زر إضافة مخزن
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'إدارة المخازن',
                      style: AccountantThemeConfig.headlineMedium,
                    ),
                  ),
                  // زر التقارير
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.greenGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                    ),
                    child: IconButton(
                      onPressed: () => _showWarehouseReports(),
                      icon: const Icon(
                        Icons.analytics_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'تقارير المخازن المتقدمة',
                    ),
                  ),

                  // زر البحث في المنتجات
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.blueGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                    ),
                    child: IconButton(
                      onPressed: () => _showWarehouseSearchDialog(),
                      icon: const Icon(
                        Icons.search,
                        color: Colors.white,
                      ),
                      tooltip: 'البحث في المنتجات والفئات',
                    ),
                  ),
                  _buildAddWarehouseButton(),
                ],
              ),
            ),

            // محتوى المخازن
            Expanded(
              child: _buildWarehousesContent(warehouseProvider),
            ),
          ],
        );
      },
    );
  }

  /// بناء زر إضافة مخزن
  Widget _buildAddWarehouseButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showAddWarehouseDialog,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_business_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'إضافة مخزن',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء محتوى المخازن
  Widget _buildWarehousesContent(WarehouseProvider provider) {
    if (provider.isLoadingWarehouses) {
      return _buildWarehousesLoadingState();
    }

    if (provider.error != null) {
      return _buildWarehousesErrorState(provider.error!, provider);
    }

    if (provider.warehouses.isEmpty) {
      return _buildEmptyWarehousesState();
    }

    return _buildWarehousesGrid(provider.warehouses);
  }

  /// بناء حالة تحميل المخازن مع skeleton screens محسن
  Widget _buildWarehousesLoadingState() {
    return Consumer<WarehouseProvider>(
      builder: (context, provider, child) {
        // تحديد مرحلة التحميل بناءً على حالة البيانات
        String loadingStage = 'warehouses';
        if (provider.warehouses.isNotEmpty && provider.isLoadingInventory) {
          loadingStage = 'inventory';
        } else if (provider.warehouses.isNotEmpty && provider.warehouseStatistics.isEmpty) {
          loadingStage = 'statistics';
        }

        return ProgressiveWarehouseLoadingSkeleton(
          loadingStage: loadingStage,
        );
      },
    );
  }

  /// بناء حالة خطأ المخازن
  Widget _buildWarehousesErrorState(String errorMessage, WarehouseProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AccountantThemeConfig.warningOrange,
          ),
          const SizedBox(height: 16),
          Text(
            'خطأ في تحميل المخازن',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => provider.loadWarehouses(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: Text(
              'إعادة المحاولة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء حالة عدم وجود مخازن
  Widget _buildEmptyWarehousesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warehouse_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مخازن',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بإضافة مخزن جديد لإدارة المخزون',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildAddWarehouseButton(),
        ],
      ),
    );
  }

  /// بناء شبكة المخازن مع تحديث تلقائي
  Widget _buildWarehousesGrid(List<WarehouseModel> warehouses) {
    return RefreshIndicator(
      onRefresh: () async {
        final provider = Provider.of<WarehouseProvider>(context, listen: false);
        await provider.loadWarehouses(forceRefresh: true);
        // تحديث إحصائيات جميع المخازن بعد التحديث
        await provider.refreshData();
      },
      backgroundColor: AccountantThemeConfig.cardBackground1,
      color: AccountantThemeConfig.primaryGreen,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75, // Further increased from 0.85 to 0.75 to provide more height and fix text overflow
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: warehouses.length,
        itemBuilder: (context, index) {
          final warehouse = warehouses[index];

          // استخدام Consumer لضمان التحديث التلقائي للبطاقات
          return Consumer<WarehouseProvider>(
            builder: (context, provider, child) {
              final stats = provider.getWarehouseStatistics(warehouse.id);

              // تسجيل تفصيلي للإحصائيات (للتشخيص)
              AppLogger.info('🏭 إحصائيات المخزن ${warehouse.name} (${warehouse.id}):');
              AppLogger.info('  - عدد المنتجات: ${stats['productCount']}');
              AppLogger.info('  - الكمية الإجمالية: ${stats['totalQuantity']}');
              AppLogger.info('  - إجمالي الكراتين: ${stats['totalCartons']}');

              return WarehouseCard(
                warehouse: warehouse,
                productCount: stats['productCount'] as int? ?? 0,
                totalQuantity: stats['totalQuantity'] as int? ?? 0,
                totalCartons: stats['totalCartons'] as int? ?? 0,
                onTap: () => _showWarehouseDetails(warehouse),
                onEdit: () => _showEditWarehouseDialog(warehouse),
                onDelete: () => _showDeleteWarehouseDialog(warehouse),
              );
            },
          );
        },
      ),
    );
  }

  /// بناء تبويب صرف المخزون - استخدام نظام أذون الصرف الفعلي
  Widget _buildRequestsTab() {
    return const WarehouseReleaseOrdersScreen(
      userRole: 'warehouseManager', // تمرير دور مدير المخزن لإظهار أزرار المعالجة
    );
  }

  /// بناء شريحة إحصائيات الطلبات
  Widget _buildDispatchStatsChip(WarehouseDispatchProvider provider) {
    final stats = provider.getRequestsStats();
    final pendingCount = stats['pending'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.pending_actions,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '$pendingCount معلق',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء فلاتر الحالة
  Widget _buildStatusFilters(WarehouseDispatchProvider provider) {
    final filters = [
      {'key': 'all', 'label': 'الكل', 'icon': Icons.list_alt},
      {'key': 'pending', 'label': 'معلق', 'icon': Icons.pending},
      {'key': 'processing', 'label': 'قيد المعالجة', 'icon': Icons.sync},
      {'key': 'completed', 'label': 'مكتمل', 'icon': Icons.check_circle},
      {'key': 'cancelled', 'label': 'ملغي', 'icon': Icons.cancel},
    ];

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = provider.statusFilter == filter['key'];

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    filter['label'] as String,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ],
              ),
              onSelected: (selected) {
                provider.setStatusFilter(filter['key'] as String);
              },
              backgroundColor: Colors.white.withOpacity(0.1),
              selectedColor: AccountantThemeConfig.primaryGreen,
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? AccountantThemeConfig.primaryGreen
                    : Colors.white.withOpacity(0.3),
              ),
            ),
          );
        },
      ),
    );
  }

  /// بناء حالة تحميل المنتجات
  Widget _buildProductsLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.primaryGreen,
                  AccountantThemeConfig.secondaryGreen,
                ],
              ),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل المنتجات...',
            style: AccountantThemeConfig.bodyLarge,
          ),
        ],
      ),
    );
  }

  /// بناء حالة خطأ المنتجات
  Widget _buildProductsErrorState(String? errorMessage, WarehouseProductsProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AccountantThemeConfig.warningOrange,
          ),
          const SizedBox(height: 16),
          Text(
            'خطأ في تحميل المنتجات',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'حدث خطأ غير متوقع',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => provider.loadProducts(),
            icon: const Icon(Icons.refresh),
            label: Text(
              'إعادة المحاولة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء حالة عدم وجود منتجات
  Widget _buildEmptyProductsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد منتجات',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم العثور على أي منتجات مطابقة للبحث',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// بناء شبكة المنتجات
  Widget _buildProductsGrid(List<ProductModel> products) {
    return RefreshIndicator(
      onRefresh: () async {
        final provider = Provider.of<WarehouseProductsProvider>(context, listen: false);
        await provider.loadProducts(forceRefresh: true);
      },
      backgroundColor: AccountantThemeConfig.cardBackground1,
      color: AccountantThemeConfig.primaryGreen,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return WarehouseProductCard(
            product: product,
            onTap: () => _showProductDetails(product),
          );
        },
      ),
    );
  }

  /// عرض تفاصيل المنتج
  void _showProductDetails(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          decoration: AccountantThemeConfig.primaryCardDecoration,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // صورة المنتج
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.imageUrl != null
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.image_not_supported, size: 48, color: Colors.white54),
                        )
                      : const Icon(Icons.inventory_2, size: 48, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 16),

              // اسم المنتج
              Text(
                product.name,
                style: AccountantThemeConfig.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // الكمية المتاحة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'الكمية المتاحة: ${product.quantity}',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // معلومات إضافية
              if (product.category.isNotEmpty) ...[
                _buildDetailRow('الفئة', product.category),
                const SizedBox(height: 8),
              ],
              if (product.sku.isNotEmpty) ...[
                _buildDetailRow('رمز المنتج', product.sku),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 24),

              // زر الإغلاق
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'إغلاق',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بناء صف التفاصيل
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: AccountantThemeConfig.bodyMedium,
        ),
      ],
    );
  }

  /// تحديث البيانات
  Future<void> _refreshData() async {
    try {
      final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);
      await warehouseProvider.refreshData();

      // تحديث المنتجات أيضاً
      final productsProvider = Provider.of<WarehouseProductsProvider>(context, listen: false);
      await productsProvider.loadProducts(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث البيانات بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('خطأ في تحديث البيانات: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في تحديث البيانات',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// عرض حوار إضافة مخزن
  void _showAddWarehouseDialog() {
    showDialog(
      context: context,
      builder: (context) => AddWarehouseDialog(
        onWarehouseAdded: (warehouse) {
          // تحديث قائمة المخازن
          final provider = Provider.of<WarehouseProvider>(context, listen: false);
          provider.loadWarehouses(forceRefresh: true);
        },
      ),
    );
  }

  /// عرض حوار تعديل مخزن
  void _showEditWarehouseDialog(WarehouseModel warehouse) {
    showDialog(
      context: context,
      builder: (context) => AddWarehouseDialog(
        warehouse: warehouse,
        onWarehouseAdded: (updatedWarehouse) {
          // تحديث قائمة المخازن
          final provider = Provider.of<WarehouseProvider>(context, listen: false);
          provider.loadWarehouses(forceRefresh: true);
        },
      ),
    );
  }

  /// عرض تفاصيل المخزن
  void _showWarehouseDetails(WarehouseModel warehouse) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WarehouseDetailsScreen(warehouse: warehouse),
      ),
    );
  }

  /// عرض حوار حذف مخزن
  void _showDeleteWarehouseDialog(WarehouseModel warehouse) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'حذف المخزن',
          style: AccountantThemeConfig.headlineSmall,
        ),
        content: Text(
          'هل أنت متأكد من حذف المخزن "${warehouse.name}"؟\nسيتم حذف جميع البيانات المرتبطة به.',
          style: AccountantThemeConfig.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteWarehouse(warehouse);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.warningOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// حذف مخزن
  Future<void> _deleteWarehouse(WarehouseModel warehouse) async {
    try {
      final provider = Provider.of<WarehouseProvider>(context, listen: false);
      final success = await provider.deleteWarehouse(warehouse.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'تم حذف المخزن بنجاح' : 'فشل في حذف المخزن',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: success
                ? AccountantThemeConfig.primaryGreen
                : AccountantThemeConfig.warningOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('خطأ في حذف المخزن: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في حذف المخزن',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// بناء محتوى طلبات الصرف
  Widget _buildDispatchContent(WarehouseDispatchProvider provider) {
    if (provider.isLoading) {
      return _buildDispatchLoadingState();
    }

    if (provider.hasError) {
      return _buildDispatchErrorState(provider.errorMessage, provider);
    }

    if (provider.filteredRequests.isEmpty) {
      return _buildEmptyDispatchState();
    }

    return _buildDispatchList(provider.filteredRequests);
  }

  /// بناء حالة تحميل طلبات الصرف
  Widget _buildDispatchLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AccountantThemeConfig.greenGradient,
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل طلبات الصرف...',
            style: AccountantThemeConfig.bodyLarge,
          ),
        ],
      ),
    );
  }

  /// بناء حالة خطأ طلبات الصرف
  Widget _buildDispatchErrorState(String? errorMessage, WarehouseDispatchProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AccountantThemeConfig.warningOrange,
          ),
          const SizedBox(height: 16),
          Text(
            'خطأ في تحميل طلبات الصرف',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'حدث خطأ غير متوقع',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => provider.loadDispatchRequests(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: Text(
              'إعادة المحاولة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء حالة عدم وجود طلبات صرف
  Widget _buildEmptyDispatchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد طلبات صرف',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر هنا طلبات الصرف المرسلة من المحاسب',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// بناء قائمة طلبات الصرف
  Widget _buildDispatchList(List<WarehouseDispatchModel> requests) {
    return RefreshIndicator(
      onRefresh: () async {
        final provider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
        await provider.loadDispatchRequests(forceRefresh: true);
      },
      backgroundColor: AccountantThemeConfig.cardBackground1,
      color: AccountantThemeConfig.primaryGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _buildDispatchCard(request);
        },
      ),
    );
  }

  /// بناء بطاقة طلب الصرف
  Widget _buildDispatchCard(WarehouseDispatchModel request) {
    final statusColor = _getDispatchStatusColor(request.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        children: [
          // رأس البطاقة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withOpacity(0.1),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getDispatchTypeIcon(request.type),
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.requestNumber,
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.customerName,
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.statusText,
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // محتوى البطاقة
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // معلومات الطلب (تم إزالة المبلغ لإخفاء المعلومات المالية عن مدير المخزن)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDispatchInfoItem(
                      'النوع',
                      request.typeText,
                      Icons.category_outlined,
                    ),
                    _buildDispatchInfoItem(
                      'العناصر',
                      '${request.itemsCount}',
                      Icons.inventory_2_outlined,
                    ),
                    _buildDispatchInfoItem(
                      'التاريخ',
                      _formatDate(request.requestedAt),
                      Icons.calendar_today_outlined,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // أزرار الإجراءات
                Row(
                  children: [
                    Expanded(
                      child: _buildDispatchActionButton(
                        'عرض التفاصيل',
                        Icons.visibility_outlined,
                        AccountantThemeConfig.accentBlue,
                        () => _showDispatchDetails(request),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (request.canProcess)
                      Expanded(
                        child: _buildDispatchActionButton(
                          'معالجة',
                          Icons.play_arrow,
                          AccountantThemeConfig.primaryGreen,
                          () => _processDispatchRequest(request),
                        ),
                      ),
                    if (request.status == 'processing')
                      Expanded(
                        child: _buildDispatchActionButton(
                          'إكمال',
                          Icons.check_circle_outline,
                          Colors.green,
                          () => _completeDispatchRequest(request),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// بناء عنصر معلومات الطلب
  Widget _buildDispatchInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: AccountantThemeConfig.primaryGreen,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 10,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  /// بناء زر إجراء الطلب
  Widget _buildDispatchActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// الحصول على لون حالة الطلب
  Color _getDispatchStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AccountantThemeConfig.warningOrange;
      case 'processing':
        return AccountantThemeConfig.accentBlue;
      case 'completed':
        return AccountantThemeConfig.primaryGreen;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// الحصول على أيقونة نوع الطلب
  IconData _getDispatchTypeIcon(String type) {
    switch (type) {
      case 'invoice':
        return Icons.receipt_outlined;
      case 'manual':
        return Icons.edit_outlined;
      default:
        return Icons.local_shipping_outlined;
    }
  }

  /// تنسيق التاريخ للعرض
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
      return '${date.day}/${date.month}';
    }
  }

  /// عرض تفاصيل طلب الصرف
  void _showDispatchDetails(WarehouseDispatchModel request) {
    try {
      AppLogger.info('📋 عرض تفاصيل طلب الصرف: ${request.requestNumber}');

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DispatchDetailsScreen(dispatch: request),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في عرض تفاصيل طلب الصرف: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في عرض تفاصيل الطلب',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// معالجة طلب الصرف
  Future<void> _processDispatchRequest(WarehouseDispatchModel request) async {
    try {
      AppLogger.info('🔄 بدء معالجة طلب الصرف: ${request.requestNumber}');

      // أولاً: تحديث حالة الطلب إلى "processing"
      final dispatchProvider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final currentUser = supabaseProvider.user;

      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // عرض مؤشر التحميل أثناء تحديث الحالة
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: AccountantThemeConfig.primaryCardDecoration,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AccountantThemeConfig.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'جاري بدء معالجة الطلب...',
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // تحديث حالة الطلب إلى "processing"
      final success = await dispatchProvider.updateDispatchStatus(
        requestId: request.id,
        newStatus: WarehouseDispatchConstants.statusProcessing,
        updatedBy: currentUser.id,
        notes: 'تم بدء معالجة الطلب بواسطة مدير المخزن',
      );

      // إغلاق مؤشر التحميل
      if (mounted) Navigator.of(context).pop();

      if (success) {
        AppLogger.info('✅ تم تحديث حالة الطلب إلى processing بنجاح');

        // FIXED: التحقق من الحالة الفعلية في قاعدة البيانات مع آلية إعادة المحاولة
        if (mounted) {
          AppLogger.info('🔄 التحقق من حالة الطلب مع آلية إعادة المحاولة...');

          // استخدام آلية إعادة المحاولة للتحقق من الحالة
          final verifiedRequest = await dispatchProvider.getDispatchByIdWithRetry(
            request.id,
            WarehouseDispatchConstants.statusProcessing,
            maxRetries: 5,
            retryDelay: const Duration(milliseconds: 300),
          );

          if (verifiedRequest != null) {
            AppLogger.info('✅ تم التحقق من الحالة بنجاح - فتح شاشة المعالجة التفاعلية');

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => InteractiveDispatchProcessingScreen(dispatch: verifiedRequest),
                fullscreenDialog: true,
              ),
            );
          } else {
            AppLogger.error('❌ فشل في التحقق من حالة الطلب بعد عدة محاولات');

            // محاولة أخيرة بإعادة تحميل كامل وتشخيص شامل
            AppLogger.info('🔄 محاولة أخيرة بإعادة تحميل كامل وتشخيص...');

            // تشخيص شامل للمشكلة
            AppLogger.info('🔍 تشخيص شامل للمشكلة...');
            final integrity = await dispatchProvider.verifyRequestIntegrity(request.id);
            AppLogger.info('📊 نتائج التشخيص: $integrity');

            // إعادة تحميل قسري
            await dispatchProvider.forceRefreshFromDatabase();

            final finalAttempt = await dispatchProvider.getDispatchById(request.id, forceRefresh: true);

            if (finalAttempt != null) {
              AppLogger.info('📋 المحاولة الأخيرة - الحالة الفعلية: ${finalAttempt.status}');

              if (finalAttempt.status == WarehouseDispatchConstants.statusProcessing) {
                AppLogger.info('✅ نجحت المحاولة الأخيرة - فتح شاشة المعالجة');

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InteractiveDispatchProcessingScreen(dispatch: finalAttempt),
                    fullscreenDialog: true,
                  ),
                );
              } else {
                // إذا كانت الحالة لا تزال غير صحيحة، قم بإصلاحها
                AppLogger.warning('⚠️ الحالة لا تزال غير صحيحة: ${finalAttempt.status}');
                AppLogger.info('🔧 محاولة إصلاح الحالة مباشرة...');

                // محاولة تحديث الحالة مرة أخرى
                final fixAttempt = await dispatchProvider.updateDispatchStatus(
                  requestId: request.id,
                  newStatus: WarehouseDispatchConstants.statusProcessing,
                  updatedBy: supabaseProvider.user!.id,
                  notes: 'إصلاح تلقائي للحالة بعد فشل التزامن',
                );

                if (fixAttempt) {
                  AppLogger.info('✅ تم إصلاح الحالة - فتح شاشة المعالجة');

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => InteractiveDispatchProcessingScreen(dispatch: finalAttempt.copyWith(status: WarehouseDispatchConstants.statusProcessing)),
                      fullscreenDialog: true,
                    ),
                  );
                } else {
                  throw Exception('فشل في إصلاح حالة الطلب بعد جميع المحاولات');
                }
              }
            } else {
              throw Exception('فشل في العثور على الطلب بعد جميع المحاولات');
            }
          }
        }
      } else {
        throw Exception('فشل في تحديث حالة الطلب إلى processing');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في بدء معالجة طلب الصرف: $e');

      // إغلاق مؤشر التحميل إذا كان مفتوحاً
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في بدء معالجة الطلب: ${e.toString()}',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// إكمال طلب الصرف
  Future<void> _completeDispatchRequest(WarehouseDispatchModel request) async {
    try {
      AppLogger.info('✅ بدء إكمال طلب الصرف: ${request.requestNumber}');

      // عرض حوار التأكيد
      final confirmed = await _showCompleteConfirmationDialog(request);
      if (!confirmed) return;

      // عرض مؤشر التحميل
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: AccountantThemeConfig.primaryCardDecoration,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AccountantThemeConfig.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'جاري إكمال الطلب...',
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final dispatchProvider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final currentUser = supabaseProvider.user;

      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // تحديث حالة الطلب إلى "completed"
      final success = await dispatchProvider.updateDispatchStatus(
        requestId: request.id,
        newStatus: WarehouseDispatchConstants.statusCompleted,
        updatedBy: currentUser.id,
        notes: 'تم إكمال الطلب بواسطة مدير المخزن',
      );

      // إغلاق مؤشر التحميل
      if (mounted) Navigator.of(context).pop();

      if (success) {
        AppLogger.info('✅ تم إكمال طلب الصرف بنجاح');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم إكمال الطلب: ${request.requestNumber}',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: AccountantThemeConfig.primaryGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        throw Exception('فشل في تحديث حالة الطلب');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في إكمال طلب الصرف: $e');

      // إغلاق مؤشر التحميل إذا كان مفتوحاً
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في إكمال الطلب: ${e.toString()}',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// عرض حوار تأكيد معالجة الطلب
  Future<bool> _showProcessConfirmationDialog(WarehouseDispatchModel request) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: AlertDialog(
          backgroundColor: AccountantThemeConfig.cardBackground1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تأكيد معالجة الطلب',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من بدء معالجة هذا الطلب؟',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.cardBackground2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رقم الطلب: ${request.requestNumber}',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'السبب: ${request.reason}',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'عدد العناصر: ${request.items.length}',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'إلغاء',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'تأكيد المعالجة',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  /// عرض حوار تأكيد إكمال الطلب
  Future<bool> _showCompleteConfirmationDialog(WarehouseDispatchModel request) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: AlertDialog(
          backgroundColor: AccountantThemeConfig.cardBackground1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تأكيد إكمال الطلب',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من إكمال هذا الطلب؟',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'سيتم تحديث حالة الطلب إلى "مكتمل" ولن يمكن التراجع عن هذا الإجراء.',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: AccountantThemeConfig.warningOrange,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.cardBackground2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رقم الطلب: ${request.requestNumber}',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'السبب: ${request.reason}',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'إلغاء',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'تأكيد الإكمال',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  /// عرض حوار البحث في المخازن
  void _showWarehouseSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider(
        create: (context) => WarehouseSearchProvider(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: Column(
              children: [
                // شريط العنوان
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.cardGradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.greenGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'البحث في المنتجات والفئات',
                          style: GoogleFonts.cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                        ),
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                ),

                // محتوى البحث
                const Expanded(
                  child: WarehouseSearchWidget(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// تنسيق التاريخ والوقت
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// عرض شاشة تقارير المخازن المتقدمة
  void _showWarehouseReports() {
    AppLogger.info('🔍 فتح شاشة تقارير المخازن المتقدمة');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WarehouseReportsScreen(),
      ),
    );
  }






  /// بناء تبويب حضور العمال
  Widget _buildWorkerAttendanceTab() {
    // تجنب مشاكل دورة الحياة عبر التحقق من حالة التركيب
    if (!mounted) {
      return const SizedBox.shrink();
    }

    return ChangeNotifierProvider.value(
      value: _workerAttendanceProvider,
      child: const WorkerAttendanceDashboardTab(),
    );
  }
}
