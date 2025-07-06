import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';
import 'package:smartbiztracker_new/widgets/common/professional_product_card.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductManagementWidget extends StatefulWidget {

  const ProductManagementWidget({
    super.key,
    this.onAddProduct,
    this.showHeader = true,
    this.isEmbedded = false,
    this.maxHeight,
    this.hideVisibleFilter = false,
    this.hideAddButton = false,
    this.hideAdvancedSearch = false,
    this.hideExportButton = false,
    this.hideLowStockButton = false,
  });
  final VoidCallback? onAddProduct;
  final bool showHeader;
  final bool isEmbedded;
  final double? maxHeight;
  final bool hideVisibleFilter;
  final bool hideAddButton;
  final bool hideAdvancedSearch;
  final bool hideExportButton;
  final bool hideLowStockButton;

  @override
  State<ProductManagementWidget> createState() => _ProductManagementWidgetState();
}

class _ProductManagementWidgetState extends State<ProductManagementWidget> {
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? errorMessage;
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _showZeroStock = false;
  late ProductProvider _productProvider;
  // Add a state variable for statistics visibility
  bool _showStatistics = false;
  // متغيرات للتحكم في إخفاء شريط البحث عند التمرير
  bool _showSearchBar = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // إضافة listener للتمرير لإخفاء شريط البحث
    _scrollController.addListener(() {
      if (_scrollController.offset > 100 && _showSearchBar) {
        setState(() {
          _showSearchBar = false;
        });
      } else if (_scrollController.offset <= 100 && !_showSearchBar) {
        setState(() {
          _showSearchBar = true;
        });
      }
    });

    // تحميل المنتجات من SAMA API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        final products = productProvider.samaAdminProducts; // Use SAMA Admin products
        final isLoading = productProvider.isLoading;
        final errorMessage = productProvider.error;

        // تصفية المنتجات بناء على البحث المتقدم وحالة المخزون
        List<ProductModel> baseProducts = products;

        // تطبيق فلتر البحث أولاً
        if (_searchQuery.isNotEmpty) {
          final lowerQuery = _searchQuery.toLowerCase();
          baseProducts = baseProducts.where((product) {
            return product.name.toLowerCase().contains(lowerQuery) ||
                   product.sku.toLowerCase().contains(lowerQuery) ||
                   product.category.toLowerCase().contains(lowerQuery) ||
                   (product.description.toLowerCase().contains(lowerQuery) ?? false);
          }).toList();
        }

        // تطبيق فلتر المخزون الصفر
        final filteredProducts = !_showZeroStock
            ? baseProducts.where((product) => product.quantity > 0).toList()
            : baseProducts;

        Widget content = Column(
          children: [
            // Profitability section at the top (collapsible)
            if (!widget.hideExportButton)
              ExpansionTile(
                initiallyExpanded: false,
                title: Text(
                  'تحليل الربحية',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                    fontSize: 18,
                  ),
                ),
                leading: Icon(Icons.trending_up, color: Colors.green[700], size: 28),
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[50]!, Colors.green[100]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildProfitabilityCard(
                                'إجمالي الربح المتوقع',
                                '${NumberFormat.currency(symbol: '').format(_calculateTotalProfit(products))} ج.م',
                                Icons.account_balance_wallet,
                                Colors.green[600]!,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildProfitabilityCard(
                                'متوسط هامش الربح',
                                '${_calculateAverageMargin(products).toStringAsFixed(1)}%',
                                Icons.percent,
                                Colors.blue[600]!,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildProfitabilityCard(
                                'منتجات مربحة',
                                '${products.where((p) => p.purchasePrice != null && p.price > p.purchasePrice!).length}',
                                Icons.trending_up,
                                Colors.green[600]!,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildProfitabilityCard(
                                'تحتاج مراجعة',
                                '${products.where((p) => p.purchasePrice == null || p.purchasePrice! <= 0).length}',
                                Icons.warning,
                                Colors.orange[600]!,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // أداء المنتجات - الأكثر والأقل ربحية
                        _buildTopPerformingProducts(products),
                      ],
                    ),
                  ),
                ],
              ),

            // Advanced Search Bar - يختفي عند التمرير
            if (!widget.hideAdvancedSearch && _showSearchBar)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _showSearchBar ? null : 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ElegantSearchBar(
                        controller: _searchController,
                        hintText: 'البحث المتقدم في المنتجات (اسم، SKU، فئة)...',
                        prefixIcon: Icons.search,
                        onChanged: _filterProducts,
                        onClear: () {
                          _filterProducts('');
                        },
                        borderColor: theme.colorScheme.primary,
                        elevation: 4.0,
                      ),
                      // Toggle switch for showing zero stock products
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: !widget.hideVisibleFilter ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _showZeroStock ? Icons.visibility : Icons.visibility_off,
                                color: _showZeroStock ? Colors.green : Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'عرض المنتجات منتهية الصلاحية',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _showZeroStock
                                          ? 'جميع المنتجات معروضة'
                                          : 'المنتجات ذات الكمية صفر مخفية (${products.where((p) => p.quantity == 0).length} منتج)',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _showZeroStock,
                                onChanged: (value) {
                                  setState(() {
                                    _showZeroStock = value;
                                    // إعادة تصفية المنتجات بناءً على القيمة الجديدة
                                    _filterProducts(_searchQuery);
                                  });
                                },
                                activeColor: Colors.green,
                                inactiveThumbColor: Colors.orange,
                              ),
                            ],
                          ),
                        ) : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),

            // Collapsible statistics section
            if (!widget.hideLowStockButton)
              ExpansionTile(
                initiallyExpanded: _showStatistics,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _showStatistics = expanded;
                  });
                },
                title: Text(
                  'إحصائيات المنتجات',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                leading: Icon(Icons.insights, color: theme.colorScheme.primary),
                children: [
                // Product summary cards
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildSummaryCard(
                        'إجمالي المنتجات',
                        '${products.length}',
                        Icons.inventory_2,
                        theme.colorScheme.primary,
                      ),
                      _buildSummaryCard(
                        'متوفر في المخزون',
                        '${products.where((p) => p.quantity > 0).length}',
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _buildSummaryCard(
                        'إجمالي قيمة المخزون',
                        '${NumberFormat.currency(symbol: '').format(products.fold<double>(0, (sum, p) => sum + (p.price * p.quantity)))} ج.م',
                        Icons.attach_money,
                        Colors.blue,
                      ),
                      _buildSummaryCard(
                        'لها أسعار شراء',
                        '${products.where((p) => p.purchasePrice != null && p.purchasePrice! > 0).length}',
                        Icons.shopping_cart,
                        Colors.orange,
                      ),
                      GestureDetector(
                        onTap: () {
                          // عند النقر، تعيين حقل البحث بنص يظهر المنتجات غير المتوفرة
                          _searchController.text = '0';
                          _filterProducts('0');
                        },
                        child: _buildSummaryCard(
                          'غير متوفر (مخفي)',
                          '${products.where((p) => p.quantity == 0).length}',
                          Icons.visibility_off,
                          Colors.red,
                        ),
                      ),
                      _buildSummaryCard(
                        'بحاجة للتجديد',
                        '${products.where((p) => p.quantity > 0 && p.quantity <= 5).length}',
                        Icons.warning,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
              ],
            ),



            // Product list
            Expanded(
              child: Stack(
                children: [
                  isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('جاري تحميل البيانات من SAMA API...'),
                            ],
                          ),
                        )
                      : errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text('حدث خطأ: $errorMessage'),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      _loadAllProducts();
                                    },
                                    child: const Text('إعادة المحاولة'),
                                  ),
                                ],
                              ),
                            )
                          : filteredProducts.isEmpty
                              ? const Center(
                                  child: Text('لا توجد منتجات'),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadAllProducts,
                                  child: _isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : filteredProducts.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.inventory_2_outlined,
                                                  size: 64,
                                                  color: theme.colorScheme.primary.withOpacity(0.5),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  errorMessage != null
                                                    ? 'حدث خطأ: $errorMessage'
                                                    : 'لا توجد منتجات',
                                                  style: theme.textTheme.titleMedium,
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 24),
                                                ElevatedButton.icon(
                                                  onPressed: _loadAllProducts,
                                                  icon: const Icon(Icons.refresh),
                                                  label: const Text('إعادة المحاولة'),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: GridView.builder(
                                              controller: _scrollController, // إضافة ScrollController
                                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                childAspectRatio: 0.75, // زيادة الارتفاع لاستيعاب المحتوى الجديد
                                                crossAxisSpacing: 16,
                                                mainAxisSpacing: 16,
                                              ),
                                              itemCount: filteredProducts.length,
                                              itemBuilder: (context, index) {
                                                final product = filteredProducts[index];
                                                return AnimationConfiguration.staggeredGrid(
                                                  position: index,
                                                  duration: const Duration(milliseconds: 200),
                                                  columnCount: 2,
                                                  child: SlideAnimation(
                                                    verticalOffset: 30.0,
                                                    child: FadeInAnimation(
                                                      duration: const Duration(milliseconds: 150),
                                                      child: ProfessionalProductCard(
                                                        product: product,
                                                        cardType: ProductCardType.admin,
                                                        onTap: () => _showProductDetails(context, product),
                                                        onEdit: () => _editProduct(context, product),
                                                        onDelete: () => _deleteProduct(context, product),
                                                        currencySymbol: 'جنيه',
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                ),

                  // زر العودة إلى الأعلى - يظهر عندما يختفي شريط البحث
                  if (!_showSearchBar)
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: AnimatedOpacity(
                        opacity: !_showSearchBar ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: FloatingActionButton(
                          mini: true,
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
            ),
          ],
        );

        // If this is embedded in a parent widget, we might need to constrain its height
        if (widget.isEmbedded && widget.maxHeight != null) {
          content = SizedBox(
            height: widget.maxHeight,
            child: content,
          );
        }

        return content;
      },
    );
  }

  // Build summary card
  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
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
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // Build profitability card
  Widget _buildProfitabilityCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Calculate total profit
  double _calculateTotalProfit(List<ProductModel> products) {
    return products.fold<double>(0, (sum, product) {
      if (product.purchasePrice != null && product.purchasePrice! > 0) {
        final profit = (product.price - product.purchasePrice!) * product.quantity;
        return sum + profit;
      }
      return sum;
    });
  }

  // Calculate average margin percentage
  double _calculateAverageMargin(List<ProductModel> products) {
    final profitableProducts = products.where((p) =>
        p.purchasePrice != null && p.purchasePrice! > 0).toList();

    if (profitableProducts.isEmpty) return 0;

    final totalMargin = profitableProducts.fold<double>(0, (sum, product) {
      final margin = ((product.price - product.purchasePrice!) / product.price) * 100;
      return sum + margin;
    });

    return totalMargin / profitableProducts.length;
  }

  // Build product image with proper error handling
  Widget _buildProductImage(ProductModel product, ThemeData theme) {
    final hasValidImageUrl = product.imageUrl != null && product.imageUrl!.isNotEmpty;
    final hasValidImages = product.images.isNotEmpty;
    String? imageUrl;

    if (hasValidImageUrl) {
      imageUrl = product.imageUrl;
      // Ensure URL has proper protocol
      if (imageUrl != null && !imageUrl.startsWith('http')) {
        if (imageUrl.startsWith('/')) {
          // Relative URL, add base
          imageUrl = 'https://samastock.pythonanywhere.com$imageUrl';
        } else {
          // Fix file:/// URLs
          imageUrl = 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
        }
      }
    } else if (hasValidImages) {
      // Find first valid image
      imageUrl = product.images.firstWhere(
          (img) => !img.contains('placeholder'),
          orElse: () => '');

      // Ensure URL has proper protocol
      if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
        if (imageUrl.startsWith('/')) {
          // Relative URL, add base
          imageUrl = 'https://samastock.pythonanywhere.com$imageUrl';
        } else {
          // Fix file:/// URLs
          imageUrl = 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
        }
      }
    }

    // If we have a valid image URL, display it with proper caching
    if (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          height: 120, // زيادة الارتفاع من 70 إلى 120
          width: 120,  // زيادة العرض من 70 إلى 120
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 120,
            width: 120,
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                  strokeWidth: 2,
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.photo,
                  color: theme.colorScheme.primary.withOpacity(0.5),
                  size: 24,
                ),
              ],
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image,
                  color: theme.colorScheme.error.withOpacity(0.7),
                  size: 32,
                ),
                const SizedBox(height: 4),
                Text(
                  'خطأ في الصورة',
                  style: TextStyle(
                    color: theme.colorScheme.error.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // No valid image, display placeholder
      return Container(
        height: 120, // زيادة الارتفاع من 70 إلى 120
        width: 120,  // زيادة العرض من 70 إلى 120
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2,
              color: theme.colorScheme.primary.withOpacity(0.5),
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              'لا توجد صورة',
              style: TextStyle(
                color: theme.colorScheme.primary.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }
  }

  // Build product card with complete information
  Widget _buildProductCard(ProductModel product, ThemeData theme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            _buildProductImage(product, theme),

            const SizedBox(width: 12),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name with Status Indicator
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 10,
                        width: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: product.isActive ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // SKU and Category
                  Row(
                    children: [
                      // SKU
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.sku,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Category
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.category,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Price, Stock, and Purchase Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Selling Price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'سعر البيع',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${NumberFormat.currency(symbol: '').format(product.price)} ج.م',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Stock
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'المخزون',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${product.quantity}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: product.quantity > 0 ? Colors.green : Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Purchase Price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'سعر الشراء',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              product.purchasePrice != null
                                  ? '${NumberFormat.currency(symbol: '').format(product.purchasePrice!)} ج.م'
                                  : 'غير محدد',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: product.purchasePrice != null ? Colors.orange : Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Profit margin if both prices are available
                  if (product.purchasePrice != null && product.purchasePrice! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'هامش الربح:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${NumberFormat.currency(symbol: '').format(product.price - product.purchasePrice!)} ج.م',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة لتحميل المنتجات من SAMA API مع استخدام toJSON
  Future<void> _loadAllProducts() async {
    try {
      setState(() {
        _isLoading = true;
        errorMessage = null;
      });

      // استخدام مزود ProductProvider للحصول على المنتجات من API
      _productProvider = Provider.of<ProductProvider>(context, listen: false);

      // التحقق من وجود منتجات محملة بالفعل
      if (_productProvider.samaAdminProducts.isNotEmpty) {
        print('DEBUG: Using existing products: ${_productProvider.samaAdminProducts.length}');
        setState(() {
          _allProducts = _productProvider.samaAdminProducts;
          _isLoading = false;
        });

        // تطبيق التصفية
        _filterProducts(_searchQuery);
        return;
      }

      // إذا لم تكن هناك منتجات، حاول تحميلها
      print('DEBUG: No existing products, loading from API...');

      // استدعاء الدالة الجديدة المخصصة لمنتجات الأدمن التي تستخدم toJSON
      await _productProvider.loadSamaAdminProductsWithToJSON();

      // طباعة معلومات تصحيحية عن البيانات المحملة
      if (_productProvider.samaAdminProducts.isNotEmpty) {
        final firstProduct = _productProvider.samaAdminProducts.first;
        print('DEBUG: Sample product data:');
        print('DEBUG: Name: ${firstProduct.name}');
        print('DEBUG: Price: ${firstProduct.price}');
        print('DEBUG: Quantity: ${firstProduct.quantity}');
        print('DEBUG: Purchase Price: ${firstProduct.purchasePrice}');
        print('DEBUG: Image URL: ${firstProduct.imageUrl}');
      }

      if (mounted) {
        setState(() {
          _allProducts = _productProvider.samaAdminProducts;
          print('DEBUG: Loaded products: ${_allProducts.length}');
          _isLoading = false;
        });

        // تطبيق التصفية بعد تحميل البيانات
        _filterProducts(_searchQuery);
        print('DEBUG: Filtered products: ${_filteredProducts.length}');
      }
    } catch (e) {
      print('DEBUG: Error loading products: $e');
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // دالة لتصفية المنتجات بناءً على مدخلات البحث المتقدم
  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query;

      List<ProductModel> baseProducts = _allProducts;

      // أولاً: تطبيق فلتر البحث إذا وجد
      if (query.isNotEmpty) {
        final lowerQuery = query.toLowerCase();
        baseProducts = baseProducts
            .where((product) =>
                product.name.toLowerCase().contains(lowerQuery) ||
                product.sku.toLowerCase().contains(lowerQuery) ||
                product.category.toLowerCase().contains(lowerQuery) ||
                (product.description.toLowerCase().contains(lowerQuery) ?? false))
            .toList();
      }

      // ثانياً: تطبيق فلتر المخزون الصفر
      if (!_showZeroStock) {
        baseProducts = baseProducts
            .where((product) => product.quantity > 0)
            .toList();
      }

      _filteredProducts = baseProducts;
    });
  }

  // Show product details dialog
  void _showProductDetails(BuildContext context, ProductModel product) {
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
                  child: CachedNetworkImage(
                    imageUrl: product.bestImageUrl,
                    fit: BoxFit.cover,
                    height: 200,
                    width: double.infinity,
                    errorWidget: (context, url, error) {
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
              Text('الفئة: ${product.category}'),
              const SizedBox(height: 8),
              Text('الكمية: ${product.quantity}'),
              const SizedBox(height: 8),
              Text('سعر البيع: ${product.price.toStringAsFixed(2)} جنيه'),
              if (product.purchasePrice != null && product.purchasePrice! > 0) ...[
                const SizedBox(height: 8),
                Text('سعر الشراء: ${product.purchasePrice!.toStringAsFixed(2)} جنيه'),
                const SizedBox(height: 8),
                Text('الربح: ${(product.price - product.purchasePrice!).toStringAsFixed(2)} جنيه'),
              ],
              if (product.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('الوصف: ${product.description}'),
              ],
            ],
          ),
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

  // Edit product (placeholder)
  void _editProduct(BuildContext context, ProductModel product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تعديل المنتج: ${product.name}'),
        backgroundColor: StyleSystem.infoColor,
      ),
    );
  }

  // Delete product (placeholder)
  void _deleteProduct(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المنتج "${product.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حذف المنتج: ${product.name}'),
                  backgroundColor: StyleSystem.errorColor,
                ),
              );
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  /// بناء قسم أداء المنتجات - الأكثر والأقل ربحية
  Widget _buildTopPerformingProducts(List<ProductModel> products) {
    final mostProfitable = _getMostProfitableProduct(products);
    final leastProfitable = _getLeastProfitableProduct(products);

    if (mostProfitable == null && leastProfitable == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Text(
            'لا توجد منتجات متوفرة لتحليل الأداء',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.analytics,
              color: Colors.purple[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'أداء المنتجات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.purple[700],
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (mostProfitable != null)
              Expanded(
                child: _buildPerformanceProductCard(
                  mostProfitable,
                  'الأكثر ربحية',
                  Colors.green,
                  Icons.trending_up,
                ),
              ),
            if (mostProfitable != null && leastProfitable != null)
              const SizedBox(width: 12),
            if (leastProfitable != null)
              Expanded(
                child: _buildPerformanceProductCard(
                  leastProfitable,
                  'الأقل ربحية',
                  Colors.orange,
                  Icons.trending_down,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// بناء بطاقة منتج الأداء
  Widget _buildPerformanceProductCard(
    ProductModel product,
    String title,
    Color color,
    IconData icon,
  ) {
    final profit = product.purchasePrice != null
        ? product.price - product.purchasePrice!
        : 0.0;
    final profitMargin = product.purchasePrice != null && product.purchasePrice! > 0
        ? ((product.price - product.purchasePrice!) / product.price) * 100
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.inventory,
                size: 12,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                'المخزون: ${product.quantity}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.attach_money,
                size: 12,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                'السعر: ${product.price.toStringAsFixed(2)} ج.م',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (product.purchasePrice != null && product.purchasePrice! > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  'الربح: ${profit.toStringAsFixed(2)} ج.م',
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.percent,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  'الهامش: ${profitMargin.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// الحصول على المنتج الأكثر ربحية (متوفر في المخزون)
  ProductModel? _getMostProfitableProduct(List<ProductModel> products) {
    final availableProducts = products.where((p) =>
        p.quantity > 0 &&
        p.purchasePrice != null &&
        p.purchasePrice! > 0
    ).toList();

    if (availableProducts.isEmpty) return null;

    availableProducts.sort((a, b) {
      final profitA = a.price - a.purchasePrice!;
      final profitB = b.price - b.purchasePrice!;
      return profitB.compareTo(profitA);
    });

    return availableProducts.first;
  }

  /// الحصول على المنتج الأقل ربحية (متوفر في المخزون)
  ProductModel? _getLeastProfitableProduct(List<ProductModel> products) {
    final availableProducts = products.where((p) =>
        p.quantity > 0 &&
        p.purchasePrice != null &&
        p.purchasePrice! > 0
    ).toList();

    if (availableProducts.isEmpty) return null;

    availableProducts.sort((a, b) {
      final profitA = a.price - a.purchasePrice!;
      final profitB = b.price - b.purchasePrice!;
      return profitA.compareTo(profitB);
    });

    return availableProducts.first;
  }
}