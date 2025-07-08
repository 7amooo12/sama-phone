import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';

/// ويدجت عرض تحليلات استخدام أدوات التصنيع
class ToolUsageAnalyticsWidget extends StatelessWidget {
  final List<ToolUsageAnalytics> analytics;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const ToolUsageAnalyticsWidget({
    super.key,
    required this.analytics,
    this.isLoading = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _buildHeader(),
          const SizedBox(height: 20),
          if (isLoading)
            _buildLoadingState()
          else if (analytics.isEmpty)
            _buildEmptyState()
          else
            _buildAnalyticsList(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.build_circle,
            color: AccountantThemeConfig.accentBlue,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'أدوات التصنيع المستخدمة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (onRefresh != null)
          IconButton(
            onPressed: onRefresh,
            icon: Icon(
              Icons.refresh,
              color: AccountantThemeConfig.accentBlue,
            ),
            tooltip: 'تحديث البيانات',
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(3, (index) => 
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
            ),
          ),
        ).animate(delay: (index * 100).ms).shimmer(duration: 1000.ms),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.build_outlined,
            size: 48,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد بيانات استخدام أدوات',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم العثور على أدوات مستخدمة في هذه الدفعة',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsList() {
    return Column(
      children: analytics.asMap().entries.map((entry) {
        final index = entry.key;
        final analytic = entry.value;
        return _buildAnalyticsCard(analytic, index);
      }).toList(),
    );
  }

  Widget _buildAnalyticsCard(ToolUsageAnalytics analytic, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: analytic.stockStatusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  analytic.toolName,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: analytic.stockStatusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: analytic.stockStatusColor.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  analytic.stockStatusText,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: analytic.stockStatusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'لكل وحدة',
                  '${analytic.quantityUsedPerUnit.toStringAsFixed(1)} ${analytic.unit}',
                  Icons.precision_manufacturing,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'إجمالي المستخدم',
                  '${analytic.totalQuantityUsed.toStringAsFixed(1)} ${analytic.unit}',
                  Icons.inventory_2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'المخزون المتبقي',
                  '${analytic.remainingStock.toStringAsFixed(1)} ${analytic.unit}',
                  Icons.storage,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'نسبة الاستخدام',
                  '${analytic.usagePercentage.toStringAsFixed(1)}%',
                  Icons.pie_chart,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildUsageProgressBar(analytic),
        ],
      ),
    ).animate(delay: (index * 100).ms).fadeIn(duration: 500.ms).slideX(begin: 0.3, end: 0);
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AccountantThemeConfig.primaryGreen,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsageProgressBar(ToolUsageAnalytics analytic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'مستوى المخزون',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white70,
              ),
            ),
            Text(
              '${(100 - analytic.usagePercentage).toStringAsFixed(1)}%',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: analytic.stockStatusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (100 - analytic.usagePercentage) / 100,
            child: Container(
              decoration: BoxDecoration(
                color: analytic.stockStatusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ويدجت عرض تحليل فجوة الإنتاج
class ProductionGapAnalysisWidget extends StatelessWidget {
  final ProductionGapAnalysis? gapAnalysis;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const ProductionGapAnalysisWidget({
    super.key,
    this.gapAnalysis,
    this.isLoading = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(
          gapAnalysis?.statusColor.withOpacity(0.5) ?? Colors.white.withOpacity(0.3)
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          if (isLoading)
            _buildLoadingState()
          else if (gapAnalysis == null)
            _buildEmptyState()
          else
            _buildGapAnalysisContent(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.analytics,
            color: AccountantThemeConfig.primaryGreen,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'تحليل فجوة الإنتاج',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (onRefresh != null)
          IconButton(
            onPressed: onRefresh,
            icon: Icon(
              Icons.refresh,
              color: AccountantThemeConfig.primaryGreen,
            ),
            tooltip: 'تحديث البيانات',
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
        ),
      ),
    ).animate().shimmer(duration: 1000.ms);
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 48,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد بيانات تحليل الفجوة',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGapAnalysisContent() {
    final gap = gapAnalysis!;

    return Column(
      children: [
        // شريط التقدم الرئيسي
        _buildMainProgressSection(gap),
        const SizedBox(height: 24),

        // معلومات الإنتاج
        _buildProductionInfoSection(gap),
        const SizedBox(height: 20),

        // القطع المتبقية
        _buildRemainingPiecesSection(gap),
      ],
    );
  }

  Widget _buildMainProgressSection(ProductionGapAnalysis gap) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: gap.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gap.statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'نسبة الإكمال',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: gap.statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gap.statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    gap.statusText,
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: gap.statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${gap.completionPercentage.toStringAsFixed(1)}%',
                  style: AccountantThemeConfig.headlineLarge.copyWith(
                    color: gap.statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  '${gap.currentProduction.toStringAsFixed(0)} / ${gap.targetQuantity.toStringAsFixed(0)}',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProgressBar(gap),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ProductionGapAnalysis gap) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (gap.completionPercentage / 100).clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: gap.statusColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    ).animate().scaleX(duration: 800.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildProductionInfoSection(ProductionGapAnalysis gap) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            'الإنتاج الحالي',
            '${gap.currentProduction.toStringAsFixed(0)} وحدة',
            Icons.factory,
            AccountantThemeConfig.accentBlue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildInfoCard(
            'الهدف المطلوب',
            '${gap.targetQuantity.toStringAsFixed(0)} وحدة',
            Icons.flag,
            AccountantThemeConfig.primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildRemainingPiecesSection(ProductionGapAnalysis gap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            gap.isCompleted ? Icons.check_circle : Icons.pending_actions,
            size: 32,
            color: gap.statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            gap.remainingPiecesText,
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: gap.statusColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          if (gap.estimatedCompletionDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'التاريخ المتوقع للإكمال: ${gap.estimatedCompletionDate!.day}/${gap.estimatedCompletionDate!.month}/${gap.estimatedCompletionDate!.year}',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            title,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// ويدجت عرض توقعات الأدوات المطلوبة
class RequiredToolsForecastWidget extends StatelessWidget {
  final RequiredToolsForecast? forecast;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final Function(int toolId)? onToolTap;

  const RequiredToolsForecastWidget({
    super.key,
    this.forecast,
    this.isLoading = false,
    this.onRefresh,
    this.onToolTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _buildHeader(),
          const SizedBox(height: 20),
          if (isLoading)
            _buildLoadingState()
          else if (forecast == null)
            _buildEmptyState()
          else
            _buildForecastContent(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.psychology,
            color: Colors.purple,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'الأدوات المطلوبة للإكمال',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (onRefresh != null)
          IconButton(
            onPressed: onRefresh,
            icon: Icon(
              Icons.refresh,
              color: Colors.purple,
            ),
            tooltip: 'تحديث البيانات',
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(3, (index) =>
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
        ).animate(delay: (index * 100).ms).shimmer(duration: 1000.ms),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 48,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد توقعات أدوات',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildForecastContent() {
    final fc = forecast!;

    return Column(
      children: [
        // ملخص التوقعات
        _buildForecastSummary(fc),
        const SizedBox(height: 20),

        // قائمة الأدوات المطلوبة
        if (fc.requiredTools.isNotEmpty) ...[
          _buildToolsList(fc),
        ],

        // تحذيرات الأدوات غير المتوفرة
        if (fc.hasUnavailableTools) ...[
          const SizedBox(height: 16),
          _buildUnavailableToolsWarning(fc),
        ],
      ],
    );
  }

  Widget _buildForecastSummary(RequiredToolsForecast fc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: fc.canCompleteProduction
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: fc.canCompleteProduction
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                fc.canCompleteProduction ? Icons.check_circle : Icons.warning,
                color: fc.canCompleteProduction ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fc.canCompleteProduction
                      ? 'يمكن إكمال الإنتاج'
                      : 'لا يمكن إكمال الإنتاج',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: fc.canCompleteProduction ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'القطع المتبقية',
                  '${fc.remainingPieces.toStringAsFixed(0)} وحدة',
                  Icons.pending_actions,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'عدد الأدوات',
                  '${fc.toolsCount} أداة',
                  Icons.build,
                ),
              ),
            ],
          ),
          if (fc.totalCost > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryItem(
              'التكلفة المتوقعة',
              '${fc.totalCost.toStringAsFixed(2)} ريال',
              Icons.attach_money,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.white70,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolsList(RequiredToolsForecast fc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تفاصيل الأدوات المطلوبة:',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...fc.requiredTools.asMap().entries.map((entry) {
          final index = entry.key;
          final tool = entry.value;
          return _buildToolItem(tool, index);
        }).toList(),
      ],
    );
  }

  Widget _buildToolItem(RequiredToolItem tool, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tool.availabilityColor.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        onTap: onToolTap != null ? () => onToolTap!(tool.toolId) : null,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tool.availabilityColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.build,
                color: tool.availabilityColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.toolName,
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'مطلوب: ${tool.quantityText}',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tool.shortfall > 0)
                    Text(
                      tool.shortfallText,
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.red,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tool.availabilityColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tool.availabilityText,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: tool.availabilityColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 100).ms).fadeIn(duration: 500.ms).slideX(begin: 0.3, end: 0);
  }

  Widget _buildUnavailableToolsWarning(RequiredToolsForecast fc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'أدوات غير متوفرة (${fc.unavailableToolsCount})',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fc.unavailableTools.join(', '),
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
