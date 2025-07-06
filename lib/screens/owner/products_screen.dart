import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/widgets/common/advanced_search_bar.dart';
import 'package:smartbiztracker_new/widgets/common/professional_product_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = true;
  bool _showStats = true;
  bool _showZeroQuantityProducts = false;
  final ScrollController _scrollController = ScrollController();
  bool _showFab = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _setupScrollController();
    _initializeAnimations();

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

  void _setupScrollController() {
    _scrollController.addListener(() {
      final shouldShowStats = _scrollController.offset <= 100;
      final shouldShowFab = _scrollController.offset > 200;

      if (shouldShowStats != _showStats || shouldShowFab != _showFab) {
        setState(() {
          _showStats = shouldShowStats;
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

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // استخدام مزود Supabase أولاً
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final supabaseUser = supabaseProvider.user;

    // استخدام مزود Auth كإجراء احتياطي
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userModel = supabaseUser ?? authProvider.user;

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
              // Search bar - يختفي عند التمرير
              if (_showStats)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _showStats ? null : 0,
                  child: Padding(
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

                    // Floating Action Button for scroll to top
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
              ),
            ],
          );
        },
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
          childAspectRatio: 0.75, // زيادة الارتفاع لاستيعاب المحتوى المحسن
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            columnCount: 2,
            duration: const Duration(milliseconds: 200), // أسرع
            child: ScaleAnimation(
              duration: const Duration(milliseconds: 150), // أسرع
              child: FadeInAnimation(
                duration: const Duration(milliseconds: 150), // أسرع
                child: ProfessionalProductCard(
                  product: products[index],
                  cardType: ProductCardType.owner,
                  onTap: () => _showProductDetails(context, products[index]),
                  currencySymbol: 'جنيه',
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          controller: scrollController,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75, // زيادة الارتفاع لاستيعاب المحتوى المحسن
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return AnimationConfiguration.staggeredGrid(
              position: index,
              columnCount: 2,
              duration: const Duration(milliseconds: 200), // أسرع
              child: SlideAnimation(
                verticalOffset: 30.0, // أقل
                duration: const Duration(milliseconds: 150), // أسرع
                child: FadeInAnimation(
                  duration: const Duration(milliseconds: 150), // أسرع
                  child: ProfessionalProductCard(
                    product: products[index],
                    cardType: ProductCardType.owner,
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
    required ProductModel product,
    VoidCallback? onTap,
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
                Colors.grey.shade50,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
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
              onTap: onTap,
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
                                Colors.grey.shade100,
                                Colors.grey.shade200,
                              ],
                            ),
                          ),
                          child: product.bestImageUrl.isNotEmpty && !product.bestImageUrl.contains('placeholder.com')
                              ? ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: product.bestImageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    placeholder: (context, url) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.grey.shade200,
                                            Colors.grey.shade100,
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
                                                color: Colors.grey.shade600,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) {
                                      AppLogger.error('خطأ في تحميل الصورة: $url - $error');
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.grey.shade200,
                                              Colors.grey.shade300,
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
                                                color: Colors.grey.shade500,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'لا توجد صورة',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    memCacheWidth: 300,
                                    maxWidthDiskCache: 600,
                                    fadeOutDuration: const Duration(milliseconds: 300),
                                    fadeInDuration: const Duration(milliseconds: 700),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.grey.shade200,
                                        Colors.grey.shade300,
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 50,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'منتج ساما',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
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
                                    Colors.green.shade400,
                                    Colors.green.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
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
                                color: Colors.grey.shade800,
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
                                      Colors.green.shade100,
                                      Colors.green.shade50,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      size: 10,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'ربح: ${profit.toStringAsFixed(0)} ج',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
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
}

class CollapsibleProductStats extends StatefulWidget {

  const CollapsibleProductStats({
    super.key,
    required this.totalProducts,
    required this.availableProducts,
    required this.unavailableProducts,
    required this.lowStockProducts,
    required this.onViewAdminPressed,
  });
  final int totalProducts;
  final int availableProducts;
  final int unavailableProducts;
  final int lowStockProducts;
  final VoidCallback onViewAdminPressed;

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
