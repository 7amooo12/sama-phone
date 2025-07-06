import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/widgets/common/animated_card.dart';

/// ويدجت للرسوم البيانية المتحركة
/// يوفر هذا الملف مجموعة من الرسوم البيانية المتحركة التي يمكن استخدامها في التطبيق
class AnimatedLineChart extends StatefulWidget {

  const AnimatedLineChart({
    super.key,
    required this.chartData,
    required this.title,
    this.subtitle,
    this.height = 300,
    this.animationDuration = const Duration(milliseconds: 1500),
    this.animationCurve = Curves.easeInOut,
    this.showLegend = true,
    this.legendLabels,
    this.legendColors,
    this.showGridLines = true,
    this.showBorder = true,
    this.showDots = true,
    this.showAreaGradient = true,
    this.showTooltip = true,
    this.showAxisTitles = true,
    this.bottomAxisTitle,
    this.leftAxisTitle,
    this.showAxisValues = true,
    this.bottomAxisValues,
    this.minY = 0,
    this.maxY = 100,
    this.currentIndex = 0,
    this.onIndexChanged,
  }) : assert(
          legendLabels == null || legendColors == null || legendLabels.length == legendColors.length,
          'Legend labels and colors must have the same length',
        );
  final List<LineChartData> chartData;
  final String title;
  final String? subtitle;
  final double height;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool showLegend;
  final List<String>? legendLabels;
  final List<Color>? legendColors;
  final bool showGridLines;
  final bool showBorder;
  final bool showDots;
  final bool showAreaGradient;
  final bool showTooltip;
  final bool showAxisTitles;
  final String? bottomAxisTitle;
  final String? leftAxisTitle;
  final bool showAxisValues;
  final List<String>? bottomAxisValues;
  final double minY;
  final double maxY;
  final int currentIndex;
  final Function(int)? onIndexChanged;

  @override
  State<AnimatedLineChart> createState() => _AnimatedLineChartState();
}

class _AnimatedLineChartState extends State<AnimatedLineChart> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;

    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: widget.animationCurve,
      ),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(AnimatedLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentIndex != widget.currentIndex) {
      setState(() {
        _currentIndex = widget.currentIndex;
      });

      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: StyleSystem.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle!,
                        style: StyleSystem.bodySmall.copyWith(
                          color: StyleSystem.neutralMedium,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.chartData.length > 1)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 18),
                      onPressed: _currentIndex > 0
                          ? () {
                              setState(() {
                                _currentIndex--;
                              });
                              if (widget.onIndexChanged != null) {
                                widget.onIndexChanged!(_currentIndex);
                              }
                              _animationController.reset();
                              _animationController.forward();
                            }
                          : null,
                      color: _currentIndex > 0
                          ? StyleSystem.primaryColor
                          : StyleSystem.neutralLight,
                    ),
                    Text(
                      '${_currentIndex + 1}/${widget.chartData.length}',
                      style: StyleSystem.bodySmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      onPressed: _currentIndex < widget.chartData.length - 1
                          ? () {
                              setState(() {
                                _currentIndex++;
                              });
                              if (widget.onIndexChanged != null) {
                                widget.onIndexChanged!(_currentIndex);
                              }
                              _animationController.reset();
                              _animationController.forward();
                            }
                          : null,
                      color: _currentIndex < widget.chartData.length - 1
                          ? StyleSystem.primaryColor
                          : StyleSystem.neutralLight,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: widget.height,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final LineChartData data = widget.chartData[_currentIndex];

                // تطبيق الرسوم المتحركة على البيانات
                final animatedData = _createAnimatedData(data);

                return LineChart(
                  animatedData,
                );
              },
            ),
          ),
          if (widget.showLegend && widget.legendLabels != null && widget.legendColors != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: List.generate(
                widget.legendLabels!.length,
                (index) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: widget.legendColors![index],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.legendLabels![index],
                      style: StyleSystem.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  LineChartData _createAnimatedData(LineChartData originalData) {
    final animatedSpots = <List<FlSpot>>[];

    for (final line in originalData.lineBarsData) {
      final spots = <FlSpot>[];

      for (int i = 0; i < line.spots.length; i++) {
        final spot = line.spots[i];
        final animatedY = spot.y * _animation.value;
        spots.add(FlSpot(spot.x, animatedY));
      }

      animatedSpots.add(spots);
    }

    final animatedLineBarsData = <LineChartBarData>[];

    for (int i = 0; i < originalData.lineBarsData.length; i++) {
      final line = originalData.lineBarsData[i];

      animatedLineBarsData.add(
        line.copyWith(
          spots: animatedSpots[i],
          dotData: FlDotData(
            show: widget.showDots && _animation.value == 1.0,
          ),
        ),
      );
    }

    return originalData.copyWith(
      lineBarsData: animatedLineBarsData,
    );
  }
}

/// ويدجت للرسوم البيانية الدائرية المتحركة
class AnimatedPieChart extends StatefulWidget {

  const AnimatedPieChart({
    super.key,
    required this.sections,
    required this.title,
    this.subtitle,
    this.height = 300,
    this.animationDuration = const Duration(milliseconds: 1500),
    this.animationCurve = Curves.easeInOut,
    this.showLegend = true,
    this.legendLabels,
    this.legendColors,
    this.showValues = true,
    this.showValuesInPercentage = true,
    this.showTitles = true,
    this.centerSpaceRadius = 40,
    this.sectionsSpace = 2,
  }) : assert(
          legendLabels == null || legendColors == null || legendLabels.length == legendColors.length,
          'Legend labels and colors must have the same length',
        );
  final List<PieChartSectionData> sections;
  final String title;
  final String? subtitle;
  final double height;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool showLegend;
  final List<String>? legendLabels;
  final List<Color>? legendColors;
  final bool showValues;
  final bool showValuesInPercentage;
  final bool showTitles;
  final double centerSpaceRadius;
  final double sectionsSpace;

  @override
  State<AnimatedPieChart> createState() => _AnimatedPieChartState();
}

class _AnimatedPieChartState extends State<AnimatedPieChart> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: widget.animationCurve,
      ),
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
    return AnimatedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: StyleSystem.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: StyleSystem.bodySmall.copyWith(
                color: StyleSystem.neutralMedium,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: widget.height,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final animatedSections = widget.sections.map((section) {
                  return section.copyWith(
                    value: section.value * _animation.value,
                    radius: 100 * _animation.value,
                    title: widget.showTitles ? section.title : '',
                    titleStyle: section.titleStyle,
                    showTitle: widget.showTitles && _animation.value > 0.5,
                  );
                }).toList();

                return PieChart(
                  PieChartData(
                    sections: animatedSections,
                    centerSpaceRadius: widget.centerSpaceRadius,
                    sectionsSpace: widget.sectionsSpace,
                  ),
                );
              },
            ),
          ),
          if (widget.showLegend && widget.legendLabels != null && widget.legendColors != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: List.generate(
                widget.legendLabels!.length,
                (index) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: widget.legendColors![index],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.legendLabels![index],
                      style: StyleSystem.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
