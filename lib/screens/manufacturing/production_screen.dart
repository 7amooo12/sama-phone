import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/services/manufacturing/production_service.dart';
import 'package:smartbiztracker_new/screens/manufacturing/widgets/production_card.dart';
import 'package:smartbiztracker_new/screens/manufacturing/production_batch_details_screen.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'dart:async';

/// شاشة الإنتاج الرئيسية مع عرض دفعات الإنتاج وإدارة العمليات
class ProductionScreen extends StatefulWidget {
  /// تحديد ما إذا كانت الشاشة مفتوحة من سياق المالك
  final bool isOwnerContext;

  const ProductionScreen({
    super.key,
    this.isOwnerContext = false,
  });

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  final ProductionService _productionService = ProductionService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<ProductionBatch> _batches = [];
  List<ProductionBatch> _filteredBatches = [];
  Map<int, ProductModel> _productCache = {};
  bool _isLoading = true;
  String _selectedStatusFilter = 'all';
  String _searchQuery = '';
  Timer? _searchDebounceTimer;


  @override
  void initState() {
    super.initState();
    _loadProductionBatches();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  /// تحميل دفعات الإنتاج
  Future<void> _loadProductionBatches() async {
    try {
      setState(() => _isLoading = true);

      final batches = await _productionService.getProductionBatches(limit: 100);

      // تحميل تفاصيل المنتجات
      await _loadProductDetails(batches);

      if (mounted) {
        setState(() {
          _batches = batches;
          _filteredBatches = batches;
          _isLoading = false;
        });

        AppLogger.info('✅ Loaded ${batches.length} production batches');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('فشل في تحميل دفعات الإنتاج: $e');
      }
      AppLogger.error('❌ Error loading production batches: $e');
    }
  }

  /// تحميل تفاصيل المنتجات للدفعات
  Future<void> _loadProductDetails(List<ProductionBatch> batches) async {
    try {
      final productIds = batches.map((batch) => batch.productId).toSet().toList();
      final products = await _productionService.getProductsByIds(productIds);

      if (mounted) {
        setState(() {
          _productCache.addAll(products);
        });
      }

      AppLogger.info('✅ Loaded ${products.length} product details');
    } catch (e) {
      AppLogger.error('❌ Error loading product details: $e');
    }
  }



  /// تطبيق البحث والفلترة
  void _applyFilters() {
    List<ProductionBatch> filtered = _batches;

    // تطبيق فلتر الحالة
    if (_selectedStatusFilter != 'all') {
      filtered = filtered.where((batch) => batch.status == _selectedStatusFilter).toList();
    }

    // تطبيق البحث
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((batch) {
        // البحث في رقم الدفعة
        if (batch.id.toString().contains(query)) return true;

        // البحث في معرف المنتج
        if (batch.productId.toString().contains(query)) return true;

        // البحث في اسم المنتج
        final product = _productCache[batch.productId];
        if (product != null && product.name.toLowerCase().contains(query)) return true;

        // البحث في حالة الإنتاج
        if (batch.statusText.toLowerCase().contains(query)) return true;

        // البحث في ملاحظات الدفعة
        if (batch.notes != null && batch.notes!.toLowerCase().contains(query)) return true;

        return false;
      }).toList();
    }

    setState(() {
      _filteredBatches = filtered;
    });
  }

  /// تغيير فلتر الحالة
  void _onStatusFilterChanged(String filter) {
    setState(() {
      _selectedStatusFilter = filter;
    });
    _applyFilters();
  }

  /// معالجة تغيير نص البحث مع debouncing
  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
      setState(() {
        _searchQuery = query;
      });
      _applyFilters();
    });
  }

  /// التنقل إلى شاشة بدء الإنتاج
  void _navigateToStartProduction() {
    Navigator.pushNamed(context, '/production/start').then((_) {
      _loadProductionBatches();
    });
  }

  /// التنقل إلى شاشة عرض الأدوات
  void _navigateToViewTools() {
    Navigator.pushNamed(context, '/manufacturing-tools');
  }

  /// التنقل إلى شاشة تفاصيل دفعة الإنتاج
  void _navigateToDetailedScreen(ProductionBatch batch, ProductModel? product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductionBatchDetailsScreen(
          batch: batch,
          product: product,
        ),
      ),
    ).then((_) {
      // إعادة تحميل البيانات عند العودة في حالة تم تعديل شيء
      _loadProductionBatches();
    });
  }

  /// إظهار رسالة خطأ
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AccountantThemeConfig.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildSearchSection(),
          _buildFiltersSection(),
          _buildProductionBatchesGrid(),
        ],
      ),
      // إخفاء أزرار الإجراءات العائمة في سياق المالك
      floatingActionButton: widget.isOwnerContext ? null : _buildFloatingActionButtons(),
    );
  }

  /// بناء SliverAppBar
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: FlexibleSpaceBar(
          title: Text(
            widget.isOwnerContext ? 'الإنتاج - عرض المالك' : 'الإنتاج',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
      ),
    );
  }

  /// بناء قسم البحث
  Widget _buildSearchSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'البحث في دفعات الإنتاج',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                border: AccountantThemeConfig.glowBorder(
                  _searchQuery.isNotEmpty
                    ? AccountantThemeConfig.primaryGreen
                    : AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)
                ),
                boxShadow: AccountantThemeConfig.cardShadows,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textDirection: TextDirection.rtl,
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ابحث برقم الدفعة، اسم المنتج، الحالة، أو الملاحظات...',
                  hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white54,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.white54,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _searchDebounceTimer?.cancel();
                            setState(() {
                              _searchQuery = '';
                            });
                            _applyFilters();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty || _selectedStatusFilter != 'all') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 16,
                      color: AccountantThemeConfig.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'عُثر على ${_filteredBatches.length} دفعة',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// بناء قسم الفلاتر
  Widget _buildFiltersSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AccountantThemeConfig.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'فلترة حسب الحالة',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('الكل', 'all'),
                  _buildFilterChip('مكتملة', 'completed'),
                  _buildFilterChip('قيد التنفيذ', 'in_progress'),
                  _buildFilterChip('في الانتظار', 'pending'),
                  _buildFilterChip('ملغية', 'cancelled'),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// بناء رقاقة الفلتر
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onStatusFilterChanged(value),
        backgroundColor: Colors.transparent,
        selectedColor: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
        checkmarkColor: AccountantThemeConfig.primaryGreen,
        labelStyle: AccountantThemeConfig.bodySmall.copyWith(
          color: isSelected ? AccountantThemeConfig.primaryGreen : Colors.white70,
        ),
        side: BorderSide(
          color: isSelected ? AccountantThemeConfig.primaryGreen : Colors.white30,
        ),
      ),
    );
  }

  /// بناء شبكة دفعات الإنتاج
  Widget _buildProductionBatchesGrid() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Center(
          child: CustomLoader(message: 'جاري تحميل دفعات الإنتاج...'),
        ),
      );
    }

    final filteredBatches = _filteredBatches;

    if (filteredBatches.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
          padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
          ),
          child: Column(
            children: [
              Icon(
                Icons.production_quantity_limits,
                size: 64,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد دفعات إنتاج',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty || _selectedStatusFilter != 'all'
                    ? 'لم يتم العثور على دفعات إنتاج تطابق معايير البحث'
                    : 'لم يتم العثور على دفعات إنتاج',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty || _selectedStatusFilter != 'all') ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    _searchDebounceTimer?.cancel();
                    setState(() {
                      _searchQuery = '';
                      _selectedStatusFilter = 'all';
                    });
                    _applyFilters();
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('مسح جميع الفلاتر'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          childAspectRatio: 2.5, // Enlarged from 2.2 to 2.5 for better readability and improved layout
          mainAxisSpacing: 24, // Increased spacing from 20 to 24 for better visual hierarchy
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final batch = filteredBatches[index];
            final product = _productCache[batch.productId];
            return ProductionCard(
              batch: batch,
              product: product,
              onTap: () => _showBatchDetails(batch),
              onLongPress: () => _navigateToDetailedScreen(batch, product),
            );
          },
          childCount: filteredBatches.length,
        ),
      ),
    );
  }

  /// إظهار تفاصيل الدفعة
  void _showBatchDetails(ProductionBatch batch) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تفاصيل دفعة الإنتاج',
                    style: AccountantThemeConfig.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('رقم الدفعة', '#${batch.id}'),
                    _buildDetailRow('معرف المنتج', '${batch.productId}'),
                    _buildDetailRow('الوحدات المنتجة', '${batch.unitsProduced}'),
                    _buildDetailRow('الحالة', batch.statusText),
                    _buildDetailRow('تاريخ الإكمال', batch.formattedCompletionDate),
                    _buildDetailRow('وقت الإكمال', batch.formattedCompletionTime),
                    if (batch.warehouseManagerName != null)
                      _buildDetailRow('مدير المخزن', batch.warehouseManagerName!),
                    if (batch.notes != null && batch.notes!.isNotEmpty)
                      _buildDetailRow('ملاحظات', batch.notes!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء صف التفاصيل
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء أزرار الإجراءات العائمة
  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // زر عرض الأدوات
        FloatingActionButton(
          heroTag: "view_tools",
          onPressed: _navigateToViewTools,
          backgroundColor: AccountantThemeConfig.accentBlue,
          child: const Icon(Icons.build, color: Colors.white),
          tooltip: 'عرض الأدوات',
        ),
        
        const SizedBox(height: 16),
        
        // زر بداية الإنتاج
        FloatingActionButton.extended(
          heroTag: "start_production",
          onPressed: _navigateToStartProduction,
          backgroundColor: AccountantThemeConfig.primaryGreen,
          icon: const Icon(Icons.construction, color: Colors.white),
          label: Text(
            'بداية الإنتاج',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
