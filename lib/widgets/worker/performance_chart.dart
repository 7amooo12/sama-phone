import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

class PerformanceChart extends StatelessWidget {
  const PerformanceChart({
    super.key,
    required this.performanceData,
    required this.title,
    this.primaryColor = Colors.blue,
    this.secondaryColor = Colors.green,
  });
  final List<PerformanceData> performanceData;
  final String title;
  final Color primaryColor;
  final Color secondaryColor;

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
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: performanceData.isNotEmpty
                  ? _buildChart()
                  : Center(
                      child: Text(
                        'لا توجد بيانات متاحة',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.safeOpacity(0.7),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _calculateMaxY(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 &&
                    value.toInt() < performanceData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      performanceData[value.toInt()].label,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: _leftTitles,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        barGroups: _generateBarGroups(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) {
            return const FlLine(
              color: Colors.grey,
              strokeWidth: 0.5,
              dashArray: [5, 5],
            );
          },
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateBarGroups() {
    return List.generate(
      performanceData.length,
      (index) {
        final data = performanceData[index];
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: data.value,
              color: primaryColor,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            if (data.secondaryValue != null)
              BarChartRodData(
                toY: data.secondaryValue!,
                color: secondaryColor,
                width: 12,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
          ],
        );
      },
    );
  }

  double _calculateMaxY() {
    double maxValue = 0;
    for (final data in performanceData) {
      if (data.value > maxValue) {
        maxValue = data.value;
      }
      if (data.secondaryValue != null && data.secondaryValue! > maxValue) {
        maxValue = data.secondaryValue!;
      }
    }
    return (maxValue * 1.2).ceilToDouble(); // Add some padding
  }

  static Widget _leftTitles(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.grey,
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );

    return Text(
      value.toInt().toString(),
      style: style,
      textAlign: TextAlign.center,
    );
  }
}

class PerformanceData {
  PerformanceData({
    required this.label,
    required this.value,
    this.secondaryValue,
  });
  final String label;
  final double value;
  final double? secondaryValue;
}
