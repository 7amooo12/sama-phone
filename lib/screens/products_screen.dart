import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/product_widgets.dart';
import '../utils/logger.dart';
import '../utils/style_system.dart';
import '../widgets/common/custom_app_bar_with_widget.dart';
import '../widgets/common/shimmer_loading.dart';
import '../widgets/common/advanced_search_bar.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> with SingleTickerProviderStateMixin {
  late ProductProvider _productProvider;
  List<String> _categories = ['All'];
  String? _selectedCategory;
  bool _isLoading = true;
  String _errorMessage = '';

  // Price range filter
  RangeValues _priceRange = const RangeValues(0, 1000);
  RangeValues _currentPriceRange = const RangeValues(0, 1000);
  double _maxPrice = 1000;

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final bool _showFilters = false;

  // انيميشن تبديل عرض المنتجات (جريد/قائمة)
  late AnimationController _animationController;
  bool _isGridView = true;

  // الفرز
  String _sortBy = 'latest'; // latest, priceAsc, priceDesc, popular

  // تحكم في التمرير
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _productProvider = Provider.of<ProductProvider>(context, listen: false);

    // إنشاء متحكم الانيميشن
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // تأكد من استخدام SamaStoreService
    _productProvider.setUseSamaStore(true);

    // تحميل سلة التسوق والمفضلة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(context, listen: false).loadCart();
      Provider.of<FavoritesProvider>(context, listen: false).loadFavorites();

      // تحديد سعر أقصى من المنتجات المتاحة
      _updateMaxPrice();
    });

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // تحديث سعر الحد الأقصى
  void _updateMaxPrice() {
    if (_productProvider.samaProducts.isNotEmpty) {
      double maxPrice = 0;
      for (var product in _productProvider.samaProducts) {
        if (product.price > maxPrice) {
          maxPrice = product.price;
        }
      }
      setState(() {
        _maxPrice = maxPrice + 100; // زيادة هامش
        _priceRange = RangeValues(0, _maxPrice);
        _currentPriceRange = RangeValues(0, _maxPrice);
      });
    }
  }

  // تحميل البيانات
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // تحميل المنتجات
      await _productProvider.loadSamaProducts(
        category: _selectedCategory,
        minPrice: _priceRange.start,
        maxPrice: _priceRange.end,
        sortBy: _sortBy,
      );

      // تحميل التصنيفات
      final categories = await _productProvider.getSamaCategories();

      if (mounted) {
        setState(() {
          _categories = ['All', ...categories];
          _isLoading = false;
        });

        _updateMaxPrice();
      }

      AppLogger.info('تم تحميل ${_productProvider.samaProducts.length} منتج و ${_categories.length} تصنيف');
    } catch (e) {
      AppLogger.error('خطأ في تحميل البيانات', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load products: ${e.toString()}';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل البيانات: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
            ),
          ),
        );
      }
    }
  }

  // تحديث البيانات
  Future<void> _refreshData() async {
    // مسح الكاش لضمان الحصول على أحدث البيانات
    _productProvider.clearSamaStoreCache();
    return _loadData();
  }

  // تصفية حسب التصنيف
  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadData();
  }

  // البحث عن منتجات
  Future<void> _searchProducts(String query) async {
    // إذا كان النص فارغ، نعرض كل المنتجات
    if (query.isEmpty) {
      _loadData();
      setState(() {
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoading = true;
    });

    try {
      final results = await _productProvider.searchSamaProducts(query);
      AppLogger.info('تم العثور على ${results.length} منتج مطابق لـ "$query"');
    } catch (e) {
      AppLogger.error('خطأ في البحث', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل البحث: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _isLoading = false;
        });
      }
    }
  }

  // عرض مربع حوار الفلترة
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildFilterBottomSheet(),
    );
  }

  // إنشاء مربع حوار الفلترة
  Widget _buildFilterBottomSheet() {
    final theme = Theme.of(context);
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(StyleSystem.radiusLarge),
            ),
            boxShadow: StyleSystem.shadowLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // المقبض
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // العنوان
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'التصفية والفرز',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
              ),

              const Divider(),

              // المحتوى
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // قسم التصنيفات
                    Text(
                      'التصنيفات',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('الكل'),
                          selected: _selectedCategory == null,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = null;
                            });
                          },
                          backgroundColor: theme.colorScheme.surface,
                          selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                          checkmarkColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
                            side: BorderSide(
                              color: _selectedCategory == null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                        ),
                        ..._categories.map((category) => FilterChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          backgroundColor: theme.colorScheme.surface,
                          selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                          checkmarkColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
                            side: BorderSide(
                              color: _selectedCategory == category
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                        )),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // قسم نطاق السعر
                    Text(
                      'نطاق السعر',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_currentPriceRange.start.toInt()} جنيه',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          '${_currentPriceRange.end.toInt()} جنيه',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: _currentPriceRange,
                      min: 0,
                      max: _maxPrice,
                      divisions: 20,
                      labels: RangeLabels(
                        '${_currentPriceRange.start.toInt()} جنيه',
                        '${_currentPriceRange.end.toInt()} جنيه',
                      ),
                      onChanged: (values) {
                        setState(() {
                          _currentPriceRange = values;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // قسم الفرز
                    Text(
                      'الفرز حسب',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('الأحدث'),
                          selected: _sortBy == 'latest',
                          onSelected: (_) {
                            setState(() {
                              _sortBy = 'latest';
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('السعر: من الأقل إلى الأعلى'),
                          selected: _sortBy == 'priceAsc',
                          onSelected: (_) {
                            setState(() {
                              _sortBy = 'priceAsc';
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('السعر: من الأعلى إلى الأقل'),
                          selected: _sortBy == 'priceDesc',
                          onSelected: (_) {
                            setState(() {
                              _sortBy = 'priceDesc';
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('الأكثر شعبية'),
                          selected: _sortBy == 'popular',
                          onSelected: (_) {
                            setState(() {
                              _sortBy = 'popular';
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // أزرار الإجراءات
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _currentPriceRange = RangeValues(0, _maxPrice);
                            _selectedCategory = null;
                            _sortBy = 'latest';
                          });
                        },
                        child: const Text('إعادة تعيين'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          this.setState(() {
                            _priceRange = _currentPriceRange;
                            _selectedCategory = _selectedCategory;
                            _sortBy = _sortBy;
                          });
                          _loadData();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('تطبيق'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBarWithWidget(
        title: 'متجر SAMA',
        actions: [
          // زر تغيير العرض
          IconButton(
            icon: AnimatedIcon(
              icon: AnimatedIcons.list_view,
              progress: _animationController,
            ),
            tooltip: _isGridView ? 'عرض قائمة' : 'عرض شبكة',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
                if (_isGridView) {
                  _animationController.reverse();
                } else {
                  _animationController.forward();
                }
              });
              HapticFeedback.lightImpact();
            },
          ),
          // زر التصفية
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'تصفية',
            onPressed: () => _showFilterDialog(),
          ),
          // زر السلة
          Consumer<CartProvider>(
            builder: (context, cartProvider, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    tooltip: 'سلة التسوق',
                    onPressed: () {
                      Navigator.pushNamed(context, '/cart');
                    },
                  ),
                  if (cartProvider.itemCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${cartProvider.itemCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        backgroundColor: theme.colorScheme.surface,
        color: theme.colorScheme.primary,
        child: Column(
          children: [
            // Search Bar - Using Advanced Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: AdvancedSearchBar(
                controller: _searchController,
                hintText: 'البحث عن منتجات...',
                onChanged: _searchProducts,
                onSubmitted: _searchProducts,
                accentColor: theme.colorScheme.primary,
                showSearchAnimation: true,
                borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
              ),
            ),

            // شريط التصنيفات
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: _isLoading
                  ? _buildCategoryShimmer()
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length + 1, // +1 for "All" option
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildCategoryChip(
                            'الكل',
                            null,
                            _selectedCategory == null,
                          );
                        } else {
                          final category = _categories[index - 1];
                          return _buildCategoryChip(
                            category,
                            category,
                            _selectedCategory == category,
                          );
                        }
                      },
                    ),
            ),

            // عرض المنتجات
            Expanded(
              child: _isLoading
                  ? _buildLoadingShimmer()
                  : Consumer<ProductProvider>(
                      builder: (context, productProvider, _) {
                        final products = productProvider.samaProducts;

                        if (products.isEmpty) {
                          return _buildEmptyState();
                        }

                        return _isGridView
                            ? _buildProductsGrid(products.map((p) => Product.fromProductModel(p)).toList())
                            : _buildProductsList(products.map((p) => Product.fromProductModel(p)).toList());
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // عنصر تصنيف
  Widget _buildCategoryChip(String label, String? value, bool isSelected) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _filterByCategory(value),
        backgroundColor: theme.colorScheme.surface,
        selectedColor: theme.colorScheme.primary.withOpacity(0.15),
        checkmarkColor: theme.colorScheme.primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelStyle: TextStyle(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  // حالة عدم وجود منتجات
  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لم يتم العثور على منتجات',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _isSearching
                ? 'لم يتم العثور على نتائج مطابقة للبحث'
                : 'حاول تغيير معايير التصفية',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة تحميل'),
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // عرض التصنيفات أثناء التحميل
  Widget _buildCategoryShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 5,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        return Container(
          width: 80,
          height: 32,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
          ),
          child: const ShimmerLoading(),
        );
      },
    );
  }

  // تحميل المنتجات
  Widget _buildLoadingShimmer() {
    return _isGridView
        ? MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            padding: const EdgeInsets.all(16),
            itemCount: 6,
            itemBuilder: (context, index) {
              // جعل بعض العناصر أطول من غيرها للحصول على مظهر متدرج
              final height = index.isEven ? 230.0 : 270.0;
              return Container(
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
                ),
                child: const ShimmerLoading(),
              );
            },
          )
        : ListView.builder(
            itemCount: 4,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              return Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
                ),
                child: const ShimmerLoading(),
              );
            },
          );
  }

  // عرض المنتجات كشبكة - استخدام LuxuryProductCard بدلاً من ProductCard
  Widget _buildProductsGrid(List<Product> products) {
    return AnimationLimiter(
      child: MasonryGridView.count(
        controller: _scrollController,
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            columnCount: 2,
            duration: const Duration(milliseconds: 500),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: LuxuryProductCard(
                  product: products[index],
                  onTap: () => _viewProductDetails(products[index]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // عرض المنتجات كقائمة - قمنا بتعديل طريقة العرض باستخدام LuxuryProductCard
  Widget _buildProductsList(List<Product> products) {
    return AnimationLimiter(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final hasPrice = product.price > 0;
          final hasStock = product.stock > 0;

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 500),
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () => _viewProductDetails(product),
                    borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Product Image
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(StyleSystem.radiusLarge),
                              bottomRight: Radius.circular(StyleSystem.radiusLarge),
                            ),
                            child: SizedBox(
                              width: 120,
                              height: 120,
                              child: product.imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: product.imageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Icon(
                                        Icons.image_not_supported,
                                        size: 40,
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                      ),
                                    )
                                  : Container(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      child: Center(
                                        child: Icon(
                                          Icons.image,
                                          size: 40,
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                            ),
                          ),

                          // Product Details
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Product Name
                                  Text(
                                    product.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  // Category if available
                                  if (product.category != null && product.category!.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        product.category!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 8),

                                  // Only show price and stock if both are available
                                  if (hasPrice && hasStock)
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${product.price.toStringAsFixed(2)} جنيه',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'متوفر',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
        },
      ),
    );
  }

  // عرض تفاصيل المنتج
  void _viewProductDetails(Product product) {
    Navigator.pushNamed(
      context,
      '/product-details',
      arguments: product.id,
    );
  }
}
