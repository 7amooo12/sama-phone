import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/models/product_movement_model.dart';
import 'package:smartbiztracker_new/services/product_movement_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// صفحة حركة صنف متطورة واحترافية مع تصميم عصري
class AdvancedProductMovementScreen extends StatefulWidget {
  const AdvancedProductMovementScreen({super.key});

  @override
  State<AdvancedProductMovementScreen> createState() => _AdvancedProductMovementScreenState();
}

class _AdvancedProductMovementScreenState extends State<AdvancedProductMovementScreen>
    with TickerProviderStateMixin {
  final ProductMovementService _movementService = ProductMovementService();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'ج.م ',
    decimalDigits: 2,
    locale: 'ar_EG',
  );
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Data
  List<ProductSearchModel> _searchResults = [];
  ProductMovementModel? _selectedProductMovement;
  bool _isSearching = false;
  bool _isLoadingMovement = false;
  String _searchQuery = '';
  String? _error;

  // Filter and sort options
  final String _selectedFilter = 'all';
  final String _selectedSort = 'date_desc';
  final String _selectedPeriod = '30'; // days
  final int _selectedChartIndex = 0;

  // Colors for professional design
  final List<Color> _gradientColors = [
    const Color(0xFF667eea),
    const Color(0xFF764ba2),
    const Color(0xFF6B73FF),
    const Color(0xFF9068BE),
  ];

  final List<Color> _chartColors = [
    const Color(0xFF4CAF50), // Green
    const Color(0xFF2196F3), // Blue
    const Color(0xFFFF9800), // Orange
    const Color(0xFF9C27B0), // Purple
    const Color(0xFFF44336), // Red
    const Color(0xFF00BCD4), // Cyan
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _searchController.addListener(_onSearchChanged);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
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
      AppLogger.info('🔍 البحث عن المنتجات: $_searchQuery');

      final results = await _movementService.searchProducts(_searchQuery);

      AppLogger.info('✅ تم العثور على ${results.length} منتج');

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      // طباعة تفاصيل النتائج للتشخيص
      if (results.isNotEmpty) {
        AppLogger.info('🔍 أول نتيجة: ${results.first.name} - المخزون: ${results.first.currentStock}');
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن المنتجات: $e');

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
      AppLogger.info('🔄 بدء تحميل بيانات حركة المنتج: ${product.name} (ID: ${product.id})');

      final movement = await _movementService.getProductMovementById(product.id);

      AppLogger.info('✅ تم تحميل بيانات حركة المنتج بنجاح');
      AppLogger.info('📊 عدد المبيعات: ${movement.salesData.length}');
      AppLogger.info('📈 إجمالي المبيعات: ${movement.statistics.totalSoldQuantity}');
      AppLogger.info('💰 إجمالي الإيرادات: ${movement.statistics.totalRevenue}');

      setState(() {
        _selectedProductMovement = movement;
        _isLoadingMovement = false;
      });

      _scaleController.reset();
      _scaleController.forward();

      // طباعة تفاصيل البيانات للتشخيص
      if (movement.salesData.isNotEmpty) {
        AppLogger.info('🛒 أول عملية بيع: ${movement.salesData.first.customerName} - ${movement.salesData.first.totalAmount} ج.م');
        AppLogger.info('📅 تاريخ أول عملية بيع: ${movement.salesData.first.saleDate}');
      } else {
        AppLogger.warning('⚠️ لا توجد بيانات مبيعات لهذا المنتج');
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل بيانات حركة المنتج: $e');

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

  /// Show all products dialog for advanced analysis
  Future<void> _showAllProductsDialog() async {
    try {
      setState(() {
        _isSearching = true;
      });

      AppLogger.info('🔄 تحميل جميع المنتجات للتحليل المتقدم');

      // Get all products using the dedicated endpoint
      final allProducts = await _movementService.getAllProductsMovementSafe(includeAll: true);

      setState(() {
        _isSearching = false;
      });

      AppLogger.info('✅ تم تحميل ${allProducts.length} منتج للتحليل');

      if (allProducts.isEmpty) {
        AppLogger.warning('⚠️ لا توجد منتجات متاحة للتحليل');
        _showNoProductsMessage();
        return;
      }

      // Check if widget is still mounted before using context
      if (!mounted) return;

      // Show products dialog
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildProductsBottomSheet(allProducts),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل المنتجات للتحليل: $e');

      setState(() {
        _isSearching = false;
      });
      _showErrorMessage('فشل في تحميل المنتجات: $e');
    }
  }

  /// Show no products message
  void _showNoProductsMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 12),
            Text('لا توجد منتجات متاحة للتحليل'),
          ],
        ),
        backgroundColor: Colors.orange[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Show error message
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Build products bottom sheet
  Widget _buildProductsBottomSheet(List<ProductSearchModel> products) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _gradientColors),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تحليل متقدم للمنتجات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'اختر منتج لعرض تحليل شامل',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
          ),

          // Products count
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _gradientColors[0].withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gradientColors[0].withValues(alpha: 0.3)),
            ),
            child: Text(
              'إجمالي المنتجات: ${products.length}',
              style: TextStyle(
                color: _gradientColors[0],
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Products list
          Expanded(
            child: AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _buildProductListItem(products[index], index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build product list item for bottom sheet
  Widget _buildProductListItem(ProductSearchModel product, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[850]!, Colors.grey[900]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _chartColors[index % _chartColors.length].withValues(alpha: 0.3),
                _chartColors[index % _chartColors.length].withValues(alpha: 0.1)
              ],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            Icons.inventory_2_rounded,
            color: _chartColors[index % _chartColors.length],
            size: 28,
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (product.sku != null)
              Text(
                'الكود: ${product.sku}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.inventory_rounded, size: 14, color: Colors.green[400]),
                const SizedBox(width: 4),
                Text(
                  'المخزون: ${product.currentStock}',
                  style: TextStyle(color: Colors.green[400], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.trending_up_rounded, size: 14, color: Colors.blue[400]),
                const SizedBox(width: 4),
                Text(
                  'المبيعات: ${product.totalSold}',
                  style: TextStyle(color: Colors.blue[400], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[600]!, Colors.green[700]!],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                _currencyFormat.format(product.totalRevenue),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: _chartColors[index % _chartColors.length],
              size: 16,
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          _loadProductMovement(product);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                _buildSearchSection(),
                if (_selectedProductMovement != null) ...[
                  _buildProductHeader(),
                  _buildStatisticsCards(),
                  _buildChartsSection(),
                  _buildAnalyticsSection(),
                  _buildTransactionsSection(),
                ] else ...[
                  _buildEmptyState(),
                ],
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradientColors,
          ),
        ),
        child: FlexibleSpaceBar(
          title: const Text(
            'حركة صنف شاملة',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          background: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _gradientColors,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.analytics_rounded,
                size: 60,
                color: Colors.white24,
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (_selectedProductMovement != null)
          Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.clear_rounded, color: Colors.white),
              onPressed: _clearSelection,
              tooltip: 'مسح التحديد',
            ),
          ),
      ],
    );
  }

  Widget _buildSearchSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[800]!, Colors.grey[850]!],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج بالاسم أو الكود...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.search_rounded, color: _gradientColors[0]),
                  suffixIcon: _isSearching
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(_gradientColors[0]),
                            ),
                          ),
                        )
                      : _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.white54),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),

            // Search Results
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: AnimationLimiter(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _buildSearchResultItem(_searchResults[index], index),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(ProductSearchModel product, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[850]!, Colors.grey[900]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_chartColors[index % _chartColors.length].withValues(alpha: 0.3),
                      _chartColors[index % _chartColors.length].withValues(alpha: 0.1)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.inventory_2_rounded,
            color: _chartColors[index % _chartColors.length],
            size: 24,
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.sku != null)
              Text(
                'الكود: ${product.sku}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.inventory_rounded, size: 14, color: Colors.green[400]),
                const SizedBox(width: 4),
                Text(
                  'المخزون: ${product.currentStock}',
                  style: TextStyle(color: Colors.green[400], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.trending_up_rounded, size: 14, color: Colors.blue[400]),
                const SizedBox(width: 4),
                Text(
                  'المبيعات: ${product.totalSold}',
                  style: TextStyle(color: Colors.blue[400], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[600]!, Colors.green[700]!],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _currencyFormat.format(product.totalRevenue),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        onTap: () => _loadProductMovement(product),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_gradientColors[0].withValues(alpha: 0.3), _gradientColors[1].withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 60,
                  color: _gradientColors[0],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ابحث عن منتج',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'ابحث عن منتج لعرض تحليل شامل لحركة المبيعات والمخزون',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _isSearching ? null : _showAllProductsDialog,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isSearching
                          ? [Colors.grey[600]!, Colors.grey[700]!]
                          : _gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: (_isSearching ? Colors.grey[600]! : _gradientColors[0]).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isSearching ? 'جاري التحميل...' : 'تحليل متقدم للمنتجات',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (!_isSearching) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                      ],
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

  Widget _buildProductHeader() {
    final product = _selectedProductMovement!.product;

    return SliverToBoxAdapter(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.grey[900]!, Colors.grey[850]!],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              // Product Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_gradientColors[0].withOpacity(0.3), _gradientColors[1].withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gradientColors[0].withOpacity(0.3)),
                ),
                child: _buildProductImage(ProductSearchModel(
                  id: product.id,
                  name: product.name,
                  imageUrl: product.imageUrl,
                  currentStock: product.currentStock,
                  totalSold: 0, // Default value since ProductMovementProductModel doesn't have this
                  totalRevenue: 0.0, // Default value since ProductMovementProductModel doesn't have this
                  category: product.category,
                  sellingPrice: product.sellingPrice,
                )),
              ),
              const SizedBox(width: 20),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (product.description != null && product.description!.isNotEmpty)
                      Text(
                        product.description!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _gradientColors[0].withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: _gradientColors[0].withOpacity(0.3)),
                          ),
                          child: Text(
                            'كود: ${product.sku ?? 'غير محدد'}',
                            style: TextStyle(
                              color: _gradientColors[0],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Text(
                            _currencyFormat.format(product.sellingPrice ?? 0),
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildStatisticsCards() {
    final statistics = _selectedProductMovement!.statistics;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimationLimiter(
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              AnimationConfiguration.staggeredGrid(
                position: 0,
                duration: const Duration(milliseconds: 375),
                columnCount: 2,
                child: ScaleAnimation(
                  child: FadeInAnimation(
                    child: _buildStatCard(
                      'إجمالي المبيعات',
                      '${statistics.totalSoldQuantity}',
                      Icons.shopping_cart_rounded,
                      _chartColors[0],
                      'قطعة',
                    ),
                  ),
                ),
              ),
              AnimationConfiguration.staggeredGrid(
                position: 1,
                duration: const Duration(milliseconds: 375),
                columnCount: 2,
                child: ScaleAnimation(
                  child: FadeInAnimation(
                    child: _buildStatCard(
                      'إجمالي الإيرادات',
                      _currencyFormat.format(statistics.totalRevenue),
                      Icons.attach_money_rounded,
                      _chartColors[1],
                      '',
                    ),
                  ),
                ),
              ),
              AnimationConfiguration.staggeredGrid(
                position: 2,
                duration: const Duration(milliseconds: 375),
                columnCount: 2,
                child: ScaleAnimation(
                  child: FadeInAnimation(
                    child: _buildStatCard(
                      'المخزون الحالي',
                      '${statistics.currentStock}',
                      Icons.inventory_rounded,
                      _chartColors[2],
                      'قطعة',
                    ),
                  ),
                ),
              ),
              AnimationConfiguration.staggeredGrid(
                position: 3,
                duration: const Duration(milliseconds: 375),
                columnCount: 2,
                child: ScaleAnimation(
                  child: FadeInAnimation(
                    child: _buildStatCard(
                      'هامش الربح',
                      '${statistics.profitMargin.toStringAsFixed(1)}%',
                      Icons.trending_up_rounded,
                      _chartColors[3],
                      '',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String unit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[900]!, Colors.grey[850]!],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Icon(Icons.trending_up_rounded, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    final salesData = _selectedProductMovement!.salesData;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[900]!, Colors.grey[850]!],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chart Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _gradientColors),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'تحليل المبيعات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _gradientColors[0].withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    'آخر 30 يوم',
                    style: TextStyle(
                      color: _gradientColors[0],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Sales Chart
            if (salesData.isNotEmpty) ...[
              SizedBox(
                height: 250,
                child: LineChart(
                  _buildSalesLineChart(salesData),
                ),
              ),
              const SizedBox(height: 16),

              // إحصائيات سريعة
              Row(
                children: [
                  Expanded(
                    child: _buildQuickStatCard(
                      'متوسط المبيعات اليومية',
                      '${(_selectedProductMovement!.statistics.totalRevenue / (salesData.isNotEmpty ? salesData.length : 1)).toStringAsFixed(0)} ج.م',
                      Icons.trending_up,
                      _chartColors[0],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickStatCard(
                      'أعلى مبيعات يومية',
                      '${_getMaxDailySales(salesData).toStringAsFixed(0)} ج.م',
                      Icons.star,
                      _chartColors[1],
                    ),
                  ),
                ],
              ),
            ] else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.show_chart_rounded,
                        size: 48,
                        color: Colors.white24,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'لا توجد بيانات مبيعات',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'قم بإضافة مبيعات لهذا المنتج لعرض الرسوم البيانية',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildSalesLineChart(List<ProductSaleModel> salesData) {
    // Group sales by date and calculate daily totals
    final Map<DateTime, double> dailySales = {};
    final Map<DateTime, int> dailyQuantity = {};

    for (final sale in salesData) {
      final date = DateTime(sale.saleDate.year, sale.saleDate.month, sale.saleDate.day);
      dailySales[date] = (dailySales[date] ?? 0) + sale.totalAmount;
      dailyQuantity[date] = (dailyQuantity[date] ?? 0) + sale.quantity;
    }

    final sortedDates = dailySales.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailySales[sortedDates[i]]!));
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: Colors.white10,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (double value, TitleMeta meta) {
              if (value.toInt() >= 0 && value.toInt() < sortedDates.length) {
                final date = sortedDates[value.toInt()];
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    '${date.day}/${date.month}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (double value, TitleMeta meta) {
              return Text(
                '${value.toInt()}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              );
            },
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.white10),
      ),
      minX: 0,
      maxX: spots.isNotEmpty ? spots.length.toDouble() - 1 : 0,
      minY: 0,
      maxY: spots.isNotEmpty ? spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2 : 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: LinearGradient(colors: _gradientColors),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 6,
                color: _gradientColors[0],
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: _gradientColors.map((color) => color.withOpacity(0.3)).toList(),
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection() {
    final statistics = _selectedProductMovement!.statistics;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[900]!, Colors.grey[850]!],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Analytics Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _gradientColors),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'تحليل الأداء المالي',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Performance Metrics
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceMetric(
                    'متوسط سعر البيع',
                    _currencyFormat.format(statistics.averageSalePrice),
                    Icons.price_change_rounded,
                    _chartColors[0],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPerformanceMetric(
                    'ربح الوحدة',
                    _currencyFormat.format(statistics.profitPerUnit),
                    Icons.monetization_on_rounded,
                    _chartColors[1],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceMetric(
                    'إجمالي الربح',
                    _currencyFormat.format(statistics.totalProfit),
                    Icons.trending_up_rounded,
                    _chartColors[2],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPerformanceMetric(
                    'عدد المعاملات',
                    '${statistics.totalSalesCount}',
                    Icons.receipt_long_rounded,
                    _chartColors[3],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsSection() {
    final salesData = _selectedProductMovement!.salesData;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[900]!, Colors.grey[850]!],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transactions Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _gradientColors),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'سجل المعاملات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _gradientColors[0].withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    '${salesData.length} معاملة',
                    style: TextStyle(
                      color: _gradientColors[0],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Transactions List - عرض كل المعاملات المتاحة
            if (salesData.isNotEmpty)
              AnimationLimiter(
                child: Column(
                  children: salesData.map((sale) {
                    final index = salesData.indexOf(sale);
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: _buildTransactionItem(sale, index),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: Colors.white24,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'لا توجد معاملات',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // إضافة معلومات إجمالية عن المعاملات
            if (salesData.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${salesData.length}',
                          style: TextStyle(
                            color: _gradientColors[0],
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'إجمالي المعاملات',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white10,
                    ),
                    Column(
                      children: [
                        Text(
                          '${salesData.fold(0, (sum, sale) => sum + sale.quantity)}',
                          style: TextStyle(
                            color: _gradientColors[1],
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'إجمالي الكمية',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white10,
                    ),
                    Column(
                      children: [
                        Text(
                          '${salesData.fold(0.0, (sum, sale) => sum + sale.totalAmount).toStringAsFixed(0)} ج.م',
                          style: TextStyle(
                            color: _gradientColors[2],
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'إجمالي القيمة',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  Widget _buildTransactionItem(ProductSaleModel sale, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _chartColors[index % _chartColors.length].withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Transaction Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _chartColors[index % _chartColors.length].withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.shopping_cart_rounded,
              color: _chartColors[index % _chartColors.length],
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'العميل: ${sale.customerName ?? 'غير محدد'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _dateFormat.format(sale.saleDate),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'الكمية: ${sale.quantity}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _currencyFormat.format(sale.totalAmount),
                        style: const TextStyle(
                          color: Colors.green,
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
        ],
      ),
    );
  }

  /// بناء صورة المنتج مع معالجة محسنة للأخطاء
  Widget _buildProductImage(ProductSearchModel product) {
    // استخدام bestImageUrl إذا كان متاحاً، وإلا استخدام imageUrl
    String? imageUrl;

    // محاولة الحصول على أفضل URL للصورة
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty && product.imageUrl != 'null') {
      imageUrl = _fixImageUrl(product.imageUrl!);
    }

    AppLogger.info('عرض صورة المنتج: ${product.name}');
    AppLogger.info('URL الصورة: $imageUrl');

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_gradientColors[0].withOpacity(0.3), _gradientColors[1].withOpacity(0.1)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: _gradientColors[0],
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تحميل...',
                    style: TextStyle(
                      color: _gradientColors[0],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            AppLogger.error('خطأ في تحميل صورة المنتج ${product.name}: $error');
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_gradientColors[0].withOpacity(0.3), _gradientColors[1].withOpacity(0.1)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_rounded,
                      color: _gradientColors[0],
                      size: 32,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'لا توجد صورة',
                      style: TextStyle(
                        color: _gradientColors[0],
                        fontSize: 9,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_gradientColors[0].withOpacity(0.3), _gradientColors[1].withOpacity(0.1)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_rounded,
                color: _gradientColors[0],
                size: 40,
              ),
              const SizedBox(height: 4),
              Text(
                'منتج',
                style: TextStyle(
                  color: _gradientColors[0],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// إصلاح URL الصورة
  String _fixImageUrl(String url) {
    // إذا كان URL كاملاً، أرجعه كما هو
    if (url.startsWith('http')) {
      return url;
    }

    // إذا كان URL فارغاً أو يحتوي على placeholder، أرجع فارغ
    if (url.isEmpty || url.contains('placeholder') || url == 'null') {
      return '';
    }

    // استخدام القيم الافتراضية
    const defaultBaseUrl = 'https://samastock.pythonanywhere.com';
    const defaultUploadsPath = '/static/uploads/';

    // تنظيف URL من المسارات الغريبة
    String cleanUrl = url.trim();

    // إزالة file:// إذا وجد
    if (cleanUrl.startsWith('file://')) {
      cleanUrl = cleanUrl.substring(7);
    }

    // إذا كان يحتوي على اسم ملف فقط بدون مسار، أضف المسار الكامل
    if (!cleanUrl.contains('/')) {
      return '$defaultBaseUrl$defaultUploadsPath$cleanUrl';
    }

    // إذا كان URL نسبياً مع مسار
    if (!cleanUrl.startsWith('http')) {
      if (cleanUrl.startsWith('/')) {
        return '$defaultBaseUrl$cleanUrl';
      } else {
        return '$defaultBaseUrl/$cleanUrl';
      }
    }

    return cleanUrl;
  }

  /// حساب أعلى مبيعات يومية
  double _getMaxDailySales(List<ProductSaleModel> salesData) {
    if (salesData.isEmpty) return 0.0;

    final Map<DateTime, double> dailySales = {};

    for (final sale in salesData) {
      final date = DateTime(sale.saleDate.year, sale.saleDate.month, sale.saleDate.day);
      dailySales[date] = (dailySales[date] ?? 0) + sale.totalAmount;
    }

    return dailySales.values.isNotEmpty
        ? dailySales.values.reduce((a, b) => a > b ? a : b)
        : 0.0;
  }

  /// بناء بطاقة إحصائية سريعة
  Widget _buildQuickStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}