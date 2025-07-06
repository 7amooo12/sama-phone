import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/services/unified_products_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/effects/lamp_container.dart';
import 'package:smartbiztracker_new/widgets/common/enhanced_product_image.dart';
import 'package:smartbiztracker_new/utils/helpers.dart';

/// Completely rebuilt SAMA Store page with optimized performance,
/// 3D card flip animations, and direct AR integration
class SamaStoreRebuiltScreen extends StatefulWidget {
  const SamaStoreRebuiltScreen({super.key});

  @override
  State<SamaStoreRebuiltScreen> createState() => _SamaStoreRebuiltScreenState();
}

class _SamaStoreRebuiltScreenState extends State<SamaStoreRebuiltScreen>
    with TickerProviderStateMixin {
  
  // Services and Controllers
  final UnifiedProductsService _productsService = UnifiedProductsService();
  final TextEditingController _searchController = TextEditingController();

  // Data State
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  Set<String> _categories = {};
  String? _selectedCategory;
  bool _isLoading = true;
  String _searchQuery = '';
  
  // Performance optimization - simplified animation system
  late AnimationController _mainAnimationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadProducts();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _mainAnimationController.dispose();

    // تنظيف ذاكرة الصور
    _clearImageCache();

    super.dispose();
  }

  /// تنظيف كاش الصور لتوفير الذاكرة
  void _clearImageCache() {
    try {
      // تنظيف كاش الصور المحسن
      OptimizedImageCacheManager.instance.emptyCache();
      AppLogger.info('🧹 تم تنظيف كاش الصور');
    } catch (e) {
      AppLogger.warning('⚠️ خطأ في تنظيف كاش الصور: $e');
    }
  }
  
  void _initializeAnimations() {
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: Curves.easeInOut,
    ));
  }
  

  
  // Card tap functionality disabled - product cards are now purely visual/informational
  // void _handleCardTap(ProductModel product) {
  //   AppLogger.info('🎯 Card tapped: ${product.id} - ${product.name}');
  //
  //   // Haptic feedback for better UX
  //   HapticFeedback.lightImpact();
  //
  //   // Show product details directly
  //   _showProfessionalProductDetails(product);
  // }
  
  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoading = true);

      AppLogger.info('🔄 Loading SAMA Store products from API...');

      final products = await _productsService.getProducts();

      AppLogger.info('📦 Raw products loaded: ${products.length}');

      // Extract unique categories from ProductModel
      final categories = products
          .map((p) => p.category)
          .where((c) => c.isNotEmpty)
          .toSet();

      AppLogger.info('🏷️ Raw categories loaded: ${categories.length}');

      // Debug: Print first few products and categories
      if (products.isNotEmpty) {
        AppLogger.info('📝 Sample product: ${products.first.name}, Category: ${products.first.category}, Stock: ${products.first.quantity}');
      }
      if (categories.isNotEmpty) {
        AppLogger.info('📝 Sample categories: ${categories.take(3).join(', ')}');
      }

      setState(() {
        _products = products;
        _filteredProducts = products;
        _categories = categories;
        _isLoading = false;
      });

      // Apply filtering after loading
      _filterProducts();

      // تحسين الأداء: تحميل مسبق للصور
      _preloadVisibleImages();

      // التحقق من التصميم المتجاوب
      _validateResponsiveDesign();

      // اختبار نظام عرض الصور
      _validateImageDisplaySystem();

      // Start main animation
      _mainAnimationController.forward();

      AppLogger.info('✅ Loaded ${products.length} products with ${categories.length} categories');

    } catch (e) {
      AppLogger.error('❌ Failed to load products: $e');
      setState(() => _isLoading = false);

      _showErrorSnackBar('فشل في تحميل المنتجات: $e');
    }
  }
  
  void _filterProducts() {
    AppLogger.info('🔍 Filtering products - Search: "$_searchQuery", Category: "$_selectedCategory"');
    AppLogger.info('📦 Total products before filtering: ${_products.length}');

    setState(() {
      _filteredProducts = _products.where((product) {
        // Search filtering - check name and description
        final matchesSearch = _searchQuery.isEmpty ||
            product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.description.toLowerCase().contains(_searchQuery.toLowerCase());

        // Category filtering - handle null and "الكل" correctly
        final matchesCategory = _selectedCategory == null ||
            _selectedCategory == 'الكل' ||
            (product.category.isNotEmpty && product.category == _selectedCategory);

        // CRITICAL: Filter out zero stock products for client view
        final hasStock = product.quantity > 0;

        final shouldInclude = matchesSearch && matchesCategory && hasStock;

        if (!shouldInclude) {
          AppLogger.debug('❌ Filtered out: ${product.name} - Search: $matchesSearch, Category: $matchesCategory, Stock: $hasStock (${product.quantity})');
        }

        return shouldInclude;
      }).toList();
    });

    AppLogger.info('✅ Filtered products count: ${_filteredProducts.length}');
  }
  
  void _onSearchChanged(String query) {
    AppLogger.info('🔍 Search query changed: "$query"');
    setState(() {
      _searchQuery = query.trim();
    });
    _filterProducts();
  }

  void _onCategorySelected(String? category) {
    AppLogger.info('🏷️ Category selected: "$category"');
    setState(() {
      // Handle "الكل" (All) category correctly
      if (category == 'الكل') {
        _selectedCategory = null;
      } else {
        _selectedCategory = category;
      }
    });
    _filterProducts();
  }
  
  // Simplified AR experience launch - for now just show info
  Future<void> _launchARExperience(ProductModel product) async {
    try {
      AppLogger.info('🎯 AR experience for product: ${product.name}');

      // Show info dialog for now
      _showSuccessSnackBar('تجربة AR قريباً لمنتج: ${product.name}');

    } catch (e) {
      AppLogger.error('❌ Failed to launch AR experience: $e');
      _showErrorSnackBar('فشل في تشغيل تجربة AR: $e');
    }
  }
  
  Future<String?> _showRoomImageSourceDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.darkBlueBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        ),
        title: Text(
          'اختر صورة المساحة',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'كيف تريد التقاط صورة المساحة لتجربة AR؟',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, 'camera'),
            icon: Icon(Icons.camera_alt, color: AccountantThemeConfig.primaryGreen),
            label: Text(
              'الكاميرا',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.primaryGreen,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, 'gallery'),
            icon: Icon(Icons.photo_library, color: AccountantThemeConfig.primaryGreen),
            label: Text(
              'المعرض',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.primaryGreen,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.warningOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        ),
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder( // CRITICAL FIX: Add LayoutBuilder for proper constraint handling
              builder: (context, constraints) {
                return CustomScrollView(
                  // تحسين أداء التمرير
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  // تحسين الذاكرة
                  cacheExtent: 500, // تقليل المساحة المحفوظة
                  slivers: [
                    // Professional Header with SAMA Branding
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: _buildProfessionalHeader(),
                      ),
                    ),

                    // Enhanced Search and filters
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: _buildEnhancedSearchAndFilters(),
                      ),
                    ),

                    // Products grid or loading/error states with proper constraints
                    _isLoading
                        ? SliverToBoxAdapter(
                            child: RepaintBoundary(
                              child: _buildProfessionalLoadingView(),
                            ),
                          )
                        : _filteredProducts.isEmpty
                            ? SliverToBoxAdapter(
                                child: RepaintBoundary(
                                  child: _buildProfessionalEmptyView(),
                                ),
                              )
                            : _buildProfessionalProductsGrid(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        // Lamp container background
        const RepaintBoundary(
          child: LampContainer(
            title: 'SAMA',
          ),
        ),

        // Back button
        Positioned(
          top: 20,
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Professional header with AccountantThemeConfig styling and SAMA branding
  Widget _buildProfessionalHeader() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 200, // CRITICAL FIX: Ensure minimum height
        maxHeight: 200, // CRITICAL FIX: Prevent infinite height expansion
      ),
      child: Container(
        height: 200,
        width: double.infinity, // CRITICAL FIX: Ensure full width
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Stack(
          clipBehavior: Clip.none, // CRITICAL FIX: Prevent overflow issues
          children: [
            // Background gradient overlay
            Positioned.fill( // CRITICAL FIX: Use Positioned.fill for proper constraints
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Back button with professional styling
            Positioned(
              top: 20,
              left: 16,
              child: Container(
                decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
                  border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.arrow_back,
                        color: AccountantThemeConfig.primaryGreen,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // SAMA branding with professional styling
            Positioned.fill( // CRITICAL FIX: Use Positioned.fill for proper constraints
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // CRITICAL FIX: Prevent infinite height expansion
                  children: [
                    // SAMA logo text with gradient
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.white,
                          AccountantThemeConfig.primaryGreen,
                          Colors.white,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'SAMA',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                          letterSpacing: 4.0,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Store subtitle
                    const Text(
                      'متجر سما الإلكتروني',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        fontFamily: 'Cairo',
                      ),
                      textDirection: TextDirection.rtl,
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

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'البحث في المنتجات...',
                hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.6),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.6),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Category filters
          if (_categories.isNotEmpty) _buildCategoryFilters(),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final allCategories = ['الكل', ..._categories];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: allCategories.length,
        itemBuilder: (context, index) {
          final category = allCategories[index];
          final isSelected = _selectedCategory == category ||
              (_selectedCategory == null && category == 'الكل');

          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 8,
              right: index == allCategories.length - 1 ? 0 : 8,
            ),
            child: FilterChip(
              label: Text(
                category,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                _onCategorySelected(category == 'الكل' ? null : category);
              },
              backgroundColor: AccountantThemeConfig.darkBlueBlack,
              selectedColor: AccountantThemeConfig.primaryGreen,
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? AccountantThemeConfig.primaryGreen
                    : Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingView() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'جاري تحميل المنتجات...',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'لا توجد منتجات تطابق البحث'
                  : 'لا توجد منتجات متاحة',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'جرب تغيير كلمات البحث أو الفئة'
                  : 'سيتم إضافة المنتجات قريباً',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 24),
            if (_searchQuery.isNotEmpty || _selectedCategory != null)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = null;
                    _searchController.clear();
                  });
                  _filterProducts();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text(
                  'مسح الفلاتر',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }



  /// تحميل مسبق محسن للصور المرئية - أقل عدوانية
  void _preloadVisibleImages() {
    if (_filteredProducts.isEmpty) return;

    // تحميل مسبق للصور الأولى (أول 4 منتجات فقط لتحسين الأداء)
    final visibleProducts = _filteredProducts.take(4).toList();

    // تأخير التحميل المسبق لتجنب التداخل مع التحميل الأساسي
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      for (final product in visibleProducts) {
        if (product.bestImageUrl.isNotEmpty) {
          try {
            // تحميل مسبق باستخدام precacheImage مع معالجة أفضل للأخطاء
            precacheImage(
              CachedNetworkImageProvider(
                product.bestImageUrl,
                cacheManager: OptimizedImageCacheManager.instance,
              ),
              context,
            ).catchError((error) {
              // تسجيل صامت للأخطاء لتجنب إزعاج المستخدم
              AppLogger.info('تم تخطي التحميل المسبق للصورة: ${product.name}');
            });
          } catch (e) {
            // معالجة صامتة للأخطاء
          }
        }
      }

      AppLogger.info('🚀 تم بدء التحميل المسبق لـ ${visibleProducts.length} صورة');
    });
  }

  /// Get responsive cross axis count based on screen width
  int _getResponsiveCrossAxisCount() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 4; // Large screens (tablets in landscape)
    if (screenWidth > 800) return 3;  // Medium screens (tablets in portrait)
    return 2; // Small screens (phones)
  }

  /// Get responsive aspect ratio based on screen size
  double _getResponsiveAspectRatio() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 0.8;  // Slightly taller cards on large screens
    if (screenWidth > 800) return 0.75;  // Standard ratio for medium screens
    return 0.7; // Slightly shorter cards on small screens for better content visibility
  }

  /// Validate responsive design parameters
  void _validateResponsiveDesign() {
    final screenSize = MediaQuery.of(context).size;
    final crossAxisCount = _getResponsiveCrossAxisCount();
    final aspectRatio = _getResponsiveAspectRatio();

    AppLogger.info('📱 Screen validation:');
    AppLogger.info('   Size: ${screenSize.width}x${screenSize.height}');
    AppLogger.info('   Cross axis count: $crossAxisCount');
    AppLogger.info('   Aspect ratio: $aspectRatio');
    AppLogger.info('   Device pixel ratio: ${MediaQuery.of(context).devicePixelRatio}');

    // تحقق من صحة القيم
    assert(crossAxisCount >= 2 && crossAxisCount <= 4, 'Cross axis count should be between 2-4');
    assert(aspectRatio >= 0.6 && aspectRatio <= 1.0, 'Aspect ratio should be between 0.6-1.0');
  }

  /// اختبار شامل لنظام عرض الصور
  void _validateImageDisplaySystem() {
    AppLogger.info('🧪 بدء اختبار نظام عرض الصور...');

    int productsWithImages = 0;
    int productsWithoutImages = 0;
    int productsWithMultipleImages = 0;

    for (final product in _filteredProducts) {
      if (product.bestImageUrl.isNotEmpty) {
        productsWithImages++;
        if (product.images.length > 1) {
          productsWithMultipleImages++;
        }
      } else {
        productsWithoutImages++;
      }
    }

    AppLogger.info('📊 إحصائيات الصور:');
    AppLogger.info('   منتجات بصور: $productsWithImages');
    AppLogger.info('   منتجات بدون صور: $productsWithoutImages');
    AppLogger.info('   منتجات بصور متعددة: $productsWithMultipleImages');
    AppLogger.info('   نسبة التغطية: ${(productsWithImages / _filteredProducts.length * 100).toStringAsFixed(1)}%');

    // تحذير إذا كانت نسبة المنتجات بدون صور عالية
    if (productsWithoutImages > _filteredProducts.length * 0.3) {
      AppLogger.warning('⚠️ نسبة عالية من المنتجات بدون صور: ${(productsWithoutImages / _filteredProducts.length * 100).toStringAsFixed(1)}%');
    }

    AppLogger.info('✅ اكتمل اختبار نظام عرض الصور');
  }







  void _showProductDetailsDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl, // Ensure RTL direction in dialog
        child: AlertDialog(
          backgroundColor: const Color(0xFF1e293b),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            product.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              child: EnhancedProductImage(
                product: product,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            const SizedBox(height: 16),

            if (product.category.isNotEmpty) ...[
              Text(
                'الفئة: ${product.category}',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (product.description.isNotEmpty) ...[
              const Text(
                'الوصف:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ],
        ),
          actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إغلاق',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _launchARExperience(product);
            },
            icon: const Icon(Icons.view_in_ar, size: 18),
            label: const Text(
              'تجربة AR',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// Enhanced search and filters with AccountantThemeConfig styling
  Widget _buildEnhancedSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min, // CRITICAL FIX: Prevent infinite height expansion
        children: [
          // Professional search bar
          Container(
            decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Cairo',
                fontSize: 16,
              ),
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'البحث في المنتجات المتاحة...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontFamily: 'Cairo',
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AccountantThemeConfig.primaryGreen,
                  size: 24,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AccountantThemeConfig.defaultPadding,
                  vertical: AccountantThemeConfig.defaultPadding,
                ),
              ),
            ),
          ),

          const SizedBox(height: AccountantThemeConfig.defaultPadding),

          // Enhanced category filter with proper constraints
          if (_categories.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 45, // CRITICAL FIX: Explicit height constraint
                minHeight: 45,
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _categories.length + 1,
                physics: const BouncingScrollPhysics(), // Better scroll physics
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildProfessionalCategoryChip('الكل', _selectedCategory == null);
                  }
                  final category = _categories.elementAt(index - 1);
                  return _buildProfessionalCategoryChip(category, _selectedCategory == category);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Professional category chip with AccountantThemeConfig styling
  Widget _buildProfessionalCategoryChip(String category, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          category,
          style: TextStyle(
            color: isSelected ? Colors.white : AccountantThemeConfig.primaryGreen,
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          // Handle "الكل" (All) category correctly
          if (category == 'الكل') {
            _onCategorySelected(null);
          } else {
            _onCategorySelected(selected ? category : null);
          }
        },
        backgroundColor: isSelected
            ? AccountantThemeConfig.primaryGreen
            : Colors.transparent,
        selectedColor: AccountantThemeConfig.primaryGreen,
        side: BorderSide(
          color: AccountantThemeConfig.primaryGreen,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        ),
        elevation: isSelected ? 4 : 0,
        shadowColor: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
      ),
    );
  }

  /// Professional loading view with AccountantThemeConfig styling
  Widget _buildProfessionalLoadingView() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(40),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: Icon(
                Icons.store,
                size: 40,
                color: AccountantThemeConfig.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'جاري تحميل المنتجات...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'يرجى الانتظار',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }

  /// Professional empty view with AccountantThemeConfig styling
  Widget _buildProfessionalEmptyView() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(50),
                boxShadow: AccountantThemeConfig.cardShadows,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 50,
                color: AccountantThemeConfig.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'لا توجد منتجات متاحة تطابق البحث'
                  : 'لا توجد منتجات متاحة حالياً',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'جرب تغيير كلمات البحث أو الفئة المحددة'
                  : 'سيتم إضافة المنتجات قريباً إن شاء الله',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_searchQuery.isNotEmpty || _selectedCategory != null)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = null;
                    _searchController.clear();
                  });
                  _filterProducts();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text(
                  'مسح جميع الفلاتر',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 16),
                ),
                style: AccountantThemeConfig.primaryButtonStyle,
              ),
          ],
        ),
      ),
    );
  }

  /// Professional products grid with AccountantThemeConfig styling - محسن للأداء
  Widget _buildProfessionalProductsGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getResponsiveCrossAxisCount(), // Use responsive cross axis count
          childAspectRatio: _getResponsiveAspectRatio(), // Use responsive aspect ratio
          crossAxisSpacing: AccountantThemeConfig.defaultPadding,
          mainAxisSpacing: AccountantThemeConfig.defaultPadding,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = _filteredProducts[index];
            return RepaintBoundary( // CRITICAL FIX: Add RepaintBoundary for better performance
              child: _buildProfessionalProductCard(product),
            );
          },
          childCount: _filteredProducts.length,
          // تحسينات الأداء المهمة
          addRepaintBoundaries: false, // نحن نضيف RepaintBoundary يدوياً
          addAutomaticKeepAlives: false, // توفير الذاكرة
          addSemanticIndexes: false, // تحسين الأداء
        ),
      ),
    );
  }

  /// Professional product card with AccountantThemeConfig styling - محسن للأداء
  Widget _buildProfessionalProductCard(ProductModel product) {
    return Container(
      key: ValueKey('professional_card_${product.id}'),
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        // Removed InkWell to disable tap functionality - cards are now purely visual/informational
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min, // CRITICAL FIX: Prevent infinite height expansion
          children: [
              // Product image with optimized styling
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AccountantThemeConfig.defaultBorderRadius),
                    topRight: Radius.circular(AccountantThemeConfig.defaultBorderRadius),
                  ),
                  child: FastProductImage(
                    product: product,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Product name with enhanced typography
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min, // CRITICAL FIX: Prevent infinite height expansion
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
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

  /// Professional product details dialog
  void _showProfessionalProductDetails(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AccountantThemeConfig.cardBackground1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          ),
          title: Text(
            product.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 200,
                width: double.infinity,
                child: EnhancedProductImage(
                  product: product,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                ),
              ),

              const SizedBox(height: 16),

              if (product.category.isNotEmpty) ...[
                Text(
                  'الفئة: ${product.category}',
                  style: TextStyle(
                    color: AccountantThemeConfig.primaryGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (product.description.isNotEmpty) ...[
                const Text(
                  'الوصف:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'إغلاق',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchARExperience(product);
              },
              icon: const Icon(Icons.view_in_ar, size: 18),
              label: const Text(
                'تجربة AR',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              style: AccountantThemeConfig.primaryButtonStyle,
            ),
          ],
        ),
      ),
    );
  }
}
