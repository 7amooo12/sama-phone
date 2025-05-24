import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductManagementWidget extends StatefulWidget {
  final VoidCallback? onAddProduct;
  final bool showHeader;
  final bool isEmbedded;
  final double? maxHeight;
  final bool hideVisibleFilter;

  const ProductManagementWidget({
    super.key,
    this.onAddProduct,
    this.showHeader = true,
    this.isEmbedded = false,
    this.maxHeight,
    this.hideVisibleFilter = false,
  });

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
  
  @override
  void initState() {
    super.initState();

    // تحميل المنتجات من SAMA API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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

        // تصفية المنتجات بناء على كلمة البحث
        final filteredProducts = _searchQuery.isEmpty
            ? products.where((product) => _showZeroStock || product.quantity > 0).toList() // عرض فقط المنتجات ذات المخزون > 0 عند عدم البحث إلا إذا كان _showZeroStock = true
            : products.where((product) =>
                product.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

        Widget content = Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  ElegantSearchBar(
                    controller: _searchController,
                    hintText: 'البحث في المنتجات...',
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
                    child: !widget.hideVisibleFilter ? Row(
                      children: [
                        Checkbox(
                          value: _showZeroStock,
                          onChanged: (value) {
                            setState(() {
                              _showZeroStock = value ?? false;
                              // إعادة تصفية المنتجات بناءً على القيمة الجديدة
                              _filterProducts(_searchQuery);
                            });
                          },
                        ),
                        const Text("إظهار المنتجات غير المتوفرة في المخزون"),
                        Tooltip(
                          message: "المنتجات غير المتوفرة مخفية افتراضيًا لتسهيل العمل",
                          child: Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                        ),
                      ],
                    ) : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // Collapsible statistics section
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
                      GestureDetector(
                        onTap: () {
                          // عند النقر، تعيين حقل البحث بنص يظهر المنتجات غير المتوفرة
                          _searchController.text = "0";
                          _filterProducts("0");
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

            // SAMA API connection info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isLoading ? Icons.sync : Icons.cloud_done, 
                          color: isLoading ? Colors.orange : theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isLoading 
                                ? 'جاري مزامنة البيانات من متجر SAMA...' 
                                : errorMessage != null
                                    ? 'حدث خطأ في مزامنة البيانات: $errorMessage'
                                    : 'تم مزامنة البيانات من متجر SAMA (${filteredProducts.length} منتج${filteredProducts.length != 1 ? 'ات' : ''})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isLoading 
                                  ? Colors.orange 
                                  : errorMessage != null 
                                      ? Colors.red 
                                      : theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isLoading)
                          TextButton.icon(
                            onPressed: () => _loadAllProducts(),
                            icon: Icon(
                              Icons.refresh,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            label: Text(
                              'تحديث',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              minimumSize: const Size(0, 30),
                            ),
                          ),
                      ],
                    ),
                    if (!isLoading && errorMessage != null && _filteredProducts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'المصدر: samastock.pythonanywhere.com/admin/products',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 48,
                                  ),
                                  SizedBox(height: 16),
                                  Text('حدث خطأ: $errorMessage'),
                                  SizedBox(height: 16),
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
                              : Column(
                                  children: [
                                    // Products count indicator
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _searchQuery.isEmpty 
                                                ? _showZeroStock 
                                                  ? 'عرض جميع المنتجات (${filteredProducts.length}): ${products.where((p) => p.quantity > 0).length} متوفر و ${products.where((p) => p.quantity == 0).length} غير متوفر'
                                                  : 'تم عرض ${filteredProducts.length} منتج متوفر من أصل ${products.length} (المنتجات غير المتوفرة مخفية)' 
                                                : 'تم العثور على ${filteredProducts.length} منتج مطابق لـ "$_searchQuery"',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Product list with virtual scrolling for better performance
                                    Expanded(
                                      child: RefreshIndicator(
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
                                              : ListView.builder(
                                                  padding: const EdgeInsets.all(16),
                                                  itemCount: filteredProducts.length,
                                                  // Use a builder for better memory management with large lists
                                                  itemBuilder: (context, index) {
                                                    final product = filteredProducts[index];
                                                    return _buildProductCard(product, theme);
                                                  },
                                                ),
                                      ),
                                    ),
                                  ],
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
        borderRadius: BorderRadius.circular(4.0),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          height: 70,
          width: 70,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            child: Icon(
              Icons.photo,
              color: theme.colorScheme.primary.withOpacity(0.5),
              size: 24,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Icon(
              Icons.broken_image,
              color: theme.colorScheme.error.withOpacity(0.7),
              size: 24,
            ),
          ),
        ),
      );
    } else {
      // No valid image, display placeholder
      return Container(
        height: 70,
        width: 70,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Icon(
          Icons.inventory_2,
          color: theme.colorScheme.primary.withOpacity(0.5),
          size: 24,
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
                          color: theme.colorScheme.surfaceVariant,
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
                  
                  // Price and Stock
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'السعر',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            NumberFormat.currency(symbol: '').format(product.price),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      
                      // Stock
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            ),
                          ),
                        ],
                      ),
                      
                      // Cost
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'التكلفة',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            NumberFormat.currency(symbol: '').format(product.cost),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

  // دالة لتحميل المنتجات من SAMA API مع استخدام toJSON
  Future<void> _loadAllProducts() async {
    try {
      setState(() {
        _isLoading = true;
        errorMessage = null;
      });
      
      // استخدام مزود ProductProvider للحصول على المنتجات من API
      _productProvider = Provider.of<ProductProvider>(context, listen: false);
      
      // تعيين الوضع إلى استخدام SAMA Admin API
      _productProvider.setUseSamaAdmin(true);
      
      // استدعاء الدالة الجديدة المخصصة لمنتجات الأدمن التي تستخدم toJSON
      await _productProvider.loadSamaAdminProductsWithToJSON();
      
      if (mounted) {
        setState(() {
          _allProducts = _productProvider.samaAdminProducts;
          // تصفية المنتجات وفقًا لحالة _showZeroStock
          _filteredProducts = _searchQuery.isEmpty 
              ? _allProducts.where((product) => _showZeroStock || product.quantity > 0).toList()
              : _allProducts.where((product) => product.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // دالة لتصفية المنتجات بناءً على مدخلات البحث
  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        // إذا كان البحث فارغًا، يتم تصفية المنتجات بناءً على قيمة showZeroStock
        _filteredProducts = _allProducts
            .where((product) => _showZeroStock || product.quantity > 0)
            .toList();
      } else {
        // عند البحث، عرض جميع المنتجات التي تتطابق مع البحث، بغض النظر عن المخزون
        _filteredProducts = _allProducts
            .where((product) => product.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }
} 