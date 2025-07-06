import 'package:flutter/material.dart';

import 'package:percent_indicator/linear_percent_indicator.dart';

class WorkerPerformanceCard extends StatefulWidget {
  const WorkerPerformanceCard({
    super.key,
    required this.name,
    required this.productivity,
    required this.completedOrders,
    this.onTap,
  });
  final String name;
  final int productivity;
  final int completedOrders;
  final VoidCallback? onTap;

  @override
  State<WorkerPerformanceCard> createState() => _WorkerPerformanceCardState();
}

class _WorkerPerformanceCardState extends State<WorkerPerformanceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine productivity color and gradient
    List<Color> productivityGradient;
    Color productivityColor;
    IconData performanceIcon;

    if (widget.productivity >= 80) {
      productivityGradient = [const Color(0xFF10B981), const Color(0xFF059669)];
      productivityColor = const Color(0xFF10B981);
      performanceIcon = Icons.trending_up_rounded;
    } else if (widget.productivity >= 60) {
      productivityGradient = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      productivityColor = const Color(0xFFF59E0B);
      performanceIcon = Icons.trending_flat_rounded;
    } else {
      productivityGradient = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
      productivityColor = const Color(0xFFEF4444);
      performanceIcon = Icons.trending_down_rounded;
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.translate(
            offset: Offset(_slideAnimation.value, 0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1E293B).withOpacity(0.9),
                          const Color(0xFF334155).withOpacity(0.8),
                        ]
                      : [
                          Colors.white,
                          const Color(0xFFF8FAFC),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: productivityColor.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
                border: Border.all(
                  color: productivityColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with avatar and performance badge
                        Row(
                          children: [
                            // Worker avatar
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: productivityGradient,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: productivityColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Worker info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: productivityColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.completedOrders} طلب مكتمل',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: isDark
                                              ? Colors.white.withOpacity(0.7)
                                              : const Color(0xFF6B7280),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Performance badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: productivityGradient,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: productivityColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    performanceIcon,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.productivity}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Productivity progress bar with enhanced design
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'مستوى الأداء',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.8)
                                        : const Color(0xFF374151),
                                  ),
                                ),
                                Text(
                                  _getPerformanceLabel(widget.productivity),
                                  style: TextStyle(
                                    color: productivityColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : const Color(0xFFF3F4F6),
                              ),
                              child: LinearPercentIndicator(
                                lineHeight: 8,
                                percent: widget.productivity / 100,
                                backgroundColor: Colors.transparent,
                                linearGradient: LinearGradient(
                                  colors: productivityGradient,
                                ),
                                barRadius: const Radius.circular(4),
                                padding: EdgeInsets.zero,
                                animation: true,
                                animationDuration: 1500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getPerformanceLabel(int productivity) {
    if (productivity >= 80) {
      return 'ممتاز';
    } else if (productivity >= 60) {
      return 'جيد';
    } else {
      return 'يحتاج تحسين';
    }
  }
}
