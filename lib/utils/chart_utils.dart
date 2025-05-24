import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

class ChartUtils {
  static Color getBarColor(int index, BuildContext context) {
    final List<Color> colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  static BarChartGroupData generateBarGroup(
    int x,
    double value,
    BuildContext context, {
    double width = 20,
    bool showTooltip = true,
  }) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          color: getBarColor(x, context),
          width: width,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
      showingTooltipIndicators: showTooltip ? [0] : [],
    );
  }

  static FlTitlesData getTitlesData(
    BuildContext context, {
    List<String>? bottomTitles,
    bool showLeftTitles = true,
    bool showRightTitles = false,
    bool showTopTitles = false,
    double leftTitlesReservedSize = 40,
    int? maxLeftTitles,
  }) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: showLeftTitles
            ? SideTitles(
                showTitles: true,
                reservedSize: leftTitlesReservedSize,
                getTitlesWidget: (value, meta) {
                  if (maxLeftTitles != null && value > maxLeftTitles) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toInt().toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              )
            : const SideTitles(showTitles: false),
      ),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: showRightTitles),
      ),
      topTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: showTopTitles),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            if (bottomTitles == null || value >= bottomTitles.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                bottomTitles[value.toInt()],
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        ),
      ),
    );
  }

  static FlBorderData getBorderData() {
    return FlBorderData(
      show: true,
      border: const Border(
        bottom: BorderSide(width: 1),
        left: BorderSide(width: 1),
      ),
    );
  }

  static FlGridData getGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.grey.safeOpacity(0.2),
          strokeWidth: 1,
          dashArray: [5, 5],
        );
      },
    );
  }
}
