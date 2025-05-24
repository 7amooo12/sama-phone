import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

class BusinessStatsCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Value and change percentage
            Row(
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                _buildChangeIndicator(context),
              ],
            ),
            const SizedBox(height: 8),

            // Period
            Text(
              period,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.safeOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),

            // Chart
            SizedBox(
              height: 80,
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
                      barWidth: 3,
                      color: chartColor,
                      belowBarData: BarAreaData(
                        show: true,
                        color: chartColor.safeOpacity(0.1),
                      ),
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                  minX: 0,
                  maxX: chartData.length.toDouble() - 1,
                  minY: _getMinY(),
                  maxY: _getMaxY(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _createSpots() {
    final spots = <FlSpot>[];
    for (int i = 0; i < chartData.length; i++) {
      spots.add(FlSpot(i.toDouble(), chartData[i]));
    }
    return spots;
  }

  double _getMinY() {
    final min =
        chartData.isEmpty ? 0 : chartData.reduce((a, b) => a < b ? a : b);
    return (min * 0.9).toDouble();
  }

  double _getMaxY() {
    final max =
        chartData.isEmpty ? 0 : chartData.reduce((a, b) => a > b ? a : b);
    return (max * 1.1).toDouble();
  }

  Widget _buildChangeIndicator(BuildContext context) {
    final color = isPositiveChange ? Colors.green : Colors.red;
    final icon = isPositiveChange ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.safeOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${change.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
