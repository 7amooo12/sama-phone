import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/all_products_movement_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_loader.dart';
import '../../utils/app_logger.dart';
import '../../utils/accountant_theme_config.dart';

class AllProductsMovementScreen extends StatefulWidget {
  const AllProductsMovementScreen({super.key});

  @override
  State<AllProductsMovementScreen> createState() => _AllProductsMovementScreenState();
}

class _AllProductsMovementScreenState extends State<AllProductsMovementScreen>
    with TickerProviderStateMixin {
  final AllProductsMovementService _service = AllProductsMovementService();

  // Use AccountantThemeConfig currency formatting for consistency
  String _formatCurrency(double amount) {
    return AccountantThemeConfig.formatCurrency(amount);
  }
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final ScrollController _scrollController = ScrollController();

  List<ProductMovementData> _allProducts = [];
  List<ProductMovementData> _filteredProducts = [];
  bool _isLoading = false;
  String? _error;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  String _searchQuery = '';

  // Scroll and UI state
  bool _showScrollToTop = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Initialize search functionality
    _searchController.addListener(_onSearchChanged);

    // Initialize animation controller for FAB
    _fabAnimationController = AnimationController(
      duration: AccountantThemeConfig.animationDuration,
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );

    // Setup scroll listener
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showFab = _scrollController.offset > 200;
    if (showFab != _showScrollToTop) {
      setState(() {
        _showScrollToTop = showFab;
      });
      if (showFab) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    }
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
      setState(() {
        _searchQuery = _searchController.text.trim();
        _filterProducts();
      });
    });
  }

  void _filterProducts() {
    if (_searchQuery.isEmpty) {
      _filteredProducts = List.from(_allProducts);
    } else {
      _filteredProducts = _allProducts.where((product) {
        return product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               product.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      AppLogger.info('بدء تحميل حركة جميع المنتجات');
      final response = await _service.getAllProductsMovement();

      setState(() {
        _allProducts = response.products;
        _filteredProducts = List.from(_allProducts);
        _isLoading = false;
      });

      AppLogger.info('تم تحميل ${_allProducts.length} منتج بنجاح');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      AppLogger.error('خطأ في تحميل حركة المنتجات', e);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Modern App Bar
              _buildModernAppBar(),

              // Search Bar
              _buildSearchBar(),

              // Content
              _buildSliverContent(),
            ],
          ),
        ),
        floatingActionButton: _buildScrollToTopFAB(),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: FlexibleSpaceBar(
          title: Text(
            'حركة المنتجات',
            style: AccountantThemeConfig.headlineMedium,
          ),
          centerTitle: true,
          background: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                  AccountantThemeConfig.accentBlue.withOpacity(0.1),
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.analytics_rounded,
                size: 48,
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(left: AccountantThemeConfig.defaultPadding),
          padding: const EdgeInsets.symmetric(
            horizontal: AccountantThemeConfig.defaultPadding,
            vertical: AccountantThemeConfig.smallPadding,
          ),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.greenGradient,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
          ),
          child: Text(
            '${_filteredProducts.length}',
            style: AccountantThemeConfig.labelMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
          child: TextField(
            controller: _searchController,
            textDirection: ui.TextDirection.rtl,
            style: AccountantThemeConfig.bodyLarge,
            decoration: InputDecoration(
              hintText: 'البحث في المنتجات...',
              hintStyle: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white.withOpacity(0.6),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: AccountantThemeConfig.dangerRed,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _filterProducts();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.primaryGreen,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AccountantThemeConfig.defaultPadding,
                vertical: AccountantThemeConfig.smallPadding,
              ),
            ),
          ),
        ),
      ),
    );
  }





  Widget _buildSliverContent() {
    if (_isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CustomLoader(),
              const SizedBox(height: AccountantThemeConfig.defaultPadding),
              Text(
                'جاري تحميل حركة المنتجات...',
                style: AccountantThemeConfig.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AccountantThemeConfig.dangerRed,
              ),
              const SizedBox(height: AccountantThemeConfig.defaultPadding),
              Text(
                'خطأ في تحميل البيانات',
                style: AccountantThemeConfig.headlineMedium.copyWith(
                  color: AccountantThemeConfig.dangerRed,
                ),
              ),
              const SizedBox(height: AccountantThemeConfig.smallPadding),
              Text(
                _error!,
                style: AccountantThemeConfig.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AccountantThemeConfig.defaultPadding),
              Container(
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.orangeGradient,
                  borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                ),
                child: ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                  ),
                  child: Text('إعادة المحاولة', style: AccountantThemeConfig.labelMedium),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.5),
              ),
              const SizedBox(height: AccountantThemeConfig.defaultPadding),
              Text(
                _searchQuery.isEmpty ? 'لا توجد منتجات' : 'لا توجد نتائج',
                style: AccountantThemeConfig.headlineMedium.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: AccountantThemeConfig.smallPadding),
              Text(
                _searchQuery.isEmpty
                    ? 'لم يتم العثور على أي منتجات في النظام'
                    : 'لم يتم العثور على منتجات تطابق البحث "${_searchQuery}"',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = _filteredProducts[index];
          return Padding(
            padding: EdgeInsets.only(
              left: AccountantThemeConfig.defaultPadding,
              right: AccountantThemeConfig.defaultPadding,
              bottom: AccountantThemeConfig.defaultPadding,
              top: index == 0 ? AccountantThemeConfig.defaultPadding : 0,
            ),
            child: _buildModernProductCard(product),
          );
        },
        childCount: _filteredProducts.length,
      ),
    );
  }

  Widget _buildScrollToTopFAB() {
    return AnimatedBuilder(
      animation: _fabAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabAnimation.value,
          child: Opacity(
            opacity: _fabAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: FloatingActionButton(
                onPressed: _scrollToTop,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        );
      },
    );
  }



  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomLoader(),
            SizedBox(height: 16),
            Text('جاري تحميل حركة المنتجات...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'خطأ في تحميل البيانات',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_allProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد منتجات',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على أي منتجات في النظام',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allProducts.length,
      itemBuilder: (context, index) {
        final product = _allProducts[index];
        return _buildModernProductCard(product);
      },
    );
  }

  Widget _buildModernProductCard(ProductMovementData product) {
    final hasMovement = product.salesSummary.totalSold > 0;
    final movementColor = hasMovement ? AccountantThemeConfig.primaryGreen : AccountantThemeConfig.warningOrange;

    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(movementColor),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: ExpansionTile(
        leading: _buildModernProductImage(product, hasMovement),
        title: Text(
          product.name,
          style: AccountantThemeConfig.headlineSmall.copyWith(fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.sku.isNotEmpty)
              Text(
                'الكود: ${product.sku}',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            const SizedBox(height: AccountantThemeConfig.smallPadding),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AccountantThemeConfig.smallPadding,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: hasMovement
                        ? AccountantThemeConfig.greenGradient
                        : AccountantThemeConfig.orangeGradient,
                    borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
                    boxShadow: AccountantThemeConfig.glowShadows(movementColor),
                  ),
                  child: Text(
                    hasMovement ? 'يوجد حركة' : 'لا يوجد حركة',
                    style: AccountantThemeConfig.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AccountantThemeConfig.smallPadding),
                Text(
                  'المخزون: ${product.currentStock}',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: product.currentStock > 0
                        ? AccountantThemeConfig.primaryGreen
                        : AccountantThemeConfig.dangerRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.all(AccountantThemeConfig.smallPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AccountantThemeConfig.accentBlue.withOpacity(0.1),
                AccountantThemeConfig.accentBlue.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
            border: Border.all(color: AccountantThemeConfig.accentBlue.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'مبيعات: ${product.salesSummary.totalSold}',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AccountantThemeConfig.accentBlue,
                ),
              ),
              Text(
                _formatCurrency(product.salesSummary.totalRevenue),
                style: AccountantThemeConfig.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        children: [
          Container(
            margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
              child: _buildProductDetails(product),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetails(ProductMovementData product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Info
        _buildModernProductInfo(product),

        const SizedBox(height: AccountantThemeConfig.defaultPadding),

        // Sales Summary
        _buildModernSalesSummary(product),

        const SizedBox(height: AccountantThemeConfig.defaultPadding),

        // Sales Data Table
        if (product.salesData.isNotEmpty)
          _buildModernSalesTable(product)
        else
          _buildModernNoMovementMessage(),
      ],
    );
  }

  Widget _buildModernProductInfo(ProductMovementData product) {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.accentBlue.withOpacity(0.1),
            AccountantThemeConfig.accentBlue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
        border: Border.all(color: AccountantThemeConfig.accentBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معلومات المنتج',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: AccountantThemeConfig.accentBlue,
            ),
          ),
          const SizedBox(height: AccountantThemeConfig.smallPadding),
          Row(
            children: [
              Expanded(
                child: Text(
                  'الاسم: ${product.name}',
                  style: AccountantThemeConfig.bodyMedium,
                ),
              ),
            ],
          ),
          if (product.sku.isNotEmpty) ...[
            const SizedBox(height: AccountantThemeConfig.smallPadding),
            Text(
              'الكود: ${product.sku}',
              style: AccountantThemeConfig.bodyMedium,
            ),
          ],
          const SizedBox(height: AccountantThemeConfig.smallPadding),
          Text(
            'المخزون الحالي: ${product.currentStock}',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: product.currentStock > 0
                  ? AccountantThemeConfig.primaryGreen
                  : AccountantThemeConfig.dangerRed,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSalesSummary(ProductMovementData product) {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.primaryGreen.withOpacity(0.1),
            AccountantThemeConfig.primaryGreen.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
        border: Border.all(color: AccountantThemeConfig.primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص المبيعات',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: AccountantThemeConfig.primaryGreen,
            ),
          ),
          const SizedBox(height: AccountantThemeConfig.smallPadding),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إجمالي المبيعات',
                      style: AccountantThemeConfig.bodySmall,
                    ),
                    Text(
                      '${product.salesSummary.totalSold}',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: AccountantThemeConfig.accentBlue,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إجمالي الإيرادات',
                      style: AccountantThemeConfig.bodySmall,
                    ),
                    Text(
                      _formatCurrency(product.salesSummary.totalRevenue),
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo(ProductMovementData product, ThemeData theme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات المنتج',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (product.category.isNotEmpty)
              _buildInfoRow('التصنيف', product.category, theme),
            if (product.description.isNotEmpty)
              _buildInfoRow('الوصف', product.description, theme),
            _buildInfoRow('سعر الشراء', _formatCurrency(product.purchasePrice), theme),
            _buildInfoRow('سعر البيع', _formatCurrency(product.sellingPrice), theme),
            _buildInfoRow('المخزون الحالي', '${product.currentStock}', theme),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSummary(ProductMovementData product, ThemeData theme) {
    // حساب رصيد أول مدة (إجمالي المبيعات + المخزون الحالي)
    final openingBalance = product.salesSummary.totalSold + product.currentStock;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص المبيعات',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'إجمالي المبيعات',
                    '${product.salesSummary.totalSold}',
                    Icons.shopping_cart,
                    Colors.blue,
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'إجمالي الإيرادات',
                    _formatCurrency(product.salesSummary.totalRevenue),
                    Icons.attach_money,
                    Colors.green,
                    theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'إجمالي الربح',
                    _formatCurrency(product.salesSummary.totalProfit),
                    Icons.trending_up,
                    Colors.purple,
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'عدد العمليات',
                    '${product.salesSummary.salesCount}',
                    Icons.receipt,
                    Colors.orange,
                    theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItemWithTranslation(
                    'opening_balance',
                    'رصيد أول مدة',
                    '$openingBalance',
                    Icons.account_balance,
                    Colors.deepPurple,
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItemWithTranslation(
                    'current_stock',
                    'المخزون الحالي',
                    '${product.currentStock}',
                    Icons.inventory_2,
                    Colors.brown,
                    theme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItemWithTranslation(
    String translationKey,
    String fallbackLabel,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            fallbackLabel, // استخدام النص العربي مباشرة لأن التطبيق يستخدم العربية بشكل أساسي
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(ProductMovementData product, bool hasMovement) {
    final imageUrl = product.imageUrl.isNotEmpty
        ? 'https://samastock.pythonanywhere.com/static/uploads/${product.imageUrl}'
        : null;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasMovement ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: (imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'null' && Uri.tryParse(imageUrl) != null)
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackIcon(hasMovement);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                    ),
                  );
                },
              )
            : _buildFallbackIcon(hasMovement),
      ),
    );
  }

  Widget _buildFallbackIcon(bool hasMovement) {
    return Container(
      decoration: BoxDecoration(
        color: hasMovement
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        hasMovement ? Icons.trending_up : Icons.trending_flat,
        color: hasMovement ? Colors.green : Colors.orange,
        size: 24,
      ),
    );
  }

  Widget _buildSalesTable(ProductMovementData product, ThemeData theme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'تفاصيل عمليات البيع (${product.salesData.length} عملية)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingRowColor: WidgetStateProperty.all(
                theme.colorScheme.surface,
              ),
              columns: const [
                DataColumn(
                  label: Text(
                    '#',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'التاريخ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'رقم الفاتورة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'العميل',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'الكمية',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'سعر الوحدة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
                DataColumn(
                  label: Text(
                    'الإجمالي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
                DataColumn(
                  label: Text(
                    'الحالة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'المستخدم',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
              rows: product.salesData.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final sale = entry.value;
                final date = DateTime.tryParse(sale.date);

                return DataRow(
                  color: WidgetStateProperty.all(
                    index % 2 == 0
                        ? theme.colorScheme.surface.withOpacity(0.5)
                        : Colors.transparent,
                  ),
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$index',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(
                      date != null ? _dateFormat.format(date) : sale.date,
                      style: const TextStyle(fontSize: 11),
                    )),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sale.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        constraints: const BoxConstraints(minWidth: 120),
                        child: Text(
                          sale.customerName,
                          style: const TextStyle(fontSize: 11),
                          softWrap: true,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${sale.quantity}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(
                      _formatCurrency(sale.unitPrice),
                      style: const TextStyle(fontSize: 11),
                    )),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatCurrency(sale.totalAmount),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: sale.status == 'completed' ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sale.status == 'completed' ? 'مكتمل' :
                        sale.status == 'pending' ? 'معلق' : sale.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )),
                    DataCell(
                      Container(
                        constraints: const BoxConstraints(minWidth: 100),
                        child: Text(
                          sale.user,
                          style: const TextStyle(fontSize: 11),
                          softWrap: true,
                          maxLines: 2,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          // إضافة ملخص في النهاية
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إجمالي العمليات: ${product.salesData.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'إجمالي الكمية: ${product.salesSummary.totalSold}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                Text(
                  'إجمالي المبلغ: ${_formatCurrency(product.salesSummary.totalRevenue)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMovementMessage(ThemeData theme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.trending_flat,
                size: 48,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'لا يوجد حركة لهذا الصنف',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'لم يتم تسجيل أي عمليات بيع لهذا المنتج حتى الآن',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Missing methods implementation
  Widget _buildModernProductImage(ProductMovementData product, bool hasMovement) {
    final imageUrl = product.imageUrl.isNotEmpty && product.imageUrl != 'null'
        ? 'https://samastock.pythonanywhere.com/static/uploads/${product.imageUrl}'
        : null;

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasMovement
              ? [AccountantThemeConfig.primaryGreen.withOpacity(0.2), AccountantThemeConfig.primaryGreen.withOpacity(0.1)]
              : [AccountantThemeConfig.warningOrange.withOpacity(0.2), AccountantThemeConfig.warningOrange.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
        border: Border.all(
          color: hasMovement ? AccountantThemeConfig.primaryGreen.withOpacity(0.3) : AccountantThemeConfig.warningOrange.withOpacity(0.3),
        ),
        boxShadow: AccountantThemeConfig.glowShadows(
          hasMovement ? AccountantThemeConfig.primaryGreen : AccountantThemeConfig.warningOrange,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(hasMovement),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildImagePlaceholder(hasMovement);
                },
              )
            : _buildImagePlaceholder(hasMovement),
      ),
    );
  }

  Widget _buildImagePlaceholder(bool hasMovement) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasMovement
              ? [AccountantThemeConfig.primaryGreen.withOpacity(0.1), AccountantThemeConfig.primaryGreen.withOpacity(0.05)]
              : [AccountantThemeConfig.warningOrange.withOpacity(0.1), AccountantThemeConfig.warningOrange.withOpacity(0.05)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: hasMovement ? AccountantThemeConfig.primaryGreen : AccountantThemeConfig.warningOrange,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildModernSalesTable(ProductMovementData product) {
    if (product.salesData.isEmpty) {
      return _buildModernNoMovementMessage();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.accentBlue.withOpacity(0.1),
            AccountantThemeConfig.accentBlue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
        border: Border.all(color: AccountantThemeConfig.accentBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.accentBlue.withOpacity(0.2),
                  AccountantThemeConfig.accentBlue.withOpacity(0.1),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AccountantThemeConfig.smallBorderRadius),
                topRight: Radius.circular(AccountantThemeConfig.smallBorderRadius),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.table_chart_rounded,
                  color: AccountantThemeConfig.accentBlue,
                  size: 20,
                ),
                const SizedBox(width: AccountantThemeConfig.smallPadding),
                Text(
                  'تفاصيل المبيعات',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: AccountantThemeConfig.accentBlue,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AccountantThemeConfig.smallPadding,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.blueGradient,
                    borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
                  ),
                  child: Text(
                    '${product.salesData.length} عملية',
                    style: AccountantThemeConfig.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Content
          Padding(
            padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AccountantThemeConfig.smallPadding,
                    horizontal: AccountantThemeConfig.defaultPadding,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'العميل',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'الكمية',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'السعر',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'الإجمالي',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AccountantThemeConfig.smallPadding),

                // Table Rows - Display ALL sales transactions without limit
                ...product.salesData.map((sale) => Container(
                  margin: const EdgeInsets.only(bottom: AccountantThemeConfig.smallPadding),
                  padding: const EdgeInsets.symmetric(
                    vertical: AccountantThemeConfig.smallPadding,
                    horizontal: AccountantThemeConfig.defaultPadding,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          sale.customerName,
                          style: AccountantThemeConfig.bodySmall,
                          softWrap: true,
                          maxLines: 2,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${sale.quantity}',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: AccountantThemeConfig.accentBlue,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          softWrap: true,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          _formatCurrency(sale.unitPrice),
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: AccountantThemeConfig.warningOrange,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          softWrap: true,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          _formatCurrency(sale.totalAmount),
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: AccountantThemeConfig.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                )).toList(),

                // Display total transactions count for better user awareness
                if (product.salesData.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AccountantThemeConfig.smallPadding,
                    ),
                    child: Text(
                      'إجمالي العمليات: ${product.salesData.length}',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernNoMovementMessage() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.warningOrange.withOpacity(0.1),
            AccountantThemeConfig.warningOrange.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
        border: Border.all(color: AccountantThemeConfig.warningOrange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.warningOrange.withOpacity(0.2),
                  AccountantThemeConfig.warningOrange.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange),
            ),
            child: Icon(
              Icons.trending_flat_rounded,
              color: AccountantThemeConfig.warningOrange,
              size: 32,
            ),
          ),
          const SizedBox(height: AccountantThemeConfig.defaultPadding),
          Text(
            'لا يوجد حركة مبيعات',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: AccountantThemeConfig.warningOrange,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AccountantThemeConfig.smallPadding),
          Text(
            'لم يتم بيع أي كمية من هذا المنتج خلال الفترة المحددة',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Sticky Header Delegate for CustomScrollView
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}