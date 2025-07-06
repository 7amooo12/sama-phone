import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/warehouse_reports_model.dart';
import 'package:smartbiztracker_new/services/warehouse_reports_service.dart';
import 'package:smartbiztracker_new/widgets/warehouse/exhibition_analysis_tab.dart';
import 'package:smartbiztracker_new/widgets/warehouse/inventory_coverage_tab.dart';
import 'package:smartbiztracker_new/widgets/warehouse/collapsible_stats_widget.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// شاشة تقارير المخازن المتقدمة
class WarehouseReportsScreen extends StatefulWidget {
  const WarehouseReportsScreen({Key? key}) : super(key: key);

  @override
  State<WarehouseReportsScreen> createState() => _WarehouseReportsScreenState();
}

class _WarehouseReportsScreenState extends State<WarehouseReportsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late WarehouseReportsService _reportsService;
  
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _quickStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _reportsService = WarehouseReportsService();
    
    // تحميل الإحصائيات السريعة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuickStats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// تحميل الإحصائيات السريعة
  Future<void> _loadQuickStats() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      AppLogger.info('📊 تحميل الإحصائيات السريعة للتقارير');
      final stats = await _reportsService.getQuickReportStats();
      
      setState(() {
        _quickStats = stats;
        _isLoading = false;
      });

      AppLogger.info('✅ تم تحميل الإحصائيات السريعة بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل الإحصائيات السريعة: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // شريط التطبيق المخصص
              _buildCustomAppBar(),

              // شريط التبويبات
              _buildTabBar(),

              // محتوى التبويبات مع التمرير
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _error != null
                        ? _buildErrorState()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildScrollableTab(
                                ExhibitionAnalysisTab(reportsService: _reportsService),
                              ),
                              _buildScrollableTab(
                                InventoryCoverageTab(reportsService: _reportsService),
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

  /// بناء تبويب قابل للتمرير بالكامل (محسن للأداء ومساحة الشاشة مع إصلاح قيود التخطيط)
  Widget _buildScrollableTab(Widget tabContent) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // الإحصائيات السريعة القابلة للطي (قابلة للتمرير)
          if (!_isLoading && _quickStats != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildCollapsibleQuickStats(),
            ),

          // محتوى التبويب مع ارتفاع محدد لتجنب مشاكل التخطيط
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 300, // ارتفاع مناسب
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: tabContent,
            ),
          ),
        ],
      ),
    );
  }





  /// بناء شريط التطبيق المخصص
  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.blueGradient,
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
      ),
      child: Row(
        children: [
          // زر الرجوع
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // العنوان والوصف
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تقارير المخازن المتقدمة',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'تحليل ذكي شامل للمخزون والتغطية',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          
          // زر التحديث
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _loadQuickStats,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء الإحصائيات السريعة القابلة للطي
  Widget _buildCollapsibleQuickStats() {
    return CollapsibleStatsWidget(
      title: 'نظرة عامة سريعة',
      icon: Icons.dashboard_rounded,
      accentColor: AccountantThemeConfig.primaryGreen,
      initiallyExpanded: false, // تغيير إلى مطوية افتراضياً لتحسين UX
      children: [
        StatsGrid(
          cards: [
            StatCard(
              title: 'إجمالي المخازن',
              value: '${_quickStats!['total_warehouses']}',
              icon: Icons.warehouse_rounded,
              color: AccountantThemeConfig.accentBlue,
              subtitle: '${_quickStats!['active_warehouses']} نشط',
            ),
            StatCard(
              title: 'منتجات API',
              value: '${_quickStats!['total_api_products']}',
              icon: Icons.api_rounded,
              color: AccountantThemeConfig.primaryGreen,
              subtitle: 'منتجات نشطة',
            ),
            StatCard(
              title: 'منتجات المعرض',
              value: '${_quickStats!['exhibition_products_count']}',
              icon: Icons.store_rounded,
              color: AccountantThemeConfig.warningOrange,
              subtitle: 'مخزون > 0',
            ),
            StatCard(
              title: 'تغطية المعرض',
              value: '${(_quickStats!['exhibition_coverage_percentage'] as double).toStringAsFixed(1)}%',
              icon: Icons.analytics_rounded,
              color: AccountantThemeConfig.successGreen,
              subtitle: 'نسبة التغطية',
            ),
          ],
        ),

        const SizedBox(height: 16),

        // إحصائيات إضافية
        StatsRow(
          cards: [
            StatCard(
              title: 'إجمالي المنتجات',
              value: '${_quickStats!['total_inventory_items']}',
              icon: Icons.inventory_rounded,
              color: AccountantThemeConfig.accentBlue,
              subtitle: 'عبر جميع المخازن',
            ),
            StatCard(
              title: 'إجمالي الكمية',
              value: '${_quickStats!['total_quantity']}',
              icon: Icons.numbers_rounded,
              color: AccountantThemeConfig.primaryGreen,
              subtitle: 'قطعة',
            ),
          ],
        ),
      ],
    );
  }



  /// بناء شريط التبويبات
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground1.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AccountantThemeConfig.greenGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        labelStyle: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.7),
        tabs: const [
          Tab(
            icon: Icon(Icons.analytics_outlined, size: 20),
            text: 'تحليل المعرض',
          ),
          Tab(
            icon: Icon(Icons.dashboard_outlined, size: 20),
            text: 'تغطية المخزون',
          ),
        ],
      ),
    );
  }

  /// بناء حالة التحميل
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AccountantThemeConfig.primaryGreen,
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل التقارير...',
            style: AccountantThemeConfig.bodyLarge,
          ),
        ],
      ),
    );
  }

  /// بناء حالة الخطأ
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AccountantThemeConfig.warningOrange,
          ),
          const SizedBox(height: 16),
          Text(
            'خطأ في تحميل التقارير',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'حدث خطأ غير متوقع',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadQuickStats,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
