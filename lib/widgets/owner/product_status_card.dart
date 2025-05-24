import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

class ProductStatusCard extends StatelessWidget {
  const ProductStatusCard({
    super.key,
    required this.name,
    required this.quantity,
    this.isLowStock = false,
    this.needsReorder = false,
    this.onTap,
  });
  final String name;
  final int quantity;
  final bool isLowStock;
  final bool needsReorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine status color based on stock and reorder status
    Color statusColor;
    String statusText;

    if (needsReorder) {
      statusColor = Colors.red;
      statusText = 'إعادة طلب';
    } else if (isLowStock) {
      statusColor = Colors.orange;
      statusText = 'مخزون منخفض';
    } else {
      statusColor = Colors.green;
      statusText = 'متوفر';
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
          child: Row(
            children: [
              // Product icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.safeOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),

              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المخزون: $quantity وحدة',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.safeOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: statusColor,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      needsReorder
                          ? Icons.add_shopping_cart
                          : isLowStock
                              ? Icons.warning_amber
                              : Icons.check_circle,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
