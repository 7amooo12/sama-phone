import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/screens/manufacturing/widgets/manufacturing_tools_tracking_widgets.dart';
import 'package:smartbiztracker_new/screens/manufacturing/widgets/manufacturing_tools_search_widget.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_search_service.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_export_service.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_validation_service.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_edge_cases_handler.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// قسم أدوات التصنيع المستخدمة مع التحليلات الشاملة
class UsedManufacturingToolsSection extends StatefulWidget {
  final int batchId;
  final double unitsProduced;
  final bool isLoading;
  final List<ToolUsageAnalytics> toolAnalytics;
  final VoidCallback? onRefresh;
  final Function(int toolId)? onToolTap;

  const UsedManufacturingToolsSection({
    super.key,
    required this.batchId,
    required this.unitsProduced,
    this.isLoading = false,
    required this.toolAnalytics,
    this.onRefresh,
    this.onToolTap,
  });

  @override
  State<UsedManufacturingToolsSection> createState() => _UsedManufacturingToolsSectionState();
}

class _UsedManufacturingToolsSectionState extends State<UsedManufacturingToolsSection>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Search and filter functionality
  final ManufacturingToolsSearchService _searchService = ManufacturingToolsSearchService();
  final ManufacturingToolsExportService _exportService = ManufacturingToolsExportService();
  final ManufacturingToolsValidationService _validationService = ManufacturingToolsValidationService();
  ToolSearchCriteria _searchCriteria = const ToolSearchCriteria();
  ToolSearchResults<ToolUsageAnalytics>? _searchResults;
  bool _showSearchWidget = false;

  // Validation and error handling
  ValidationResult? _validationResult;
  String? _errorMessage;
  bool _hasDataIntegrityIssues = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: AccountantThemeConfig.glowBorder(Colors.white.withOpacity(0.3)),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(),
              const SizedBox(height: 24),
              if (_showSearchWidget) ...[
                _buildSearchWidget(),
                const SizedBox(height: 20),
              ],
              if (widget.isLoading)
                _buildLoadingState()
              else if (_errorMessage != null)
                _buildErrorState()
              else if (widget.toolAnalytics.isEmpty)
                _buildEmptyState()
              else ...[
                if (_hasDataIntegrityIssues)
                  _buildValidationWarning(),
                if (_hasDataIntegrityIssues)
                  const SizedBox(height: 16),
                _buildOverallSummary(),
                const SizedBox(height: 24),
                _buildToolsAnalyticsList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AccountantThemeConfig.accentBlue,
                AccountantThemeConfig.accentBlue.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.precision_manufacturing,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أدوات التصنيع المستخدمة',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'تحليلات شاملة لاستهلاك الأدوات',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _toggleSearchWidget,
                icon: Icon(
                  _showSearchWidget ? Icons.search_off : Icons.search,
                  color: _showSearchWidget
                      ? AccountantThemeConfig.primaryGreen
                      : AccountantThemeConfig.accentBlue,
                ),
                tooltip: _showSearchWidget ? 'إخفاء البحث' : 'إظهار البحث',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _showExportDialog,
                icon: Icon(
                  Icons.file_download,
                  color: Colors.orange,
                ),
                tooltip: 'تصدير التقرير',
              ),
            ),
            if (widget.onRefresh != null) ...[
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: widget.onRefresh,
                  icon: Icon(
                    Icons.refresh,
                    color: AccountantThemeConfig.accentBlue,
                  ),
                  tooltip: 'تحديث البيانات',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        _buildLoadingSummary(),
        const SizedBox(height: 20),
        ...List.generate(3, (index) => 
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
          ).animate(delay: (index * 200).ms).shimmer(duration: 1500.ms),
        ),
      ],
    );
  }

  Widget _buildLoadingSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          ...List.generate(3, (index) => 
            Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < 2 ? 16 : 0),
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ).animate(delay: (index * 100).ms).shimmer(duration: 1000.ms),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.build_outlined,
              size: 48,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد أدوات مستخدمة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم العثور على بيانات استخدام أدوات التصنيع لهذه الدفعة',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: widget.onRefresh,
            icon: Icon(Icons.refresh),
            label: Text('إعادة تحميل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildOverallSummary() {
    final totalTools = widget.toolAnalytics.length;
    final totalQuantityUsed = widget.toolAnalytics
        .fold<double>(0, (sum, tool) => sum + tool.totalQuantityUsed);
    final averageUsagePercentage = widget.toolAnalytics.isNotEmpty
        ? widget.toolAnalytics
            .fold<double>(0, (sum, tool) => sum + tool.usagePercentage) / totalTools
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.primaryGreen.withOpacity(0.1),
            AccountantThemeConfig.accentBlue.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
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
                Icons.analytics,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'ملخص الاستهلاك الإجمالي',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  'عدد الأدوات',
                  '$totalTools',
                  'أداة',
                  Icons.build_circle,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
              Expanded(
                child: _buildSummaryMetric(
                  'الوحدات المنتجة',
                  '${widget.unitsProduced.toStringAsFixed(0)}',
                  'وحدة',
                  Icons.factory,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  'إجمالي المستهلك',
                  totalQuantityUsed.toStringAsFixed(1),
                  'وحدة',
                  Icons.inventory_2,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildSummaryMetric(
                  'متوسط الاستهلاك',
                  '${averageUsagePercentage.toStringAsFixed(1)}%',
                  '',
                  Icons.pie_chart,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildSummaryMetric(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsAnalyticsList() {
    final analyticsToShow = _getFilteredAnalytics();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.list_alt,
              color: AccountantThemeConfig.accentBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تفاصيل استخدام الأدوات',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_searchResults != null && _searchResults!.isFiltered)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  '${_searchResults!.filteredCount} من ${_searchResults!.totalCount}',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: AccountantThemeConfig.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...analyticsToShow.asMap().entries.map((entry) {
          final index = entry.key;
          final tool = entry.value;
          return _buildDetailedToolCard(tool, index);
        }).toList(),
      ],
    );
  }

  Widget _buildDetailedToolCard(ToolUsageAnalytics tool, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tool.stockStatusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onToolTap != null ? () => widget.onToolTap!(tool.toolId) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildToolHeader(tool),
                const SizedBox(height: 16),
                _buildToolMetrics(tool),
                const SizedBox(height: 16),
                _buildUsageVisualization(tool),
                if (tool.usageHistory.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildUsageHistoryPreview(tool),
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (index * 150).ms).fadeIn(duration: 600.ms).slideX(begin: 0.3, end: 0);
  }

  Widget _buildToolHeader(ToolUsageAnalytics tool) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tool.stockStatusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.build,
            color: tool.stockStatusColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tool.toolName,
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'الوحدة: ${tool.unit}',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: tool.stockStatusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tool.stockStatusColor.withOpacity(0.5),
            ),
          ),
          child: Text(
            tool.stockStatusText,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: tool.stockStatusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolMetrics(ToolUsageAnalytics tool) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricColumn(
                  'لكل وحدة منتجة',
                  '${tool.quantityUsedPerUnit.toStringAsFixed(2)} ${tool.unit}',
                  Icons.precision_manufacturing,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.1),
              ),
              Expanded(
                child: _buildMetricColumn(
                  'إجمالي المستخدم',
                  '${tool.totalQuantityUsed.toStringAsFixed(1)} ${tool.unit}',
                  Icons.inventory_2,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildEnhancedRemainingStockColumn(tool),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.1),
              ),
              Expanded(
                child: _buildMetricColumn(
                  'نسبة الاستهلاك',
                  '${tool.usagePercentage.toStringAsFixed(1)}%',
                  Icons.pie_chart,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedRemainingStockColumn(ToolUsageAnalytics tool) {
    return Column(
      children: [
        Stack(
          children: [
            Icon(
              Icons.storage,
              color: AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.accentBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.calculate,
                  color: Colors.white,
                  size: 6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'المخزون المتبقي',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Tooltip(
              message: 'محسوب: (الوحدات المتبقية × الأدوات لكل وحدة)',
              child: Icon(
                Icons.info_outline,
                color: AccountantThemeConfig.accentBlue,
                size: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${tool.remainingStock.toStringAsFixed(1)} ${tool.unit}',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'للإنتاج المتبقي',
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: AccountantThemeConfig.accentBlue,
            fontSize: 9,
          ),
          textAlign: TextAlign.center,
        ),
        // Debug info for remaining stock calculation
        if (kDebugMode)
          Text(
            'Debug: ${tool.quantityUsedPerUnit.toStringAsFixed(2)}/unit',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.yellow,
              fontSize: 8,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildMetricColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildUsageVisualization(ToolUsageAnalytics tool) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'مستوى المخزون المتبقي',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(100 - tool.usagePercentage).toStringAsFixed(1)}%',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: tool.stockStatusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            children: [
              // شريط الاستهلاك
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: tool.usagePercentage / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              // شريط المخزون المتبقي
              FractionallySizedBox(
                alignment: Alignment.centerRight,
                widthFactor: (100 - tool.usagePercentage) / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: tool.stockStatusColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ).animate().scaleX(duration: 1000.ms, curve: Curves.easeOutCubic),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'مستهلك',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: tool.stockStatusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'متبقي',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUsageHistoryPreview(ToolUsageAnalytics tool) {
    final recentEntries = tool.usageHistory.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history,
              color: AccountantThemeConfig.accentBlue,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'آخر الاستخدامات (${tool.usageHistory.length})',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...recentEntries.map((entry) =>
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.build,
                    color: AccountantThemeConfig.accentBlue,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دفعة رقم ${entry.batchId}',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${entry.quantityUsed.toStringAsFixed(1)} ${tool.unit}',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  entry.formattedDate,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ).toList(),
        if (tool.usageHistory.length > 3)
          TextButton.icon(
            onPressed: widget.onToolTap != null ? () => widget.onToolTap!(tool.toolId) : null,
            icon: Icon(
              Icons.more_horiz,
              size: 16,
              color: AccountantThemeConfig.accentBlue,
            ),
            label: Text(
              'عرض المزيد (${tool.usageHistory.length - 3})',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.accentBlue,
              ),
            ),
          ),
      ],
    );
  }

  /// بناء ويدجت البحث والفلترة
  Widget _buildSearchWidget() {
    return ManufacturingToolsSearchWidget(
      initialCriteria: _searchCriteria,
      onCriteriaChanged: _onSearchCriteriaChanged,
      onExport: _showExportDialog,
      searchHint: 'البحث في أدوات التصنيع...',
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  /// الحصول على التحليلات المفلترة مع التحقق من صحة البيانات
  List<ToolUsageAnalytics> _getFilteredAnalytics() {
    List<ToolUsageAnalytics> analytics;

    if (_searchResults != null) {
      analytics = _searchResults!.items;
    } else {
      analytics = widget.toolAnalytics;
    }

    // تطبيق التحقق من صحة البيانات والتنظيف
    return _validateAndSanitizeAnalytics(analytics);
  }

  /// التحقق من صحة البيانات وتنظيفها
  List<ToolUsageAnalytics> _validateAndSanitizeAnalytics(List<ToolUsageAnalytics> analytics) {
    try {
      // التحقق من صحة البيانات
      _validationResult = _validationService.validateToolUsageAnalytics(analytics);

      if (!_validationResult!.isValid) {
        AppLogger.warning('⚠️ Data validation failed: ${_validationResult!.errors.join(', ')}');
        _hasDataIntegrityIssues = true;
      } else if (_validationResult!.warnings.isNotEmpty) {
        AppLogger.info('ℹ️ Data validation warnings: ${_validationResult!.warnings.join(', ')}');
        _hasDataIntegrityIssues = true;
      } else {
        _hasDataIntegrityIssues = false;
      }

      // تنظيف البيانات التالفة
      final sanitizedAnalytics = analytics.map((analytic) {
        return ManufacturingToolsEdgeCasesHandler.sanitizeToolAnalytics(analytic);
      }).toList();

      return sanitizedAnalytics;
    } catch (e) {
      AppLogger.error('❌ Error validating analytics: $e');
      _errorMessage = 'خطأ في التحقق من صحة البيانات: $e';
      return [];
    }
  }

  /// تبديل عرض ويدجت البحث
  void _toggleSearchWidget() {
    setState(() {
      _showSearchWidget = !_showSearchWidget;
      if (!_showSearchWidget) {
        // إعادة تعيين معايير البحث عند إخفاء البحث
        _searchCriteria = const ToolSearchCriteria();
        _searchResults = null;
      }
    });
  }

  /// معالج تغيير معايير البحث
  void _onSearchCriteriaChanged(ToolSearchCriteria criteria) {
    setState(() {
      _searchCriteria = criteria;
      if (criteria.hasActiveFilters) {
        _searchResults = _searchService.searchToolUsageAnalytics(
          widget.toolAnalytics,
          criteria,
        );
      } else {
        _searchResults = null;
      }
    });
  }

  /// عرض حوار التصدير
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => ManufacturingToolsExportDialog(
        onExport: _exportReport,
      ),
    );
  }

  /// تصدير التقرير
  Future<void> _exportReport(String format, Map<String, dynamic> options) async {
    try {
      AppLogger.info('📊 Exporting manufacturing tools report in $format format');

      final analyticsToExport = _getFilteredAnalytics();

      if (analyticsToExport.isEmpty) {
        _showMessage('لا توجد بيانات للتصدير', isError: true);
        return;
      }

      String content;
      String fileName;
      String mimeType;

      switch (format) {
        case 'csv':
          content = await _exportService.exportToolUsageAnalyticsToCSV(
            analyticsToExport,
            widget.batchId,
          );
          fileName = 'manufacturing_tools_analytics_${widget.batchId}_${DateTime.now().millisecondsSinceEpoch}.csv';
          mimeType = 'text/csv';
          break;

        case 'json':
          // For JSON, we'll create a comprehensive report if multiple sections are selected
          content = await _exportService.exportComprehensiveReportToJSON(
            batchId: widget.batchId,
            productId: 0, // Will be provided by parent widget
            toolAnalytics: analyticsToExport,
            gapAnalysis: null, // Will be provided if available
            forecast: null, // Will be provided if available
          );
          fileName = 'manufacturing_tools_report_${widget.batchId}_${DateTime.now().millisecondsSinceEpoch}.json';
          mimeType = 'application/json';
          break;

        default:
          throw Exception('تنسيق غير مدعوم: $format');
      }

      await _exportService.saveAndShareExport(
        content: content,
        fileName: fileName,
        mimeType: mimeType,
      );

      _showMessage('تم تصدير التقرير بنجاح');

    } catch (e) {
      AppLogger.error('❌ Error exporting report: $e');
      _showMessage('فشل في تصدير التقرير: $e', isError: true);
    }
  }

  /// عرض رسالة للمستخدم
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: isError
            ? Colors.red.withOpacity(0.9)
            : AccountantThemeConfig.primaryGreen.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  /// بناء حالة الخطأ
  Widget _buildErrorState() {
    return ManufacturingToolsEdgeCasesHandler.buildErrorFallbackWidget(
      title: 'خطأ في تحميل البيانات',
      message: _errorMessage ?? 'حدث خطأ غير متوقع',
      onRetry: () {
        setState(() {
          _errorMessage = null;
        });
        widget.onRefresh?.call();
      },
    );
  }

  /// بناء تحذير التحقق من صحة البيانات
  Widget _buildValidationWarning() {
    if (_validationResult == null) return const SizedBox.shrink();

    final hasErrors = _validationResult!.errors.isNotEmpty;
    final hasWarnings = _validationResult!.warnings.isNotEmpty;

    if (!hasErrors && !hasWarnings) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (hasErrors ? Colors.red : Colors.orange).withOpacity(0.15),
            (hasErrors ? Colors.red : Colors.orange).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (hasErrors ? Colors.red : Colors.orange).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasErrors ? Icons.error : Icons.warning,
                color: hasErrors ? Colors.red : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasErrors ? 'مشاكل في البيانات' : 'تحذيرات البيانات',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: hasErrors ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _showValidationDetails,
                child: Text(
                  'عرض التفاصيل',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: hasErrors ? Colors.red : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          if (hasErrors) ...[
            const SizedBox(height: 8),
            Text(
              'تم العثور على ${_validationResult!.errors.length} خطأ في البيانات. قد تكون بعض المعلومات غير دقيقة.',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white70,
              ),
            ),
          ] else if (hasWarnings) ...[
            const SizedBox(height: 8),
            Text(
              'تم العثور على ${_validationResult!.warnings.length} تحذير. البيانات صحيحة ولكن قد تحتاج مراجعة.',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
  }

  /// عرض تفاصيل التحقق من صحة البيانات
  void _showValidationDetails() {
    if (_validationResult == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _validationResult!.errors.isNotEmpty ? Icons.error : Icons.warning,
              color: _validationResult!.errors.isNotEmpty ? Colors.red : Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'تفاصيل التحقق من البيانات',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_validationResult!.errors.isNotEmpty) ...[
                  Text(
                    'الأخطاء:',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._validationResult!.errors.map((error) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error,
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
                if (_validationResult!.errors.isNotEmpty && _validationResult!.warnings.isNotEmpty)
                  const SizedBox(height: 16),
                if (_validationResult!.warnings.isNotEmpty) ...[
                  Text(
                    'التحذيرات:',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._validationResult!.warnings.map((warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            warning,
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إغلاق',
              style: TextStyle(color: AccountantThemeConfig.accentBlue),
            ),
          ),
          if (widget.onRefresh != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onRefresh!();
              },
              style: AccountantThemeConfig.primaryButtonStyle,
              child: Text('إعادة تحميل'),
            ),
        ],
      ),
    );
  }
}
