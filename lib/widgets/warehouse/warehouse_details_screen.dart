import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:smartbiztracker_new/models/warehouse_inventory_model.dart';
import 'package:smartbiztracker_new/models/warehouse_transaction_model.dart';
import 'package:smartbiztracker_new/providers/warehouse_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/warehouse/add_product_to_warehouse_dialog.dart';
import 'package:smartbiztracker_new/widgets/warehouse/interactive_inventory_card.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_skeleton_loader.dart';

/// شاشة تفاصيل المخزن مع إمكانية إضافة المنتجات
class WarehouseDetailsScreen extends StatefulWidget {
  final WarehouseModel warehouse;

  const WarehouseDetailsScreen({
    super.key,
    required this.warehouse,
  });

  @override
  State<WarehouseDetailsScreen> createState() => _WarehouseDetailsScreenState();
}

class _WarehouseDetailsScreenState extends State<WarehouseDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _transactionsLoaded = false; // Track if transactions have been loaded for this warehouse

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWarehouseData();
  }

  /// تحميل بيانات المخزن مع ضمان الحصول على أحدث البيانات
  Future<void> _loadWarehouseData() async {
    try {
      setState(() {
        _isLoading = true;
        _transactionsLoaded = false; // Reset transactions loaded flag for new warehouse
      });

      final provider = Provider.of<WarehouseProvider>(context, listen: false);

      // استخدام الطريقة المحسنة لتحديث بيانات المخزن
      await provider.refreshWarehouseData(widget.warehouse.id);

      // تحديد المخزن المحدد في المزود
      await provider.selectWarehouse(widget.warehouse);

      // تحميل مخزون المخزن
      await provider.loadWarehouseInventory(widget.warehouse.id, forceRefresh: true);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل بيانات المخزن: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // عرض رسالة خطأ للمستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل بيانات المخزن: ${e.toString()}'),
            backgroundColor: AccountantThemeConfig.warningOrange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// تحديث البيانات مع إعادة تعيين حالة التحميل
  Future<void> _refreshData() async {
    setState(() {
      _transactionsLoaded = false; // Reset transactions loaded flag
    });
    await _loadWarehouseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // شريط التطبيق المخصص
              _buildCustomAppBar(),
              
              // شريط التبويبات
              _buildTabBar(),
              
              // محتوى التبويبات
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildProductsTab(),
                          _buildTransactionsTab(),
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
  Widget _buildCustomAppBar() {
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.warehouse.name,
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
                  'تفاصيل المخزن',
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
          gradient: AccountantThemeConfig.greenGradient,
          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.6),
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
            icon: Icon(Icons.history_rounded, size: 20),
            text: 'المعاملات',
          ),
        ],
      ),
    );
  }

  /// بناء حالة التحميل
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
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
          const SizedBox(height: 24),
          Text(
            'جاري تحميل بيانات المخزن...',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء تبويب النظرة العامة
  Widget _buildOverviewTab() {
    return Consumer<WarehouseProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات المخزن
              _buildWarehouseInfoCard(),
              const SizedBox(height: 20),
              
              // إحصائيات سريعة
              _buildQuickStatsGrid(provider),
              const SizedBox(height: 20),
              
              // المنتجات منخفضة المخزون
              _buildLowStockSection(provider),
            ],
          ),
        );
      },
    );
  }

  /// بناء تبويب المنتجات
  Widget _buildProductsTab() {
    return Consumer<WarehouseProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // شريط الأدوات مع زر إضافة منتج
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'منتجات المخزن',
                      style: AccountantThemeConfig.headlineMedium,
                    ),
                  ),
                  _buildAddProductButton(),
                ],
              ),
            ),

            // قائمة المنتجات مع skeleton loading
            Expanded(
              child: provider.isLoadingInventory
                  ? const InventoryListSkeleton(itemCount: 8)
                  : provider.currentInventory.isEmpty
                      ? _buildEmptyProductsState()
                      : _buildProductsList(provider.currentInventory),
            ),
          ],
        );
      },
    );
  }

  /// بناء تبويب المعاملات
  Widget _buildTransactionsTab() {
    return Consumer<WarehouseProvider>(
      builder: (context, provider, child) {
        // Load transactions only once for this warehouse using a flag
        if (!_transactionsLoaded) {
          // Use Future.microtask to avoid calling during build
          Future.microtask(() async {
            await provider.loadWarehouseTransactions(
              widget.warehouse.id,
              forceRefresh: false, // Don't force refresh to use cache if available
            );
            if (mounted) {
              setState(() {
                _transactionsLoaded = true;
              });
            }
          });
          // Return loading state while transactions are being loaded for the first time
          return _buildTransactionsLoadingState();
        }

        // Check loading state from provider
        if (provider.isLoading == true) {
          return _buildTransactionsLoadingState();
        }

        // Get transactions and check if empty
        final transactions = provider.transactions as List<WarehouseTransactionModel>;
        if (transactions.isEmpty) {
          return _buildEmptyTransactionsState();
        }

        return _buildTransactionsList(transactions);
      },
    );
  }

  /// بناء بطاقة معلومات المخزن
  Widget _buildWarehouseInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warehouse_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.warehouse.name,
                      style: AccountantThemeConfig.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.warehouse.isActive 
                            ? AccountantThemeConfig.primaryGreen.withOpacity(0.2)
                            : AccountantThemeConfig.warningOrange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.warehouse.isActive ? 'نشط' : 'غير نشط',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.warehouse.isActive 
                              ? AccountantThemeConfig.primaryGreen
                              : AccountantThemeConfig.warningOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('العنوان', widget.warehouse.address),
          if (widget.warehouse.description != null && widget.warehouse.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('الوصف', widget.warehouse.description!),
          ],
          const SizedBox(height: 8),
          _buildInfoRow('تاريخ الإنشاء', _formatDate(widget.warehouse.createdAt)),
        ],
      ),
    );
  }

  /// بناء صف معلومات
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AccountantThemeConfig.bodyMedium,
          ),
        ),
      ],
    );
  }

  /// FIXED: Enhanced date formatting with better accuracy
  String _formatDate(DateTime date) {
    // Ensure we're working with local time
    final localDate = date.isUtc ? date.toLocal() : date;
    return '${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}/${localDate.year}';
  }

  /// تنسيق الأرقام مع فواصل الآلاف لتحسين القراءة
  String _formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    }

    // تنسيق الأرقام الكبيرة مع فواصل
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return number.toString().replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  /// بناء شبكة الإحصائيات السريعة
  Widget _buildQuickStatsGrid(WarehouseProvider provider) {
    // الحصول على إحصائيات المخزن المحدد
    final warehouseStats = provider.selectedWarehouse != null
        ? provider.getWarehouseStatistics(provider.selectedWarehouse!.id)
        : <String, int>{};

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.8, // Increased from 2.2 to 2.8 to make statistics cards larger
      children: [
        _buildStatCard(
          'إجمالي المنتجات',
          _formatNumber(provider.totalProductsInSelectedWarehouse),
          Icons.inventory_2_outlined,
          AccountantThemeConfig.primaryGreen,
        ),
        _buildStatCard(
          'إجمالي الكمية',
          _formatNumber(provider.totalQuantityInSelectedWarehouse),
          Icons.numbers_outlined,
          AccountantThemeConfig.accentBlue,
        ),
        _buildStatCard(
          'مخزون منخفض',
          _formatNumber(provider.lowStockProducts.length),
          Icons.warning_outlined,
          AccountantThemeConfig.warningOrange,
        ),
        _buildStatCard(
          'إجمالي الكراتين',
          _formatNumber(warehouseStats['totalCartons'] ?? 0),
          Icons.inventory_2_rounded,
          AccountantThemeConfig.successGreen,
        ),
      ],
    );
  }

  /// بناء بطاقة إحصائية محسنة لعرض الأرقام الطويلة
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // حساب الأحجام بناءً على المساحة المتاحة
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        // تحديد أحجام متجاوبة بناءً على طول القيمة
        final valueLength = value.length;
        final isLongValue = valueLength > 4;

        // أحجام متجاوبة للأيقونة والنص
        final iconSize = availableHeight > 100 ? 24.0 : 20.0;
        final valueFontSize = isLongValue
            ? (availableWidth > 150 ? 16.0 : 14.0)
            : (availableWidth > 150 ? 22.0 : 18.0);
        final titleFontSize = availableWidth > 150 ? 12.0 : 10.0;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: availableWidth * 0.08, // حشو متجاوب
            vertical: availableHeight * 0.1,
          ),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // الأيقونة
              Icon(
                icon,
                size: iconSize,
                color: color,
              ),
              SizedBox(height: availableHeight * 0.08),

              // القيمة الرقمية مع تحسين للأرقام الطويلة
              Expanded(
                flex: 2,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: GoogleFonts.cairo(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: isLongValue ? -0.5 : 0, // تقليل المسافة للأرقام الطويلة
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                ),
              ),

              SizedBox(height: availableHeight * 0.05),

              // العنوان
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: titleFontSize,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// بناء قسم المنتجات منخفضة المخزون
  Widget _buildLowStockSection(WarehouseProvider provider) {
    final lowStockProducts = provider.lowStockProducts;
    
    if (lowStockProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'منتجات تحتاج إعادة تخزين',
          style: AccountantThemeConfig.headlineSmall,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AccountantThemeConfig.primaryCardDecoration,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lowStockProducts.length,
            separatorBuilder: (context, index) => const Divider(
              color: Colors.white10,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final item = lowStockProducts[index];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.warningOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_outlined,
                    color: AccountantThemeConfig.warningOrange,
                    size: 20,
                  ),
                ),
                title: Text(
                  item.product?.name ?? 'منتج غير معروف',
                  style: AccountantThemeConfig.bodyLarge,
                ),
                subtitle: Text(
                  'الكمية المتبقية: ${item.quantity}',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.warningOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'منخفض',
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AccountantThemeConfig.warningOrange,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// بناء زر إضافة منتج
  Widget _buildAddProductButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showAddProductDialog,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_box_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'إضافة منتج',
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
            'لا توجد منتجات في هذا المخزن',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بإضافة منتجات إلى المخزن',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildAddProductButton(),
        ],
      ),
    );
  }

  /// بناء قائمة المنتجات
  Widget _buildProductsList(List<dynamic> products) {
    return RefreshIndicator(
      onRefresh: () async {
        final provider = Provider.of<WarehouseProvider>(context, listen: false);
        if (provider.selectedWarehouse != null) {
          await provider.loadWarehouseInventory(
            provider.selectedWarehouse!.id,
            forceRefresh: true,
          );
        }
      },
      backgroundColor: AccountantThemeConfig.cardBackground1,
      color: AccountantThemeConfig.primaryGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final inventoryItem = products[index];

          // التحقق من نوع البيانات وتحويلها إلى WarehouseInventoryModel
          if (inventoryItem is WarehouseInventoryModel) {
            return InteractiveInventoryCard(
              inventoryItem: inventoryItem,
              currentWarehouseId: widget.warehouse.id,
              onRefresh: () async {
                final provider = Provider.of<WarehouseProvider>(context, listen: false);
                await provider.loadWarehouseInventory(
                  widget.warehouse.id,
                  forceRefresh: true,
                );
              },
            );
          }

          // الرجوع للتصميم القديم في حالة عدم التوافق
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
                // توهج سفلي حسب حالة المخزون
                BoxShadow(
                  color: _getStockStatusColor(inventoryItem).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 6),
                  spreadRadius: -2,
                ),
              ],
            ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // صورة المنتج
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStockStatusColor(inventoryItem).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: inventoryItem.product?.imageUrl != null && inventoryItem.product!.imageUrl!.isNotEmpty
                        ? Image.network(
                            inventoryItem.product!.imageUrl!,
                            fit: BoxFit.cover,
                            cacheWidth: 120,
                            cacheHeight: 120,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return _buildLoadingImage();
                            },
                          )
                        : _buildPlaceholderImage(),
                  ),
                ),
                const SizedBox(width: 16),

                // معلومات المنتج
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // اسم المنتج
                      Text(
                        inventoryItem.product?.name ?? 'منتج غير معروف',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // فئة المنتج
                      if (inventoryItem.product?.category != null && inventoryItem.product!.category!.isNotEmpty)
                        Text(
                          inventoryItem.product!.category!,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      const SizedBox(height: 8),

                      // الكمية
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: _getStockStatusColor(inventoryItem),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'الكمية: ${inventoryItem.quantity}',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getStockStatusColor(inventoryItem),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // مؤشر حالة المخزون
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStockStatusColor(inventoryItem).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStockStatusColor(inventoryItem).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getStockStatusText(inventoryItem),
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStockStatusColor(inventoryItem),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  /// بناء حالة عدم وجود معاملات
  Widget _buildEmptyTransactionsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد معاملات',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر هنا جميع معاملات المخزن',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// بناء حالة تحميل المعاملات
  Widget _buildTransactionsLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'جاري تحميل المعاملات...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء قائمة المعاملات
  Widget _buildTransactionsList(List<WarehouseTransactionModel> transactions) {
    return Column(
      children: [
        // Clear All Button
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showClearAllTransactionsDialog(),
                  icon: const Icon(Icons.clear_all_rounded, color: Colors.white),
                  label: const Text(
                    'مسح جميع المعاملات',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.warningOrange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Transactions List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _transactionsLoaded = false; // Reset flag to allow reload
              });
              final provider = Provider.of<WarehouseProvider>(context, listen: false);
              await provider.loadWarehouseTransactions(widget.warehouse.id, forceRefresh: true);
              setState(() {
                _transactionsLoaded = true; // Set flag after successful load
              });
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return _buildTransactionCard(transaction);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// بناء بطاقة معاملة واحدة
  Widget _buildTransactionCard(WarehouseTransactionModel transaction) {
    final String transactionType = transaction.type.displayName;
    final String reason = transaction.reason;
    final int quantity = transaction.quantity;
    final DateTime performedAt = transaction.performedAt;

    String productName = transaction.product?.name ?? 'منتج غير محدد';

    // Determine transaction icon and color
    IconData transactionIcon;
    Color transactionColor;

    if (transactionType.contains('withdrawal') || transactionType.contains('stock_out') || transactionType.contains('out')) {
      transactionIcon = Icons.remove_circle_outline;
      transactionColor = Colors.red;
    } else if (transactionType.contains('addition') || transactionType.contains('stock_in') || transactionType.contains('in')) {
      transactionIcon = Icons.add_circle_outline;
      transactionColor = Colors.green;
    } else {
      transactionIcon = Icons.swap_horiz;
      transactionColor = AccountantThemeConfig.accentBlue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: transactionColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            transactionIcon,
            color: transactionColor,
            size: 24,
          ),
        ),
        title: Text(
          reason,
          style: AccountantThemeConfig.bodyLarge,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productName,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'الكمية: $quantity',
              style: AccountantThemeConfig.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: transactionColor,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDate(performedAt),
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(performedAt),
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        onTap: () => _showTransactionDetails(transaction),
      ),
    );
  }



  /// FIXED: Enhanced time formatting with better accuracy
  String _formatTime(DateTime date) {
    // Ensure we're working with local time
    final localDate = date.isUtc ? date.toLocal() : date;
    return '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
  }

  /// عرض تفاصيل المعاملة
  void _showTransactionDetails(dynamic transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفاصيل المعاملة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('النوع', transaction.type.displayName as String),
            _buildDetailRow('السبب', transaction.reason as String),
            _buildDetailRow('الكمية', transaction.quantity.toString()),
            _buildDetailRow('الكمية قبل', transaction is Map
                ? transaction['quantity_before']?.toString() ?? '0'
                : transaction.quantityBefore.toString()),
            _buildDetailRow('الكمية بعد', transaction is Map
                ? transaction['quantity_after']?.toString() ?? '0'
                : transaction.quantityAfter.toString()),
            if (transaction is Map && transaction['reference_id'] != null)
              _buildDetailRow('المرجع', transaction['reference_id'].toString()),
            if (transaction is Map && transaction['transaction_number'] != null)
              _buildDetailRow('رقم المعاملة', transaction['transaction_number'].toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  /// بناء صف تفاصيل
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  /// الحصول على لون حالة المخزون
  Color _getStockStatusColor(dynamic item) {
    if (item is WarehouseInventoryModel) {
      if (item.quantity == 0) {
        return Colors.red;
      } else if (item.isLowStock) {
        return AccountantThemeConfig.warningOrange;
      } else {
        return AccountantThemeConfig.primaryGreen;
      }
    }
    // Fallback for other types
    if (item.quantity == 0) {
      return Colors.red;
    } else {
      return AccountantThemeConfig.primaryGreen;
    }
  }

  /// الحصول على نص حالة المخزون
  String _getStockStatusText(dynamic item) {
    if (item is WarehouseInventoryModel) {
      if (item.quantity == 0) {
        return 'نفد';
      } else if (item.isLowStock) {
        return 'منخفض';
      } else {
        return 'متوفر';
      }
    }
    // Fallback for other types
    if (item.quantity == 0) {
      return 'نفد';
    } else {
      return 'متوفر';
    }
  }

  /// عرض حوار إضافة منتج
  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => AddProductToWarehouseDialog(
        warehouse: widget.warehouse,
        onProductAdded: () {
          // تحديث بيانات المخزن
          _loadWarehouseData();
        },
      ),
    );
  }

  /// بناء صورة بديلة للمنتج
  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.1),
            Colors.black.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 24,
          color: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }

  /// بناء مؤشر تحميل الصورة
  Widget _buildLoadingImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.1),
            Colors.black.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: AccountantThemeConfig.primaryGreen,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  /// عرض حوار تأكيد مسح جميع المعاملات
  Future<void> _showClearAllTransactionsDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AccountantThemeConfig.cardBackground1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: AccountantThemeConfig.warningOrange,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'تأكيد المسح',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'هل أنت متأكد من رغبتك في مسح جميع معاملات هذا المخزن؟',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.warningOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AccountantThemeConfig.warningOrange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AccountantThemeConfig.warningOrange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'هذا الإجراء لا يمكن التراجع عنه وسيتم حذف جميع سجلات المعاملات نهائياً.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
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
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.warningOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'مسح الكل',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _clearAllTransactions();
    }
  }

  /// مسح جميع المعاملات
  Future<void> _clearAllTransactions() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AccountantThemeConfig.cardBackground1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AccountantThemeConfig.primaryGreen,
              ),
              const SizedBox(height: 16),
              const Text(
                'جاري مسح المعاملات...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );

      final provider = Provider.of<WarehouseProvider>(context, listen: false);

      // Clear all transactions for this warehouse
      await provider.clearAllWarehouseTransactions(widget.warehouse.id);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Reset transactions loaded flag to reload the empty state
      setState(() {
        _transactionsLoaded = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تم مسح جميع المعاملات بنجاح',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }

    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل في مسح المعاملات: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.warningOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }


}
