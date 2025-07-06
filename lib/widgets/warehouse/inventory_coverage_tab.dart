import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/models/warehouse_reports_model.dart';
import 'package:smartbiztracker_new/models/warehouse_inventory_model.dart';
import 'package:smartbiztracker_new/services/warehouse_reports_service.dart';
import 'package:smartbiztracker_new/widgets/warehouse/collapsible_stats_widget.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_reports_loader.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_reports_error_widget.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// تبويب تغطية المخزون الذكي
class InventoryCoverageTab extends StatefulWidget {
  final WarehouseReportsService reportsService;

  const InventoryCoverageTab({
    Key? key,
    required this.reportsService,
  }) : super(key: key);

  @override
  State<InventoryCoverageTab> createState() => _InventoryCoverageTabState();
}

class _InventoryCoverageTabState extends State<InventoryCoverageTab>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  String? _error;
  InventoryCoverageReport? _report;

  // Progress tracking
  final WarehouseReportsProgressService _progressService = WarehouseReportsProgressService();

  // فلاتر البحث والترتيب
  final TextEditingController _searchController = TextEditingController();
  String _selectedSortBy = 'coverage'; // coverage, quantity, name, category
  bool _sortAscending = false;
  CoverageStatus? _selectedStatus;
  String _selectedCategory = 'الكل';
  List<String> _availableCategories = ['الكل'];

  // Pagination للأداء المحسن
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  bool _hasMoreItems = true;

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

  /// تحميل تقرير تغطية المخزون مع تتبع التقدم
  Future<void> _loadReport() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // إعادة تعيين خدمة التقدم
      _progressService.reset();

      AppLogger.info('📊 بدء تحميل تقرير تغطية المخزون الذكي مع تتبع التقدم');

      // المرحلة 1: تحميل المخازن
      _progressService.updateProgress(
        stage: 'warehouses',
        progress: 0.1,
        message: 'جاري تحميل بيانات المخازن...',
        subMessage: 'تحميل قائمة المخازن النشطة',
      );
      setState(() {}); // تحديث واجهة المستخدم

      // المرحلة 2: تحميل منتجات API
      _progressService.updateProgress(
        stage: 'api_products',
        progress: 0.3,
        message: 'جاري تحميل منتجات API...',
        subMessage: 'تحميل كتالوج المنتجات',
      );
      setState(() {});

      // المرحلة 3: تحليل المخزون
      _progressService.updateProgress(
        stage: 'inventory',
        progress: 0.5,
        message: 'جاري تحليل المخزون...',
        subMessage: 'معالجة بيانات المخزون عبر المخازن',
      );
      setState(() {});

      // تنفيذ التقرير الفعلي
      final report = await widget.reportsService.generateInventoryCoverageReport();

      // المرحلة 4: إنهاء التحليل
      _progressService.updateProgress(
        stage: 'finalizing',
        progress: 0.9,
        message: 'جاري إنهاء التقرير...',
        subMessage: 'تجهيز النتائج والإحصائيات',
      );
      setState(() {});

      // استخراج الفئات المتاحة
      final categories = <String>{'الكل'};
      categories.addAll(report.productAnalyses.map((p) => p.apiProduct.category));

      // إكمال التحميل
      _progressService.updateProgress(
        stage: 'finalizing',
        progress: 1.0,
        message: 'تم إكمال التقرير بنجاح',
        subMessage: 'جاهز للعرض',
      );

      setState(() {
        _report = report;
        _availableCategories = categories.toList()..sort();
        _isLoading = false;
      });

      AppLogger.info('✅ تم تحميل تقرير تغطية المخزون بنجاح مع ${report.productAnalyses.length} منتج');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل تقرير تغطية المخزون: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// معالجة تغيير البحث
  void _onSearchChanged() {
    setState(() {
      _currentPage = 0; // إعادة تعيين الصفحة عند تغيير البحث
    });
  }

  /// إعادة تعيين Pagination عند تغيير الفلاتر
  void _resetPagination() {
    setState(() {
      _currentPage = 0;
    });
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

        // الإحصائيات العامة القابلة للطي
        _buildCollapsibleGlobalStatistics(),

        // قائمة تحليل المنتجات مع ارتفاع محدد
        Container(
          height: 400, // ارتفاع ثابت لتجنب مشاكل التخطيط
          child: _buildProductAnalysisList(),
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
          
          // فلاتر الترتيب والحالة
          Row(
            children: [
              // فلتر الترتيب
              Expanded(
                child: _buildSortFilter(),
              ),
              
              const SizedBox(width: 8),
              
              // فلتر الحالة
              Expanded(
                child: _buildStatusFilter(),
              ),
              
              const SizedBox(width: 8),
              
              // فلتر الفئة
              Expanded(
                child: _buildCategoryFilter(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// بناء فلتر الترتيب
  Widget _buildSortFilter() {
    final sortOptions = {
      'coverage': 'نسبة التغطية',
      'quantity': 'إجمالي الكمية',
      'name': 'اسم المنتج',
      'category': 'الفئة',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground1.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSortBy,
                isExpanded: true,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 12,
                ),
                dropdownColor: AccountantThemeConfig.cardBackground1,
                icon: Icon(
                  Icons.sort_rounded,
                  color: AccountantThemeConfig.accentBlue,
                  size: 16,
                ),
                items: sortOptions.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedSortBy = value;
                      _resetPagination();
                    });
                  }
                },
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
              });
            },
            icon: Icon(
              _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: AccountantThemeConfig.accentBlue,
              size: 16,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  /// بناء فلتر الحالة
  Widget _buildStatusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground1.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.warningOrange.withOpacity(0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CoverageStatus?>(
          value: _selectedStatus,
          isExpanded: true,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 12,
          ),
          dropdownColor: AccountantThemeConfig.cardBackground1,
          icon: Icon(
            Icons.filter_list_rounded,
            color: AccountantThemeConfig.warningOrange,
            size: 16,
          ),
          items: [
            DropdownMenuItem<CoverageStatus?>(
              value: null,
              child: Text('جميع الحالات'),
            ),
            ...CoverageStatus.values.map((status) {
              return DropdownMenuItem<CoverageStatus?>(
                value: status,
                child: Text(status.displayName),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedStatus = value;
              _resetPagination();
            });
          },
        ),
      ),
    );
  }

  /// بناء فلتر الفئة
  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
            fontSize: 12,
          ),
          dropdownColor: AccountantThemeConfig.cardBackground1,
          icon: Icon(
            Icons.category_rounded,
            color: AccountantThemeConfig.primaryGreen,
            size: 16,
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
                _resetPagination();
              });
            }
          },
        ),
      ),
    );
  }

  /// بناء الإحصائيات العامة القابلة للطي
  Widget _buildCollapsibleGlobalStatistics() {
    final stats = _report!.coverageStatistics;
    final distribution = stats['coverage_distribution'] as Map<String, int>;

    return CollapsibleStatsWidget(
      title: 'إحصائيات تغطية المخزون العامة',
      icon: Icons.dashboard_rounded,
      accentColor: AccountantThemeConfig.primaryGreen,
      initiallyExpanded: false, // مطوية افتراضياً لتوفير مساحة
      children: [
        // الإحصائيات الرئيسية
        StatsGrid(
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          cards: [
            StatCard(
              title: 'إجمالي المنتجات',
              value: '${stats['total_products_analyzed']}',
              icon: Icons.inventory_2_rounded,
              color: AccountantThemeConfig.accentBlue,
              subtitle: 'منتج للتحليل',
            ),
            StatCard(
              title: 'منتجات بمخزون',
              value: '${stats['products_with_stock']}',
              icon: Icons.check_circle_rounded,
              color: AccountantThemeConfig.successGreen,
              subtitle: 'مخزون > 0',
            ),
            StatCard(
              title: 'منتجات بدون مخزون',
              value: '${stats['products_without_stock']}',
              icon: Icons.warning_rounded,
              color: AccountantThemeConfig.warningOrange,
              subtitle: 'مخزون = 0',
            ),
            StatCard(
              title: 'متوسط التغطية',
              value: '${(stats['average_coverage_percentage'] as double).toStringAsFixed(1)}%',
              icon: Icons.analytics_rounded,
              color: AccountantThemeConfig.primaryGreen,
              subtitle: 'نسبة عامة',
            ),
          ],
        ),

        const SizedBox(height: 16),

        // توزيع التغطية
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'توزيع مستويات التغطية',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            _buildCoverageDistribution(distribution),
          ],
        ),
      ],
    );
  }



  /// بناء توزيع التغطية
  Widget _buildCoverageDistribution(Map<String, int> distribution) {
    final statusColors = {
      'excellent': AccountantThemeConfig.successGreen,
      'good': AccountantThemeConfig.accentBlue,
      'moderate': AccountantThemeConfig.primaryGreen,
      'low': AccountantThemeConfig.warningOrange,
      'critical': Color(0xFFEF4444),
      'exception': Color(0xFF8B5CF6), // Purple for exception status
    };

    final statusNames = {
      'excellent': 'ممتازة',
      'good': 'جيدة',
      'moderate': 'متوسطة',
      'low': 'منخفضة',
      'critical': 'حرجة',
      'exception': 'استثنائية',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: distribution.entries.map((entry) {
        final status = entry.key;
        final count = entry.value;
        final color = statusColors[status] ?? Colors.grey;
        final name = statusNames[status] ?? status;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$name ($count)',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// بناء قائمة تحليل المنتجات مع Pagination للأداء المحسن
  Widget _buildProductAnalysisList() {
    final filteredAnalyses = _getFilteredAndSortedAnalyses();

    if (filteredAnalyses.isEmpty) {
      return _buildEmptySection();
    }

    // تطبيق Pagination
    final totalItems = filteredAnalyses.length;
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
    final paginatedAnalyses = filteredAnalyses.sublist(startIndex, endIndex);

    _hasMoreItems = endIndex < totalItems;

    return Column(
      children: [
        // معلومات Pagination
        _buildPaginationInfo(totalItems, startIndex + 1, endIndex),

        // قائمة المنتجات
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: paginatedAnalyses.length,
            itemBuilder: (context, index) {
              final analysis = paginatedAnalyses[index];
              return _buildProductAnalysisCard(analysis);
            },
          ),
        ),

        // أزرار التنقل
        _buildPaginationControls(totalItems),
      ],
    );
  }

  /// الحصول على التحليلات المفلترة والمرتبة
  List<ProductCoverageAnalysis> _getFilteredAndSortedAnalyses() {
    var analyses = _report!.productAnalyses.where((analysis) {
      // معالجة المنتجات الاستثنائية (API بكمية صفر)
      if (analysis.status == CoverageStatus.exception) {
        // عرض المنتجات الاستثنائية فقط إذا تم اختيار فلتر الاستثناء تحديداً
        if (_selectedStatus != CoverageStatus.exception) {
          return false;
        }
      }

      // استبعاد المنتجات ذات المخزون الصفري من العرض (ولكن الاحتفاظ بها في الإحصائيات)
      // يمكن عرضها فقط إذا كان المستخدم يبحث عن حالة "مفقودة" تحديداً
      if (analysis.totalWarehouseQuantity == 0 &&
          analysis.status != CoverageStatus.exception &&
          _selectedStatus != CoverageStatus.missing) {
        return false;
      }

      // فلترة بالبحث النصي
      final searchQuery = _searchController.text.toLowerCase();
      if (searchQuery.isNotEmpty) {
        if (!analysis.apiProduct.name.toLowerCase().contains(searchQuery) &&
            !analysis.apiProduct.description.toLowerCase().contains(searchQuery) &&
            !(analysis.apiProduct.sku?.toLowerCase().contains(searchQuery) ?? false)) {
          return false;
        }
      }

      // فلترة بالحالة
      if (_selectedStatus != null && analysis.status != _selectedStatus) {
        return false;
      }

      // فلترة بالفئة
      if (_selectedCategory != 'الكل' && analysis.apiProduct.category != _selectedCategory) {
        return false;
      }

      return true;
    }).toList();

    // ترتيب النتائج
    analyses.sort((a, b) {
      int comparison = 0;

      switch (_selectedSortBy) {
        case 'coverage':
          comparison = a.coveragePercentage.compareTo(b.coveragePercentage);
          break;
        case 'quantity':
          comparison = a.totalWarehouseQuantity.compareTo(b.totalWarehouseQuantity);
          break;
        case 'name':
          comparison = a.apiProduct.name.compareTo(b.apiProduct.name);
          break;
        case 'category':
          comparison = a.apiProduct.category.compareTo(b.apiProduct.category);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return analyses;
  }

  /// بناء بطاقة تحليل المنتج
  Widget _buildProductAnalysisCard(ProductCoverageAnalysis analysis) {
    final statusColor = Color(int.parse(analysis.status.colorCode.substring(1), radix: 16) + 0xFF000000);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showProductAnalysisDetails(analysis),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رأس البطاقة
                Row(
                  children: [
                    // أيقونة المنتج
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.2),
                            statusColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(analysis.status),
                        color: statusColor,
                        size: 24,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // معلومات المنتج
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            analysis.apiProduct.name,
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            analysis.apiProduct.category,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // حالة التغطية
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        analysis.status.displayName,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // شريط التقدم الذكي
                _buildSmartProgressBar(analysis),

                const SizedBox(height: 12),

                // مقارنة الكميات (API مقابل المخازن)
                _buildQuantityComparison(analysis),

                const SizedBox(height: 12),

                // معلومات التوزيع
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'إجمالي المخازن',
                        '${analysis.totalWarehouseQuantity}',
                        Icons.inventory_rounded,
                        AccountantThemeConfig.accentBlue,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        'عدد المخازن',
                        '${analysis.warehouseInventories.length}',
                        Icons.warehouse_rounded,
                        AccountantThemeConfig.primaryGreen,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        'إجمالي الكراتين',
                        '${analysis.totalCartons}',
                        Icons.inventory_2_rounded,
                        AccountantThemeConfig.warningOrange,
                      ),
                    ),
                  ],
                ),

                // التوصيات (إذا وجدت)
                if (analysis.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildRecommendations(analysis.recommendations),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء مقارنة الكميات (API مقابل المخازن)
  Widget _buildQuantityComparison(ProductCoverageAnalysis analysis) {
    final apiQuantity = analysis.apiProduct.quantity;
    final warehouseQuantity = analysis.totalWarehouseQuantity;
    final difference = warehouseQuantity - apiQuantity;

    // تحديد اللون بناءً على الحالة
    Color statusColor;
    String statusText;
    IconData statusIcon;

    // معالجة الحالة الاستثنائية (API بكمية صفر)
    if (analysis.status == CoverageStatus.exception) {
      statusColor = Color(0xFF8B5CF6); // Purple for exception
      statusText = 'منتج غير متوفر في API (كمية = 0)';
      statusIcon = Icons.help_outline_rounded;
    } else if (difference > 0) {
      statusColor = AccountantThemeConfig.successGreen;
      statusText = 'فائض: ${difference} قطعة';
      statusIcon = Icons.trending_up_rounded;
    } else if (difference < 0) {
      statusColor = AccountantThemeConfig.dangerRed;
      statusText = 'نقص: ${difference.abs()} قطعة';
      statusIcon = Icons.trending_down_rounded;
    } else {
      statusColor = AccountantThemeConfig.primaryGreen;
      statusText = 'مطابق تماماً';
      statusIcon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // العنوان
          Row(
            children: [
              Icon(
                Icons.compare_arrows_rounded,
                color: statusColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'مقارنة الكميات',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // مقارنة الكميات
          Row(
            children: [
              // كمية API
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'كمية API',
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      '$apiQuantity',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AccountantThemeConfig.accentBlue,
                      ),
                    ),
                  ],
                ),
              ),

              // أيقونة المقارنة
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 16,
                ),
              ),

              // كمية المخازن
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'كمية المخازن',
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      '$warehouseQuantity',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AccountantThemeConfig.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // حالة الفرق
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء شريط التقدم الذكي
  Widget _buildSmartProgressBar(ProductCoverageAnalysis analysis) {
    final percentage = analysis.status == CoverageStatus.exception
        ? 0.0
        : analysis.coveragePercentage.clamp(0.0, 100.0);
    final statusColor = Color(int.parse(analysis.status.colorCode.substring(1), radix: 16) + 0xFF000000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'تغطية المخزون الذكية',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            Text(
              analysis.status == CoverageStatus.exception
                  ? 'غير قابل للحساب'
                  : '${percentage.toStringAsFixed(1)}%',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // شريط التقدم
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage / 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // تفسير التغطية
        Text(
          _getCoverageExplanation(analysis),
          style: GoogleFonts.cairo(
            fontSize: 10,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  /// بناء عنصر معلومات
  Widget _buildInfoItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 10,
            color: Colors.white.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// بناء التوصيات
  Widget _buildRecommendations(List<String> recommendations) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: AccountantThemeConfig.primaryGreen,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'توصيات ذكية',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...recommendations.take(2).map((recommendation) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                ),
                Expanded(
                  child: Text(
                    recommendation,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// الحصول على أيقونة الحالة
  IconData _getStatusIcon(CoverageStatus status) {
    switch (status) {
      case CoverageStatus.excellent:
        return Icons.check_circle_rounded;
      case CoverageStatus.good:
        return Icons.thumb_up_rounded;
      case CoverageStatus.moderate:
        return Icons.info_rounded;
      case CoverageStatus.low:
        return Icons.warning_rounded;
      case CoverageStatus.critical:
        return Icons.error_rounded;
      case CoverageStatus.missing:
        return Icons.cancel_rounded;
      case CoverageStatus.exception:
        return Icons.help_outline_rounded; // أيقونة خاصة للحالة الاستثنائية
    }
  }

  /// الحصول على تفسير التغطية
  String _getCoverageExplanation(ProductCoverageAnalysis analysis) {
    final quantity = analysis.totalWarehouseQuantity;
    final warehouses = analysis.warehouseInventories.length;

    if (quantity == 0) {
      return 'لا يوجد مخزون لهذا المنتج في أي مخزن';
    }

    if (warehouses == 1) {
      return 'متوفر في مخزن واحد فقط - يُنصح بالتوزيع';
    }

    return 'موزع على $warehouses مخزن بإجمالي $quantity قطعة';
  }

  /// عرض تفاصيل تحليل المنتج
  void _showProductAnalysisDetails(ProductCoverageAnalysis analysis) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // عنوان الحوار
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'تحليل تفصيلي للمنتج',
                      style: AccountantThemeConfig.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // معلومات المنتج
              _buildDetailSection('معلومات المنتج', [
                _buildDetailRow('الاسم', analysis.apiProduct.name),
                _buildDetailRow('الفئة', analysis.apiProduct.category),
                _buildDetailRow('السعر', '${analysis.apiProduct.price.toStringAsFixed(2)} ج.م'),
                if (analysis.apiProduct.sku != null)
                  _buildDetailRow('SKU', analysis.apiProduct.sku!),
              ]),

              const SizedBox(height: 16),

              // إحصائيات التغطية
              _buildDetailSection('إحصائيات التغطية', [
                _buildDetailRow('نسبة التغطية',
                  analysis.status == CoverageStatus.exception
                    ? 'غير قابل للحساب (API: 0)'
                    : '${analysis.coveragePercentage.toStringAsFixed(1)}%'),
                _buildDetailRow('حالة التغطية', analysis.status.displayName),
                _buildDetailRow('كمية API', '${analysis.apiProduct.quantity}'),
                _buildDetailRow('كمية المخازن', '${analysis.totalWarehouseQuantity}'),
                _buildDetailRow('الفرق',
                  analysis.status == CoverageStatus.exception
                    ? 'غير قابل للحساب'
                    : '${analysis.totalWarehouseQuantity - analysis.apiProduct.quantity}'),
                _buildDetailRow('عدد المخازن', '${analysis.warehouseInventories.length}'),
                _buildDetailRow('إجمالي الكراتين', '${analysis.totalCartons}'),
              ]),

              const SizedBox(height: 16),

              // توزيع المخازن
              if (analysis.warehouseInventories.isNotEmpty) ...[
                Text(
                  'توزيع المخازن',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: analysis.warehouseInventories.length,
                    itemBuilder: (context, index) {
                      final inventory = analysis.warehouseInventories[index];
                      final warehouseName = _getWarehouseName(inventory);
                      final quantityColor = _getQuantityColor(inventory.quantity);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AccountantThemeConfig.cardBackground1.withOpacity(0.6),
                              AccountantThemeConfig.cardBackground2.withOpacity(0.4),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: quantityColor.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: quantityColor.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // أيقونة المخزن مع تحسينات بصرية
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.warehouse_rounded,
                                color: AccountantThemeConfig.accentBlue,
                                size: 18,
                              ),
                            ),

                            const SizedBox(width: 12),

                            // اسم المخزن مع معالجة محسنة للأخطاء
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    warehouseName,
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (inventory.warehouseName == null)
                                    Text(
                                      'معرف: ${inventory.warehouseId}',
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // عرض الكمية مع تصميم محسن
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [quantityColor, quantityColor.withOpacity(0.8)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: quantityColor.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${inventory.quantity}',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
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
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// بناء قسم تفاصيل
  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AccountantThemeConfig.primaryGreen,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  /// بناء صف تفاصيل
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء معلومات Pagination
  Widget _buildPaginationInfo(int totalItems, int startItem, int endItem) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'عرض $startItem-$endItem من $totalItems منتج',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          Text(
            'صفحة ${_currentPage + 1} من ${((totalItems - 1) ~/ _itemsPerPage) + 1}',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء أزرار التنقل
  Widget _buildPaginationControls(int totalItems) {
    final totalPages = ((totalItems - 1) ~/ _itemsPerPage) + 1;
    final canGoBack = _currentPage > 0;
    final canGoForward = _currentPage < totalPages - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // زر الصفحة السابقة
          IconButton(
            onPressed: canGoBack ? () {
              setState(() {
                _currentPage--;
              });
            } : null,
            icon: const Icon(Icons.chevron_right_rounded),
            style: IconButton.styleFrom(
              backgroundColor: canGoBack
                  ? AccountantThemeConfig.primaryGreen.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              foregroundColor: canGoBack
                  ? AccountantThemeConfig.primaryGreen
                  : Colors.grey,
            ),
          ),

          const SizedBox(width: 16),

          // معلومات الصفحة الحالية
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
              ),
            ),
            child: Text(
              '${_currentPage + 1} / $totalPages',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // زر الصفحة التالية
          IconButton(
            onPressed: canGoForward ? () {
              setState(() {
                _currentPage++;
              });
            } : null,
            icon: const Icon(Icons.chevron_left_rounded),
            style: IconButton.styleFrom(
              backgroundColor: canGoForward
                  ? AccountantThemeConfig.primaryGreen.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              foregroundColor: canGoForward
                  ? AccountantThemeConfig.primaryGreen
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء قسم فارغ
  Widget _buildEmptySection() {
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
            'لا توجد منتجات تطابق المعايير المحددة',
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
          : 'جاري تحميل تقرير تغطية المخزون...',
      subMessage: _progressService.currentSubMessage,
      currentItem: _progressService.currentItem,
      totalItems: _progressService.totalItems,
      showProgress: true,
      onCancel: () {
        // يمكن إضافة منطق الإلغاء هنا إذا لزم الأمر
        AppLogger.info('🚫 المستخدم طلب إلغاء تحميل تقرير تغطية المخزون');
      },
    );
  }

  /// بناء حالة الخطأ المحسنة
  Widget _buildErrorState() {
    return WarehouseReportsErrorWidget(
      error: _error,
      operationName: 'تقرير تغطية المخزون',
      onRetry: _loadReport,
      context: {
        'report_type': 'inventory_coverage',
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
            Icons.dashboard_outlined,
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

  /// الحصول على اسم المخزن مع معالجة محسنة للأخطاء
  String _getWarehouseName(WarehouseInventoryModel inventory) {
    if (inventory.warehouseName != null && inventory.warehouseName!.isNotEmpty) {
      return inventory.warehouseName!;
    }

    // محاولة الحصول على اسم المخزن من معرف المخزن
    final warehouseId = inventory.warehouseId;

    // إذا كان معرف المخزن يحتوي على نص وصفي
    if (warehouseId.contains('exhibition') || warehouseId.contains('معرض')) {
      return 'مخزن المعرض';
    } else if (warehouseId.contains('main') || warehouseId.contains('رئيسي')) {
      return 'المخزن الرئيسي';
    } else if (warehouseId.contains('secondary') || warehouseId.contains('ثانوي')) {
      return 'المخزن الثانوي';
    }

    // الافتراضي: عرض معرف المخزن مع تحسين التنسيق
    return 'مخزن ${warehouseId.length > 8 ? warehouseId.substring(0, 8) + '...' : warehouseId}';
  }

  /// تحديد لون الكمية بناءً على المستوى
  Color _getQuantityColor(int quantity) {
    if (quantity >= 100) {
      return AccountantThemeConfig.successGreen;
    } else if (quantity >= 50) {
      return AccountantThemeConfig.primaryGreen;
    } else if (quantity >= 20) {
      return AccountantThemeConfig.accentBlue;
    } else if (quantity > 0) {
      return AccountantThemeConfig.warningOrange;
    } else {
      return AccountantThemeConfig.dangerRed;
    }
  }
}
