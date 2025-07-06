import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smartbiztracker_new/models/product_movement_model.dart';
import 'package:smartbiztracker_new/services/product_movement_service.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/accountant/modern_widgets.dart';
import 'all_products_movement_screen.dart';

class ProductMovementScreen extends StatefulWidget {
  const ProductMovementScreen({super.key});

  @override
  State<ProductMovementScreen> createState() => _ProductMovementScreenState();
}

class _ProductMovementScreenState extends State<ProductMovementScreen> {
  final ProductMovementService _movementService = ProductMovementService();
  final TextEditingController _searchController = TextEditingController();

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  List<ProductSearchModel> _searchResults = [];
  ProductMovementModel? _selectedProductMovement;
  bool _isSearching = false;
  bool _isLoadingMovement = false;
  String _searchQuery = '';
  String? _error;

  // Filter and sort options
  String _selectedSort = 'date_desc'; // date_desc, date_asc, quantity_desc, amount_desc

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text != _searchQuery) {
      setState(() {
        _searchQuery = _searchController.text;
      });
      _searchProducts();
    }
  }

  Future<void> _searchProducts() async {
    if (_searchQuery.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await _movementService.searchProducts(_searchQuery);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  Future<void> _loadProductMovement(ProductSearchModel product) async {
    setState(() {
      _isLoadingMovement = true;
      _error = null;
      _selectedProductMovement = null;
    });

    try {
      final movement = await _movementService.getProductMovementById(product.id);
      setState(() {
        _selectedProductMovement = movement;
        _isLoadingMovement = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingMovement = false;
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedProductMovement = null;
      _searchController.clear();
      _searchResults = [];
      _searchQuery = '';
    });
  }

  List<ProductSaleModel> _getFilteredSales() {
    if (_selectedProductMovement == null) return [];

    final sales = _selectedProductMovement!.salesData;

    // Apply sorting
    switch (_selectedSort) {
      case 'date_asc':
        sales.sort((a, b) => a.saleDate.compareTo(b.saleDate));
        break;
      case 'quantity_desc':
        sales.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case 'amount_desc':
        sales.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        break;
      case 'date_desc':
      default:
        sales.sort((a, b) => b.saleDate.compareTo(a.saleDate));
        break;
    }

    return sales;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'حركة صنف شاملة',
            style: AccountantThemeConfig.headlineSmall,
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.blueGradient,
            ),
          ),
          actions: [
            if (_selectedProductMovement != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: _clearSelection,
                  tooltip: 'مسح التحديد',
                ),
              ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: Column(
            children: [
              // Modern Search Section
              Container(
                padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.cardGradient,
                  border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                  boxShadow: AccountantThemeConfig.cardShadows,
                ),
                child: Column(
                  children: [
                    // Modern Search Bar
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.1),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                        border: Border.all(color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: AccountantThemeConfig.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن منتج بالاسم أو الكود...',
                          hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AccountantThemeConfig.accentBlue,
                          ),
                          suffixIcon: _isSearching
                              ? Container(
                                  width: 20,
                                  height: 20,
                                  padding: const EdgeInsets.all(12),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AccountantThemeConfig.primaryGreen,
                                    ),
                                  ),
                                )
                              : _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        color: AccountantThemeConfig.neutralColor,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                  : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AccountantThemeConfig.defaultPadding,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),

                    // Modern Search Results
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: AccountantThemeConfig.defaultPadding),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.cardGradient,
                          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final product = _searchResults[index];
                            return AnimatedContainer(
                              duration: Duration(milliseconds: 800 + (index * 100)),
                              curve: Curves.easeInOut,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                                          AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_rounded,
                                      color: AccountantThemeConfig.accentBlue,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    product.name,
                                    style: AccountantThemeConfig.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (product.sku != null)
                                        Text(
                                          'الكود: ${product.sku}',
                                          style: AccountantThemeConfig.bodySmall,
                                        ),
                                      Text(
                                        'المخزون: ${product.currentStock} | المبيعات: ${product.totalSold}',
                                        style: AccountantThemeConfig.bodySmall.copyWith(
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                                          AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      AccountantThemeConfig.formatCurrency(product.totalRevenue),
                                      style: AccountantThemeConfig.labelMedium.copyWith(
                                        color: AccountantThemeConfig.primaryGreen,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  onTap: () => _loadProductMovement(product),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Content Section
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_isLoadingMovement) {
      return ModernAccountantWidgets.buildModernLoader(
        message: 'جاري تحميل بيانات المنتج...',
        color: AccountantThemeConfig.primaryGreen,
      );
    }

    if (_selectedProductMovement == null) {
      return _buildEmptyState();
    }

    return _buildProductMovementData();
  }

  Widget _buildErrorWidget() {
    return ModernAccountantWidgets.buildEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'حدث خطأ',
      subtitle: _error!,
      actionText: 'إعادة المحاولة',
      onActionPressed: () {
        setState(() {
          _error = null;
        });
      },
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Expanded(
          child: ModernAccountantWidgets.buildEmptyState(
            icon: Icons.search_rounded,
            title: 'ابحث عن منتج',
            subtitle: 'ابحث عن منتج لعرض حركة المبيعات والمخزون',
          ),
        ),

        // Modern Navigation Button
        Container(
          padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
          margin: const EdgeInsets.symmetric(horizontal: AccountantThemeConfig.largePadding),
          child: _buildModernNavigationButton(),
        ),

        const SizedBox(height: AccountantThemeConfig.defaultPadding),

        Text(
          'أو ابحث عن منتج محدد أعلاه',
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AccountantThemeConfig.largePadding),
      ],
    );
  }

  Widget _buildModernNavigationButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.blueGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AllProductsMovementScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AccountantThemeConfig.defaultPadding,
              horizontal: AccountantThemeConfig.largePadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.view_list_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: AccountantThemeConfig.defaultPadding),
                Text(
                  'عرض حركة جميع المنتجات',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AccountantThemeConfig.smallPadding),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductMovementData() {
    final product = _selectedProductMovement!.product;
    final statistics = _selectedProductMovement!.statistics;
    final sales = _getFilteredSales();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern Product Info Card
          _buildModernProductInfoCard(product, statistics),

          const SizedBox(height: AccountantThemeConfig.defaultPadding),

          // Modern Statistics Cards
          _buildModernStatisticsCards(statistics),

          const SizedBox(height: AccountantThemeConfig.defaultPadding),

          // Modern Filter and Sort Controls
          _buildModernFilterControls(),

          const SizedBox(height: AccountantThemeConfig.defaultPadding),

          // Modern Sales Data Table
          _buildModernSalesTable(sales),
        ],
      ),
    );
  }

  Widget _buildModernProductInfoCard(ProductMovementProductModel product, ProductMovementStatisticsModel statistics) {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern Product Header
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                  gradient: LinearGradient(
                    colors: [
                      AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                      AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
                    ],
                  ),
                  border: Border.all(
                    color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: (product.imageUrl != null && product.imageUrl!.isNotEmpty && product.imageUrl != 'null' && Uri.tryParse(product.imageUrl!) != null)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.inventory_2_rounded,
                              color: AccountantThemeConfig.accentBlue,
                              size: 35,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_rounded,
                        color: AccountantThemeConfig.accentBlue,
                        size: 35,
                      ),
              ),
              const SizedBox(width: AccountantThemeConfig.defaultPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AccountantThemeConfig.headlineSmall,
                    ),
                    if (product.sku != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'الكود: ${product.sku}',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    if (product.category != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                              AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                          border: Border.all(
                            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          product.category!,
                          style: AccountantThemeConfig.labelSmall.copyWith(
                            color: AccountantThemeConfig.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Modern Profit Margin Display
          if (statistics.profitMargin > 0) ...[
            const SizedBox(height: AccountantThemeConfig.defaultPadding),
            Container(
              padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                    AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                border: Border.all(
                  color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    color: AccountantThemeConfig.primaryGreen,
                    size: 24,
                  ),
                  const SizedBox(width: AccountantThemeConfig.defaultPadding),
                  Expanded(
                    child: Text(
                      'هامش الربح: ${statistics.profitMargin.toStringAsFixed(1)}%',
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    'ربح الوحدة: ${AccountantThemeConfig.formatCurrency(statistics.profitPerUnit)}',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: AccountantThemeConfig.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernStatisticsCards(ProductMovementStatisticsModel statistics) {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernAccountantWidgets.buildSectionHeader(
            title: 'إحصائيات المنتج',
            icon: Icons.analytics_rounded,
            iconColor: AccountantThemeConfig.accentBlue,
          ),

          const SizedBox(height: AccountantThemeConfig.defaultPadding),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            crossAxisSpacing: AccountantThemeConfig.defaultPadding,
            mainAxisSpacing: AccountantThemeConfig.defaultPadding,
            children: [
              ModernAccountantWidgets.buildStatusCard(
                title: 'إجمالي المبيعات',
                value: '${statistics.totalSoldQuantity}',
                icon: Icons.shopping_cart_rounded,
                color: AccountantThemeConfig.accentBlue,
              ),
              ModernAccountantWidgets.buildStatusCard(
                title: 'إجمالي الإيرادات',
                value: AccountantThemeConfig.formatCurrency(statistics.totalRevenue),
                icon: Icons.attach_money_rounded,
                color: AccountantThemeConfig.primaryGreen,
              ),
              ModernAccountantWidgets.buildStatusCard(
                title: 'المخزون الحالي',
                value: '${statistics.currentStock}',
                icon: Icons.inventory_rounded,
                color: AccountantThemeConfig.warningOrange,
              ),
              ModernAccountantWidgets.buildStatusCard(
                title: 'عدد العمليات',
                value: '${statistics.totalSalesCount}',
                icon: Icons.receipt_rounded,
                color: AccountantThemeConfig.neutralColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernFilterControls() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernAccountantWidgets.buildSectionHeader(
            title: 'خيارات العرض والترتيب',
            icon: Icons.filter_list_rounded,
            iconColor: AccountantThemeConfig.warningOrange,
          ),

          const SizedBox(height: AccountantThemeConfig.defaultPadding),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ترتيب حسب:',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: AccountantThemeConfig.smallPadding),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                  border: Border.all(color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedSort,
                  style: AccountantThemeConfig.bodyMedium,
                  dropdownColor: AccountantThemeConfig.cardBackground1,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AccountantThemeConfig.defaultPadding,
                      vertical: 12,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'date_desc',
                      child: Text(
                        'التاريخ (الأحدث أولاً)',
                        style: AccountantThemeConfig.bodyMedium,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'date_asc',
                      child: Text(
                        'التاريخ (الأقدم أولاً)',
                        style: AccountantThemeConfig.bodyMedium,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'quantity_desc',
                      child: Text(
                        'الكمية (الأكبر أولاً)',
                        style: AccountantThemeConfig.bodyMedium,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'amount_desc',
                      child: Text(
                        'المبلغ (الأكبر أولاً)',
                        style: AccountantThemeConfig.bodyMedium,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSort = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernSalesTable(List<ProductSaleModel> sales) {
    if (sales.isEmpty) {
      final product = _selectedProductMovement?.product;
      return Container(
        padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Column(
          children: [
            ModernAccountantWidgets.buildEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'لا يوجد حركة مبيعات لهذا الصنف',
              subtitle: 'لم يتم تسجيل أي مبيعات لهذا المنتج في النظام',
            ),

            if (product != null) ...[
              const SizedBox(height: AccountantThemeConfig.defaultPadding),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AccountantThemeConfig.defaultPadding,
                  vertical: AccountantThemeConfig.smallPadding,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                      AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'الرصيد الحالي: ${product.currentStock} قطعة',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AccountantThemeConfig.accentBlue,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
            child: ModernAccountantWidgets.buildSectionHeader(
              title: 'سجل المبيعات (${sales.length} عملية)',
              icon: Icons.table_chart_rounded,
              iconColor: AccountantThemeConfig.primaryGreen,
            ),
          ),

          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                  Colors.transparent,
                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
          // Modern Table Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AccountantThemeConfig.defaultPadding,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                  AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'العميل',
                    style: AccountantThemeConfig.labelLarge.copyWith(
                      color: AccountantThemeConfig.accentBlue,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'التاريخ',
                    style: AccountantThemeConfig.labelLarge.copyWith(
                      color: AccountantThemeConfig.accentBlue,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'الكمية',
                    style: AccountantThemeConfig.labelLarge.copyWith(
                      color: AccountantThemeConfig.accentBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'السعر',
                    style: AccountantThemeConfig.labelLarge.copyWith(
                      color: AccountantThemeConfig.accentBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'الإجمالي',
                    style: AccountantThemeConfig.labelLarge.copyWith(
                      color: AccountantThemeConfig.accentBlue,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          // Modern Table Rows
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sales.length,
            itemBuilder: (context, index) {
              final sale = sales[index];
              return AnimatedContainer(
                duration: Duration(milliseconds: 800 + (index * 50)),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(
                  horizontal: AccountantThemeConfig.smallPadding,
                  vertical: 2,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AccountantThemeConfig.defaultPadding,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    // Customer Info
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.customerName,
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (sale.customerPhone != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              sale.customerPhone!,
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Date
                    Expanded(
                      flex: 2,
                      child: Text(
                        _dateFormat.format(sale.saleDate),
                        style: AccountantThemeConfig.bodySmall,
                      ),
                    ),
                    // Quantity
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                              AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${sale.quantity}',
                          style: AccountantThemeConfig.labelMedium.copyWith(
                            color: AccountantThemeConfig.accentBlue,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    // Unit Price
                    Expanded(
                      flex: 2,
                      child: Text(
                        AccountantThemeConfig.formatCurrency(sale.unitPrice),
                        style: AccountantThemeConfig.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Total Amount
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                              AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AccountantThemeConfig.formatCurrency(sale.totalAmount),
                          style: AccountantThemeConfig.labelMedium.copyWith(
                            color: AccountantThemeConfig.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Modern Summary Footer
          Container(
            padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                bottomRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
              ),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  'إجمالي العمليات',
                  '${sales.length}',
                  Icons.receipt_rounded,
                  AccountantThemeConfig.accentBlue,
                ),
                _buildSummaryItem(
                  'إجمالي الكمية',
                  '${sales.fold<int>(0, (sum, sale) => sum + sale.quantity)}',
                  Icons.inventory_rounded,
                  AccountantThemeConfig.warningOrange,
                ),
                _buildSummaryItem(
                  'إجمالي المبلغ',
                  AccountantThemeConfig.formatCurrency(
                    sales.fold<double>(0, (sum, sale) => sum + sale.totalAmount),
                  ),
                  Icons.attach_money_rounded,
                  AccountantThemeConfig.primaryGreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: AccountantThemeConfig.smallPadding),
        Text(
          value,
          style: AccountantThemeConfig.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
