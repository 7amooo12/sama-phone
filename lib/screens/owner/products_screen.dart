import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/widgets/common/advanced_search_bar.dart';
import 'package:smartbiztracker_new/widgets/unified_product_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:flutter/rendering.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = true;
  bool _showStats = true;
  bool _showZeroQuantityProducts = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupScrollController();
    
    // تحميل المنتجات من SAMA API
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final productProvider = Provider.of<ProductProvider>(context, listen: false);
        productProvider.setUseSamaAdmin(true); // مفعل استخدام SAMA Admin API
        
        AppLogger.info('بدء تحميل المنتجات من SAMA Admin API');
        await productProvider.loadSamaAdminProductsWithToJSON(); // استخدام طريقة toJSON لمعالجة استجابة API بشكل أفضل
        
        // تحقق من عدد المنتجات المحملة
        final productsCount = productProvider.samaAdminProducts.length;
        AppLogger.info('تم تحميل $productsCount منتج من SAMA Admin API');
        
        // إذا لم يتم تحميل أي منتجات، حاول مرة أخرى
        if (productsCount == 0) {
          AppLogger.warning('لم يتم تحميل أي منتجات، محاولة إعادة التحميل...');
          await productProvider.loadSamaAdminProductsWithToJSON();
        }
      } catch (e) {
        AppLogger.error('خطأ في تحميل المنتجات من SAMA API', e);
      }
    });
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_showStats) {
          setState(() {
            _showStats = false;
          });
        }
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_showStats && _scrollController.position.pixels <= 50) {
          setState(() {
            _showStats = true;
          });
        }
      }
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
    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.user;

    if (userModel == null) {
      // Handle case where user is not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomAppBar(
          title: 'المنتجات (SAMA)',
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          hideStatusBarHeader: true,
          actions: [
            IconButton(
              icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
              },
              tooltip: _isGridView ? 'عرض قائمة' : 'عرض شبكة',
            ),
            IconButton(
              icon: Icon(_showZeroQuantityProducts ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() {
                  _showZeroQuantityProducts = !_showZeroQuantityProducts;
                });
              },
              tooltip: _showZeroQuantityProducts ? 'إخفاء المنتجات بدون رصيد' : 'إظهار المنتجات بدون رصيد',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                final productProvider = Provider.of<ProductProvider>(context, listen: false);
                productProvider.setUseSamaAdmin(true); // تفعيل استخدام SAMA Admin API
                await productProvider.loadSamaAdminProductsWithToJSON(); // استخدام طريقة toJSON للتعامل مع استجابة API بشكل أفضل
                
                // عرض رسالة نجاح التحديث
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تحديث بيانات المنتجات بنجاح'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              tooltip: 'تحديث المنتجات',
            ),
          ],
        ),
      ),
      drawer: MainDrawer(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        currentRoute: AppRoutes.ownerProducts,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, _) {
          // Use SAMA Admin products instead of regular products
          final products = productProvider.samaAdminProducts;
          final isLoading = productProvider.isLoading;
          final errorMessage = productProvider.error;

          // Filter products based on search query
          final filteredBySearch = _searchQuery.isEmpty
              ? products
              : products.where((product) =>
                  product.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          
          // Filter out zero quantity products if needed
          final displayProducts = _showZeroQuantityProducts || _searchQuery.isNotEmpty
              ? filteredBySearch
              : filteredBySearch.where((product) => product.quantity > 0).toList();

          return Column(
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

              // Collapsible Product Statistics
              if (_showStats)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _showStats ? null : 0,
                  child: CollapsibleProductStats(
                    totalProducts: products.length,
                    availableProducts: products.where((p) => p.quantity > 0).length,
                    unavailableProducts: products.where((p) => p.quantity == 0).length,
                    lowStockProducts: products.where((p) => p.quantity <= 5 && p.quantity > 0).length,
                    onViewAdminPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.adminProductsView);
                    },
                  ),
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
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline, 
                            color: theme.colorScheme.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'البيانات مزامنة من متجر SAMA (API)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!_showZeroQuantityProducts && products.where((p) => p.quantity == 0).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_off,
                                color: theme.colorScheme.secondary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'يوجد ${products.where((p) => p.quantity == 0).length} منتج مخفي (اضغط على أيقونة العين لإظهارها)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontSize: 11,
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

              // Products list
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
                                        productProvider.loadSamaAdminProductsWithToJSON();
                                      },
                                      child: const Text('إعادة المحاولة'),
                                    ),
                                  ],
                                ),
                              )
                            : displayProducts.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.search_off,
                                          size: 64,
                                          color: theme.colorScheme.primary.withOpacity(0.6),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'لا توجد منتجات مطابقة لمعايير البحث',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: () async {
                                      productProvider.setUseSamaAdmin(true);
                                      await productProvider.loadSamaAdminProductsWithToJSON();
                                    },
                                    child: _isGridView
                                        ? _buildGridView(displayProducts, _scrollController)
                                        : _buildListView(displayProducts, _scrollController),
                                  ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show add new product dialog
          _showAddProductDialog(context);
        },
        tooltip: 'إضافة منتج جديد',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Grid view for products
  Widget _buildGridView(List<ProductModel> products, ScrollController scrollController) {
    return AnimationLimiter(
      child: GridView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            columnCount: 2,
            duration: const Duration(milliseconds: 375),
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildProductCard(
                  name: products[index].name,
                  price: products[index].price,
                  quantity: products[index].quantity,
                  onTap: () {
                    _showProductDetails(context, products[index]);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // List view for products
  Widget _buildListView(List<ProductModel> products, ScrollController scrollController) {
    return AnimationLimiter(
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildProductCard(
                  name: products[index].name,
                  price: products[index].price,
                  quantity: products[index].quantity,
                  onTap: () {
                    _showProductDetails(context, products[index]);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Show product details dialog
  void _showProductDetails(BuildContext context, ProductModel product) {
    // استخدام bestImageUrl getter للحصول على الصورة بالمسار الصحيح
    final imageUrl = product.bestImageUrl;
    AppLogger.info('عرض تفاصيل المنتج: ${product.name} - صورة: $imageUrl');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) {
                    AppLogger.error('خطأ في تحميل صورة المنتج: $url - $error');
                    return Icon(
                      Icons.image_not_supported,
                      color: Colors.grey.shade400,
                      size: 50,
                    );
                  },
                ),
              const SizedBox(height: 16),
              Text(product.description),
              const SizedBox(height: 16),
              Text('الفئة: ${product.category}'),
              Text('الكمية المتوفرة: ${product.quantity}'),
              Text('سعر الشراء: ${product.purchasePrice ?? 'غير متاح'} جنيه'),
              Text('سعر البيع: ${product.price} جنيه'),
              if (product.purchasePrice != null && product.purchasePrice! > 0)
                Text('الربح: ${(product.price - product.purchasePrice!).toStringAsFixed(2)} جنيه (${((product.price / product.purchasePrice! - 1) * 100).toStringAsFixed(1)}%)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditProductDialog(context, product);
            },
            child: const Text('تعديل'),
          ),
        ],
      ),
    );
  }

  // Show edit product dialog
  void _showEditProductDialog(BuildContext context, ProductModel product) {
    // For now just show a placeholder dialog
    // In the future, you can implement a full edit form
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل ${product.name}'),
        content: const Text('خاصية التعديل ستكون متاحة قريبًا'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // Show add product dialog
  void _showAddProductDialog(BuildContext context) {
    // For now just show a placeholder dialog
    // In the future, you can implement a full add form
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة منتج جديد'),
        content: const Text('خاصية إضافة منتج جديد ستكون متاحة قريبًا'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // Build product card placeholder - replaced by CollapsibleProductStats

  Widget _buildProductCard({
    required String name,
    required double price,
    required int quantity,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image with CachedNetworkImage
            Consumer<ProductProvider>(
              builder: (context, productProvider, _) {
                final product = productProvider.samaAdminProducts.firstWhere(
                  (p) => p.name == name,
                  orElse: () => ProductModel(
                    id: '',
                    name: name,
                    description: '',
                    price: price,
                    quantity: quantity,
                    category: '',
                    images: [],
                    sku: '',
                    isActive: true,
                    createdAt: DateTime.now(),
                    reorderPoint: 0,
                  ),
                );

                // استخدام bestImageUrl للحصول على الصورة بشكل صحيح من SAMA API
                String imageUrl = product.bestImageUrl;
                
                return ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: imageUrl.isNotEmpty && !imageUrl.contains('placeholder.com')
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary,
                                ),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            AppLogger.error('خطأ في تحميل الصورة: $url - $error');
                            return Container(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported,
                                      size: 30,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'الصورة غير متوفرة',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          // Optimize memory usage
                          memCacheWidth: 300,
                          maxWidthDiskCache: 600,
                          fadeOutDuration: const Duration(milliseconds: 300),
                          fadeInDuration: const Duration(milliseconds: 700),
                        )
                      : Container(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory,
                                  size: 40,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'لا توجد صورة',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                );
              },
            ),

            // Product details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${price.toStringAsFixed(2)} جنيه',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 14,
                        color: quantity > 10
                            ? Colors.green
                            : quantity > 0
                                ? Colors.orange
                                : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'المخزون: $quantity',
                        style: theme.textTheme.bodySmall,
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
}

class CollapsibleProductStats extends StatefulWidget {
  final int totalProducts;
  final int availableProducts;
  final int unavailableProducts;
  final int lowStockProducts;
  final VoidCallback onViewAdminPressed;

  const CollapsibleProductStats({
    Key? key,
    required this.totalProducts,
    required this.availableProducts,
    required this.unavailableProducts,
    required this.lowStockProducts,
    required this.onViewAdminPressed,
  }) : super(key: key);

  @override
  State<CollapsibleProductStats> createState() => _CollapsibleProductStatsState();
}

class _CollapsibleProductStatsState extends State<CollapsibleProductStats> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'إحصائيات المنتجات',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),

              // Expandable content
              if (_isExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        context,
                        'إجمالي المنتجات',
                        widget.totalProducts.toString(),
                        Icons.inventory_2,
                        theme.colorScheme.primary,
                      ),
                      _buildStatItem(
                        context,
                        'متوفر',
                        widget.availableProducts.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _buildStatItem(
                        context,
                        'غير متوفر',
                        widget.unavailableProducts.toString(),
                        Icons.cancel,
                        Colors.red,
                      ),
                      _buildStatItem(
                        context,
                        'بحاجة للتجديد',
                        widget.lowStockProducts.toString(),
                        Icons.warning,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ElevatedButton.icon(
                    onPressed: widget.onViewAdminPressed,
                    icon: const Icon(Icons.inventory),
                    label: const Text('عرض المنتجات (واجهة الإدارة)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      minimumSize: const Size(200, 45),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
