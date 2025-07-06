import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/services/optimized_analytics_service.dart';
import 'package:smartbiztracker_new/services/optimized_data_pipeline.dart';
import 'package:smartbiztracker_new/services/smart_cache_manager.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/screens/owner/comprehensive_reports_screen.dart';

/// Optimized Reports Tab Widget for Owner Dashboard
/// Provides instant loading with intelligent caching and background updates
class OptimizedReportsTab extends StatefulWidget {
  const OptimizedReportsTab({super.key});

  @override
  State<OptimizedReportsTab> createState() => _OptimizedReportsTabState();
}

class _OptimizedReportsTabState extends State<OptimizedReportsTab> {
  // Optimized services
  final OptimizedAnalyticsService _analyticsService = OptimizedAnalyticsService();
  final OptimizedDataPipeline _dataPipeline = OptimizedDataPipeline();
  final SmartCacheManager _cacheManager = SmartCacheManager();

  // State variables
  bool _isLoading = false;
  Map<String, dynamic>? _reportsData;
  String? _error;
  String _selectedPeriod = 'أسبوعي';
  final List<String> _periods = ['أسبوعي', 'شهري', 'سنوي'];

  @override
  void initState() {
    super.initState();
    _initializeOptimizedReports();
  }

  /// Initialize optimized reports with instant loading
  Future<void> _initializeOptimizedReports() async {
    try {
      AppLogger.info('🚀 Initializing optimized reports tab...');
      
      // Initialize data pipeline
      await _dataPipeline.initialize();
      
      // Load reports data with caching
      await _loadReportsData(useCache: true);
      
      AppLogger.info('✅ Optimized reports tab initialized successfully');
    } catch (e) {
      AppLogger.error('❌ Error initializing optimized reports: $e');
      if (mounted) {
        setState(() {
          _error = 'فشل في تحميل التقارير: ${e.toString()}';
        });
      }
    }
  }

  /// Load reports data with intelligent caching
  Future<void> _loadReportsData({bool useCache = true, bool forceRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (forceRefresh) _error = null;
    });

    try {
      AppLogger.info('🔄 Loading reports data (useCache: $useCache, forceRefresh: $forceRefresh)');

      // Get dashboard data with optimized pipeline
      final dashboardData = await _dataPipeline.getDashboardData(
        period: _selectedPeriod,
        forceRefresh: forceRefresh,
      );

      // Get additional reports data
      final reportsData = await _dataPipeline.getReportsData(
        loadCharts: true,
        loadAnalytics: true,
        loadTrends: false, // Lazy load trends
      );

      // Combine data
      final combinedData = {
        ...dashboardData,
        'reportsData': reportsData,
        'performanceMetrics': _cacheManager.getStatistics(),
      };

      if (mounted) {
        setState(() {
          _reportsData = combinedData;
          _isLoading = false;
          _error = null;
        });
      }

      AppLogger.info('✅ Reports data loaded successfully');
    } catch (e) {
      AppLogger.error('❌ Error loading reports data: $e');
      if (mounted) {
        setState(() {
          _error = 'فشل في تحميل البيانات: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  /// Handle period change with optimized loading
  Future<void> _onPeriodChanged(String newPeriod) async {
    if (newPeriod == _selectedPeriod) return;

    setState(() {
      _selectedPeriod = newPeriod;
    });

    // Load data for new period (use cache first, then refresh in background)
    await _loadReportsData(useCache: true);
    
    // Refresh in background for next time
    _loadReportsData(useCache: false, forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    // Add safety check to prevent rendering issues
    if (!mounted) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ensure constraints are valid
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const Center(child: CircularProgressIndicator());
        }

        final isTablet = constraints.maxWidth > 600;
        final isMobile = constraints.maxWidth <= 600;

        return Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modern header
                _buildModernHeader(isMobile, isTablet),
                
                SizedBox(height: isMobile ? 16 : 24),
                
                // Period selector
                _buildPeriodSelector(isMobile),
                
                SizedBox(height: isMobile ? 16 : 24),
                
                // Content based on loading state
                if (_isLoading && _reportsData == null)
                  _buildLoadingState(isMobile)
                else if (_error != null && _reportsData == null)
                  _buildErrorState(isMobile)
                else if (_reportsData != null)
                  _buildReportsContent(isMobile, isTablet)
                else
                  _buildErrorState(isMobile),
                
                SizedBox(height: isMobile ? 16 : 24),
                
                // Launch comprehensive reports button
                _buildLaunchButton(isMobile),
                
                // Performance metrics (debug info)
                if (_reportsData != null) _buildPerformanceMetrics(isMobile),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernHeader(bool isMobile, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.analytics_rounded,
              size: isMobile ? 32 : 40,
              color: Colors.white,
            ),
          ),
          
          SizedBox(width: isMobile ? 12 : 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'التقارير المحسنة',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تحميل فوري مع ذاكرة تخزين ذكية',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          
          if (_isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _periods.asMap().entries.map((entry) {
          final index = entry.key;
          final period = entry.value;
          final isSelected = period == _selectedPeriod;
          
          return Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(period),
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 8 : 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AccountantThemeConfig.primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoadingState(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 32 : 48),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Text(
            'جاري تحميل التقارير المحسنة...',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 14 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: isMobile ? 32 : 40,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            _error ?? 'حدث خطأ غير متوقع',
            style: TextStyle(
              color: Colors.red,
              fontSize: isMobile ? 14 : 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          ElevatedButton(
            onPressed: () => _loadReportsData(useCache: false, forceRefresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsContent(bool isMobile, bool isTablet) {
    // Add null safety check
    if (_reportsData == null) {
      return _buildErrorState(isMobile);
    }

    final data = _reportsData!;
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    
    return Column(
      children: [
        // Quick stats
        _buildQuickStats(summary, isMobile),
        
        SizedBox(height: isMobile ? 16 : 24),
        
        // Performance indicator
        _buildPerformanceIndicator(isMobile),
      ],
    );
  }

  Widget _buildQuickStats(Map<String, dynamic> summary, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص سريع',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'إجمالي الإيرادات',
                  '${(summary['totalRevenue'] as num?)?.toStringAsFixed(0) ?? '0'} ج.م',
                  Icons.attach_money,
                  isMobile,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: _buildStatItem(
                  'إجمالي المعاملات',
                  '${summary['totalTransactions'] ?? 0}',
                  Icons.receipt_long,
                  isMobile,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AccountantThemeConfig.primaryGreen, size: isMobile ? 16 : 20),
          SizedBox(height: isMobile ? 4 : 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceIndicator(bool isMobile) {
    if (_reportsData == null) return const SizedBox.shrink();
    final metrics = _reportsData!['performanceMetrics'] as Map<String, dynamic>? ?? {};
    final hitRate = (metrics['hitRate'] as num?)?.toDouble() ?? 0.0;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.speed,
            color: Colors.green,
            size: isMobile ? 16 : 20,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Text(
              'أداء محسن: ${(hitRate * 100).toStringAsFixed(1)}% معدل نجاح التخزين المؤقت',
              style: TextStyle(
                color: Colors.green,
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaunchButton(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ComprehensiveReportsScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 16 : 20,
              horizontal: isMobile ? 16 : 24,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.launch_rounded,
                  size: isMobile ? 18 : 22,
                  color: Colors.white,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Text(
                  'فتح التقارير الشاملة',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceMetrics(bool isMobile) {
    if (_reportsData == null) return const SizedBox.shrink();
    final metrics = _reportsData!['performanceMetrics'] as Map<String, dynamic>? ?? {};
    
    return Container(
      margin: EdgeInsets.only(top: isMobile ? 16 : 24),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مؤشرات الأداء',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            'عناصر مخزنة: ${metrics['cachedItems'] ?? 0} | '
            'نجاح التخزين: ${metrics['totalHits'] ?? 0} | '
            'فشل التخزين: ${metrics['totalMisses'] ?? 0}',
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}
