import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/accountant/modern_widgets.dart';
import 'package:smartbiztracker_new/widgets/shared/professional_progress_loader.dart';
import 'package:smartbiztracker_new/models/product_movement_model.dart';
import 'package:smartbiztracker_new/models/flask_product_model.dart';
import 'package:smartbiztracker_new/models/warehouse_inventory_model.dart';
import 'package:smartbiztracker_new/services/product_movement_service.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';
import 'package:smartbiztracker_new/services/warehouse_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/charts/professional_inventory_flow_chart.dart';
import 'package:google_fonts/google_fonts.dart';

/// Quick Access Screen for displaying comprehensive product information from QR scan
class QuickAccessScreen extends StatefulWidget {
  final String productId;
  final String productName;

  const QuickAccessScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<QuickAccessScreen> createState() => _QuickAccessScreenState();
}

class _QuickAccessScreenState extends State<QuickAccessScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  FlaskProductModel? _product;
  ProductMovementModel? _productMovement;
  List<WarehouseInventoryModel> _warehouseInventory = [];
  bool _isLoading = true;
  bool _isLoadingWarehouse = false;
  String? _error;

  final ProductMovementService _movementService = ProductMovementService();
  final FlaskApiService _flaskService = FlaskApiService();
  final WarehouseService _warehouseService = WarehouseService();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadProductData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  Future<void> _loadProductData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      AppLogger.info('🔄 تحميل بيانات المنتج: ${widget.productName} (ID: ${widget.productId})');

      // Load product details
      final products = await _flaskService.getProducts();
      _product = products.where((p) => p.id.toString() == widget.productId).firstOrNull;

      if (_product == null) {
        throw Exception('لم يتم العثور على المنتج');
      }

      // Load product movement data
      _productMovement = await _movementService.getProductMovementById(int.parse(widget.productId));

      // Load warehouse inventory data
      await _loadWarehouseInventory();

      AppLogger.info('✅ تم تحميل بيانات المنتج بنجاح');

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل بيانات المنتج: $e');
      setState(() {
        _error = 'فشل في تحميل بيانات المنتج: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Load warehouse inventory for the current product
  Future<void> _loadWarehouseInventory() async {
    try {
      setState(() {
        _isLoadingWarehouse = true;
      });

      AppLogger.info('📦 جاري تحميل مخزون المخازن للمنتج: ${widget.productId}');

      _warehouseInventory = await _warehouseService.getProductInventoryAcrossWarehouses(widget.productId);

      AppLogger.info('✅ تم تحميل مخزون ${_warehouseInventory.length} مخزن');

      setState(() {
        _isLoadingWarehouse = false;
      });

    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل مخزون المخازن: $e');
      setState(() {
        _warehouseInventory = [];
        _isLoadingWarehouse = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'الوصول السريع',
        style: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: AccountantThemeConfig.darkBlueBlack,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        if (!_isLoading && _product != null)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadProductData,
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: ProfessionalProgressLoader(
          message: 'جاري تحميل بيانات المنتج...',
        ),
      );
    }

    if (_error != null) {
      return _buildErrorView();
    }

    if (_product == null) {
      return _buildNotFoundView();
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Product Header
              SliverToBoxAdapter(
                child: _buildProductHeader(),
              ),

              // Product Details
              SliverToBoxAdapter(
                child: _buildProductDetails(),
              ),

              // Warehouse Inventory
              SliverToBoxAdapter(
                child: _buildWarehouseInventory(),
              ),

              // Sales Statistics
              if (_productMovement != null)
                SliverToBoxAdapter(
                  child: _buildSalesStatistics(),
                ),

              // Inventory Flow Chart
              if (_productMovement != null)
                SliverToBoxAdapter(
                  child: _buildInventoryFlowChart(),
                ),

              // Recent Sales
              if (_productMovement != null && _productMovement!.salesData.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildRecentSales(),
                ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AccountantThemeConfig.warningOrange,
            ),
            const SizedBox(height: 16),
            Text(
              'خطأ في التحميل',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProductData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'إعادة المحاولة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AccountantThemeConfig.accentBlue,
            ),
            const SizedBox(height: 16),
            Text(
              'المنتج غير موجود',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على المنتج المطلوب',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildProductImage(),
                ),
              ),

              const SizedBox(width: 16),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _product!.name,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'معرف المنتج: ${_product!.id}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AccountantThemeConfig.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_product!.description.isNotEmpty)
                      Text(
                        _product!.description,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build product image with proper URL construction
  Widget _buildProductImage() {
    final imageUrl = _getProductImageUrl();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AccountantThemeConfig.cardBackground2,
          child: const Icon(
            Icons.image,
            color: Colors.white54,
            size: 40,
          ),
        ),
        errorWidget: (context, url, error) {
          AppLogger.warning('خطأ في تحميل صورة المنتج: $url - $error');
          return Container(
            color: AccountantThemeConfig.cardBackground2,
            child: const Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 40,
            ),
          );
        },
      );
    } else {
      return Container(
        color: AccountantThemeConfig.cardBackground2,
        child: const Icon(
          Icons.inventory,
          color: Colors.white54,
          size: 40,
        ),
      );
    }
  }

  /// Get properly constructed product image URL
  String? _getProductImageUrl() {
    if (_product?.imageUrl == null || _product!.imageUrl!.isEmpty) {
      AppLogger.info('🖼️ لا توجد صورة للمنتج: ${_product?.name}');
      return null;
    }

    final imageUrl = _product!.imageUrl!;
    AppLogger.info('🖼️ معالجة صورة المنتج: $imageUrl');

    // If already a complete URL, return as is
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      AppLogger.info('🖼️ رابط كامل: $imageUrl');
      return imageUrl;
    }

    // If starts with /, prepend base URL
    if (imageUrl.startsWith('/')) {
      final fullUrl = 'https://samastock.pythonanywhere.com$imageUrl';
      AppLogger.info('🖼️ رابط مع مسار: $fullUrl');
      return fullUrl;
    }

    // If just filename, construct full path
    final fullUrl = 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
    AppLogger.info('🖼️ رابط مع اسم الملف: $fullUrl');
    return fullUrl;
  }

  Widget _buildProductDetails() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل المنتج',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Price Information
          Row(
            children: [
              Expanded(
                child: _buildDetailCard(
                  'سعر البيع',
                  '${_product!.finalPrice.toStringAsFixed(2)} جنيه',
                  Icons.attach_money,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailCard(
                  'سعر الشراء',
                  '${_product!.purchasePrice.toStringAsFixed(2)} جنيه',
                  Icons.shopping_cart,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Stock and Category
          Row(
            children: [
              Expanded(
                child: _buildDetailCard(
                  'المخزون الحالي',
                  '${_product!.stockQuantity} قطعة',
                  Icons.inventory_2,
                  _product!.stockQuantity > 10
                      ? AccountantThemeConfig.primaryGreen
                      : AccountantThemeConfig.warningOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailCard(
                  'الفئة',
                  _product!.categoryName ?? 'غير محدد',
                  Icons.category,
                  AccountantThemeConfig.deepBlue,
                ),
              ),
            ],
          ),

          // Discount Information
          if (_product!.discountPercent > 0 || _product!.discountFixed > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_product!.discountPercent > 0)
                  Expanded(
                    child: _buildDetailCard(
                      'خصم نسبي',
                      '${_product!.discountPercent.toStringAsFixed(1)}%',
                      Icons.percent,
                      AccountantThemeConfig.warningOrange,
                    ),
                  ),
                if (_product!.discountPercent > 0 && _product!.discountFixed > 0)
                  const SizedBox(width: 12),
                if (_product!.discountFixed > 0)
                  Expanded(
                    child: _buildDetailCard(
                      'خصم ثابت',
                      '${_product!.discountFixed.toStringAsFixed(2)} جنيه',
                      Icons.money_off,
                      AccountantThemeConfig.warningOrange,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground2.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Build warehouse inventory section
  Widget _buildWarehouseInventory() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warehouse,
                color: AccountantThemeConfig.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'كميات المخازن',
                style: AccountantThemeConfig.headlineMedium.copyWith(fontSize: 16),
              ),
              const Spacer(),
              if (_isLoadingWarehouse)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AccountantThemeConfig.primaryGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_warehouseInventory.isEmpty && !_isLoadingWarehouse)
            _buildEmptyWarehouseState()
          else if (_warehouseInventory.isNotEmpty)
            ..._warehouseInventory.map((inventory) => _buildWarehouseCard(inventory)),
        ],
      ),
    );
  }

  /// Build empty warehouse state
  Widget _buildEmptyWarehouseState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground2.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AccountantThemeConfig.accentBlue,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'لا توجد كميات في المخازن',
              style: AccountantThemeConfig.bodyLarge.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual warehouse card
  Widget _buildWarehouseCard(WarehouseInventoryModel inventory) {
    final cartonQuantity = inventory.quantityPerCarton > 0
        ? (inventory.quantity / inventory.quantityPerCarton).floor()
        : 0;
    final remainingUnits = inventory.quantity % inventory.quantityPerCarton;

    // Determine stock level status
    final isLowStock = inventory.minimumStock != null &&
        inventory.quantity <= inventory.minimumStock!;

    final statusColor = isLowStock
        ? AccountantThemeConfig.warningOrange
        : AccountantThemeConfig.primaryGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground2.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warehouse name and status
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  inventory.warehouseName ?? 'مخزن غير محدد',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isLowStock)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.warningOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'مخزون منخفض',
                    style: TextStyle(
                      fontSize: 9,
                      color: AccountantThemeConfig.warningOrange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Quantity information
          Row(
            children: [
              // Units
              Expanded(
                child: _buildQuantityInfo(
                  'الوحدات',
                  '${inventory.quantity} قطعة',
                  Icons.inventory_2,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              // Cartons
              if (inventory.quantityPerCarton > 1)
                Expanded(
                  child: _buildQuantityInfo(
                    'الكراتين',
                    '$cartonQuantity كرتونة',
                    Icons.all_inbox,
                    AccountantThemeConfig.accentBlue,
                  ),
                ),
            ],
          ),

          if (inventory.quantityPerCarton > 1) ...[
            const SizedBox(height: 8),
            // Conversion info
            Text(
              'التحويل: ${inventory.quantityPerCarton} قطعة/كرتونة' +
              (remainingUnits > 0 ? ' (${remainingUnits} قطعة متبقية)' : ''),
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],

          const SizedBox(height: 8),
          // Last updated
          Text(
            'آخر تحديث: ${_formatDateTime(inventory.lastUpdated)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Build quantity information widget
  Widget _buildQuantityInfo(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Format DateTime for display
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} يوم مضى';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعة مضت';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقيقة مضت';
    } else {
      return 'الآن';
    }
  }

  Widget _buildSalesStatistics() {
    final stats = _productMovement!.statistics;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إحصائيات المبيعات',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Sales Overview
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي المبيعات',
                  '${stats.totalSoldQuantity} قطعة',
                  Icons.trending_up,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'إجمالي الإيرادات',
                  '${stats.totalRevenue.toStringAsFixed(2)} جنيه',
                  Icons.monetization_on,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Profit Information
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'الربح الإجمالي',
                  '${stats.totalProfit.toStringAsFixed(2)} جنيه',
                  Icons.account_balance_wallet,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'هامش الربح',
                  '${stats.profitMargin.toStringAsFixed(1)}%',
                  Icons.percent,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Average and Count
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'متوسط سعر البيع',
                  '${stats.averageSalePrice.toStringAsFixed(2)} جنيه',
                  Icons.analytics,
                  AccountantThemeConfig.deepBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'عدد المبيعات',
                  '${stats.totalSalesCount} عملية',
                  Icons.receipt_long,
                  AccountantThemeConfig.deepBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryFlowChart() {
    AppLogger.info('🔄 بناء مخطط تدفق المخزون المحسن');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ProfessionalInventoryFlowChart(
        productMovement: _productMovement!,
        enableInteraction: true,
        showLegend: false,
        onChartTap: () {
          _showFullscreenChart();
        },
      ),
    );
  }

  /// Show fullscreen inventory flow chart dialog
  void _showFullscreenChart() {
    AppLogger.info('📊 عرض مخطط تدفق المخزون بملء الشاشة');

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: _buildFullscreenChartAppBar(),
              body: _buildFullscreenChartBody(),
            ),
          ),
        );
      },
    );
  }

  /// Build app bar for fullscreen chart
  PreferredSizeWidget _buildFullscreenChartAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.cardBackground1.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.close,
            color: AccountantThemeConfig.primaryGreen,
            size: 20,
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timeline,
              color: AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'تدفق المخزون عبر الزمن',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      centerTitle: true,
    );
  }

  /// Build body for fullscreen chart
  Widget _buildFullscreenChartBody() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Product info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AccountantThemeConfig.cardShadows,
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2,
                    color: AccountantThemeConfig.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _product?.name ?? widget.productName,
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المخزون الحالي: ${_productMovement?.statistics.currentStock ?? 0} قطعة',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: AccountantThemeConfig.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Fullscreen chart
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AccountantThemeConfig.cardShadows,
                border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
              ),
              child: ProfessionalInventoryFlowChart(
                productMovement: _productMovement!,
                enableInteraction: true,
                showLegend: false,
                height: null, // Let it expand to fill available space
                onChartTap: () {
                  // Disable further fullscreen functionality since we're already in fullscreen
                  AppLogger.info('📊 المخطط في وضع ملء الشاشة بالفعل - تجاهل النقر');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }



  /// Build individual stock indicator
  Widget _buildStockIndicator(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSales() {
    final allSales = _productMovement!.salesData.toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'جميع المبيعات',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${allSales.length} معاملة',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Make the sales list scrollable with a maximum height
          Container(
            constraints: BoxConstraints(
              maxHeight: allSales.length > 5 ? 400 : double.infinity,
            ),
            child: allSales.length > 5
                ? Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: allSales.length,
                      itemBuilder: (context, index) => _buildSaleItem(allSales[index]),
                    ),
                  )
                : Column(
                    children: allSales.map((sale) => _buildSaleItem(sale)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleItem(ProductSaleModel sale) {
    // Calculate unit price for display
    final unitPrice = sale.quantity > 0 ? sale.totalAmount / sale.quantity : 0.0;

    AppLogger.info('💰 عرض بيع: ${sale.customerName} - ${sale.quantity} قطعة - ${sale.totalAmount.toStringAsFixed(2)} جنيه - سعر الوحدة: ${unitPrice.toStringAsFixed(2)} جنيه');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground2.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Enhanced circular indicator with unit price
          _buildUnitPriceIndicator(unitPrice),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.customerName,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                // Enhanced display with both total and unit price
                Text(
                  '${sale.quantity} قطعة - ${sale.totalAmount.toStringAsFixed(2)} جنيه',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 2),
                // Unit price display
                Text(
                  '(${unitPrice.toStringAsFixed(2)} جنيه/قطعة)',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AccountantThemeConfig.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${sale.saleDate.day}/${sale.saleDate.month}',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: AccountantThemeConfig.accentBlue,
                ),
              ),
              const SizedBox(height: 4),
              // Invoice status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getInvoiceStatusColor(sale.invoiceStatus).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getInvoiceStatusText(sale.invoiceStatus),
                  style: GoogleFonts.cairo(
                    fontSize: 9,
                    color: _getInvoiceStatusColor(sale.invoiceStatus),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build enhanced circular indicator with unit price highlighting
  Widget _buildUnitPriceIndicator(double unitPrice) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AccountantThemeConfig.primaryGreen,
            AccountantThemeConfig.primaryGreen.withOpacity(0.7),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.monetization_on,
              color: Colors.white,
              size: 14,
            ),
            Text(
              '${unitPrice.toStringAsFixed(0)}',
              style: GoogleFonts.cairo(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get invoice status color
  Color _getInvoiceStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'مدفوع':
        return AccountantThemeConfig.primaryGreen;
      case 'pending':
      case 'معلق':
        return AccountantThemeConfig.warningOrange;
      case 'cancelled':
      case 'ملغي':
        return Colors.red;
      default:
        return AccountantThemeConfig.accentBlue;
    }
  }

  /// Get invoice status text
  String _getInvoiceStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'مدفوع';
      case 'pending':
        return 'معلق';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }
}


