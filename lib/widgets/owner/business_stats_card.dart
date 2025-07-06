import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/accountant_theme_config.dart';


class BusinessStatsCard extends StatefulWidget {
  const BusinessStatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.change,
    required this.isPositiveChange,
    required this.chartData,
    required this.period,
    this.chartColor = Colors.blue,
  });
  final String title;
  final String value;
  final double change;
  final bool isPositiveChange;
  final List<double> chartData;
  final String period;
  final Color chartColor;

  @override
  State<BusinessStatsCard> createState() => _BusinessStatsCardState();
}

class _BusinessStatsCardState extends State<BusinessStatsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Responsive sizing based on available space
                final screenWidth = MediaQuery.of(context).size.width;
                final isTablet = screenWidth > 768;
                final isLargePhone = screenWidth > 600;

                // Calculate responsive dimensions
                final cardPadding = isTablet ? 24.0 : isLargePhone ? 20.0 : 16.0;
                final iconSize = isTablet ? 24.0 : 20.0;
                final titleFontSize = isTablet ? 18.0 : 16.0;
                final valueFontSize = isTablet ? 28.0 : 24.0;
                final chartPadding = isTablet ? 12.0 : 8.0;

                // Calculate minimum height based on content
                final minHeight = isTablet ? 240.0 : isLargePhone ? 220.0 : 200.0;
                final maxHeight = isTablet ? 300.0 : isLargePhone ? 260.0 : 240.0;

                return Container(
                  constraints: BoxConstraints(
                    minHeight: minHeight,
                    maxHeight: maxHeight,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: AccountantThemeConfig.mainBackgroundGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                        spreadRadius: 0,
                      ),
                    ],
                    border: Border.all(
                      color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with icon and title
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(iconSize * 0.4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                                    AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                              ),
                              child: Icon(
                                _getIconForTitle(widget.title),
                                color: AccountantThemeConfig.primaryGreen,
                                size: iconSize,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: AccountantThemeConfig.headlineMedium.copyWith(
                                  fontSize: titleFontSize,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildChangeIndicator(context),
                          ],
                        ),
                        SizedBox(height: isTablet ? 20 : 16),

                        // Value
                        Text(
                          widget.value,
                          style: AccountantThemeConfig.headlineLarge.copyWith(
                            fontSize: valueFontSize,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Period
                        Text(
                          widget.period,
                          style: AccountantThemeConfig.bodyMedium.copyWith(
                            fontSize: isTablet ? 14 : 12,
                          ),
                        ),
                        SizedBox(height: isTablet ? 20 : 16),

                        // Chart - Use Flexible instead of Expanded for better overflow handling
                        Flexible(
                          child: Container(
                            constraints: BoxConstraints(
                              minHeight: isTablet ? 80 : 60,
                              maxHeight: isTablet ? 120 : 100,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                                  AccountantThemeConfig.primaryGreen.withOpacity(0.05),
                                ],
                              ),
                            ),
                            padding: EdgeInsets.all(chartPadding),
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: false),
                                titlesData: const FlTitlesData(show: false),
                                borderData: FlBorderData(show: false),
                                lineTouchData: const LineTouchData(enabled: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _createSpots(),
                                    isCurved: true,
                                    barWidth: isTablet ? 3 : 2.5,
                                    color: AccountantThemeConfig.primaryGreen,
                                    gradient: LinearGradient(
                                      colors: [
                                        AccountantThemeConfig.primaryGreen,
                                        AccountantThemeConfig.primaryGreen.withOpacity(0.7),
                                      ],
                                    ),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                                          AccountantThemeConfig.primaryGreen.withOpacity(0.05),
                                        ],
                                      ),
                                    ),
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter: (spot, percent, barData, index) {
                                        return FlDotCirclePainter(
                                          radius: isTablet ? 3 : 2.5,
                                          color: AccountantThemeConfig.primaryGreen,
                                          strokeWidth: 2,
                                          strokeColor: Colors.white,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                minX: 0,
                                maxX: widget.chartData.length.toDouble() - 1,
                                minY: _getMinY(),
                                maxY: _getMaxY(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<FlSpot> _createSpots() {
    final spots = <FlSpot>[];
    for (int i = 0; i < widget.chartData.length; i++) {
      spots.add(FlSpot(i.toDouble(), widget.chartData[i]));
    }
    return spots;
  }

  double _getMinY() {
    final min = widget.chartData.isEmpty
        ? 0
        : widget.chartData.reduce((a, b) => a < b ? a : b);
    return (min * 0.9).toDouble();
  }

  double _getMaxY() {
    final max = widget.chartData.isEmpty
        ? 0
        : widget.chartData.reduce((a, b) => a > b ? a : b);
    return (max * 1.1).toDouble();
  }

  IconData _getIconForTitle(String title) {
    switch (title.toLowerCase()) {
      case 'المبيعات':
      case 'sales':
        return Icons.trending_up_rounded;
      case 'الطلبات':
      case 'orders':
        return Icons.shopping_cart_rounded;
      case 'الأرباح':
      case 'profits':
        return Icons.account_balance_wallet_rounded;
      case 'العملاء':
      case 'customers':
        return Icons.people_rounded;
      default:
        return Icons.analytics_rounded;
    }
  }

  Widget _buildChangeIndicator(BuildContext context) {
    final color = widget.isPositiveChange
        ? AccountantThemeConfig.primaryGreen
        : AccountantThemeConfig.dangerRed;
    final icon = widget.isPositiveChange
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: AccountantThemeConfig.glowShadows(color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.change.toStringAsFixed(1)}%',
            style: GoogleFonts.cairo(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
