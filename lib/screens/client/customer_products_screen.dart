import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/models/voucher_model.dart';
import 'package:smartbiztracker_new/providers/simplified_product_provider.dart';
import 'package:smartbiztracker_new/providers/app_settings_provider.dart';
import 'package:smartbiztracker_new/providers/customer_cart_provider.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/client/quantity_selection_dialog.dart';
import 'package:smartbiztracker_new/utils/show_snackbar.dart';
import 'package:smartbiztracker_new/screens/client/customer_cart_screen.dart';
import 'enhanced_voucher_products_screen.dart';

class CustomerProductsScreen extends StatefulWidget {

  const CustomerProductsScreen({
    super.key,
    this.voucherContext,
  });
  final Map<String, dynamic>? voucherContext;

  @override
  State<CustomerProductsScreen> createState() => _CustomerProductsScreenState();
}

class _CustomerProductsScreenState extends State<CustomerProductsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabAnimationController;
  late AnimationController _searchAnimationController;
  late Animation<double> _fabAnimation;
  late Animation<double> _searchAnimation;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  bool _isSearchExpanded = false;
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadProducts();
    _setupScrollListener();
  }

  void _initializeAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    );

    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      final shouldShowFab = _scrollController.offset > 200;
      if (shouldShowFab != _showFab) {
        setState(() {
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

  Future<void> _loadProducts() async {
    final productProvider = Provider.of<SimplifiedProductProvider>(context, listen: false);
    await productProvider.loadProducts();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
    });

    if (_isSearchExpanded) {
      _searchAnimationController.forward();
    } else {
      _searchAnimationController.reverse();
      _searchController.clear();
      _onSearchChanged('');
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<ProductModel> _getFilteredProducts(List<ProductModel> products) {
    // Filter out products with no stock
    var filteredProducts = products.where((product) => product.quantity > 0).toList();

    // Filter for featured products only
    filteredProducts = filteredProducts.where((product) {
      return product.category.toLowerCase().contains('مميز') ||
             product.category.toLowerCase().contains('featured') ||
             product.category.toLowerCase().contains('مختار') ||
             product.name.toLowerCase().contains('مميز');
    }).toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredProducts = filteredProducts.where((product) {
        return product.name.toLowerCase().contains(_searchQuery) ||
               product.description.toLowerCase().contains(_searchQuery) ||
               product.category.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    return filteredProducts;
  }

  void _addToCart(ProductModel product) {
    // Check if product is available
    if (product.quantity <= 0) {
      ShowSnackbar.show(
        context,
        'هذا المنتج غير متوفر حالياً',
        isError: true,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Show quantity selection dialog
    showDialog(
      context: context,
      builder: (context) => QuantitySelectionDialog(
        product: product,
        onQuantitySelected: (quantity) {
          final cartProvider = Provider.of<CustomerCartProvider>(context, listen: false);
          cartProvider.addToCart(product, quantity: quantity);

          ShowSnackbar.show(
            context,
            'تم إضافة $quantity من ${product.name} إلى السلة',
            isError: false,
            duration: const Duration(seconds: 2),
          );
        },
      ),
    );
  }

  void _showProductDetails(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildProductDetailsSheet(product),
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _searchAnimationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If voucher context is provided, redirect to enhanced voucher products screen
    if (widget.voucherContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final voucherData = widget.voucherContext!['voucherContext'];
        Navigator.pushReplacementNamed(
          context,
          '/enhanced-voucher-products',
          arguments: {
            'voucher': voucherData['voucher'],
            'clientVoucher': voucherData['clientVoucher'],
            'clientVoucherId': voucherData['clientVoucherId'],
            'highlightEligible': (voucherData['highlightEligible'] as bool?) ?? true,
            'filterByEligibility': (voucherData['filterByEligibility'] as bool?) ?? false,
          },
        );
      });
    }

    return Scaffold(
      backgroundColor: StyleSystem.backgroundDark,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildCustomerProfileSection(),
          _buildSearchBar(),
          _buildProductsGrid(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildBackToTopButton(),
          const SizedBox(height: 16),
          _buildFloatingActionButton(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return Consumer<CustomerCartProvider>(
      builder: (context, cartProvider, child) {
        return SliverAppBar(
          expandedHeight: 180, // Increased height to prevent SAMA header clipping
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: FlexibleSpaceBar(
              title: Text(
                'SAMA',
                style: AccountantThemeConfig.headlineLarge.copyWith(
                  fontSize: 28, // Reduced from 32 to prevent overflow
                  fontWeight: FontWeight.bold,
                  foreground: Paint()
                    ..shader = AccountantThemeConfig.greenGradient.createShader(
                      const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                    ),
                ),
              ),
              centerTitle: true,
              titlePadding: const EdgeInsets.only(
                bottom: 20, // Increased bottom padding for better visibility
                left: 16,
                right: 16,
              ),
            ),
          ),
          actions: [
            // Search toggle button
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _toggleSearch,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _isSearchExpanded ? Icons.close : Icons.search,
                    key: ValueKey(_isSearchExpanded),
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Cart button with badge
            Container(
              margin: const EdgeInsets.only(right: 16, left: 8),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CustomerCartScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (cartProvider.itemCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: StyleSystem.errorGradient,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: StyleSystem.shadowSmall,
                        ),
                        child: Text(
                          '${cartProvider.itemCount}',
                          style: StyleSystem.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ).animate().scale(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.elasticOut,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomerProfileSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Row(
          children: [
            // Customer circular initial icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                shape: BoxShape.circle,
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: Center(
                child: Text(
                  'C', // Default customer initial - can be dynamic later
                  style: AccountantThemeConfig.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Customer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحباً بك',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'عميل كريم',
                    style: AccountantThemeConfig.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Widget button positioned at far right
            Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: IconButton(
                onPressed: () {
                  // Widget button action - can be customized
                },
                icon: const Icon(
                  Icons.widgets_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                tooltip: 'الأدوات',
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _searchAnimation,
        builder: (context, child) {
          return Container(
            height: _isSearchExpanded ? 80 : 0,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _searchAnimation.value,
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        StyleSystem.surfaceDark,
                        StyleSystem.surfaceDark.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: StyleSystem.primaryColor.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: StyleSystem.primaryColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: StyleSystem.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن المنتجات...',
                      hintStyle: StyleSystem.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              StyleSystem.primaryColor,
                              StyleSystem.secondaryColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
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

  Widget _buildProductsGrid() {
    return Consumer2<SimplifiedProductProvider, AppSettingsProvider>(
      builder: (context, productProvider, settingsProvider, child) {
        if (productProvider.isLoading) {
          return const SliverToBoxAdapter(
            child: CustomLoader(message: 'جاري تحميل المنتجات...'),
          );
        }

        if (productProvider.error != null) {
          return SliverToBoxAdapter(
            child: _buildErrorState(productProvider.error!),
          );
        }

        final filteredProducts = _getFilteredProducts(productProvider.products);

        if (filteredProducts.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildEmptyState(),
          );
        }

        // Use LayoutBuilder to get screen constraints and prevent overflow
        return SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final padding = 12.0;
              final spacing = 12.0;
              final availableWidth = screenWidth - (padding * 2) - spacing;
              final itemWidth = availableWidth / 2;
              final itemHeight = itemWidth / 0.88; // Maintain aspect ratio

              return Container(
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.88,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _buildProductCard(product, settingsProvider)
                        .animate(delay: (index * 50).ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.2, curve: Curves.easeOutBack);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductCard(ProductModel product, AppSettingsProvider settingsProvider) {
    return Consumer<CustomerCartProvider>(
      builder: (context, cartProvider, child) {
        final isInCart = cartProvider.isInCart(product.id);

        return Container(
          decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
            border: AccountantThemeConfig.glowBorder(
              isInCart
                ? AccountantThemeConfig.primaryGreen
                : AccountantThemeConfig.accentBlue
            ),
            boxShadow: isInCart
              ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
              : AccountantThemeConfig.cardShadows,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => _showProductDetails(product),
              borderRadius: BorderRadius.circular(20),
              splashColor: StyleSystem.primaryColor.withValues(alpha: 0.1),
              highlightColor: StyleSystem.primaryColor.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(8), // Reduced padding from 12 to 8 to prevent overflow
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image - Enhanced for featured products
                    Expanded(
                      flex: 5, // Reduced from 6 to give more space for content
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12), // Reduced radius
                          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildProductImage(product),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8), // Reduced spacing

                    // Product Name
                    Text(
                      product.name,
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14, // Reduced font size to prevent overflow
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 6), // Reduced spacing

                    // Price display for clients - Show both pending pricing and actual price
                    if (product.price > 0) ...[
                      if (settingsProvider.showPricesToPublic) ...[
                        // Normal price display when prices are public
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AccountantThemeConfig.greenGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.attach_money,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${product.price.toStringAsFixed(0)} ج.م',
                                style: AccountantThemeConfig.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Show both pending pricing message AND actual price
                        Column(
                          children: [
                            // Pending pricing indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 10,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'في انتظار التسعير',
                                    style: AccountantThemeConfig.bodySmall.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Current price display
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: AccountantThemeConfig.greenGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${product.price.toStringAsFixed(0)} ج.م',
                                    style: AccountantThemeConfig.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                    ] else
                      const SizedBox(height: 8), // Maintain spacing when price is zero

                    // Add to Cart Button - Enhanced styling
                    SizedBox(
                      width: double.infinity,
                      height: 36, // Reduced height from 40 to 36
                      child: ElevatedButton(
                        onPressed: () => _addToCart(product),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isInCart
                              ? AccountantThemeConfig.primaryGreen
                              : AccountantThemeConfig.accentBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10), // Reduced radius
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isInCart ? Icons.check_rounded : Icons.add_shopping_cart_rounded,
                              size: 16, // Reduced icon size
                            ),
                            const SizedBox(width: 6), // Reduced spacing
                            Flexible( // Added Flexible to prevent text overflow
                              child: Text(
                                isInCart ? 'في السلة' : 'أضف للسلة',
                                style: AccountantThemeConfig.bodyMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12, // Reduced font size
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
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
        );
      },
    );
  }

  Widget _buildProductImage(ProductModel product) {
    final imageUrl = product.bestImageUrl;
    if (imageUrl.isNotEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              StyleSystem.primaryColor.withValues(alpha: 0.05),
              StyleSystem.accentColor.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover, // Better image display for featured products
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AccountantThemeConfig.primaryGreen,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تحميل الصورة...',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            // Enhanced error logging
            print('❌ خطأ في تحميل صورة المنتج المميز: $url');
            print('❌ تفاصيل الخطأ: $error');

            return Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_rounded,
                      size: 40,
                      color: AccountantThemeConfig.accentBlue,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'صورة غير متاحة',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                        fontSize: 12,
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
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.star_rounded,
                size: 48,
                color: AccountantThemeConfig.primaryGreen,
              ),
              const SizedBox(height: 8),
              Text(
                'منتج مميز',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildBackToTopButton() {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        final showButton = _scrollController.hasClients && _scrollController.offset > 200;

        return AnimatedOpacity(
          opacity: showButton ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: AnimatedScale(
            scale: showButton ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    StyleSystem.primaryColor,
                    StyleSystem.secondaryColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: StyleSystem.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                heroTag: 'scroll_to_top_customer_products',
                mini: true,
                onPressed: showButton ? _scrollToTop : null,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer<CustomerCartProvider>(
      builder: (context, cartProvider, child) {
        if (cartProvider.itemCount == 0) return const SizedBox.shrink();

        return AnimatedBuilder(
          animation: _fabAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _fabAnimation.value,
              child: FloatingActionButton.extended(
                heroTag: 'cart_fab_customer_products',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerCartScreen(),
                    ),
                  );
                },
                backgroundColor: StyleSystem.primaryColor,
                foregroundColor: Colors.white,
                elevation: 8,
                icon: const Icon(Icons.shopping_cart_rounded),
                label: Text(
                  'السلة (${cartProvider.itemCount})',
                  style: StyleSystem.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StyleSystem.primaryColor.withValues(alpha: 0.1),
                  StyleSystem.accentColor.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.inventory_2_outlined,
              size: 64,
              color: StyleSystem.primaryColor,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            _searchQuery.isNotEmpty
                ? 'لا توجد نتائج للبحث'
                : 'لا توجد منتجات متاحة',
            style: StyleSystem.headlineSmall.copyWith(
              color: StyleSystem.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            _searchQuery.isNotEmpty
                ? 'جرب البحث بكلمات مختلفة'
                : 'سيتم عرض المنتجات هنا عند توفرها',
            style: StyleSystem.bodyMedium.copyWith(
              color: StyleSystem.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
              icon: const Icon(Icons.clear_rounded),
              label: const Text('مسح البحث'),
              style: ElevatedButton.styleFrom(
                backgroundColor: StyleSystem.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: StyleSystem.errorGradient,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'حدث خطأ',
            style: StyleSystem.headlineSmall.copyWith(
              color: StyleSystem.errorColor,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            error,
            style: StyleSystem.bodyMedium.copyWith(
              color: StyleSystem.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: StyleSystem.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  Widget _buildProductDetailsSheet(ProductModel product) {
    return Consumer2<CustomerCartProvider, AppSettingsProvider>(
      builder: (context, cartProvider, settingsProvider, child) {
        final isInCart = cartProvider.isInCart(product.id);

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    StyleSystem.surfaceDark,
                    StyleSystem.backgroundDark,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: StyleSystem.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: StyleSystem.primaryColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Image
                          Container(
                            height: 250,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: StyleSystem.shadowSmall,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _buildProductImage(product),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Product Name
                          Text(
                            product.name,
                            style: StyleSystem.headlineMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  StyleSystem.primaryColor,
                                  StyleSystem.secondaryColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              product.category,
                              style: StyleSystem.labelMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Description
                          if (product.description.isNotEmpty) ...[
                            Text(
                              'وصف المنتج',
                              style: StyleSystem.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: StyleSystem.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: StyleSystem.primaryColor.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                product.description,
                                style: StyleSystem.bodyLarge.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ] else ...[
                            // إذا لم يكن هناك وصف، أضف رسالة بديلة
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: StyleSystem.primaryColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: StyleSystem.primaryColor.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: StyleSystem.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'لا يوجد وصف متاح لهذا المنتج',
                                      style: StyleSystem.bodyMedium.copyWith(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Add to Cart Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                _addToCart(product);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isInCart
                                    ? StyleSystem.successColor
                                    : StyleSystem.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isInCart ? Icons.check_rounded : Icons.add_shopping_cart_rounded,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    isInCart ? 'تم الإضافة للسلة' : 'أضف إلى السلة',
                                    style: StyleSystem.titleMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}