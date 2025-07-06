import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardChart extends StatelessWidget {

  const DashboardChart({
    super.key,
    required this.values,
    required this.labels,
    this.color = Colors.blue,
  });
  final List<double> values;
  final List<String> labels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (values.isEmpty || labels.isEmpty) {
      return Center(
        child: Text(
          'لا توجد بيانات كافية للعرض',
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.grey[600],
            fontFamily: 'Cairo',
          ),
        ),
      );
    }

    // حساب القيمة القصوى للرسم البياني
    final double maxY = values.isNotEmpty
        ? values.reduce((a, b) => a > b ? a : b) * 1.2
        : 10;

    // Dark theme colors
    final gridColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final textColor = isDarkMode ? Colors.white70 : Colors.grey[600];
    final borderColor = isDarkMode ? Colors.grey[600] : Colors.grey[300];
    final chartColor = color == Colors.blue ? const Color(0xFF10B981) : color; // Use green for better visibility

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor!,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
            verticalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: gridColor!,
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: gridColor,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value == value.roundToDouble() && value >= 0) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < labels.length) {
                    // Show every other label to avoid crowding
                    if (value.toInt() % 2 == 0 || labels.length <= 10) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          labels[value.toInt()],
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      );
                    }
                  }
                  return const SizedBox();
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: borderColor, width: 1),
          ),
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(values.length, (index) {
                return FlSpot(index.toDouble(), values[index]);
              }),
              isCurved: true,
              color: chartColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: chartColor,
                    strokeWidth: 2,
                    strokeColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: chartColor.withOpacity(0.2),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: isDarkMode
                  ? Colors.grey.shade800.withOpacity(0.9)
                  : Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  final value = spot.y;
                  String label = '';
                  if (index >= 0 && index < labels.length) {
                    label = labels[index];
                  }
                  return LineTooltipItem(
                    '$label: ${value.toStringAsFixed(0)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
            touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {},
          ),
        ),
      ),
    );
  }
}