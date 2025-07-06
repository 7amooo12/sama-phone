import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/widgets/common/advanced_search_bar.dart';
import 'package:smartbiztracker_new/widgets/common/professional_product_card.dart';

class AccountantProductsScreen extends StatefulWidget {
  const AccountantProductsScreen({super.key});

  @override
  State<AccountantProductsScreen> createState() => _AccountantProductsScreenState();
}

class _AccountantProductsScreenState extends State<AccountantProductsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  final bool _isGridView = false;
  bool _isLoading = true;
  List<ProductModel> _products = [];
  String? _error;
  bool _showHeader = true;
  bool _showFab = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _setupScrollListener();
    _initializeAnimations();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      final shouldShowHeader = _scrollController.offset <= 100;
      final shouldShowFab = _scrollController.offset > 200;

      if (shouldShowHeader != _showHeader || shouldShowFab != _showFab) {
        setState(() {
          _showHeader = shouldShowHeader;
          _showFab = shouldShowFab;
        });

        if (_showFab) {
          _fabAnimationController.forward();
        } else {
          _fabAnimationController.reverse();
        }
      }
    });
  }

  void _initializeAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use products from ProductProvider with SAMA API
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      productProvider.setUseSamaAdmin(true);
      await productProvider.loadSamaAdminProductsWithToJSON();

      setState(() {
        _products = productProvider.samaAdminProducts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      debugPrint('❌ Error loading products: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter products based on search query
    final filteredProducts = _searchQuery.isEmpty
        ? _products
        : _products.where((product) =>
            product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.sku.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Animated header
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _showHeader ? null : 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showHeader ? 1.0 : 0.0,
                  child: Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: AdvancedSearchBar(
                          controller: _searchController,
                          hintText: 'بحث عن منتج...',
                          accentColor: theme.colorScheme.primary,
                          showSearchAnimation: true,
                          onChanged: (query) {
                            setState(() {
                              _searchQuery = query;
                            });
                          },
                          onSubmitted: (query) {
                            setState(() {
                              _searchQuery = query;
                            });
                          },
                        ),
                      ),

                      // Summary card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSummaryItem(
                                  'إجمالي المنتجات',
                                  '${_products.length}',
                                  Icons.inventory_2,
                                  theme.colorScheme.primary,
                                ),
                                _buildSummaryItem(
                                  'متوفر',
                                  '${_products.where((p) => p.quantity > 0).length}',
                                  Icons.check_circle,
                                  Colors.green,
                                ),
                                _buildSummaryItem(
                                  'غير متوفر',
                                  '${_products.where((p) => p.quantity == 0).length}',
                                  Icons.cancel,
                                  Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Products
              Expanded(
                child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 60, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              'حدث خطأ أثناء تحميل المنتجات\n$_error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadProducts,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : filteredProducts.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد منتجات مطابقة لمعايير البحث',
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : _isGridView
                          ? _buildGridView(filteredProducts)
                          : _buildListView(filteredProducts),
              ),
            ],
          ),

          // Floating Action Button
          if (_showFab)
            Positioned(
              bottom: 20,
              right: 20,
              child: ScaleTransition(
                scale: _fabAnimation,
                child: FloatingActionButton(
                  onPressed: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.keyboard_arrow_up),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Grid view for products
  Widget _buildGridView(List<ProductModel> products) {
    return AnimationLimiter(
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75, // تحسين النسبة لاستيعاب المحتوى المحسن
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            columnCount: 2,
            duration: const Duration(milliseconds: 375),
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildAccountantProductCard(
                  product: products[index],
                  // إزالة onTap - سيتم النقر على الكارد مباشرة
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // List view for products
  Widget _buildListView(List<ProductModel> products) {
    return AnimationLimiter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          controller: _scrollController,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75, // تحسين النسبة لاستيعاب المحتوى المحسن
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return AnimationConfiguration.staggeredGrid(
              position: index,
              duration: const Duration(milliseconds: 200), // أسرع - كان 375
              columnCount: 2,
              child: SlideAnimation(
                verticalOffset: 30.0, // أقل - كان 50
                child: FadeInAnimation(
                  duration: const Duration(milliseconds: 150), // أسرع
                  child: ProfessionalProductCard(
                    product: products[index],
                    cardType: ProductCardType.accountant,
                    onTap: () => _showProductDetails(context, products[index]),
                    currencySymbol: 'جنيه',
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Build summary item
  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // Build accountant product card
  Widget _buildAccountantProductCard({
    required ProductModel product,
  }) {
    final theme = Theme.of(context);

    // حساب الربحية
    final purchasePrice = product.purchasePrice ?? 0.0;
    final sellPrice = product.price;
    final profit = sellPrice - purchasePrice;
    final profitPercentage = purchasePrice > 0 ? ((profit / purchasePrice) * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.blue.shade50,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.blue.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showProductDetails(context, product), // النقر على الكارد مباشرة
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // صورة المنتج المحسنة
                    Stack(
                      children: [
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.blue.shade100,
                                Colors.blue.shade200,
                              ],
                            ),
                          ),
                          child: product.bestImageUrl.isNotEmpty && !product.bestImageUrl.contains('placeholder.com')
                              ? ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                  child: Image.network(
                                    product.bestImageUrl,
                                    fit: BoxFit.cover, // تحسين عرض الصورة لتملأ المساحة بذكاء
                                    width: double.infinity,
                                    height: double.infinity,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.shade200,
                                              Colors.blue.shade100,
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 30,
                                                height: 30,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    theme.primaryColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'جاري التحميل...',
                                                style: TextStyle(
                                                  color: Colors.blue.shade600,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.shade200,
                                              Colors.blue.shade300,
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.image_not_supported_outlined,
                                                size: 40,
                                                color: Colors.blue.shade500,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'لا توجد صورة',
                                                style: TextStyle(
                                                  color: Colors.blue.shade600,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade200,
                                        Colors.blue.shade300,
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.account_balance_outlined,
                                          size: 50,
                                          color: Colors.blue.shade500,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'منتج ساما',
                                          style: TextStyle(
                                            color: Colors.blue.shade600,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),

                        // مؤشر حالة المخزون
                        if (product.quantity <= 5 && product.quantity > 0)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'كمية محدودة',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ),

                        // مؤشر الربحية
                        if (profit > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${profitPercentage.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // تفاصيل المنتج المحسنة
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // اسم المنتج
                            Text(
                              product.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 8),

                            // الكمية المتوفرة
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: product.quantity > 10
                                    ? Colors.green.shade50
                                    : product.quantity > 0
                                        ? Colors.orange.shade50
                                        : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: product.quantity > 10
                                      ? Colors.green.shade200
                                      : product.quantity > 0
                                          ? Colors.orange.shade200
                                          : Colors.red.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 12,
                                    color: product.quantity > 10
                                        ? Colors.green.shade700
                                        : product.quantity > 0
                                            ? Colors.orange.shade700
                                            : Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${product.quantity}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: product.quantity > 10
                                          ? Colors.green.shade700
                                          : product.quantity > 0
                                              ? Colors.orange.shade700
                                              : Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 6),

                            // أسعار الشراء والبيع
                            if (purchasePrice > 0) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 12,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'شراء: ${purchasePrice.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                            ],

                            Row(
                              children: [
                                Icon(
                                  Icons.sell_outlined,
                                  size: 12,
                                  color: Colors.green.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'بيع: ${sellPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                            // الربحية
                            if (profit > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade100,
                                      Colors.blue.shade50,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      size: 10,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'ربح: ${profit.toStringAsFixed(0)} ج',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Show product details dialog
  void _showProductDetails(BuildContext context, ProductModel product) {
    final purchasePrice = product.purchasePrice ?? 0.0;
    final sellPrice = product.price;
    final profit = sellPrice - purchasePrice;
    final profitPercentage = purchasePrice > 0 ? ((profit / purchasePrice) * 100) : 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.bestImageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.bestImageUrl,
                    fit: BoxFit.cover,
                    height: 200,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey.shade400,
                            size: 50,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Text(product.description),
              const SizedBox(height: 16),
              Text('الفئة: ${product.category}'),
              Text('الكمية المتوفرة: ${product.quantity}'),
              if (purchasePrice > 0)
                Text('سعر الشراء: ${purchasePrice.toStringAsFixed(2)} جنيه'),
              Text('سعر البيع: ${sellPrice.toStringAsFixed(2)} جنيه'),
              if (profit > 0)
                Text('الربح: ${profit.toStringAsFixed(2)} جنيه (${profitPercentage.toStringAsFixed(1)}%)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}