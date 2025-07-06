import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/services/import_analysis/packing_analyzer_service.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// مخطط دائري لتوزيع التصنيفات مع تصميم احترافي
/// يعرض النسب والألوان مع دعم RTL العربية والتفاعل
class CategoryChartWidget extends StatefulWidget {
  final Map<String, CategoryStatistics> categoryBreakdown;

  const CategoryChartWidget({
    super.key,
    required this.categoryBreakdown,
  });

  @override
  State<CategoryChartWidget> createState() => _CategoryChartWidgetState();
}

class _CategoryChartWidgetState extends State<CategoryChartWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  int _touchedIndex = -1;

  // ألوان المخطط
  final List<Color> _chartColors = [
    AccountantThemeConfig.primaryGreen,
    AccountantThemeConfig.accentBlue,
    AccountantThemeConfig.warningOrange,
    AccountantThemeConfig.successGreen,
    AccountantThemeConfig.dangerRed,
    const Color(0xFF9C27B0),
    const Color(0xFF607D8B),
    const Color(0xFF795548),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.mainBackgroundGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AccountantThemeConfig.glowShadows(
                    AccountantThemeConfig.primaryGreen,
                  ),
                ),
                child: const Icon(
                  Icons.pie_chart,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'توزيع التصنيفات',
                style: AccountantThemeConfig.headlineMedium.copyWith(
                  fontSize: 18,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // المخطط والأسطورة
          Row(
            children: [
              // المخطط الدائري
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 200,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: _buildPieChartSections(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // الأسطورة
              Expanded(
                flex: 2,
                child: _buildLegend(),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  /// بناء أقسام المخطط الدائري
  List<PieChartSectionData> _buildPieChartSections() {
    final entries = widget.categoryBreakdown.entries.toList();
    
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final categoryEntry = entry.value;
      final category = categoryEntry.key;
      final stats = categoryEntry.value;
      
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 65.0 : 55.0;
      final fontSize = isTouched ? 14.0 : 12.0;
      
      return PieChartSectionData(
        color: _chartColors[index % _chartColors.length],
        value: stats.percentage,
        title: '${stats.percentage.toInt()}%',
        radius: radius * _animationController.value,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
        badgeWidget: isTouched ? _buildBadge(category, stats) : null,
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  /// بناء شارة التفاصيل
  Widget _buildBadge(String category, CategoryStatistics stats) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            category,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            '${stats.itemCount} عنصر',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              fontSize: 8,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// بناء الأسطورة
  Widget _buildLegend() {
    final entries = widget.categoryBreakdown.entries.toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التصنيفات',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        ...entries.asMap().entries.map((entry) {
          final index = entry.key;
          final categoryEntry = entry.value;
          final category = categoryEntry.key;
          final stats = categoryEntry.value;
          
          return _buildLegendItem(
            category,
            stats,
            _chartColors[index % _chartColors.length],
            index,
          );
        }),
      ],
    );
  }

  /// بناء عنصر الأسطورة
  Widget _buildLegendItem(
    String category,
    CategoryStatistics stats,
    Color color,
    int index,
  ) {
    final isSelected = index == _touchedIndex;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _touchedIndex = _touchedIndex == index ? -1 : index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.1) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected 
              ? Border.all(color: color.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            // مؤشر اللون
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // تفاصيل التصنيف
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${stats.itemCount} عنصر (${stats.percentage.toInt()}%)',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      fontSize: 9,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 100).ms).fadeIn().slideX(begin: 0.3);
  }
}
