import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/models/product.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/providers/cart_provider.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/utils/app_localizations.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';
import 'package:smartbiztracker_new/screens/store/product_details_with_cart.dart';
import 'package:smartbiztracker_new/widgets/loading_widget.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class ClientProductScreen extends StatefulWidget {
  const ClientProductScreen({super.key});

  @override
  _ClientProductScreenState createState() => _ClientProductScreenState();
}

class _ClientProductScreenState extends State<ClientProductScreen> {
  Future<List<ProductModel>>? _productsFuture;
  String? _selectedCategory;
  double? _minPrice;
  double? _maxPrice;
  String _sortBy = 'latest';
  final TextEditingController _searchController = TextEditingController();
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<String> _categories = [];
  bool _isSearching = false;
  bool _isCategoriesLoading = false;
  bool _hasNetworkError = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Debug: Print out when component initializes
    print('ClientProductScreen initialized');
  }

  Future<void> _loadData() async {
    print('Loading data in ClientProductScreen');
    await _loadCategories();
    await _loadProducts();

    // Debug: Print out all categories and selected category
    print('Available categories: $_categories');
    print('Selected category: $_selectedCategory');
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isCategoriesLoading = true;
    });

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final categories = await productProvider.getSamaCategories();

      setState(() {
        // Remove 'All Categories' if it exists as we'll add our own "All" option in the UI
        _categories = categories.where((cat) => cat != 'All Categories').toList();
        _isCategoriesLoading = false;
      });

      AppLogger.info('Loaded ${_categories.length} categories from API');
      print('Categories loaded: $_categories');
    } catch (e) {
      AppLogger.error('Failed to load categories', e);
      setState(() {
        _isCategoriesLoading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    setState(() {
      _hasNetworkError = false;
      _lastError = null;
      _productsFuture = productProvider.loadSamaProducts(
        category: _selectedCategory,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        sortBy: _sortBy,
      );
    });

    try {
      final productModels = await _productsFuture!;
      _allProducts = productModels.map((p) => Product.fromProductModel(p)).toList();
      _filteredProducts = List.from(_allProducts);

      setState(() {
        _hasNetworkError = false;
        _lastError = null;
      });

      // Log the number of products received after filtering
      print('Loaded ${_allProducts.length} products');
      if (_selectedCategory != null) {
        print('Selected category: $_selectedCategory with ${_allProducts.length} products');
      }
    } catch (e) {
      setState(() {
        _hasNetworkError = true;
        _lastError = e.toString();
      });

      AppLogger.error('خطأ في تحميل المنتجات', e);

      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              onPressed: () => _loadProducts(),
            ),
          ),
        );
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('Failed host lookup') || error.contains('No address associated with hostname')) {
      return 'لا يمكن الاتصال بالخادم. تحقق من اتصالك بالإنترنت';
    } else if (error.contains('Connection refused') || error.contains('Connection timed out')) {
      return 'انتهت مهلة الاتصال. يرجى المحاولة لاحقاً';
    } else if (error.contains('SocketException')) {
      return 'خطأ في الشبكة. تحقق من اتصالك بالإنترنت';
    } else {
      return 'حدث خطأ في تحميل المنتجات. يرجى المحاولة مرة أخرى';
    }
  }

  Widget _buildErrorWidget(ThemeData theme, AppLocalizations appLocalizations) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off,
              size: 64,
              color: theme.colorScheme.error.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'خطأ في الاتصال',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _lastError != null ? _getErrorMessage(_lastError!) : 'حدث خطأ غير متوقع',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadProducts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    // Try to load cached data or show offline mode
                    _loadOfflineData();
                  },
                  icon: const Icon(Icons.offline_bolt),
                  label: const Text('وضع عدم الاتصال'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations appLocalizations) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            appLocalizations.translate('no_products_found') ?? 'لا توجد منتجات',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'جرب تغيير فلاتر البحث أو إعادة تحميل الصفحة',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة التحميل'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadOfflineData() async {
    // Try to load any cached products
    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      // Check if there are any cached products
      if (productProvider.products.isNotEmpty) {
        setState(() {
          _allProducts = productProvider.products.map((p) => Product.fromProductModel(p)).toList();
          _filteredProducts = List.from(_allProducts);
          _hasNetworkError = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحميل البيانات المحفوظة محلياً'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد بيانات محفوظة محلياً'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('خطأ في تحميل البيانات المحفوظة', e);
    }
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = List.from(_allProducts);
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _filteredProducts = _allProducts
          .where((product) =>
              product.name.toLowerCase().contains(query.toLowerCase()) ||
              (product.description ?? '').toLowerCase().contains(query.toLowerCase()) ||
              (product.category ?? '').toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.translate('store_products') ?? 'منتجات المتجر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: appLocalizations.translate('search_products') ?? 'بحث عن منتجات',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: _filterProducts,
                ),
                const SizedBox(height: 12),

                // Category filter with loading indicator
                _isCategoriesLoading
                    ? SizedBox(
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: appLocalizations.translate('all') ?? 'الكل',
                              selected: _selectedCategory == null,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedCategory = null;
                                  });
                                  _loadProducts();
                                }
                              },
                            ),
                            ..._categories.map((category) => _buildFilterChip(
                              label: category,
                              selected: _selectedCategory == category,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                } else {
                                  setState(() {
                                    _selectedCategory = null;
                                  });
                                }
                                print('Category selection changed to: $_selectedCategory');
                                _loadProducts();
                              },
                            )),
                            const SizedBox(width: 8),

                            // Sort dropdown
                            DropdownButton<String>(
                              value: _sortBy,
                              items: [
                                DropdownMenuItem(
                                  value: 'latest',
                                  child: Text(appLocalizations.translate('latest') ?? 'الأحدث'),
                                ),
                                DropdownMenuItem(
                                  value: 'priceAsc',
                                  child: Text(appLocalizations.translate('price_low_to_high') ?? 'السعر من الأقل للأعلى'),
                                ),
                                DropdownMenuItem(
                                  value: 'priceDesc',
                                  child: Text(appLocalizations.translate('price_high_to_low') ?? 'السعر من الأعلى للأقل'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _sortBy = value ?? 'latest';
                                  _loadProducts();
                                });
                              },
                              hint: Text(appLocalizations.translate('sort_by') ?? 'ترتيب حسب'),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),

          // Products grid
          Expanded(
            child: _productsFuture == null
                ? const LoadingWidget()
                : FutureBuilder<List<ProductModel>>(
                    future: _productsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingWidget();
                      } else if (snapshot.hasError || _hasNetworkError) {
                        return _buildErrorWidget(theme, appLocalizations);
                      } else if (!snapshot.hasData ||
                                (_isSearching && _filteredProducts.isEmpty) ||
                                (!_isSearching && snapshot.data!.isEmpty)) {
                        return _buildEmptyState(theme, appLocalizations);
                      }

                final products = _isSearching ? _filteredProducts : snapshot.data!.map((p) => Product.fromProductModel(p)).toList();

                return AnimationLimiter(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return AnimationConfiguration.staggeredGrid(
                        position: index,
                        columnCount: 2,
                        duration: AnimationSystem.medium,
                        child: ScaleAnimation(
                          child: FadeInAnimation(
                            child: _buildProductCard(context, products[index]),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        selected: selected,
        onSelected: (value) {
          // Log selection change
          print('Category filter changed: $label is now ${value ? 'selected' : 'unselected'}');
          onSelected(value);
        },
        checkmarkColor: Colors.white,
        selectedColor: Theme.of(context).colorScheme.primary,
        backgroundColor: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
        elevation: selected ? 2 : 0,
        shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsWithCart(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  // Image
                  CachedNetworkImage(
                    imageUrl: product.imageUrl ?? '',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[100],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2),
                            SizedBox(height: 8),
                            Text(
                              'تحميل...',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      print('Product image error: $url - $error');
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 40, color: Colors.grey),
                              SizedBox(height: 4),
                              Text(
                                'فشل تحميل الصورة',
                                style: TextStyle(color: Colors.grey, fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    httpHeaders: const {
                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                    },
                  ),

                  // Add to cart button
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                        onPressed: () {
                          cartProvider.addItem(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تمت إضافة ${product.name} إلى السلة'),
                              duration: const Duration(seconds: 2),
                              action: SnackBarAction(
                                label: 'عرض السلة',
                                onPressed: () {
                                  Navigator.pushNamed(context, '/cart');
                                },
                              ),
                            ),
                          );
                        },
                        tooltip: AppLocalizations.of(context).translate('add_to_cart') ?? 'إضافة إلى السلة',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category tag if available
                    if (product.category != null && product.category!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.category!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Price
                    Text(
                      '${product.price.toStringAsFixed(2)} جنيه',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Stock status
                    if (product.inStock)
                      Text(
                        AppLocalizations.of(context).translate('in_stock') ?? 'متوفر',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                        ),
                      )
                    else
                      Text(
                        AppLocalizations.of(context).translate('out_of_stock') ?? 'غير متوفر',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                        ),
                      ),

                    // View details button
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailsWithCart(product: product),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 0),
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Theme.of(context).colorScheme.onSecondary,
                        ),
                        child: Text(
                          AppLocalizations.of(context).translate('view_details') ?? 'عرض التفاصيل',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
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
}