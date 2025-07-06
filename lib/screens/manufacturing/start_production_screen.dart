import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/common/optimized_image.dart';
import 'package:smartbiztracker_new/models/manufacturing/manufacturing_tool.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_recipe.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_service.dart';
import 'package:smartbiztracker_new/services/manufacturing/production_service.dart';
import 'package:smartbiztracker_new/services/manufacturing/inventory_deduction_service.dart';
import 'package:smartbiztracker_new/services/warehouse_products_service.dart';
import 'package:smartbiztracker_new/screens/manufacturing/widgets/manufacturing_tool_card.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'dart:async';

/// شاشة بدء الإنتاج مع سير عمل السحب والإفلات
class StartProductionScreen extends StatefulWidget {
  const StartProductionScreen({super.key});

  @override
  State<StartProductionScreen> createState() => _StartProductionScreenState();
}

class _StartProductionScreenState extends State<StartProductionScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ManufacturingToolsService _toolsService = ManufacturingToolsService();
  final ProductionService _productionService = ProductionService();
  final InventoryDeductionService _inventoryService = InventoryDeductionService();
  final WarehouseProductsService _productsService = WarehouseProductsService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _unitsController = TextEditingController();

  // State variables
  List<ManufacturingTool> _tools = [];
  List<ManufacturingTool> _filteredTools = [];
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  Map<int, ProductionRecipe> _selectedRecipes = {};
  String? _selectedProductId;
  bool _isLoading = true;
  bool _isLoadingProducts = true;
  bool _isProcessing = false;
  Timer? _searchDebouncer;
  String _productSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProducts();
    _loadTools();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _unitsController.dispose();
    _searchDebouncer?.cancel();
    super.dispose();
  }

  /// تحميل المنتجات من قاعدة البيانات
  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoadingProducts = true);

      final products = await _productsService.getProducts();

      if (mounted) {
        setState(() {
          _products = products;
          _filteredProducts = products;
          _isLoadingProducts = false;
        });

        AppLogger.info('✅ Loaded ${products.length} products for manufacturing');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProducts = false);
        _showErrorSnackBar('فشل في تحميل المنتجات: $e');
      }
      AppLogger.error('❌ Error loading products: $e');
    }
  }

  /// تحميل الأدوات
  Future<void> _loadTools() async {
    try {
      setState(() => _isLoading = true);

      final tools = await _toolsService.getAllTools();

      if (mounted) {
        setState(() {
          _tools = tools;
          _filteredTools = tools;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('فشل في تحميل الأدوات: $e');
      }
    }
  }

  /// معالجة تغيير البحث
  void _onSearchChanged() {
    _searchDebouncer?.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 1500), () {
      _performSearch(_searchController.text);
    });
  }

  /// تنفيذ البحث
  void _performSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTools = _tools;
      } else {
        _filteredTools = _tools.where((tool) {
          return tool.name.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  /// البحث في المنتجات
  void _onProductSearchChanged(String query) {
    setState(() {
      _productSearchQuery = query;
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        final searchQuery = query.toLowerCase();
        _filteredProducts = _products.where((product) {
          return product.name.toLowerCase().contains(searchQuery) ||
                 product.category.toLowerCase().contains(searchQuery) ||
                 product.sku.toLowerCase().contains(searchQuery) ||
                 product.description.toLowerCase().contains(searchQuery);
        }).toList();
      }
    });
  }

  /// الحصول على اسم المنتج المحدد
  String _getSelectedProductName() {
    if (_selectedProductId == null) return 'غير محدد';

    try {
      final product = _products.firstWhere((p) => p.id == _selectedProductId);
      return product.name;
    } catch (e) {
      return 'منتج غير معروف';
    }
  }

  /// اختيار منتج
  void _selectProduct(String productId) {
    setState(() {
      _selectedProductId = productId;
      _selectedRecipes.clear();
    });
    _tabController.animateTo(1);
  }

  /// إضافة أداة إلى الوصفة
  void _addToolToRecipe(ManufacturingTool tool) {
    _showQuantityDialog(tool);
  }

  /// إظهار حوار إدخال الكمية
  void _showQuantityDialog(ManufacturingTool tool) {
    final TextEditingController quantityController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'كمية ${tool.name} المطلوبة',
          style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'كم وحدة من ${tool.name} مطلوبة لإنتاج وحدة واحدة؟',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'الكمية المطلوبة',
                labelStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
                suffixText: tool.unit,
                suffixStyle: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AccountantThemeConfig.primaryGreen),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'المخزون المتاح: ${tool.quantity} ${tool.unit}',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: tool.stockIndicatorColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text);
              if (quantity != null && quantity > 0) {
                Navigator.pop(context);
                _addRecipe(tool, quantity);
              }
            },
            style: AccountantThemeConfig.primaryButtonStyle,
            child: Text('إضافة'),
          ),
        ],
      ),
    );
  }

  /// إضافة وصفة
  void _addRecipe(ManufacturingTool tool, double quantity) {
    if (_selectedProductId == null) return;

    // Convert string product ID to integer for database compatibility
    final productIdInt = int.tryParse(_selectedProductId!) ?? 0;
    if (productIdInt == 0) {
      _showErrorSnackBar('معرف المنتج غير صحيح');
      return;
    }

    setState(() {
      _selectedRecipes[tool.id] = ProductionRecipe(
        id: 0, // مؤقت
        productId: productIdInt,
        toolId: tool.id,
        toolName: tool.name,
        quantityRequired: quantity,
        unit: tool.unit,
        currentStock: tool.quantity,
        stockStatus: tool.stockStatus,
        createdAt: DateTime.now(),
      );
    });

    _showSuccessSnackBar('تم إضافة ${tool.name} إلى الوصفة');
    _tabController.animateTo(2);
  }

  /// حذف وصفة
  void _removeRecipe(int toolId) {
    setState(() {
      _selectedRecipes.remove(toolId);
    });
  }

  /// حفظ الوصفة وبدء الإنتاج
  Future<void> _saveRecipeAndStartProduction() async {
    if (_selectedRecipes.isEmpty || _selectedProductId == null) {
      _showErrorSnackBar('يجب اختيار منتج وإضافة أدوات للوصفة');
      return;
    }

    final unitsText = _unitsController.text.trim();
    if (unitsText.isEmpty) {
      _showErrorSnackBar('يجب إدخال عدد الوحدات المراد إنتاجها');
      return;
    }

    final units = double.tryParse(unitsText);
    if (units == null || units <= 0) {
      _showErrorSnackBar('عدد الوحدات يجب أن يكون رقم صحيح أكبر من صفر');
      return;
    }

    // Convert string product ID to integer for database compatibility
    final productIdInt = int.tryParse(_selectedProductId!) ?? 0;
    if (productIdInt == 0) {
      _showErrorSnackBar('معرف المنتج غير صحيح');
      return;
    }

    try {
      setState(() => _isProcessing = true);

      // حفظ الوصفات أولاً
      for (final recipe in _selectedRecipes.values) {
        final request = CreateProductionRecipeRequest(
          productId: productIdInt,
          toolId: recipe.toolId,
          quantityRequired: recipe.quantityRequired,
        );
        await _productionService.createProductionRecipe(request);
      }

      // تنفيذ الإنتاج
      final batchId = await _inventoryService.executeInventoryDeduction(
        productIdInt,
        units,
        'إنتاج من خلال واجهة بدء الإنتاج',
      );

      _showSuccessSnackBar('تم بدء الإنتاج بنجاح - رقم الدفعة: $batchId (قيد التنفيذ)');
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackBar('فشل في تنفيذ الإنتاج: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// إظهار رسالة خطأ
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AccountantThemeConfig.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// إظهار رسالة نجاح
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildTabBar(),
          _buildTabContent(),
        ],
      ),
    );
  }

  /// بناء SliverAppBar
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: FlexibleSpaceBar(
          title: Text(
            'بدء الإنتاج',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
      ),
    );
  }

  /// بناء شريط التبويبات
  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorColor: AccountantThemeConfig.primaryGreen,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(text: '1. اختيار المنتج', icon: Icon(Icons.shopping_bag)),
            Tab(text: '2. اختيار الأدوات', icon: Icon(Icons.build)),
            Tab(text: '3. مراجعة الوصفة', icon: Icon(Icons.list_alt)),
            Tab(text: '4. تنفيذ الإنتاج', icon: Icon(Icons.play_arrow)),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms),
    );
  }

  /// بناء محتوى التبويبات
  Widget _buildTabContent() {
    return SliverFillRemaining(
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildProductSelectionTab(),
          _buildToolSelectionTab(),
          _buildRecipeReviewTab(),
          _buildProductionExecutionTab(),
        ],
      ),
    );
  }

  /// بناء تبويب اختيار المنتج
  Widget _buildProductSelectionTab() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اختر المنتج المراد إنتاجه',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // شريط البحث
          Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: AccountantThemeConfig.glowBorder(Colors.white.withOpacity(0.3)),
            ),
            child: TextField(
              onChanged: _onProductSearchChanged,
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'البحث في المنتجات...',
                hintStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // عرض حالة التحميل أو المنتجات
          Expanded(
            child: _isLoadingProducts
                ? const Center(
                    child: CustomLoader(
                      message: 'جاري تحميل المنتجات...',
                    ),
                  )
                : _filteredProducts.isEmpty
                    ? _buildEmptyProductsState()
                    : _buildProductsGrid(),
          ),
        ],
      ),
    );
  }

  /// بناء شبكة المنتجات
  Widget _buildProductsGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final isSelected = _selectedProductId == product.id;

        return GestureDetector(
          onTap: () => _selectProduct(product.id),
          child: Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: AccountantThemeConfig.glowBorder(
                isSelected ? AccountantThemeConfig.primaryGreen : Colors.white.withOpacity(0.3),
              ),
              boxShadow: isSelected ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // صورة المنتج
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: OptimizedImage(
                      imageUrl: _getProductImageUrl(product),
                      fit: BoxFit.cover,
                      // Remove width/height: double.infinity to avoid Infinity calculations
                      // The image will fill the available space from the parent container
                    ),
                  ),
                ),

                // معلومات المنتج
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: AccountantThemeConfig.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.category,
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        if (isSelected)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AccountantThemeConfig.primaryGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'محدد',
                                style: AccountantThemeConfig.bodySmall.copyWith(
                                  color: AccountantThemeConfig.primaryGreen,
                                  fontWeight: FontWeight.bold,
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
        ).animate().fadeIn(duration: 600.ms, delay: (index * 100).ms);
      },
    );
  }

  /// بناء حالة عدم وجود منتجات
  Widget _buildEmptyProductsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            _productSearchQuery.isEmpty ? 'لا توجد منتجات متاحة' : 'لم يتم العثور على منتجات',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _productSearchQuery.isEmpty
                ? 'يرجى إضافة منتجات إلى النظام أولاً'
                : 'جرب البحث بكلمات مختلفة',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white54,
            ),
            textAlign: TextAlign.center,
          ),
          if (_productSearchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _onProductSearchChanged('');
              },
              style: AccountantThemeConfig.primaryButtonStyle,
              child: const Text('مسح البحث'),
            ),
          ],
        ],
      ),
    );
  }

  /// بناء تبويب اختيار الأدوات
  Widget _buildToolSelectionTab() {
    if (_selectedProductId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              'يجب اختيار منتج أولاً',
              style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CustomLoader(message: 'جاري تحميل الأدوات...'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اختر الأدوات المطلوبة للإنتاج',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // شريط البحث
          Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
            ),
            child: TextField(
              controller: _searchController,
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'البحث في الأدوات...',
                hintStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // شبكة الأدوات
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.9, // Increased from 0.8 to 0.9 to provide more height and fix overflow
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _filteredTools.length,
              itemBuilder: (context, index) {
                final tool = _filteredTools[index];
                return ManufacturingToolCard(
                  tool: tool,
                  onTap: () => _addToolToRecipe(tool),
                ).animate().fadeIn(duration: 600.ms, delay: (index * 50).ms);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// بناء تبويب مراجعة الوصفة
  Widget _buildRecipeReviewTab() {
    if (_selectedRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              'لم يتم إضافة أدوات للوصفة بعد',
              style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مراجعة وصفة الإنتاج',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView.builder(
              itemCount: _selectedRecipes.length,
              itemBuilder: (context, index) {
                final recipe = _selectedRecipes.values.elementAt(index);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.cardGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.toolName,
                              style: AccountantThemeConfig.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الكمية المطلوبة: ${recipe.quantityRequired} ${recipe.unit}',
                              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
                            ),
                            Text(
                              'المخزون المتاح: ${recipe.currentStock} ${recipe.unit}',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: recipe.currentStock >= recipe.quantityRequired 
                                    ? Colors.green 
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeRecipe(recipe.toolId),
                        icon: const Icon(Icons.delete, color: Colors.red),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: (index * 100).ms);
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          ElevatedButton(
            onPressed: () => _tabController.animateTo(3),
            style: AccountantThemeConfig.primaryButtonStyle.copyWith(
              minimumSize: MaterialStateProperty.all(const Size(double.infinity, 50)),
            ),
            child: Text(
              'متابعة إلى التنفيذ',
              style: AccountantThemeConfig.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء تبويب تنفيذ الإنتاج
  Widget _buildProductionExecutionTab() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تنفيذ الإنتاج',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // إدخال عدد الوحدات
          Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
            ),
            child: TextField(
              controller: _unitsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'عدد الوحدات المراد إنتاجها',
                labelStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
                hintText: '1',
                hintStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white54),
                prefixIcon: const Icon(Icons.production_quantity_limits, color: Colors.white54),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // ملخص الإنتاج
          if (_selectedRecipes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(12),
                border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ملخص الإنتاج',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'المنتج: ${_getSelectedProductName()}',
                    style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
                  ),
                  Text(
                    'عدد الأدوات المطلوبة: ${_selectedRecipes.length}',
                    style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
          
          const Spacer(),
          
          // زر التنفيذ
          ElevatedButton(
            onPressed: (_selectedRecipes.isNotEmpty && !_isProcessing) 
                ? _saveRecipeAndStartProduction 
                : null,
            style: AccountantThemeConfig.primaryButtonStyle.copyWith(
              minimumSize: MaterialStateProperty.all(const Size(double.infinity, 50)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'بدء الإنتاج',
                    style: AccountantThemeConfig.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
