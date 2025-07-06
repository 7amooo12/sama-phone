import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/simplified_product_provider.dart';
import '../../providers/client_orders_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../services/client_orders_service.dart' as client_service;
import '../../utils/app_logger.dart';
import '../../utils/accountant_theme_config.dart';
import '../../widgets/client/product_details_sheet.dart';
import '../../widgets/client/quantity_selection_dialog.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/optimized_image.dart';
import '../../widgets/common/enhanced_product_image.dart';
import '../../screens/client/shopping_cart_screen.dart';

class EnhancedProductsBrowser extends StatefulWidget {
  const EnhancedProductsBrowser({super.key});

  @override
  State<EnhancedProductsBrowser> createState() => _EnhancedProductsBrowserState();
}

class _EnhancedProductsBrowserState extends State<EnhancedProductsBrowser> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isGridView = true;
  String _sortBy = 'name';
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScrollChanged);
  }

  void _onScrollChanged() {
    final showScrollToTop = _scrollController.offset > 200;
    if (showScrollToTop != _showScrollToTop) {
      setState(() {
        _showScrollToTop = showScrollToTop;
      });
    }
  }

  void _addToCart(ProductModel product) {
    // Null safety checks
    if (product.id.isEmpty) {
      _showSnackBar('خطأ: معرف المنتج غير صحيح', AccountantThemeConfig.dangerRed);
      return;
    }

    // Check if product is available
    if (product.quantity <= 0) {
      _showSnackBar('هذا المنتج غير متوفر حالياً', AccountantThemeConfig.dangerRed);
      return;
    }

    // Show quantity selection dialog
    showDialog(
      context: context,
      builder: (context) => QuantitySelectionDialog(
        product: product,
        onQuantitySelected: (quantity) {
          try {
            final cartProvider = Provider.of<ClientOrdersProvider>(context, listen: false);

            // Set product provider for stock validation
            final productProvider = Provider.of<SimplifiedProductProvider>(context, listen: false);
            cartProvider.setProductProvider(productProvider);

            final cartItem = client_service.CartItem(
              productId: product.id.toString(),
              productName: product.name.isNotEmpty ? product.name : 'منتج غير محدد',
              productImage: product.bestImageUrl.isNotEmpty ? product.bestImageUrl : '',
              price: product.price,
              quantity: quantity,
              category: product.category.isNotEmpty ? product.category : 'غير محدد',
            );

            final success = cartProvider.addToCart(cartItem);

            if (success) {
              _showSnackBar('تم إضافة $quantity من ${product.name} للسلة', AccountantThemeConfig.primaryGreen);
            } else {
              _showSnackBar(cartProvider.error ?? 'فشل في إضافة المنتج للسلة', AccountantThemeConfig.dangerRed);
            }
          } catch (e) {
            AppLogger.error('خطأ في إضافة المنتج للسلة', e);
            _showSnackBar('حدث خطأ في إضافة المنتج للسلة', AccountantThemeConfig.dangerRed);
          }
        },
      ),
    );
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Helper method to get properly formatted image URL like the working product details screen
  String _getProductImageUrl(ProductModel product) {
    // Check main image URL first
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      final imageUrl = product.imageUrl!;
      if (imageUrl.startsWith('http')) {
        return imageUrl;
      } else {
        return 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
      }
    }

    // Check additional images
    for (final image in product.images) {
      if (image.isNotEmpty) {
        final imageUrl = image.startsWith('http')
            ? image
            : 'https://samastock.pythonanywhere.com/static/uploads/$image';
        return imageUrl;
      }
    }

    // Return placeholder if no images found
    return 'https://via.placeholder.com/400x400/E0E0E0/757575?text=لا+توجد+صورة';
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterProducts();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final productProvider = Provider.of<SimplifiedProductProvider>(context, listen: false);
      await productProvider.loadProducts();

      _allProducts = productProvider.products;
      _categories = _extractCategories(_allProducts);
      _filterProducts();

      AppLogger.info('تم تحميل ${_allProducts.length} منتج بنجاح');

      // إظهار رسالة نجاح إذا كان هناك خطأ سابق
      if (productProvider.hasNetworkError && _allProducts.isNotEmpty) {
        _showSnackBar('تم تحميل البيانات المحفوظة محلياً', Colors.orange);
      }
    } catch (e) {
      AppLogger.error('خطأ في تحميل المنتجات', e);
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _showErrorDialog(String error) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('خطأ في التحميل'),
          content: Text(_getErrorMessage(error)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('موافق'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadData();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('Failed host lookup') || error.contains('No address associated with hostname')) {
      return 'لا يمكن الاتصال بالخادم. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';
    } else if (error.contains('Connection refused') || error.contains('Connection timed out')) {
      return 'انتهت مهلة الاتصال. يرجى المحاولة لاحقاً.';
    } else if (error.contains('SocketException')) {
      return 'خطأ في الشبكة. تحقق من اتصالك بالإنترنت.';
    } else {
      return 'حدث خطأ في تحميل المنتجات. يرجى المحاولة مرة أخرى.';
    }
  }

  List<String> _extractCategories(List<ProductModel> products) {
    final categories = products
        .map((p) => p.category)
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  void _filterProducts() {
    _filteredProducts = _allProducts.where((product) {
      // Null safety checks
      if (product.id.isEmpty) return false;

      final productName = product.name ?? '';
      final productDescription = product.description ?? '';
      final productCategory = product.category ?? '';

      final matchesSearch = _searchQuery.isEmpty ||
          productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          productDescription.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == null ||
          productCategory == _selectedCategory;

      // Filter out zero stock products for client view
      final hasStock = product.quantity > 0;

      return matchesSearch && matchesCategory && hasStock;
    }).toList();

    _sortProducts();
  }

  void _sortProducts() {
    try {
      switch (_sortBy) {
        case 'name':
          _filteredProducts.sort((a, b) {
            final nameA = a.name ?? '';
            final nameB = b.name ?? '';
            return nameA.compareTo(nameB);
          });
          break;
        case 'stock':
          _filteredProducts.sort((a, b) => b.quantity.compareTo(a.quantity));
          break;
      }
    } catch (e) {
      AppLogger.error('خطأ في ترتيب المنتجات', e);
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomAppBar(
          title: 'تصفح المنتجات',
          hideStatusBarHeader: true,
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(8),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: IconButton(
                icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
                onPressed: () => setState(() => _isGridView = !_isGridView),
                tooltip: _isGridView ? 'عرض قائمة' : 'عرض شبكة',
                color: Colors.white,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.blueGradient,
                borderRadius: BorderRadius.circular(8),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.sort, color: Colors.white),
                onSelected: (value) => setState(() {
                  _sortBy = value;
                  _sortProducts();
                }),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'name', child: Text('ترتيب بالاسم')),
                  const PopupMenuItem(value: 'stock', child: Text('حسب التوفر')),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: Column(
          children: [
            _buildSearchAndFilters(theme),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AccountantThemeConfig.primaryGreen))
                  : _filteredProducts.isEmpty
                      ? _buildEmptyState(theme)
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AccountantThemeConfig.primaryGreen,
                          child: _isGridView
                              ? _buildGridView(theme)
                              : _buildListView(theme),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        children: [
          // شريط البحث
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
            ),
            child: TextField(
              controller: _searchController,
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن المنتجات...',
                hintStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: AccountantThemeConfig.primaryGreen),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _filterProducts();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: false,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // فلتر الفئات
          if (_categories.isNotEmpty)
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildCategoryChip(
                      theme,
                      'الكل',
                      _selectedCategory == null,
                      () => setState(() {
                        _selectedCategory = null;
                        _filterProducts();
                      }),
                    );
                  }

                  final category = _categories[index - 1];
                  return _buildCategoryChip(
                    theme,
                    category,
                    _selectedCategory == category,
                    () => setState(() {
                      _selectedCategory = category;
                      _filterProducts();
                    }),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(ThemeData theme, String label, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? AccountantThemeConfig.greenGradient
                : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
            borderRadius: BorderRadius.circular(25),
            border: isSelected
                ? null
                : AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
            boxShadow: isSelected
                ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                : null,
          ),
          child: Text(
            label,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: AccountantThemeConfig.transparentCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                shape: BoxShape.circle,
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: const Icon(
                Icons.search_off,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد منتجات مطابقة',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'جرب تغيير معايير البحث أو الفلتر',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(ThemeData theme) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Added bottom padding for FABs
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65, // Reduced from 0.75 to give more height for cart button
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        return _buildProductCard(_filteredProducts[index], theme);
      },
    );
  }

  Widget _buildListView(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Added bottom padding for FABs
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        return _buildProductListTile(_filteredProducts[index], theme);
      },
    );
  }

  Widget _buildProductCard(ProductModel product, ThemeData theme) {
    final isAvailable = product.quantity > 0;

    return Container(
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        border: AccountantThemeConfig.glowBorder(
          isAvailable
              ? AccountantThemeConfig.primaryGreen
              : AccountantThemeConfig.neutralColor
        ),
        boxShadow: isAvailable
            ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
            : AccountantThemeConfig.cardShadows,
      ),
      child: InkWell(
        onTap: () => _showProductDetails(product, AppSettingsProvider()),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: OptimizedImage(
                    imageUrl: _getProductImageUrl(product),
                    fit: BoxFit.cover,
                    // Remove width: double.infinity to avoid Infinity calculations
                    // The image will fill the available space from the parent Container
                  ),
                ),
              ),
            ),

            // معلومات المنتج - بدون أسعار
            Expanded(
              flex: 3, // Increased from 2 to 3 to give more space for content
              child: Padding(
                padding: const EdgeInsets.all(6), // Reduced padding from 8 to 6
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم المنتج
                    Text(
                      product.name,
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12, // Reduced from 13 to 12
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 3), // Reduced from 4 to 3

                    // الفئة
                    if (product.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Reduced padding
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.blueGradient,
                          borderRadius: BorderRadius.circular(6), // Reduced from 8 to 6
                        ),
                        child: Text(
                          product.category,
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 9, // Reduced from 10 to 9
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    const SizedBox(height: 3), // Reduced from 4 to 3

                    // حالة التوفر
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 10, // Reduced from 12 to 10
                          color: isAvailable
                              ? AccountantThemeConfig.primaryGreen
                              : AccountantThemeConfig.dangerRed,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            isAvailable
                                ? 'متوفر (${product.quantity} قطعة)'
                                : 'غير متوفر',
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: isAvailable
                                  ? AccountantThemeConfig.primaryGreen
                                  : AccountantThemeConfig.dangerRed,
                              fontWeight: FontWeight.w600,
                              fontSize: 9, // Reduced from 10 to 9
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4), // Small spacing

                    // السعر - Price display for clients
                    Consumer<AppSettingsProvider>(
                      builder: (context, settingsProvider, child) {
                        if (settingsProvider.showPricesToPublic && product.price > 0) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: AccountantThemeConfig.greenGradient,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.attach_money,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    '${product.price.toStringAsFixed(0)} ج.م',
                                    style: AccountantThemeConfig.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    const Spacer(), // Use Spacer to push button to bottom

                    // زر إضافة للسلة
                    SizedBox(
                      width: double.infinity,
                      height: 28, // Reduced from 32 to 28
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isAvailable
                              ? AccountantThemeConfig.greenGradient
                              : LinearGradient(
                                  colors: [
                                    AccountantThemeConfig.neutralColor,
                                    AccountantThemeConfig.neutralColor.withValues(alpha: 0.8),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(14), // Reduced from 16 to 14
                          boxShadow: isAvailable
                              ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                              : null,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: isAvailable ? () => _addToCart(product) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Reduced padding
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            isAvailable ? Icons.shopping_cart : Icons.block,
                            color: Colors.white,
                            size: 12, // Reduced from 14 to 12
                          ),
                          label: Text(
                            isAvailable ? 'أضف للسلة' : 'غير متوفر',
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9, // Reduced from 10 to 9
                            ),
                          ),
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

  Widget _buildProductListTile(ProductModel product, ThemeData theme) {
    final isAvailable = product.quantity > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        border: AccountantThemeConfig.glowBorder(
          isAvailable
              ? AccountantThemeConfig.primaryGreen
              : AccountantThemeConfig.neutralColor
        ),
        boxShadow: isAvailable
            ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
            : AccountantThemeConfig.cardShadows,
      ),
      child: InkWell(
        onTap: () => _showProductDetails(product, AppSettingsProvider()),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // صورة المنتج
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: OptimizedImage(
                    imageUrl: _getProductImageUrl(product),
                    fit: BoxFit.cover,
                    width: 80,
                    height: 80,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // معلومات المنتج - بدون أسعار
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم المنتج
                    Text(
                      product.name,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // الفئة
                    if (product.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.blueGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          product.category,
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // حالة التوفر
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isAvailable
                            ? AccountantThemeConfig.greenGradient
                            : LinearGradient(
                                colors: [AccountantThemeConfig.dangerRed, AccountantThemeConfig.dangerRed.withValues(alpha: 0.8)],
                              ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAvailable ? Icons.check_circle : Icons.cancel,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAvailable
                                ? 'متوفر (${product.quantity} قطعة)'
                                : 'غير متوفر',
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // السعر - Price display for clients
                    Consumer<AppSettingsProvider>(
                      builder: (context, settingsProvider, child) {
                        if (settingsProvider.showPricesToPublic && product.price > 0) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AccountantThemeConfig.greenGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.attach_money,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${product.price.toStringAsFixed(0)} ج.م',
                                  style: AccountantThemeConfig.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // أزرار العمليات
              SizedBox(
                width: 100, // Fixed width to prevent overflow
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // Minimize column size
                  children: [
                    // زر إضافة للسلة
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: isAvailable
                            ? AccountantThemeConfig.greenGradient
                            : LinearGradient(
                                colors: [
                                  AccountantThemeConfig.neutralColor,
                                  AccountantThemeConfig.neutralColor.withValues(alpha: 0.8),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(10), // Reduced from 12 to 10
                        boxShadow: isAvailable
                            ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                            : null,
                      ),
                      child: ElevatedButton.icon(
                        onPressed: isAvailable ? () => _addToCart(product) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Reduced padding
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(
                          isAvailable ? Icons.shopping_cart : Icons.block,
                          color: Colors.white,
                          size: 14, // Reduced from 16 to 14
                        ),
                        label: Text(
                          isAvailable ? 'أضف للسلة' : 'غير متوفر',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10, // Reduced from 11 to 10
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6), // Reduced from 8 to 6

                    // زر عرض التفاصيل
                    Container(
                      decoration: BoxDecoration(
                        gradient: AccountantThemeConfig.blueGradient,
                        borderRadius: BorderRadius.circular(10), // Reduced from 12 to 10
                        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16), // Reduced from 18 to 16
                        onPressed: () => _showProductDetails(product, AppSettingsProvider()),
                        tooltip: 'عرض التفاصيل',
                        padding: const EdgeInsets.all(8), // Reduced padding
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
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



  void _showProductDetails(ProductModel product, AppSettingsProvider settingsProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer<AppSettingsProvider>(
        builder: (context, settingsProvider, child) => ProductDetailsSheet(
          product: product,
          showPrice: settingsProvider.showPricesToPublic, // Show prices based on settings
          currencySymbol: 'ج.م', // Use Egyptian Pound symbol
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Consumer<ClientOrdersProvider>(
      builder: (context, cartProvider, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scroll to top FAB
            if (_showScrollToTop)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  shape: BoxShape.circle,
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                ),
                child: FloatingActionButton(
                  heroTag: 'scroll_to_top',
                  onPressed: _scrollToTop,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: const Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

            // Cart FAB
            Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: FloatingActionButton.extended(
                heroTag: 'cart_fab',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ShoppingCartScreen(),
                    ),
                  );
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                      size: 24,
                    ),
                    if (cartProvider.cartItems.isNotEmpty)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AccountantThemeConfig.dangerRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '${cartProvider.cartItems.length}',
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
                ),
                label: const Text(
                  'السلة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
