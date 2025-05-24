import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class WorkerPerformanceCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine productivity color
    Color productivityColor;
    if (productivity >= 90) {
      productivityColor = Colors.green;
    } else if (productivity >= 75) {
      productivityColor = Colors.blue;
    } else if (productivity >= 60) {
      productivityColor = Colors.orange;
    } else {
      productivityColor = Colors.red;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Worker name and completed orders
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.safeOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$completedOrders طلب',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Productivity label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الإنتاجية',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.safeOpacity(0.7),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '$productivity%',
                        style: TextStyle(
                          color: productivityColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildProductivityBadge(productivityColor),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Productivity progress bar
              LinearPercentIndicator(
                lineHeight: 12,
                percent: productivity / 100,
                backgroundColor: theme.colorScheme.primary.safeOpacity(0.1),
                progressColor: productivityColor,
                barRadius: const Radius.circular(8),
                padding: EdgeInsets.zero,
                animation: true,
                animationDuration: 1000,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductivityBadge(Color color) {
    String text;
    if (productivity >= 90) {
      text = 'ممتاز';
    } else if (productivity >= 75) {
      text = 'جيد';
    } else if (productivity >= 60) {
      text = 'متوسط';
    } else {
      text = 'ضعيف';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.safeOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
