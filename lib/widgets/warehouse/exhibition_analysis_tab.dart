import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/models/warehouse_reports_model.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/services/warehouse_reports_service.dart';
import 'package:smartbiztracker_new/widgets/warehouse/interactive_inventory_card.dart';
import 'package:smartbiztracker_new/widgets/warehouse/collapsible_stats_widget.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_reports_loader.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_reports_error_widget.dart';
import 'package:smartbiztracker_new/widgets/common/enhanced_product_image.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// تبويب تحليل المعرض
class ExhibitionAnalysisTab extends StatefulWidget {
  final WarehouseReportsService reportsService;

  const ExhibitionAnalysisTab({
    Key? key,
    required this.reportsService,
  }) : super(key: key);

  @override
  State<ExhibitionAnalysisTab> createState() => _ExhibitionAnalysisTabState();
}

class _ExhibitionAnalysisTabState extends State<ExhibitionAnalysisTab>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  String? _error;
  ExhibitionAnalysisReport? _report;

  // Progress tracking
  final WarehouseReportsProgressService _progressService = WarehouseReportsProgressService();

  // فلاتر البحث
  final TextEditingController _searchController = TextEditingController();
  String _selectedSection = 'missing'; // missing, exhibition, api
  String _selectedCategory = 'الكل';
  List<String> _availableCategories = ['الكل'];

  @override
  void initState() {
    super.initState();
    _loadReport();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// تحميل تقرير تحليل المعرض مع تتبع التقدم
  Future<void> _loadReport() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // إعادة تعيين خدمة التقدم
      _progressService.reset();

      AppLogger.info('📊 بدء تحميل تقرير تحليل المعرض مع تتبع التقدم');

      // المرحلة 1: تحميل منتجات المعرض
      _progressService.updateProgress(
        stage: 'inventory',
        progress: 0.2,
        message: 'جاري تحميل منتجات المعرض...',
        subMessage: 'تحميل مخزون المعرض الحالي',
      );
      setState(() {});

      // المرحلة 2: تحميل منتجات API
      _progressService.updateProgress(
        stage: 'api_products',
        progress: 0.5,
        message: 'جاري تحميل كتالوج API...',
        subMessage: 'تحميل قائمة المنتجات المرجعية',
      );
      setState(() {});

      // المرحلة 3: إجراء التحليل
      _progressService.updateProgress(
        stage: 'analysis',
        progress: 0.8,
        message: 'جاري تحليل البيانات...',
        subMessage: 'مقارنة المعرض مع كتالوج API',
      );
      setState(() {});

      // تنفيذ التقرير الفعلي
      final report = await widget.reportsService.generateExhibitionAnalysisReport();

      // طباعة إحصائيات التشخيص
      AppLogger.info('📈 إحصائيات التقرير:');
      AppLogger.info('  - إجمالي منتجات API: ${report.allApiProducts.length}');
      AppLogger.info('  - منتجات المعرض (كمية > 0): ${report.exhibitionProducts.length}');
      AppLogger.info('  - منتجات مفقودة: ${report.missingProducts.length}');
      AppLogger.info('  - نسبة التغطية: ${((report.allApiProducts.length - report.missingProducts.length) / report.allApiProducts.length * 100).toStringAsFixed(1)}%');

      // التحقق من وجود منتجات مكررة في قائمة المفقودة
      final exhibitionProductIds = report.exhibitionProducts.map((e) => e.productId).toSet();
      final missingProductIds = report.missingProducts.map((e) => e.id).toSet();
      final duplicates = exhibitionProductIds.intersection(missingProductIds);

      if (duplicates.isNotEmpty) {
        AppLogger.warning('⚠️ تم العثور على منتجات مكررة في قائمة المفقودة: ${duplicates.take(5).join(', ')}');
      } else {
        AppLogger.info('✅ لا توجد منتجات مكررة في قائمة المفقودة');
      }

      // المرحلة 4: إنهاء التقرير
      _progressService.updateProgress(
        stage: 'finalizing',
        progress: 1.0,
        message: 'تم إكمال التحليل بنجاح',
        subMessage: 'جاهز للعرض',
      );

      // استخراج الفئات المتاحة
      final categories = <String>{'الكل'};
      categories.addAll(report.allApiProducts.map((p) => p.category));
      categories.addAll(report.exhibitionProducts
          .where((p) => p.product?.category != null)
          .map((p) => p.product!.category));

      setState(() {
        _report = report;
        _availableCategories = categories.toList()..sort();
        _isLoading = false;
      });

      AppLogger.info('✅ تم تحميل تقرير تحليل المعرض بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل تقرير تحليل المعرض: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// معالجة تغيير البحث
  void _onSearchChanged() {
    setState(() {}); // إعادة بناء الواجهة مع النتائج المفلترة
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_error != null) {
      return _buildErrorState();
    }
    
    if (_report == null) {
      return _buildEmptyState();
    }

    return Column(
      mainAxisSize: MainAxisSize.min, // تقليص الحجم لتجنب مشاكل unbounded constraints
      children: [
        // شريط الأدوات والفلاتر
        _buildToolbar(),

        // الإحصائيات القابلة للطي
        _buildCollapsibleStatistics(),

        // محتوى القسم المحدد مع ارتفاع محدد
        Container(
          height: 400, // ارتفاع ثابت لتجنب مشاكل التخطيط
          child: _buildSelectedSection(),
        ),
      ],
    );
  }

  /// بناء شريط الأدوات
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // شريط البحث
          Container(
            decoration: BoxDecoration(
              color: AccountantThemeConfig.cardBackground1.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.cairo(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'البحث في المنتجات...',
                hintStyle: GoogleFonts.cairo(
                  color: Colors.white.withOpacity(0.6),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AccountantThemeConfig.primaryGreen,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // فلاتر الأقسام والفئات
          Row(
            children: [
              // فلتر الأقسام
              Expanded(
                child: _buildSectionFilter(),
              ),
              
              const SizedBox(width: 12),
              
              // فلتر الفئات
              Expanded(
                child: _buildCategoryFilter(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// بناء فلتر الأقسام
  Widget _buildSectionFilter() {
    final sections = {
      'missing': 'المنتجات المفقودة',
      'exhibition': 'منتجات المعرض',
      'api': 'كتالوج API',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground1.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSection,
          isExpanded: true,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 14,
          ),
          dropdownColor: AccountantThemeConfig.cardBackground1,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AccountantThemeConfig.accentBlue,
          ),
          items: sections.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedSection = value;
              });
            }
          },
        ),
      ),
    );
  }

  /// بناء فلتر الفئات
  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground1.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 14,
          ),
          dropdownColor: AccountantThemeConfig.cardBackground1,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AccountantThemeConfig.primaryGreen,
          ),
          items: _availableCategories.map((category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedCategory = value;
              });
            }
          },
        ),
      ),
    );
  }

  /// بناء الإحصائيات القابلة للطي
  Widget _buildCollapsibleStatistics() {
    final stats = _report!.statistics;

    return CollapsibleStatsWidget(
      title: 'إحصائيات تحليل المعرض',
      icon: Icons.analytics_rounded,
      accentColor: AccountantThemeConfig.primaryGreen,
      initiallyExpanded: false, // مطوية افتراضياً لتوفير مساحة
      children: [
        StatsGrid(
          crossAxisCount: 2, // إعادة إلى عمودين مع 4 بطاقات
          childAspectRatio: 2.2, // إعادة النسبة الأصلية
          cards: [
            StatCard(
              title: 'إجمالي منتجات API',
              value: '${stats['total_api_products']}',
              icon: Icons.api_rounded,
              color: AccountantThemeConfig.accentBlue,
              subtitle: 'منتجات نشطة',
            ),
            StatCard(
              title: 'منتجات المعرض',
              value: '${stats['exhibition_products']}',
              icon: Icons.store_rounded,
              color: AccountantThemeConfig.primaryGreen,
              subtitle: 'مخزون > 0',
            ),
            StatCard(
              title: 'المنتجات المفقودة',
              value: '${stats['missing_products']}',
              icon: Icons.warning_rounded,
              color: AccountantThemeConfig.warningOrange,
              subtitle: 'غير متوفرة',
            ),
            StatCard(
              title: 'نسبة التغطية',
              value: '${(stats['coverage_percentage'] as double).toStringAsFixed(1)}%',
              icon: Icons.analytics_rounded,
              color: AccountantThemeConfig.successGreen,
              subtitle: 'تغطية المعرض',
            ),
          ],
        ),

        const SizedBox(height: 16),

        // إحصائيات إضافية
        StatsRow(
          cards: [
            StatCard(
              title: 'إجمالي الكمية',
              value: '${stats['total_exhibition_quantity']}',
              icon: Icons.inventory_rounded,
              color: AccountantThemeConfig.accentBlue,
              subtitle: 'قطعة في المعرض',
            ),
            StatCard(
              title: 'إجمالي الكراتين',
              value: '${stats['total_exhibition_cartons']}',
              icon: Icons.inventory_2_rounded,
              color: AccountantThemeConfig.primaryGreen,
              subtitle: 'كرتونة',
            ),
          ],
        ),
      ],
    );
  }



  /// بناء القسم المحدد
  Widget _buildSelectedSection() {
    switch (_selectedSection) {
      case 'missing':
        return _buildMissingProductsSection();
      case 'exhibition':
        return _buildExhibitionProductsSection();
      case 'api':
        return _buildApiProductsSection();
      default:
        return _buildMissingProductsSection();
    }
  }

  /// بناء قسم المنتجات المفقودة
  Widget _buildMissingProductsSection() {
    final filteredProducts = _filterApiProducts(_report!.missingProducts);
    
    if (filteredProducts.isEmpty) {
      return _buildEmptySection('لا توجد منتجات مفقودة');
    }

    // قائمة المنتجات المفقودة مع ارتفاع محدد (إزالة العنوان الكبير لتوفير مساحة الشاشة)
    return SizedBox(
      height: 400, // ارتفاع أكبر لاستغلال المساحة المحررة
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) {
          final product = filteredProducts[index];
          return _buildApiProductCard(product, isMissing: true);
        },
      ),
    );
  }

  /// بناء قسم منتجات المعرض
  Widget _buildExhibitionProductsSection() {
    final filteredProducts = _filterExhibitionProducts(_report!.exhibitionProducts);
    
    if (filteredProducts.isEmpty) {
      return _buildEmptySection('لا توجد منتجات في المعرض');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // عنوان القسم
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.store_rounded,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'منتجات المعرض الحالية',
                      style: AccountantThemeConfig.headlineSmall,
                    ),
                    Text(
                      'المنتجات المتوفرة حالياً في مخزن المعرض',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${filteredProducts.length}',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),

        // قائمة منتجات المعرض مع ارتفاع محدد
        SizedBox(
          height: 300, // ارتفاع ثابت لتجنب مشاكل التخطيط
          child: ListView.builder(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final inventoryItem = filteredProducts[index];
              return InteractiveInventoryCard(
                inventoryItem: inventoryItem,
                currentWarehouseId: WarehouseReportsService.exhibitionWarehouseId,
                onRefresh: () => _loadReport(),
              );
            },
          ),
        ),
      ],
    );
  }

  /// بناء قسم كتالوج API
  Widget _buildApiProductsSection() {
    final filteredProducts = _filterApiProducts(_report!.allApiProducts);

    if (filteredProducts.isEmpty) {
      return _buildEmptySection('لا توجد منتجات في كتالوج API');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // عنوان القسم
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.api_rounded,
                color: AccountantThemeConfig.accentBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'كتالوج منتجات API الكامل',
                      style: AccountantThemeConfig.headlineSmall,
                    ),
                    Text(
                      'جميع المنتجات المتاحة في النظام الخارجي',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${filteredProducts.length}',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AccountantThemeConfig.accentBlue,
                  ),
                ),
              ),
            ],
          ),
        ),

        // قائمة منتجات API مع ارتفاع محدد
        SizedBox(
          height: 300, // ارتفاع ثابت لتجنب مشاكل التخطيط
          child: ListView.builder(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return _buildApiProductCard(product);
            },
          ),
        ),
      ],
    );
  }

  /// فلترة منتجات API
  List<ApiProductModel> _filterApiProducts(List<ApiProductModel> products) {
    final originalCount = products.length;

    final filteredProducts = products.where((product) {
      // استبعاد المنتجات ذات المخزون الصفري (تحسين الأداء وإخفاء المنتجات المنفذة)
      if (product.quantity <= 0) {
        return false;
      }

      // فلترة بالبحث النصي
      final searchQuery = _searchController.text.toLowerCase();
      if (searchQuery.isNotEmpty) {
        if (!product.name.toLowerCase().contains(searchQuery) &&
            !product.description.toLowerCase().contains(searchQuery) &&
            !(product.sku?.toLowerCase().contains(searchQuery) ?? false)) {
          return false;
        }
      }

      // فلترة بالفئة
      if (_selectedCategory != 'الكل' && product.category != _selectedCategory) {
        return false;
      }

      return true;
    }).toList();

    final zeroStockCount = products.where((p) => p.quantity <= 0).length;
    if (zeroStockCount > 0) {
      AppLogger.info('🚫 تم استبعاد $zeroStockCount منتج بمخزون صفري من إجمالي $originalCount منتج API');
    }

    return filteredProducts;
  }

  /// فلترة منتجات المعرض
  List<dynamic> _filterExhibitionProducts(List<dynamic> products) {
    final originalCount = products.length;

    final filteredProducts = products.where((product) {
      // استبعاد المنتجات ذات المخزون الصفري
      if (product.quantity <= 0) {
        return false;
      }

      // فلترة بالبحث النصي
      final searchQuery = _searchController.text.toLowerCase();
      if (searchQuery.isNotEmpty) {
        final productName = product.product?.name ?? '';
        final productDescription = product.product?.description ?? '';
        final productSku = product.product?.sku ?? '';

        if (!productName.toLowerCase().contains(searchQuery) &&
            !productDescription.toLowerCase().contains(searchQuery) &&
            !productSku.toLowerCase().contains(searchQuery)) {
          return false;
        }
      }

      // فلترة بالفئة
      if (_selectedCategory != 'الكل') {
        final productCategory = product.product?.category ?? '';
        if (productCategory != _selectedCategory) {
          return false;
        }
      }

      return true;
    }).toList();

    final zeroStockCount = products.where((p) => p.quantity <= 0).length;
    if (zeroStockCount > 0) {
      AppLogger.info('🚫 تم استبعاد $zeroStockCount منتج معرض بمخزون صفري من إجمالي $originalCount منتج');
    }

    return filteredProducts;
  }

  /// بناء بطاقة منتج API محسنة ومهنية
  Widget _buildApiProductCard(ApiProductModel product, {bool isMissing = false}) {
    final statusColor = isMissing ? AccountantThemeConfig.warningOrange : AccountantThemeConfig.accentBlue;
    final quantityColor = product.quantity > 50
        ? AccountantThemeConfig.successGreen
        : product.quantity > 20
            ? AccountantThemeConfig.primaryGreen
            : product.quantity > 0
                ? AccountantThemeConfig.warningOrange
                : AccountantThemeConfig.dangerRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AccountantThemeConfig.cardBackground1,
            AccountantThemeConfig.cardBackground2.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showProductDetails(product),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رأس البطاقة المحسن
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // صورة المنتج المحسنة مع تأثيرات بصرية
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: EnhancedProductImage(
                              product: _convertApiProductToProductModel(product),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          // تأثير التدرج للحالة
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(8),
                                ),
                              ),
                              child: Icon(
                                isMissing ? Icons.warning_rounded : Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // معلومات المنتج المحسنة
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // اسم المنتج مع تحسينات التايبوغرافي
                          Text(
                            product.name,
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 6),

                          // الوصف مع تحسينات
                          if (product.description.isNotEmpty)
                            Text(
                              product.description,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                          const SizedBox(height: 8),

                          // شريط الحالة
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: statusColor.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isMissing ? 'مفقود من المعرض' : 'متوفر في المعرض',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // عرض الكمية بشكل بارز ومهني
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [quantityColor, quantityColor.withOpacity(0.8)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: quantityColor.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${product.quantity}',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'قطعة',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // تفاصيل إضافية محسنة
                Row(
                  children: [
                    // الفئة مع تصميم محسن
                    _buildEnhancedInfoChip(
                      product.category,
                      Icons.category_rounded,
                      AccountantThemeConfig.primaryGreen,
                    ),

                    const SizedBox(width: 10),

                    // SKU مع تصميم محسن
                    if (product.sku != null)
                      _buildEnhancedInfoChip(
                        product.sku!,
                        Icons.qr_code_rounded,
                        AccountantThemeConfig.accentBlue,
                      ),

                    const Spacer(),

                    // معلومات إضافية عن المنتج
                    if (isMissing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AccountantThemeConfig.warningOrange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AccountantThemeConfig.warningOrange.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_business_rounded,
                              size: 14,
                              color: AccountantThemeConfig.warningOrange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'يحتاج إضافة',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AccountantThemeConfig.warningOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء رقاقة معلومات محسنة
  Widget _buildEnhancedInfoChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.08),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: 12,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }



  /// عرض تفاصيل المنتج
  void _showProductDetails(ApiProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          product.name,
          style: AccountantThemeConfig.headlineSmall,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('المعرف', product.id),
            _buildDetailRow('الوصف', product.description),
            _buildDetailRow('الكمية المتوفرة', '${product.quantity} قطعة'),
            _buildDetailRow('الفئة', product.category),
            if (product.sku != null) _buildDetailRow('SKU', product.sku!),
            _buildDetailRow('الحالة', product.isActive ? 'نشط' : 'غير نشط'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إغلاق',
              style: GoogleFonts.cairo(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء صف تفاصيل
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AccountantThemeConfig.primaryGreen,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }



  /// بناء قسم فارغ
  Widget _buildEmptySection(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AccountantThemeConfig.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// بناء حالة التحميل المهنية مع تتبع التقدم
  Widget _buildLoadingState() {
    return WarehouseReportsLoader(
      stage: _progressService.currentStage,
      progress: _progressService.currentProgress,
      message: _progressService.currentMessage.isNotEmpty
          ? _progressService.currentMessage
          : 'جاري تحميل تقرير تحليل المعرض...',
      subMessage: _progressService.currentSubMessage,
      currentItem: _progressService.currentItem,
      totalItems: _progressService.totalItems,
      showProgress: true,
      onCancel: () {
        // يمكن إضافة منطق الإلغاء هنا إذا لزم الأمر
        AppLogger.info('🚫 المستخدم طلب إلغاء تحميل تقرير تحليل المعرض');
      },
    );
  }

  /// بناء حالة الخطأ المحسنة
  Widget _buildErrorState() {
    return WarehouseReportsErrorWidget(
      error: _error,
      operationName: 'تقرير تحليل المعرض',
      onRetry: _loadReport,
      context: {
        'report_type': 'exhibition_analysis',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// بناء حالة فارغة
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد بيانات للتحليل',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadReport,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تحديث البيانات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// تحويل ApiProductModel إلى ProductModel للتوافق مع EnhancedProductImage
  ProductModel _convertApiProductToProductModel(ApiProductModel apiProduct) {
    return ProductModel(
      id: apiProduct.id,
      name: apiProduct.name,
      description: apiProduct.description,
      price: apiProduct.price,
      quantity: apiProduct.quantity,
      category: apiProduct.category,
      imageUrl: apiProduct.imageUrl,
      images: apiProduct.imageUrl != null && apiProduct.imageUrl!.isNotEmpty
          ? [apiProduct.imageUrl!]
          : [],
      sku: apiProduct.sku ?? 'API-${apiProduct.id}',
      isActive: apiProduct.isActive,
      createdAt: DateTime.now(),
      reorderPoint: 10,
    );
  }
}
